-- =========================================================
-- SỰ CỐ 12/08/2026: hai khoá ngoại giữa app_users và employees làm hỏng
-- TOÀN BỘ trang sau đăng nhập
--
-- Migration 20260812000006 thêm `employees.deleted_by references app_users`.
-- Trước đó giữa hai bảng này chỉ có MỘT khoá ngoại: app_users.employee_id.
-- Thêm cái thứ hai là PostgREST không còn suy ra được nên nhúng theo quan hệ
-- nào, và trả về lỗi:
--
--   PGRST201 Could not embed because more than one relationship was found
--
-- Truy vấn bị hỏng là truy vấn của `layPhien()`:
--   app_users -> employees ( positions ( tabs ) )
--
-- Mà layPhien chạy trên MỌI trang cần đăng nhập. Nên một cột mới thêm để ghi
-- vết xoá đã làm sập cả app, trong khi migration chạy trơn tru và mọi bộ
-- kiểm tra đều xanh — không bộ nào chạm tới đường nhúng của PostgREST.
--
-- CÁCH SỬA: trỏ `deleted_by` sang `auth.users(id)` thay vì `public.app_users`.
--
-- Vì sao chọn cách này thay vì sửa câu truy vấn trong `phien.ts` bằng cách
-- chỉ đích danh quan hệ:
--   1. Sửa ở đây có hiệu lực NGAY, không phải chờ Vercel build lại — app
--      đang hỏng.
--   2. Sửa câu truy vấn chỉ chữa đúng một chỗ, và để lại cái bẫy nguyên vẹn
--      cho mọi câu nhúng viết sau này. Gỡ khoá ngoại thứ hai là gỡ nguyên
--      nhân.
--   3. Không mất gì: `app_users.id` vốn = `auth.users.id`, nên các hàm thùng
--      rác vẫn join sang app_users để lấy tên người xoá như cũ. PostgREST
--      không phơi schema `auth` nên khoá ngoại này không tạo quan hệ nhúng
--      nào để mà nhập nhằng.
-- =========================================================

alter table public.employees
  drop constraint employees_deleted_by_fkey,
  add  constraint employees_deleted_by_fkey
       foreign key (deleted_by) references auth.users (id);

alter table public.attendance_logs
  drop constraint attendance_logs_deleted_by_fkey,
  add  constraint attendance_logs_deleted_by_fkey
       foreign key (deleted_by) references auth.users (id);

comment on column public.employees.deleted_by is
  'Trỏ auth.users chứ KHÔNG phải app_users: khoá ngoại thứ hai giữa app_users và employees làm PostgREST không nhúng được (sự cố 12/08/2026).';

comment on column public.attendance_logs.deleted_by is
  'Trỏ auth.users — cùng lý do với employees.deleted_by. attendance_logs đã có xac_nhan_boi trỏ app_users rồi.';
