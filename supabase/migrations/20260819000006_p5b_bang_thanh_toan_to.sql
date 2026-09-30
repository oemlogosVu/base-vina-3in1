-- =========================================================
-- P5b — Bảng thanh toán cho tổ công nhật
--
-- Triệu Vũ duyệt 19/08/2026, sau bốn câu hỏi. Bốn quyết định:
--
--   1. Đơn giá gắn THEO CHỨC DANH, ghi đè được cho từng người. Cùng khuôn với
--      phụ cấp đang chạy (mức theo chức danh + ghi đè theo hợp đồng) — một
--      khuôn quen thì ít chỗ sai hơn một khuôn mới.
--   2. Người quản lý chấm công XEM ĐƯỢC TIỀN của tổ mình, và tự sinh bảng.
--   3. KHÔNG khấu trừ thuế TNCN. Bảng ra số gộp: số công × đơn giá. Cố ý
--      không có chỗ nào cài tỷ lệ khấu trừ — nghĩa vụ khai thuế cho khoản chi
--      này nằm ngoài phần mềm. Muốn khấu trừ thì phải mở lại phase, và con số
--      phải vào nhóm cfg_* có ngày hiệu lực như mọi con số pháp lý khác.
--   4. KHÔNG có cơ chế chốt kỳ; thay bằng quyền: sinh và xem thì nhiều người,
--      SỬA thì chỉ admin.
--
-- VÌ SAO CHỤP LẠI SỐ THAY VÌ TÍNH LẠI MỖI LẦN MỞ: bảng in ra để trả tiền
-- tháng trước không được đổi khi ai đó sửa đơn giá hôm nay. Không có ảnh chụp
-- thì "bảng đã trả" và "bảng mở lại xem" là hai con số khác nhau mà không ai
-- giải thích được — đúng loại lỗi làm mất lòng tin vào cả hệ thống.
--
-- VÌ SAO CHỈ CỘNG CÔNG ĐÃ DUYỆT: công chưa duyệt là công chưa ai xác nhận.
-- Nhưng im lặng bỏ qua chúng thì bảng ra ít tiền mà không ai hiểu vì sao, nên
-- bảng ghi lại luôn số công còn chờ duyệt trong khoảng đó.
-- =========================================================

-- ---------------------------------------------------------
-- 1. Đơn giá theo chức danh
-- ---------------------------------------------------------
create table public.don_gia_cong_nhat (
  id          uuid primary key default gen_random_uuid(),
  position_id uuid not null unique references public.positions (id) on delete cascade,
  don_gia     numeric(15, 2) not null check (don_gia >= 0),
  ghi_chu     text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

comment on table public.don_gia_cong_nhat is
  'Đơn giá một công của lao động công nhật, theo chức danh. Ghi đè cho từng người ở to_doi_thanh_vien.don_gia.';

create trigger trg_don_gia_cong_nhat_touch
  before update on public.don_gia_cong_nhat
  for each row execute function public.touch_updated_at();

-- Không seed đơn giá nào: đây là chính sách trả công của doanh nghiệp, không
-- phải thứ suy ra được. Cùng lý do với việc không seed tên công ty và biểu thuế.

-- ---------------------------------------------------------
-- 2. Ghi đè đơn giá cho từng người
--
--    Đặt trên dòng THÀNH VIÊN chứ không trên hồ sơ nhân sự: đơn giá là thoả
--    thuận trong phạm vi một tổ và một kỳ tham gia. Cùng một người sang tổ
--    khác, mùa khác, giá khác — và bảng cũ vẫn phải giữ giá cũ.
-- ---------------------------------------------------------
alter table public.to_doi_thanh_vien
  add column don_gia numeric(15, 2) check (don_gia >= 0);

comment on column public.to_doi_thanh_vien.don_gia is
  'Đơn giá riêng của người này trong tổ này. NULL = dùng mức theo chức danh ở don_gia_cong_nhat.';

-- ---------------------------------------------------------
-- 3. Bảng thanh toán
-- ---------------------------------------------------------
create table public.bang_thanh_toan_to (
  id            uuid primary key default gen_random_uuid(),
  to_doi_id     uuid not null references public.to_doi (id),
  tu_ngay       date not null,
  den_ngay      date not null,

  nguoi_tao     uuid not null references public.app_users (id),
  tao_luc       timestamptz not null default now(),
  ghi_chu       text,

  -- Số công nằm trong khoảng nhưng thuộc phiên CHƯA DUYỆT, chụp lại lúc sinh.
  -- Không có con số này thì bảng ra ít tiền mà không ai biết là do thiếu duyệt
  -- hay do tổ làm ít thật.
  cong_cho_duyet numeric(8, 2) not null default 0,

  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  constraint bang_ky_hop_le check (den_ngay >= tu_ngay),
  constraint bang_duy_nhat  unique (to_doi_id, tu_ngay, den_ngay)
);

comment on table public.bang_thanh_toan_to is
  'Bảng thanh toán của một tổ cho một khoảng ngày tự chọn. Số liệu CHỤP LẠI lúc sinh — sửa đơn giá về sau không làm đổi bảng đã sinh.';

create index idx_bang_to_doi on public.bang_thanh_toan_to (to_doi_id, tu_ngay desc);

create trigger trg_bang_thanh_toan_to_touch
  before update on public.bang_thanh_toan_to
  for each row execute function public.touch_updated_at();

create table public.dong_thanh_toan_to (
  id          uuid primary key default gen_random_uuid(),
  bang_id     uuid not null references public.bang_thanh_toan_to (id) on delete cascade,
  employee_id uuid not null references public.employees (id),

  so_cong     numeric(8, 2)  not null check (so_cong >= 0),
  don_gia     numeric(15, 2) not null check (don_gia >= 0),

  -- Cột SINH: không bao giờ lệch khỏi số công × đơn giá, kể cả khi admin sửa
  -- tay một trong hai. Lưu thành tiền như một cột thường là mở đường cho ba
  -- con số trên cùng một dòng không khớp nhau.
  thanh_tien  numeric(15, 2) generated always as (so_cong * don_gia) stored,

  ghi_chu     text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),

  constraint dong_mot_nguoi_mot_bang unique (bang_id, employee_id)
);

comment on table public.dong_thanh_toan_to is
  'Từng người trong một bảng thanh toán. thanh_tien là cột sinh nên không thể lệch khỏi so_cong × don_gia.';

create index idx_dong_bang on public.dong_thanh_toan_to (bang_id);

create trigger trg_dong_thanh_toan_to_touch
  before update on public.dong_thanh_toan_to
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------
-- 4. Ai được đọc một bảng thanh toán
-- ---------------------------------------------------------
create or replace function public.co_the_doc_bang_thanh_toan(p_bang_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.bang_thanh_toan_to b
    where b.id = p_bang_id
      and (public.can_read_payroll() or public.la_nguoi_cham_cong_to(b.to_doi_id))
  );
$$;

revoke execute on function public.co_the_doc_bang_thanh_toan(uuid) from anon;

-- ---------------------------------------------------------
-- 5. Sinh bảng
--
--    security definer vì nó phải đọc đơn giá (bảng chỉ kế toán/admin đọc
--    được) và ghi vào bảng không có policy INSERT nào. Đổi lại, nó TỰ kiểm
--    quyền ngay dòng đầu — hàm chạy quyền cao mà không tự kiểm là cửa hậu.
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
  cho_duyet numeric;
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

  -- Số công của các phiên ĐÃ DUYỆT, gộp theo người.
  create temporary table tam_cong on commit drop as
  select
    c.employee_id,
    sum(c.so_cong) as so_cong,
    -- Đơn giá: ưu tiên mức riêng của người trong tổ, sau đó tới mức của chức
    -- danh. Lấy dòng thành viên GIAO với khoảng đang tính, mới nhất trước.
    coalesce(
      (select tv.don_gia
       from public.to_doi_thanh_vien tv
       where tv.to_doi_id = p_to_doi_id
         and tv.employee_id = c.employee_id
         and tv.tu_ngay <= p_den_ngay
         and (tv.den_ngay is null or tv.den_ngay >= p_tu_ngay)
       order by tv.tu_ngay desc
       limit 1),
      (select g.don_gia
       from public.don_gia_cong_nhat g
       join public.employees e on e.position_id = g.position_id
       where e.id = c.employee_id)
    ) as don_gia
  from public.cham_cong_cong_nhat c
  join public.phien_cham_cong_to p on p.id = c.phien_id
  where p.to_doi_id = p_to_doi_id
    and p.da_duyet
    and c.work_date between p_tu_ngay and p_den_ngay
    and c.so_cong > 0
  group by c.employee_id;

  -- THIẾU ĐƠN GIÁ THÌ TỪ CHỐI, không lặng lẽ tính 0 đồng (AGENTS.md mục 5).
  -- Nêu đích danh để người dùng biết phải nhập cho ai.
  select string_agg(e.full_name || ' (' || e.employee_code || ')', ', ' order by e.employee_code)
    into thieu_gia
  from tam_cong t
  join public.employees e on e.id = t.employee_id
  where t.don_gia is null;

  if thieu_gia is not null then
    raise exception
      'Chưa có đơn giá công nhật cho: %. Nhập đơn giá theo chức danh tại Quản trị → Tổ đội công nhật, hoặc đặt mức riêng cho từng người trong tổ.',
      thieu_gia;
  end if;

  if not exists (select 1 from tam_cong) then
    raise exception
      'Không có ngày công nào ĐÃ DUYỆT trong khoảng % đến % của tổ %. Nhân sự cần duyệt phiên chấm công trước.',
      p_tu_ngay, p_den_ngay, ten_to;
  end if;

  select coalesce(sum(c.so_cong), 0) into cho_duyet
  from public.cham_cong_cong_nhat c
  join public.phien_cham_cong_to p on p.id = c.phien_id
  where p.to_doi_id = p_to_doi_id
    and not p.da_duyet
    and c.work_date between p_tu_ngay and p_den_ngay;

  insert into public.bang_thanh_toan_to
    (to_doi_id, tu_ngay, den_ngay, nguoi_tao, cong_cho_duyet)
  values
    (p_to_doi_id, p_tu_ngay, p_den_ngay, (select auth.uid()), cho_duyet)
  returning id into bang_id;

  insert into public.dong_thanh_toan_to (bang_id, employee_id, so_cong, don_gia)
  select bang_id, t.employee_id, t.so_cong, t.don_gia from tam_cong t;

  return bang_id;
end;
$$;

comment on function public.sinh_bang_thanh_toan_to(uuid, date, date) is
  'Sinh bảng thanh toán cho một tổ trong một khoảng ngày. Chỉ cộng công của phiên ĐÃ DUYỆT; từ chối nếu thiếu đơn giá của bất kỳ ai.';

revoke execute on function public.sinh_bang_thanh_toan_to(uuid, date, date) from anon, public;
grant execute on function public.sinh_bang_thanh_toan_to(uuid, date, date) to authenticated;

-- =========================================================
-- 6. RLS
--
--    | Bảng                | Quản lý của tổ | HR/Kế toán | Admin
--    |---------------------|----------------|------------|--------
--    | don_gia_cong_nhat   | KHÔNG          | đọc        | đọc+ghi
--    | bang_thanh_toan_to  | tổ mình, đọc   | đọc        | đọc+sửa+xoá
--    | dong_thanh_toan_to  | tổ mình, đọc   | đọc        | đọc+sửa
--
--    Quản lý KHÔNG đọc danh mục đơn giá: họ chỉ cần con số của tổ mình, mà
--    con số ấy đã nằm sẵn trong bảng đã sinh. Mở cả danh mục là cho họ biết
--    giá của những tổ không phải việc của họ.
--
--    KHÔNG bảng nào có policy INSERT: dòng chỉ sinh ra qua hàm ở mục 5.
-- =========================================================

alter table public.don_gia_cong_nhat  enable row level security;
alter table public.don_gia_cong_nhat  force  row level security;
alter table public.bang_thanh_toan_to enable row level security;
alter table public.bang_thanh_toan_to force  row level security;
alter table public.dong_thanh_toan_to enable row level security;
alter table public.dong_thanh_toan_to force  row level security;

create policy "don_gia_select_luong"
  on public.don_gia_cong_nhat for select
  to authenticated
  using ((select public.can_read_payroll()));

create policy "don_gia_insert_admin"
  on public.don_gia_cong_nhat for insert
  to authenticated
  with check ((select public.current_app_role()) = 'admin');

create policy "don_gia_update_admin"
  on public.don_gia_cong_nhat for update
  to authenticated
  using ((select public.current_app_role()) = 'admin')
  with check ((select public.current_app_role()) = 'admin');

create policy "don_gia_delete_admin"
  on public.don_gia_cong_nhat for delete
  to authenticated
  using ((select public.current_app_role()) = 'admin');

create policy "bang_select_luong"
  on public.bang_thanh_toan_to for select
  to authenticated
  using ((select public.can_read_payroll()));

create policy "bang_select_nguoi_cham"
  on public.bang_thanh_toan_to for select
  to authenticated
  using ((select public.la_nguoi_cham_cong_to(to_doi_id)));

create policy "bang_update_admin"
  on public.bang_thanh_toan_to for update
  to authenticated
  using ((select public.current_app_role()) = 'admin')
  with check ((select public.current_app_role()) = 'admin');

create policy "bang_delete_admin"
  on public.bang_thanh_toan_to for delete
  to authenticated
  using ((select public.current_app_role()) = 'admin');

create policy "dong_select_duoc_doc_bang"
  on public.dong_thanh_toan_to for select
  to authenticated
  using ((select public.co_the_doc_bang_thanh_toan(bang_id)));

create policy "dong_update_admin"
  on public.dong_thanh_toan_to for update
  to authenticated
  using ((select public.current_app_role()) = 'admin')
  with check ((select public.current_app_role()) = 'admin');

revoke all on public.don_gia_cong_nhat  from anon, authenticated;
revoke all on public.bang_thanh_toan_to from anon, authenticated;
revoke all on public.dong_thanh_toan_to from anon, authenticated;

grant select, insert, update, delete on public.don_gia_cong_nhat to authenticated;
grant select, update, delete on public.bang_thanh_toan_to to authenticated;
grant select on public.dong_thanh_toan_to to authenticated;
-- Admin sửa được số công và đơn giá của một dòng. `thanh_tien` là cột sinh
-- nên không cấp được, và cũng không cần: nó tự theo hai cột kia.
grant update (so_cong, don_gia, ghi_chu) on public.dong_thanh_toan_to to authenticated;
