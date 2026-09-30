-- =========================================================
-- P2c — Hai công ty, và chấm thêm giờ tường minh
--
-- Yêu cầu 12/08/2026:
--   1. Theo dõi nhân sự cho HAI công ty, chọn công ty cho từng nhân viên.
--   2. Tab chấm công thêm phần chấm thêm giờ.
--
-- Migration này chỉ dựng schema. Các hàm dùng tới giá trị enum mới nằm ở
-- migration kế tiếp: Postgres không cho dùng giá trị enum vừa thêm trong
-- cùng một giao dịch với lệnh thêm nó.
-- =========================================================

-- ---------------------------------------------------------
-- 1. Hai giá trị mới cho check_type
--
--    Chấm thêm giờ tường minh thay cho cách suy ra cũ ("ở lại quá giờ tan ca
--    thì coi là ngoài giờ"). Giữ cả hai là tính hai lần.
--
--    Đây cũng là thay đổi tốt về nghiệp vụ: ngoài giờ trở thành việc CÓ CHỦ
--    ĐÍCH, người lao động bấm nút để bắt đầu, chứ không phải hệ quả của việc
--    nán lại công ty.
-- ---------------------------------------------------------
alter type public.check_type add value if not exists 'ot_in';
alter type public.check_type add value if not exists 'ot_out';

-- ---------------------------------------------------------
-- 2. Công ty
--
--    Hai công ty là HAI PHÁP NHÂN: khác mã số thuế, khai thuế TNCN và BHXH
--    riêng, sổ sách riêng. Không phải hai phòng ban.
-- ---------------------------------------------------------
create table public.companies (
  id          uuid primary key default gen_random_uuid(),
  code        text not null unique,
  name        text not null,
  tax_code    text,
  address     text,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

comment on table public.companies is
  'Pháp nhân sử dụng lao động. Mỗi công ty có kỳ lương và bảng lương riêng — khai thuế và BHXH tách bạch.';

create trigger trg_companies_touch
  before update on public.companies
  for each row execute function public.touch_updated_at();

-- Migration KHÔNG seed công ty nào: tên và mã số thuế của công ty là dữ liệu
-- thật của doanh nghiệp, không phải thứ agent được đoán. Admin nhập ở màn
-- /quan-tri/cong-ty.

-- ---------------------------------------------------------
-- 3. Gán công ty cho nhân viên và phòng ban
--
--    Để NULL được vì lúc chạy migration chưa có công ty nào. Nhưng nhân viên
--    không có công ty sẽ KHÔNG nằm trong kỳ lương nào — tức bị bỏ sót khỏi
--    bảng lương mà không ai thấy. Engine lương xử lý bằng cách TỪ CHỐI TÍNH
--    và nêu tên họ, xem migration kế tiếp.
-- ---------------------------------------------------------
alter table public.employees
  add column company_id uuid references public.companies (id);

comment on column public.employees.company_id is
  'Pháp nhân trả lương cho nhân viên này. NULL = chưa gán; engine lương sẽ từ chối tính và nêu tên.';

create index idx_employees_cong_ty on public.employees (company_id);

alter table public.departments
  add column company_id uuid references public.companies (id);

comment on column public.departments.company_id is
  'Công ty sở hữu phòng ban. NULL = phòng ban dùng chung, chấp nhận được khi hai công ty chia sẻ bộ máy.';

-- ---------------------------------------------------------
-- 4. Kỳ lương tách theo công ty
--
--    Bắt buộc, không phải tuỳ chọn: một kỳ lương gộp hai pháp nhân là trộn
--    sổ sách của hai doanh nghiệp khác nhau. Chốt kỳ cũng là việc của từng
--    pháp nhân — công ty này chốt xong, công ty kia còn đang điều chỉnh.
--
--    Bảng đang rỗng nên đặt NOT NULL được ngay.
-- ---------------------------------------------------------
delete from public.payroll_periods;

alter table public.payroll_periods
  add column company_id uuid not null references public.companies (id);

alter table public.payroll_periods
  drop constraint ky_luong_duy_nhat;

alter table public.payroll_periods
  add constraint ky_luong_duy_nhat unique (company_id, month, year);

comment on table public.payroll_periods is
  'Kỳ lương theo tháng của MỘT công ty. Hai công ty có hai kỳ riêng cho cùng một tháng.';

-- ---------------------------------------------------------
-- 5. Bảng công ngày: ghi lại giờ bắt đầu và kết thúc làm thêm
--
--    Không chỉ lưu số phút: nhân sự cần thấy làm thêm từ mấy giờ tới mấy giờ
--    để đối chiếu, và người lao động cần thấy để phản hồi nếu sai.
-- ---------------------------------------------------------
alter table public.attendance_days
  add column ot_first_in timestamptz,
  add column ot_last_out timestamptz;

alter table public.attendance_days
  add constraint att_day_ot_thu_tu_hop_le check (
    ot_first_in is null or ot_last_out is null or ot_last_out >= ot_first_in
  );

-- ---------------------------------------------------------
-- 6. RLS cho companies
--
--    Ai đăng nhập cũng đọc được danh sách công ty: nhân viên cần biết mình
--    thuộc pháp nhân nào, và tên công ty không phải bí mật. Chỉ admin sửa.
-- ---------------------------------------------------------
alter table public.companies enable row level security;
alter table public.companies force  row level security;

create policy "companies_select_authenticated"
  on public.companies for select
  to authenticated
  using ((select public.current_app_role()) is not null);

create policy "companies_insert_admin"
  on public.companies for insert
  to authenticated
  with check ((select public.current_app_role()) = 'admin');

create policy "companies_update_admin"
  on public.companies for update
  to authenticated
  using ((select public.current_app_role()) = 'admin')
  with check ((select public.current_app_role()) = 'admin');

revoke all on public.companies from anon, authenticated;
grant select, insert, update on public.companies to authenticated;
