-- =========================================================
-- P0 — Nền tảng xác thực & phân quyền
-- Dự án: HR Base Vina
-- Phạm vi: enum vai trò, bảng app_users, hàm vai trò dùng chung, RLS.
-- KHÔNG tạo employees/departments ở đây — thuộc P1.
-- =========================================================

-- ---------------------------------------------------------
-- 1. Enum vai trò
--    Giá trị nghiệp vụ giữ tiếng Việt không dấu theo AGENTS.md mục 3.
-- ---------------------------------------------------------
create type public.user_role as enum (
  'nhan_vien',
  'truong_phong',
  'hr',
  'ke_toan',
  'admin'
);

-- ---------------------------------------------------------
-- 2. Bảng app_users — cầu nối giữa Supabase Auth và vai trò nghiệp vụ
-- ---------------------------------------------------------
create table public.app_users (
  id          uuid primary key references auth.users (id) on delete cascade,
  full_name   text not null,
  role        public.user_role not null default 'nhan_vien',
  -- Nối tới hồ sơ nhân sự. CHƯA có khoá ngoại vì bảng employees thuộc P1.
  -- P1 BẮT BUỘC thêm: alter table public.app_users
  --   add constraint fk_app_users_employee
  --   foreign key (employee_id) references public.employees (id);
  employee_id uuid,
  -- Người mới đăng ký mặc định BỊ KHOÁ. Admin phải kích hoạt tay.
  -- Không để người lạ tự tạo tài khoản rồi vào được hệ thống.
  is_active   boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

comment on table public.app_users is
  'Vai trò nghiệp vụ gắn với tài khoản Supabase Auth. Tài khoản mới mặc định is_active=false, chờ admin kích hoạt.';

create index idx_app_users_employee on public.app_users (employee_id);
create index idx_app_users_role on public.app_users (role);

-- ---------------------------------------------------------
-- 3. Hàm vai trò dùng chung
--
--    security definer + search_path rỗng là BẮT BUỘC:
--    policy trên app_users sẽ gọi hàm này, mà hàm lại đọc app_users.
--    Nếu không phải security definer, RLS áp lên chính truy vấn bên trong
--    hàm -> đệ quy vô hạn (Postgres báo "infinite recursion detected").
--    search_path = '' chặn tấn công search_path hijacking.
-- ---------------------------------------------------------
create or replace function public.current_app_role()
returns public.user_role
language sql
stable
security definer
set search_path = ''
as $$
  select u.role
  from public.app_users u
  where u.id = (select auth.uid())
    and u.is_active = true;
$$;

comment on function public.current_app_role() is
  'Vai trò của người dùng đang đăng nhập; NULL nếu chưa đăng nhập hoặc tài khoản bị khoá. Mọi policy RLS phase sau tái dùng hàm này.';

-- Nhân viên đang đăng nhập trỏ tới hồ sơ nhân sự nào.
-- P1..P4 dùng hàm này để viết policy "chỉ xem dữ liệu của mình".
create or replace function public.current_employee_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select u.employee_id
  from public.app_users u
  where u.id = (select auth.uid())
    and u.is_active = true;
$$;

comment on function public.current_employee_id() is
  'employee_id của người dùng đang đăng nhập; NULL nếu chưa gắn hồ sơ hoặc tài khoản bị khoá.';

-- Rút gọn cho các policy "HR/admin xem tất cả".
create or replace function public.is_hr_or_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.current_app_role() in ('hr', 'admin');
$$;

-- Hàm chỉ dành cho người dùng đã đăng nhập, không mở cho khách.
revoke execute on function public.current_app_role() from anon;
revoke execute on function public.current_employee_id() from anon;
revoke execute on function public.is_hr_or_admin() from anon;

-- ---------------------------------------------------------
-- 4. Trigger: tự tạo app_users khi có tài khoản Auth mới
--    Mặc định vai trò thấp nhất + is_active=false (nguyên tắc least privilege).
-- ---------------------------------------------------------
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.app_users (id, full_name, role, is_active)
  values (
    new.id,
    -- Không log/echo email ra ngoài; chỉ dùng làm tên tạm khi chưa có full_name.
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''), new.email),
    'nhan_vien',
    false
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();

-- Giữ updated_at trung thực.
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger trg_app_users_touch
  before update on public.app_users
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------
-- 5. RLS — bật NGAY trong migration tạo bảng (AGENTS.md mục 3)
-- ---------------------------------------------------------
alter table public.app_users enable row level security;
-- Chặn cả chủ sở hữu bảng đi vòng qua RLS.
alter table public.app_users force row level security;

-- Nhân viên chỉ đọc được đúng dòng của chính mình.
create policy "app_users_select_self"
  on public.app_users for select
  to authenticated
  using (id = (select auth.uid()));

-- HR và admin đọc được tất cả (ma trận phân quyền mục 4 kế hoạch DB).
create policy "app_users_select_hr_admin"
  on public.app_users for select
  to authenticated
  using (public.is_hr_or_admin());

-- Người dùng tự sửa được TÊN của mình, nhưng KHÔNG tự đổi vai trò,
-- không tự kích hoạt tài khoản, không tự gắn mình vào hồ sơ nhân sự khác.
create policy "app_users_update_self_name"
  on public.app_users for update
  to authenticated
  using (id = (select auth.uid()))
  with check (
    id = (select auth.uid())
    and role = (select u.role from public.app_users u where u.id = (select auth.uid()))
    and is_active = (select u.is_active from public.app_users u where u.id = (select auth.uid()))
    and employee_id is not distinct from
        (select u.employee_id from public.app_users u where u.id = (select auth.uid()))
  );

-- Chỉ admin được cấp/đổi vai trò và kích hoạt tài khoản.
create policy "app_users_update_admin"
  on public.app_users for update
  to authenticated
  using (public.current_app_role() = 'admin')
  with check (public.current_app_role() = 'admin');

create policy "app_users_insert_admin"
  on public.app_users for insert
  to authenticated
  with check (public.current_app_role() = 'admin');

-- CỐ Ý không có policy DELETE.
-- Không xoá cứng dữ liệu nhân sự (AGENTS.md mục 3) — vô hiệu hoá bằng is_active.

-- ---------------------------------------------------------
-- 6. Quyền bảng: khách (anon) không chạm được vào app_users.
-- ---------------------------------------------------------
revoke all on public.app_users from anon;
grant select, insert, update on public.app_users to authenticated;
