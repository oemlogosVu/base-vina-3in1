-- =========================================================
-- Engine lương: hệ số làm thêm theo TỪNG NGÀY
--
-- Yêu cầu 12/08/2026: "làm ngày chủ nhật cho phép lựa chọn tỷ lệ % linh
-- động".
--
-- Trước đây engine gộp phút làm thêm thành hai nhóm — ngày thường và chủ
-- nhật — rồi nhân mỗi nhóm một hệ số lấy từ cfg_overtime_rates. Cách gộp đó
-- không chừa chỗ nào để đặt tỷ lệ riêng cho một ngày cụ thể.
--
-- Nay mỗi ngày tự nhân hệ số của chính nó rồi mới cộng lại thành GIỜ QUY
-- ĐỔI. Thứ tự lấy hệ số:
--     attendance_days.ty_le_lam_them_pct  (đặt tay cho đúng ngày đó)
--  → cfg_overtime_rates.ngay_nghi_tuan_pct nếu là chủ nhật
--  → cfg_overtime_rates.ngay_thuong_pct
--
-- Sinh ra TỪ migration 20260812000007 rồi vá đúng bảy chỗ, không gõ lại.
-- =========================================================

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
  pct_thuong    numeric;
  pct_ngay_nghi numeric;
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

  select string_agg(e.full_name || ' (' || e.employee_code || ')', ', ' order by e.employee_code)
    into thieu_cong_ty
  from public.employees e
  join public.labor_contracts lc on lc.employee_id = e.id and lc.is_active
  where e.status in ('thu_viec', 'chinh_thuc')
    and e.company_id is null
    and e.deleted_at is null;

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

  -- Tách sang biến vô hướng thay vì dùng thẳng ot.<cột> trong câu SQL lồng
  -- bên dưới: trong ngữ cảnh đó "ot" cũng có thể bị đọc thành bí danh bảng,
  -- và lỗi kiểu ấy chỉ lộ ra lúc chạy.
  pct_thuong    := ot.ngay_thuong_pct;
  pct_ngay_nghi := ot.ngay_nghi_tuan_pct;

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
      lc.position_salary, lc.bhxh_salary,
      -- Phụ cấp đã gộp: chức danh làm mặc định, hợp đồng ghi đè theo mã loại.
      public.phu_cap_cua_nhan_vien(e.position_id, lc.allowances) as phu_cap,
      coalesce(cong.phut_lam, 0)       as phut_lam,
      coalesce(cong.phut_ot, 0)        as phut_ot,
      coalesce(cong.gio_ot_quy_doi, 0) as gio_ot_quy_doi,
      coalesce(pt.so_nguoi, 0)       as so_nguoi_phu_thuoc
    from public.employees e
    join public.labor_contracts lc on lc.employee_id = e.id and lc.is_active
    left join lateral (
      select
        sum(d.worked_minutes) as phut_lam,
        sum(d.ot_minutes)     as phut_ot,
        -- GIỜ QUY ĐỔI: mỗi ngày nhân hệ số của CHÍNH NGÀY ĐÓ rồi mới cộng.
        -- Bản trước gộp phút thành hai nhóm (ngày thường / chủ nhật) rồi nhân
        -- một hệ số cho cả nhóm — cách đó không có chỗ nào để đặt tỷ lệ riêng
        -- cho một ngày cụ thể.
        sum(
          d.ot_minutes / 60.0
          * coalesce(
              d.ty_le_lam_them_pct,
              case when extract(isodow from d.work_date) = 7
                   then pct_ngay_nghi else pct_thuong end
            ) / 100
        ) as gio_ot_quy_doi
      from public.attendance_days d
      where d.employee_id = e.id
        and d.work_date between make_date(ky.year, ky.month, 1) and ngay_cuoi
    ) cong on true
    left join lateral (
      select count(*) as so_nguoi from public.dependents dp where dp.employee_id = e.id
    ) pt on true
    where e.status in ('thu_viec', 'chinh_thuc')
      and e.company_id = ky.company_id
      -- Hồ sơ đã xoá mềm KHÔNG có phiếu lương. Engine chạy SECURITY DEFINER
      -- nên nó bỏ qua RLS, tức là policy ẩn dòng đã xoá KHÔNG che được nó —
      -- phải lọc tường minh ở đây.
      and e.deleted_at is null
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

      for pc in select * from jsonb_array_elements(nv.phu_cap)
      loop
        phu_cap_tong := phu_cap_tong + coalesce((pc->>'amount')::numeric, 0);
        if coalesce((pc->>'taxable')::boolean, true) then
          phu_cap_chiu_thue := phu_cap_chiu_thue + coalesce((pc->>'amount')::numeric, 0);
        end if;
        if coalesce((pc->>'insurance')::boolean, false) then
          phu_cap_dong_bh := phu_cap_dong_bh + coalesce((pc->>'amount')::numeric, 0);
        end if;
      end loop;

      tong_phut_ot := nv.phut_ot;

      if nv.theo_doi_cham_cong and tong_phut_ot > 0 then
        if ot.id is null then
          raise exception
            'Nhân viên % (%) có % phút làm thêm nhưng chưa có hệ số làm thêm giờ hiệu lực tới %. Nhập cfg_overtime_rates trước.',
            nv.full_name, nv.employee_code, tong_phut_ot, ngay_cuoi;
        end if;
        don_gia_gio := nv.position_salary / ky.standard_days / (phut_chuan_ngay / 60.0);
        tien_ot := round(don_gia_gio * nv.gio_ot_quy_doi);
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
        greatest(0, tn_tinh_thue), thue, net,
        -- Chụp luôn danh sách phụ cấp đã gộp: sang năm nếu ai đổi mức phụ cấp
        -- của chức danh thì vẫn dựng lại được vì sao phiếu này ra con số đó.
        snapshot || jsonb_build_object('phu_cap', nv.phu_cap),
        now()
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

      -- Ghi rõ NGUỒN của từng dòng phụ cấp. Kế toán nhìn phiếu là biết khoản
      -- này đến từ chức danh hay từ hợp đồng riêng, không phải đi tra ngược.
      insert into public.payslip_items (payslip_id, item_type, name, amount, is_taxable, is_insurance)
      select
        phieu_id, 'phu_cap',
        (pc2->>'name') || case when pc2->>'nguon' = 'chuc_danh'
                               then ' (theo chức danh)' else ' (theo hợp đồng)' end,
        coalesce((pc2->>'amount')::numeric, 0),
        coalesce((pc2->>'taxable')::boolean, true),
        coalesce((pc2->>'insurance')::boolean, false)
      from jsonb_array_elements(nv.phu_cap) as pc2;

      if tien_ot > 0 then
        insert into public.payslip_items (payslip_id, item_type, name, amount, is_taxable, is_insurance)
        values (
          phieu_id, 'thuong',
          format('Làm thêm %s phút, quy đổi %s giờ theo hệ số của từng ngày',
                 nv.phut_ot, round(nv.gio_ot_quy_doi, 2)),
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
