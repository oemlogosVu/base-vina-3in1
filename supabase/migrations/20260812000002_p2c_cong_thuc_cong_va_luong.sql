-- =========================================================
-- P2c — Công thức tính công theo mô hình chấm thêm giờ tường minh,
--       và engine lương tách theo công ty
-- =========================================================

-- ---------------------------------------------------------
-- 1. Tách phép tính công MỘT NGÀY thành hàm gọi được riêng
--
--    Trước đây công thức nằm lẫn trong thân tong_hop_cong_ngay(), nên bộ
--    kiểm tra chỉ soi được nó gián tiếp qua dữ liệu thật, và có thêm một bản
--    sao bằng TypeScript để test đơn vị. Hai bản đã từng lệch nhau một lần
--    (ceil vs floor) — đúng cái bẫy mà ghi chú của chính chúng nói phải tránh.
--
--    Tách ra thành hàm thì bộ kiểm tra soi thẳng vào công thức THẬT, và bản
--    sao TypeScript không còn lý do tồn tại.
--
-- ĐỊNH NGHĨA MỚI CỦA GIỜ LÀM, đổi theo yêu cầu 12/08:
--
--    worked = phần có mặt NẰM TRONG ca − phần nghỉ trưa chồng lấn
--
--    Trước đây là (ra − vào) − nghỉ, không cắt theo ca. Đổi vì giờ đã có chấm
--    thêm giờ tường minh: ai ở lại tới 19:00 mà không bấm thêm giờ thì phần
--    sau 17:00 không được tính vào đâu cả — không thành giờ làm, cũng không
--    thành ngoài giờ. Giữ cách cũ là trả tiền cho việc nán lại.
--
--    ot = phần giữa hai lần bấm thêm giờ, TRỪ phần chồng lấn với ca. Trừ để
--    phòng trường hợp bấm nhầm thêm giờ trong giờ hành chính — không thì một
--    cú bấm nhầm thành trả tiền hai lần cho cùng một khoảng.
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
           else (p_ngay + p_nghi_ket_thuc) at time zone 'Asia/Ho_Chi_Minh' end as nghi_ket_thuc
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
      case when p_ot_in is null or p_ot_out is null then 0
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

comment on function public.tinh_cong_mot_ngay is
  'Công thức tính công một ngày. Bản cài đặt DUY NHẤT — bộ kiểm tra gọi thẳng hàm này, không qua bản sao nào.';

-- ---------------------------------------------------------
-- 2. Tổng hợp công, dùng hàm trên
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

  with gom as (
    select
      l.employee_id,
      min(l.logged_at) filter (where l.check_type = 'in')     as first_in,
      max(l.logged_at) filter (where l.check_type = 'out')    as last_out,
      min(l.logged_at) filter (where l.check_type = 'ot_in')  as ot_in,
      max(l.logged_at) filter (where l.check_type = 'ot_out') as ot_out
    from public.attendance_logs l
    where l.da_xac_nhan
      and (l.logged_at at time zone 'Asia/Ho_Chi_Minh')::date = p_ngay
    group by l.employee_id
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

-- ---------------------------------------------------------
-- 3. Engine lương: tách theo công ty, và hệ số ngoài giờ theo loại ngày
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
  thieu_cong_ty text;
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

  -- Nhân viên chưa gán công ty sẽ không thuộc kỳ lương nào, tức bị bỏ sót
  -- khỏi bảng lương mà KHÔNG AI THẤY. Từ chối tính và nêu tên, thay vì lặng
  -- lẽ trả lương thiếu người.
  select string_agg(e.full_name || ' (' || e.employee_code || ')', ', ' order by e.employee_code)
    into thieu_cong_ty
  from public.employees e
  join public.labor_contracts lc on lc.employee_id = e.id and lc.is_active
  where e.status in ('thu_viec', 'chinh_thuc') and e.company_id is null;

  if thieu_cong_ty is not null then
    raise exception
      'Những nhân viên sau chưa được gán công ty nên sẽ bị bỏ sót khỏi mọi bảng lương: %. Gán công ty cho họ trước khi tính.',
      thieu_cong_ty;
  end if;

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
    'cong_ty',           (select to_jsonb(c) from public.companies c where c.id = ky.company_id),
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
      e.id as employee_id, e.employee_code, e.full_name, e.region, e.theo_doi_cham_cong,
      lc.position_salary, lc.bhxh_salary, lc.allowances,
      coalesce(cong.phut_lam, 0)     as phut_lam,
      coalesce(cong.ot_thuong, 0)    as ot_thuong,
      coalesce(cong.ot_chu_nhat, 0)  as ot_chu_nhat,
      coalesce(pt.so_nguoi, 0)       as so_nguoi_phu_thuoc
    from public.employees e
    join public.labor_contracts lc on lc.employee_id = e.id and lc.is_active
    left join lateral (
      select
        sum(d.worked_minutes) as phut_lam,
        -- Ngoài giờ chủ nhật hưởng hệ số khác ngày thường. Ngày lễ cần bảng
        -- lịch nghỉ lễ, thuộc phase sau — tới lúc đó kế toán điều chỉnh tay.
        sum(d.ot_minutes) filter (where extract(isodow from d.work_date) <> 7) as ot_thuong,
        sum(d.ot_minutes) filter (where extract(isodow from d.work_date)  = 7) as ot_chu_nhat
      from public.attendance_days d
      where d.employee_id = e.id
        and d.work_date between make_date(ky.year, ky.month, 1) and ngay_cuoi
    ) cong on true
    left join lateral (
      select count(*) as so_nguoi from public.dependents dp where dp.employee_id = e.id
    ) pt on true
    where e.status in ('thu_viec', 'chinh_thuc')
      -- CHỈ nhân viên của công ty thuộc kỳ lương này.
      and e.company_id = ky.company_id
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
      don_gia_gio      numeric;
      tien_ot          numeric := 0;
      tong_phut_ot     integer;
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

      tong_phut_ot := nv.ot_thuong + nv.ot_chu_nhat;

      if nv.theo_doi_cham_cong and tong_phut_ot > 0 then
        if ot.id is null then
          raise exception
            'Nhân viên % (%) có % phút làm thêm nhưng chưa có hệ số làm thêm giờ hiệu lực tới %. Nhập cfg_overtime_rates trước.',
            nv.full_name, nv.employee_code, tong_phut_ot, ngay_cuoi;
        end if;
        don_gia_gio := nv.position_salary / ky.standard_days / (phut_chuan_ngay / 60.0);
        tien_ot := round(
          don_gia_gio * (
            (nv.ot_thuong    / 60.0) * ot.ngay_thuong_pct    / 100
          + (nv.ot_chu_nhat  / 60.0) * ot.ngay_nghi_tuan_pct / 100
          )
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
        values (
          phieu_id, 'thuong',
          format('Làm thêm: %s phút ngày thường, %s phút chủ nhật', nv.ot_thuong, nv.ot_chu_nhat),
          tien_ot, true, false
        );
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
