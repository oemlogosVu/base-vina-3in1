-- =========================================================
-- P5a — Người quản lý chấm công tổ đội: điều kiện và cách gán
--
-- Yêu cầu Triệu Vũ 19/08/2026, sau khi xem bản đầu:
--   1. Người chấm công cho tổ công nhật PHẢI là nhân viên chính thức, có
--      hợp đồng lao động đang hiệu lực (đóng bảo hiểm).
--   2. Admin thiết lập một người quản lý được chấm cho NHỮNG tổ nào.
--
-- HAI THAY ĐỔI SO VỚI BẢN ĐẦU:
--
-- (a) Ô `to_doi.nguoi_cham_cong_id` thành BẢNG GÁN `to_doi_nguoi_cham`.
--     Một ô chỉ chứa được một người, mà thực tế cần cả hai chiều: một quản lý
--     phụ trách nhiều tổ, và một tổ cần người chấm dự phòng cho hôm tổ trưởng
--     nghỉ. Bản đầu làm được chiều thứ nhất, không làm được chiều thứ hai —
--     và chiều thứ hai mới là chiều hay hỏng việc lúc 6 giờ sáng ngoài công
--     trường. Bảng chưa có dữ liệu thật nên đổi lúc này không mất gì.
--
-- (b) Điều kiện "nhân viên chính thức" kiểm ở HAI CHỖ, cố ý:
--
--       • Trigger lúc GÁN     — báo bằng tiếng người, chặn sai từ đầu vào.
--       • Hàm nền lúc ĐỌC/GHI — người nghỉ việc MẤT quyền chấm ngay lập tức.
--
--     Chỉ kiểm lúc gán là không đủ: gán xong rồi người đó nghỉ việc, hợp đồng
--     hết hiệu lực, mà dòng gán vẫn nằm đó — họ vẫn chấm công được cho tới khi
--     có ai đó nhớ ra mà gỡ. Kiểm lúc dùng thì quyền tự tắt theo hồ sơ, không
--     phụ thuộc trí nhớ của ai.
--
-- VÌ SAO ĐÒI NHÂN VIÊN CHÍNH THỨC: người chấm công quyết định công của người
-- khác, và công là tiền. Giao việc đó cho một cộng tác viên thời vụ là giao
-- quyền quyết tiền cho người mà chính doanh nghiệp cũng chỉ ràng buộc lỏng.
-- =========================================================

-- ---------------------------------------------------------
-- 1. Thế nào là "nhân viên chính thức, đóng bảo hiểm"
--
--    Ba vế, thiếu vế nào cũng không đạt:
--      - tài khoản còn hiệu lực và có gắn hồ sơ nhân sự;
--      - hồ sơ ở trạng thái chinh_thuc và chưa bị xoá;
--      - có hợp đồng lao động đang hiệu lực với mức đóng bảo hiểm > 0.
--
--    Vế thứ ba là phần "(đóng bảo hiểm)" trong yêu cầu. Không suy ra từ trạng
--    thái: trạng thái nói về quan hệ lao động, hợp đồng mới nói về tiền đóng.
-- ---------------------------------------------------------
create or replace function public.la_nhan_vien_chinh_thuc(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.app_users u
    join public.employees e on e.id = u.employee_id
    join public.labor_contracts lc on lc.employee_id = e.id and lc.is_active
    where u.id = p_user_id
      and u.is_active
      and e.deleted_at is null
      and e.status = 'chinh_thuc'
      and lc.bhxh_salary > 0
  );
$$;

comment on function public.la_nhan_vien_chinh_thuc(uuid) is
  'Tài khoản này có phải nhân viên chính thức đang đóng bảo hiểm không: hồ sơ chinh_thuc, chưa xoá, và có hợp đồng đang hiệu lực với bhxh_salary > 0.';

revoke execute on function public.la_nhan_vien_chinh_thuc(uuid) from anon;

-- ---------------------------------------------------------
-- 2. Bảng gán: ai được chấm cho tổ nào
-- ---------------------------------------------------------
create table public.to_doi_nguoi_cham (
  id          uuid primary key default gen_random_uuid(),
  to_doi_id   uuid not null references public.to_doi (id) on delete cascade,
  app_user_id uuid not null references public.app_users (id),
  ghi_chu     text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),

  constraint nguoi_cham_khong_trung unique (to_doi_id, app_user_id)
);

comment on table public.to_doi_nguoi_cham is
  'Admin gán người quản lý chấm công cho từng tổ. Một người phụ trách nhiều tổ; một tổ có nhiều người chấm (chính và dự phòng).';

create index idx_tdnc_to_doi on public.to_doi_nguoi_cham (to_doi_id);
create index idx_tdnc_nguoi on public.to_doi_nguoi_cham (app_user_id);

create trigger trg_to_doi_nguoi_cham_touch
  before update on public.to_doi_nguoi_cham
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------
-- 3. Chặn gán người không đủ điều kiện
-- ---------------------------------------------------------
create or replace function public.kiem_nguoi_cham_chinh_thuc()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  ten text;
begin
  if public.la_nhan_vien_chinh_thuc(new.app_user_id) then
    return new;
  end if;

  select u.full_name into ten from public.app_users u where u.id = new.app_user_id;

  raise exception
    'Không giao được việc chấm công cho %. Người chấm công tổ đội phải là nhân viên CHÍNH THỨC, có hợp đồng lao động đang hiệu lực và đóng bảo hiểm — vì họ quyết định công của người khác, mà công là tiền.',
    coalesce(ten, 'tài khoản này');
end;
$$;

create trigger trg_kiem_nguoi_cham_chinh_thuc
  before insert or update on public.to_doi_nguoi_cham
  for each row execute function public.kiem_nguoi_cham_chinh_thuc();

-- ---------------------------------------------------------
-- 4. Hàm nền đọc bảng gán, và kiểm điều kiện NGAY LÚC DÙNG
--
--    Thay thân hàm, giữ nguyên tên và chữ ký: policy trên public.* lẫn policy
--    trên storage.objects đều đang gọi chúng, không phải sửa chỗ nào khác.
-- ---------------------------------------------------------
create or replace function public.la_nguoi_cham_cong_to(p_to_doi_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.to_doi t
    join public.to_doi_nguoi_cham g on g.to_doi_id = t.id
    where t.id = p_to_doi_id
      and t.is_active
      and g.app_user_id = (select auth.uid())
      -- Kiểm lại điều kiện tại đây: nghỉ việc hôm nay thì mất quyền chấm hôm
      -- nay, không chờ ai nhớ ra mà gỡ dòng gán.
      and public.la_nhan_vien_chinh_thuc(g.app_user_id)
  );
$$;

comment on function public.la_nguoi_cham_cong_to(uuid) is
  'Người đang đăng nhập có được giao chấm công cho tổ này không. Tổ ngừng hoạt động, tài khoản bị khoá, hoặc người đó không còn là nhân viên chính thức — đều trả false.';

create or replace function public.la_nguoi_cham_cong_to_txt(p_id text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.to_doi t
    join public.to_doi_nguoi_cham g on g.to_doi_id = t.id
    where t.id::text = p_id
      and t.is_active
      and g.app_user_id = (select auth.uid())
      and public.la_nhan_vien_chinh_thuc(g.app_user_id)
  );
$$;

-- ---------------------------------------------------------
-- 5. Gỡ ô cũ
--
--    Bảng chưa có dữ liệu thật nên không phải chuyển đổi gì. Gỡ hẳn thay vì
--    để lại: một cột chết mà vẫn trông như đang dùng là cái bẫy cho người đọc
--    code sau này.
-- ---------------------------------------------------------
alter table public.to_doi drop column nguoi_cham_cong_id;

-- ---------------------------------------------------------
-- 6. RLS cho bảng gán
--
--    Đọc: HR/kế toán/admin, và chính người được gán (họ cần biết mình phụ
--    trách tổ nào). Ghi: chỉ admin — đây là việc thiết lập quyền, không phải
--    việc vận hành hàng ngày.
--
--    CÓ policy DELETE, khác với các bảng khác của phase. Gỡ một người khỏi tổ
--    là việc bình thường và phải gỡ được sạch — giữ lại dòng đã gỡ chỉ làm
--    hàm nền phải lọc thêm. Cùng lý do với position_allowances ở P2c. Dữ liệu
--    chấm công đã ghi KHÔNG bị ảnh hưởng: phiên lưu `nguoi_cham_id` của
--    chính nó.
-- ---------------------------------------------------------
alter table public.to_doi_nguoi_cham enable row level security;
alter table public.to_doi_nguoi_cham force  row level security;

create policy "tdnc_select_quan_ly"
  on public.to_doi_nguoi_cham for select
  to authenticated
  using ((select public.can_read_all_employees()));

create policy "tdnc_select_chinh_minh"
  on public.to_doi_nguoi_cham for select
  to authenticated
  using (app_user_id = (select auth.uid()));

create policy "tdnc_insert_admin"
  on public.to_doi_nguoi_cham for insert
  to authenticated
  with check ((select public.current_app_role()) = 'admin');

create policy "tdnc_update_admin"
  on public.to_doi_nguoi_cham for update
  to authenticated
  using ((select public.current_app_role()) = 'admin')
  with check ((select public.current_app_role()) = 'admin');

create policy "tdnc_delete_admin"
  on public.to_doi_nguoi_cham for delete
  to authenticated
  using ((select public.current_app_role()) = 'admin');

revoke all on public.to_doi_nguoi_cham from anon, authenticated;
grant select, insert, update, delete on public.to_doi_nguoi_cham to authenticated;
