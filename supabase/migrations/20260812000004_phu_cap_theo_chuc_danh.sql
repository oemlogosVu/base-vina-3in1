-- =========================================================
-- Phụ cấp theo chức danh
--
-- Yêu cầu 12/08/2026: mỗi chức danh chọn được các loại phụ cấp, admin thiết
-- lập mức.
--
-- HAI BẢNG, KHÔNG PHẢI MỘT:
--   allowance_types      — DANH MỤC loại phụ cấp: tên, có chịu thuế không, có
--                          tính vào lương đóng bảo hiểm không. Định nghĩa một
--                          lần, dùng chung.
--   position_allowances  — chức danh nào hưởng loại nào, MỨC bao nhiêu.
--
-- Tách ra vì "phụ cấp ăn ca có chịu thuế không" là thuộc tính của LOẠI, giống
-- nhau ở mọi chức danh. Gộp vào một bảng là mỗi chức danh tự khai lại, và chỉ
-- cần một chỗ khai sai là tính sai thuế của riêng nhóm đó.
-- =========================================================

-- ---------------------------------------------------------
-- 1. Danh mục loại phụ cấp
-- ---------------------------------------------------------
create table public.allowance_types (
  id           uuid primary key default gen_random_uuid(),
  code         text not null unique,
  name         text not null,

  -- Hai cờ này quyết định tiền, và chúng KHÁC NHAU — đừng gộp:
  --   is_taxable   : có cộng vào thu nhập chịu thuế TNCN không
  --   is_insurance : có cộng vào lương đóng BHXH/BHYT/BHTN không
  -- Ví dụ phụ cấp ăn ca trong định mức thì không chịu thuế và không đóng BH;
  -- phụ cấp chức vụ thì thường cả hai đều có.
  is_taxable   boolean not null default true,
  is_insurance boolean not null default false,

  ghi_chu      text,
  is_active    boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

comment on table public.allowance_types is
  'Danh mục loại phụ cấp. is_taxable và is_insurance là thuộc tính của LOẠI, không phải của từng chức danh.';

create trigger trg_allowance_types_touch
  before update on public.allowance_types
  for each row execute function public.touch_updated_at();

-- Không seed loại nào: tên và cách đối xử thuế của từng phụ cấp là chính sách
-- của doanh nghiệp, không phải thứ agent được đoán.

-- ---------------------------------------------------------
-- 2. Chức danh hưởng loại nào, mức bao nhiêu
-- ---------------------------------------------------------
create table public.position_allowances (
  id                 uuid primary key default gen_random_uuid(),
  position_id        uuid not null references public.positions (id) on delete cascade,
  allowance_type_id  uuid not null references public.allowance_types (id),
  amount             numeric(15, 2) not null check (amount >= 0),
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),

  -- Một chức danh không thể hưởng cùng một loại phụ cấp hai lần.
  constraint phu_cap_chuc_danh_duy_nhat unique (position_id, allowance_type_id)
);

comment on table public.position_allowances is
  'Mức phụ cấp MẶC ĐỊNH theo chức danh. Dòng cùng type_code trong labor_contracts.allowances sẽ ghi đè cho cá nhân đó.';

create index idx_position_allowances_chuc_danh on public.position_allowances (position_id);

create trigger trg_position_allowances_touch
  before update on public.position_allowances
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------
-- 3. RLS
--
--    Danh mục LOẠI: ai đăng nhập cũng đọc được — tên "phụ cấp ăn ca" không
--    phải bí mật, và nhân viên thấy nó trên phiếu lương của mình.
--
--    MỨC theo chức danh: chỉ HR / kế toán / admin. Biết "trưởng phòng hưởng
--    5 triệu phụ cấp chức vụ" là suy ra được một phần thu nhập của người giữ
--    chức danh đó — cùng lý do nhân viên không đọc được cfg_* ở P3.
-- ---------------------------------------------------------
alter table public.allowance_types      enable row level security;
alter table public.allowance_types      force  row level security;
alter table public.position_allowances  enable row level security;
alter table public.position_allowances  force  row level security;

create policy "allowance_types_select_authenticated"
  on public.allowance_types for select
  to authenticated
  using ((select public.current_app_role()) is not null);

create policy "allowance_types_insert_admin"
  on public.allowance_types for insert
  to authenticated
  with check ((select public.current_app_role()) = 'admin');

create policy "allowance_types_update_admin"
  on public.allowance_types for update
  to authenticated
  using ((select public.current_app_role()) = 'admin')
  with check ((select public.current_app_role()) = 'admin');

create policy "position_allowances_select_payroll"
  on public.position_allowances for select
  to authenticated
  using ((select public.can_read_payroll()));

create policy "position_allowances_insert_admin"
  on public.position_allowances for insert
  to authenticated
  with check ((select public.current_app_role()) = 'admin');

create policy "position_allowances_update_admin"
  on public.position_allowances for update
  to authenticated
  using ((select public.current_app_role()) = 'admin')
  with check ((select public.current_app_role()) = 'admin');

-- Đây là bảng DUY NHẤT trong dự án cho phép xoá cứng: gỡ một phụ cấp khỏi
-- chức danh là việc bình thường, và giữ lại dòng đã gỡ chỉ làm engine phải
-- lọc thêm. Bảng lương đã tính thì không bị ảnh hưởng vì payslips lưu
-- cfg_snapshot và các dòng payslip_items của riêng nó.
create policy "position_allowances_delete_admin"
  on public.position_allowances for delete
  to authenticated
  using ((select public.current_app_role()) = 'admin');

revoke all on public.allowance_types     from anon, authenticated;
revoke all on public.position_allowances from anon, authenticated;
grant select, insert, update on public.allowance_types to authenticated;
grant select, insert, update, delete on public.position_allowances to authenticated;
