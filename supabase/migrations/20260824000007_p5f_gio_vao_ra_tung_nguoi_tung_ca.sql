-- =========================================================
-- P5f — Mỗi người, mỗi ca, một cặp giờ vào–giờ ra của riêng mình
--
-- Triệu Vũ, 24/08/2026: "chỗ chấm công các ca cần phải cho chọn được giờ vào
-- giờ ra của từng ca", và chốt: đặt **riêng từng người**, còn ba ca khai ở
-- Quản trị → Công ty chỉ làm **giờ mặc định, sửa được tự do**.
--
-- CÁI THIẾU CỦA P5e
--
-- P5e cho tick ca, và giờ của ca lấy nguyên từ khai báo của công ty. Nghĩa là
-- cả tổ ai làm ca sáng cũng được ghi đúng 07:00–11:00, kể cả người đến lúc
-- 08:30. Ba ô tick không nói được thực tế ngoài công trường.
--
-- MÔ HÌNH MỚI
--
-- Ba ô tick boolean biến mất. Thay bằng ba CẶP GIỜ trên chính dòng công:
--
--     ca_sang_tu / ca_sang_den, ca_chieu_tu / ca_chieu_den, ca_toi_tu / ca_toi_den
--
-- Một ca được coi là CÓ LÀM khi cặp giờ của nó khác NULL. Không còn cột
-- boolean song song với cặp giờ — hai thứ nói cùng một điều thì sẽ có ngày
-- nói khác nhau.
--
-- Ba ô tick cũ chưa có dòng dữ liệu thật nào (12 dòng đang có đều là khoán
-- ngày, `so_cong` khác NULL, tick đều false), nên bỏ chúng không mất gì. Đã
-- kiểm trước khi viết.
--
-- SỐ GIỜ VẪN DO DATABASE TÍNH
--
-- Không đổi nguyên tắc của P5e: tổ trưởng nói GIỜ LÀM, database nói GIỜ NÀO
-- TÍNH NGOÀI GIỜ. `so_gio` và `so_gio_ot` vẫn ngoài tầm ghi của client, vẫn do
-- trigger đặt lại mọi lệnh ghi — chỉ khác là nay nó tính từ giờ THẬT của từng
-- người thay vì giờ khai của công ty.
-- =========================================================

-- ---------------------------------------------------------
-- 1. Ba cặp giờ thay cho ba ô tick
-- ---------------------------------------------------------
alter table public.cham_cong_cong_nhat
  drop constraint cccn_ca_khong_kem_so_cong;

alter table public.cham_cong_cong_nhat
  drop column ca_sang,
  drop column ca_chieu,
  drop column ca_toi;

alter table public.cham_cong_cong_nhat
  add column ca_sang_tu   time,
  add column ca_sang_den  time,
  add column ca_chieu_tu  time,
  add column ca_chieu_den time,
  add column ca_toi_tu    time,
  add column ca_toi_den   time;

comment on column public.cham_cong_cong_nhat.ca_sang_tu is
  'Giờ vào ca sáng CỦA RIÊNG NGƯỜI NÀY. NULL = không làm ca ấy. Mặc định lấy giờ ca của công ty, nhưng tổ trưởng sửa được cho đúng thực tế.';

-- Nửa cặp là một dòng công không đọc được: biết vào mà không biết ra.
alter table public.cham_cong_cong_nhat
  add constraint cccn_ca_sang_du_doi
    check ((ca_sang_tu is null) = (ca_sang_den is null)),
  add constraint cccn_ca_chieu_du_doi
    check ((ca_chieu_tu is null) = (ca_chieu_den is null)),
  add constraint cccn_ca_toi_du_doi
    check ((ca_toi_tu is null) = (ca_toi_den is null));

-- Giờ ra phải sau giờ vào. Khoảng vắt qua nửa đêm chưa nhận — cùng giới hạn
-- với khung giờ chuẩn của công ty, và nói ra ở màn hình chứ không im lặng.
alter table public.cham_cong_cong_nhat
  add constraint cccn_ca_sang_xuoi  check (ca_sang_tu  is null or ca_sang_den  > ca_sang_tu),
  add constraint cccn_ca_chieu_xuoi check (ca_chieu_tu is null or ca_chieu_den > ca_chieu_tu),
  add constraint cccn_ca_toi_xuoi   check (ca_toi_tu   is null or ca_toi_den   > ca_toi_tu);

-- Hai ca của CÙNG MỘT NGƯỜI trong cùng một ngày không được chồng giờ — chồng
-- nhau là đếm hai lần cùng một giờ làm, y như hai ca của công ty chồng nhau.
--
-- Viết thẳng ba vế thay vì gọi hàm: CHECK phải là biểu thức bất biến, và ba vế
-- thì đọc ra là thấy đủ tổ hợp.
alter table public.cham_cong_cong_nhat
  add constraint cccn_ca_khong_chong_nhau check (
        not (ca_sang_tu is not null and ca_chieu_tu is not null
             and ca_sang_tu < ca_chieu_den and ca_sang_den > ca_chieu_tu)
    and not (ca_sang_tu is not null and ca_toi_tu is not null
             and ca_sang_tu < ca_toi_den and ca_sang_den > ca_toi_tu)
    and not (ca_chieu_tu is not null and ca_toi_tu is not null
             and ca_chieu_tu < ca_toi_den and ca_chieu_den > ca_toi_tu)
  );

-- Khoán ngày và chấm theo ca là hai đơn vị; một dòng mang cả hai là bảng thanh
-- toán cộng cả hai và trả gấp đôi.
alter table public.cham_cong_cong_nhat
  add constraint cccn_ca_khong_kem_so_cong check (
    (ca_sang_tu is null and ca_chieu_tu is null and ca_toi_tu is null)
    or so_cong is null
  );

-- ---------------------------------------------------------
-- 2. Giờ thường / ngoài giờ tính từ GIỜ THẬT, không từ giờ khai của công ty
--
-- Luật không đổi so với P5e — chỉ đổi nguồn của các khoảng giờ:
--
--   giờ nghỉ   = phần khoảng giao với giờ nghỉ trưa → không trả tiền
--   giờ thường = phần khoảng nằm trong khung giờ chuẩn, đã trừ giờ nghỉ
--   ngoài giờ  = phần còn lại
--
-- TỪ CHỐI khi công ty chưa khai khung giờ chuẩn. Trả 0 ở đây là ghi nhận người
-- ta đi làm cả ngày mà không có giờ nào.
-- ---------------------------------------------------------
create or replace function public.gio_cong_nhat_tu_khoang(
  p_company_id  uuid,
  p_sang_tu     time, p_sang_den   time,
  p_chieu_tu    time, p_chieu_den  time,
  p_toi_tu      time, p_toi_den    time,
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
  k          record;
  phut_tong  integer := 0;
  phut_nghi  integer := 0;
  phut_trong integer := 0;
begin
  -- Nửa cặp giờ: ràng buộc `cccn_ca_*_du_doi` cũng chặn, nhưng hàm này chạy
  -- TRƯỚC nó (trigger BEFORE), và một nửa cặp làm phép trừ ra NULL — dẫn tới
  -- `so_gio_ot` NULL và một lỗi `23502 not_null_violation` chẳng nói lên gì.
  -- Nói thành câu ở đây thì người dùng biết mình thiếu ô nào.
  if (p_sang_tu  is null) <> (p_sang_den  is null)
     or (p_chieu_tu is null) <> (p_chieu_den is null)
     or (p_toi_tu   is null) <> (p_toi_den   is null) then
    raise exception
      'Ca nào có giờ vào thì phải có giờ ra. Một dòng công thiếu nửa cặp giờ là dòng không đọc được.'
      using errcode = 'check_violation';
  end if;

  if p_sang_tu is null and p_chieu_tu is null and p_toi_tu is null then
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

  for k in
    select * from (values (p_sang_tu, p_sang_den),
                          (p_chieu_tu, p_chieu_den),
                          (p_toi_tu, p_toi_den)) v(tu, den)
    where v.tu is not null
  loop
    phut_tong  := phut_tong  + ceil(extract(epoch from (k.den - k.tu)) / 60)::integer;
    phut_trong := phut_trong + public.phut_giao_gio(k.tu, k.den, cty.gio_vao, cty.gio_ra);

    if cty.nghi_tu is not null then
      phut_nghi := phut_nghi + public.phut_giao_gio(k.tu, k.den, cty.nghi_tu, cty.nghi_den);
    end if;
  end loop;

  -- Giờ nghỉ nằm trong khung (ràng buộc `cty_nghi_trong_khung`), nên nó đang
  -- được đếm trong `phut_trong` và phải trừ đúng một lần ở đó.
  so_gio    := round((phut_trong - phut_nghi)::numeric / 60, 2);
  so_gio_ot := round((phut_tong - phut_trong)::numeric / 60, 2);
end;
$$;

comment on function public.gio_cong_nhat_tu_khoang(uuid, time, time, time, time, time, time) is
  'Giờ thường và giờ ngoài giờ của ba khoảng giờ THẬT trong ngày, theo khung giờ chuẩn của công ty. Nguồn DUY NHẤT của luật đó.';

revoke all on function
  public.gio_cong_nhat_tu_khoang(uuid, time, time, time, time, time, time) from public, anon;
grant execute on function
  public.gio_cong_nhat_tu_khoang(uuid, time, time, time, time, time, time) to authenticated;

-- ---------------------------------------------------------
-- 3. Trigger đọc từ ba cặp giờ
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
  from public.gio_cong_nhat_tu_khoang(
    cty,
    new.ca_sang_tu,  new.ca_sang_den,
    new.ca_chieu_tu, new.ca_chieu_den,
    new.ca_toi_tu,   new.ca_toi_den
  );

  new.so_gio    := kq.so_gio;
  new.so_gio_ot := kq.so_gio_ot;

  return new;
end;
$$;

comment on function public.tinh_gio_tu_ca() is
  'Đặt lại so_gio và so_gio_ot từ ba cặp giờ vào–ra của chính người này, mọi lệnh ghi. Client gửi số giờ nào cũng bị ghi đè — ngoài giờ là tiền, không để người chấm tự quyết.';

-- ---------------------------------------------------------
-- 4. Quyền cấp cột: client ghi GIỜ, không ghi SỐ GIỜ
-- ---------------------------------------------------------
grant insert (phien_id, work_date, employee_id, ghi_chu,
              ca_sang_tu, ca_sang_den, ca_chieu_tu, ca_chieu_den, ca_toi_tu, ca_toi_den)
  on public.cham_cong_cong_nhat to authenticated;

grant update (ghi_chu,
              ca_sang_tu, ca_sang_den, ca_chieu_tu, ca_chieu_den, ca_toi_tu, ca_toi_den)
  on public.cham_cong_cong_nhat to authenticated;
