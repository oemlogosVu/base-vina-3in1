-- =========================================================
-- Báo cáo tổng hợp lương theo khoảng thời gian
--
-- VÌ SAO CỘNG Ở SQL CHỨ KHÔNG Ở TRÌNH DUYỆT: tiền lương là `numeric` của
-- Postgres. Kéo từng phiếu về rồi cộng bằng số thực JavaScript là đúng thứ
-- AGENTS.md mục 2.2 cấm — 0.1 + 0.2 ≠ 0.3, và sai số đó nhân với vài trăm
-- dòng thì bảng tổng hợp lệch với bảng chi tiết mà không ai giải thích được.
--
-- SECURITY INVOKER (mặc định), KHÔNG phải DEFINER: nhờ vậy RLS trên payslips
-- vẫn áp nguyên. Kế toán thấy toàn công ty, nhân viên chỉ thấy phiếu của
-- mình. Báo cáo không tự mở thêm quyền cho ai.
--
-- Khoảng kỳ truyền dạng số nguyên yyyymm (ví dụ 202601) thay vì hai cặp
-- năm/tháng: so sánh một phép, và không có cách nào lọt trường hợp
-- "tháng 12/2025 tới tháng 1/2026" bị hiểu ngược.
-- =========================================================

-- ---------------------------------------------------------
-- 1. Tổng hợp THEO KỲ — mỗi dòng một tháng
-- ---------------------------------------------------------
create or replace function public.bao_cao_luong_theo_ky(
  p_company_id uuid,
  p_tu  integer,
  p_den integer
)
returns table (
  nam               integer,
  thang             integer,
  trang_thai        public.period_status,
  ngay_cong_chuan   numeric,
  so_phieu          bigint,
  tong_ngay_cong    numeric,
  tong_gross        numeric,
  bh_nguoi_lao_dong numeric,
  tong_thue         numeric,
  tong_net          numeric,
  bh_cong_ty        numeric,
  tong_chi_phi      numeric
)
language sql
stable
set search_path = ''
as $$
  select
    k.year,
    k.month,
    k.status,
    k.standard_days,
    count(p.id),
    coalesce(sum(p.worked_days), 0),
    coalesce(sum(p.gross_salary), 0),
    coalesce(sum(p.bhxh_employee + p.bhyt_employee + p.bhtn_employee), 0),
    coalesce(sum(p.pit), 0),
    coalesce(sum(p.net_salary), 0),
    coalesce(sum(p.bhxh_employer + p.bhyt_employer + p.bhtn_employer), 0),
    -- Chi phí lao động THẬT của doanh nghiệp: tổng thu nhập cộng phần công ty
    -- đóng bảo hiểm. Không phải tổng thực nhận — phần bảo hiểm và thuế người
    -- lao động chịu vẫn là tiền doanh nghiệp chi ra.
    coalesce(sum(p.gross_salary + p.bhxh_employer + p.bhyt_employer + p.bhtn_employer), 0)
  from public.payroll_periods k
  left join public.payslips p on p.period_id = k.id
  where k.company_id = p_company_id
    and (k.year * 100 + k.month) between p_tu and p_den
  group by k.year, k.month, k.status, k.standard_days
  order by k.year, k.month;
$$;

comment on function public.bao_cao_luong_theo_ky(uuid, integer, integer) is
  'Tổng hợp lương theo từng kỳ trong khoảng yyyymm. LEFT JOIN để kỳ chưa tính vẫn hiện ra với 0 phiếu.';

-- ---------------------------------------------------------
-- 2. Tổng hợp THEO NHÂN VIÊN — cộng dồn qua các kỳ trong khoảng
-- ---------------------------------------------------------
create or replace function public.bao_cao_luong_theo_nhan_vien(
  p_company_id uuid,
  p_tu  integer,
  p_den integer
)
returns table (
  employee_code     text,
  full_name         text,
  so_ky             bigint,
  tong_ngay_cong    numeric,
  tong_gross        numeric,
  bh_nguoi_lao_dong numeric,
  tong_thue         numeric,
  tong_net          numeric,
  bh_cong_ty        numeric
)
language sql
stable
set search_path = ''
as $$
  select
    -- LEFT JOIN employees, không phải INNER: hồ sơ có thể bị RLS ẩn khỏi
    -- người đang xem (hoặc đã xoá mềm). Dùng INNER thì dòng phiếu lương biến
    -- mất khỏi bảng này trong khi vẫn được đếm ở bảng theo kỳ — hai bảng
    -- lệch nhau mà không ai biết vì sao. Thà hiện "không đọc được".
    coalesce(e.employee_code, '(không đọc được)'),
    coalesce(e.full_name, '(hồ sơ ngoài quyền xem)'),
    count(p.id),
    coalesce(sum(p.worked_days), 0),
    coalesce(sum(p.gross_salary), 0),
    coalesce(sum(p.bhxh_employee + p.bhyt_employee + p.bhtn_employee), 0),
    coalesce(sum(p.pit), 0),
    coalesce(sum(p.net_salary), 0),
    coalesce(sum(p.bhxh_employer + p.bhyt_employer + p.bhtn_employer), 0)
  from public.payslips p
  join public.payroll_periods k on k.id = p.period_id
  left join public.employees e on e.id = p.employee_id
  where k.company_id = p_company_id
    and (k.year * 100 + k.month) between p_tu and p_den
  group by e.employee_code, e.full_name
  order by 1;
$$;

comment on function public.bao_cao_luong_theo_nhan_vien(uuid, integer, integer) is
  'Tổng hợp lương theo từng người trong khoảng yyyymm. LEFT JOIN employees để tổng luôn khớp với báo cáo theo kỳ.';

revoke execute on function public.bao_cao_luong_theo_ky(uuid, integer, integer) from public, anon;
revoke execute on function public.bao_cao_luong_theo_nhan_vien(uuid, integer, integer) from public, anon;
grant execute on function public.bao_cao_luong_theo_ky(uuid, integer, integer) to authenticated;
grant execute on function public.bao_cao_luong_theo_nhan_vien(uuid, integer, integer) to authenticated;
