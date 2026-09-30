-- =========================================================
-- P2b — Điều chỉnh chấm công theo yêu cầu 11/08/2026
--
-- Bốn thay đổi Triệu Vũ yêu cầu:
--   1. Bỏ địa điểm chấm công (không còn kiểm tra GPS / bán kính).
--   2. Ảnh chấm công thành TUỲ CHỌN, đính kèm được chứ không bắt buộc.
--   3. Lần chấm chỉ được tính công khi NHÂN SỰ XÁC NHẬN.
--   4. Bật/tắt chấm công cho từng nhân viên, do đặc thù công việc.
--
-- Hai hệ quả phải xử lý cùng lúc, nếu bỏ qua là tính sai tiền:
--
--   • Người được MIỄN chấm công sẽ không có dòng nào trong attendance_days,
--     nên engine lương tính ra 0 ngày công và trả 0 đồng. Phải cho họ đủ
--     ngày công chuẩn của kỳ. Xử lý ở mục 6.
--
--   • `is_valid` trước đây nghĩa là "hệ thống thấy hợp lệ", giờ nghĩa là
--     "nhân sự đã xác nhận" — khác hẳn. Giữ nguyên tên cũ sẽ khiến người đọc
--     code sau này hiểu sai, nên đổi tên tường minh. Chưa có dữ liệu thật nên
--     đổi tên lúc này không mất gì.
-- =========================================================

-- ---------------------------------------------------------
-- 1. Bật/tắt chấm công cho từng nhân viên
--
--    Mặc định TRUE: thêm người mới thì mặc định phải chấm công. Miễn là
--    ngoại lệ, và ngoại lệ thì phải do người ta chủ động chọn.
-- ---------------------------------------------------------
alter table public.employees
  add column theo_doi_cham_cong boolean not null default true;

comment on column public.employees.theo_doi_cham_cong is
  'Nhân viên này có phải chấm công không. FALSE = miễn do đặc thù công việc; engine lương tính đủ ngày công chuẩn cho họ.';

-- ---------------------------------------------------------
-- 2. Bỏ toàn bộ phần địa điểm và GPS
--
--    Bỏ luôn việc THU THẬP toạ độ, không chỉ bỏ việc kiểm tra. Không còn
--    dùng để đối chiếu thì giữ lại là thu thập dữ liệu cá nhân không có mục
--    đích — trái nguyên tắc tối thiểu của NĐ 13/2023.
--
--    Dropping cột cũng tự bỏ các ràng buộc CHECK liên quan (toạ độ hợp lệ,
--    khoảng cách không âm).
-- ---------------------------------------------------------
alter table public.attendance_logs
  drop column latitude,
  drop column longitude,
  drop column accuracy_m,
  drop column distance_m,
  drop column office_id,
  -- Lý do "không hợp lệ" do máy sinh ra không còn nghĩa lý gì khi máy không
  -- còn phán xét nữa. Ghi chú của người xác nhận thay chỗ nó.
  drop column ly_do_khong_hop_le;

drop table public.office_locations;

-- ---------------------------------------------------------
-- 3. Đổi tên cho đúng nghĩa mới
--
--    is_valid (máy phán) -> da_xac_nhan (người xác nhận).
-- ---------------------------------------------------------
alter table public.attendance_logs rename column is_valid      to da_xac_nhan;
alter table public.attendance_logs rename column duyet_boi     to xac_nhan_boi;
alter table public.attendance_logs rename column duyet_luc     to xac_nhan_luc;
alter table public.attendance_logs rename column ghi_chu_duyet to ghi_chu_xac_nhan;

alter table public.attendance_logs
  rename constraint att_log_duyet_du_doi to att_log_xac_nhan_du_doi;

comment on column public.attendance_logs.da_xac_nhan is
  'Nhân sự đã xác nhận lần chấm này chưa. Chỉ log đã xác nhận mới được tính công.';

-- Hàng đợi xác nhận của nhân sự: mọi lần chấm chưa ai đụng tới.
drop index if exists public.idx_att_logs_cho_duyet;
create index idx_att_logs_cho_xac_nhan
  on public.attendance_logs (logged_at desc)
  where da_xac_nhan = false and xac_nhan_luc is null;

comment on table public.attendance_logs is
  'Log thô mỗi lần bấm chấm công. logged_at do SERVER đặt. Ảnh kèm là tuỳ chọn. Chỉ Edge Function được insert, và chỉ nhân sự xác nhận thì mới được tính công.';

-- ---------------------------------------------------------
-- 4. Quyền cấp cột — cấp lại theo tên mới
--
--    Rename tự mang quyền theo, nhưng viết lại tường minh để người đọc file
--    này thấy đúng danh sách cột mà nhân sự được sửa. Vẫn KHÔNG cho sửa
--    logged_at, check_type, employee_id: sửa được thì log không còn là bằng
--    chứng công.
-- ---------------------------------------------------------
revoke update on public.attendance_logs from authenticated;
grant update (da_xac_nhan, xac_nhan_boi, xac_nhan_luc, ghi_chu_xac_nhan)
  on public.attendance_logs to authenticated;

-- ---------------------------------------------------------
-- 5. Tổng hợp công — chỉ đếm lần chấm ĐÃ XÁC NHẬN
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

  with log_trong_ngay as (
    select
      l.employee_id,
      (l.logged_at at time zone 'Asia/Ho_Chi_Minh')::date as work_date,
      l.check_type,
      l.logged_at
    from public.attendance_logs l
    where l.da_xac_nhan
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
      when t.first_in is null                then 'nghi'
      when t.last_out is null                then 'thieu_cham_ra'
      when t.worked_minutes >= t.phut_chuan  then 'du_cong'
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

revoke execute on function public.tong_hop_cong_ngay(date) from public, anon, authenticated;

-- ---------------------------------------------------------
-- 6. Xác nhận hàng loạt
--
--    Nếu mọi lần chấm đều cần xác nhận thì với 50 nhân viên chấm 2 lần/ngày
--    là 100 lần bấm mỗi ngày. Không có hàm này thì tính năng xác nhận không
--    dùng được trong thực tế, và người ta sẽ tìm cách lách.
--
--    Xác nhận theo NGÀY: nhân sự nhìn bảng công một ngày, thấy hợp lý thì
--    xác nhận cả ngày. Vẫn ghi vết ai xác nhận và lúc nào trên từng dòng.
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
begin
  if not public.can_manage_attendance() then
    raise exception 'Chỉ nhân sự hoặc admin được xác nhận chấm công.';
  end if;

  update public.attendance_logs
  set da_xac_nhan      = true,
      xac_nhan_boi     = auth.uid(),
      xac_nhan_luc     = now(),
      ghi_chu_xac_nhan = coalesce(p_ghi_chu, ghi_chu_xac_nhan)
  where (logged_at at time zone 'Asia/Ho_Chi_Minh')::date = p_ngay
    and xac_nhan_luc is null;

  get diagnostics so_dong = row_count;

  -- Tổng hợp lại ngay: xác nhận xong mà bảng công chưa đổi thì người dùng
  -- tưởng nút không ăn.
  perform public.tong_hop_cong_ngay(p_ngay);

  return so_dong;
end;
$$;

comment on function public.xac_nhan_cham_cong_ngay(date, text) is
  'Xác nhận toàn bộ lần chấm chưa xử lý của một ngày (giờ VN), rồi tổng hợp lại bảng công ngày đó.';

revoke execute on function public.xac_nhan_cham_cong_ngay(date, text) from public, anon;
grant  execute on function public.xac_nhan_cham_cong_ngay(date, text) to authenticated;

-- ---------------------------------------------------------
-- 7. Engine lương — người MIỄN chấm công hưởng đủ ngày công chuẩn
--
--    Đây là hệ quả bắt buộc phải xử lý của thay đổi số 4. Không có nó thì
--    người được miễn chấm công không có dòng nào trong attendance_days, ra
--    0 ngày công, và bảng lương trả họ 0 đồng.
-- ---------------------------------------------------------
create or replace function public.tinh_luong_ky(p_period_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  ky          public.payroll_periods%rowtype;
  ngay_cuoi   date;
  bh          public.cfg_insurance_rates%rowtype;
  gt          public.cfg_pit_deductions%rowtype;
  ot          public.cfg_overtime_rates%rowtype;
  luong_co_so numeric;
  phut_chuan_ngay integer;
  nv          record;
  so_phieu    integer := 0;
  snapshot    jsonb;
begin
  select * into ky from public.payroll_periods where id = p_period_id;
  if not found then
    raise exception 'Không tìm thấy kỳ lương %.', p_period_id;
  end if;
  if ky.status <> 'mo' then
    raise exception 'Kỳ lương %/% đã chốt — không tính lại được. Muốn sửa thì mở kỳ điều chỉnh mới.',
      ky.month, ky.year;
  end if;

  ngay_cuoi := (make_date(ky.year, ky.month, 1) + interval '1 month - 1 day')::date;

  select * into bh from public.cfg_insurance_rates
   where effective_from <= ngay_cuoi order by effective_from desc limit 1;
  if not found then
    raise exception 'Chưa có tỷ lệ bảo hiểm hiệu lực tới %. Nhập cfg_insurance_rates trước.', ngay_cuoi;
  end if;

  select * into gt from public.cfg_pit_deductions
   where effective_from <= ngay_cuoi order by effective_from desc limit 1;
  if not found then
    raise exception 'Chưa có mức giảm trừ gia cảnh hiệu lực tới %. Nhập cfg_pit_deductions trước.', ngay_cuoi;
  end if;

  select amount into luong_co_so from public.cfg_base_salary
   where effective_from <= ngay_cuoi order by effective_from desc limit 1;
  if luong_co_so is null then
    raise exception 'Chưa có lương cơ sở hiệu lực tới %. Nhập cfg_base_salary trước.', ngay_cuoi;
  end if;

  select * into ot from public.cfg_overtime_rates
   where effective_from <= ngay_cuoi order by effective_from desc limit 1;

  select greatest(
           1,
           floor(extract(epoch from (s.end_time - s.start_time)) / 60)::integer
           - case when s.break_start is null then 0
                  else floor(extract(epoch from (s.break_end - s.break_start)) / 60)::integer end
         )
    into phut_chuan_ngay
  from public.work_shifts s
  where s.is_active order by s.code limit 1;

  if phut_chuan_ngay is null then
    raise exception 'Chưa khai báo ca làm việc — không quy đổi được phút công thành ngày công.';
  end if;

  snapshot := jsonb_build_object(
    'ngay_cuoi_ky',      ngay_cuoi,
    'bao_hiem',          to_jsonb(bh),
    'giam_tru',          to_jsonb(gt),
    'luong_co_so',       luong_co_so,
    'lam_them',          to_jsonb(ot),
    'phut_chuan_ngay',   phut_chuan_ngay,
    'ngay_cong_chuan',   ky.standard_days,
    'bieu_thue_tu_ngay', (select max(effective_from) from public.cfg_pit_brackets
                           where effective_from <= ngay_cuoi),
    'bieu_thue',         (select jsonb_agg(to_jsonb(b) order by b.level)
                          from public.cfg_pit_brackets b
                          where b.effective_from = (select max(effective_from)
                                                    from public.cfg_pit_brackets
                                                    where effective_from <= ngay_cuoi))
  );

  for nv in
    select
      e.id                        as employee_id,
      e.employee_code,
      e.full_name,
      e.region,
      e.theo_doi_cham_cong,
      lc.position_salary,
      lc.bhxh_salary,
      lc.allowances,
      coalesce(cong.phut_lam, 0)  as phut_lam,
      coalesce(cong.phut_ot, 0)   as phut_ot,
      coalesce(pt.so_nguoi, 0)    as so_nguoi_phu_thuoc
    from public.employees e
    join public.labor_contracts lc
      on lc.employee_id = e.id and lc.is_active
    left join lateral (
      select sum(d.worked_minutes) as phut_lam, sum(d.ot_minutes) as phut_ot
      from public.attendance_days d
      where d.employee_id = e.id
        and d.work_date between make_date(ky.year, ky.month, 1) and ngay_cuoi
    ) cong on true
    left join lateral (
      select count(*) as so_nguoi
      from public.dependents dp
      where dp.employee_id = e.id
    ) pt on true
    where e.status in ('thu_viec', 'chinh_thuc')
  loop
    declare
      ngay_cong        numeric;
      ngay_nghi        numeric;
      co_dong_bh       boolean;
      ty_le            numeric;
      luong_theo_cong  numeric;
      phu_cap_tong     numeric := 0;
      phu_cap_chiu_thue numeric := 0;
      phu_cap_dong_bh  numeric := 0;
      tien_ot          numeric := 0;
      gross            numeric;
      nen_bhxh         numeric;
      nen_bhtn         numeric;
      luong_toi_thieu  numeric;
      bhxh_nv numeric := 0; bhyt_nv numeric := 0; bhtn_nv numeric := 0;
      bhxh_cty numeric := 0; bhyt_cty numeric := 0; bhtn_cty numeric := 0;
      tn_chiu_thue     numeric;
      gt_ban_than      numeric;
      gt_phu_thuoc     numeric;
      tn_tinh_thue     numeric;
      thue             numeric;
      net              numeric;
      phieu_id         uuid;
      pc               jsonb;
    begin
      -- Người được MIỄN chấm công hưởng đủ ngày công chuẩn. Không có nhánh
      -- này thì họ ra 0 ngày công và bảng lương trả họ 0 đồng.
      if nv.theo_doi_cham_cong then
        ngay_cong := round(nv.phut_lam::numeric / phut_chuan_ngay, 2);
      else
        ngay_cong := ky.standard_days;
      end if;

      ty_le := least(1, ngay_cong / ky.standard_days);
      luong_theo_cong := round(nv.position_salary * ty_le);

      for pc in select * from jsonb_array_elements(coalesce(nv.allowances, '[]'::jsonb))
      loop
        phu_cap_tong := phu_cap_tong + coalesce((pc->>'amount')::numeric, 0);
        if coalesce((pc->>'taxable')::boolean, true) then
          phu_cap_chiu_thue := phu_cap_chiu_thue + coalesce((pc->>'amount')::numeric, 0);
        end if;
        if coalesce((pc->>'insurance')::boolean, false) then
          phu_cap_dong_bh := phu_cap_dong_bh + coalesce((pc->>'amount')::numeric, 0);
        end if;
      end loop;

      -- Người miễn chấm công không có số liệu làm thêm giờ. Muốn trả thêm
      -- giờ cho họ thì kế toán thêm dòng thưởng tay — có người quyết định,
      -- không phải hệ thống tự suy ra từ chỗ không có dữ liệu.
      if nv.theo_doi_cham_cong and nv.phut_ot > 0 then
        if ot.id is null then
          raise exception
            'Nhân viên % (%) có % phút làm thêm nhưng chưa có hệ số làm thêm giờ hiệu lực tới %. Nhập cfg_overtime_rates trước.',
            nv.full_name, nv.employee_code, nv.phut_ot, ngay_cuoi;
        end if;
        tien_ot := round(
          (nv.position_salary / ky.standard_days / (phut_chuan_ngay / 60.0))
          * (nv.phut_ot / 60.0)
          * ot.ngay_thuong_pct / 100
        );
      end if;

      gross := luong_theo_cong + phu_cap_tong + tien_ot;

      ngay_nghi := greatest(0, ky.standard_days - ngay_cong);
      co_dong_bh := bh.nghi_khong_luong_mien_dong_ngay is null
                    or ngay_nghi < bh.nghi_khong_luong_mien_dong_ngay;

      if co_dong_bh then
        nen_bhxh := least(nv.bhxh_salary + phu_cap_dong_bh, luong_co_so * bh.bhxh_cap_multiple);

        select amount into luong_toi_thieu
        from public.cfg_region_min_wage
        where effective_from <= ngay_cuoi and region = coalesce(nv.region, 1)
        order by effective_from desc limit 1;

        if luong_toi_thieu is null then
          raise exception
            'Chưa có lương tối thiểu vùng % hiệu lực tới %. Nhập cfg_region_min_wage trước.',
            coalesce(nv.region, 1), ngay_cuoi;
        end if;

        nen_bhtn := least(nv.bhxh_salary + phu_cap_dong_bh, luong_toi_thieu * bh.bhtn_cap_multiple);

        bhxh_nv  := round(nen_bhxh * bh.bhxh_employee_pct / 100);
        bhyt_nv  := round(nen_bhxh * bh.bhyt_employee_pct / 100);
        bhtn_nv  := round(nen_bhtn * bh.bhtn_employee_pct / 100);
        bhxh_cty := round(nen_bhxh * bh.bhxh_employer_pct / 100);
        bhyt_cty := round(nen_bhxh * bh.bhyt_employer_pct / 100);
        bhtn_cty := round(nen_bhtn * bh.bhtn_employer_pct / 100);
      end if;

      tn_chiu_thue := gross - (phu_cap_tong - phu_cap_chiu_thue) - (bhxh_nv + bhyt_nv + bhtn_nv);
      gt_ban_than  := gt.personal_amount;
      gt_phu_thuoc := gt.dependent_amount * nv.so_nguoi_phu_thuoc;
      tn_tinh_thue := tn_chiu_thue - gt_ban_than - gt_phu_thuoc;

      thue := public.thue_tncn(tn_tinh_thue, ngay_cuoi);
      net  := gross - (bhxh_nv + bhyt_nv + bhtn_nv) - thue;

      if net < 0 then
        raise exception
          'Lương thực nhận của % (%) ra số âm: %. Kiểm lại ngày công, ngưỡng miễn đóng bảo hiểm, hoặc lương hợp đồng.',
          nv.full_name, nv.employee_code, net;
      end if;

      insert into public.payslips as ps (
        period_id, employee_id, worked_days, gross_salary,
        bhxh_employee, bhyt_employee, bhtn_employee,
        bhxh_employer, bhyt_employer, bhtn_employer,
        taxable_income, personal_deduction, dependent_deduction,
        assessable_income, pit, net_salary, cfg_snapshot, tinh_luc
      )
      values (
        p_period_id, nv.employee_id, ngay_cong, gross,
        bhxh_nv, bhyt_nv, bhtn_nv, bhxh_cty, bhyt_cty, bhtn_cty,
        greatest(0, tn_chiu_thue), gt_ban_than, gt_phu_thuoc,
        greatest(0, tn_tinh_thue), thue, net, snapshot, now()
      )
      on conflict (period_id, employee_id) do update set
        worked_days         = excluded.worked_days,
        gross_salary        = excluded.gross_salary,
        bhxh_employee       = excluded.bhxh_employee,
        bhyt_employee       = excluded.bhyt_employee,
        bhtn_employee       = excluded.bhtn_employee,
        bhxh_employer       = excluded.bhxh_employer,
        bhyt_employer       = excluded.bhyt_employer,
        bhtn_employer       = excluded.bhtn_employer,
        taxable_income      = excluded.taxable_income,
        personal_deduction  = excluded.personal_deduction,
        dependent_deduction = excluded.dependent_deduction,
        assessable_income   = excluded.assessable_income,
        pit                 = excluded.pit,
        net_salary          = excluded.net_salary,
        cfg_snapshot        = excluded.cfg_snapshot,
        tinh_luc            = excluded.tinh_luc
      returning ps.id into phieu_id;

      delete from public.payslip_items where payslip_id = phieu_id;

      insert into public.payslip_items (payslip_id, item_type, name, amount, is_taxable, is_insurance)
      select
        phieu_id, 'phu_cap',
        coalesce(pc2->>'name', 'Phụ cấp'),
        coalesce((pc2->>'amount')::numeric, 0),
        coalesce((pc2->>'taxable')::boolean, true),
        coalesce((pc2->>'insurance')::boolean, false)
      from jsonb_array_elements(coalesce(nv.allowances, '[]'::jsonb)) as pc2;

      if tien_ot > 0 then
        insert into public.payslip_items (payslip_id, item_type, name, amount, is_taxable, is_insurance)
        values (phieu_id, 'thuong', format('Làm thêm %s phút', nv.phut_ot), tien_ot, true, false);
      end if;

      if not nv.theo_doi_cham_cong then
        insert into public.payslip_items (payslip_id, item_type, name, amount, is_taxable, is_insurance)
        values (phieu_id, 'phu_cap', 'Miễn chấm công — hưởng đủ ngày công chuẩn', 0, false, false);
      end if;

      if not co_dong_bh then
        insert into public.payslip_items (payslip_id, item_type, name, amount, is_taxable, is_insurance)
        values (phieu_id, 'khau_tru',
                format('Không đóng bảo hiểm tháng này (nghỉ %s ngày)', ngay_nghi), 0, false, false);
      end if;

      so_phieu := so_phieu + 1;
    end;
  end loop;

  return so_phieu;
end;
$$;

revoke execute on function public.tinh_luong_ky(uuid) from public, anon, authenticated;
