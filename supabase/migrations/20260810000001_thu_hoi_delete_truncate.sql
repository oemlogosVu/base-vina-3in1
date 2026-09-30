-- =========================================================
-- Vá: thu hồi DELETE và TRUNCATE của `authenticated`
--
-- Vì sao cần migration này — `p1_rls_check.sql` kiểm tra #3 báo HỎNG:
-- `authenticated` vẫn có quyền DELETE trên cả 7 bảng P1, và trên cả
-- `app_users` của P0.
--
-- Nguyên nhân: Supabase đặt sẵn DEFAULT PRIVILEGES trong schema `public`
-- cấp `arwdDxtm` (có cả DELETE `d` lẫn TRUNCATE `D`) cho anon, authenticated
-- và service_role trên MỌI bảng vừa được tạo. Migration P0 và P1 chỉ viết
-- `grant select, insert, update`. Cấp thêm quyền KHÔNG thu hồi quyền đã có —
-- muốn bỏ thì phải `revoke` tường minh. Hai migration đó có `revoke all
-- ... from anon` nên phía anon sạch; phía authenticated thì không ai đụng tới.
--
-- Hệ quả thực tế, hai mức khác nhau:
--   • DELETE  — thực tế vẫn bị chặn, vì không bảng nào có policy DELETE mà
--     RLS mặc định từ chối. Đây là MẤT LỚP PHÒNG THỦ THỨ HAI, chưa phải lỗ
--     hổng khai thác được. Tài liệu ghi "hai lớp chặn" nhưng thực tế chỉ có một.
--   • TRUNCATE — nặng hơn hẳn: **TRUNCATE không đi qua RLS**. Postgres không
--     lọc hàng cho lệnh này, nên có quyền là xoá sạch bảng bất kể policy.
--     PostgREST không phát được TRUNCATE nên chưa có đường khai thác qua web,
--     nhưng bất kỳ kết nối nào cầm JWT `authenticated` đều làm được.
--
-- Nguyên tắc của dự án: không xoá cứng dữ liệu nhân sự. Nghỉ việc là đổi
-- `status`, ngừng dùng phòng ban là bỏ `is_active`.
-- =========================================================

-- ---------------------------------------------------------
-- 1. Thu hồi trên các bảng đang tồn tại (7 bảng P1 + app_users của P0)
-- ---------------------------------------------------------
revoke delete, truncate on public.app_users          from authenticated;
revoke delete, truncate on public.departments        from authenticated;
revoke delete, truncate on public.positions          from authenticated;
revoke delete, truncate on public.employees          from authenticated;
revoke delete, truncate on public.employee_sensitive from authenticated;
revoke delete, truncate on public.dependents         from authenticated;
revoke delete, truncate on public.labor_contracts    from authenticated;
revoke delete, truncate on public.employee_documents from authenticated;

-- ---------------------------------------------------------
-- 2. Chặn tận gốc cho các bảng SẼ tạo ở P2, P3, P4...
--
--    Nếu chỉ làm mục 1 thì mỗi bảng mới lại thủng lại, và người viết migration
--    sau phải nhớ thêm dòng revoke — thứ vừa chứng minh là dễ quên.
--
--    Default privileges áp theo role TẠO ra bảng. Migration của dự án chạy
--    dưới role `postgres`, nên chỉ cần sửa bộ của `postgres`. Bộ của
--    `supabase_admin` không đụng tới được (postgres không phải thành viên của
--    role đó) — nên `p1_rls_check.sql` kiểm tra #3 quét TOÀN BỘ bảng trong
--    schema public chứ không chỉ danh sách bảng P1, để bắt được cả trường hợp
--    bảng do đường khác tạo ra.
--
--    Chỉ thu hồi DELETE + TRUNCATE, không đụng SELECT/INSERT/UPDATE: bảng mới
--    vẫn giữ hành vi Supabase mặc định, và RLS vẫn là tầng quyết định ai đọc
--    được gì.
-- ---------------------------------------------------------
alter default privileges for role postgres in schema public
  revoke delete, truncate on tables from authenticated;

alter default privileges for role postgres in schema public
  revoke delete, truncate on tables from anon;
