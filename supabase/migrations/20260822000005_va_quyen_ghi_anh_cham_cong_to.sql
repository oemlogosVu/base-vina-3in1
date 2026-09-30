-- =========================================================
-- Vá lỗi: tải ảnh chấm công tổ đội LUÔN thất bại
--
-- Triệu Vũ báo 22/08/2026: "đã tải ảnh lên nhưng vẫn báo chưa có ảnh".
--
-- Tái hiện được ngay: Edge Function `anh-cham-cong-to` trả HTTP 404
-- "Không tìm thấy phiên chấm công" cho MỌI lần gọi. Bucket rỗng hoàn toàn —
-- ảnh chưa từng lên tới nơi. Tính năng này hỏng kể từ ngày nó ra đời.
--
-- NGUYÊN NHÂN
--
-- Edge Function truy vấn:
--
--     .select('id, to_doi_id, work_date, da_duyet,
--              to_doi ( nguoi_cham_cong_id, is_active )')
--
-- Cột `to_doi.nguoi_cham_cong_id` đã bị GỠ cùng ngày 19/08, khi bảng
-- `to_doi_nguoi_cham` (nhiều người chấm cho một tổ) thay thế nó. Migration ấy
-- sửa phía SQL và sửa cả bộ kiểm — phép kiểm 26 của p5 còn canh đúng việc cột
-- này phải biến mất — nhưng KHÔNG ai sửa Edge Function.
--
-- PostgREST trả lỗi "cột không tồn tại", hàm bỏ qua lỗi ấy (`const { data }`
-- không đọc `error`), thấy `data` là null và kết luận "không tìm thấy phiên".
-- Một lỗi bị nuốt biến thành một thông báo sai hoàn toàn.
--
-- VÌ SAO BỘ KIỂM KHÔNG THẤY
--
-- Bộ hành vi tổ đội đặt `anh_path` THẲNG bằng SQL để đi tiếp tới phần duyệt:
--
--     update public.phien_cham_cong_to set anh_path = '...' where id = ...
--
-- Nên nó kiểm được mọi thứ SAU khi có ảnh, mà chưa bao giờ gọi vào đường ghi
-- ảnh thật. 48 phép xanh trong khi tính năng chưa chạy được lần nào.
--
-- CÁCH VÁ Ở ĐÂY
--
-- Đưa luật "ai được ghi ảnh cho phiên này" vào MỘT hàm SQL, thay vì để Edge
-- Function tự chép lại luật bằng TypeScript. Hàm chạy bằng `service_role` thì
-- không có policy nào chặn hộ, nên luật phải viết ra — và viết ra ở đây thì
-- nó nằm cạnh những hàm phân quyền khác, kiểm được bằng cả hai tầng bộ kiểm,
-- và không thể lệch với RLS mà không ai thấy.
-- =========================================================

-- ---------------------------------------------------------
-- 1. Tách quyền-theo-chức-danh ra bản nhận user_id
--
-- `co_quyen_chuc_danh()` của P1d hỏi về NGƯỜI ĐANG ĐĂNG NHẬP, mà Edge Function
-- chạy bằng service_role nên `auth.uid()` là NULL. Cần bản nhận thẳng user_id.
--
-- Giữ đúng MỘT cài đặt: bản không tham số nay chỉ là lớp mỏng gọi bản có tham
-- số. Hai bản chép nhau là hai bản sẽ lệch nhau.
-- ---------------------------------------------------------
create or replace function public.co_quyen_chuc_danh_cua(p_user_id uuid, p_quyen text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.app_users u
    join public.nhan_vien_chuc_danh nc on nc.employee_id = u.employee_id
    join public.positions p on p.id = nc.position_id
    where u.id = p_user_id
      and u.is_active
      and p.is_active
      and nc.tu_ngay <= current_date
      and (nc.den_ngay is null or nc.den_ngay >= current_date)
      and p_quyen = any (p.quyen)
  );
$$;

comment on function public.co_quyen_chuc_danh_cua(uuid, text) is
  'Người này có quyền đó qua một chức danh đang hiệu lực hay không. Bản nhận user_id, dùng cho Edge Function chạy bằng service_role.';

create or replace function public.co_quyen_chuc_danh(p_quyen text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.co_quyen_chuc_danh_cua((select auth.uid()), p_quyen);
$$;

revoke all on function public.co_quyen_chuc_danh_cua(uuid, text) from public;
revoke all on function public.co_quyen_chuc_danh_cua(uuid, text) from anon;
grant execute on function public.co_quyen_chuc_danh_cua(uuid, text) to authenticated;

-- ---------------------------------------------------------
-- 2. Ai được ghi ảnh xác minh cho một phiên chấm công
--
-- Ba đường, đúng như `la_nguoi_cham_cong_to()` cộng với quyền mới của P1d:
--
--   a) HR hoặc admin — quản lý mọi tổ.
--   b) Chức danh có quyền `xac_nhan_cham_cong` (P1d).
--   c) Được giao chấm công cho CHÍNH tổ này, VÀ là nhân viên chính thức đang
--      đóng bảo hiểm — điều kiện Triệu Vũ chốt 19/08 và giữ lại 22/08.
--
-- Nhánh (c) gọi `la_nhan_vien_chinh_thuc()` chứ không chép lại ba vế của nó.
-- Chép lại là tạo bản thứ hai của một luật đã có, và bản thứ hai sẽ lệch.
--
-- KHÔNG xét `da_duyet` ở đây: hàm này trả lời câu hỏi về QUYỀN. Phiên đã duyệt
-- là một câu chuyện khác, và người dùng đáng nhận đúng câu "phiên đã duyệt,
-- không thay được ảnh nữa" thay vì "bạn không có quyền".
-- ---------------------------------------------------------
create or replace function public.duoc_ghi_anh_phien(p_phien_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.phien_cham_cong_to p
    join public.to_doi t on t.id = p.to_doi_id
    where p.id = p_phien_id
      and t.is_active
      and (
        exists (
          select 1 from public.app_users u
          where u.id = p_user_id and u.is_active and u.role in ('hr', 'admin')
        )
        or public.co_quyen_chuc_danh_cua(p_user_id, 'xac_nhan_cham_cong')
        or (
          exists (
            select 1 from public.to_doi_nguoi_cham g
            where g.to_doi_id = t.id and g.app_user_id = p_user_id
          )
          and public.la_nhan_vien_chinh_thuc(p_user_id)
        )
      )
  );
$$;

comment on function public.duoc_ghi_anh_phien(uuid, uuid) is
  'Người này có được ghi ảnh xác minh cho phiên chấm công tổ này không. Nguồn DUY NHẤT của luật đó — Edge Function gọi vào đây thay vì tự chép luật bằng TypeScript.';

revoke all on function public.duoc_ghi_anh_phien(uuid, uuid) from public;
revoke all on function public.duoc_ghi_anh_phien(uuid, uuid) from anon;
grant execute on function public.duoc_ghi_anh_phien(uuid, uuid) to authenticated;
