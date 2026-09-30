-- =========================================================
-- Vá lỗi: KHÔNG ai sửa được app_users qua PostgREST
--
-- Phát hiện 22/08/2026 khi dựng màn quản trị người dùng. Mọi lệnh UPDATE lên
-- `app_users` từ một phiên `authenticated` — bất kể vai trò, bất kể sửa dòng
-- nào — đều chết với:
--
--     42P17: infinite recursion detected in policy for relation "app_users"
--
-- NGUYÊN NHÂN
--
-- Policy `app_users_update_self_name` (viết ở P0, 08/08/2026) có ba câu con
-- đọc THẲNG chính bảng nó đang bảo vệ:
--
--     and role = (select u.role from public.app_users u where u.id = auth.uid())
--
-- Postgres áp RLS lên cả câu con đó, câu con lại kích hoạt chính policy này,
-- và nó dừng lại bằng lỗi đệ quy. Đây là cái bẫy mà P0 đã tránh đúng cho
-- `current_app_role()` bằng `security definer` — nhưng chỉ tránh ở hàm, không
-- tránh ở policy.
--
-- VÌ SAO NẰM IM 14 NGÀY
--
-- Không phải vì nó hiếm gặp — nó chặn 100% lệnh update. Nó nằm im vì bộ kiểm
-- tra hành vi P0 chứng minh sai điều: phép kiểm 3 và 4 bỏ qua `error` mà chỉ
-- xem giá trị trong bảng có đổi không. Giá trị không đổi thật — nhưng vì câu
-- lệnh sập, chứ không phải vì policy chặn. Một phép kiểm hỏi "kết quả có
-- đúng không" mà không hỏi "đúng vì lý do gì" sẽ xanh cả khi thứ nó canh đã
-- hỏng hoàn toàn.
--
-- Màn "quản lý tổ đội" của P5c (21/08) cũng đi qua đường này, nên nút bật/tắt
-- quyền chấm công tổ đội chưa từng lưu được lần nào.
--
-- CÁCH VÁ
--
-- Chuyển ba câu con vào một hàm `security definer`. Hàm chạy dưới quyền chủ
-- sở hữu nên câu đọc bên trong không bị RLS áp lại — hết đệ quy, mà ý nghĩa
-- của policy giữ nguyên từng chữ: người dùng đổi được TÊN của mình, và
-- không đổi được vai trò, trạng thái kích hoạt, hay hồ sơ nhân sự mình trỏ
-- tới.
-- =========================================================

-- ---------------------------------------------------------
-- 1. Dòng app_users của chính người đang đăng nhập
--
-- Trả về đúng MỘT dòng, và luôn là dòng của người gọi — `auth.uid()` nằm
-- trong thân hàm, không nhận tham số. Không có đường nào để người gọi hỏi về
-- dòng của người khác, nên `security definer` ở đây không mở thêm quyền đọc
-- nào so với policy `app_users_select_self` đã có sẵn.
-- ---------------------------------------------------------
create or replace function public.tai_khoan_cua_toi()
returns public.app_users
language sql
stable
security definer
set search_path = ''
as $$
  select u.* from public.app_users u where u.id = (select auth.uid());
$$;

comment on function public.tai_khoan_cua_toi() is
  'Dòng app_users của người đang đăng nhập. security definer để policy trên chính bảng này gọi được mà không đệ quy.';

revoke all on function public.tai_khoan_cua_toi() from public;
revoke all on function public.tai_khoan_cua_toi() from anon;
grant execute on function public.tai_khoan_cua_toi() to authenticated;

-- ---------------------------------------------------------
-- 2. Viết lại policy — cùng ý nghĩa, không còn tự tham chiếu
-- ---------------------------------------------------------
drop policy "app_users_update_self_name" on public.app_users;

create policy "app_users_update_self_name"
  on public.app_users for update
  to authenticated
  using (id = (select auth.uid()))
  with check (
    id = (select auth.uid())
    and role      = (select t.role      from public.tai_khoan_cua_toi() t)
    and is_active = (select t.is_active from public.tai_khoan_cua_toi() t)
    and employee_id is not distinct from
        (select t.employee_id from public.tai_khoan_cua_toi() t)
  );

comment on policy "app_users_update_self_name" on public.app_users is
  'Người dùng tự sửa TÊN của mình. Vai trò, kích hoạt và hồ sơ nhân sự phải giữ nguyên — so với giá trị cũ qua tai_khoan_cua_toi() để policy không đọc thẳng bảng nó đang bảo vệ.';
