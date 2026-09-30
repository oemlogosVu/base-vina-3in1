-- =========================================================
-- P1 — Hồ sơ nhân sự
-- Dự án: HR Base Vina
--
-- Phạm vi: tổ chức (departments, positions), hồ sơ nhân sự (employees,
-- employee_sensitive, dependents, labor_contracts, employee_documents),
-- hàm nền current_department_id(), RLS cho toàn bộ.
--
-- KHÔNG thuộc migration này: Storage bucket + upload giấy tờ (P1b),
-- chấm công (P2), bảng cfg_* và tính lương (P3), đơn nghỉ phép (P4).
-- =========================================================

-- ---------------------------------------------------------
-- 1. Enum nghiệp vụ
--    Giá trị tiếng Việt không dấu theo AGENTS.md mục 3.
-- ---------------------------------------------------------
create type public.employee_status as enum (
  'thu_viec',
  'chinh_thuc',
  'nghi_viec',
  'tam_hoan'
);

create type public.contract_type as enum (
  'thu_viec',
  'xac_dinh_thoi_han',
  'khong_xac_dinh',
  'thoi_vu'
);

-- ---------------------------------------------------------
-- 2. Tổ chức
-- ---------------------------------------------------------
create table public.departments (
  id         uuid primary key default gen_random_uuid(),
  code       text not null unique,
  name       text not null,
  parent_id  uuid references public.departments (id),
  -- Trưởng phòng. Khoá ngoại tới employees thêm ở mục 4 (bảng chưa tồn tại).
  manager_id uuid,
  is_active  boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- Phòng ban không được là cha của chính nó.
  constraint departments_parent_khac_chinh_no check (parent_id is null or parent_id <> id)
);

comment on table public.departments is
  'Phòng ban, tự tham chiếu để có cây phân cấp. Không xoá cứng — dùng is_active.';

create index idx_departments_parent on public.departments (parent_id);

create table public.positions (
  id         uuid primary key default gen_random_uuid(),
  code       text not null unique,
  name       text not null,
  is_active  boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.positions is 'Chức danh. Không xoá cứng — dùng is_active.';

-- ---------------------------------------------------------
-- 3. Hồ sơ nhân sự — phần KHÔNG nhạy cảm
--
--    Các trường nhạy cảm (CCCD, tài khoản ngân hàng, MST, số sổ BHXH)
--    CỐ Ý không nằm ở đây. Xem mục 3b và ghi chú thiết kế bên dưới.
-- ---------------------------------------------------------
create table public.employees (
  id                uuid primary key default gen_random_uuid(),
  employee_code     text not null unique,
  full_name         text not null,
  dob               date,
  gender            text check (gender in ('nam', 'nu', 'khac')),
  permanent_address text,
  phone             text,
  personal_email    text,
  department_id     uuid references public.departments (id),
  position_id       uuid references public.positions (id),
  manager_id        uuid references public.employees (id),
  -- Vùng lương tối thiểu (NĐ về lương tối thiểu vùng). Dùng từ P3.
  region            smallint check (region between 1 and 4),
  hire_date         date,
  status            public.employee_status not null default 'thu_viec',
  avatar_url        text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  constraint employees_manager_khac_chinh_no check (manager_id is null or manager_id <> id)
);

comment on table public.employees is
  'Hồ sơ nhân sự — phần không nhạy cảm. Trưởng phòng đọc được hàng của phòng mình. Không xoá cứng: nghỉ việc đổi status.';

create index idx_employees_department on public.employees (department_id);
create index idx_employees_manager on public.employees (manager_id);
create index idx_employees_status on public.employees (status);

-- ---------------------------------------------------------
-- 3b. Hồ sơ nhân sự — phần NHẠY CẢM, tách bảng riêng
--
--     VÌ SAO TÁCH BẢNG thay vì để chung rồi thu hồi quyền cột:
--     Postgres KHÔNG có RLS cấp cột, và `grant/revoke` cấp cột áp lên role
--     của database. Nhưng trưởng phòng, HR, kế toán, nhân viên đều đăng nhập
--     dưới CÙNG một role `authenticated` — vai trò nghiệp vụ chỉ là giá trị
--     trong app_users.role. Nên không có cách nào thu hồi cột theo vai trò
--     nghiệp vụ. Tách bảng biến bài toán cột thành bài toán hàng, và RLS
--     giải được bài toán hàng.
--
--     Hệ quả cần biết: mọi truy vấn cần CCCD/số tài khoản phải join sang đây,
--     và trưởng phòng join sẽ ra rỗng — đó là hành vi mong muốn, không phải lỗi.
-- ---------------------------------------------------------
create table public.employee_sensitive (
  employee_id         uuid primary key references public.employees (id) on delete cascade,
  cccd                text,
  cccd_issue_date     date,
  cccd_issue_place    text,
  bank_account_no     text,
  bank_name           text,
  tax_code            text,               -- MST thuế TNCN
  social_insurance_no text,               -- số sổ BHXH
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

comment on table public.employee_sensitive is
  'Trường nhạy cảm của hồ sơ (CCCD, ngân hàng, MST, sổ BHXH). Chỉ chính chủ, HR, kế toán và admin đọc được — trưởng phòng KHÔNG. Tách bảng vì Postgres không có RLS cấp cột.';

-- ---------------------------------------------------------
-- 3c. Người phụ thuộc — đầu vào giảm trừ gia cảnh thuế TNCN (dùng từ P3)
-- ---------------------------------------------------------
create table public.dependents (
  id           uuid primary key default gen_random_uuid(),
  employee_id  uuid not null references public.employees (id) on delete cascade,
  full_name    text not null,
  relationship text,                      -- con, cha, me ...
  tax_code     text,
  -- Kỳ được tính giảm trừ. reg_to null = còn hiệu lực.
  reg_from     date,
  reg_to       date,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint dependents_ky_hop_le check (reg_to is null or reg_from is null or reg_to >= reg_from)
);

comment on table public.dependents is
  'Người phụ thuộc để tính giảm trừ gia cảnh. Số tiền giảm trừ KHÔNG nằm ở đây — đọc từ cfg_pit_deductions theo ngày hiệu lực (P3).';

create index idx_dependents_employee on public.dependents (employee_id);

-- ---------------------------------------------------------
-- 3d. Hợp đồng lao động — chứa lương, nhạy cảm ngang bảng lương
-- ---------------------------------------------------------
create table public.labor_contracts (
  id              uuid primary key default gen_random_uuid(),
  employee_id     uuid not null references public.employees (id) on delete cascade,
  contract_no     text not null unique,
  type            public.contract_type not null,
  start_date      date not null,
  end_date        date,
  -- Tiền: numeric, KHÔNG dùng float (AGENTS.md mục 3).
  bhxh_salary     numeric(15, 2) not null check (bhxh_salary >= 0),
  position_salary numeric(15, 2) not null default 0 check (position_salary >= 0),
  -- [{name, amount, taxable, insurance}] — engine lương P3 đọc mảng này.
  allowances      jsonb not null default '[]'::jsonb,
  is_active       boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint labor_contracts_ky_hop_le check (end_date is null or end_date >= start_date)
);

comment on table public.labor_contracts is
  'Hợp đồng lao động. Chứa lương nên trưởng phòng KHÔNG truy cập được. Kế toán chỉ đọc.';

create index idx_labor_contracts_employee on public.labor_contracts (employee_id);

-- Mỗi nhân viên chỉ có tối đa MỘT hợp đồng đang hiệu lực. Chặn ở DB chứ không
-- chỉ ở UI: engine lương P3 sẽ chọn hợp đồng theo cờ này, hai dòng active là
-- tính sai tiền thật.
create unique index uniq_hop_dong_dang_hieu_luc
  on public.labor_contracts (employee_id)
  where is_active;

-- ---------------------------------------------------------
-- 3e. Giấy tờ đính kèm — P1 chỉ tạo bảng + RLS.
--     Storage bucket private, signed URL và màn upload thuộc P1b.
-- ---------------------------------------------------------
create table public.employee_documents (
  id          uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.employees (id) on delete cascade,
  doc_type    text not null,              -- cccd / hop_dong / bang_cap ...
  file_path   text not null,              -- đường dẫn trong Storage (bucket private)
  note        text,
  uploaded_at timestamptz not null default now()
);

comment on table public.employee_documents is
  'Giấy tờ nhân sự lưu ở Storage private. P1 mới tạo bảng; bucket và luồng upload/signed URL làm ở P1b.';

create index idx_employee_documents_employee on public.employee_documents (employee_id);

-- ---------------------------------------------------------
-- 4. Trả nợ kỹ thuật của P0 — khoá ngoại giờ mới đặt được
-- ---------------------------------------------------------
alter table public.app_users
  add constraint fk_app_users_employee
  foreign key (employee_id) references public.employees (id);

alter table public.departments
  add constraint fk_departments_manager
  foreign key (manager_id) references public.employees (id);

-- ---------------------------------------------------------
-- 5. Hàm nền thứ tư — phòng ban của người đang đăng nhập
--
--    security definer + search_path rỗng, cùng chuẩn với ba hàm P0:
--    hàm này đọc employees, mà policy trên employees lại gọi chính nó.
--    Thiếu security definer là đệ quy vô hạn.
-- ---------------------------------------------------------
create or replace function public.current_department_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select e.department_id
  from public.employees e
  where e.id = public.current_employee_id();
$$;

comment on function public.current_department_id() is
  'department_id của người dùng đang đăng nhập; NULL nếu chưa gắn hồ sơ. Policy trưởng phòng dùng hàm này.';

revoke execute on function public.current_department_id() from anon;

-- Rút gọn cho các policy "được xem toàn bộ hồ sơ nhân sự".
-- Kế toán CHỈ ĐỌC — quyền ghi kiểm bằng is_hr_or_admin() riêng.
create or replace function public.can_read_all_employees()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.current_app_role() in ('hr', 'ke_toan', 'admin');
$$;

revoke execute on function public.can_read_all_employees() from anon;

-- ---------------------------------------------------------
-- 6. Trigger updated_at — tái dùng hàm touch_updated_at() của P0
-- ---------------------------------------------------------
create trigger trg_departments_touch
  before update on public.departments
  for each row execute function public.touch_updated_at();

create trigger trg_positions_touch
  before update on public.positions
  for each row execute function public.touch_updated_at();

create trigger trg_employees_touch
  before update on public.employees
  for each row execute function public.touch_updated_at();

create trigger trg_employee_sensitive_touch
  before update on public.employee_sensitive
  for each row execute function public.touch_updated_at();

create trigger trg_dependents_touch
  before update on public.dependents
  for each row execute function public.touch_updated_at();

create trigger trg_labor_contracts_touch
  before update on public.labor_contracts
  for each row execute function public.touch_updated_at();

-- =========================================================
-- 7. RLS — bật NGAY trong migration tạo bảng (AGENTS.md mục 3)
--
--    Ma trận đã duyệt:
--    | bảng               | nhân viên      | trưởng phòng     | HR      | kế toán | admin |
--    | employees          | mình, chỉ đọc  | phòng trực tiếp, | đọc+ghi | đọc     | đọc+ghi
--    |                    |                | chỉ đọc          |         |         |
--    | employee_sensitive | mình, chỉ đọc  | KHÔNG            | đọc+ghi | đọc     | đọc+ghi
--    | dependents         | mình, chỉ đọc  | KHÔNG            | đọc+ghi | đọc     | đọc+ghi
--    | labor_contracts    | mình, chỉ đọc  | KHÔNG            | đọc+ghi | đọc     | đọc+ghi
--    | employee_documents | mình, chỉ đọc  | KHÔNG            | đọc+ghi | KHÔNG   | đọc+ghi
--    | departments        | chỉ đọc        | chỉ đọc          | chỉ đọc | chỉ đọc | đọc+ghi
--    | positions          | chỉ đọc        | chỉ đọc          | chỉ đọc | chỉ đọc | đọc+ghi
--
--    Nhân viên CHỈ XEM, không sửa được hồ sơ mình (quyết định của người phụ
--    trách 09/08/2026) — nên không bảng nào có policy UPDATE cho nhan_vien.
--    Không bảng nào có policy DELETE — không xoá cứng dữ liệu nhân sự.
-- =========================================================

alter table public.departments        enable row level security;
alter table public.departments        force  row level security;
alter table public.positions          enable row level security;
alter table public.positions          force  row level security;
alter table public.employees          enable row level security;
alter table public.employees          force  row level security;
alter table public.employee_sensitive enable row level security;
alter table public.employee_sensitive force  row level security;
alter table public.dependents         enable row level security;
alter table public.dependents         force  row level security;
alter table public.labor_contracts    enable row level security;
alter table public.labor_contracts    force  row level security;
alter table public.employee_documents enable row level security;
alter table public.employee_documents force  row level security;

-- ---- departments: ai đăng nhập cũng đọc được, chỉ admin sửa ----
create policy "departments_select_authenticated"
  on public.departments for select
  to authenticated
  using ((select public.current_app_role()) is not null);

create policy "departments_insert_admin"
  on public.departments for insert
  to authenticated
  with check ((select public.current_app_role()) = 'admin');

create policy "departments_update_admin"
  on public.departments for update
  to authenticated
  using ((select public.current_app_role()) = 'admin')
  with check ((select public.current_app_role()) = 'admin');

-- ---- positions ----
create policy "positions_select_authenticated"
  on public.positions for select
  to authenticated
  using ((select public.current_app_role()) is not null);

create policy "positions_insert_admin"
  on public.positions for insert
  to authenticated
  with check ((select public.current_app_role()) = 'admin');

create policy "positions_update_admin"
  on public.positions for update
  to authenticated
  using ((select public.current_app_role()) = 'admin')
  with check ((select public.current_app_role()) = 'admin');

-- ---- employees ----
create policy "employees_select_self"
  on public.employees for select
  to authenticated
  using (id = (select public.current_employee_id()));

-- Trưởng phòng: CHỈ phòng trực tiếp, không đệ quy xuống phòng con
-- (quyết định của người phụ trách 09/08/2026). Nếu current_department_id()
-- trả NULL thì phép so sánh ra NULL -> policy từ chối, đúng ý.
create policy "employees_select_truong_phong"
  on public.employees for select
  to authenticated
  using (
    (select public.current_app_role()) = 'truong_phong'
    and department_id = (select public.current_department_id())
  );

create policy "employees_select_hr_ketoan_admin"
  on public.employees for select
  to authenticated
  using ((select public.can_read_all_employees()));

create policy "employees_insert_hr_admin"
  on public.employees for insert
  to authenticated
  with check ((select public.is_hr_or_admin()));

create policy "employees_update_hr_admin"
  on public.employees for update
  to authenticated
  using ((select public.is_hr_or_admin()))
  with check ((select public.is_hr_or_admin()));

-- ---- employee_sensitive: CỐ Ý không có policy nào cho trưởng phòng ----
create policy "employee_sensitive_select_self"
  on public.employee_sensitive for select
  to authenticated
  using (employee_id = (select public.current_employee_id()));

create policy "employee_sensitive_select_hr_ketoan_admin"
  on public.employee_sensitive for select
  to authenticated
  using ((select public.can_read_all_employees()));

create policy "employee_sensitive_insert_hr_admin"
  on public.employee_sensitive for insert
  to authenticated
  with check ((select public.is_hr_or_admin()));

create policy "employee_sensitive_update_hr_admin"
  on public.employee_sensitive for update
  to authenticated
  using ((select public.is_hr_or_admin()))
  with check ((select public.is_hr_or_admin()));

-- ---- dependents ----
create policy "dependents_select_self"
  on public.dependents for select
  to authenticated
  using (employee_id = (select public.current_employee_id()));

create policy "dependents_select_hr_ketoan_admin"
  on public.dependents for select
  to authenticated
  using ((select public.can_read_all_employees()));

create policy "dependents_insert_hr_admin"
  on public.dependents for insert
  to authenticated
  with check ((select public.is_hr_or_admin()));

create policy "dependents_update_hr_admin"
  on public.dependents for update
  to authenticated
  using ((select public.is_hr_or_admin()))
  with check ((select public.is_hr_or_admin()));

-- ---- labor_contracts ----
create policy "labor_contracts_select_self"
  on public.labor_contracts for select
  to authenticated
  using (employee_id = (select public.current_employee_id()));

create policy "labor_contracts_select_hr_ketoan_admin"
  on public.labor_contracts for select
  to authenticated
  using ((select public.can_read_all_employees()));

create policy "labor_contracts_insert_hr_admin"
  on public.labor_contracts for insert
  to authenticated
  with check ((select public.is_hr_or_admin()));

create policy "labor_contracts_update_hr_admin"
  on public.labor_contracts for update
  to authenticated
  using ((select public.is_hr_or_admin()))
  with check ((select public.is_hr_or_admin()));

-- ---- employee_documents: kế toán KHÔNG đọc (giấy tờ có bản chụp CCCD) ----
create policy "employee_documents_select_self"
  on public.employee_documents for select
  to authenticated
  using (employee_id = (select public.current_employee_id()));

create policy "employee_documents_select_hr_admin"
  on public.employee_documents for select
  to authenticated
  using ((select public.is_hr_or_admin()));

create policy "employee_documents_insert_hr_admin"
  on public.employee_documents for insert
  to authenticated
  with check ((select public.is_hr_or_admin()));

create policy "employee_documents_update_hr_admin"
  on public.employee_documents for update
  to authenticated
  using ((select public.is_hr_or_admin()))
  with check ((select public.is_hr_or_admin()));

-- ---------------------------------------------------------
-- 8. Quyền bảng — khách (anon) không chạm được vào bảng nào.
--    Không cấp DELETE cho ai: hai lớp chặn (không grant + không policy).
-- ---------------------------------------------------------
revoke all on public.departments        from anon;
revoke all on public.positions          from anon;
revoke all on public.employees          from anon;
revoke all on public.employee_sensitive from anon;
revoke all on public.dependents         from anon;
revoke all on public.labor_contracts    from anon;
revoke all on public.employee_documents from anon;

grant select, insert, update on public.departments        to authenticated;
grant select, insert, update on public.positions          to authenticated;
grant select, insert, update on public.employees          to authenticated;
grant select, insert, update on public.employee_sensitive to authenticated;
grant select, insert, update on public.dependents         to authenticated;
grant select, insert, update on public.labor_contracts    to authenticated;
grant select, insert, update on public.employee_documents to authenticated;
