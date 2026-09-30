-- =========================================================
-- P5j — Người chấm công của tổ XOÁ được và SỬA TAY được bảng thanh toán
--
-- Triệu Vũ, 15/09/2026: "cấp quyền cho Quản lý tổ đội được phép xoá bảng
-- lương tổ đội đã tạo hoặc sửa bảng lương".
--
-- Được hỏi lại "sửa" theo cách nào — tính lại từ số công và đơn giá gốc, hay
-- sửa tay từng dòng — kèm hệ quả của từng cách, anh chọn SỬA TAY TỪNG DÒNG.
--
-- "Quản lý tổ đội" ở đây là NGƯỜI CHẤM CÔNG của tổ (`la_nguoi_cham_cong_to`)
-- — đúng người Triệu Vũ gọi bằng tên ấy ngày 29/08 (chị Hà: chấm ba tổ, đã
-- sinh 13 bảng). Cờ `quan_ly_to_doi` không cần nêu riêng: người lập tổ tự
-- thành người chấm của tổ đó (P5c).
--
-- ĐẢO MỘT QUYẾT ĐỊNH CÓ CHỦ. P5h (24/08) khoá dòng bảng đã sinh: "phần tính
-- lương của tổ đội đã tính xong không cho phép sửa nữa". Nay cùng người phụ
-- trách mở lại cho sửa tay.
--
-- ĐÁNH ĐỔI, nói rõ: từ bản này MỘT NGƯỜI vừa khai số công, vừa duyệt số công
-- (P5h), vừa sửa được số tiền trả mà số công và đơn giá gốc không đổi. Lớp
-- canh còn lại là SỔ SỬA TAY bất biến ở mục 3, và chứng từ PDF của bảng cũ
-- vẫn nằm nguyên.
-- =========================================================

-- ---------------------------------------------------------
-- 1. XOÁ: admin, hoặc người chấm của chính tổ ấy
--
--    Quyền cấp bảng DELETE đã có sẵn từ P5b; chỉ đổi policy. Dòng đi theo
--    bằng `on delete cascade`, như khi admin xoá từ trước tới nay.
-- ---------------------------------------------------------
drop policy "bang_delete_admin" on public.bang_thanh_toan_to;

create policy "bang_delete_admin_hoac_nguoi_cham"
  on public.bang_thanh_toan_to for delete
  to authenticated
  using (
    (select public.current_app_role()) = 'admin'
    or (select public.la_nguoi_cham_cong_to(to_doi_id))
  );

-- ---------------------------------------------------------
-- 2. SỬA TAY = THAY BẰNG MỘT BẢNG MỚI, không sửa tại chỗ
--
--    Vì sao không `update` thẳng dòng: `chung_tu` có ràng buộc một đối tượng
--    một bản (`chung_tu_mot_doi_tuong_mot_ban`). Sửa tại chỗ thì bảng mang số
--    mới mà PDF đã in mang số cũ, và không sinh lại PDF được nữa.
--
--    Thay bằng bảng mới thì mọi bất biến cũ vẫn đứng: số của một bảng không
--    bao giờ đổi sau khi đã có chứng từ; chứng từ cũ ở lại làm vết (nó sống
--    sót khi bảng gốc bị xoá — phép p6 số 15); bảng mới có chứng từ của nó.
--
--    Không mở quyền UPDATE nào trên `dong_thanh_toan_to` — lối duy nhất là
--    hàm này, có kiểm quyền ở dòng đầu và bắt ghi sổ. Các phép p5 số 33, 90,
--    109 và phép hành vi "không ai sửa thẳng được dòng" vẫn đúng nguyên văn.
-- ---------------------------------------------------------

-- ---------------------------------------------------------
-- 3. Sổ sửa tay — bất biến, chỉ có policy SELECT
--
--    Ba cột id bảng CỐ Ý không có khoá ngoại, cùng lý do với
--    `chung_tu.doi_tuong_id`: cascade thì xoá bảng là mất luôn dấu vết sửa,
--    restrict thì không xoá được bảng nữa. Sổ phải SỐNG SÓT khi bảng bị xoá.
--
--    `bang_goc_id` nối các lần sửa của cùng một bảng: mỗi lần sửa đẻ ra một
--    id mới, nên thiếu nó thì lịch sử của một bảng rời thành từng mảnh.
--
--    Tên người sửa và tên nhân công CHỤP LẠI lúc sửa: người đọc sổ thường là
--    người chấm, mà họ không đọc được `app_users` của người khác, cũng không
--    đọc được hồ sơ của người đã rời tổ.
-- ---------------------------------------------------------
create table public.sua_tay_bang_thanh_toan (
  id             uuid primary key default gen_random_uuid(),
  bang_goc_id    uuid not null,
  bang_cu_id     uuid not null,
  bang_moi_id    uuid not null,
  to_doi_id      uuid not null references public.to_doi (id),
  tu_ngay        date not null,
  den_ngay       date not null,
  employee_id    uuid not null references public.employees (id),
  ten_nhan_cong  text not null,
  truoc          jsonb not null,
  sau            jsonb not null,
  ly_do          text not null check (btrim(ly_do) <> ''),
  nguoi_sua      uuid not null references public.app_users (id),
  nguoi_sua_ten  text not null,
  sua_luc        timestamptz not null default now()
);

comment on table public.sua_tay_bang_thanh_toan is
  'Sổ sửa tay bảng thanh toán tổ đội (P5j, 15/09/2026). BẤT BIẾN: chỉ có policy SELECT, chỉ ghi qua sua_tay_dong_thanh_toan_to(). Sống sót khi bảng bị xoá — ba cột id bảng cố ý không có khoá ngoại.';
comment on column public.sua_tay_bang_thanh_toan.bang_goc_id is
  'Bảng sinh ra đầu tiên của chuỗi. Mỗi lần sửa tay đẻ ra một bảng mới; cột này nối chúng lại thành một lịch sử.';

create index idx_sua_tay_bang_goc on public.sua_tay_bang_thanh_toan (bang_goc_id, sua_luc desc);
create index idx_sua_tay_bang_moi on public.sua_tay_bang_thanh_toan (bang_moi_id);

alter table public.sua_tay_bang_thanh_toan enable row level security;
alter table public.sua_tay_bang_thanh_toan force row level security;

-- Ai đọc được bảng thì đọc được sổ của nó: kế toán và người chấm của tổ.
create policy "sua_tay_bang_select"
  on public.sua_tay_bang_thanh_toan for select
  to authenticated
  using (
    (select public.can_read_payroll())
    or (select public.la_nguoi_cham_cong_to(to_doi_id))
  );

-- Supabase cấp sẵn mọi quyền cho bảng mới, và `grant` không thu hồi được
-- quyền đã có — nên thu hết rồi mới cấp lại đúng một quyền đọc.
revoke all on public.sua_tay_bang_thanh_toan from anon, authenticated;
grant select on public.sua_tay_bang_thanh_toan to authenticated;

-- ---------------------------------------------------------
-- 4. Hàm sửa tay một dòng
-- ---------------------------------------------------------
create or replace function public.sua_tay_dong_thanh_toan_to(
  p_dong_id    uuid,
  p_so_luong   numeric,
  p_don_gia    numeric,
  p_so_gio_ot  numeric,
  p_don_gia_ot numeric,
  p_thuong     numeric,
  p_ly_do      text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  bang_cu_id uuid;
  bang       public.bang_thanh_toan_to;
  cu         public.dong_thanh_toan_to;
  cac_dong   public.dong_thanh_toan_to[];
  goc        uuid;
  moi        uuid;
  tien_moi   numeric;
  ten_nv     text;
  ten_sua    text;
begin
  select d.bang_id into bang_cu_id from public.dong_thanh_toan_to d where d.id = p_dong_id;
  if bang_cu_id is null then
    raise exception 'Không tìm thấy dòng này — bảng vừa được sửa hoặc xoá. Mở lại bảng rồi thử lại.';
  end if;

  -- Khoá bảng trước khi đọc: hai người cùng sửa một bảng thì người sau phải
  -- chờ, rồi thấy bảng đã được thay — không chép đè lên nhau.
  select * into bang from public.bang_thanh_toan_to b where b.id = bang_cu_id for update;
  if not found then
    raise exception 'Bảng này vừa được người khác sửa hoặc xoá. Mở lại bảng rồi thử lại.';
  end if;

  if not (public.current_app_role() = 'admin' or public.la_nguoi_cham_cong_to(bang.to_doi_id)) then
    raise exception 'Bạn không phụ trách tổ này, nên không sửa được bảng thanh toán của tổ.'
      using errcode = 'insufficient_privilege';
  end if;

  if coalesce(btrim(p_ly_do), '') = '' then
    raise exception 'Phải ghi lý do sửa. Đây là tiền trả cho người thật — sửa mà không có lý do thì vài tháng sau không ai trả lời được vì sao con số đổi.';
  end if;

  if p_so_luong is null or p_don_gia is null or p_so_gio_ot is null
     or p_don_gia_ot is null or p_thuong is null then
    raise exception 'Phải điền đủ năm ô: số lượng, đơn giá, giờ ngoài giờ, đơn giá ngoài giờ, thưởng. Không có thì ghi 0.';
  end if;

  if least(p_so_luong, p_don_gia, p_so_gio_ot, p_don_gia_ot, p_thuong) < 0 then
    raise exception 'Không nhập số âm.';
  end if;

  select * into cu from public.dong_thanh_toan_to d where d.id = p_dong_id;

  if (p_so_luong, p_don_gia, p_so_gio_ot, p_don_gia_ot, p_thuong)
     is not distinct from (cu.so_luong, cu.don_gia, cu.so_gio_ot, cu.don_gia_ot, cu.thuong) then
    raise exception 'Không có số nào thay đổi.';
  end if;

  goc := coalesce(
    (select s.bang_goc_id from public.sua_tay_bang_thanh_toan s where s.bang_moi_id = bang.id limit 1),
    bang.id
  );

  select e.full_name || ' (' || e.employee_code || ')' into ten_nv
  from public.employees e where e.id = cu.employee_id;
  select u.full_name into ten_sua from public.app_users u where u.id = (select auth.uid());

  -- Chép dòng ra biến TRƯỚC khi xoá bảng cũ: xoá bảng là cascade xoá dòng, và
  -- `bang_duy_nhat` không cho bảng mới cùng khoảng ngày ra đời khi bảng cũ còn.
  cac_dong := array(select d from public.dong_thanh_toan_to d where d.bang_id = bang.id);

  delete from public.bang_thanh_toan_to b where b.id = bang.id;

  insert into public.bang_thanh_toan_to
    (to_doi_id, tu_ngay, den_ngay, nguoi_tao, dong_cho_duyet, ghi_chu)
  values
    (bang.to_doi_id, bang.tu_ngay, bang.den_ngay, (select auth.uid()), bang.dong_cho_duyet, bang.ghi_chu)
  returning id into moi;

  insert into public.dong_thanh_toan_to
    (bang_id, employee_id, kieu_tinh, so_luong, don_gia, so_gio_ot, don_gia_ot, thuong, ghi_chu)
  select
    moi, u.employee_id, u.kieu_tinh,
    case when u.id = p_dong_id then p_so_luong   else u.so_luong   end,
    case when u.id = p_dong_id then p_don_gia    else u.don_gia    end,
    case when u.id = p_dong_id then p_so_gio_ot  else u.so_gio_ot  end,
    case when u.id = p_dong_id then p_don_gia_ot else u.don_gia_ot end,
    case when u.id = p_dong_id then p_thuong     else u.thuong     end,
    u.ghi_chu
  from unnest(cac_dong) u;

  -- Thành tiền đọc lại từ CỘT SINH, không tự nhân ở đây: một phép tính tiền
  -- chỉ có một chỗ.
  select d.thanh_tien into tien_moi
  from public.dong_thanh_toan_to d
  where d.bang_id = moi and d.employee_id = cu.employee_id;

  insert into public.sua_tay_bang_thanh_toan
    (bang_goc_id, bang_cu_id, bang_moi_id, to_doi_id, tu_ngay, den_ngay,
     employee_id, ten_nhan_cong, truoc, sau, ly_do, nguoi_sua, nguoi_sua_ten)
  values
    (goc, bang.id, moi, bang.to_doi_id, bang.tu_ngay, bang.den_ngay,
     cu.employee_id, coalesce(ten_nv, '(không rõ)'),
     jsonb_build_object(
       'so_luong', cu.so_luong, 'don_gia', cu.don_gia, 'so_gio_ot', cu.so_gio_ot,
       'don_gia_ot', cu.don_gia_ot, 'thuong', cu.thuong, 'thanh_tien', cu.thanh_tien),
     jsonb_build_object(
       'so_luong', p_so_luong, 'don_gia', p_don_gia, 'so_gio_ot', p_so_gio_ot,
       'don_gia_ot', p_don_gia_ot, 'thuong', p_thuong, 'thanh_tien', tien_moi),
     btrim(p_ly_do), (select auth.uid()), coalesce(ten_sua, '(không rõ)'));

  return moi;
end;
$$;

comment on function public.sua_tay_dong_thanh_toan_to(uuid, numeric, numeric, numeric, numeric, numeric, text) is
  'Sửa tay một dòng bảng thanh toán tổ đội (P5j). Bảng cũ được THAY bằng bảng mới cùng khoảng ngày, và một dòng ghi vào sổ sua_tay_bang_thanh_toan. Trả về id bảng mới. Admin hoặc người chấm của tổ; bắt buộc có lý do.';

revoke execute on function
  public.sua_tay_dong_thanh_toan_to(uuid, numeric, numeric, numeric, numeric, numeric, text)
  from anon, public;
grant execute on function
  public.sua_tay_dong_thanh_toan_to(uuid, numeric, numeric, numeric, numeric, numeric, text)
  to authenticated;

comment on table public.dong_thanh_toan_to is
  'Dòng thanh toán của một người trong một bảng. KHÔNG SỬA TẠI CHỖ: không ai có quyền UPDATE. Sửa tay (P5j, 15/09/2026) đi qua sua_tay_dong_thanh_toan_to(), hàm này THAY cả bảng bằng bảng mới và ghi sổ sua_tay_bang_thanh_toan.';

-- ---------------------------------------------------------
-- 5. Câu báo trùng khoảng ngày thôi bảo "nhờ quản trị xoá"
--
--    Sửa bằng pg_get_functiondef() + replace() trên bản ĐANG CHẠY, không chép
--    thân hàm từ migration cũ — và dừng hẳn nếu không thay được gì, vì
--    replace() không khớp thì trả nguyên chuỗi cũ, êm ru.
-- ---------------------------------------------------------
do $$
declare
  cu  text := pg_get_functiondef('public.sinh_bang_thanh_toan_to(uuid, date, date)'::regprocedure);
  moi text := replace(cu, 'hoặc nhờ quản trị xoá nó rồi sinh lại', 'hoặc xoá nó rồi sinh lại');
begin
  if moi = cu then
    raise exception 'Không tìm thấy câu "nhờ quản trị xoá" trong sinh_bang_thanh_toan_to — dừng, đừng áp nửa vời.';
  end if;
  execute moi;
end;
$$;
