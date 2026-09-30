-- =========================================================
-- P5a — Gỡ khoá ngoại thứ hai giữa app_users và phien_cham_cong_to
--
-- Bảng `phien_cham_cong_to` vừa tạo mang HAI khoá ngoại trỏ về app_users:
-- `nguoi_cham_id` và `duyet_boi`. Đó đúng là hình dạng đã làm sập cả app ngày
-- 12/08/2026 (xem 20260812000008): PostgREST không suy ra được nên nhúng theo
-- quan hệ nào và trả PGRST201 cho mọi câu nhúng chạm tới cặp bảng này.
--
-- Lần này KHÔNG có sự cố: chưa câu truy vấn nào nhúng app_users từ bảng mới.
-- Bắt được là nhờ phép kiểm 27 trong supabase/tests/p3_rls_check.sql — cái
-- lưới canh dựng lên sau sự cố kia đã làm đúng việc của nó, bắt lỗi trước khi
-- lỗi thành sự cố lần thứ hai.
--
-- Cách sửa giữ nguyên như lần trước, vì lý do vẫn nguyên vẹn: trỏ `duyet_boi`
-- sang auth.users. Không mất gì — `app_users.id` vốn bằng `auth.users.id`,
-- nên muốn lấy tên người duyệt vẫn join sang app_users được như thường.
-- PostgREST không phơi schema `auth` nên khoá ngoại này không sinh quan hệ
-- nhúng nào để mà nhập nhằng.
--
-- Giữ `nguoi_cham_id` trỏ app_users: mỗi cặp bảng được phép có một khoá ngoại,
-- và người chấm là thứ hay phải tra ngược hơn.
-- =========================================================

alter table public.phien_cham_cong_to
  drop constraint phien_cham_cong_to_duyet_boi_fkey,
  add  constraint phien_cham_cong_to_duyet_boi_fkey
       foreign key (duyet_boi) references auth.users (id);

comment on column public.phien_cham_cong_to.duyet_boi is
  'Trỏ auth.users chứ KHÔNG phải app_users: khoá ngoại thứ hai giữa hai bảng làm PostgREST không nhúng được (sự cố 12/08/2026). Muốn lấy tên thì join public.app_users theo id.';
