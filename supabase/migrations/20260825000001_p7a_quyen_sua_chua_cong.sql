-- =========================================================
-- P7a — Quyền "Sửa chữa công", và tab mang nó
--
-- Triệu Vũ, 25/08/2026: "Hiện tại chưa có tab sửa chữa công, chấm bù công do
-- sót, bạn thiết kế cho tôi."
--
-- VÌ SAO NÓ PHẢI LÀ MỘT QUYỀN RIÊNG, KHÔNG GỘP VÀO "XÁC NHẬN CHẤM CÔNG"
--
-- Xác nhận là nói "đúng rồi" về một lần chấm CÓ THẬT. Sửa chữa là **tạo ra**
-- một lần chấm chưa từng xảy ra, hoặc xoá một lần đã xảy ra. Hai việc khác
-- hẳn nhau về sức nặng: người xác nhận sai thì công lệch một chút; người sửa
-- chữa sai thì có công khống.
--
-- Từ P0d một quyền = một ô tick = một tab, nên quyền này đi kèm tab
-- `sua-chua-cong`. Tick vào là cấp thật, bỏ tick là mất thật.
--
-- ⚠️ ĐỔI `quyen_tu_tab()` THÌ PHẢI DROP RỒI TẠO LẠI CỘT SINH `quyen`.
-- Postgres không tự tính lại. Cảnh báo này do chính P0d viết hôm qua, và đây
-- là lần đầu nó được dùng — nên làm đúng từng bước, có thứ tự:
--
--   1. drop cột sinh (kéo theo index gin)
--   2. thay thân hàm
--   3. tạo lại cột + index
--
-- Phép kiểm cấu trúc p0 số 30 so từng dòng giá trị đang lưu với giá trị tính
-- lại; nếu tôi quên bước 1 thì nó đỏ ngay.
-- =========================================================

-- ---------------------------------------------------------
-- 1. Gỡ cột sinh
-- ---------------------------------------------------------
drop index if exists public.idx_app_users_quyen;
alter table public.app_users drop column quyen;

-- ---------------------------------------------------------
-- 2. Ánh xạ mới
-- ---------------------------------------------------------
create or replace function public.quyen_tu_tab(p_tabs text[], p_duyet_cong boolean)
returns text[]
language sql
immutable
set search_path = ''
as $$
  select coalesce(
    (
      select array_agg(q order by q)
      from (
        select unnest(array[
          case when 'nhan-su'            = any (coalesce(p_tabs, '{}')) then 'quan_ly_nhan_su' end,
          case when 'luong-ky-luong'     = any (coalesce(p_tabs, '{}')) then 'tinh_luong' end,
          case when 'luong-bao-cao'      = any (coalesce(p_tabs, '{}')) then 'xem_luong' end,
          case when 'cham-cong-xac-nhan' = any (coalesce(p_tabs, '{}')) then 'xac_nhan_cham_cong' end,
          case when 'sua-chua-cong'      = any (coalesce(p_tabs, '{}')) then 'sua_chua_cong' end,
          case when coalesce(p_duyet_cong, false)                       then 'duyet_cong' end
        ]) as q
      ) t
      where q is not null
    ),
    '{}'::text[]
  );
$$;

comment on function public.quyen_tu_tab(text[], boolean) is
  'Ánh xạ ô tick tab → quyền. NGUỒN DUY NHẤT. Đổi ở đây thì phải drop và tạo lại cột app_users.quyen — Postgres không tự tính lại cột sinh.';

-- ---------------------------------------------------------
-- 3. Dựng lại cột sinh
-- ---------------------------------------------------------
alter table public.app_users
  add column quyen text[]
  generated always as (public.quyen_tu_tab(tabs, duyet_cong)) stored;

comment on column public.app_users.quyen is
  'CỘT SINH từ tabs + duyet_cong qua quyen_tu_tab(). Không ghi thẳng được. RLS đọc cột này — nó là quyền thật, còn tabs là lời khai ra nó.';

create index idx_app_users_quyen on public.app_users using gin (quyen);

-- ---------------------------------------------------------
-- 4. Cửa gác cho quyền mới
--
--    Sửa chữa công KHÔNG kèm quyền đọc lương, và cũng không kèm quyền xác
--    nhận chấm công. Nhưng nó PHẢI đọc được danh sách nhân sự — không biết
--    đang bù công cho ai thì không làm được việc.
-- ---------------------------------------------------------
create or replace function public.duoc_sua_chua_cong()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.current_app_role() = 'admin'
      or public.co_quyen('sua_chua_cong');
$$;

comment on function public.duoc_sua_chua_cong() is
  'Được chấm bù, sửa giờ và mở lại phiên tổ đội. Mạnh hơn xác nhận chấm công: nó TẠO RA công chứ không chỉ công nhận công có sẵn.';

revoke execute on function public.duoc_sua_chua_cong() from public, anon;
grant  execute on function public.duoc_sua_chua_cong() to authenticated;

create or replace function public.can_read_all_employees()
returns boolean language sql stable security definer set search_path = ''
as $$
  select public.current_app_role() = 'admin'
      or public.co_quyen('quan_ly_nhan_su')
      or public.co_quyen('tinh_luong')
      or public.co_quyen('xem_luong')
      or public.co_quyen('xac_nhan_cham_cong')
      or public.co_quyen('sua_chua_cong');
$$;
