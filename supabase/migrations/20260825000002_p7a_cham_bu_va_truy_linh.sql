-- =========================================================
-- P7a — Chấm bù công sót, sửa giờ, mở lại phiên tổ đội, và truy lĩnh
--
-- Triệu Vũ, 25/08/2026: "Hiện tại chưa có tab sửa chữa công, chấm bù công do
-- sót, bạn thiết kế cho tôi."
--
-- ĐANG MỞ MỘT CỬA CỐ Ý ĐÓNG — NÊN NÓI RÕ NÓ ĐÓNG VÌ SAO
--
-- `attendance_logs.logged_at` lấy mặc định `now()` của database, và Edge
-- Function `cham-cong` cố ý BỎ QUA mọi giờ client gửi lên. Đó là thứ làm cho
-- một lần chấm công có nghĩa: không ai bịa được giờ.
--
-- "Chấm bù" phá đúng tính chất ấy. Nên nó không được là một ô nhập giờ tự do:
--
--   1. Đòi quyền RIÊNG (`sua_chua_cong`), không dùng chung với xác nhận.
--   2. Đòi LÝ DO ít nhất 10 ký tự. Một chữ "bù" không phải lý do.
--   3. Dòng sinh ra mang cờ `la_cham_bu` — nó KHÔNG BAO GIỜ trông giống một
--      lần chấm có ảnh selfie. Ai đọc bảng công thấy ngay dòng nào là người
--      bấm, dòng nào là người khai hộ.
--   4. Mọi thao tác ghi một dòng vào `sua_chua_cong` — bất biến, có ảnh chụp
--      trước/sau, có tên người làm.
--   5. Kỳ lương đã CHỐT thì TỪ CHỐI. Không sửa được số đã trả.
--
-- SÓT CÔNG CỦA KỲ ĐÃ CHỐT THÌ ĐI ĐƯỜNG TRUY LĨNH
--
-- Triệu Vũ chọn (25/08): khoá kỳ đã chốt, bù sang kỳ đang mở bằng một khoản
-- truy lĩnh ghi rõ "bù công ngày nào".
--
-- Giữ được hai thứ cùng lúc: nguyên tắc "chốt là một chiều" có từ P3, và
-- phiếu lương đã phát cho người lao động ký thì không bị đổi số sau lưng họ.
-- Người bị sót vẫn nhận đủ tiền, chỉ nhận ở kỳ sau và nhìn thấy rõ vì sao.
-- =========================================================

-- ---------------------------------------------------------
-- 1. Cờ đánh dấu công do người khác khai hộ
-- ---------------------------------------------------------
alter table public.attendance_logs
  add column la_cham_bu boolean not null default false;

comment on column public.attendance_logs.la_cham_bu is
  'Lần chấm này do người có quyền sửa chữa công KHAI HỘ, không phải người lao động tự bấm. Không có ảnh selfie. Giao diện phải hiện khác đi.';

-- ---------------------------------------------------------
-- 2. Sổ ghi vết — bất biến
--
--    Không có policy UPDATE hay DELETE nào. Sổ mà sửa được thì nó không phải
--    sổ, cùng lý do đã dùng cho `chung_tu` ở P6a.
-- ---------------------------------------------------------
create type public.loai_sua_cong as enum (
  'cham_bu',        -- khai hộ một lần chấm chưa từng có
  'xoa_lan_cham',   -- xoá một lần chấm sai
  'mo_lai_phien',   -- mở lại phiên tổ đội đã duyệt
  'truy_linh'       -- tạo khoản bù tiền cho kỳ đã chốt
);

create table public.sua_chua_cong (
  id           uuid primary key default gen_random_uuid(),
  loai         public.loai_sua_cong not null,

  -- NULL khi thao tác nhắm vào cả phiên tổ đội chứ không vào một người.
  employee_id  uuid references public.employees (id),
  phien_id     uuid references public.phien_cham_cong_to (id) on delete set null,

  work_date    date not null,

  -- Ảnh chụp trước/sau. `truoc` NULL nghĩa là trước đó không có gì (chấm bù
  -- một ngày trống). Chụp lại chứ không chỉ ghi "đã sửa": ba tháng sau không
  -- ai dựng lại được trạng thái cũ nếu không có ảnh này.
  truoc        jsonb,
  sau          jsonb,

  -- Một chữ "bù" không phải lý do. Ràng buộc ở database chứ không chỉ ở giao
  -- diện — người gọi thẳng PostgREST cũng phải viết ra lý do.
  ly_do        text not null check (length(btrim(ly_do)) >= 10),

  nguoi_sua    uuid not null references public.app_users (id),
  sua_luc      timestamptz not null default now()
);

comment on table public.sua_chua_cong is
  'Sổ ghi vết mọi lần can thiệp vào công. BẤT BIẾN: không có policy UPDATE/DELETE nào. Chụp lại trạng thái trước và sau, không chỉ ghi "đã sửa".';

create index idx_sua_chua_cong_nguoi on public.sua_chua_cong (employee_id, work_date desc);
create index idx_sua_chua_cong_luc   on public.sua_chua_cong (sua_luc desc);

alter table public.sua_chua_cong enable row level security;

-- Ai được sửa thì được đọc sổ. Cộng thêm người tính lương: một khoản truy
-- lĩnh xuất hiện trong bảng lương thì họ phải tra được nó từ đâu ra.
create policy "sua_chua_cong_select"
  on public.sua_chua_cong for select
  to authenticated
  using ((select public.duoc_sua_chua_cong() or public.can_read_payroll()));

grant select on public.sua_chua_cong to authenticated;
revoke insert, update, delete on public.sua_chua_cong from authenticated;
revoke all on public.sua_chua_cong from anon;

-- ---------------------------------------------------------
-- 3. Truy lĩnh — khoản bù tiền cho công sót của kỳ đã chốt
-- ---------------------------------------------------------
create table public.truy_linh_luong (
  id           uuid primary key default gen_random_uuid(),
  employee_id  uuid not null references public.employees (id),

  -- Kỳ SẼ TRẢ. Engine cộng mọi dòng của kỳ nó đang tính, mỗi lần tính lại đều
  -- cộng đúng như thế — không có cờ "đã tính", vì cờ ấy sẽ sai ngay lần tính
  -- lại thứ hai.
  period_id    uuid not null references public.payroll_periods (id),

  ngay_goc     date not null,
  so_tien      numeric(15, 2) not null check (so_tien > 0),

  -- Căn cứ tính, chụp lại lúc tạo. Bài học 19/08: mọi bảng ra tiền phải chụp
  -- lại CĂN CỨ, không chỉ kết quả — sửa mức lương về sau không được làm đổi
  -- một khoản đã duyệt.
  can_cu       jsonb not null,

  ly_do        text not null check (length(btrim(ly_do)) >= 10),
  nguoi_tao    uuid not null references public.app_users (id),
  tao_luc      timestamptz not null default now(),

  -- Một ngày công sót chỉ được bù MỘT lần. Thiếu ràng buộc này thì bấm hai
  -- lần là trả tiền hai lần, và không ai phát hiện cho tới khi đối chiếu quỹ.
  constraint truy_linh_mot_ngay_mot_lan unique (employee_id, ngay_goc)
);

comment on table public.truy_linh_luong is
  'Khoản bù tiền cho ngày công bị sót của kỳ ĐÃ CHỐT, trả vào kỳ đang mở. Engine cộng thẳng vào gross và ghi một dòng payslip_items.';

create index idx_truy_linh_ky on public.truy_linh_luong (period_id);

alter table public.truy_linh_luong enable row level security;

create policy "truy_linh_select"
  on public.truy_linh_luong for select
  to authenticated
  using (
    (select public.duoc_sua_chua_cong() or public.can_read_payroll())
    -- Người lao động xem được khoản của CHÍNH MÌNH: nó là tiền của họ, và
    -- phiếu lương sẽ hiện nó.
    or employee_id = (select public.current_employee_id())
  );

grant select on public.truy_linh_luong to authenticated;
revoke insert, update, delete on public.truy_linh_luong from authenticated;
revoke all on public.truy_linh_luong from anon;

-- ---------------------------------------------------------
-- 4. Kỳ lương của một ngày đã chốt chưa
--
--    Dùng ở cả ba hàm dưới, nên viết một lần. Trả NULL khi tháng ấy chưa có
--    kỳ lương nào — chưa có kỳ thì chưa chốt, và sửa được.
-- ---------------------------------------------------------
create or replace function public.ky_luong_cua_ngay(p_employee_id uuid, p_ngay date)
returns public.payroll_periods
language sql
stable
security definer
set search_path = ''
as $$
  select k.*
  from public.payroll_periods k
  join public.employees e on e.id = p_employee_id
  where k.month = extract(month from p_ngay)::smallint
    and k.year  = extract(year  from p_ngay)::smallint
    and k.company_id is not distinct from e.company_id
  limit 1;
$$;

revoke execute on function public.ky_luong_cua_ngay(uuid, date) from public, anon;
grant  execute on function public.ky_luong_cua_ngay(uuid, date) to authenticated;

-- ---------------------------------------------------------
-- 5. Chấm bù một ngày công
--
--    `security definer` vì nó phải ghi vào `attendance_logs` — bảng không có
--    policy INSERT nào cho `authenticated`, cố ý từ P2. Đổi lại, nó TỰ KIỂM
--    quyền ngay dòng đầu: hàm chạy quyền cao mà không tự kiểm là cửa hậu.
-- ---------------------------------------------------------
create or replace function public.cham_bu_cong(
  p_employee_id uuid,
  p_work_date   date,
  p_gio_vao     time,
  p_gio_ra      time,
  p_ly_do       text
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  ky      public.payroll_periods%rowtype;
  nv      public.employees%rowtype;
  uid     uuid := (select auth.uid());
  da_co   integer;
  vao_at  timestamptz;
  ra_at   timestamptz;
  so_phut integer;
begin
  if not public.duoc_sua_chua_cong() then
    raise exception 'Bạn không có quyền chấm bù công. Quyền này thuộc quản trị hệ thống, hoặc tài khoản được tick tab "Sửa chữa công" tại Quản trị → Người dùng.'
      using errcode = 'insufficient_privilege';
  end if;

  if length(btrim(coalesce(p_ly_do, ''))) < 10 then
    raise exception 'Phải ghi lý do chấm bù, ít nhất 10 ký tự. Đây là dòng duy nhất giải thích vì sao có một lần chấm không ai bấm.'
      using errcode = 'check_violation';
  end if;

  select * into nv from public.employees where id = p_employee_id and deleted_at is null;
  if not found then
    raise exception 'Không tìm thấy hồ sơ nhân sự %.', p_employee_id;
  end if;

  if p_gio_ra <= p_gio_vao then
    raise exception 'Giờ ra (%) phải sau giờ vào (%).', p_gio_ra, p_gio_vao
      using errcode = 'check_violation';
  end if;

  if p_work_date > (now() at time zone 'Asia/Ho_Chi_Minh')::date then
    raise exception 'Không chấm bù cho ngày trong tương lai (%).', p_work_date
      using errcode = 'check_violation';
  end if;

  -- Kỳ đã chốt thì dừng, và NÊU ĐƯỜNG ĐI TIẾP thay vì chỉ từ chối. Một câu từ
  -- chối không chỉ đường là một cuộc gọi hỗ trợ.
  ky := public.ky_luong_cua_ngay(p_employee_id, p_work_date);
  if ky.id is not null and ky.status <> 'mo' then
    raise exception 'Kỳ lương %/% đã chốt nên không sửa công của ngày % được. Dùng nút "Tạo khoản truy lĩnh" để bù tiền vào kỳ đang mở.',
      ky.month, ky.year, p_work_date
      using errcode = 'insufficient_privilege';
  end if;

  select count(*) into da_co
  from public.attendance_logs
  where employee_id = p_employee_id
    and deleted_at is null
    and (logged_at at time zone 'Asia/Ho_Chi_Minh')::date = p_work_date;

  if da_co > 0 then
    raise exception 'Ngày % đã có % lần chấm. Xoá lần chấm sai trước rồi mới bù, để không có hai bản ghi cùng nói về một buổi làm.',
      p_work_date, da_co
      using errcode = 'unique_violation';
  end if;

  -- Dựng mốc thời gian theo giờ Việt Nam rồi đổi về timestamptz. Ghép thẳng
  -- date + time rồi để Postgres suy diễn múi giờ của server là cách sai lệch
  -- 7 tiếng mà không ai thấy ngay.
  vao_at := (p_work_date + p_gio_vao) at time zone 'Asia/Ho_Chi_Minh';
  ra_at  := (p_work_date + p_gio_ra)  at time zone 'Asia/Ho_Chi_Minh';

  insert into public.attendance_logs
    (employee_id, check_type, logged_at, la_cham_bu,
     da_xac_nhan, xac_nhan_boi, xac_nhan_luc, ghi_chu_xac_nhan)
  values
    (p_employee_id, 'in',  vao_at, true, true, uid, now(), 'Chấm bù: ' || p_ly_do),
    (p_employee_id, 'out', ra_at,  true, true, uid, now(), 'Chấm bù: ' || p_ly_do);

  -- Tổng hợp lại ngày đó. Không gọi thì `attendance_days` vẫn giữ số cũ và
  -- bảng lương đọc số cũ — chấm bù xong mà lương không đổi.
  perform public.tong_hop_cong_ngay(p_work_date);

  select worked_minutes into so_phut
  from public.attendance_days
  where employee_id = p_employee_id and work_date = p_work_date;

  insert into public.sua_chua_cong
    (loai, employee_id, work_date, truoc, sau, ly_do, nguoi_sua)
  values (
    'cham_bu', p_employee_id, p_work_date,
    jsonb_build_object('so_lan_cham', 0, 'phut_lam', 0),
    jsonb_build_object('gio_vao', p_gio_vao, 'gio_ra', p_gio_ra,
                       'phut_lam', coalesce(so_phut, 0)),
    p_ly_do, uid
  );

  return coalesce(so_phut, 0);
end;
$$;

comment on function public.cham_bu_cong(uuid, date, time, time, text) is
  'Khai hộ một ngày công chưa từng được bấm. Dòng sinh ra mang cờ la_cham_bu nên không bao giờ trông giống lần chấm thật. Từ chối khi kỳ lương đã chốt.';

revoke execute on function public.cham_bu_cong(uuid, date, time, time, text) from public, anon;
grant  execute on function public.cham_bu_cong(uuid, date, time, time, text) to authenticated;

-- ---------------------------------------------------------
-- 6. Mở lại phiên chấm công tổ đội đã duyệt
--
--    Tổ đội KHÔNG dùng `cham_bu_cong`: ở đó người chấm gõ số công thẳng vào
--    `cham_cong_cong_nhat`, và mọi thứ khoá lại khi phiên được duyệt. Nên
--    đường sửa của tổ đội là MỞ LẠI PHIÊN, rồi sửa như bình thường.
-- ---------------------------------------------------------
create or replace function public.mo_lai_phien_to(p_phien_id uuid, p_ly_do text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  ph     public.phien_cham_cong_to%rowtype;
  bang   text;
  uid    uuid := (select auth.uid());
begin
  if not public.duoc_sua_chua_cong() then
    raise exception 'Bạn không có quyền mở lại phiên chấm công. Quyền này thuộc quản trị hệ thống, hoặc tài khoản được tick tab "Sửa chữa công".'
      using errcode = 'insufficient_privilege';
  end if;

  if length(btrim(coalesce(p_ly_do, ''))) < 10 then
    raise exception 'Phải ghi lý do mở lại phiên, ít nhất 10 ký tự.'
      using errcode = 'check_violation';
  end if;

  select * into ph from public.phien_cham_cong_to where id = p_phien_id;
  if not found then
    raise exception 'Không tìm thấy phiên chấm công %.', p_phien_id;
  end if;
  if not ph.da_duyet then
    raise exception 'Phiên ngày % chưa duyệt nên đang sửa được rồi, không cần mở lại.', ph.work_date;
  end if;

  -- Bảng thanh toán đã sinh cho khoảng ngày này thì con số đã chốt và đã có
  -- chứng từ PDF. Mở lại phiên mà không nói gì là để hai con số cùng tồn tại:
  -- bảng nói một đằng, phiên nói một nẻo.
  select string_agg(
           to_char(b.tu_ngay, 'DD/MM') || '–' || to_char(b.den_ngay, 'DD/MM/YYYY'), ', ')
    into bang
  from public.bang_thanh_toan_to b
  where b.to_doi_id = ph.to_doi_id
    and ph.work_date between b.tu_ngay and b.den_ngay;

  if bang is not null then
    raise exception 'Ngày % đã nằm trong bảng thanh toán (%). Xoá bảng đó trước rồi mới mở lại phiên, nếu không sẽ có hai con số khác nhau cho cùng một ngày công.',
      ph.work_date, bang
      using errcode = 'insufficient_privilege';
  end if;

  update public.phien_cham_cong_to
  set da_duyet = false, duyet_boi = null, duyet_luc = null
  where id = p_phien_id;

  insert into public.sua_chua_cong
    (loai, employee_id, phien_id, work_date, truoc, sau, ly_do, nguoi_sua)
  values (
    'mo_lai_phien', null, p_phien_id, ph.work_date,
    jsonb_build_object('da_duyet', true, 'duyet_boi', ph.duyet_boi, 'duyet_luc', ph.duyet_luc),
    jsonb_build_object('da_duyet', false),
    p_ly_do, uid
  );
end;
$$;

comment on function public.mo_lai_phien_to(uuid, text) is
  'Mở lại phiên chấm công tổ đội đã duyệt để sửa. TỪ CHỐI khi ngày đó đã nằm trong một bảng thanh toán — xoá bảng trước, nếu không sẽ có hai con số cho cùng một ngày.';

revoke execute on function public.mo_lai_phien_to(uuid, text) from public, anon;
grant  execute on function public.mo_lai_phien_to(uuid, text) to authenticated;

-- ---------------------------------------------------------
-- 7. Tạo khoản truy lĩnh
--
--    Số tiền do người tạo quyết định và LƯU LẠI, không tính lại lúc chạy
--    lương. Giao diện gợi ý con số từ mức lương tại thời điểm đó, nhưng người
--    ký mới là người chốt — kế toán biết những thứ hệ thống không biết.
-- ---------------------------------------------------------
create or replace function public.tao_truy_linh(
  p_employee_id uuid,
  p_ngay_goc    date,
  p_so_tien     numeric,
  p_ly_do       text,
  p_can_cu      jsonb default '{}'::jsonb
)
returns public.truy_linh_luong
language plpgsql
security definer
set search_path = ''
as $$
declare
  ky_goc  public.payroll_periods%rowtype;
  ky_mo   public.payroll_periods%rowtype;
  nv      public.employees%rowtype;
  uid     uuid := (select auth.uid());
  ket     public.truy_linh_luong%rowtype;
begin
  if not public.duoc_sua_chua_cong() then
    raise exception 'Bạn không có quyền tạo khoản truy lĩnh.'
      using errcode = 'insufficient_privilege';
  end if;

  if length(btrim(coalesce(p_ly_do, ''))) < 10 then
    raise exception 'Phải ghi lý do truy lĩnh, ít nhất 10 ký tự — nó sẽ hiện trên phiếu lương của người nhận.'
      using errcode = 'check_violation';
  end if;

  if p_so_tien is null or p_so_tien <= 0 then
    raise exception 'Số tiền truy lĩnh phải lớn hơn 0.' using errcode = 'check_violation';
  end if;

  select * into nv from public.employees where id = p_employee_id and deleted_at is null;
  if not found then
    raise exception 'Không tìm thấy hồ sơ nhân sự %.', p_employee_id;
  end if;

  -- Chỉ dùng đường này cho kỳ ĐÃ CHỐT. Kỳ còn mở thì sửa công thẳng, đúng và
  -- gọn hơn — tạo truy lĩnh ở đó là ghi tiền hai lần.
  ky_goc := public.ky_luong_cua_ngay(p_employee_id, p_ngay_goc);
  if ky_goc.id is null then
    raise exception 'Tháng %/% chưa có kỳ lương nào cho công ty này, nên không có gì đã chốt để phải truy lĩnh.',
      extract(month from p_ngay_goc)::int, extract(year from p_ngay_goc)::int;
  end if;
  if ky_goc.status = 'mo' then
    raise exception 'Kỳ lương %/% vẫn đang MỞ. Chấm bù thẳng vào ngày % rồi tính lại lương, đừng tạo truy lĩnh — làm cả hai là trả tiền hai lần.',
      ky_goc.month, ky_goc.year, p_ngay_goc
      using errcode = 'check_violation';
  end if;

  -- Kỳ nhận tiền: kỳ đang mở của chính công ty ấy, mới nhất.
  select * into ky_mo
  from public.payroll_periods
  where status = 'mo' and company_id is not distinct from nv.company_id
  order by year desc, month desc
  limit 1;

  if ky_mo.id is null then
    raise exception 'Không có kỳ lương nào đang mở để trả khoản truy lĩnh này. Tạo kỳ mới trước.';
  end if;

  insert into public.truy_linh_luong
    (employee_id, period_id, ngay_goc, so_tien, can_cu, ly_do, nguoi_tao)
  values (p_employee_id, ky_mo.id, p_ngay_goc, p_so_tien,
          coalesce(p_can_cu, '{}'::jsonb)
            || jsonb_build_object('ky_goc', ky_goc.month || '/' || ky_goc.year,
                                  'ky_tra', ky_mo.month || '/' || ky_mo.year),
          p_ly_do, uid)
  returning * into ket;

  insert into public.sua_chua_cong
    (loai, employee_id, work_date, truoc, sau, ly_do, nguoi_sua)
  values (
    'truy_linh', p_employee_id, p_ngay_goc,
    jsonb_build_object('ky_goc', ky_goc.month || '/' || ky_goc.year, 'trang_thai', ky_goc.status),
    jsonb_build_object('ky_tra', ky_mo.month || '/' || ky_mo.year, 'so_tien', p_so_tien),
    p_ly_do, uid
  );

  return ket;
end;
$$;

comment on function public.tao_truy_linh(uuid, date, numeric, text, jsonb) is
  'Bù tiền cho ngày công sót của kỳ ĐÃ CHỐT, trả vào kỳ đang mở. Từ chối khi kỳ gốc còn mở — ở đó phải chấm bù thẳng, làm cả hai là trả hai lần.';

revoke execute on function public.tao_truy_linh(uuid, date, numeric, text, jsonb) from public, anon;
grant  execute on function public.tao_truy_linh(uuid, date, numeric, text, jsonb) to authenticated;

-- ---------------------------------------------------------
-- 8. Xoá một lần chấm sai, có ghi vết
--
--    `xoa_cham_cong()` đã có từ P2 và vẫn giữ nguyên. Hàm này gói thêm một
--    dòng sổ, để "sửa giờ" (xoá lần sai rồi bù lần đúng) hiện ra thành hai
--    dòng liền nhau trong sổ chứ không phải một lần xoá không rõ vì sao.
-- ---------------------------------------------------------
create or replace function public.xoa_lan_cham_de_sua(p_log_id uuid, p_ly_do text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  log public.attendance_logs%rowtype;
  ky  public.payroll_periods%rowtype;
  ngay date;
begin
  if not public.duoc_sua_chua_cong() then
    raise exception 'Bạn không có quyền sửa chữa công.' using errcode = 'insufficient_privilege';
  end if;
  if length(btrim(coalesce(p_ly_do, ''))) < 10 then
    raise exception 'Phải ghi lý do xoá, ít nhất 10 ký tự.' using errcode = 'check_violation';
  end if;

  select * into log from public.attendance_logs where id = p_log_id and deleted_at is null;
  if not found then
    raise exception 'Không tìm thấy lần chấm % (hoặc đã xoá rồi).', p_log_id;
  end if;

  ngay := (log.logged_at at time zone 'Asia/Ho_Chi_Minh')::date;

  ky := public.ky_luong_cua_ngay(log.employee_id, ngay);
  if ky.id is not null and ky.status <> 'mo' then
    raise exception 'Kỳ lương %/% đã chốt nên không xoá được lần chấm ngày %. Dùng khoản truy lĩnh nếu cần bù tiền.',
      ky.month, ky.year, ngay
      using errcode = 'insufficient_privilege';
  end if;

  perform public.xoa_cham_cong(p_log_id, p_ly_do);
  perform public.tong_hop_cong_ngay(ngay);

  insert into public.sua_chua_cong
    (loai, employee_id, work_date, truoc, sau, ly_do, nguoi_sua)
  values (
    'xoa_lan_cham', log.employee_id, ngay,
    jsonb_build_object('check_type', log.check_type, 'logged_at', log.logged_at,
                       'la_cham_bu', log.la_cham_bu),
    null,
    p_ly_do, (select auth.uid())
  );
end;
$$;

comment on function public.xoa_lan_cham_de_sua(uuid, text) is
  'Xoá mềm một lần chấm sai VÀ ghi một dòng sổ. Không sửa giờ tại chỗ: bản gốc phải còn lại làm bằng chứng, nên "sửa giờ" = xoá lần sai + chấm bù lần đúng.';

revoke execute on function public.xoa_lan_cham_de_sua(uuid, text) from public, anon;
grant  execute on function public.xoa_lan_cham_de_sua(uuid, text) to authenticated;
