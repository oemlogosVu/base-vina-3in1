-- =========================================================
-- P6a — Bucket private cho file PDF chứng từ
--
-- Tách khỏi migration bảng theo đúng tiền lệ P2 và P5a: storage nằm trong
-- schema do Supabase quản lý, quyền ở đó khác schema public, và hỏng ở đây
-- không được kéo đổ phần bảng đã áp xong.
-- =========================================================

-- ---------------------------------------------------------
-- 1. Bucket
--
--    5 MB, chỉ nhận application/pdf. Một bảng thanh toán 200 người vẫn dưới
--    200 KB, nên 5 MB là rộng rãi. Bucket private mà nhận file tuỳ kiểu là
--    chỗ chứa dữ liệu miễn phí cho người biết cách gọi.
-- ---------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'chung-tu',
  'chung-tu',
  false,
  5242880,                                  -- 5 MB
  array['application/pdf']
)
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- ---------------------------------------------------------
-- 2. Ai đọc được file
--
--    KHÔNG phân quyền theo thư mục như hai bucket kia. Ở đây quyền đọc phụ
--    thuộc vào chuyện chứng từ ấy thuộc loại gì và của tổ nào — thông tin đã
--    nằm sẵn trong bảng `chung_tu`. Tra ngược từ đường dẫn là cách duy nhất
--    không phải chép quy tắc ra lần thứ hai.
--
--    Hệ quả cố ý: file có trong kho mà KHÔNG có dòng trong `chung_tu` thì
--    không ai đọc được. Đó là hành vi đúng — file không có bản ghi đi kèm thì
--    không có vân tay sha256, và không có vân tay thì nó không phải chứng từ.
-- ---------------------------------------------------------
drop policy if exists "chung_tu_pdf_select" on storage.objects;

create policy "chung_tu_pdf_select"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'chung-tu'
    and (select public.co_the_doc_chung_tu_theo_duong_dan(name))
  );

-- ---------------------------------------------------------
-- 3. Không ai GHI được ngoài Edge Function
--
--    Không policy INSERT / UPDATE / DELETE nào cho `authenticated`; thiếu
--    policy nghĩa là RLS từ chối. `service_role` bỏ qua RLS nên Edge Function
--    vẫn ghi được.
--
--    Ở đây lý do nặng hơn hai bucket kia. Cho người dùng tự upload vào bucket
--    này là cho họ tự tạo ra "chứng từ" với bất kỳ con số nào — thứ mà cả hệ
--    thống này dựng lên để chống. Bản ghi trong `chung_tu` cũng không ai ghi
--    được, nên hai đầu khoá cùng lúc.
-- ---------------------------------------------------------
