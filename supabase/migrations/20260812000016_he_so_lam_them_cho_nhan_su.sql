-- =========================================================
-- Cho nhân sự đọc HỆ SỐ làm thêm giờ (chỉ ba con số, không cả bảng)
--
-- Màn xác nhận chấm công là của HR và admin. Từ 12/08/2026 màn đó có ô đặt
-- tỷ lệ % làm thêm riêng cho từng ngày, và ô đó cần hiện hệ số MẶC ĐỊNH làm
-- gợi ý — không biết mình đang đè lên con số nào thì đặt tỷ lệ là đoán mò.
--
-- Nhưng `cfg_overtime_rates` nằm sau `can_read_payroll()`, tức chỉ kế toán và
-- admin. HR không đọc được.
--
-- Mở đúng ba con số qua hàm này thay vì nới policy của cả bảng: hệ số làm
-- thêm là CHÍNH SÁCH (150%, 200%, 300%), không phải thu nhập của ai. Còn
-- những cột khác trong nhóm cfg_* — biểu thuế, trần bảo hiểm, lương cơ sở —
-- vẫn đóng nguyên với HR.
-- =========================================================

create or replace function public.he_so_lam_them_hieu_luc(p_ngay date)
returns table (
  ngay_thuong_pct    numeric,
  ngay_nghi_tuan_pct numeric,
  ngay_le_pct        numeric
)
language sql
stable
security definer
set search_path = ''
as $$
  select o.ngay_thuong_pct, o.ngay_nghi_tuan_pct, o.ngay_le_pct
  from public.cfg_overtime_rates o
  where o.effective_from <= p_ngay
    -- Vẫn phải là người quản lý chấm công hoặc đọc được bảng lương. Hàm
    -- SECURITY DEFINER không được mở cho mọi người chỉ vì dữ liệu "không
    -- nhạy cảm lắm".
    and (public.can_manage_attendance() or public.can_read_payroll())
  order by o.effective_from desc
  limit 1;
$$;

comment on function public.he_so_lam_them_hieu_luc(date) is
  'Ba hệ số làm thêm giờ hiệu lực tại một ngày. Mở cho HR để màn xác nhận chấm công hiện được mức mặc định.';

revoke execute on function public.he_so_lam_them_hieu_luc(date) from public, anon;
grant execute on function public.he_so_lam_them_hieu_luc(date) to authenticated;
