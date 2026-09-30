-- =========================================================
-- Bảng thanh toán đọc theo DỮ LIỆU của dòng công, không theo `kieu_tinh`
--
-- Lỗ hổng tìm ra khi soát lại P5e trước khi giao, chưa ai gặp phải.
--
-- 12 nhân công thật đang mang `to_doi_thanh_vien.kieu_tinh = 'ngay'` vì họ
-- được khai từ trước 24/08/2026. Từ P5e, màn chấm công tick CA cho mọi người —
-- kể cả họ. Dòng công sinh ra khi ấy có `so_gio` và `so_gio_ot`, còn `so_cong`
-- là NULL.
--
-- Bản P5e của `sinh_bang_thanh_toan_to()` vẫn hỏi `kieu_tinh` để quyết định
-- đọc cột nào:
--
--     case when tv.kieu_tinh = 'gio' then so_gio else so_cong end
--
-- Với 12 người ấy, `kieu_tinh` là 'ngay' nên nó cộng `so_cong` — mà `so_cong`
-- của dòng chấm theo ca là NULL, tức 0. Kết quả: bảng thanh toán ra **0 đồng
-- tiền công**, chỉ còn tiền ngoài giờ, và KHÔNG BÁO GÌ. Người ta đi làm cả
-- ngày rồi nhận một bảng thanh toán thiếu tiền công, không có dòng lỗi nào để
-- lần ra.
--
-- CÁCH VÁ: hỏi chính DÒNG CÔNG, không hỏi một cột cấu hình ở bảng khác.
--
--   dòng có `so_cong`  → khoán ngày, nhân `don_gia_cong`
--   dòng không có      → chấm theo ca, nhân `don_gia_gio`
--
-- Dữ liệu tự nói nó là loại gì; không còn cách nào để cấu hình lệch với thực
-- tế. `kieu_tinh` từ bản này chỉ còn là ghi chú, không tham gia tính tiền.
--
-- Một người có CẢ HAI loại dòng trong cùng khoảng ngày thì TỪ CHỐI: bảng chỉ
-- cho mỗi người một dòng (`dong_mot_nguoi_mot_bang`), mà hai loại ấy là hai
-- đơn vị khác nhau, gộp lại là cộng công với giờ. Nói ra và bảo người dùng
-- tách khoảng ngày — đúng nguyên tắc "từ chối tính chứ không lặng lẽ trả 0".
-- =========================================================

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
  tron_kieu text;
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

  -- Gộp theo người, chỉ lấy phiên ĐÃ DUYỆT. Đơn giá lấy từ dòng thành viên
  -- GIAO với khoảng đang tính, mới nhất trước.
  --
  -- Tính luôn ba cột dẫn xuất trong CHÍNH câu tạo bảng, không `update` sau.
  -- Project bật `pg-safeupdate`, nên một lệnh UPDATE không WHERE bị từ chối
  -- thẳng — kể cả trên bảng tạm. Tính một lượt cũng đọc dễ hơn.
  create temporary table tam_cong on commit drop as
  with gop as (
  select
    c.employee_id,
    count(*) filter (where c.so_cong is not null) as dong_khoan_ngay,
    count(*) filter (where c.so_cong is null)     as dong_theo_ca,
    sum(coalesce(c.so_cong, 0))                   as tong_cong,
    sum(coalesce(c.so_gio, 0))                    as tong_gio,
    sum(coalesce(c.so_gio_ot, 0))                 as so_gio_ot,
    tv.don_gia_cong,
    tv.don_gia_gio,
    tv.don_gia_ot
  from public.cham_cong_cong_nhat c
  join public.phien_cham_cong_to p on p.id = c.phien_id
  join lateral (
    select t2.don_gia_cong, t2.don_gia_gio, t2.don_gia_ot
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
  group by c.employee_id, tv.don_gia_cong, tv.don_gia_gio, tv.don_gia_ot
  )
  select
    g.employee_id,
    g.dong_khoan_ngay,
    g.dong_theo_ca,
    g.so_gio_ot,
    g.don_gia_ot,
    -- Đọc theo DỮ LIỆU: có `so_cong` là khoán ngày, không có là chấm theo ca.
    case when g.dong_khoan_ngay > 0 then 'ngay' else 'gio' end          as kieu_tinh,
    case when g.dong_khoan_ngay > 0 then g.tong_cong else g.tong_gio end as so_luong,
    case when g.dong_khoan_ngay > 0 then g.don_gia_cong else g.don_gia_gio end as don_gia
  from gop g;

  -- Hai đơn vị trong một khoảng thì không gộp được vào một dòng bảng.
  select string_agg(e.full_name || ' (' || e.employee_code || ')', ', ' order by e.employee_code)
    into tron_kieu
  from tam_cong t
  join public.employees e on e.id = t.employee_id
  where t.dong_khoan_ngay > 0 and t.dong_theo_ca > 0;

  if tron_kieu is not null then
    raise exception
      'Trong khoảng này, % vừa có ngày công khoán cũ vừa có ca chấm mới. Bảng chỉ ghi được một dòng cho mỗi người, mà công và giờ là hai đơn vị. Tách thành hai khoảng ngày rồi sinh lại.',
      tron_kieu;
  end if;

  delete from tam_cong where so_luong <= 0 and so_gio_ot <= 0;

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

comment on function public.sinh_bang_thanh_toan_to(uuid, date, date) is
  'Sinh bảng thanh toán cho một tổ trong một khoảng ngày. Nhận diện khoán ngày hay chấm theo ca bằng CHÍNH DÒNG CÔNG, không bằng cột kieu_tinh ở bảng thành viên — cấu hình lệch với thực tế thì không còn đường nào để lệch.';

comment on column public.to_doi_thanh_vien.kieu_tinh is
  'GHI CHÚ, không tham gia tính tiền từ 24/08/2026. Bảng thanh toán nhận diện loại dòng công bằng chính dòng ấy: có so_cong là khoán ngày, không có là chấm theo ca.';
