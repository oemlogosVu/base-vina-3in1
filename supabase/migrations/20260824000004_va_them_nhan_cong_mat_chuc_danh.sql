-- =========================================================
-- Vá lỗi P5e vừa gây ra: thêm nhân công công nhật ngã ngay
--
-- Bộ kiểm hành vi tổ đội bắt được ngay khi chạy lần đầu sau P5e:
--
--   ✖ Người quản lý thêm được nhân công vào tổ mình
--     — column "position_id" of relation "employees" does not exist
--
-- NGUYÊN NHÂN, và nó đáng ghi lại
--
-- P5e viết lại `them_nhan_cong_to()` để đổi tham số đơn giá. Tôi chép thân hàm
-- từ migration P5c (19/08) — nơi nó ra đời — mà KHÔNG kiểm xem bản đang chạy
-- có còn là bản ấy không. Nó không: P1c cùng ngày 19/08 đã viết lại hàm này,
-- vì `employees.position_id` bị gỡ và chức danh chuyển sang bảng lịch sử
-- `nhan_vien_chuc_danh`. Chép bản cũ đè lên bản mới là quay ngược lịch sử một
-- hàm.
--
-- Cùng một hình dạng với lỗi ảnh chấm công ngày 22/08: một chỗ được sửa, một
-- chỗ chép lại luật cũ, và không ai thấy cho tới khi có người chạy thật.
--
-- BÀI HỌC: sửa một hàm thì lấy thân hàm từ DATABASE ĐANG CHẠY
-- (`pg_get_functiondef`), không lấy từ migration đầu tiên định nghĩa nó. Tên
-- file migration nói hàm ấy RA ĐỜI ở đâu, không nói nó ĐANG là gì.
--
-- Bản này ghép đúng hai thứ: thân hàm của P1c, và tham số đơn giá giờ của P5e.
-- =========================================================

drop function if exists public.them_nhan_cong_to(uuid, text, text, numeric, numeric, date);

create or replace function public.them_nhan_cong_to(
  p_to_doi_id   uuid,
  p_ho_ten      text,
  p_cccd        text    default null,
  p_don_gia_gio numeric default null,
  p_don_gia_ot  numeric default null,
  p_tu_ngay     date    default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $tnc$
declare
  chuc_danh uuid;
  cty       uuid;
  ma        text;
  nv        uuid;
  vao_tu    date;
begin
  if not (public.la_nguoi_cham_cong_to(p_to_doi_id) or public.is_hr_or_admin()) then
    raise exception 'Bạn không phụ trách tổ này.';
  end if;

  if coalesce(btrim(p_ho_ten), '') = '' then
    raise exception 'Thiếu họ và tên.';
  end if;
  if p_don_gia_gio is not null and p_don_gia_gio < 0 then
    raise exception 'Đơn giá giờ không được âm.';
  end if;
  if p_don_gia_ot is not null and p_don_gia_ot < 0 then
    raise exception 'Đơn giá ngoài giờ không được âm.';
  end if;

  select id into chuc_danh from public.positions where la_cong_nhat limit 1;
  if chuc_danh is null then
    raise exception 'Chưa đánh dấu chức danh nào là "công nhật". Vào Quản lý tổ đội → Lập tổ để tích chức danh dùng cho nhân công thuê ngoài.';
  end if;

  select company_id into cty from public.to_doi where id = p_to_doi_id;
  vao_tu := coalesce(p_tu_ngay, current_date);

  select 'CN' || lpad(
           (coalesce(max(substring(e.employee_code from '^CN(\d+)$')::integer), 0) + 1)::text,
           4, '0')
    into ma
  from public.employees e
  where e.employee_code ~ '^CN\d+$';

  insert into public.employees
    (employee_code, full_name, status, company_id, hire_date, theo_doi_cham_cong)
  values
    (ma, btrim(p_ho_ten), 'cong_tac_vien', cty, vao_tu, false)
  returning id into nv;

  -- P1c: chức danh nằm ở bảng lịch sử, không còn là một cột trên hồ sơ.
  insert into public.nhan_vien_chuc_danh
    (employee_id, position_id, tu_ngay, la_chinh, ly_do)
  values
    (nv, chuc_danh, vao_tu, true, 'Nhân công công nhật');

  if coalesce(btrim(p_cccd), '') <> '' then
    insert into public.employee_sensitive (employee_id, cccd)
    values (nv, btrim(p_cccd));
  end if;

  -- P5e: công nhật tính theo giờ, chấm theo ca.
  insert into public.to_doi_thanh_vien
    (to_doi_id, employee_id, tu_ngay, kieu_tinh, don_gia_gio, don_gia_ot)
  values
    (p_to_doi_id, nv, vao_tu, 'gio', p_don_gia_gio, p_don_gia_ot);

  return nv;
end;
$tnc$;

revoke all    on function public.them_nhan_cong_to(uuid, text, text, numeric, numeric, date) from anon, public;
grant execute on function public.them_nhan_cong_to(uuid, text, text, numeric, numeric, date) to authenticated;
