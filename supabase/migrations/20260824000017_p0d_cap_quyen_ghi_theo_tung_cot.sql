-- =========================================================
-- P0d (tiếp) — Cấp quyền ghi `app_users` theo TỪNG CỘT
--
-- Phép kiểm cấu trúc p0 số 29 vừa bắt được: `authenticated` có UPDATE ở mức
-- BẢNG trên `app_users`, nên cột `quyen` vừa thêm tự thừa hưởng quyền ghi.
--
-- Postgres từ chối mọi lần ghi vào cột sinh nên KHÔNG khai thác được — nhưng
-- danh sách quyền đang nói sai. Và nói sai ở đúng chỗ nguy hiểm: người sau đọc
-- "authenticated có UPDATE trên quyen" rồi kết luận cột ấy là cột thường, hoặc
-- tệ hơn, đổi nó thành cột thường và quyền ghi đã sẵn ở đó.
--
-- Bản này cấp lại theo từng cột, giữ NGUYÊN hiệu lực hôm nay trừ đúng `quyen`.
-- Không nới thêm gì, không thu hẹp gì khác.
--
-- Vì sao không revoke thẳng `update (quyen)`: quyền cấp ở mức bảng thì revoke
-- ở mức cột không gỡ được nó. Phải hạ mức bảng xuống rồi cấp lại từng cột.
-- =========================================================

revoke insert, update on public.app_users from authenticated;

grant insert (
  id, full_name, role, employee_id, is_active,
  created_at, updated_at, quan_ly_to_doi, tabs, duyet_cong
) on public.app_users to authenticated;

grant update (
  id, full_name, role, employee_id, is_active,
  created_at, updated_at, quan_ly_to_doi, tabs, duyet_cong
) on public.app_users to authenticated;

-- SELECT giữ nguyên ở mức bảng: `quyen` phải đọc được, giao diện dựng thanh
-- menu từ nó. RLS mới là thứ quyết định thấy dòng nào.
