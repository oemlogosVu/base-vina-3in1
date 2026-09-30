-- =========================================================
-- P2b — Đổi tên khoá ngoại cho khớp tên cột mới
--
-- Migration trước đổi cột `duyet_boi` thành `xac_nhan_boi`, nhưng Postgres
-- giữ nguyên tên ràng buộc tự sinh `attendance_logs_duyet_boi_fkey`.
--
-- Chuyện nhỏ, nhưng nó hiện ra trong thông báo lỗi khi ai đó vi phạm khoá
-- ngoại — và một cái tên chỉ tới cột không còn tồn tại sẽ làm người đang gỡ
-- lỗi đi tìm nhầm chỗ. Đây chính là cách nó lộ ra: script kiểm tra P2 báo
-- lỗi dọn dẹp kèm tên ràng buộc cũ.
-- =========================================================

alter table public.attendance_logs
  rename constraint attendance_logs_duyet_boi_fkey to attendance_logs_xac_nhan_boi_fkey;
