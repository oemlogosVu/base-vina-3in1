-- =========================================================
-- P3 — Engine tính lương
--
-- Viết bằng plpgsql chứ không phải TypeScript trong Edge Function như kế
-- hoạch gốc ghi. Ba lý do:
--
--   1. Tiền phải tính bằng `numeric`. JavaScript không có kiểu thập phân
--      chính xác — 0.1 + 0.2 !== 0.3. Tính bằng JS rồi ghi vào cột numeric là
--      đã sai trước khi ghi. AGENTS.md mục 10 cấm float cho tiền.
--   2. Bài học vừa vấp ở P2: `phut_giao_nhau` tồn tại hai bản, SQL dùng ceil
--      còn TypeScript dùng floor, ra hai con số khác nhau. Với tiền lương,
--      hai bản là hai lần rủi ro.
--   3. Cả kỳ lương tính trong một giao dịch: hoặc cả bảng lương ra, hoặc
--      không dòng nào.
-- =========================================================

-- ---------------------------------------------------------
-- 1. Bảng tham số còn thiếu: hệ số làm thêm giờ
--
--    Kế hoạch database gốc KHÔNG có bảng này. Nhưng P2 đã ghi nhận
--    `ot_minutes`, và nếu P3 không có hệ số để quy đổi thì giờ ngoài giờ sẽ
--    không được trả tiền một cách ÂM THẦM — nhân viên làm thêm mà bảng lương
--    không thể hiện, và không có gì báo cho ai biết.
--
--    Bộ luật Lao động quy định các mức khác nhau cho ngày thường, ngày nghỉ
--    hằng tuần và ngày lễ. Đây là tham số pháp lý nên cũng để RỖNG chờ xác
--    nhận, giống biểu thuế.
-- ---------------------------------------------------------
create table public.cfg_overtime_rates (
  id                  uuid primary key default gen_random_uuid(),
  effective_from      date not null unique,
  ngay_thuong_pct     numeric(6, 2) not null,
  ngay_nghi_tuan_pct  numeric(6, 2) not null,
  ngay_le_pct         numeric(6, 2) not null,
  ghi_chu             text,
  created_at          timestamptz not null default now(),

  constraint ot_he_so_hop_le check (
    ngay_thuong_pct >= 100 and ngay_nghi_tuan_pct >= 100 and ngay_le_pct >= 100
  )
);

comment on table public.cfg_overtime_rates is
  'Hệ số làm thêm giờ theo %. Để rỗng cho tới khi có xác nhận kèm căn cứ pháp lý.';

alter table public.cfg_overtime_rates enable row level security;
alter table public.cfg_overtime_rates force  row level security;

create policy "cfg_overtime_rates_select_hr_ketoan_admin"
  on public.cfg_overtime_rates for select
  to authenticated using ((select public.can_read_payroll()));
create policy "cfg_overtime_rates_insert_admin"
  on public.cfg_overtime_rates for insert
  to authenticated with check ((select public.current_app_role()) = 'admin');
create policy "cfg_overtime_rates_update_admin"
  on public.cfg_overtime_rates for update
  to authenticated using ((select public.current_app_role()) = 'admin')
  with check ((select public.current_app_role()) = 'admin');

revoke all on public.cfg_overtime_rates from anon, authenticated;
grant select, insert, update on public.cfg_overtime_rates to authenticated;

-- ---------------------------------------------------------
-- 2. Thuế TNCN luỹ tiến — KHÔNG phụ thuộc số bậc
--
--    Cộng qua từng bậc: phần thu nhập nằm trong bậc đó nhân thuế suất bậc đó.
--    5 bậc hay 7 bậc đều chạy đúng, vì hàm chỉ đọc bao nhiêu dòng có trong
--    bảng chứ không giả định con số nào.
--
--    Đây là lý do việc chưa chốt 5 hay 7 bậc không chặn được phần còn lại
--    của P3.
-- ---------------------------------------------------------
create or replace function public.thue_tncn(
  p_thu_nhap_tinh_thue numeric,
  p_ngay date
)
returns numeric
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  ngay_hieu_luc date;
  thue          numeric;
begin
  -- Thu nhập tính thuế âm hoặc bằng 0 thì thuế bằng 0, KHÔNG âm. Người thu
  -- nhập thấp không được "hoàn thuế" qua bảng lương.
  if p_thu_nhap_tinh_thue is null or p_thu_nhap_tinh_thue <= 0 then
    return 0;
  end if;

  select max(effective_from) into ngay_hieu_luc
  from public.cfg_pit_brackets
  where effective_from <= p_ngay;

  if ngay_hieu_luc is null then
    -- Từ chối tính, KHÔNG trả về 0. Trả 0 nghĩa là "thuế bằng không", và đó
    -- là con số dễ lọt qua mắt người duyệt nhất.
    raise exception
      'Chưa có biểu thuế TNCN hiệu lực tới ngày %. Nhập cfg_pit_brackets trước khi tính lương.',
      p_ngay;
  end if;

  select coalesce(sum(
           (least(p_thu_nhap_tinh_thue, coalesce(b.to_amount, p_thu_nhap_tinh_thue))
            - b.from_amount) * b.rate / 100
         ), 0)
    into thue
  from public.cfg_pit_brackets b
  where b.effective_from = ngay_hieu_luc
    and p_thu_nhap_tinh_thue > b.from_amount;

  return round(thue);
end;
$$;

comment on function public.thue_tncn(numeric, date) is
  'Thuế TNCN luỹ tiến từ cfg_pit_brackets. Không phụ thuộc số bậc. Ném lỗi nếu chưa có biểu thuế — không bao giờ lặng lẽ trả 0.';

revoke execute on function public.thue_tncn(numeric, date) from public, anon, authenticated;

-- ---------------------------------------------------------
-- 3. Engine: tính lương cho toàn bộ nhân viên của một kỳ
--
--    Trả về số phiếu lương đã ghi. Chạy lại được nhiều lần khi kỳ đang mở.
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

  -- Lấy tham số hiệu lực tới NGÀY CUỐI KỲ, không phải ngày hôm nay: tính lại
  -- bảng lương tháng 3 vào tháng 8 phải ra đúng con số của tháng 3.
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

  -- Số phút chuẩn một ngày, lấy từ ca đang dùng. Dùng để quy phút công của
  -- P2 thành ngày công.
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
      bhxh_nv numeric; bhyt_nv numeric; bhtn_nv numeric;
      bhxh_cty numeric; bhyt_cty numeric; bhtn_cty numeric;
      tn_chiu_thue     numeric;
      gt_ban_than      numeric;
      gt_phu_thuoc     numeric;
      tn_tinh_thue     numeric;
      thue             numeric;
      net              numeric;
      phieu_id         uuid;
      pc               jsonb;
    begin
      ngay_cong := round(nv.phut_lam::numeric / phut_chuan_ngay, 2);
      -- Tỷ lệ hưởng lương không vượt quá 1: làm nhiều hơn ngày công chuẩn thì
      -- phần dôi ra là làm thêm giờ, đã tính riêng ở tien_ot. Không cộng hai lần.
      ty_le := least(1, ngay_cong / ky.standard_days);
      luong_theo_cong := round(nv.position_salary * ty_le);

      -- Phụ cấp từ hợp đồng: [{name, amount, taxable, insurance}]
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

      -- Làm thêm giờ. Chưa có hệ số thì KHÔNG lặng lẽ trả 0 — dừng lại và nói
      -- rõ, vì im lặng ở đây là quỵt tiền của người đã làm thêm.
      if nv.phut_ot > 0 then
        if ot.id is null then
          raise exception
            'Nhân viên % có % phút làm thêm nhưng chưa có hệ số làm thêm giờ hiệu lực tới %. Nhập cfg_overtime_rates trước.',
            nv.employee_id, nv.phut_ot, ngay_cuoi;
        end if;
        -- Đơn giá giờ tính trên lương theo ngày công chuẩn của kỳ.
        tien_ot := round(
          (nv.position_salary / ky.standard_days / (phut_chuan_ngay / 60.0))
          * (nv.phut_ot / 60.0)
          * ot.ngay_thuong_pct / 100
        );
      end if;

      gross := luong_theo_cong + phu_cap_tong + tien_ot;

      -- Nền đóng bảo hiểm: lương ghi trong hợp đồng cộng phụ cấp có đóng BH,
      -- KHÔNG phải gross. Lương đóng BH do hợp đồng quy định, không phụ thuộc
      -- tháng đó đi làm bao nhiêu ngày.
      nen_bhxh := least(nv.bhxh_salary + phu_cap_dong_bh, luong_co_so * bh.bhxh_cap_multiple);

      select amount into luong_toi_thieu
      from public.cfg_region_min_wage
      where effective_from <= ngay_cuoi
        and region = coalesce((select region from public.employees where id = nv.employee_id), 1)
      order by effective_from desc limit 1;

      if luong_toi_thieu is null then
        raise exception 'Chưa có lương tối thiểu vùng hiệu lực tới %. Nhập cfg_region_min_wage trước.', ngay_cuoi;
      end if;

      -- Trần BHTN tính trên lương tối thiểu VÙNG, khác gốc với trần BHXH.
      nen_bhtn := least(nv.bhxh_salary + phu_cap_dong_bh, luong_toi_thieu * bh.bhtn_cap_multiple);

      bhxh_nv  := round(nen_bhxh * bh.bhxh_employee_pct / 100);
      bhyt_nv  := round(nen_bhxh * bh.bhyt_employee_pct / 100);
      bhtn_nv  := round(nen_bhtn * bh.bhtn_employee_pct / 100);
      bhxh_cty := round(nen_bhxh * bh.bhxh_employer_pct / 100);
      bhyt_cty := round(nen_bhxh * bh.bhyt_employer_pct / 100);
      bhtn_cty := round(nen_bhtn * bh.bhtn_employer_pct / 100);

      -- Thu nhập chịu thuế: gross trừ phần phụ cấp KHÔNG chịu thuế, trừ bảo
      -- hiểm nhân viên đóng.
      tn_chiu_thue := gross - (phu_cap_tong - phu_cap_chiu_thue) - (bhxh_nv + bhyt_nv + bhtn_nv);

      gt_ban_than  := gt.personal_amount;
      gt_phu_thuoc := gt.dependent_amount * nv.so_nguoi_phu_thuoc;
      tn_tinh_thue := tn_chiu_thue - gt_ban_than - gt_phu_thuoc;

      thue := public.thue_tncn(tn_tinh_thue, ngay_cuoi);
      net  := gross - (bhxh_nv + bhyt_nv + bhtn_nv) - thue;

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
        tn_chiu_thue, gt_ban_than, gt_phu_thuoc,
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

      -- Dựng lại các dòng chi tiết. Xoá rồi chèn lại vì phụ cấp có thể đã đổi
      -- trong hợp đồng giữa hai lần tính.
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
        values (phieu_id, 'thuong',
                format('Làm thêm %s phút', nv.phut_ot), tien_ot, true, false);
      end if;

      so_phieu := so_phieu + 1;
    end;
  end loop;

  return so_phieu;
end;
$$;

comment on function public.tinh_luong_ky(uuid) is
  'Tính lương toàn bộ nhân viên của một kỳ. Chỉ chạy khi kỳ đang mở. Chạy lại được nhiều lần. Ném lỗi nếu thiếu bất kỳ tham số nào — không bao giờ lặng lẽ tính ra 0.';

revoke execute on function public.tinh_luong_ky(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------
-- 4. Vỏ bọc kiểm vai trò cho UI gọi
-- ---------------------------------------------------------
create or replace function public.tinh_luong_ky_cua_toi(p_period_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.can_manage_payroll() then
    raise exception 'Chỉ kế toán hoặc admin được tính lương.';
  end if;
  return public.tinh_luong_ky(p_period_id);
end;
$$;

revoke execute on function public.tinh_luong_ky_cua_toi(uuid) from public, anon;
grant  execute on function public.tinh_luong_ky_cua_toi(uuid) to authenticated;

-- ---------------------------------------------------------
-- 5. Chốt kỳ lương — hành động một chiều
-- ---------------------------------------------------------
create or replace function public.chot_ky_luong(p_period_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  ky public.payroll_periods%rowtype;
begin
  if not public.can_manage_payroll() then
    raise exception 'Chỉ kế toán hoặc admin được chốt kỳ lương.';
  end if;

  select * into ky from public.payroll_periods where id = p_period_id;
  if not found then
    raise exception 'Không tìm thấy kỳ lương %.', p_period_id;
  end if;
  if ky.status <> 'mo' then
    raise exception 'Kỳ lương %/% đã chốt rồi.', ky.month, ky.year;
  end if;
  if not exists (select 1 from public.payslips where period_id = p_period_id) then
    raise exception 'Kỳ lương %/% chưa có phiếu lương nào — tính lương trước khi chốt.', ky.month, ky.year;
  end if;

  update public.payroll_periods
  set status = 'da_chot', closed_at = now(),
      closed_by = (select id from public.app_users where id = auth.uid())
  where id = p_period_id;
end;
$$;

comment on function public.chot_ky_luong(uuid) is
  'Chốt kỳ lương. Một chiều: sau khi chốt, phiếu lương bất biến. Muốn sửa phải mở kỳ điều chỉnh mới.';

revoke execute on function public.chot_ky_luong(uuid) from public, anon;
grant  execute on function public.chot_ky_luong(uuid) to authenticated;
