-- =========================================================
-- P2 — Bucket private cho ảnh selfie chấm công
--
-- Tách khỏi migration bảng (20260810000002) để nếu phần storage hỏng thì
-- phần bảng đã áp dụng xong không bị kéo theo — storage nằm trong schema do
-- Supabase quản lý, quyền hạn ở đó khác với schema public.
--
-- Ảnh selfie là DỮ LIỆU CÁ NHÂN. NĐ 13/2023 — thu thập tối thiểu, truy cập
-- tối thiểu, không giữ vô thời hạn.
-- =========================================================

-- ---------------------------------------------------------
-- 1. Bucket
--
--    public = false: không có URL công khai nào đọc được. Muốn xem phải xin
--    signed URL có hạn, và việc cấp signed URL vẫn phải đi qua policy dưới.
--
--    Giới hạn 2MB và chỉ nhận ảnh: bucket private mà nhận file tuỳ ý là một
--    chỗ chứa dữ liệu miễn phí cho người biết cách gọi.
-- ---------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'attendance-selfies',
  'attendance-selfies',
  false,
  2097152,                                  -- 2 MB
  array['image/jpeg', 'image/png']
)
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- ---------------------------------------------------------
-- 2. Ai đọc được ảnh của ai
--
--    Quy ước đường dẫn do Edge Function đặt: <employee_id>/<năm>/<log_id>.jpg
--    Đoạn đầu tiên là employee_id, nên phân quyền theo thư mục là phân quyền
--    theo người — không cần tra bảng.
--
--    Ma trận đã duyệt:
--      nhân viên   — ảnh của chính mình
--      trưởng phòng— KHÔNG. TP cần biết ai đi muộn, không cần ảnh mặt cấp
--                    dưới. Thu thập/truy cập tối thiểu theo NĐ 13/2023.
--      kế toán     — KHÔNG. Cần bảng công để tính lương, không cần ảnh.
--      HR, admin   — có, để duyệt log nghi ngờ.
-- ---------------------------------------------------------
drop policy if exists "selfie_select_cua_minh_hoac_hr" on storage.objects;

create policy "selfie_select_cua_minh_hoac_hr"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'attendance-selfies'
    and (
      (select public.can_manage_attendance())
      or (storage.foldername(name))[1] = (select public.current_employee_id())::text
    )
  );

-- ---------------------------------------------------------
-- 3. Không ai GHI được ngoài Edge Function
--
--    Không tạo policy INSERT / UPDATE / DELETE nào cho `authenticated`.
--    Thiếu policy nghĩa là RLS từ chối. service_role bỏ qua RLS nên Edge
--    Function vẫn ghi được.
--
--    Vì sao chặt đến vậy: đường dẫn ảnh là <employee_id>/... Nếu nhân viên
--    tự upload được, họ ghi đè được ảnh của lần chấm công cũ — tức sửa được
--    bằng chứng. Cùng lý do attendance_logs không cho sửa toạ độ và giờ.
--
--    Cũng không cho xoá: ảnh hết hạn 90 ngày sẽ do job dọn định kỳ chạy bằng
--    service_role, không phải do người dùng bấm xoá.
-- ---------------------------------------------------------

-- Ghi chú: KHÔNG dùng `comment on table storage.objects` ở đây. Lần đầu viết
-- migration này có câu đó và db push hỏng với `must be owner of table objects
-- (42501)` — `postgres` tạo được policy trên storage.objects nhưng KHÔNG sở
-- hữu bảng, mà COMMENT thì đòi quyền sở hữu. Toàn bộ migration bị cuộn lại vì
-- một dòng chú thích. Bài học: đừng đặt lệnh trang trí vào migration chạm tới
-- schema do Supabase quản lý.
