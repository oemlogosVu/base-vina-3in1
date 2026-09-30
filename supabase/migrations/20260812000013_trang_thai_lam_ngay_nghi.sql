-- =========================================================
-- Thêm trạng thái ngày công "làm ngày nghỉ"
--
-- Tách riêng một file chỉ để thêm giá trị enum: giá trị mới của enum KHÔNG
-- dùng được trong cùng giao dịch tạo ra nó. Gộp chung với migration dùng nó
-- là hỏng ngay lúc chạy.
--
-- Vì sao cần trạng thái mới: từ nay chủ nhật có người đi làm sẽ ra 0 phút
-- giờ làm thường và toàn bộ vào phút làm thêm. Nếu vẫn dùng 'du_cong' thì
-- bảng công hiện "Đủ công" cho một ngày mà giờ làm thường bằng 0 — người xem
-- không hiểu nổi.
-- =========================================================

alter type public.attendance_day_status add value if not exists 'lam_ngay_nghi';
