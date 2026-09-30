-- =========================================================
-- P3 — Tính lương: tham số có ngày hiệu lực, kỳ lương, phiếu lương
--
-- Kế hoạch: docs/P3-KE-HOACH.md
--
-- Migration này KHÔNG seed một tham số pháp lý nào. Bảng cfg_* để rỗng có
-- chủ ý: hai tài liệu của dự án đang mâu thuẫn về biểu thuế TNCN (7 bậc theo
-- kế hoạch database, 5 bậc theo Luật 109/2025 trong hồ sơ của người phụ
-- trách). Seed sai biểu thuế là tính sai tiền thật của nhân viên thật, và sai
-- theo hướng khó phát hiện — con số vẫn ra, vẫn trông hợp lý, chỉ là sai.
--
-- Engine được thiết kế KHÔNG phụ thuộc số bậc, nên phần còn lại của P3 vẫn
-- làm và kiểm được ngay. Xem migration kế tiếp.
-- =========================================================

create type public.period_status as enum ('mo', 'da_chot', 'da_tra');

comment on type public.period_status is
  'Trạng thái kỳ lương. mo -> da_chot -> da_tra, một chiều. Kỳ đã chốt thì phiếu lương bất biến.';

-- =========================================================
-- 1. Tham số có ngày hiệu lực
--
--    Chỉ có effective_from, KHÔNG có effective_to. Engine chọn dòng có
--    effective_from lớn nhất mà <= ngày cuối kỳ lương. Hai cột ngày là hai
--    chỗ phải giữ cho khớp nhau, và khi lệch thì sinh ra khoảng trống không
--    ai để ý — kỳ lương rơi vào khoảng đó sẽ không tìm thấy tham số nào.
-- =========================================================

create table public.cfg_insurance_rates (
  id                 uuid primary key default gen_random_uuid(),
  effective_from     date not null unique,
  bhxh_employee_pct  numeric(5, 2) not null,
  bhxh_employer_pct  numeric(5, 2) not null,
  bhyt_employee_pct  numeric(5, 2) not null,
  bhyt_employer_pct  numeric(5, 2) not null,
  bhtn_employee_pct  numeric(5, 2) not null,
  bhtn_employer_pct  numeric(5, 2) not null,
  -- Trần đóng BHXH/BHYT = bội số lương cơ sở; trần BHTN = bội số lương tối
  -- thiểu vùng. Hai trần khác gốc nhau, đừng gộp.
  bhxh_cap_multiple  numeric(6, 2) not null,
  bhtn_cap_multiple  numeric(6, 2) not null,
  ghi_chu            text,
  created_at         timestamptz not null default now(),

  constraint bh_ty_le_hop_le check (
    bhxh_employee_pct between 0 and 100 and bhxh_employer_pct between 0 and 100 and
    bhyt_employee_pct between 0 and 100 and bhyt_employer_pct between 0 and 100 and
    bhtn_employee_pct between 0 and 100 and bhtn_employer_pct between 0 and 100
  ),
  constraint bh_tran_duong check (bhxh_cap_multiple > 0 and bhtn_cap_multiple > 0)
);

-- CỐ Ý KHÔNG có ràng buộc `level between 1 and 7`.
--
-- Kế hoạch database ghi 1..7, hồ sơ người phụ trách ghi 5 bậc theo Luật
-- 109/2025. Chưa chốt được thì schema không được khoá cứng số bậc — khoá vào
-- rồi mà luật khác đi là phải sửa migration đã chạy trên production.
create table public.cfg_pit_brackets (
  id             uuid primary key default gen_random_uuid(),
  effective_from date not null,
  level          smallint not null,
  from_amount    numeric(15, 2) not null,
  -- NULL = "trở lên", tức bậc cuối cùng.
  to_amount      numeric(15, 2),
  rate           numeric(5, 2) not null,
  created_at     timestamptz not null default now(),

  constraint pit_bac_duy_nhat unique (effective_from, level),
  constraint pit_bac_duong    check (level >= 1),
  constraint pit_nguong_hop_le check (from_amount >= 0 and (to_amount is null or to_amount > from_amount)),
  constraint pit_thue_suat_hop_le check (rate between 0 and 100)
);

comment on table public.cfg_pit_brackets is
  'Biểu thuế TNCN luỹ tiến. KHÔNG ràng buộc số bậc — engine cộng qua bao nhiêu dòng cũng được.';

create table public.cfg_pit_deductions (
  id               uuid primary key default gen_random_uuid(),
  effective_from   date not null unique,
  personal_amount  numeric(15, 2) not null check (personal_amount >= 0),
  dependent_amount numeric(15, 2) not null check (dependent_amount >= 0),
  created_at       timestamptz not null default now()
);

create table public.cfg_region_min_wage (
  id             uuid primary key default gen_random_uuid(),
  effective_from date not null,
  region         smallint not null check (region between 1 and 4),
  amount         numeric(15, 2) not null check (amount > 0),
  created_at     timestamptz not null default now(),

  constraint min_wage_duy_nhat unique (effective_from, region)
);

create table public.cfg_base_salary (
  id             uuid primary key default gen_random_uuid(),
  effective_from date not null unique,
  amount         numeric(15, 2) not null check (amount > 0),
  created_at     timestamptz not null default now()
);

-- =========================================================
-- 2. Kỳ lương
-- =========================================================
create table public.payroll_periods (
  id         uuid primary key default gen_random_uuid(),
  month      smallint not null check (month between 1 and 12),
  year       smallint not null check (year between 2020 and 2100),
  status     public.period_status not null default 'mo',
  -- Ngày công chuẩn của kỳ. Kế toán đặt theo lịch làm việc thật của tháng,
  -- không suy ra từ số ngày trong tháng — tháng có lễ thì khác.
  standard_days numeric(5, 2) not null check (standard_days > 0),
  closed_at  timestamptz,
  closed_by  uuid references public.app_users (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint ky_luong_duy_nhat unique (month, year),
  constraint ky_dong_du_doi check (
    (status = 'mo' and closed_at is null and closed_by is null)
    or (status <> 'mo' and closed_at is not null)
  )
);

comment on table public.payroll_periods is
  'Kỳ lương theo tháng. Chỉ tính lại được khi status = mo. Đóng kỳ là hành động một chiều.';

-- =========================================================
-- 3. Phiếu lương
-- =========================================================
create table public.payslips (
  id                  uuid primary key default gen_random_uuid(),
  period_id           uuid not null references public.payroll_periods (id) on delete cascade,
  employee_id         uuid not null references public.employees (id),

  worked_days         numeric(5, 2) not null default 0,
  gross_salary        numeric(15, 2) not null default 0,

  bhxh_employee       numeric(15, 2) not null default 0,
  bhyt_employee       numeric(15, 2) not null default 0,
  bhtn_employee       numeric(15, 2) not null default 0,
  bhxh_employer       numeric(15, 2) not null default 0,
  bhyt_employer       numeric(15, 2) not null default 0,
  bhtn_employer       numeric(15, 2) not null default 0,

  taxable_income      numeric(15, 2) not null default 0,
  personal_deduction  numeric(15, 2) not null default 0,
  dependent_deduction numeric(15, 2) not null default 0,
  assessable_income   numeric(15, 2) not null default 0,
  pit                 numeric(15, 2) not null default 0,
  net_salary          numeric(15, 2) not null default 0,

  -- Bộ tham số đã dùng, chụp lại tại thời điểm tính.
  --
  -- Không có nó thì sang năm, khi luật đổi và cfg_* có dòng mới, không ai
  -- dựng lại được vì sao phiếu lương tháng này ra con số đó. Bảng lương là
  -- chứng từ — phải giải thích được sau nhiều năm, kể cả khi người tính đã
  -- nghỉ việc.
  cfg_snapshot        jsonb not null default '{}'::jsonb,

  tinh_luc            timestamptz,
  tinh_boi            uuid references public.app_users (id),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),

  constraint phieu_luong_duy_nhat unique (period_id, employee_id),
  -- Thuế không bao giờ âm. Người thu nhập thấp không được "hoàn thuế" qua
  -- bảng lương.
  constraint phieu_thue_khong_am check (pit >= 0),
  constraint phieu_so_tien_khong_am check (
    gross_salary >= 0 and net_salary >= 0 and worked_days >= 0
    and bhxh_employee >= 0 and bhyt_employee >= 0 and bhtn_employee >= 0
    and bhxh_employer >= 0 and bhyt_employer >= 0 and bhtn_employer >= 0
  )
);

create index idx_payslips_ky on public.payslips (period_id);
create index idx_payslips_nhan_vien on public.payslips (employee_id, period_id);

create table public.payslip_items (
  id           uuid primary key default gen_random_uuid(),
  payslip_id   uuid not null references public.payslips (id) on delete cascade,
  item_type    text not null check (item_type in ('phu_cap', 'thuong', 'khau_tru')),
  name         text not null,
  amount       numeric(15, 2) not null,
  -- Phụ cấp có loại chịu thuế có loại không (ăn trưa, điện thoại, công tác
  -- phí trong định mức). Cờ này quyết định nó có vào thu nhập chịu thuế không.
  is_taxable   boolean not null default true,
  -- Có tính vào lương đóng bảo hiểm không. Khác với chịu thuế, đừng gộp.
  is_insurance boolean not null default false,
  created_at   timestamptz not null default now()
);

create index idx_payslip_items_phieu on public.payslip_items (payslip_id);

-- =========================================================
-- 4. Trigger updated_at
-- =========================================================
create trigger trg_payroll_periods_touch
  before update on public.payroll_periods
  for each row execute function public.touch_updated_at();

create trigger trg_payslips_touch
  before update on public.payslips
  for each row execute function public.touch_updated_at();

-- =========================================================
-- 5. Hàm nền
-- =========================================================

-- Ai đọc được dữ liệu lương của cả công ty.
-- TRƯỞNG PHÒNG KHÔNG có mặt ở đây — nhất quán với P1, nơi TP đã không xem
-- được lương hợp đồng của cấp dưới. Lương là thông tin nhạy cảm nhất trong
-- hệ thống này.
create or replace function public.can_read_payroll()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.current_app_role() in ('hr', 'ke_toan', 'admin');
$$;

revoke execute on function public.can_read_payroll() from anon;

-- Ai được tạo kỳ lương, bấm tính, và chốt kỳ. HR không — HR làm hồ sơ và
-- chấm công, kế toán làm tiền.
create or replace function public.can_manage_payroll()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.current_app_role() in ('ke_toan', 'admin');
$$;

revoke execute on function public.can_manage_payroll() from anon;

-- =========================================================
-- 6. RLS
--
--    | Bảng             | NV          | TP     | HR   | KT      | Admin
--    |------------------|-------------|--------|------|---------|--------
--    | cfg_*            | KHÔNG       | KHÔNG  | đọc  | đọc     | đọc+ghi
--    | payroll_periods  | đọc         | đọc    | đọc  | đọc+ghi | đọc+ghi
--    | payslips         | CỦA MÌNH    | KHÔNG  | đọc  | đọc+ghi | đọc+ghi
--    | payslip_items    | của mình    | KHÔNG  | đọc  | đọc+ghi | đọc+ghi
--
--    Nhân viên không đọc được cfg_*: biết trần đóng BHXH không giúp gì cho
--    công việc của họ, mà để lộ thì thành cơ sở suy ra lương người khác.
-- =========================================================

alter table public.cfg_insurance_rates  enable row level security;
alter table public.cfg_insurance_rates  force  row level security;
alter table public.cfg_pit_brackets     enable row level security;
alter table public.cfg_pit_brackets     force  row level security;
alter table public.cfg_pit_deductions   enable row level security;
alter table public.cfg_pit_deductions   force  row level security;
alter table public.cfg_region_min_wage  enable row level security;
alter table public.cfg_region_min_wage  force  row level security;
alter table public.cfg_base_salary      enable row level security;
alter table public.cfg_base_salary      force  row level security;
alter table public.payroll_periods      enable row level security;
alter table public.payroll_periods      force  row level security;
alter table public.payslips             enable row level security;
alter table public.payslips             force  row level security;
alter table public.payslip_items        enable row level security;
alter table public.payslip_items        force  row level security;

-- ---- cfg_*: HR/kế toán đọc, chỉ admin sửa ----
do $$
declare
  ten_bang text;
begin
  foreach ten_bang in array array[
    'cfg_insurance_rates', 'cfg_pit_brackets', 'cfg_pit_deductions',
    'cfg_region_min_wage', 'cfg_base_salary'
  ]
  loop
    execute format($p$
      create policy "%1$s_select_hr_ketoan_admin" on public.%1$I for select
        to authenticated using ((select public.can_read_payroll()));
      create policy "%1$s_insert_admin" on public.%1$I for insert
        to authenticated with check ((select public.current_app_role()) = 'admin');
      create policy "%1$s_update_admin" on public.%1$I for update
        to authenticated using ((select public.current_app_role()) = 'admin')
        with check ((select public.current_app_role()) = 'admin');
    $p$, ten_bang);
  end loop;
end $$;

-- ---- payroll_periods: ai đăng nhập cũng đọc được, kế toán/admin quản lý ----
-- Nhân viên đọc được để biết kỳ nào đã chốt, khỏi hỏi kế toán.
create policy "payroll_periods_select_authenticated"
  on public.payroll_periods for select
  to authenticated
  using ((select public.current_app_role()) is not null);

create policy "payroll_periods_insert_ketoan_admin"
  on public.payroll_periods for insert
  to authenticated
  with check ((select public.can_manage_payroll()));

create policy "payroll_periods_update_ketoan_admin"
  on public.payroll_periods for update
  to authenticated
  using ((select public.can_manage_payroll()))
  with check ((select public.can_manage_payroll()));

-- ---- payslips ----
create policy "payslips_select_self"
  on public.payslips for select
  to authenticated
  using (employee_id = (select public.current_employee_id()));

create policy "payslips_select_hr_ketoan_admin"
  on public.payslips for select
  to authenticated
  using ((select public.can_read_payroll()));

create policy "payslips_insert_ketoan_admin"
  on public.payslips for insert
  to authenticated
  with check ((select public.can_manage_payroll()));

-- Chỉ sửa được phiếu của kỳ ĐANG MỞ. Kỳ đã chốt thì phiếu lương là chứng từ
-- đã phát hành — muốn sửa phải mở kỳ mới điều chỉnh, không sửa lịch sử.
create policy "payslips_update_ketoan_admin_ky_mo"
  on public.payslips for update
  to authenticated
  using (
    (select public.can_manage_payroll())
    and exists (
      select 1 from public.payroll_periods p
      where p.id = period_id and p.status = 'mo'
    )
  )
  with check (
    (select public.can_manage_payroll())
    and exists (
      select 1 from public.payroll_periods p
      where p.id = period_id and p.status = 'mo'
    )
  );

-- ---- payslip_items ----
create policy "payslip_items_select_self"
  on public.payslip_items for select
  to authenticated
  using (
    exists (
      select 1 from public.payslips ps
      where ps.id = payslip_id
        and ps.employee_id = (select public.current_employee_id())
    )
  );

create policy "payslip_items_select_hr_ketoan_admin"
  on public.payslip_items for select
  to authenticated
  using ((select public.can_read_payroll()));

create policy "payslip_items_insert_ketoan_admin"
  on public.payslip_items for insert
  to authenticated
  with check ((select public.can_manage_payroll()));

create policy "payslip_items_update_ketoan_admin"
  on public.payslip_items for update
  to authenticated
  using ((select public.can_manage_payroll()))
  with check ((select public.can_manage_payroll()));

-- =========================================================
-- 7. Quyền bảng
--
--    Từ migration 20260810000003, bảng mới KHÔNG tự động nhận quyền nào.
--    Mọi thứ dưới đây phải khai báo tường minh — đó là ý đồ.
-- =========================================================
do $$
declare
  ten_bang text;
begin
  foreach ten_bang in array array[
    'cfg_insurance_rates', 'cfg_pit_brackets', 'cfg_pit_deductions',
    'cfg_region_min_wage', 'cfg_base_salary',
    'payroll_periods', 'payslips', 'payslip_items'
  ]
  loop
    execute format('revoke all on public.%I from anon, authenticated', ten_bang);
    execute format('grant select, insert, update on public.%I to authenticated', ten_bang);
  end loop;
end $$;
