-- =========================================================
-- P5e — Chấm công tổ đội theo BA CA, giờ thường/ngoài giờ tính từ khung giờ
--       chuẩn của công ty
--
-- Triệu Vũ, 24/08/2026: "phần chấm công tạo 3 ca chấm theo giờ, thời gian làm
-- việc tính theo giờ chuẩn của công ty, ngoài giờ đó ra tính ngoài giờ", và
-- chốt bỏ kiểu khoán ngày — cả tổ chấm theo ca.
--
-- CÁI SAI CỦA MÔ HÌNH CŨ
--
-- P5c cho tổ trưởng GÕ TAY cả `so_gio` lẫn `so_gio_ot`. Người đứng ngoài công
-- trường tự quyết định giờ nào là ngoài giờ, và không gì đối chiếu được con số
-- ấy. Ngoài giờ là tiền nhân hệ số, nên đó là chỗ sai đắt nhất có thể để hở.
--
-- Từ bản này tổ trưởng chỉ trả lời một câu: **ca nào có làm**. Giờ thường và
-- giờ ngoài giờ do database tính, từ khung giờ chuẩn của công ty. Hai cột ấy
-- không còn nhận giá trị từ client — quyền cấp cột ở mục 6 chặn thẳng.
--
-- BA THỨ PHẢI KHAI TRƯỚC, KHÔNG ĐOÁN
--
--   1. Khung giờ chuẩn của công ty (giờ vào, giờ ra, nghỉ trưa).
--   2. Ba ca của công ty (sáng, chiều, tối) — giờ bắt đầu và kết thúc.
--   3. Đơn giá GIỜ của từng nhân công.
--
-- Migration KHÔNG điền số nào cho ba thứ đó, và cũng không quy đổi đơn giá
-- công sang đơn giá giờ. Cùng lý do đã viết cho `standard_days` ngày 12/08:
-- 8 giờ một công hay 10 giờ một công là chính sách trả lương của doanh
-- nghiệp, không phải thứ suy ra được. Chia bừa là trả sai tiền của người thật.
-- Engine từ chối tính khi thiếu, không lặng lẽ trả 0.
--
-- DỮ LIỆU CŨ GIỮ NGUYÊN
--
-- Đang có 12 nhân công khoán ngày, 12 dòng công ngày 22/08 và 2 bảng thanh
-- toán đã sinh từ chúng. Bản này KHÔNG xoá, KHÔNG quy đổi và KHÔNG viết lại
-- dòng nào trong số đó — chúng là căn cứ của tiền đã tính. `so_cong` chỉ
-- chuyển sang cho phép NULL để dòng MỚI không phải mang nó nữa.
-- =========================================================

-- ---------------------------------------------------------
-- 1. Khung giờ chuẩn của công ty
--
-- Bốn cột nullable, không phải bảng riêng: mỗi công ty có đúng một khung, và
-- một bảng con cho quan hệ một-một chỉ thêm một phép nối vào mọi câu truy vấn.
--
-- Nghỉ trưa phải nằm TRONG khung. Không có ràng buộc ấy thì một giờ nghỉ đặt
-- ngoài khung sẽ bị trừ hai lần ở mục 3 — trừ khỏi tổng, rồi lại không có
-- trong phần giao với khung.
-- ---------------------------------------------------------
alter table public.companies
  add column gio_vao  time,
  add column gio_ra   time,
  add column nghi_tu  time,
  add column nghi_den time;

alter table public.companies
  add constraint cty_khung_gio_du_doi
    check ((gio_vao is null) = (gio_ra is null)),
  add constraint cty_khung_gio_hop_le
    check (gio_vao is null or gio_ra > gio_vao),
  add constraint cty_nghi_du_doi
    check ((nghi_tu is null) = (nghi_den is null)),
  add constraint cty_nghi_trong_khung
    check (
      nghi_tu is null
      or (gio_vao is not null and nghi_den > nghi_tu
          and nghi_tu >= gio_vao and nghi_den <= gio_ra)
    );

comment on column public.companies.gio_vao is
  'Giờ bắt đầu khung giờ chuẩn. Làm trong khung là giờ thường, ngoài khung là ngoài giờ. NULL = chưa khai, và tổ đội của công ty đó chưa chấm công theo ca được.';

-- ---------------------------------------------------------
-- 2. Ba ca công nhật của công ty
--
-- Bảng riêng chứ không sáu cột trên `companies`: ba ca là ba dòng có cùng
-- hình dạng, và sáu cột `ca_sang_bat_dau`, `ca_sang_ket_thuc`… là một mảng
-- viết bằng tên cột.
--
-- Ràng buộc `unique (company_id, ma)` cộng với `check (ma in …)` giới hạn
-- đúng ba ca cho mỗi công ty — "ba ca cố định" là quyết định của Triệu Vũ hôm
-- nay, không phải giới hạn kỹ thuật.
-- ---------------------------------------------------------
create table public.ca_cong_nhat (
  id           uuid primary key default gen_random_uuid(),
  company_id   uuid not null references public.companies (id) on delete cascade,
  ma           text not null,
  gio_bat_dau  time not null,
  gio_ket_thuc time not null,
  is_active    boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),

  constraint ca_ma_hop_le check (ma in ('sang', 'chieu', 'toi')),
  constraint ca_ky_hop_le check (gio_ket_thuc > gio_bat_dau),
  constraint ca_mot_cong_ty_mot_ma unique (company_id, ma)
);

comment on table public.ca_cong_nhat is
  'Ba ca chấm công nhật của một công ty. Tổ trưởng chỉ tick ca nào có làm; số giờ thường và ngoài giờ suy ra từ đây và từ khung giờ chuẩn của công ty.';

create index idx_ca_cong_nhat_cty on public.ca_cong_nhat (company_id);

create trigger trg_ca_cong_nhat_touch
  before update on public.ca_cong_nhat
  for each row execute function public.touch_updated_at();

-- Ba ca KHÔNG được chồng giờ nhau.
--
-- Chồng nhau là đếm hai lần cùng một giờ làm, và nó ra tiền. Không dùng
-- exclusion constraint vì cần `btree_gist`; một trigger đọc được bằng mắt thì
-- người sau còn sửa được.
create or replace function public.chan_ca_cong_nhat_chong_nhau()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  ten_ca text;
begin
  select c.ma into ten_ca
  from public.ca_cong_nhat c
  where c.company_id = new.company_id
    and c.id is distinct from new.id
    and c.gio_bat_dau < new.gio_ket_thuc
    and c.gio_ket_thuc > new.gio_bat_dau
  limit 1;

  if ten_ca is not null then
    raise exception
      'Ca "%" chồng giờ với ca "%" của cùng công ty. Hai ca chồng nhau là đếm hai lần cùng một giờ làm.',
      new.ma, ten_ca
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

create trigger trg_ca_cong_nhat_chan_chong_nhau
  before insert or update of company_id, gio_bat_dau, gio_ket_thuc
  on public.ca_cong_nhat
  for each row execute function public.chan_ca_cong_nhat_chong_nhau();

-- ---------------------------------------------------------
-- 3. Số phút giao nhau của hai khoảng GIỜ TRONG NGÀY
--
-- `phut_giao_nhau()` của P2 nhận timestamptz. Ở đây thứ có trong tay là
-- `time`, và ghép chúng với một ngày giả chỉ để gọi hàm cũ là mời một lỗi múi
-- giờ vào chỗ không cần đến ngày tháng.
-- ---------------------------------------------------------
create or replace function public.phut_giao_gio(
  a_bat_dau time, a_ket_thuc time,
  b_bat_dau time, b_ket_thuc time
)
returns integer
language sql
immutable
set search_path = ''
as $$
  select greatest(
    0,
    ceil(extract(epoch from (
      least(a_ket_thuc, b_ket_thuc) - greatest(a_bat_dau, b_bat_dau)
    )) / 60)
  )::integer;
$$;

comment on function public.phut_giao_gio(time, time, time, time) is
  'Số phút giao nhau của hai khoảng giờ trong ngày, 0 nếu không giao. Bản `time` của phut_giao_nhau() — không đụng tới ngày tháng nên không có múi giờ để mà sai.';

-- ---------------------------------------------------------
-- 4. Giờ thường và giờ ngoài giờ của một tổ hợp ca
--
-- Luật, viết ra một lần ở đây:
--
--   giờ nghỉ   = phần ca giao với giờ nghỉ trưa → KHÔNG trả tiền, không phải
--                giờ thường cũng không phải ngoài giờ.
--   giờ thường = phần ca nằm trong khung giờ chuẩn, đã trừ giờ nghỉ.
--   ngoài giờ  = phần còn lại của ca.
--
-- Ví dụ, công ty khai khung 08:00–17:00 nghỉ 12:00–13:00:
--   ca sáng 07:00–11:00 → 1h ngoài giờ (07–08) + 3h thường
--   ca tối  18:00–22:00 → 4h ngoài giờ
--
-- TỪ CHỐI khi thiếu tham số, không trả 0: công ty chưa khai khung giờ, hoặc
-- tick một ca chưa khai / đã ngừng dùng. Trả 0 ở đây là ghi nhận người ta đi
-- làm cả ngày mà không có giờ nào.
-- ---------------------------------------------------------
create or replace function public.gio_ca_cong_nhat(
  p_company_id uuid,
  p_ca_sang    boolean,
  p_ca_chieu   boolean,
  p_ca_toi     boolean,
  out so_gio    numeric,
  out so_gio_ot numeric
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  cty        record;
  ca         record;
  da_tick    text[] := array[]::text[];
  phut_tong  integer := 0;
  phut_nghi  integer := 0;
  phut_trong integer := 0;
  thieu      text;
begin
  -- Ép kiểu tường minh: `text[] || 'sang'` bị Postgres đọc là nối HAI MẢNG,
  -- và nó ngã ngay với "malformed array literal".
  if p_ca_sang  then da_tick := da_tick || 'sang'::text;  end if;
  if p_ca_chieu then da_tick := da_tick || 'chieu'::text; end if;
  if p_ca_toi   then da_tick := da_tick || 'toi'::text;   end if;

  -- Không tick ca nào = nghỉ. Không cần tham số nào để nói ra điều đó.
  if array_length(da_tick, 1) is null then
    so_gio := 0; so_gio_ot := 0;
    return;
  end if;

  select c.name, c.gio_vao, c.gio_ra, c.nghi_tu, c.nghi_den
    into cty
  from public.companies c where c.id = p_company_id;

  if cty.gio_vao is null then
    raise exception
      'Công ty "%" chưa khai khung giờ chuẩn. Vào Quản trị → Công ty khai giờ vào, giờ ra và giờ nghỉ trưa — không có nó thì không biết giờ nào là ngoài giờ.',
      coalesce(cty.name, '?')
      using errcode = 'check_violation';
  end if;

  select string_agg(m, ', ' order by m) into thieu
  from unnest(da_tick) m
  where not exists (
    select 1 from public.ca_cong_nhat c
    where c.company_id = p_company_id and c.ma = m and c.is_active
  );

  if thieu is not null then
    raise exception
      'Công ty "%" chưa khai ca: %. Vào Quản trị → Công ty khai giờ cho ba ca sáng / chiều / tối.',
      coalesce(cty.name, '?'), thieu
      using errcode = 'check_violation';
  end if;

  for ca in
    select c.gio_bat_dau, c.gio_ket_thuc
    from public.ca_cong_nhat c
    where c.company_id = p_company_id and c.ma = any (da_tick) and c.is_active
  loop
    phut_tong := phut_tong
      + ceil(extract(epoch from (ca.gio_ket_thuc - ca.gio_bat_dau)) / 60)::integer;

    phut_trong := phut_trong
      + public.phut_giao_gio(ca.gio_bat_dau, ca.gio_ket_thuc, cty.gio_vao, cty.gio_ra);

    if cty.nghi_tu is not null then
      phut_nghi := phut_nghi
        + public.phut_giao_gio(ca.gio_bat_dau, ca.gio_ket_thuc, cty.nghi_tu, cty.nghi_den);
    end if;
  end loop;

  -- Giờ nghỉ nằm trong khung (ràng buộc mục 1), nên nó đang được đếm trong
  -- `phut_trong` và phải trừ đúng một lần ở đó.
  so_gio    := round((phut_trong - phut_nghi)::numeric / 60, 2);
  so_gio_ot := round((phut_tong - phut_nghi - (phut_trong - phut_nghi))::numeric / 60, 2);
end;
$$;

comment on function public.gio_ca_cong_nhat(uuid, boolean, boolean, boolean) is
  'Giờ thường và giờ ngoài giờ của một tổ hợp ca, theo khung giờ chuẩn của công ty. Nguồn DUY NHẤT của luật đó — trigger và giao diện đều hỏi vào đây.';

revoke all    on function public.gio_ca_cong_nhat(uuid, boolean, boolean, boolean) from public;
revoke all    on function public.gio_ca_cong_nhat(uuid, boolean, boolean, boolean) from anon;
grant execute on function public.gio_ca_cong_nhat(uuid, boolean, boolean, boolean) to authenticated;

-- ---------------------------------------------------------
-- 5. Dòng công mang BA Ô TICK, không mang số giờ gõ tay
--
-- `so_cong` chuyển sang cho phép NULL. 12 dòng cũ giữ nguyên giá trị của
-- chúng và vẫn là căn cứ của hai bảng thanh toán đã sinh; dòng mới để trống ô
-- ấy. Ràng buộc `cccn_so_cong_hop_le` vẫn còn nguyên và vẫn gác đúng những
-- dòng có giá trị — `null in (0, 0.5, 1)` trả NULL, mà CHECK chỉ chặn FALSE.
-- ---------------------------------------------------------
alter table public.cham_cong_cong_nhat
  alter column so_cong drop not null;

alter table public.cham_cong_cong_nhat
  add column ca_sang  boolean not null default false,
  add column ca_chieu boolean not null default false,
  add column ca_toi   boolean not null default false;

comment on column public.cham_cong_cong_nhat.so_cong is
  'LỊCH SỬ, chỉ có ở những dòng chấm theo kiểu khoán ngày trước 24/08/2026. Dòng mới để NULL và mang ba ô tick ca.';

comment on column public.cham_cong_cong_nhat.ca_sang is
  'Có làm ca sáng của công ty hay không. Số giờ suy ra từ đây, không ai gõ tay.';

-- Ràng buộc "một dòng một đơn vị" của P5c nói: có công thì không có giờ, có
-- giờ thì không có công. Dòng chấm theo ca mà nghỉ cả ba ca thì so_gio = 0 —
-- vẫn là "có giờ", chỉ là bằng không. Nên ràng buộc cũ vẫn đúng nguyên văn và
-- không cần đụng tới.

-- Tick ca thì không được đồng thời mang số công: hai đơn vị trên một dòng là
-- bảng thanh toán cộng cả hai và trả gấp đôi.
alter table public.cham_cong_cong_nhat
  add constraint cccn_ca_khong_kem_so_cong
  check (not (ca_sang or ca_chieu or ca_toi) or so_cong is null);

-- ---------------------------------------------------------
-- 6. Số giờ do DATABASE tính, client không đặt được
--
-- Đây là điểm cốt lõi của bản này. Trigger chạy trước mọi lệnh ghi và đặt lại
-- `so_gio` / `so_gio_ot` từ ba ô tick, kể cả khi client cố gửi giá trị khác.
-- Quyền cấp cột bên dưới còn chặn thêm một lớp: `authenticated` không có
-- quyền UPDATE hai cột ấy nữa.
--
-- Dòng LỊCH SỬ (`so_cong` not null) đi thẳng, không bị viết lại.
-- ---------------------------------------------------------
create or replace function public.tinh_gio_tu_ca()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  cty uuid;
  kq  record;
begin
  if new.so_cong is not null then
    return new;
  end if;

  select t.company_id into cty
  from public.phien_cham_cong_to p
  join public.to_doi t on t.id = p.to_doi_id
  where p.id = new.phien_id;

  select * into kq
  from public.gio_ca_cong_nhat(cty, new.ca_sang, new.ca_chieu, new.ca_toi);

  new.so_gio    := kq.so_gio;
  new.so_gio_ot := kq.so_gio_ot;

  return new;
end;
$$;

comment on function public.tinh_gio_tu_ca() is
  'Đặt lại so_gio và so_gio_ot từ ba ô tick ca, mọi lệnh ghi. Client gửi số giờ nào cũng bị ghi đè — ngoài giờ là tiền nhân hệ số, không để người chấm tự quyết.';

create trigger trg_cccn_tinh_gio_tu_ca
  before insert or update on public.cham_cong_cong_nhat
  for each row execute function public.tinh_gio_tu_ca();

-- Quyền cấp cột: bỏ `so_gio`, `so_gio_ot` khỏi tay client, thêm ba ô tick.
-- `so_cong` cũng bỏ khỏi quyền GHI MỚI — kiểu khoán ngày đã bỏ, và cho ghi
-- tiếp là mở lại đúng con đường vừa đóng.
revoke insert (so_cong, so_gio, so_gio_ot) on public.cham_cong_cong_nhat from authenticated;
revoke update (so_cong, so_gio, so_gio_ot) on public.cham_cong_cong_nhat from authenticated;

grant insert (phien_id, work_date, employee_id, ca_sang, ca_chieu, ca_toi, ghi_chu)
  on public.cham_cong_cong_nhat to authenticated;
grant update (ca_sang, ca_chieu, ca_toi, ghi_chu)
  on public.cham_cong_cong_nhat to authenticated;

-- ---------------------------------------------------------
-- 7. Đơn giá GIỜ, tách hẳn khỏi đơn giá công
--
-- Đổi tên `don_gia` → `don_gia_cong` và thêm `don_gia_gio`, thay vì đổi nghĩa
-- cột cũ tại chỗ. 12 dòng đang có giữ số tiền MỘT CÔNG; đọc con số ấy như đơn
-- giá một GIỜ là trả gấp tám lần. Một cái tên nói đúng nghĩa rẻ hơn nhiều so
-- với một lần trả nhầm.
--
-- Không quy đổi tự động: xem đầu file.
-- ---------------------------------------------------------
alter table public.to_doi_thanh_vien rename column don_gia to don_gia_cong;

alter table public.to_doi_thanh_vien
  add column don_gia_gio numeric(15, 2) check (don_gia_gio >= 0);

comment on column public.to_doi_thanh_vien.don_gia_cong is
  'LỊCH SỬ — tiền một CÔNG, của kiểu khoán ngày đã bỏ ngày 24/08/2026. Chỉ còn dùng để tính lại những bảng thanh toán của dòng công cũ.';

comment on column public.to_doi_thanh_vien.don_gia_gio is
  'Tiền một GIỜ làm trong khung giờ chuẩn. NULL = chưa khai, và bảng thanh toán sẽ từ chối sinh chứ không tính 0 đồng.';

-- Nhân công thêm mới từ nay tính theo giờ. Dòng cũ giữ nguyên 'ngay'.
alter table public.to_doi_thanh_vien alter column kieu_tinh set default 'gio';

-- ---------------------------------------------------------
-- 8. Bảng thanh toán đọc đúng đơn giá theo kiểu tính
--
-- Chỉ đổi ĐÚNG chỗ lấy đơn giá. Toàn bộ phần còn lại — chỉ cộng phiên đã
-- duyệt, từ chối khi thiếu đơn giá, đếm dòng chờ duyệt — giữ nguyên từng chữ
-- của P5d.
-- ---------------------------------------------------------
create or replace function public.sinh_bang_thanh_toan_to(
  p_to_doi_id uuid,
  p_tu_ngay   date,
  p_den_ngay  date
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
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

  create temporary table tam_cong on commit drop as
  select
    c.employee_id,
    tv.kieu_tinh,
    sum(
      case when tv.kieu_tinh = 'gio' then coalesce(c.so_gio, 0)
           else coalesce(c.so_cong, 0) end
    )                                  as so_luong,
    sum(coalesce(c.so_gio_ot, 0))      as so_gio_ot,
    case when tv.kieu_tinh = 'gio' then tv.don_gia_gio
         else tv.don_gia_cong end      as don_gia,
    tv.don_gia_ot                      as don_gia_ot
  from public.cham_cong_cong_nhat c
  join public.phien_cham_cong_to p on p.id = c.phien_id
  join lateral (
    select t2.kieu_tinh, t2.don_gia_cong, t2.don_gia_gio, t2.don_gia_ot
    from public.to_doi_thanh_vien t2
    where t2.to_doi_id = p_to_doi_id
      and t2.employee_id = c.employee_id
      and t2.tu_ngay <= p_den_ngay
      and (t2.den_ngay is null or t2.den_ngay >= p_tu_ngay)
    order by t2.tu_ngay desc
    limit 1
  ) tv on true
  where p.to_doi_id = p_to_doi_id
    and p.da_duyet
    and c.work_date between p_tu_ngay and p_den_ngay
  group by c.employee_id, tv.kieu_tinh, tv.don_gia_cong, tv.don_gia_gio, tv.don_gia_ot
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
      'Chưa có đơn giá giờ cho: %. Sửa dòng của họ trong danh sách nhân công của tổ và nhập đơn giá một giờ.',
      thieu_gia;
  end if;

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
      'Không có ngày công nào ĐÃ DUYỆT trong khoảng % đến % của tổ %. Phiên chấm công phải được duyệt trước.',
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
$$;

-- ---------------------------------------------------------
-- 9. Thêm và sửa nhân công: nhận đơn giá GIỜ
--
-- Hai hàm này chạy `security definer` nên chúng tự kiểm quyền ngay dòng đầu —
-- giữ nguyên như P5c. Chỉ đổi tham số đơn giá.
--
-- Bỏ luôn tham số `p_kieu_tinh`: kiểu khoán ngày đã bỏ, để lại một ô chọn chỉ
-- còn một giá trị hợp lệ là mời người ta chọn nhầm.
-- ---------------------------------------------------------
drop function if exists public.them_nhan_cong_to(uuid, text, text, text, numeric, numeric, date);

create or replace function public.them_nhan_cong_to(
  p_to_doi_id   uuid,
  p_ho_ten      text,
  p_cccd        text    default null,
  p_don_gia_gio numeric default null,
  p_don_gia_ot  numeric default null,
  p_tu_ngay     date    default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  chuc_danh uuid;
  cty       uuid;
  ma        text;
  nv        uuid;
begin
  if not (public.la_nguoi_cham_cong_to(p_to_doi_id) or public.is_hr_or_admin()) then
    raise exception 'Bạn không phụ trách tổ này.';
  end if;

  if coalesce(btrim(p_ho_ten), '') = '' then
    raise exception 'Thiếu họ và tên.';
  end if;
  if p_don_gia_gio is not null and p_don_gia_gio < 0 then
    raise exception 'Đơn giá giờ không được âm.';
  end if;
  if p_don_gia_ot is not null and p_don_gia_ot < 0 then
    raise exception 'Đơn giá ngoài giờ không được âm.';
  end if;

  select id into chuc_danh from public.positions where la_cong_nhat limit 1;
  if chuc_danh is null then
    raise exception 'Chưa đánh dấu chức danh nào là "công nhật". Vào Quản trị → Tổ đội công nhật để tích chức danh dùng cho nhân công thuê ngoài.';
  end if;

  select company_id into cty from public.to_doi where id = p_to_doi_id;

  select 'CN' || lpad(
           (coalesce(max(substring(e.employee_code from '^CN(\d+)$')::integer), 0) + 1)::text,
           4, '0')
    into ma
  from public.employees e
  where e.employee_code ~ '^CN\d+$';

  insert into public.employees
    (employee_code, full_name, status, company_id, position_id, theo_doi_cham_cong)
  values
    (ma, btrim(p_ho_ten), 'cong_tac_vien', cty, chuc_danh, false)
  returning id into nv;

  if coalesce(btrim(p_cccd), '') <> '' then
    insert into public.employee_sensitive (employee_id, cccd)
    values (nv, btrim(p_cccd));
  end if;

  insert into public.to_doi_thanh_vien
    (to_doi_id, employee_id, tu_ngay, kieu_tinh, don_gia_gio, don_gia_ot)
  values
    (p_to_doi_id, nv, coalesce(p_tu_ngay, current_date), 'gio', p_don_gia_gio, p_don_gia_ot);

  return nv;
end;
$$;

revoke all    on function public.them_nhan_cong_to(uuid, text, text, numeric, numeric, date) from anon, public;
grant execute on function public.them_nhan_cong_to(uuid, text, text, numeric, numeric, date) to authenticated;

drop function if exists public.sua_nhan_cong_to(uuid, text, text, text, numeric, numeric);

create or replace function public.sua_nhan_cong_to(
  p_thanh_vien_id uuid,
  p_ho_ten        text    default null,
  p_cccd          text    default null,
  p_don_gia_gio   numeric default null,
  p_don_gia_ot    numeric default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  tv record;
begin
  select * into tv from public.to_doi_thanh_vien where id = p_thanh_vien_id;
  if not found then raise exception 'Không tìm thấy dòng thành viên.'; end if;

  if not (public.la_nguoi_cham_cong_to(tv.to_doi_id) or public.is_hr_or_admin()) then
    raise exception 'Bạn không phụ trách tổ này.';
  end if;

  if coalesce(btrim(p_ho_ten), '') <> '' then
    update public.employees set full_name = btrim(p_ho_ten) where id = tv.employee_id;
  end if;

  -- Để trống ô CCCD nghĩa là GIỮ NGUYÊN, không phải xoá. Xoá một số giấy tờ
  -- phải là hành động có chủ đích, không phải hệ quả của việc bỏ trống ô.
  if coalesce(btrim(p_cccd), '') <> '' then
    insert into public.employee_sensitive (employee_id, cccd)
    values (tv.employee_id, btrim(p_cccd))
    on conflict (employee_id) do update set cccd = excluded.cccd;
  end if;

  -- Khai đơn giá giờ là chuyển hẳn người này sang tính theo ca. Không có bước
  -- ấy thì 12 người khoán ngày cũ khai xong đơn giá vẫn nằm ở nhánh cũ.
  update public.to_doi_thanh_vien
  set don_gia_gio = coalesce(p_don_gia_gio, don_gia_gio),
      don_gia_ot  = coalesce(p_don_gia_ot, don_gia_ot),
      kieu_tinh   = case when coalesce(p_don_gia_gio, don_gia_gio) is not null
                         then 'gio' else kieu_tinh end
  where id = p_thanh_vien_id;
end;
$$;

revoke all    on function public.sua_nhan_cong_to(uuid, text, text, numeric, numeric) from anon, public;
grant execute on function public.sua_nhan_cong_to(uuid, text, text, numeric, numeric) to authenticated;

-- ---------------------------------------------------------
-- 10. RLS cho bảng ca
--
--     Đọc: mọi tài khoản còn hiệu lực, như `companies` và `work_shifts` — tổ
--     trưởng phải đọc được giờ của ca để màn chấm công nói ra được "ca sáng
--     07:00–11:00".
--     Ghi: CHỈ admin. Giờ của ca ra tiền ngoài giờ, nên nó là tham số chính
--     sách, không phải thứ người ở công trường tự sửa.
-- ---------------------------------------------------------
alter table public.ca_cong_nhat enable row level security;
alter table public.ca_cong_nhat force  row level security;

create policy "ca_cong_nhat_select_moi_nguoi"
  on public.ca_cong_nhat for select
  to authenticated
  using ((select public.current_app_role()) is not null);

create policy "ca_cong_nhat_insert_admin"
  on public.ca_cong_nhat for insert
  to authenticated
  with check ((select public.current_app_role()) = 'admin');

create policy "ca_cong_nhat_update_admin"
  on public.ca_cong_nhat for update
  to authenticated
  using ((select public.current_app_role()) = 'admin')
  with check ((select public.current_app_role()) = 'admin');

create policy "ca_cong_nhat_delete_admin"
  on public.ca_cong_nhat for delete
  to authenticated
  using ((select public.current_app_role()) = 'admin');

revoke all on public.ca_cong_nhat from anon, authenticated;
grant select, insert, update, delete on public.ca_cong_nhat to authenticated;
