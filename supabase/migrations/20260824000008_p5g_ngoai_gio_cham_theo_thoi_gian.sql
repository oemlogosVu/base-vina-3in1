-- =========================================================
-- P5g — Ngoài giờ chấm theo THỜI GIAN, và bỏ trần giờ làm
--
-- Triệu Vũ, 24/08/2026: "ngoài giờ cũng phải chấm theo thời gian, do tính chất
-- công việc nên không giới hạn thời gian làm việc". Chốt thêm: ngoài giờ là
-- **một dòng riêng từ–đến**, và làm vắt qua nửa đêm thì **tách theo ngày**.
--
-- CÁI THIẾU CỦA P5f
--
-- P5f suy ngoài giờ ra từ ba ca: phần nằm ngoài khung giờ chuẩn là ngoài giờ.
-- Đúng cho việc đi sớm về muộn trong ca, nhưng không ghi được một buổi làm
-- thêm KHÔNG thuộc ca nào — mà đó chính là phần lớn việc làm thêm ở công
-- trường.
--
-- BA LUẬT, VIẾT RA MỘT LẦN
--
--   1. BA CA — phần trong khung giờ chuẩn (đã trừ giờ nghỉ) là giờ thường;
--      phần ngoài khung là ngoài giờ. Không đổi so với P5f.
--
--   2. DÒNG NGOÀI GIỜ — TOÀN BỘ tính ngoài giờ, không xét khung, không trừ
--      giờ nghỉ. Nó là khoảng người ta ở lại làm thêm; hỏi nó có nằm trong
--      giờ hành chính không là hỏi sai câu.
--
--   3. BỐN KHOẢNG KHÔNG ĐƯỢC CHỒNG NHAU. Chồng nhau là đếm hai lần cùng một
--      giờ làm, và lần này còn tệ hơn: phần chồng được trả cả giá thường lẫn
--      giá ngoài giờ.
--
-- QUA NỬA ĐÊM: TÁCH THEO NGÀY
--
-- 20:00 hôm nay đến 02:00 sáng mai ghi thành hai dòng: 20:00–24:00 của hôm
-- nay, và 00:00–02:00 của ngày mai. Quyết định của Triệu Vũ — đúng công của
-- từng ngày hơn, đổi lại tổ trưởng phải mở hai phiếu.
--
-- Nên phải ghi được GIỜ KẾT THÚC LÀ NỬA ĐÊM. Postgres `time` nhận '24:00:00',
-- nhưng ô `<input type="time">` của trình duyệt dừng ở 23:59. Nên quy ước:
-- **giờ kết thúc bằng 00:00 nghĩa là nửa đêm cuối ngày**. Không nhập nhằng —
-- một khoảng kết thúc lúc 00:00 thì chỉ có thể là nửa đêm; còn 00:00 ở đầu
-- khoảng vẫn là 0 giờ sáng như thường.
--
-- KHÔNG GIỚI HẠN THỜI GIAN LÀM VIỆC
--
-- Bỏ hai trần `so_gio <= 24` và `so_gio_ot <= 24` của P5c. Bốn khoảng không
-- chồng nhau nên tổng vốn không quá 24 giờ một ngày — hai trần ấy nay chỉ còn
-- là hai con số chờ chặn oan ai đó, không chặn được sai sót nào.
-- =========================================================

-- ---------------------------------------------------------
-- 1. Cặp giờ ngoài giờ, và quy ước nửa đêm
-- ---------------------------------------------------------
alter table public.cham_cong_cong_nhat
  add column ngoai_gio_tu  time,
  add column ngoai_gio_den time;

comment on column public.cham_cong_cong_nhat.ngoai_gio_tu is
  'Khoảng làm thêm của riêng người này, ngoài ba ca. TOÀN BỘ khoảng này tính là ngoài giờ, không xét khung giờ chuẩn. NULL = không làm thêm.';

comment on column public.cham_cong_cong_nhat.ngoai_gio_den is
  'Giờ kết thúc. Bằng 00:00 nghĩa là NỬA ĐÊM cuối ngày — ô giờ của trình duyệt không nhập được 24:00.';

alter table public.cham_cong_cong_nhat
  add constraint cccn_ngoai_gio_du_doi
    check ((ngoai_gio_tu is null) = (ngoai_gio_den is null));

-- ---------------------------------------------------------
-- 2. Giờ kết thúc bằng 00:00 = nửa đêm, cho CẢ BỐN khoảng
--
-- Ba ràng buộc `cccn_ca_*_xuoi` của P5f đòi `den > tu`, nên chúng chặn mất
-- một ca kết thúc lúc nửa đêm — đúng thứ quyết định "tách theo ngày" cần.
-- ---------------------------------------------------------
alter table public.cham_cong_cong_nhat
  drop constraint cccn_ca_sang_xuoi,
  drop constraint cccn_ca_chieu_xuoi,
  drop constraint cccn_ca_toi_xuoi;

alter table public.cham_cong_cong_nhat
  add constraint cccn_ca_sang_xuoi
    check (ca_sang_tu is null or ca_sang_den > ca_sang_tu or ca_sang_den = time '00:00'),
  add constraint cccn_ca_chieu_xuoi
    check (ca_chieu_tu is null or ca_chieu_den > ca_chieu_tu or ca_chieu_den = time '00:00'),
  add constraint cccn_ca_toi_xuoi
    check (ca_toi_tu is null or ca_toi_den > ca_toi_tu or ca_toi_den = time '00:00'),
  add constraint cccn_ngoai_gio_xuoi
    check (ngoai_gio_tu is null or ngoai_gio_den > ngoai_gio_tu or ngoai_gio_den = time '00:00');

-- ---------------------------------------------------------
-- 3. Bốn khoảng không chồng nhau
--
-- Hàm `immutable` chứ không viết thẳng sáu vế vào CHECK: sáu vế với quy ước
-- nửa đêm là một khối không ai đọc nổi, và cùng phép so ấy còn dùng ở mục 4.
-- ---------------------------------------------------------
create or replace function public.phut_trong_ngay(p_gio time, p_la_dau_cuoi boolean)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case
    when p_gio is null then null
    -- 00:00 ở ĐẦU khoảng là 0 giờ sáng; ở CUỐI khoảng là nửa đêm, tức 1440.
    when p_la_dau_cuoi and p_gio = time '00:00' then 1440
    else (extract(hour from p_gio) * 60 + extract(minute from p_gio))::integer
  end;
$$;

comment on function public.phut_trong_ngay(time, boolean) is
  'Giờ trong ngày quy ra phút. Tham số thứ hai = true khi đây là giờ KẾT THÚC, để 00:00 được đọc là nửa đêm (1440) thay vì 0.';

create or replace function public.bon_khoang_chong_nhau(
  s_tu time, s_den time, c_tu time, c_den time,
  t_tu time, t_den time, n_tu time, n_den time
)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select exists (
    select 1
    -- Đánh số tay chứ không `with ordinality`: cú pháp ấy chỉ dùng được với
    -- hàm trả bảng, không dùng được với VALUES.
    from (values (1, s_tu, s_den), (2, c_tu, c_den),
                 (3, t_tu, t_den), (4, n_tu, n_den)) a(i, tu, den)
    join (values (1, s_tu, s_den), (2, c_tu, c_den),
                 (3, t_tu, t_den), (4, n_tu, n_den)) b(i, tu, den) on b.i > a.i
    where a.tu is not null and b.tu is not null
      and public.phut_trong_ngay(a.tu, false) < public.phut_trong_ngay(b.den, true)
      and public.phut_trong_ngay(a.den, true) > public.phut_trong_ngay(b.tu, false)
  );
$$;

comment on function public.bon_khoang_chong_nhau(time, time, time, time, time, time, time, time) is
  'Có hai khoảng nào trong bốn khoảng (ba ca + ngoài giờ) chồng giờ nhau không. Chồng nhau là đếm hai lần cùng một giờ làm — và phần chồng còn được trả cả giá thường lẫn giá ngoài giờ.';

alter table public.cham_cong_cong_nhat
  drop constraint cccn_ca_khong_chong_nhau;

alter table public.cham_cong_cong_nhat
  add constraint cccn_ca_khong_chong_nhau check (
    not public.bon_khoang_chong_nhau(
      ca_sang_tu, ca_sang_den, ca_chieu_tu, ca_chieu_den,
      ca_toi_tu, ca_toi_den, ngoai_gio_tu, ngoai_gio_den
    )
  );

-- Dòng chấm theo ca hay theo giờ đều không kèm số công khoán ngày.
alter table public.cham_cong_cong_nhat
  drop constraint cccn_ca_khong_kem_so_cong;

alter table public.cham_cong_cong_nhat
  add constraint cccn_ca_khong_kem_so_cong check (
    (ca_sang_tu is null and ca_chieu_tu is null and ca_toi_tu is null
     and ngoai_gio_tu is null)
    or so_cong is null
  );

-- ---------------------------------------------------------
-- 4. Không giới hạn thời gian làm việc
-- ---------------------------------------------------------
alter table public.cham_cong_cong_nhat
  drop constraint cham_cong_cong_nhat_so_gio_check,
  drop constraint cham_cong_cong_nhat_so_gio_ot_check;

alter table public.cham_cong_cong_nhat
  add constraint cccn_so_gio_khong_am    check (so_gio is null or so_gio >= 0),
  add constraint cccn_so_gio_ot_khong_am check (so_gio_ot >= 0);

-- ---------------------------------------------------------
-- 5. Phép tính, có thêm dòng ngoài giờ
-- ---------------------------------------------------------
create or replace function public.gio_cong_nhat_tu_khoang(
  p_company_id  uuid,
  p_sang_tu     time, p_sang_den     time,
  p_chieu_tu    time, p_chieu_den    time,
  p_toi_tu      time, p_toi_den      time,
  p_ngoai_tu    time, p_ngoai_den    time,
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
  bd         integer;
  kt         integer;
  phut_tong  integer := 0;
  phut_nghi  integer := 0;
  phut_trong integer := 0;
  phut_ngoai integer := 0;
begin
  if (p_sang_tu  is null) <> (p_sang_den  is null)
     or (p_chieu_tu is null) <> (p_chieu_den is null)
     or (p_toi_tu   is null) <> (p_toi_den   is null)
     or (p_ngoai_tu is null) <> (p_ngoai_den is null) then
    raise exception
      'Khoảng nào có giờ vào thì phải có giờ ra. Một dòng công thiếu nửa cặp giờ là dòng không đọc được.'
      using errcode = 'check_violation';
  end if;

  if p_sang_tu is null and p_chieu_tu is null and p_toi_tu is null
     and p_ngoai_tu is null then
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

  -- BA CA: chia theo khung giờ chuẩn.
  for k in
    select * from (values (p_sang_tu, p_sang_den),
                          (p_chieu_tu, p_chieu_den),
                          (p_toi_tu, p_toi_den)) v(tu, den)
    where v.tu is not null
  loop
    bd := public.phut_trong_ngay(k.tu, false);
    kt := public.phut_trong_ngay(k.den, true);

    phut_tong  := phut_tong + (kt - bd);
    phut_trong := phut_trong
      + greatest(0, least(kt, public.phut_trong_ngay(cty.gio_ra, true))
                    - greatest(bd, public.phut_trong_ngay(cty.gio_vao, false)));

    if cty.nghi_tu is not null then
      phut_nghi := phut_nghi
        + greatest(0, least(kt, public.phut_trong_ngay(cty.nghi_den, true))
                      - greatest(bd, public.phut_trong_ngay(cty.nghi_tu, false)));
    end if;
  end loop;

  -- DÒNG NGOÀI GIỜ: toàn bộ là ngoài giờ, không xét khung, không trừ giờ nghỉ.
  -- Đây là khoảng người ta ở lại làm thêm; hỏi nó có nằm trong giờ hành chính
  -- không là hỏi sai câu.
  if p_ngoai_tu is not null then
    phut_ngoai := public.phut_trong_ngay(p_ngoai_den, true)
                - public.phut_trong_ngay(p_ngoai_tu, false);
  end if;

  so_gio    := round((phut_trong - phut_nghi)::numeric / 60, 2);
  so_gio_ot := round((phut_tong - phut_trong + phut_ngoai)::numeric / 60, 2);
end;
$$;

comment on function public.gio_cong_nhat_tu_khoang(uuid, time, time, time, time, time, time, time, time) is
  'Giờ thường và giờ ngoài giờ của ba ca cộng dòng ngoài giờ. Ba ca chia theo khung giờ chuẩn; dòng ngoài giờ tính trọn vào ngoài giờ. Nguồn DUY NHẤT của luật đó.';

drop function if exists public.gio_cong_nhat_tu_khoang(uuid, time, time, time, time, time, time);

revoke all on function
  public.gio_cong_nhat_tu_khoang(uuid, time, time, time, time, time, time, time, time)
  from public, anon;
grant execute on function
  public.gio_cong_nhat_tu_khoang(uuid, time, time, time, time, time, time, time, time)
  to authenticated;

-- ---------------------------------------------------------
-- 6. Trigger truyền thêm dòng ngoài giờ
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
    new.ca_toi_tu,   new.ca_toi_den,
    new.ngoai_gio_tu, new.ngoai_gio_den
  );

  new.so_gio    := kq.so_gio;
  new.so_gio_ot := kq.so_gio_ot;

  return new;
end;
$$;

-- ---------------------------------------------------------
-- 7. Quyền cấp cột cho hai cột mới
-- ---------------------------------------------------------
grant insert (ngoai_gio_tu, ngoai_gio_den) on public.cham_cong_cong_nhat to authenticated;
grant update (ngoai_gio_tu, ngoai_gio_den) on public.cham_cong_cong_nhat to authenticated;
