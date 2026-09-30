-- =========================================================
-- P1b — Một nhân viên kiêm nhiệm nhiều chức danh
--
-- Yêu cầu Triệu Vũ 19/08/2026. Bốn quyết định:
--   1. Giữ `employees.position_id` làm chức danh CHÍNH, thêm bảng chức danh
--      KIÊM. Bốn hàm tính tiền và câu truy vấn đăng nhập đều bám vào cột đó;
--      bỏ nó để làm nhiều–nhiều thuần là đụng vào cả bốn đường đang chạy đúng,
--      trong đó có câu đã từng làm sập app ngày 12/08.
--   2. Phụ cấp: CÙNG một loại thì lấy mức CAO NHẤT, khác loại thì cộng. Kiêm
--      hai chức danh cùng có phụ cấp ăn ca thì không ăn hai suất ăn ca.
--   3. Tab hiển thị: HỢP của mọi chức danh — làm cả hai việc thì cần cả hai
--      màn hình. Vẫn giao với quyền theo vai trò nên không cấp thêm quyền đọc.
--   4. Việc kiêm nhiệm có NGÀY HIỆU LỰC. Phụ cấp đi kèm chức danh, nên gỡ một
--      chức danh mà không lưu kỳ thì phiếu lương tháng trước hết giải thích
--      được vì sao có khoản phụ cấp đó. Cùng khuôn với mức lương theo thời
--      gian ở P3b.
-- =========================================================

-- ---------------------------------------------------------
-- 1. Bảng chức danh kiêm nhiệm
-- ---------------------------------------------------------
create table public.nhan_vien_kiem_nhiem (
  id          uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.employees (id) on delete cascade,
  position_id uuid not null references public.positions (id),

  tu_ngay     date not null,
  den_ngay    date,

  -- "Quyết định 12/QĐ-BVN ngày 01/09/2026" — người xem lại sau này cần biết
  -- căn cứ, nhất là khi khoản phụ cấp đi kèm bị thắc mắc.
  ly_do       text,

  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),

  constraint knn_ky_hop_le check (den_ngay is null or den_ngay >= tu_ngay)
);

comment on table public.nhan_vien_kiem_nhiem is
  'Chức danh KIÊM của một nhân viên, có kỳ hiệu lực. Chức danh CHÍNH vẫn nằm ở employees.position_id.';

-- Không kiêm cùng một chức danh hai lần trong cùng lúc.
create unique index uniq_kiem_nhiem_dang_mo
  on public.nhan_vien_kiem_nhiem (employee_id, position_id)
  where den_ngay is null;

create index idx_kiem_nhiem_nhan_su on public.nhan_vien_kiem_nhiem (employee_id);

create trigger trg_kiem_nhiem_touch
  before update on public.nhan_vien_kiem_nhiem
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------
-- 2. Không kiêm chính chức danh mình đang giữ
--
--    Ràng buộc CHECK không tham chiếu được bảng khác nên phải dùng trigger.
--    Lọt cái này thì phụ cấp của chức danh chính bị đếm hai lần ở bước gộp.
-- ---------------------------------------------------------
create or replace function public.kiem_nhiem_khac_chuc_danh_chinh()
returns trigger
language plpgsql
security definer
set search_path = ''
as $ktr$
begin
  if exists (
    select 1 from public.employees e
    where e.id = new.employee_id and e.position_id = new.position_id
  ) then
    raise exception
      'Đây đã là chức danh chính của người này rồi — kiêm nhiệm phải là một chức danh khác.';
  end if;
  return new;
end;
$ktr$;

create trigger trg_kiem_nhiem_khac_chinh
  before insert or update on public.nhan_vien_kiem_nhiem
  for each row execute function public.kiem_nhiem_khac_chuc_danh_chinh();

-- ---------------------------------------------------------
-- 3. Mọi chức danh của một người tại một ngày
-- ---------------------------------------------------------
create or replace function public.chuc_danh_cua_nhan_vien(p_employee_id uuid, p_ngay date)
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $cd$
  select e.position_id
  from public.employees e
  where e.id = p_employee_id and e.position_id is not null
  union
  select k.position_id
  from public.nhan_vien_kiem_nhiem k
  where k.employee_id = p_employee_id
    and k.tu_ngay <= p_ngay
    and (k.den_ngay is null or k.den_ngay >= p_ngay);
$cd$;

comment on function public.chuc_danh_cua_nhan_vien(uuid, date) is
  'Chức danh chính cộng các chức danh kiêm còn hiệu lực tại một ngày.';

revoke execute on function public.chuc_danh_cua_nhan_vien(uuid, date) from anon;

-- ---------------------------------------------------------
-- 4. Gộp phụ cấp theo MỌI chức danh
--
--    Sinh ra từ bản đang chạy rồi sửa đúng phần nguồn chức danh. Chữ ký đổi
--    (nhận employee_id + ngày thay vì một position_id) nên phải tạo bản mới
--    rồi bỏ bản cũ — `create or replace` không đổi được chữ ký.
--
--    ĐIỂM MỚI: `distinct on (at.code) ... order by at.code, pa.amount desc`
--    — cùng một LOẠI phụ cấp thì giữ mức cao nhất trong các chức danh, khác
--    loại thì cộng bình thường. Kiêm hai chức danh cùng có ăn ca không thành
--    hai suất ăn ca cho một người một ngày.
-- ---------------------------------------------------------
create or replace function public.phu_cap_cua_nhan_vien(
  p_employee_id uuid,
  p_ngay        date,
  p_hop_dong    jsonb
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $pc$
  with
  chuc_danh as (
    select public.chuc_danh_cua_nhan_vien(p_employee_id, p_ngay) as id
  ),
  theo_chuc_danh as (
    select distinct on (at.code)
      at.code                                   as ma_loai,
      at.name                                   as ten,
      pa.amount                                 as so_tien,
      at.is_taxable                             as chiu_thue,
      at.is_insurance                           as dong_bh
    from public.position_allowances pa
    join public.allowance_types at on at.id = pa.allowance_type_id
    join chuc_danh cd on cd.id = pa.position_id
    where at.is_active
    order by at.code, pa.amount desc
  ),
  theo_hop_dong as (
    select
      nullif(x->>'type_code', '')               as ma_loai,
      coalesce(x->>'name', 'Phụ cấp')           as ten,
      coalesce((x->>'amount')::numeric, 0)      as so_tien,
      coalesce((x->>'taxable')::boolean, true)  as chiu_thue,
      coalesce((x->>'insurance')::boolean, false) as dong_bh
    from jsonb_array_elements(coalesce(p_hop_dong, '[]'::jsonb)) as x
  ),
  gop as (
    select t.ten, t.so_tien, t.chiu_thue, t.dong_bh, 'chuc_danh' as nguon
    from theo_chuc_danh t
    where not exists (
      select 1 from theo_hop_dong h where h.ma_loai is not null and h.ma_loai = t.ma_loai
    )

    union all

    select h.ten, h.so_tien, h.chiu_thue, h.dong_bh, 'hop_dong'
    from theo_hop_dong h
  )
  select coalesce(
    jsonb_agg(jsonb_build_object(
      'name',      g.ten,
      'amount',    g.so_tien,
      'taxable',   g.chiu_thue,
      'insurance', g.dong_bh,
      'nguon',     g.nguon
    ) order by g.nguon, g.ten),
    '[]'::jsonb
  )
  from gop g;
$pc$;

revoke execute on function public.phu_cap_cua_nhan_vien(uuid, date, jsonb) from anon;

-- ---------------------------------------------------------
-- 5. Engine lương gọi bản mới
--
--    SINH RA TỪ định nghĩa đang chạy rồi vá ĐÚNG MỘT dòng — chỗ gọi hàm gộp
--    phụ cấp. Không gõ lại: đây là hàm tính tiền của người thật.
--
--    Lấy chức danh tại NGÀY CUỐI KỲ, cùng mốc mà engine dùng để chọn tham số
--    pháp lý. Kiêm nhiệm kết thúc giữa tháng thì tháng đó không còn phụ cấp
--    của chức danh kiêm.
-- ---------------------------------------------------------
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
      public.phu_cap_cua_nhan_vien(e.id, ngay_cuoi, lc.allowances) as phu_cap,
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

-- ---------------------------------------------------------
-- 6. Bỏ bản cũ, sau khi engine đã trỏ sang bản mới
-- ---------------------------------------------------------
drop function public.phu_cap_cua_nhan_vien(uuid, jsonb);

-- ---------------------------------------------------------
-- 7. RLS
--
--    Chức danh không nhạy cảm như lương, nhưng vẫn là hồ sơ nhân sự: chính
--    chủ đọc được của mình, HR/kế toán/admin đọc tất cả, HR/admin ghi.
--    KHÔNG có policy DELETE — gỡ kiêm nhiệm là đặt `den_ngay`, để phiếu lương
--    cũ còn giải thích được vì sao có khoản phụ cấp đó.
-- ---------------------------------------------------------
alter table public.nhan_vien_kiem_nhiem enable row level security;
alter table public.nhan_vien_kiem_nhiem force  row level security;

create policy "kiem_nhiem_select_self"
  on public.nhan_vien_kiem_nhiem for select
  to authenticated
  using (employee_id = (select public.current_employee_id()));

create policy "kiem_nhiem_select_hr_ketoan_admin"
  on public.nhan_vien_kiem_nhiem for select
  to authenticated
  using ((select public.can_read_all_employees()));

create policy "kiem_nhiem_insert_hr_admin"
  on public.nhan_vien_kiem_nhiem for insert
  to authenticated
  with check ((select public.is_hr_or_admin()));

create policy "kiem_nhiem_update_hr_admin"
  on public.nhan_vien_kiem_nhiem for update
  to authenticated
  using ((select public.is_hr_or_admin()))
  with check ((select public.is_hr_or_admin()));

revoke all on public.nhan_vien_kiem_nhiem from anon, authenticated;
grant select, insert, update on public.nhan_vien_kiem_nhiem to authenticated;
