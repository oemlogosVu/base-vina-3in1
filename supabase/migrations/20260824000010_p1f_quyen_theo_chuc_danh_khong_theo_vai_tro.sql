-- =========================================================
-- P1f — Quyền xem nhân sự và lương đi theo CHỨC DANH, không theo vai trò
--
-- Triệu Vũ, 24/08/2026, hai lượt:
--
--   "Chỉ tài khoản quản trị mới xem và sửa được: danh sách toàn bộ nhân sự,
--    bảng lương toàn bộ nhân sự. HR cũng không được xem."
--
--   "Thay vì kế toán trưởng thì chức danh trưởng phòng sẽ được phân quyền xem
--    thông tin nhân sự, trưởng phòng kế toán sẽ tính lương. Đối với tổ đội
--    nhân công thì người chấm công sẽ là người duyệt công hoặc cấp trưởng
--    phòng."
--
-- CÁCH LÀM, VÀ VÌ SAO KHÔNG THÊM VAI TRÒ MỚI
--
-- Không thêm `ke_toan_truong` hay `truong_phong_nhan_su` vào danh mục vai trò.
-- Cơ chế để nói "người NÀY được làm việc NÀY" đã có từ P1d: quyền gán theo
-- chức danh. "Trưởng phòng kế toán" là một CHỨC DANH, và admin tick quyền
-- `tinh_luong` cho nó. Thêm một vai trò nữa là dựng cơ chế thứ hai làm đúng
-- việc mà cơ chế thứ nhất đã làm — rồi hai cơ chế sẽ lệch nhau.
--
-- Nên bản này chỉ làm một việc: **gỡ `hr` và `ke_toan` ra khỏi năm hàm phân
-- quyền**. Từ đây quyền đến từ đúng hai nguồn:
--
--   • vai trò `admin` — quản trị hệ thống, luôn có;
--   • chức danh mang quyền — admin tick ở Quản trị → Chức danh.
--
-- Ai đang là `hr` hay `ke_toan` mà vẫn cần làm việc cũ thì admin gán cho họ
-- chức danh mang đúng quyền ấy. Không mất đường nào, chỉ đổi chỗ khai.
--
-- HỆ QUẢ PHẢI NÓI TRƯỚC
--
-- Sau bản này, tài khoản vai trò `hr` KHÔNG còn: đọc danh sách nhân sự, sửa hồ
-- sơ, xác nhận chấm công, chấm hộ tổ đội. Tài khoản `ke_toan` KHÔNG còn: đọc
-- bảng lương, tạo/tính/chốt kỳ lương. Màn hình của họ sẽ trống cho tới khi
-- admin gán chức danh.
--
-- Đây là điều Triệu Vũ yêu cầu đích danh ("HR cũng không được xem"), không
-- phải hệ quả ngoài ý muốn.
-- =========================================================

-- ---------------------------------------------------------
-- 1. Năm hàm phân quyền — bỏ vai trò, giữ chức danh
--
-- Toàn bộ RLS của P1–P5 đi qua đúng năm hàm này. Sửa ở đây là sửa đúng một
-- chỗ và mọi bảng theo cùng — đó là lý do năm hàm này tồn tại từ P0.
-- ---------------------------------------------------------

-- Xem và sửa hồ sơ nhân sự, hợp đồng, người phụ thuộc; quản lý tổ đội.
-- ↔ chức danh "Trưởng phòng" mà admin tick quyền `quan_ly_nhan_su`.
create or replace function public.is_hr_or_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.current_app_role() = 'admin'
      or public.co_quyen_chuc_danh('quan_ly_nhan_su');
$$;

comment on function public.is_hr_or_admin() is
  'Tên giữ từ P0 vì hàng chục policy gọi nó. Nghĩa từ 24/08/2026: admin, hoặc chức danh mang quyền quan_ly_nhan_su. Vai trò `hr` KHÔNG còn nằm trong đây.';

create or replace function public.can_manage_attendance()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.current_app_role() = 'admin'
      or public.co_quyen_chuc_danh('xac_nhan_cham_cong');
$$;

-- Tạo kỳ lương, bấm tính, chốt kỳ. ↔ chức danh "Trưởng phòng kế toán".
create or replace function public.can_manage_payroll()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.current_app_role() = 'admin'
      or public.co_quyen_chuc_danh('tinh_luong');
$$;

-- Đọc hồ sơ toàn công ty. Ba quyền cùng cần nền này: không thấy người thì
-- không làm được hồ sơ, không tính được lương, không duyệt được công.
create or replace function public.can_read_all_employees()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.current_app_role() = 'admin'
      or public.co_quyen_chuc_danh('quan_ly_nhan_su')
      or public.co_quyen_chuc_danh('tinh_luong')
      or public.co_quyen_chuc_danh('xac_nhan_cham_cong');
$$;

-- ĐỌC BẢNG LƯƠNG của người khác — hẹp nhất trong năm hàm.
--
-- Bỏ luôn `quan_ly_nhan_su`: Triệu Vũ tách bạch hai việc, "trưởng phòng xem
-- thông tin nhân sự" và "trưởng phòng kế toán tính lương". Người làm hồ sơ
-- không cần biết thực nhận của từng người (NĐ 13/2023 — truy cập tối thiểu).
create or replace function public.can_read_payroll()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.current_app_role() = 'admin'
      or public.co_quyen_chuc_danh('tinh_luong');
$$;

comment on function public.can_read_payroll() is
  'Đọc bảng lương của người khác: CHỈ admin và chức danh mang quyền tinh_luong (trưởng phòng kế toán). Quyền quan_ly_nhan_su cố ý KHÔNG có mặt — làm hồ sơ không cần biết thực nhận của từng người.';

-- ---------------------------------------------------------
-- 2. Duyệt công tổ đội: thêm CẤP TRƯỞNG PHÒNG
--
-- "Người chấm công sẽ là người duyệt công hoặc cấp trưởng phòng."
--
-- Người chấm đã có đường riêng từ P5h (policy `phien_duyet_boi_nguoi_cham`).
-- Ở đây thêm vai trò `truong_phong`, và bỏ `hr` cùng lý do với mục 1.
--
-- CỐ Ý không giới hạn trưởng phòng theo phòng của tổ: `to_doi.department_id`
-- được phép NULL, nên siết theo phòng là khoá luôn những tổ chưa gán phòng.
-- Nếu sau này cần siết thì phải bắt buộc `department_id` trước.
-- ---------------------------------------------------------
create or replace function public.duoc_duyet_cong_to()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.current_app_role() in ('truong_phong', 'admin')
      or public.co_quyen_chuc_danh('duyet_cong');
$$;

comment on function public.duoc_duyet_cong_to() is
  'Duyệt phiên chấm công tổ đội: admin, trưởng phòng, hoặc chức danh mang quyền duyet_cong. Người chấm của chính tổ ấy đi bằng policy riêng (P5h).';

-- ---------------------------------------------------------
-- 3. Ghi ảnh xác minh: bỏ `hr`
--
-- Ba đường còn lại giữ nguyên: admin, chức danh `xac_nhan_cham_cong`, và
-- người được giao chấm công cho chính tổ ấy (kèm điều kiện nhân viên chính
-- thức đóng bảo hiểm, quyết định 19/08).
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
          where u.id = p_user_id and u.is_active and u.role = 'admin'
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
