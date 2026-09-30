-- =========================================================
-- Tổng hợp công phải chịu được lần bấm NGƯỢC THỨ TỰ
--
-- LỖI (dò ra 12/08/2026 bằng scripts/do-loi-toan-dien.mjs):
--
--   Một người quên bấm vào buổi sáng, bấm "Chấm ra" trước rồi chiều bấm
--   "Chấm vào". Bốn nút trên màn chấm công luôn bấm được nên chuyện này
--   xảy ra được bằng thao tác bình thường.
--
--   Khi nhân sự xác nhận, hàm này dựng dòng bảng công với first_in 17:00 và
--   last_out 08:00, vi phạm ràng buộc att_day_thu_tu_hop_le và NÉM LỖI.
--
--   Hàm gom TẤT CẢ nhân viên trong MỘT câu lệnh, nên nó không hỏng riêng cho
--   người bấm ngược — nó dừng hẳn. Đã dựng lại đúng ca này: một người thứ
--   hai bấm hoàn toàn bình thường cùng ngày cũng MẤT bảng công. pg_cron gọi
--   hàm này mỗi đêm lúc 00:15.
--
-- CÁCH SỬA: lần bấm ra chỉ được nhận nếu nó SAU lần bấm vào. Không thoả thì
-- coi như thiếu lần bấm ra — `last_out` là NULL, trạng thái thành
-- `thieu_cham_ra`, công 0 phút.
--
-- Vì sao không tự đoán "chắc họ định bấm ngược lại": đoán là tự tạo ra giờ
-- công không có căn cứ. Để trạng thái `thieu_cham_ra` thì nhân sự nhìn bảng
-- công là thấy ngay và sửa được, còn đoán thì không ai biết mà sửa.
--
-- Ràng buộc att_day_thu_tu_hop_le GIỮ NGUYÊN. Nó không phải thủ phạm — nó
-- là thứ đã chặn dữ liệu vô lý đi vào bảng. Sửa phần tính toán, không nới
-- ràng buộc.
-- =========================================================

create or replace function public.tong_hop_cong_ngay(p_ngay date)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  so_dong integer;
  ca      public.work_shifts%rowtype;
begin
  select * into ca from public.work_shifts where is_active order by code limit 1;
  if not found then
    raise exception 'Chưa khai báo ca làm việc nào — không tổng hợp công được.';
  end if;

  -- Dọn trước: ai không còn lần chấm hợp lệ nào trong ngày thì không có ngày
  -- công. attendance_days là dữ liệu dẫn xuất nên xoá ở đây không mất gì.
  delete from public.attendance_days d
  where d.work_date = p_ngay
    and not exists (
      select 1 from public.attendance_logs l
      where l.employee_id = d.employee_id
        and l.da_xac_nhan
        and l.deleted_at is null
        and (l.logged_at at time zone 'Asia/Ho_Chi_Minh')::date = p_ngay
    );

  with tho as (
    select
      l.employee_id,
      min(l.logged_at) filter (where l.check_type = 'in')     as first_in,
      max(l.logged_at) filter (where l.check_type = 'out')    as last_out,
      min(l.logged_at) filter (where l.check_type = 'ot_in')  as ot_in,
      max(l.logged_at) filter (where l.check_type = 'ot_out') as ot_out
    from public.attendance_logs l
    where l.da_xac_nhan
      and l.deleted_at is null
      and (l.logged_at at time zone 'Asia/Ho_Chi_Minh')::date = p_ngay
    group by l.employee_id
  ),
  gom as (
    select
      t.employee_id,
      t.first_in,
      t.ot_in,
      -- So sánh với NULL cho ra NULL, nên người chỉ bấm ra mà không bấm vào
      -- cũng rơi vào nhánh này — đúng ý: không có lần bấm vào thì không có
      -- mốc nào để tính công.
      case when t.last_out >= t.first_in then t.last_out end as last_out,
      case when t.ot_out   >= t.ot_in    then t.ot_out   end as ot_out
    from tho t
  )
  insert into public.attendance_days as d (
    employee_id, work_date, shift_id, first_in, last_out,
    ot_first_in, ot_last_out,
    worked_minutes, ot_minutes, late_minutes, early_leave_minutes,
    status, tong_hop_luc
  )
  select
    g.employee_id, p_ngay, ca.id, g.first_in, g.last_out,
    g.ot_in, g.ot_out,
    c.worked_minutes, c.ot_minutes, c.late_minutes, c.early_leave_minutes,
    c.status, now()
  from gom g
  cross join lateral public.tinh_cong_mot_ngay(
    p_ngay, g.first_in, g.last_out, g.ot_in, g.ot_out,
    ca.start_time, ca.end_time, ca.break_start, ca.break_end
  ) c
  on conflict (employee_id, work_date) do update set
    shift_id            = excluded.shift_id,
    first_in            = excluded.first_in,
    last_out            = excluded.last_out,
    ot_first_in         = excluded.ot_first_in,
    ot_last_out         = excluded.ot_last_out,
    worked_minutes      = excluded.worked_minutes,
    ot_minutes          = excluded.ot_minutes,
    late_minutes        = excluded.late_minutes,
    early_leave_minutes = excluded.early_leave_minutes,
    status              = excluded.status,
    tong_hop_luc        = excluded.tong_hop_luc;

  get diagnostics so_dong = row_count;
  return so_dong;
end;
$$;

revoke execute on function public.tong_hop_cong_ngay(date) from public, anon, authenticated;
