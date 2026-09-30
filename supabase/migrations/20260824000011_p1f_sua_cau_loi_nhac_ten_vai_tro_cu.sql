-- =========================================================
-- P1f (tiếp) — Sửa câu từ chối còn gọi tên vai trò cũ
--
-- P1f gỡ `hr` và `ke_toan` khỏi năm hàm phân quyền, nhưng năm hàm nghiệp vụ
-- vẫn từ chối bằng câu "Chỉ kế toán hoặc admin…" / "Chỉ nhân sự hoặc admin…".
--
-- Câu ấy nay SAI, và sai theo kiểu tệ nhất: nó bảo người dùng đi xin đúng thứ
-- không còn giúp được họ. Một kế toán đọc câu đó sẽ đi hỏi "tôi là kế toán mà"
-- — và họ đúng.
--
-- Không đổi một dòng logic nào ở đây, chỉ đổi câu chữ. Điều kiện vẫn là
-- `can_manage_payroll()` / `can_manage_attendance()` / `is_hr_or_admin()` như
-- P1f đã đặt.
-- =========================================================

-- Sửa tại chỗ trong định nghĩa ĐANG CHẠY, không chép lại thân hàm từ migration
-- cũ. Bài học 24/08: tên file migration nói hàm ấy RA ĐỜI ở đâu, không nói nó
-- ĐANG là gì — chép bản cũ đè lên bản mới là quay ngược lịch sử một hàm.
do $$
declare
  f       record;
  dinh_nghia text;
begin
  for f in
    select p.oid
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prokind = 'f'
      and (pg_get_functiondef(p.oid) like '%Chỉ kế toán%'
           or pg_get_functiondef(p.oid) like '%Chỉ nhân sự%')
  loop
    dinh_nghia := pg_get_functiondef(f.oid);

    dinh_nghia := replace(
      dinh_nghia,
      'Chỉ kế toán hoặc admin được chốt kỳ lương.',
      'Bạn không có quyền chốt kỳ lương. Quyền này thuộc quản trị hệ thống, hoặc chức danh được tick quyền "Tính lương" tại Quản trị → Chức danh.');

    dinh_nghia := replace(
      dinh_nghia,
      'Chỉ kế toán hoặc admin được tính lương.',
      'Bạn không có quyền tính lương. Quyền này thuộc quản trị hệ thống, hoặc chức danh được tick quyền "Tính lương" tại Quản trị → Chức danh.');

    dinh_nghia := replace(
      dinh_nghia,
      'Chỉ kế toán hoặc admin được đánh dấu kỳ lương đã trả.',
      'Bạn không có quyền đánh dấu kỳ lương đã trả. Quyền này thuộc quản trị hệ thống, hoặc chức danh được tick quyền "Tính lương".');

    dinh_nghia := replace(
      dinh_nghia,
      'Chỉ nhân sự hoặc admin được xác nhận chấm công.',
      'Bạn không có quyền xác nhận chấm công. Quyền này thuộc quản trị hệ thống, hoặc chức danh được tick quyền "Xác nhận chấm công".');

    dinh_nghia := replace(
      dinh_nghia,
      'Chỉ nhân sự và quản trị mới đổi được chức danh.',
      'Bạn không có quyền đổi chức danh. Quyền này thuộc quản trị hệ thống, hoặc chức danh được tick quyền "Quản lý nhân sự" tại Quản trị → Chức danh.');

    execute dinh_nghia;
  end loop;
end $$;
