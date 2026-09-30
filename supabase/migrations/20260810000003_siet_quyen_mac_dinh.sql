-- =========================================================
-- Vá lần hai: "không grant" vẫn KHÔNG có nghĩa là "không có quyền"
--
-- Sáng 10/08 đã vá lần một (20260810000001): thu hồi DELETE và TRUNCATE, và
-- sửa default privileges để bảng mới không dính lại. Vá đó ĐÚNG nhưng CHƯA
-- ĐỦ — nó chỉ thu hồi hai quyền đó. Supabase vẫn cấp mặc định INSERT, UPDATE,
-- SELECT (và REFERENCES, TRIGGER, MAINTAIN) cho anon + authenticated trên
-- mọi bảng vừa tạo.
--
-- Hậu quả lộ ra ngay ở P2, do p2_rls_check.sql bắt được:
--
--   • attendance_logs cố ý KHÔNG grant insert cho authenticated, để nhân
--     viên không tự ghi được log. Nhưng nó đã có sẵn INSERT từ default
--     privileges. Điều khoản quan trọng nhất của P2 — client không tự tạo
--     được công — trên thực tế KHÔNG CÓ HIỆU LỰC.
--
--   • attendance_logs cấp UPDATE trên đúng 5 cột duyệt, để không ai sửa được
--     toạ độ và giờ đã chấm. Nhưng nó đã có sẵn UPDATE trên TOÀN BỘ cột.
--     Grant cấp cột chỉ THÊM quyền, không giới hạn quyền đã có.
--
-- Bài học lặp lại lần thứ hai trong cùng một ngày, nên lần này vá tận gốc
-- thay vì vá từng bảng: mặc định phải là KHÔNG CÓ GÌ, rồi mỗi migration tự
-- khai báo quyền nó cần. Cả P0, P1, P2 đều đã viết `grant ...` tường minh
-- rồi, nên không migration nào phải sửa lại.
-- =========================================================

-- ---------------------------------------------------------
-- 1. Mặc định của bảng tương lai: không có gì
--
--    Áp theo role TẠO ra bảng. Migration của dự án chạy dưới `postgres`.
--    Bộ của `supabase_admin` không đụng tới được (postgres không phải thành
--    viên role đó) — nên p2_rls_check.sql kiểm tra #3 và #16 quét TOÀN BỘ
--    schema public, để bắt được bảng do đường khác tạo ra.
-- ---------------------------------------------------------
alter default privileges for role postgres in schema public
  revoke all on tables from authenticated;

alter default privileges for role postgres in schema public
  revoke all on tables from anon;

-- ---------------------------------------------------------
-- 2. Sửa hậu quả trên attendance_logs — bảng duy nhất bị ảnh hưởng thật
--
--    Ba bảng P2 còn lại (office_locations, work_shifts, attendance_days) có
--    grant select/insert/update trùng đúng với quyền mặc định, và RLS mới là
--    lớp quyết ai ghi được. Không sai, nên không sửa.
-- ---------------------------------------------------------

-- Nhân viên không tự ghi log chấm công. Insert chỉ đi qua Edge Function
-- (service_role), vì client tự insert thì tự đặt được logged_at và is_valid.
revoke insert on public.attendance_logs from authenticated;

-- Thu hồi UPDATE ở cấp BẢNG trước, rồi mới cấp lại đúng 5 cột duyệt.
-- Thứ tự này bắt buộc: cấp cột không thu hẹp được quyền cấp bảng đã có.
revoke update on public.attendance_logs from authenticated;

grant update (is_valid, ly_do_khong_hop_le, duyet_boi, duyet_luc, ghi_chu_duyet)
  on public.attendance_logs to authenticated;

-- ---------------------------------------------------------
-- 3. Bảo hiểm cho các quyền ít ai để ý
--
--    REFERENCES cho phép tạo khoá ngoại trỏ vào bảng — dùng được để dò sự
--    tồn tại của một hàng mà RLS đang giấu. TRIGGER cho phép gắn trigger lên
--    bảng của người khác. Cả hai đều nằm trong arwdDxtm mặc định và chưa
--    migration nào cần tới.
-- ---------------------------------------------------------
do $$
declare
  ten_bang text;
begin
  for ten_bang in
    select c.relname
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r'
  loop
    execute format(
      'revoke references, trigger on public.%I from authenticated, anon',
      ten_bang
    );
  end loop;
end $$;
