-- =========================================================
-- P5c — Bảng thanh toán cộng BA loại tiền
--
-- P5b chỉ biết một phép nhân: số công × đơn giá. Từ 19/08/2026 một tổ có thể
-- có cả người khoán ngày lẫn người tính giờ, và ai cũng có thể làm ngoài giờ.
-- Nên bảng thanh toán phải cộng:
--
--     số công × đơn giá/công     (người khoán ngày)
--     số giờ  × đơn giá/giờ      (người tính giờ)
--   + giờ ngoài giờ × đơn giá ngoài giờ   (cả hai loại)
--
-- Các bảng liên quan còn RỖNG (đã kiểm trước khi viết) nên đổi cấu trúc không
-- phải chuyển đổi dữ liệu nào.
--
-- ĐỔI TÊN CỘT `so_cong` → `so_luong`: nó không còn luôn là số công nữa. Giữ
-- tên cũ là để lại một cái bẫy đọc — người sau nhìn `so_cong = 8` của một
-- người tính giờ sẽ tưởng anh ta làm 8 công.
-- =========================================================

-- ---------------------------------------------------------
-- 1. Dòng thanh toán mang đủ ba thành phần
-- ---------------------------------------------------------
alter table public.dong_thanh_toan_to drop column thanh_tien;

alter table public.dong_thanh_toan_to rename column so_cong to so_luong;

alter table public.dong_thanh_toan_to
  add column kieu_tinh  text not null default 'ngay'
    check (kieu_tinh in ('ngay', 'gio')),
  add column so_gio_ot  numeric(8, 2)  not null default 0 check (so_gio_ot >= 0),
  add column don_gia_ot numeric(15, 2) not null default 0 check (don_gia_ot >= 0);

-- Cột SINH, như bản trước: ba con số trên một dòng không bao giờ lệch nhau,
-- kể cả sau khi admin sửa tay một trong số chúng.
alter table public.dong_thanh_toan_to
  add column thanh_tien numeric(15, 2)
    generated always as (so_luong * don_gia + so_gio_ot * don_gia_ot) stored;

comment on column public.dong_thanh_toan_to.so_luong is
  'Số CÔNG nếu kieu_tinh = ngay, số GIỜ nếu kieu_tinh = gio. Đọc cùng kieu_tinh mới ra nghĩa.';

grant update (so_luong, don_gia, so_gio_ot, don_gia_ot, ghi_chu)
  on public.dong_thanh_toan_to to authenticated;

-- ---------------------------------------------------------
-- 2. Phần chưa duyệt đếm theo DÒNG, không theo đơn vị
--
--    Cộng số công của người khoán ngày với số giờ của người tính giờ ra một
--    con số là cộng hai đơn vị khác nhau. Đếm số dòng chấm công chưa duyệt thì
--    không phụ thuộc đơn vị, và vẫn trả lời đúng câu người dùng cần: "còn bao
--    nhiêu thứ chưa duyệt nằm ngoài bảng này".
-- ---------------------------------------------------------
alter table public.bang_thanh_toan_to rename column cong_cho_duyet to dong_cho_duyet;

comment on column public.bang_thanh_toan_to.dong_cho_duyet is
  'Số DÒNG chấm công nằm trong khoảng ngày nhưng thuộc phiên chưa duyệt, chụp lại lúc sinh.';

-- ---------------------------------------------------------
-- 3. Sinh bảng — bản có giờ và ngoài giờ
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
    select g.don_gia
    from public.don_gia_cong_nhat g
    join public.employees e on e.position_id = g.position_id
    where e.id = c.employee_id
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
$$;

comment on function public.sinh_bang_thanh_toan_to(uuid, date, date) is
  'Sinh bảng thanh toán cho một tổ trong một khoảng ngày. Chỉ cộng công của phiên ĐÃ DUYỆT; cộng cả tiền theo công, theo giờ và ngoài giờ; từ chối nếu thiếu bất kỳ đơn giá nào.';

revoke execute on function public.sinh_bang_thanh_toan_to(uuid, date, date) from anon, public;
grant  execute on function public.sinh_bang_thanh_toan_to(uuid, date, date) to authenticated;
