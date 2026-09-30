-- =========================================================
-- P3b — Engine lương chia mức lương theo thời gian
--
-- SINH RA TỪ định nghĩa đang chạy trên database (pg_get_functiondef) rồi VÁ
-- ĐÚNG 15 CHỖ, không gõ lại. Đây là hàm tính tiền của người thật — gõ lại là
-- mời thêm lỗi vào những đoạn không liên quan gì tới thay đổi này. Cùng cách
-- đã làm ở migration 20260812000015.
--
-- Ba quy tắc Triệu Vũ chốt 19/08/2026:
--   • Lương theo công — mỗi ngày mang mức của chính ngày đó.
--   • Làm thêm giờ    — tính theo mức của chính ngày làm thêm.
--   • Bảo hiểm        — đóng theo mức của ngày ĐẦU kỳ; tăng lương giữa tháng
--                       thì tháng đó vẫn đóng mức cũ, mức mới đóng từ tháng sau.
--
-- Người miễn chấm công chia theo số ngày dương lịch của từng đoạn.
-- Trần 100% giữ nguyên; phần vượt cắt theo tỷ lệ ngày công của từng đoạn.
--
-- TƯƠNG THÍCH NGƯỢC: với một mức lương duy nhất cả tháng, mọi công thức ở đây
-- ra ĐÚNG con số của bản cũ. Bộ đối chiếu tay `scripts/kiem-tra-rls-p3.mjs`
-- canh đúng điều đó — 99 phép, không phép nào được phép đổi kết quả.
-- =========================================================

CREATE OR REPLACE FUNCTION public.tinh_luong_ky(p_period_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  ky          public.payroll_periods%rowtype;
  ngay_cuoi   date;
  ngay_dau    date;
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
  ngay_dau  := make_date(ky.year, ky.month, 1);

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
      lc.id as contract_id,
      -- Phụ cấp đã gộp: chức danh làm mặc định, hợp đồng ghi đè theo mã loại.
      public.phu_cap_cua_nhan_vien(e.position_id, lc.allowances) as phu_cap,
      coalesce(cong.phut_lam, 0)       as phut_lam,
      coalesce(cong.phut_ot, 0)        as phut_ot,
      coalesce(cong.gio_ot_quy_doi, 0) as gio_ot_quy_doi,
      coalesce(cong.phut_lam_nhan_luong, 0) as phut_lam_nhan_luong,
      coalesce(cong.gio_ot_nhan_luong, 0)   as gio_ot_nhan_luong,
      coalesce(pt.so_nguoi, 0)       as so_nguoi_phu_thuoc
    from public.employees e
    join public.labor_contracts lc on lc.employee_id = e.id and lc.is_active
    left join lateral (
      select
        sum(d.worked_minutes) as phut_lam,
        sum(d.ot_minutes)     as phut_ot,
        -- P3b: nhan san phut lam voi muc luong cua CHINH NGAY do, cong xong
        -- moi chia. Nho vay mot thang co hai muc van ra dung con so ma khong
        -- phai tach vong lap theo doan — cung cach da dung cho he so lam them
        -- gio theo tung ngay.
        sum(d.worked_minutes * public.luong_chuc_danh_tai_ngay(lc.id, d.work_date))
          as phut_lam_nhan_luong,
        sum(
          d.ot_minutes / 60.0
          * coalesce(
              d.ty_le_lam_them_pct,
              case when extract(isodow from d.work_date) = 7
                   then pct_ngay_nghi else pct_thuong end
            ) / 100
          * public.luong_chuc_danh_tai_ngay(lc.id, d.work_date)
        ) as gio_ot_nhan_luong,
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
      luong_bhxh_dau_ky numeric;
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
      -- P3b: nen dong bao hiem lay muc cua ngay DAU KY (Trieu Vu chot
      -- 19/08/2026). Tang luong giua thang thi thang do van dong theo muc cu,
      -- muc moi bat dau dong tu thang sau — khop voi cach co quan BHXH ghi
      -- nhan mot muc cho mot thang, va khop voi to khai.
      luong_bhxh_dau_ky := public.luong_bhxh_tai_ngay(nv.contract_id, ngay_dau);

      if nv.theo_doi_cham_cong then
        ngay_cong := round(nv.phut_lam::numeric / phut_chuan_ngay, 2);
      else
        ngay_cong := ky.standard_days;
      end if;

      ty_le := least(1, ngay_cong / ky.standard_days);

      -- P3b: moi ngay cong mang muc luong cua chinh ngay do.
      --
      -- Voi mot muc duy nhat ca thang, cong thuc nay ra DUNG con so cua ban
      -- cu: tong(phut x muc) / phut_chuan / cong_chuan = muc x ty_le.
      --
      -- Tran 100% van giu: di nhieu hon cong chuan cung chi huong du luong
      -- thang. Phan vuot cat THEO TY LE ngay cong cua tung doan (quyet dinh
      -- 19/08/2026), khong cat rieng doan cuoi.
      if nv.theo_doi_cham_cong then
        if ngay_cong > 0 then
          luong_theo_cong := round(
            nv.phut_lam_nhan_luong / phut_chuan_ngay / ky.standard_days
            * least(1, ky.standard_days / ngay_cong)
          );
        else
          luong_theo_cong := 0;
        end if;
      else
        -- Nguoi MIEN cham cong huong du ngay cong chuan nen khong co bang cong
        -- de chia. Chia theo so ngay duong lich cua tung doan — cach phan bo
        -- trung tinh nhat, va la mot lua chon chu khong phai mac dinh tinh co.
        luong_theo_cong := round(
          public.luong_chuc_danh_binh_quan(nv.contract_id, ngay_dau, ngay_cuoi) * ty_le
        );
      end if;

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
        -- P3b: moi gio lam them tinh theo muc luong cua CHINH NGAY lam them.
        -- Bang cong luu work_date nen chia duoc chinh xac, khong phai uoc luong.
        tien_ot := round(nv.gio_ot_nhan_luong / ky.standard_days / (phut_chuan_ngay / 60.0));
      end if;

      gross := luong_theo_cong + phu_cap_tong + tien_ot;

      ngay_nghi := greatest(0, ky.standard_days - ngay_cong);
      co_dong_bh := bh.nghi_khong_luong_mien_dong_ngay is null
                    or ngay_nghi < bh.nghi_khong_luong_mien_dong_ngay;

      if co_dong_bh then
        nen_bhxh := least(luong_bhxh_dau_ky + phu_cap_dong_bh, luong_co_so * bh.bhxh_cap_multiple);

        select amount into luong_toi_thieu
        from public.cfg_region_min_wage
        where effective_from <= ngay_cuoi and region = coalesce(nv.region, 1)
        order by effective_from desc limit 1;

        if luong_toi_thieu is null then
          raise exception
            'Chưa có lương tối thiểu vùng % hiệu lực tới %. Nhập cfg_region_min_wage trước.',
            coalesce(nv.region, 1), ngay_cuoi;
        end if;

        nen_bhtn := least(luong_bhxh_dau_ky + phu_cap_dong_bh, luong_toi_thieu * bh.bhtn_cap_multiple);

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
          'Lương thực nhận của % (%) ra số âm: %. Kiểm lại ngày công, ngưỡng miễn đóng bảo hiểm, hoặc mức lương đang hiệu lực.',
          nv.full_name, nv.employee_code, net;
      end if;

      insert into public.payslips as ps (
        period_id, employee_id, worked_days, gross_salary,
        bhxh_employee, bhyt_employee, bhtn_employee,
        bhxh_employer, bhyt_employer, bhtn_employer,
        taxable_income, personal_deduction, dependent_deduction,
        assessable_income, pit, net_salary, cfg_snapshot, tinh_luc,
        luong_dong_bhxh, muc_luong_snapshot
      )
      values (
        p_period_id, nv.employee_id, ngay_cong, gross,
        bhxh_nv, bhyt_nv, bhtn_nv, bhxh_cty, bhyt_cty, bhtn_cty,
        greatest(0, tn_chiu_thue), gt_ban_than, gt_phu_thuoc,
        greatest(0, tn_tinh_thue), thue, net,
        -- Chụp luôn danh sách phụ cấp đã gộp: sang năm nếu ai đổi mức phụ cấp
        -- của chức danh thì vẫn dựng lại được vì sao phiếu này ra con số đó.
        snapshot || jsonb_build_object('phu_cap', nv.phu_cap),
        now(),
        -- CAN CU, khong chi ket qua: muc dong bao hiem da dung, va cac muc
        -- luong chuc danh da ap trong ky kem ngay hieu luc. Thieu hai thu nay
        -- thi ba thang sau khong ai dung lai duoc vi sao phieu ra con so do.
        luong_bhxh_dau_ky,
        public.muc_luong_trong_ky(nv.contract_id, ngay_dau, ngay_cuoi)
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
        tinh_luc            = excluded.tinh_luc,
        luong_dong_bhxh     = excluded.luong_dong_bhxh,
        muc_luong_snapshot  = excluded.muc_luong_snapshot
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
$function$
;
