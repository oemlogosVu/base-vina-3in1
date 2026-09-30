-- =========================================================
-- P5a — Bucket private cho ảnh xác minh chấm công tổ đội
--
-- Tách khỏi migration bảng theo đúng tiền lệ P2 (20260810000004): storage
-- nằm trong schema do Supabase quản lý, quyền ở đó khác schema public, và
-- hỏng ở đây không được kéo đổ phần bảng đã áp xong.
--
-- VÌ SAO BUCKET RIÊNG, KHÔNG DÙNG `attendance-selfies`: bucket kia phân
-- quyền theo thư mục `<employee_id>/...` — đoạn đầu đường dẫn LÀ người sở
-- hữu ảnh. Ảnh chụp cả tổ không thuộc về một employee_id nào, nên nhét vào
-- đó là phá vỡ đúng cái quy ước làm cho policy bên kia đọc được.
--
-- Ảnh mặt người là DỮ LIỆU CÁ NHÂN, và ở đây còn nặng hơn selfie thường:
-- người công nhật KHÔNG có tài khoản, không tự bấm, không tự xem lại được
-- ảnh của mình. NĐ 13/2023 đòi thông báo và có sự đồng ý — việc giấy tờ
-- phía doanh nghiệp, đã nêu rõ trong kế hoạch phase. Phần code làm được là
-- giữ ảnh kín, cho ít người xem, và không giữ quá hạn.
-- =========================================================

-- ---------------------------------------------------------
-- 1. Bucket
--
--    Cùng giới hạn với bucket selfie: 2MB, chỉ ảnh. Bucket private mà nhận
--    file tuỳ ý là chỗ chứa dữ liệu miễn phí cho người biết cách gọi.
-- ---------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'to-doi-cham-cong',
  'to-doi-cham-cong',
  false,
  2097152,                                  -- 2 MB
  array['image/jpeg', 'image/png']
)
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- ---------------------------------------------------------
-- 2. Ai đọc được ảnh
--
--    Quy ước đường dẫn do Edge Function đặt: <to_doi_id>/<yyyy-mm>/<ngày>.jpg
--    Đoạn đầu là to_doi_id, nên phân quyền theo thư mục là phân quyền theo tổ.
--
--    Ma trận Triệu Vũ chốt 19/08/2026:
--      HR, admin        — có, để duyệt phiên.
--      người chấm của tổ— có, NHƯNG chỉ tổ mình. Họ cần xem lại ảnh vừa tải
--                         để biết có lên đúng không; tải nhầm mà không tự
--                         phát hiện được thì ảnh xác minh thành hình thức.
--      kế toán          — KHÔNG. Cần số công để thanh toán, không cần ảnh mặt.
--      trưởng phòng     — KHÔNG. Giữ đúng quy ước đã dùng cho ảnh selfie.
-- ---------------------------------------------------------
drop policy if exists "anh_to_doi_select" on storage.objects;

create policy "anh_to_doi_select"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'to-doi-cham-cong'
    and (
      (select public.can_manage_attendance())
      or (select public.la_nguoi_cham_cong_to_txt((storage.foldername(name))[1]))
    )
  );

-- ---------------------------------------------------------
-- 3. Không ai GHI được ngoài Edge Function
--
--    Không policy INSERT / UPDATE / DELETE nào cho `authenticated`; thiếu
--    policy nghĩa là RLS từ chối. service_role bỏ qua RLS nên Edge Function
--    vẫn ghi được.
--
--    Cùng lý do với bucket selfie, và ở đây còn nặng hơn: đường dẫn đoán
--    được từ (mã tổ, ngày). Cho người chấm tự upload là cho họ ghi đè ảnh
--    của ngày hôm trước — sửa được bằng chứng của một ngày công đã duyệt.
-- ---------------------------------------------------------
