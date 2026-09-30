-- =========================================================
-- P1d — Quyền gán theo chức danh, cộng dồn
--
-- Triệu Vũ, 22/08/2026: "trong tab quản trị cần phải gán quyền quản lý, tính
-- lương và chấm công cho các chức danh, phần này đang thiếu".
--
-- Đúng là thiếu. Màn Chức danh có ô tick tab, nhưng `tabsChoPhep()` lấy GIAO
-- của quyền-theo-vai-trò và cấu hình-theo-chức-danh, nên ô tick ấy chỉ BỚT
-- chứ không CẤP. Muốn ai đó tính được lương thì phải đặt vai trò `ke_toan`
-- trên tài khoản của họ — một chỗ khác hẳn, và phải nhớ làm cho từng người.
--
-- Từ bản này, chức danh mang quyền, và người giữ chức danh được CỘNG quyền
-- của mọi chức danh đang hiệu lực (chính lẫn kiêm nhiệm). Người mới vào tự có
-- đúng quyền theo chức danh, không phải nhớ đặt tay.
--
-- Ba quyền, do Triệu Vũ chọn hôm nay:
--   quan_ly_nhan_su    — như vai trò `hr`
--   tinh_luong         — như vai trò `ke_toan`
--   xac_nhan_cham_cong — duyệt chấm công hàng ngày
--
-- CỐ Ý KHÔNG có "trưởng phòng": quyền ấy gắn với việc phụ trách MỘT phòng cụ
-- thể, không phải với chức danh. Hai người cùng chức danh "Trưởng phòng" ở hai
-- phòng khác nhau phải thấy hai tập hồ sơ khác nhau — chức danh không nói được
-- điều đó. Nó vẫn nằm ở vai trò tài khoản như cũ.
--
-- CỐ Ý KHÔNG có "quản trị hệ thống": vai trò admin sửa được chính bảng
-- `positions`, nên cấp admin qua chức danh là mở đường cho người ta tự cấp
-- cho mình mọi thứ còn lại.
-- =========================================================

-- ---------------------------------------------------------
-- 1. Cột quyền trên chức danh
--
-- Mảng text như cột `tabs` đã có, không phải ba cột boolean: thêm quyền thứ
-- tư sau này chỉ là thêm một giá trị vào ràng buộc, không phải một migration
-- đổi hình dạng bảng.
--
-- Ràng buộc liệt kê đủ giá trị hợp lệ. Không có nó thì một lỗi gõ
-- ('tinh_long') sẽ lưu êm và người giữ chức danh đó lặng lẽ KHÔNG có quyền —
-- kiểu hỏng khó thấy nhất, vì màn hình vẫn hiện ô đã tick.
-- ---------------------------------------------------------
alter table public.positions
  add column quyen text[] not null default '{}'::text[];

alter table public.positions
  add constraint positions_quyen_hop_le
  check (quyen <@ array['quan_ly_nhan_su', 'tinh_luong', 'xac_nhan_cham_cong']::text[]);

comment on column public.positions.quyen is
  'Quyền mà người giữ chức danh này được hưởng, CỘNG DỒN với vai trò tài khoản và với các chức danh kiêm nhiệm khác. Rỗng = chức danh không cấp quyền gì.';

-- ---------------------------------------------------------
-- 2. Người đang đăng nhập có quyền này qua chức danh nào không
--
-- `security definer` là BẮT BUỘC, cùng lý do với `current_app_role()` ở P0:
-- hàm này được gọi TỪ TRONG policy của những bảng mà chính nó đọc, nên nếu
-- RLS áp lên câu đọc bên trong thì đệ quy. Đây cũng đúng cái bẫy đã làm chết
-- mọi lệnh UPDATE trên app_users suốt 14 ngày (vá sáng nay).
--
-- Chỉ tính chức danh ĐANG HIỆU LỰC hôm nay. Chức danh đã kết thúc thì quyền
-- cũng hết theo — không chờ ai nhớ ra mà gỡ.
-- ---------------------------------------------------------
create or replace function public.co_quyen_chuc_danh(p_quyen text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.app_users u
    join public.nhan_vien_chuc_danh nc on nc.employee_id = u.employee_id
    join public.positions p on p.id = nc.position_id
    where u.id = (select auth.uid())
      and u.is_active
      and p.is_active
      and nc.tu_ngay <= current_date
      and (nc.den_ngay is null or nc.den_ngay >= current_date)
      and p_quyen = any (p.quyen)
  );
$$;

comment on function public.co_quyen_chuc_danh(text) is
  'Người đang đăng nhập có quyền này qua một chức danh đang hiệu lực hay không. Cộng dồn mọi chức danh chính và kiêm nhiệm.';

revoke all on function public.co_quyen_chuc_danh(text) from public;
revoke all on function public.co_quyen_chuc_danh(text) from anon;
grant execute on function public.co_quyen_chuc_danh(text) to authenticated;

-- ---------------------------------------------------------
-- 3. Năm hàm phân quyền cộng thêm quyền theo chức danh
--
-- KHÔNG sửa một policy nào. Toàn bộ RLS của P1–P5 đã đi qua đúng năm hàm này,
-- nên sửa ở đây là sửa đúng một chỗ và mọi bảng theo cùng. Đó là lý do năm
-- hàm này tồn tại ngay từ P0.
-- ---------------------------------------------------------
create or replace function public.is_hr_or_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.current_app_role() in ('hr', 'admin')
      or public.co_quyen_chuc_danh('quan_ly_nhan_su');
$$;

create or replace function public.can_manage_attendance()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.current_app_role() in ('hr', 'admin')
      or public.co_quyen_chuc_danh('xac_nhan_cham_cong');
$$;

create or replace function public.can_manage_payroll()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.current_app_role() in ('ke_toan', 'admin')
      or public.co_quyen_chuc_danh('tinh_luong');
$$;

-- Xem được hồ sơ nhân sự là điều kiện nền của cả ba quyền: không thấy người
-- thì không làm được hồ sơ, không tính được lương, không duyệt được công.
create or replace function public.can_read_all_employees()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.current_app_role() in ('hr', 'ke_toan', 'admin')
      or public.co_quyen_chuc_danh('quan_ly_nhan_su')
      or public.co_quyen_chuc_danh('tinh_luong')
      or public.co_quyen_chuc_danh('xac_nhan_cham_cong');
$$;

-- Đọc bảng lương thì KHÔNG cộng 'xac_nhan_cham_cong': duyệt công là xác nhận
-- số ngày, không cần biết ai lương bao nhiêu. Cho kèm là mở dữ liệu lương cho
-- một việc không cần tới nó (NĐ 13/2023 — thu thập và truy cập tối thiểu).
create or replace function public.can_read_payroll()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.current_app_role() in ('hr', 'ke_toan', 'admin')
      or public.co_quyen_chuc_danh('quan_ly_nhan_su')
      or public.co_quyen_chuc_danh('tinh_luong');
$$;

-- ---------------------------------------------------------
-- 4. Bịt đường leo thang: gán chức danh CÓ QUYỀN là việc của admin
--
-- Đây là chỗ nguy hiểm nhất của cả thay đổi này, và nó không hiện ra khi chỉ
-- nhìn màn hình.
--
-- Ghi vào `positions` đã là admin-only, nên không ai tự thêm quyền cho một
-- chức danh. NHƯNG gán chức danh cho người thì `is_hr_or_admin()` làm được —
-- nghĩa là HR có thể tự gán cho mình chức danh "Kế toán trưởng" và lập tức
-- tính được lương. Trước bản này HR không làm được vậy: đổi vai trò tài khoản
-- là đặc quyền của admin.
--
-- Nên: gán/sửa một dòng chức danh mà chức danh ấy MANG QUYỀN thì phải là
-- admin. Chức danh không mang quyền nào vẫn để HR làm như cũ — tuyển người và
-- xếp chức danh là việc hằng ngày của họ.
--
-- `auth.uid()` NULL (service_role, SQL Editor) đi qua được: lối thoát bằng tay
-- phải luôn còn, giống hai trigger của P0b.
-- ---------------------------------------------------------
create or replace function public.chan_tu_cap_quyen_qua_chuc_danh()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  quyen_cd text[];
  ten_cd   text;
begin
  select p.quyen, p.name into quyen_cd, ten_cd
  from public.positions p where p.id = new.position_id;

  if coalesce(array_length(quyen_cd, 1), 0) = 0 then
    return new;
  end if;

  if (select auth.uid()) is not null
     and public.current_app_role() is distinct from 'admin' then
    raise exception
      'Chức danh "%" có kèm quyền (%). Chỉ quản trị hệ thống mới gán được chức danh có quyền — nếu không, người làm nhân sự sẽ tự cấp quyền cho chính mình.',
      ten_cd, array_to_string(quyen_cd, ', ')
      using errcode = 'insufficient_privilege';
  end if;

  return new;
end;
$$;

comment on function public.chan_tu_cap_quyen_qua_chuc_danh() is
  'Gán chức danh CÓ QUYỀN là một hành vi cấp quyền, nên chỉ admin làm được. Chức danh không mang quyền vẫn để HR gán như cũ.';

create trigger trg_chuc_danh_chan_tu_cap_quyen
  before insert or update of position_id on public.nhan_vien_chuc_danh
  for each row execute function public.chan_tu_cap_quyen_qua_chuc_danh();
