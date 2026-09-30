-- =========================================================
-- P5d — Tổ trưởng lấy từ danh sách tổ, và bỏ đơn giá theo chức danh
--
-- Triệu Vũ, 22/08/2026, sau khi lập tổ thật đầu tiên và thêm 5 nhân công:
--
--   "bỏ bảng Đơn giá một công theo chức danh, nhập danh sách nhân sự của tổ
--    đội thì ấn định chức danh tổ trưởng luôn, tổ trưởng không nhất thiết
--    phải là người của công ty"
--
-- Migration này làm ba việc:
--   1. Tổ trưởng phải là NGƯỜI ĐANG TRONG TỔ — ràng buộc ở database.
--   2. Bỏ hai nguồn đơn giá, chỉ còn đơn giá riêng từng người.
--   3. Xoá bảng `don_gia_cong_nhat`.
--
-- KHÔNG đổi ở đây: người chấm công vẫn phải là nhân viên chính thức đóng bảo
-- hiểm. Đã hỏi lại Triệu Vũ hôm nay và anh chọn giữ nguyên quy tắc 19/08. Tổ
-- trưởng là chức danh ghi nhận trong tổ, KHÔNG kèm quyền chấm công — hai vai
-- trò khác nhau, và trộn chúng lại là để người hưởng tiền tự khai số công của
-- chính mình.
-- =========================================================

-- ---------------------------------------------------------
-- 1. Tổ trưởng phải là người đang trong tổ
--
-- Trước bản này `to_truong_id` chỉ có khoá ngoại tới `employees`, nên nó nhận
-- BẤT KỲ hồ sơ nào trong công ty — kể cả người chưa bao giờ ra công trường
-- đó. Ô chọn trên màn hình cũng liệt kê toàn bộ nhân sự, nên chọn nhầm là
-- chuyện sẽ xảy ra chứ không phải có thể xảy ra.
--
-- Điều kiện là "đang trong tổ", tức `den_ngay is null`. CỐ Ý không đòi nhân
-- viên chính thức: tổ trưởng công nhật là người trong nhóm thợ, không phải
-- người của công ty — đó chính là điểm Triệu Vũ nêu.
-- ---------------------------------------------------------
create or replace function public.chan_to_truong_ngoai_to()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  ten text;
begin
  if new.to_truong_id is null then
    return new;
  end if;

  if not exists (
    select 1 from public.to_doi_thanh_vien tv
    where tv.to_doi_id = new.id
      and tv.employee_id = new.to_truong_id
      and tv.den_ngay is null
  ) then
    select e.full_name into ten from public.employees e where e.id = new.to_truong_id;
    raise exception
      'Tổ trưởng phải là người đang trong tổ. % chưa có tên trong danh sách nhân công của tổ này — thêm vào tổ trước, rồi đặt làm tổ trưởng.',
      coalesce(ten, 'Người này')
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

comment on function public.chan_to_truong_ngoai_to() is
  'Tổ trưởng phải đang là thành viên của chính tổ đó. Không đòi nhân viên chính thức — tổ trưởng công nhật là người trong nhóm thợ.';

create trigger trg_to_doi_chan_to_truong_ngoai_to
  before insert or update of to_truong_id on public.to_doi
  for each row execute function public.chan_to_truong_ngoai_to();

-- ---------------------------------------------------------
-- 2. Cho người ra khỏi tổ thì phải gỡ chức tổ trưởng trước
--
-- Không có bước này thì kết thúc thành viên là để lại một tổ có tổ trưởng
-- không còn trong tổ — đúng trạng thái mà mục 1 vừa cấm, chỉ là đi vào bằng
-- cửa sau.
--
-- Chặn thay vì tự xoá `to_truong_id`: tổ mất tổ trưởng là việc người quản lý
-- phải biết, không phải việc hệ thống lặng lẽ làm hộ.
-- ---------------------------------------------------------
create or replace function public.chan_cho_to_truong_roi_to()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.den_ngay is not null and old.den_ngay is null
     and exists (
       select 1 from public.to_doi t
       where t.id = new.to_doi_id and t.to_truong_id = new.employee_id
     ) then
    raise exception
      'Người này đang là tổ trưởng. Đặt người khác làm tổ trưởng trước, rồi mới cho ra khỏi tổ.'
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

comment on function public.chan_cho_to_truong_roi_to() is
  'Không cho kết thúc thành viên đang giữ chức tổ trưởng — nếu không, tổ sẽ có tổ trưởng không còn trong tổ.';

create trigger trg_thanh_vien_chan_to_truong_roi_to
  before update of den_ngay on public.to_doi_thanh_vien
  for each row execute function public.chan_cho_to_truong_roi_to();

-- ---------------------------------------------------------
-- 3. Một nguồn đơn giá duy nhất: mức riêng của từng người
--
-- P5c dựng hai tầng — đơn giá theo chức danh làm mặc định, đơn giá từng người
-- ghi đè. Chạy thật rồi thì tầng mặc định thừa: biểu mẫu "thêm nhân công" đã
-- bắt nhập mức của từng người ngay lúc thêm, nên tầng chức danh chưa bao giờ
-- có dòng nào (`don_gia_cong_nhat` rỗng tại thời điểm gỡ).
--
-- Hai nguồn cho một con số tiền là thứ dự án này đã gỡ hai lần rồi: hai cột
-- lương trên hợp đồng (P3b) và cột `employees.position_id` (P1c). Giữ tầng
-- thứ hai chỉ vì "biết đâu cần" là để lại đúng loại nợ đó.
--
-- Hệ quả cần nói thẳng: từ nay THIẾU đơn giá riêng là bảng thanh toán TỪ CHỐI
-- sinh, và câu báo lỗi chỉ còn một đường sửa. Đó là ý muốn — chứ không phải
-- lặng lẽ tính 0 đồng (AGENTS.md mục 5).
-- ---------------------------------------------------------
create or replace function public.sinh_bang_thanh_toan_to(
  p_to_doi_id uuid,
  p_tu_ngay date,
  p_den_ngay date
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
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
    tv.don_gia                         as don_gia,
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
  where p.to_doi_id = p_to_doi_id
    and p.da_duyet
    and c.work_date between p_tu_ngay and p_den_ngay
  group by c.employee_id, tv.kieu_tinh, tv.don_gia, tv.don_gia_ot
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
      'Chưa có đơn giá cho: %. Sửa dòng của họ trong danh sách nhân công của tổ và nhập đơn giá.',
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
$function$;

-- ---------------------------------------------------------
-- 4. Xoá bảng đơn giá theo chức danh
--
-- Xoá cứng, không xoá mềm: bảng đang RỖNG, và nó là bảng danh mục cấu hình
-- chứ không phải chứng từ. Giữ lại một bảng không màn hình nào ghi được nữa
-- là để lại một cấu hình ẩn — người sau đọc schema sẽ tưởng nó còn dùng.
--
-- Nếu sau này cần lại đơn giá mặc định theo chức danh thì dựng lại bằng một
-- migration mới, khi đó nó sẽ có đúng hình dạng của nhu cầu lúc đó.
-- ---------------------------------------------------------
drop table if exists public.don_gia_cong_nhat;
