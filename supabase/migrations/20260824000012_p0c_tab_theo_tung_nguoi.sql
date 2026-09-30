-- =========================================================
-- P0c — Tab được vào khai theo TỪNG NGƯỜI, ở màn Quản trị → Người dùng
--
-- Triệu Vũ, 24/08/2026: "cho phép người dùng xem những tab nào đặt vào phần
-- quản trị người dùng để phân quyền xem các tab cho từng người".
--
-- CHUYỂN, KHÔNG THÊM
--
-- Cấu hình tab đang nằm ở `positions.tabs` — theo CHỨC DANH, từ 12/08/2026.
-- Bản này chuyển hẳn sang `app_users.tabs`, theo TỪNG NGƯỜI, và **xoá cột cũ**.
--
-- Giữ cả hai là dựng hai cơ chế làm cùng một việc, rồi phải trả lời "hai bên
-- nói khác nhau thì nghe ai" ở mọi lần đọc. Đúng lý do vừa dùng sáng nay để
-- không thêm vai trò `ke_toan_truong`.
--
-- Không mất dữ liệu: đã tra trước khi xoá, **cả 13 chức danh đều để `tabs`
-- NULL** — chưa ai từng cấu hình. Nếu có, bản này đã phải chuyển dữ liệu sang
-- từng người trước khi xoá cột.
--
-- RANH GIỚI GIỮA TAB VÀ QUYỀN — đọc kỹ chỗ này
--
-- Tab là ĐIỀU HƯỚNG, quyền là ĐỌC ĐƯỢC GÌ. Hai thứ khác nhau và nay nằm ở hai
-- màn khác nhau, đúng theo bản chất:
--
--   • Quản trị → Người dùng  : người này THẤY màn nào.
--   • Quản trị → Chức danh   : người giữ chức danh này ĐỌC/GHI được dữ liệu gì.
--
-- Bỏ tick một tab KHÔNG thu hồi quyền đọc dữ liệu — RLS vẫn là lớp quyết định,
-- và ai gọi thẳng PostgREST vẫn đọc được đúng phần của mình. Muốn chặn dữ liệu
-- thì gỡ QUYỀN ở màn Chức danh, không phải bỏ tick tab.
-- =========================================================

-- ---------------------------------------------------------
-- 1. Cột tab trên tài khoản
--
-- NULL = CHƯA CẤU HÌNH, dùng nguyên quyền theo vai trò và theo chức danh —
-- khác hẳn mảng rỗng, nghĩa là "chỉ còn tab bắt buộc". Tài khoản mới rơi vào
-- nhánh NULL nên không ai mất tab vì admin chưa kịp khai.
-- ---------------------------------------------------------
alter table public.app_users add column tabs text[];

comment on column public.app_users.tabs is
  'Tab người này được vào. NULL = chưa cấu hình, dùng nguyên quyền theo vai trò và chức danh. Mảng rỗng = chỉ còn tab bắt buộc. ĐÂY LÀ ĐIỀU HƯỚNG, không phải quyền đọc dữ liệu — RLS mới quyết định điều đó.';

-- ---------------------------------------------------------
-- 2. Người dùng KHÔNG tự đổi tab của mình
--
-- Quyền cấp cột là theo VAI TRÒ database, không theo từng dòng, nên chỉ cấp
-- `update (tabs)` là mọi tài khoản tự sửa tab của chính mình được. Ghim `tabs`
-- vào policy tự-sửa-tên, đúng cách `role`, `is_active` và `employee_id` đã
-- được ghim từ P0.
--
-- `tai_khoan_cua_toi()` trả về nguyên dòng `public.app_users` nên nó tự có cột
-- mới, không phải sửa hàm.
--
-- Hậu quả nếu quên bước này thì nhỏ — tab là điều hướng, RLS vẫn chặn dữ liệu
-- — nhưng một người tự mở tab rồi gặp màn trống là một cuộc gọi hỗ trợ, và là
-- một lỗ hổng nhìn thì tưởng có.
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
    and tabs is not distinct from
        (select t.tabs from public.tai_khoan_cua_toi() t)
  );

comment on policy "app_users_update_self_name" on public.app_users is
  'Người dùng tự sửa TÊN của mình. Vai trò, kích hoạt, hồ sơ nhân sự và danh sách tab phải giữ nguyên — so với giá trị cũ qua tai_khoan_cua_toi() để policy không đọc thẳng bảng nó đang bảo vệ.';

grant update (tabs) on public.app_users to authenticated;

-- ---------------------------------------------------------
-- 3. Bỏ cấu hình tab theo chức danh
--
-- Xoá cột chứ không để lại: một cột không ai đọc là một cột người sau sẽ đọc
-- nhầm. Màn Chức danh từ nay chỉ còn hai việc — quyền, và phụ cấp.
-- ---------------------------------------------------------
alter table public.positions drop column tabs;
