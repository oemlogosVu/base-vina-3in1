-- =========================================================
-- P2 — Tổng hợp attendance_logs thành attendance_days
--
-- Chạy phía database chứ không phải Edge Function: bảng công là đầu vào của
-- engine lương P3, nên phải nằm cùng chỗ với dữ liệu và cùng một giao dịch.
-- Một job tổng hợp chạy nửa chừng rồi chết mà để lại bảng công dở dang là
-- tính sai tiền.
-- =========================================================

-- ---------------------------------------------------------
-- 1. Sửa phut_giao_nhau: ceil -> floor
--
--    Bản đầu (20260810000002) dùng ceil. Bản TypeScript ở
--    supabase/functions/_shared/thoi-gian.ts dùng floor. Hai nơi cùng công
--    thức mà làm tròn khác nhau thì ra hai con số khác nhau — đúng thứ mà
--    ghi chú của chính hàm đó nói là phải tránh.
--
--    Chọn floor chứ không sửa TypeScript sang ceil: ceil làm phần trừ giờ
--    nghỉ to lên, tức trừ oan của người lao động. Sai số dưới một phút thì
--    nên nghiêng về phía người làm công.
-- ---------------------------------------------------------
create or replace function public.phut_giao_nhau(
  a_bat_dau timestamptz, a_ket_thuc timestamptz,
  b_bat_dau timestamptz, b_ket_thuc timestamptz
)
returns integer
language sql
immutable
set search_path = ''
as $$
  select greatest(
    0,
    floor(extract(epoch from (
      least(a_ket_thuc, b_ket_thuc) - greatest(a_bat_dau, b_bat_dau)
    )) / 60)
  )::integer;
$$;

-- ---------------------------------------------------------
-- 2. Tổng hợp công của MỘT ngày
--
--    Trả về số dòng đã ghi. Chạy lại bao nhiêu lần cũng ra cùng kết quả —
--    cần thiết vì HR duyệt một log nghi ngờ xong là phải tổng hợp lại ngày
--    đó.
--
--    CHỈ tính log is_valid = true. Log đang chờ HR duyệt KHÔNG được tính
--    công: tính trước rồi trừ sau là đã trả tiền cho công chưa được duyệt.
-- ---------------------------------------------------------
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
  -- Ca mặc định. P2 chỉ có một ca; khi công ty có nhiều ca thì chỗ này đổi
  -- thành tra ca theo từng nhân viên, và đó là migration riêng.
  select * into ca from public.work_shifts where is_active order by code limit 1;
  if not found then
    raise exception 'Chưa khai báo ca làm việc nào — không tổng hợp công được.';
  end if;

  with log_trong_ngay as (
    select
      l.employee_id,
      -- Ngày làm việc theo GIỜ VIỆT NAM. Ca đêm chấm ra 00:30 giờ VN là UTC
      -- 17:30 hôm trước — gom theo UTC là đẩy công sang nhầm ngày.
      (l.logged_at at time zone 'Asia/Ho_Chi_Minh')::date as work_date,
      l.check_type,
      l.logged_at
    from public.attendance_logs l
    where l.is_valid
      and (l.logged_at at time zone 'Asia/Ho_Chi_Minh')::date = p_ngay
  ),
  gom as (
    select
      employee_id,
      work_date,
      min(logged_at) filter (where check_type = 'in')  as first_in,
      max(logged_at) filter (where check_type = 'out') as last_out
    from log_trong_ngay
    group by employee_id, work_date
  ),
  moc as (
    select
      g.*,
      (p_ngay + ca.start_time) at time zone 'Asia/Ho_Chi_Minh' as ca_bat_dau,
      (p_ngay + ca.end_time)   at time zone 'Asia/Ho_Chi_Minh' as ca_ket_thuc,
      case when ca.break_start is null then null
           else (p_ngay + ca.break_start) at time zone 'Asia/Ho_Chi_Minh' end as nghi_bat_dau,
      case when ca.break_end is null then null
           else (p_ngay + ca.break_end)   at time zone 'Asia/Ho_Chi_Minh' end as nghi_ket_thuc
    from gom g
  ),
  tinh as (
    select
      m.employee_id,
      m.work_date,
      m.first_in,
      m.last_out,
      -- Trừ đúng PHẦN GIAO với giờ nghỉ, không trừ hằng số 60 phút. Trừ cứng
      -- thì người làm 08:00–12:00 bị tính 3 tiếng trong khi họ làm đủ 4.
      case
        when m.first_in is null or m.last_out is null then 0
        else greatest(
          0,
          floor(extract(epoch from (m.last_out - m.first_in)) / 60)::integer
          - coalesce(
              public.phut_giao_nhau(m.first_in, m.last_out, m.nghi_bat_dau, m.nghi_ket_thuc),
              0
            )
        )
      end as worked_minutes,
      -- Ngoài giờ CHỈ tính phần sau giờ tan ca. Đến sớm không thành ngoài giờ:
      -- nếu tính, ai đến sớm mỗi ngày sẽ tự tạo ra tiền ngoài giờ.
      case when m.last_out is null then 0
           else greatest(0, floor(extract(epoch from (m.last_out - m.ca_ket_thuc)) / 60)::integer)
      end as ot_minutes,
      case when m.first_in is null then 0
           else greatest(0, floor(extract(epoch from (m.first_in - m.ca_bat_dau)) / 60)::integer)
      end as late_minutes,
      case when m.last_out is null then 0
           else greatest(0, floor(extract(epoch from (m.ca_ket_thuc - m.last_out)) / 60)::integer)
      end as early_leave_minutes,
      greatest(
        0,
        floor(extract(epoch from (m.ca_ket_thuc - m.ca_bat_dau)) / 60)::integer
        - coalesce(
            public.phut_giao_nhau(m.ca_bat_dau, m.ca_ket_thuc, m.nghi_bat_dau, m.nghi_ket_thuc),
            0
          )
      ) as phut_chuan
    from moc m
  )
  insert into public.attendance_days as d (
    employee_id, work_date, shift_id, first_in, last_out,
    worked_minutes, ot_minutes, late_minutes, early_leave_minutes,
    status, tong_hop_luc
  )
  select
    t.employee_id, t.work_date, ca.id, t.first_in, t.last_out,
    t.worked_minutes, t.ot_minutes, t.late_minutes, t.early_leave_minutes,
    case
      when t.first_in is null                       then 'nghi'
      -- Có chấm vào mà không có chấm ra: KHÔNG tự đoán giờ về. Đoán là tự
      -- tạo công. Để HR bổ sung tay, có ghi vết.
      when t.last_out is null                       then 'thieu_cham_ra'
      when t.worked_minutes >= t.phut_chuan         then 'du_cong'
      else 'thieu_gio'
    end::public.attendance_day_status,
    now()
  from tinh t
  on conflict (employee_id, work_date) do update set
    shift_id            = excluded.shift_id,
    first_in            = excluded.first_in,
    last_out            = excluded.last_out,
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

comment on function public.tong_hop_cong_ngay(date) is
  'Tổng hợp attendance_logs hợp lệ của một ngày (giờ VN) thành attendance_days. Chạy lại được nhiều lần. Chỉ tính log is_valid = true.';

-- Chỉ HR và admin được gọi tay. Nhân viên gọi được là tự tổng hợp lại công
-- của cả công ty — không có lý do nghiệp vụ nào cần điều đó.
revoke execute on function public.tong_hop_cong_ngay(date) from public, anon, authenticated;

create or replace function public.tong_hop_cong_ngay_cua_toi(p_ngay date)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.can_manage_attendance() then
    raise exception 'Chỉ HR hoặc admin được tổng hợp lại bảng công.';
  end if;
  return public.tong_hop_cong_ngay(p_ngay);
end;
$$;

comment on function public.tong_hop_cong_ngay_cua_toi(date) is
  'Vỏ bọc cho tong_hop_cong_ngay(): kiểm vai trò trước khi chạy. Dùng cho nút "tổng hợp lại" của HR sau khi duyệt log.';

revoke execute on function public.tong_hop_cong_ngay_cua_toi(date) from public, anon;
grant  execute on function public.tong_hop_cong_ngay_cua_toi(date) to authenticated;
