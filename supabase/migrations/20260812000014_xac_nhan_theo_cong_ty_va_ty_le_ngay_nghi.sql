-- =========================================================
-- HAI YÊU CẦU CỦA TRIỆU VŨ, 12/08/2026
--
--   1. "Nhân sự ký hợp đồng với công ty nào sẽ xác nhận cả ngày tại công ty
--      đó" — nút Xác nhận cả ngày đang quét MỌI nhân viên của MỌI pháp nhân.
--   2. "Làm ngày chủ nhật cho phép lựa chọn tỷ lệ % linh động" — hệ số ngày
--      nghỉ tuần đang cố định trong bảng tham số.
-- =========================================================

-- ---------------------------------------------------------
-- 1. Công ty của người đang đăng nhập
--
--    SECURITY DEFINER vì nó đọc employees, mà policy trên employees lại gọi
--    các hàm cùng họ — không định nghĩa như vậy là đệ quy.
-- ---------------------------------------------------------
create or replace function public.current_company_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select e.company_id
  from public.employees e
  where e.id = (select public.current_employee_id());
$$;

comment on function public.current_company_id() is
  'Công ty của người đang đăng nhập, qua hồ sơ nhân sự. NULL khi tài khoản chưa gắn hồ sơ (tài khoản quản trị thuần).';

-- ---------------------------------------------------------
-- 2. Xác nhận cả ngày — chỉ trong phạm vi công ty của người xác nhận
--
--    NULL nghĩa là tài khoản không gắn hồ sơ nhân sự, tức tài khoản quản trị
--    thuần. Người đó xác nhận được toàn hệ thống. KHÔNG để mặc định này im
--    lặng: hàm trả về số dòng, còn màn hình nói rõ đang xác nhận cho công ty
--    nào — xem /cham-cong/xac-nhan.
-- ---------------------------------------------------------
create or replace function public.xac_nhan_cham_cong_ngay(
  p_ngay date,
  p_ghi_chu text default null
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  so_dong integer;
  cty     uuid;
begin
  if not public.can_manage_attendance() then
    raise exception 'Chỉ nhân sự hoặc admin được xác nhận chấm công.';
  end if;

  cty := public.current_company_id();

  update public.attendance_logs l
  set da_xac_nhan      = true,
      xac_nhan_boi     = (select auth.uid()),
      xac_nhan_luc     = now(),
      ghi_chu_xac_nhan = coalesce(p_ghi_chu, l.ghi_chu_xac_nhan)
  where (l.logged_at at time zone 'Asia/Ho_Chi_Minh')::date = p_ngay
    and l.xac_nhan_luc is null
    and l.deleted_at is null
    and (
      cty is null
      or exists (
        select 1 from public.employees e
        where e.id = l.employee_id and e.company_id = cty
      )
    );

  get diagnostics so_dong = row_count;

  -- Tổng hợp lại ngay: xác nhận xong mà bảng công chưa đổi thì người dùng
  -- tưởng nút không ăn. Tổng hợp chạy cho cả ngày, không riêng công ty —
  -- nó là dữ liệu dẫn xuất, tính lại toàn bộ luôn rẻ hơn là tính một phần
  -- rồi phải nhớ phần nào chưa tính.
  perform public.tong_hop_cong_ngay(p_ngay);

  return so_dong;
end;
$$;

revoke execute on function public.xac_nhan_cham_cong_ngay(date, text) from public, anon;
grant execute on function public.xac_nhan_cham_cong_ngay(date, text) to authenticated;

-- ---------------------------------------------------------
-- 3. Tỷ lệ làm thêm linh động cho TỪNG NGÀY của TỪNG NGƯỜI
--
--    NULL = dùng hệ số theo loại ngày trong cfg_overtime_rates (150% ngày
--    thường, 200% ngày nghỉ tuần). Có giá trị = đè lên cho đúng ngày đó của
--    đúng người đó.
--
--    Đặt ở attendance_days chứ không ở cfg: "chủ nhật này trả 250%" là quyết
--    định của một lần cụ thể, không phải chính sách chung. Để ở cfg thì mỗi
--    lần đổi là thêm một dòng hiệu lực và ảnh hưởng ngược về quá khứ.
-- ---------------------------------------------------------
alter table public.attendance_days
  add column ty_le_lam_them_pct numeric(6, 2)
    check (ty_le_lam_them_pct is null or ty_le_lam_them_pct >= 100);

comment on column public.attendance_days.ty_le_lam_them_pct is
  'Tỷ lệ % làm thêm áp riêng cho ngày này. NULL = theo cfg_overtime_rates. Không thấp hơn 100%.';

-- ---------------------------------------------------------
-- 4. Ngày nghỉ tuần: toàn bộ thời gian làm việc là LÀM THÊM
--
--    Trước đây chủ nhật có hai đường và cả hai đều sai:
--      - bấm nút thêm giờ trong giờ hành chính → 0 phút (đã vá ở 0011)
--      - bấm Chấm vào/Chấm ra bình thường → 480 phút giờ làm THƯỜNG, trả
--        100% thay vì 200%, lại cộng thêm một ngày công
--
--    Sửa cho nhất quán: chủ nhật không có ca hành chính nào, nên mọi thời
--    gian làm việc hôm đó đều là làm thêm. Giờ làm thường bằng 0 và ngày đó
--    không cộng vào ngày công.
--
--    LẤY MỘT NGUỒN, KHÔNG CỘNG HAI: nếu bấm đủ cặp thêm giờ thì lấy theo
--    cặp đó; không thì lấy theo cặp vào/ra. Cộng cả hai là đếm trùng khi
--    người ta bấm cả bốn nút, và đếm trùng ở đây là trả thừa tiền.
-- ---------------------------------------------------------
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
      extract(isodow from p_ngay) = 7 as ngay_nghi_tuan,
      -- Khoảng dùng để tính làm thêm NGÀY NGHỈ: ưu tiên cặp nút thêm giờ,
      -- không đủ thì dùng cặp vào/ra. Thiếu một vế thì bỏ, không đoán.
      case when p_ot_in is not null and p_ot_out is not null then p_ot_in
           when p_first_in is not null and p_last_out is not null then p_first_in end as nghi_tu,
      case when p_ot_in is not null and p_ot_out is not null then p_ot_out
           when p_first_in is not null and p_last_out is not null then p_last_out end as nghi_den
  ),
  tinh as (
    select
      m.*,
      case
        -- Ngày nghỉ tuần không có giờ hành chính, nên không có giờ làm thường.
        when m.ngay_nghi_tuan then 0
        when p_first_in is null or p_last_out is null then 0
        else greatest(
          0,
          public.phut_giao_nhau(p_first_in, p_last_out, m.ca_bat_dau, m.ca_ket_thuc)
          - coalesce(public.phut_giao_nhau(p_first_in, p_last_out,
                                           m.nghi_bat_dau, m.nghi_ket_thuc), 0)
        )
      end as worked,
      case
        when m.ngay_nghi_tuan then
          case when m.nghi_tu is null then 0
               else greatest(
                 0,
                 floor(extract(epoch from (m.nghi_den - m.nghi_tu)) / 60)::integer
                 - coalesce(public.phut_giao_nhau(m.nghi_tu, m.nghi_den,
                                                  m.nghi_bat_dau, m.nghi_ket_thuc), 0)
               )
          end
        -- Ngày thường: chỉ tính khi có ĐỦ cả hai lần bấm thêm giờ. Thiếu một
        -- lần bấm thì KHÔNG đoán — đoán là tự tạo tiền ngoài giờ.
        when p_ot_in is null or p_ot_out is null then 0
        else greatest(
          0,
          floor(extract(epoch from (p_ot_out - p_ot_in)) / 60)::integer
          - public.phut_giao_nhau(p_ot_in, p_ot_out, m.ca_bat_dau, m.ca_ket_thuc)
        )
      end as ot,
      case when p_first_in is null or m.ngay_nghi_tuan then 0
           else greatest(0, floor(extract(epoch from (p_first_in - m.ca_bat_dau)) / 60)::integer)
      end as muon,
      case when p_last_out is null or m.ngay_nghi_tuan then 0
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
      when t.ngay_nghi_tuan and t.ot > 0     then 'lam_ngay_nghi'
      when t.ngay_nghi_tuan                  then 'nghi'
      when p_first_in is null                then 'nghi'
      when p_last_out is null                then 'thieu_cham_ra'
      when t.worked >= t.phut_chuan          then 'du_cong'
      else 'thieu_gio'
    end::public.attendance_day_status
  from tinh t;
$$;

-- ---------------------------------------------------------
-- 5. Tổng hợp lại KHÔNG được xoá tỷ lệ do người dùng đặt
--
--    `ty_le_lam_them_pct` là số người ta gõ tay, không phải số dẫn xuất.
--    Nếu đưa nó vào danh sách DO UPDATE SET thì mỗi lần tổng hợp lại — mà
--    tổng hợp chạy mỗi đêm — tỷ lệ đã chọn bị thổi bay về NULL và tiền lương
--    lặng lẽ quay về hệ số mặc định.
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
  select * into ca from public.work_shifts where is_active order by code limit 1;
  if not found then
    raise exception 'Chưa khai báo ca làm việc nào — không tổng hợp công được.';
  end if;

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
    -- ty_le_lam_them_pct CỐ Ý không có ở đây. Xem ghi chú mục 5.

  get diagnostics so_dong = row_count;
  return so_dong;
end;
$$;

revoke execute on function public.tong_hop_cong_ngay(date) from public, anon, authenticated;
