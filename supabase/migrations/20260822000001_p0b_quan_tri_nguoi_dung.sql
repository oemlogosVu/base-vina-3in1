-- =========================================================
-- P0b — Quản trị người dùng
--
-- Cho tới hôm nay việc cấp tài khoản đi hai đường tay: chạy
-- `scripts/tao-tai-khoan.mjs`, rồi vào SQL Editor gõ một câu update để nối
-- tài khoản với hồ sơ nhân sự. Đường thứ hai không có công cụ nào, không có
-- ràng buộc nào, và gõ sai một ký tự mã nhân viên là nối tài khoản của người
-- này vào hồ sơ người khác — tức người này đọc được lương và CCCD của người
-- kia. Không có gì chặn, và cũng không có gì để lại dấu vết.
--
-- Migration này dựng phần database cho màn `/quan-tri/nguoi-dung`:
--   1. Một hồ sơ nhân sự chỉ được nối với MỘT tài khoản.
--   2. Không ai tự khoá được chính mình, và không khoá được admin cuối cùng.
--   3. Hàm đọc danh sách tài khoản kèm email — admin cần email để phân biệt
--      hai tài khoản trùng tên, mà email nằm ở `auth.users`, ngoài tầm RLS.
--
-- KHÔNG làm ở đây: tạo tài khoản và đặt lại mật khẩu. Hai việc đó cần
-- `service_role` nên nằm ở Edge Function `quan-tri-tai-khoan`.
-- =========================================================

-- ---------------------------------------------------------
-- 1. Một hồ sơ nhân sự — một tài khoản
--
-- Chỉ mục duy nhất TỪNG PHẦN: nhiều tài khoản cùng để trống `employee_id`
-- là bình thường (tài khoản kế toán thuê ngoài, tài khoản quản trị kỹ
-- thuật), nhưng hai tài khoản cùng trỏ vào một hồ sơ thì không.
--
-- Vì sao là chỉ mục chứ không phải kiểm tra trong code: `current_employee_id()`
-- trả về hồ sơ của người đang đăng nhập, và mọi policy "chỉ xem dữ liệu của
-- mình" ở P1–P3 đều dựa vào nó. Hai tài khoản trỏ chung một hồ sơ là hai
-- người cùng đọc được một bảng lương — chuyện đó phải chặn ở tầng không thể
-- đi vòng, không phải ở tầng ứng dụng.
-- ---------------------------------------------------------
create unique index uniq_app_users_employee
  on public.app_users (employee_id)
  where employee_id is not null;

comment on index public.uniq_app_users_employee is
  'Một hồ sơ nhân sự chỉ nối được với một tài khoản đăng nhập. Nhiều tài khoản cùng bỏ trống employee_id thì vẫn hợp lệ.';

-- Chỉ mục thường của P0 nay thừa: chỉ mục duy nhất ở trên phục vụ luôn việc
-- tra cứu theo employee_id.
drop index if exists public.idx_app_users_employee;

-- ---------------------------------------------------------
-- 2. Không tự khoá mình, không khoá admin cuối cùng
--
-- Hai tình huống khác nhau, và cả hai đều kết thúc bằng một hệ thống không
-- ai vào sửa được nữa:
--
--   a) Admin đang đăng nhập tự hạ vai trò mình xuống `nhan_vien` để "thử
--      xem nhân viên thấy gì". Bấm xong là mất luôn đường quay lại.
--   b) Còn đúng một admin đang hoạt động và ai đó khoá tài khoản ấy.
--
-- Không có admin nào thì cũng không còn đường sửa cấu hình, cấp lại quyền,
-- hay mở lại tài khoản — phải quay về Dashboard Supabase gõ SQL tay. Đó là
-- lối thoát, không phải quy trình.
--
-- Nhánh (a) so với `auth.uid()`, mà `auth.uid()` là NULL khi chạy bằng
-- `service_role` hoặc trong SQL Editor. CỐ Ý: lối thoát bằng tay ở Dashboard
-- phải luôn còn. Nhánh (b) thì không có ngoại lệ nào — nó là bất biến dữ
-- liệu, đúng cả khi chạy bằng service_role.
-- ---------------------------------------------------------
create or replace function public.chan_mat_quyen_admin()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  con_admin int;
begin
  -- (a) Tự hạ quyền hoặc tự khoá chính mình.
  if old.id = (select auth.uid())
     and old.role = 'admin'
     and (new.role <> 'admin' or new.is_active = false) then
    raise exception
      'Không tự hạ vai trò hoặc tự khoá tài khoản admin của chính mình. Nhờ một admin khác làm giúp.'
      using errcode = 'check_violation';
  end if;

  -- (b) Admin đang hoạt động cuối cùng.
  if old.role = 'admin' and old.is_active
     and (new.role <> 'admin' or new.is_active = false) then
    select count(*) into con_admin
    from public.app_users u
    where u.role = 'admin' and u.is_active and u.id <> old.id;

    if con_admin = 0 then
      raise exception
        'Đây là admin đang hoạt động cuối cùng. Cấp quyền admin cho một tài khoản khác trước đã, nếu không sẽ không còn ai vào được màn quản trị.'
        using errcode = 'check_violation';
    end if;
  end if;

  return new;
end;
$$;

comment on function public.chan_mat_quyen_admin() is
  'Chặn hai đường dẫn tới hệ thống không còn admin: tự hạ quyền mình, và hạ/khoá admin đang hoạt động cuối cùng.';

create trigger trg_app_users_chan_mat_quyen_admin
  before update on public.app_users
  for each row execute function public.chan_mat_quyen_admin();

-- ---------------------------------------------------------
-- 3. Danh sách tài khoản cho admin — kèm email và lần đăng nhập cuối
--
-- Email nằm ở `auth.users`, mà bảng đó PostgREST không cho đọc và RLS không
-- với tới. Không có email thì màn quản trị hiện hai dòng "Triệu Vũ" giống
-- hệt nhau và admin không biết dòng nào là tài khoản nào — đúng tình trạng
-- hiện tại của project.
--
-- `security definer` nên hàm này BỎ QUA RLS. Vì vậy điều kiện phân quyền
-- phải tự viết ra ngay trong thân hàm: `current_app_role() = 'admin'`. Không
-- có dòng đó thì đây là một endpoint trả toàn bộ email của công ty cho bất
-- kỳ ai đăng nhập — đúng thứ AGENTS.md mục 7 cấm.
--
-- Trả về ZERO dòng cho người không phải admin, không ném lỗi: màn hình đã
-- chặn bằng `batBuocVaiTro('admin')` rồi, tới đây mà không phải admin thì là
-- người đang dò, và không nợ họ một thông báo lỗi cho biết hàm này tồn tại.
--
-- `last_sign_in_at` có mặt vì nó trả lời được câu hỏi admin hỏi nhiều nhất:
-- tài khoản này đã ai dùng bao giờ chưa, hay cấp xong rồi để đó.
-- ---------------------------------------------------------
create or replace function public.ds_tai_khoan()
returns table (
  id              uuid,
  full_name       text,
  email           text,
  role            public.user_role,
  is_active       boolean,
  quan_ly_to_doi  boolean,
  employee_id     uuid,
  ma_nhan_vien    text,
  ten_nhan_vien   text,
  dang_nhap_cuoi  timestamptz,
  tao_luc         timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select u.id,
         u.full_name,
         a.email::text,
         u.role,
         u.is_active,
         u.quan_ly_to_doi,
         u.employee_id,
         e.employee_code,
         e.full_name,
         a.last_sign_in_at,
         u.created_at
  from public.app_users u
  join auth.users a on a.id = u.id
  left join public.employees e on e.id = u.employee_id
  where public.current_app_role() = 'admin'
  order by u.is_active desc, u.full_name;
$$;

comment on function public.ds_tai_khoan() is
  'Danh sách tài khoản kèm email và lần đăng nhập cuối. Chỉ admin nhận được dòng nào; vai trò khác nhận danh sách rỗng.';

revoke all on function public.ds_tai_khoan() from public;
revoke all on function public.ds_tai_khoan() from anon;
grant execute on function public.ds_tai_khoan() to authenticated;
