-- =========================================================
-- Làm thêm giờ ngày nghỉ tuần không bị trừ phần trùng giờ hành chính
--
-- LỖI (dò ra 12/08/2026 bằng bộ dữ liệu thử TEST08-):
--
--   Người làm thêm sáng chủ nhật 08:00–12:00 — đúng kiểu đi làm bù thực tế —
--   nhận về 0 PHÚT làm thêm.
--
--   Vì hàm tính giờ làm thêm bằng "tổng thời gian trừ phần chồng lấn với ca
--   hành chính", và nó áp khung ca 08:00–17:00 cho MỌI ngày. Chủ nhật không
--   có ca nào cả, nhưng khung ca vẫn được trừ, nên phần làm trong giờ hành
--   chính biến mất sạch.
--
--   Hệ quả: engine lương có hệ số riêng cho ngày nghỉ tuần (ngay_nghi_tuan_pct,
--   thường 200%) nhưng hệ số đó KHÔNG BAO GIỜ dùng tới được bằng thao tác
--   bình thường — muốn có phút làm thêm chủ nhật thì phải bấm ngoài khung
--   08:00–17:00, tức là làm đêm.
--
-- SỬA: ngày nghỉ tuần thì KHÔNG trừ phần chồng lấn. Cả khoảng đã bấm đều là
-- làm thêm, vì hôm đó vốn không có giờ hành chính nào để mà trùng.
--
-- Ngày nghỉ tuần = chủ nhật (isodow = 7), khớp với cách engine lương chia hệ
-- số: `filter (where extract(isodow from work_date) = 7)`. Thứ bảy vẫn là
-- ngày làm việc bình thường trong mô hình hiện tại.
--
-- CÒN TREO, KHÔNG SỬA Ở ĐÂY: nếu người ta bấm Chấm vào / Chấm ra bình
-- thường vào chủ nhật thì vẫn ra 480 phút giờ làm THƯỜNG, trả 100% thay vì
-- 200%. Sửa chỗ đó là đổi ý nghĩa của "giờ làm thường", cần chốt với người
-- phụ trách trước.
-- =========================================================

create or replace function public.tinh_cong_mot_ngay(
  p_ngay          date,
  p_first_in      timestamptz,
  p_last_out      timestamptz,
  p_ot_in         timestamptz,
  p_ot_out        timestamptz,
  p_ca_bat_dau    time,
  p_ca_ket_thuc   time,
  p_nghi_bat_dau  time,
  p_nghi_ket_thuc time
)
returns table (
  worked_minutes      integer,
  ot_minutes          integer,
  late_minutes        integer,
  early_leave_minutes integer,
  status              public.attendance_day_status
)
language sql
stable
set search_path = ''
as $$
  with moc as (
    select
      (p_ngay + p_ca_bat_dau)  at time zone 'Asia/Ho_Chi_Minh' as ca_bat_dau,
      (p_ngay + p_ca_ket_thuc) at time zone 'Asia/Ho_Chi_Minh' as ca_ket_thuc,
      case when p_nghi_bat_dau is null then null
           else (p_ngay + p_nghi_bat_dau) at time zone 'Asia/Ho_Chi_Minh' end as nghi_bat_dau,
      case when p_nghi_ket_thuc is null then null
           else (p_ngay + p_nghi_ket_thuc) at time zone 'Asia/Ho_Chi_Minh' end as nghi_ket_thuc,
      extract(isodow from p_ngay) = 7 as ngay_nghi_tuan
  ),
  tinh as (
    select
      m.*,
      -- Giờ làm: phần có mặt nằm trong ca, trừ phần nghỉ trưa chồng lấn.
      case when p_first_in is null or p_last_out is null then 0
           else greatest(
             0,
             public.phut_giao_nhau(p_first_in, p_last_out, m.ca_bat_dau, m.ca_ket_thuc)
             - coalesce(public.phut_giao_nhau(p_first_in, p_last_out,
                                              m.nghi_bat_dau, m.nghi_ket_thuc), 0)
           )
      end as worked,
      -- Ngoài giờ: chỉ tính khi có ĐỦ cả hai lần bấm. Thiếu lần bấm ra thì
      -- KHÔNG đoán — đoán là tự tạo tiền ngoài giờ.
      case
        when p_ot_in is null or p_ot_out is null then 0
        -- Ngày nghỉ tuần: cả khoảng đã bấm đều là làm thêm. Hôm đó không có
        -- giờ hành chính nào để mà trừ phần chồng lấn.
        when m.ngay_nghi_tuan then
          greatest(0, floor(extract(epoch from (p_ot_out - p_ot_in)) / 60)::integer)
        else greatest(
          0,
          floor(extract(epoch from (p_ot_out - p_ot_in)) / 60)::integer
          - public.phut_giao_nhau(p_ot_in, p_ot_out, m.ca_bat_dau, m.ca_ket_thuc)
        )
      end as ot,
      case when p_first_in is null then 0
           else greatest(0, floor(extract(epoch from (p_first_in - m.ca_bat_dau)) / 60)::integer)
      end as muon,
      case when p_last_out is null then 0
           else greatest(0, floor(extract(epoch from (m.ca_ket_thuc - p_last_out)) / 60)::integer)
      end as ve_som,
      greatest(
        0,
        floor(extract(epoch from (m.ca_ket_thuc - m.ca_bat_dau)) / 60)::integer
        - coalesce(public.phut_giao_nhau(m.ca_bat_dau, m.ca_ket_thuc,
                                         m.nghi_bat_dau, m.nghi_ket_thuc), 0)
      ) as phut_chuan
    from moc m
  )
  select
    t.worked,
    t.ot,
    t.muon,
    t.ve_som,
    case
      when p_first_in is null            then 'nghi'
      when p_last_out is null            then 'thieu_cham_ra'
      when t.worked >= t.phut_chuan      then 'du_cong'
      else 'thieu_gio'
    end::public.attendance_day_status
  from tinh t;
$$;
