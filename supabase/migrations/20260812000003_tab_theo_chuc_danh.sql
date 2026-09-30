-- =========================================================
-- Tab hiển thị theo chức danh
--
-- Yêu cầu 12/08/2026: admin thiết lập cho từng chức danh, khi mở app lên thì
-- vào được những tab nào.
--
-- ⚠️ ĐÂY KHÔNG PHẢI PHÂN QUYỀN. Trong dự án này lớp bảo vệ thật luôn là RLS ở
--    database. Cấu hình này là lớp ĐIỀU HƯỚNG: ẩn tab khỏi menu và chặn khi
--    người dùng gõ thẳng URL. Dữ liệu vẫn do vai trò trong `app_users.role`
--    và policy RLS quyết định.
--
--    Hệ quả quan trọng: cấu hình chỉ BỚT được, không CẤP THÊM. Tick một tab
--    cho chức danh mà người giữ nó không có vai trò tương ứng thì tab hiện ra
--    rồi vẫn trống — tệ hơn là không hiện. Phía ứng dụng lấy GIAO của hai
--    tập: tab theo vai trò ∩ tab đã cấu hình.
-- =========================================================

alter table public.positions
  add column tabs text[];

comment on column public.positions.tabs is
  'Danh sách khoá tab chức danh này được vào. NULL = chưa cấu hình, dùng mặc định theo vai trò. Mảng rỗng = chỉ còn tab bắt buộc. Chỉ bớt được, không cấp thêm quyền.';

-- Không seed giá trị nào: NULL nghĩa là "chưa cấu hình" và ứng dụng dùng mặc
-- định theo vai trò — đúng hành vi hiện tại. Chức danh mới thêm sau này cũng
-- vào nhánh đó, nên không ai bị mất tab vì quên cấu hình.
