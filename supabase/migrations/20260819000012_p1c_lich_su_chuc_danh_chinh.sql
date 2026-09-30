-- =========================================================
-- P1c — Chức danh CHÍNH cũng có lịch sử theo thời gian
--
-- Yêu cầu Triệu Vũ 19/08/2026, sau khi hỏi "thêm chức danh cho nhân viên cũ
-- thì làm thế nào" và tôi phải thú nhận một nghịch lý: chức danh KIÊM NHIỆM
-- có lịch sử đầy đủ (làm sáng nay ở P1b), còn chức danh CHÍNH thì sửa đè lên
-- giá trị cũ — đúng loại lỗ hổng đã sửa cho lương ở P3b.
--
-- CÁCH LÀM: dùng CHÍNH bảng vừa dựng, thêm cờ `la_chinh`. Không bảng thứ hai.
-- Một chức danh chính và một chức danh kiêm chỉ khác nhau ở cờ đó; mọi thứ
-- còn lại — kỳ hiệu lực, căn cứ, cách gộp phụ cấp — đều y hệt.
--
-- VÀ PHẢI GỠ `employees.position_id`. Giữ lại thì nó là bản sao "chức danh
-- hiện tại" của một sự thật nằm chỗ khác, và bản sao ấy KHÔNG tự cập nhật khi
-- một dòng lịch sử tới ngày hiệu lực. Đó chính là drift — thứ mà sáng nay đã
-- gỡ hai cột lương khỏi hợp đồng để tránh.
--
-- Lần trước tôi lập luận GIỮ `position_id` vì nó nuôi bốn hàm tính tiền. Lập
-- luận ấy đúng khi chức danh chính là một giá trị KHÔNG có thời gian. Nay nó
-- có, nên nó không còn là một cột nữa.
-- =========================================================

-- ---------------------------------------------------------
-- 1. Đổi tên bảng cho đúng nghĩa mới
--
--    Bảng nay giữ CẢ chức danh chính lẫn chức danh kiêm. Để tên cũ là gài bẫy
--    người đọc sau — họ sẽ tưởng chức danh chính nằm chỗ khác.
-- ---------------------------------------------------------
alter table public.nhan_vien_kiem_nhiem rename to nhan_vien_chuc_danh;

alter table public.nhan_vien_chuc_danh
  add column la_chinh boolean not null default false;

comment on table public.nhan_vien_chuc_danh is
  'Chức danh của nhân viên theo thời gian. la_chinh = true là chức danh chính; false là kiêm nhiệm. Cả hai đều có kỳ hiệu lực.';

comment on column public.nhan_vien_chuc_danh.la_chinh is
  'Chức danh CHÍNH. Mỗi người tại một thời điểm có tối đa một dòng chính đang mở.';

-- Đúng MỘT chức danh chính đang mở cho mỗi người.
create unique index uniq_chuc_danh_chinh_dang_mo
  on public.nhan_vien_chuc_danh (employee_id)
  where la_chinh and den_ngay is null;

-- ---------------------------------------------------------
-- 2. Bỏ trigger "không kiêm chính chức danh đang giữ" — LÀM TRƯỚC
--
--    Phải gỡ TRƯỚC bước chuyển dữ liệu ở mục 3: trigger ấy so dòng mới với
--    `employees.position_id`, nên nó chặn đúng những dòng chức danh CHÍNH mà
--    migration này đang tạo. Lần chạy đầu đã bị nó từ chối — và nó từ chối
--    đúng theo luật cũ, chỉ là luật cũ hết hiệu lực từ bản này.
--
--    Không cần nữa, và đó là dấu hiệu mô hình mới đúng hơn: chức danh chính
--    nay là MỘT DÒNG trong cùng bảng, nên chỉ mục duy nhất
--    `uniq_kiem_nhiem_dang_mo` (employee_id, position_id) where den_ngay is
--    null đã chặn sẵn — không thể có hai dòng đang mở cùng trỏ một chức danh,
--    bất kể dòng nào là chính.
-- ---------------------------------------------------------
drop trigger  trg_kiem_nhiem_khac_chinh on public.nhan_vien_chuc_danh;
drop function public.kiem_nhiem_khac_chuc_danh_chinh();

alter index uniq_kiem_nhiem_dang_mo rename to uniq_chuc_danh_dang_mo;

-- ---------------------------------------------------------
-- 3. Chuyển chức danh chính đang có thành dòng lịch sử đầu tiên
--
--    Hiệu lực từ NGÀY VÀO LÀM. Không biết chính xác ngày họ nhận chức danh
--    ấy, nhưng ngày vào làm là mốc sớm nhất chắc chắn đúng: trước đó họ chưa
--    làm việc, nên không kỳ lương nào rơi vào khoảng trống.
--
--    Ai chưa có ngày vào làm thì lùi về 2000-01-01 — nói thẳng là "đã giữ từ
--    trước khi hệ thống biết", thay vì bịa một ngày trông có vẻ chính xác.
-- ---------------------------------------------------------
insert into public.nhan_vien_chuc_danh
  (employee_id, position_id, tu_ngay, la_chinh, ly_do)
select e.id, e.position_id, coalesce(e.hire_date, date '2000-01-01'), true,
       'Chức danh khi chuyển từ dữ liệu cũ (19/08/2026)'
from public.employees e
where e.position_id is not null;

-- ---------------------------------------------------------
-- 4. Hàm nền
-- ---------------------------------------------------------
create or replace function public.chuc_danh_chinh_tai_ngay(p_employee_id uuid, p_ngay date)
returns uuid
language sql
stable
security definer
set search_path = ''
as $ccn$
  select cd.position_id
  from public.nhan_vien_chuc_danh cd
  where cd.employee_id = p_employee_id
    and cd.la_chinh
    and cd.tu_ngay <= p_ngay
    and (cd.den_ngay is null or cd.den_ngay >= p_ngay)
  order by cd.tu_ngay desc
  limit 1;
$ccn$;

comment on function public.chuc_danh_chinh_tai_ngay(uuid, date) is
  'Chức danh chính của một người tại một ngày. NULL nếu ngày đó họ chưa/không giữ chức danh nào.';

-- Mọi chức danh (chính + kiêm) tại một ngày — nay đọc từ một bảng duy nhất.
create or replace function public.chuc_danh_cua_nhan_vien(p_employee_id uuid, p_ngay date)
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $cd$
  select cd.position_id
  from public.nhan_vien_chuc_danh cd
  where cd.employee_id = p_employee_id
    and cd.tu_ngay <= p_ngay
    and (cd.den_ngay is null or cd.den_ngay >= p_ngay);
$cd$;

revoke execute on function public.chuc_danh_chinh_tai_ngay(uuid, date) from anon;

-- ---------------------------------------------------------
-- 5. Đổi chức danh chính
--
--    Gói thành hàm vì phải làm HAI việc không tách rời: đóng chức danh chính
--    đang mở tại ngày TRƯỚC ngày hiệu lực mới, rồi mở dòng mới. Tách ra là có
--    lúc một người có hai chức danh chính chồng nhau, hoặc không có chức danh
--    nào trong một khoảng.
--
--    Ngày hiệu lực LÙI vẫn nhận — quyết định bổ nhiệm ký muộn là chuyện
--    thường, cùng lý do đã chốt cho mức lương ở P3b. Phía giao diện cảnh báo
--    nếu ngày đó rơi vào kỳ lương đã chốt.
-- ---------------------------------------------------------
create or replace function public.doi_chuc_danh_chinh(
  p_employee_id uuid,
  p_position_id uuid,
  p_tu_ngay     date,
  p_ly_do       text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $dcd$
declare
  hien_tai record;
begin
  if not public.is_hr_or_admin() then
    raise exception 'Chỉ nhân sự và quản trị mới đổi được chức danh.';
  end if;
  if p_position_id is null then
    raise exception 'Chưa chọn chức danh.';
  end if;

  select * into hien_tai
  from public.nhan_vien_chuc_danh
  where employee_id = p_employee_id and la_chinh and den_ngay is null;

  if found then
    if hien_tai.position_id = p_position_id then
      raise exception 'Đây đã là chức danh chính hiện tại của người này rồi.';
    end if;
    if p_tu_ngay <= hien_tai.tu_ngay then
      raise exception
        'Ngày hiệu lực phải sau ngày bắt đầu của chức danh hiện tại (%). Muốn sửa chính dòng đó thì sửa trực tiếp.',
        hien_tai.tu_ngay;
    end if;

    update public.nhan_vien_chuc_danh
    set den_ngay = p_tu_ngay - 1
    where id = hien_tai.id;
  end if;

  insert into public.nhan_vien_chuc_danh
    (employee_id, position_id, tu_ngay, la_chinh, ly_do)
  values
    (p_employee_id, p_position_id, p_tu_ngay, true, p_ly_do);
end;
$dcd$;

revoke execute on function public.doi_chuc_danh_chinh(uuid, uuid, date, text) from anon, public;
grant  execute on function public.doi_chuc_danh_chinh(uuid, uuid, date, text) to authenticated;

-- ---------------------------------------------------------
-- 6. Thêm nhân công công nhật: ghi chức danh vào bảng lịch sử
-- ---------------------------------------------------------
create or replace function public.them_nhan_cong_to(
  p_to_doi_id  uuid,
  p_ho_ten     text,
  p_cccd       text    default null,
  p_kieu_tinh  text    default 'ngay',
  p_don_gia    numeric default null,
  p_don_gia_ot numeric default null,
  p_tu_ngay    date    default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $tnc$
declare
  chuc_danh uuid;
  cty       uuid;
  ma        text;
  nv        uuid;
  vao_tu    date;
begin
  if not (public.la_nguoi_cham_cong_to(p_to_doi_id) or public.is_hr_or_admin()) then
    raise exception 'Bạn không phụ trách tổ này.';
  end if;

  if coalesce(btrim(p_ho_ten), '') = '' then
    raise exception 'Thiếu họ và tên.';
  end if;
  if p_kieu_tinh not in ('ngay', 'gio') then
    raise exception 'Kiểu tính lương phải là theo ngày hoặc theo giờ.';
  end if;
  if p_don_gia is not null and p_don_gia < 0 then
    raise exception 'Đơn giá không được âm.';
  end if;
  if p_don_gia_ot is not null and p_don_gia_ot < 0 then
    raise exception 'Đơn giá ngoài giờ không được âm.';
  end if;

  select id into chuc_danh from public.positions where la_cong_nhat limit 1;
  if chuc_danh is null then
    raise exception 'Chưa đánh dấu chức danh nào là "công nhật". Vào Quản trị → Tổ đội công nhật để tích chức danh dùng cho nhân công thuê ngoài.';
  end if;

  select company_id into cty from public.to_doi where id = p_to_doi_id;
  vao_tu := coalesce(p_tu_ngay, current_date);

  select 'CN' || lpad(
           (coalesce(max(substring(e.employee_code from '^CN(\d+)$')::integer), 0) + 1)::text,
           4, '0')
    into ma
  from public.employees e
  where e.employee_code ~ '^CN\d+$';

  insert into public.employees
    (employee_code, full_name, status, company_id, hire_date, theo_doi_cham_cong)
  values
    (ma, btrim(p_ho_ten), 'cong_tac_vien', cty, vao_tu, false)
  returning id into nv;

  -- P1c: chức danh nằm ở bảng lịch sử, không còn là một cột trên hồ sơ.
  insert into public.nhan_vien_chuc_danh
    (employee_id, position_id, tu_ngay, la_chinh, ly_do)
  values
    (nv, chuc_danh, vao_tu, true, 'Nhân công công nhật');

  if coalesce(btrim(p_cccd), '') <> '' then
    insert into public.employee_sensitive (employee_id, cccd)
    values (nv, btrim(p_cccd));
  end if;

  insert into public.to_doi_thanh_vien
    (to_doi_id, employee_id, tu_ngay, kieu_tinh, don_gia, don_gia_ot)
  values
    (p_to_doi_id, nv, vao_tu, p_kieu_tinh, p_don_gia, p_don_gia_ot);

  return nv;
end;
$tnc$;

-- ---------------------------------------------------------
-- 7. Bảng thanh toán tra đơn giá theo chức danh chính TẠI NGÀY
--
--    Sinh ra từ định nghĩa đang chạy rồi vá đúng một khối lateral.
-- ---------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sinh_bang_thanh_toan_to(p_to_doi_id uuid, p_tu_ngay date, p_den_ngay date)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  bang_id   uuid;
  thieu_gia text;
  thieu_ot  text;
  cho_duyet integer;
  ten_to    text;
begin
  if not (public.la_nguoi_cham_cong_to(p_to_doi_id) or public.can_read_payroll()) then
    raise exception 'Bạn không được giao chấm công cho tổ này.';
  end if;

  if p_den_ngay < p_tu_ngay then
    raise exception 'Khoảng ngày không hợp lệ: ngày cuối sớm hơn ngày đầu.';
  end if;

  select t.name into ten_to from public.to_doi t where t.id = p_to_doi_id;
  if ten_to is null then
    raise exception 'Không tìm thấy tổ này.';
  end if;

  if exists (
    select 1 from public.bang_thanh_toan_to b
    where b.to_doi_id = p_to_doi_id and b.tu_ngay = p_tu_ngay and b.den_ngay = p_den_ngay
  ) then
    raise exception
      'Tổ % đã có bảng thanh toán cho khoảng % đến %. Xem bảng đã có, hoặc nhờ quản trị xoá nó rồi sinh lại.',
      ten_to, p_tu_ngay, p_den_ngay;
  end if;

  -- Gộp theo người, chỉ lấy phiên ĐÃ DUYỆT. Đơn giá và kiểu tính lấy từ dòng
  -- thành viên GIAO với khoảng đang tính, mới nhất trước.
  create temporary table tam_cong on commit drop as
  select
    c.employee_id,
    tv.kieu_tinh,
    sum(
      case when tv.kieu_tinh = 'gio' then coalesce(c.so_gio, 0)
           else coalesce(c.so_cong, 0) end
    )                                  as so_luong,
    sum(coalesce(c.so_gio_ot, 0))      as so_gio_ot,
    coalesce(tv.don_gia, dg.don_gia)   as don_gia,
    tv.don_gia_ot                      as don_gia_ot
  from public.cham_cong_cong_nhat c
  join public.phien_cham_cong_to p on p.id = c.phien_id
  join lateral (
    select t2.kieu_tinh, t2.don_gia, t2.don_gia_ot
    from public.to_doi_thanh_vien t2
    where t2.to_doi_id = p_to_doi_id
      and t2.employee_id = c.employee_id
      and t2.tu_ngay <= p_den_ngay
      and (t2.den_ngay is null or t2.den_ngay >= p_tu_ngay)
    order by t2.tu_ngay desc
    limit 1
  ) tv on true
  left join lateral (
    -- P1c: chức danh chính nay có kỳ hiệu lực, nên tra theo NGÀY CUỐI khoảng
    -- thanh toán thay vì đọc thẳng một cột trên hồ sơ.
    select g.don_gia
    from public.don_gia_cong_nhat g
    where g.position_id = public.chuc_danh_chinh_tai_ngay(c.employee_id, p_den_ngay)
  ) dg on true
  where p.to_doi_id = p_to_doi_id
    and p.da_duyet
    and c.work_date between p_tu_ngay and p_den_ngay
  group by c.employee_id, tv.kieu_tinh, tv.don_gia, tv.don_gia_ot, dg.don_gia
  having sum(
           case when tv.kieu_tinh = 'gio' then coalesce(c.so_gio, 0)
                else coalesce(c.so_cong, 0) end
         ) > 0
      or sum(coalesce(c.so_gio_ot, 0)) > 0;

  -- THIẾU ĐƠN GIÁ THÌ TỪ CHỐI, không lặng lẽ tính 0 đồng (AGENTS.md mục 5).
  select string_agg(e.full_name || ' (' || e.employee_code || ')', ', ' order by e.employee_code)
    into thieu_gia
  from tam_cong t
  join public.employees e on e.id = t.employee_id
  where t.so_luong > 0 and t.don_gia is null;

  if thieu_gia is not null then
    raise exception
      'Chưa có đơn giá cho: %. Nhập đơn giá riêng cho từng người trong tổ, hoặc khai đơn giá theo chức danh.',
      thieu_gia;
  end if;

  -- Có giờ ngoài giờ mà chưa khai đơn giá ngoài giờ cũng là thiếu tham số —
  -- từ chối, không lặng lẽ trả 0 đồng cho những giờ người ta đã làm.
  select string_agg(e.full_name || ' (' || e.employee_code || ')', ', ' order by e.employee_code)
    into thieu_ot
  from tam_cong t
  join public.employees e on e.id = t.employee_id
  where t.so_gio_ot > 0 and t.don_gia_ot is null;

  if thieu_ot is not null then
    raise exception
      'Có giờ ngoài giờ nhưng chưa khai đơn giá ngoài giờ cho: %. Nhập đơn giá ngoài giờ cho họ trước.',
      thieu_ot;
  end if;

  if not exists (select 1 from tam_cong) then
    raise exception
      'Không có ngày công nào ĐÃ DUYỆT trong khoảng % đến % của tổ %. Nhân sự cần duyệt phiên chấm công trước.',
      p_tu_ngay, p_den_ngay, ten_to;
  end if;

  select count(*) into cho_duyet
  from public.cham_cong_cong_nhat c
  join public.phien_cham_cong_to p on p.id = c.phien_id
  where p.to_doi_id = p_to_doi_id
    and not p.da_duyet
    and c.work_date between p_tu_ngay and p_den_ngay;

  insert into public.bang_thanh_toan_to
    (to_doi_id, tu_ngay, den_ngay, nguoi_tao, dong_cho_duyet)
  values
    (p_to_doi_id, p_tu_ngay, p_den_ngay, (select auth.uid()), cho_duyet)
  returning id into bang_id;

  insert into public.dong_thanh_toan_to
    (bang_id, employee_id, kieu_tinh, so_luong, don_gia, so_gio_ot, don_gia_ot)
  select
    bang_id, t.employee_id, t.kieu_tinh, t.so_luong,
    coalesce(t.don_gia, 0), t.so_gio_ot, coalesce(t.don_gia_ot, 0)
  from tam_cong t;

  return bang_id;
end;
$function$
;

-- ---------------------------------------------------------
-- 8. Gỡ cột chức danh khỏi hồ sơ
--
--    Sau khi mọi thứ đã trỏ sang bảng lịch sử.
-- ---------------------------------------------------------
alter table public.employees drop column position_id;

comment on table public.employees is
  'Hồ sơ nhân sự — phần không nhạy cảm. Chức danh KHÔNG nằm ở đây từ 19/08/2026: xem nhan_vien_chuc_danh, nơi mỗi chức danh có kỳ hiệu lực riêng.';

-- ---------------------------------------------------------
-- 9. Đổi tên policy cho khớp nghĩa mới
--
--    Policy sống sót qua lệnh đổi tên bảng nhưng giữ tên cũ. Tên nói "kiem
--    nhiem" trong khi bảng giữ cả chức danh chính là gài bẫy người đọc sau.
-- ---------------------------------------------------------
alter policy "kiem_nhiem_select_self"             on public.nhan_vien_chuc_danh rename to "chuc_danh_select_self";
alter policy "kiem_nhiem_select_hr_ketoan_admin"  on public.nhan_vien_chuc_danh rename to "chuc_danh_select_hr_ketoan_admin";
alter policy "kiem_nhiem_insert_hr_admin"         on public.nhan_vien_chuc_danh rename to "chuc_danh_insert_hr_admin";
alter policy "kiem_nhiem_update_hr_admin"         on public.nhan_vien_chuc_danh rename to "chuc_danh_update_hr_admin";
