-- =========================================================
-- Trạng thái nhân sự: thêm "cong_tac_vien"
--
-- Yêu cầu 19/08/2026 (Triệu Vũ duyệt): bảng dữ liệu chuẩn của hai công ty có
-- 12 người là cộng tác viên — làm việc theo vụ việc, KHÔNG có hợp đồng lao
-- động. Bốn trạng thái cũ không có chỗ nào đúng cho họ:
--
--   thu_viec / chinh_thuc → sai bản chất, và nguy hiểm: chỉ cần ai đó tạo cho
--                           họ một hợp đồng là họ lọt thẳng vào bảng lương.
--   nghi_viec             → sai, họ đang cộng tác.
--   tam_hoan              → dành cho người CÓ hợp đồng đang tạm hoãn.
--
-- KHÔNG đụng tới engine lương, và cố ý như vậy. Engine chọn người theo
--     status in ('thu_viec', 'chinh_thuc')  VÀ  có hợp đồng đang hiệu lực
-- nên cộng tác viên nằm ngoài bảng lương theo cả hai vế. Muốn trả lương qua
-- hệ thống cho một cộng tác viên thì phải chuyển trạng thái VÀ lập hợp đồng —
-- hai việc có chủ đích, không phải hệ quả âm thầm của bản migration này.
--
-- Chèn TRƯỚC 'nghi_viec' để thứ tự enum vẫn là "đang làm việc" rồi mới tới
-- "đã thôi việc" — các màn danh sách sắp xếp theo status đọc mới xuôi.
-- =========================================================

alter type public.employee_status add value if not exists 'cong_tac_vien' before 'nghi_viec';

-- Postgres không cho DÙNG giá trị enum vừa thêm trong cùng giao dịch với lệnh
-- thêm nó. Nên migration này chỉ khai giá trị; việc gán trạng thái cho 12 hồ
-- sơ nằm ở bước nhập dữ liệu (scripts/nhap-du-lieu-cong-ty.mjs), chạy sau.
