-- =====================================================================
-- DANH MỤC DÙNG CHUNG — chuẩn hoá (docs/KE_HOACH_DU_LIEU_DUNG_CHUNG.md, duyệt 30/09/2026)
--
-- Chạy SAU: 71 migration Nhân sự · 000001 cấu trúc Tài chính · 000002 quyền · (dữ liệu 2 phân hệ đã nạp).
-- Làm được trên DB rỗng lẫn DB có dữ liệu (dữ liệu được chuyển sang bảng chung ngay trong file này).
--
-- CÁCH LÀM: "bảng chung + view tương thích"
--   * Mỗi thực thể dùng chung lưu MỘT lần. Bảng cũ được ĐỔI TÊN thành bảng chung (Postgres tự giữ mọi khóa ngoại,
--     policy, trigger, quyền) hoặc gộp vào bảng chung.
--   * Tên bảng cũ trở thành VIEW cùng tên, cùng cột, cùng thứ tự cột (security_invoker: RLS của bảng chung áp
--     cho người đang đăng nhập) → 59 hàm + code 2 app đọc danh mục chạy NGUYÊN, không viết lại logic tiền/lương.
--   * Ghi qua view: view 1 bảng tự cập nhật được; view ghép 2 bảng (employees, nhan_vien, companies) dùng trigger
--     INSTEAD OF.
--
--   companies (NS) + cong_ty (TC)      → cong_ty      (giữ id Tài chính)     view: companies
--   departments (NS)                   → phong_ban                           view: departments
--   du_an (TC)                         → cong_trinh                          view: du_an
--   nha_cung_cap + khach_hang (TC)     → doi_tac      (+ NCC Kho ở 000005)   view: nha_cung_cap, khach_hang
--   employees (NS) → nguoi (danh tính) + ho_so_nhan_su (vai trò Nhân sự)    view: employees
--   nhan_vien (TC) → nguoi (danh tính) + nhan_vien_tc  (vai trò Tài chính)   view: nhan_vien
--   MỚI: quyen_phan_he (ai được vào phân hệ nào)
--
-- Quyết định chủ dự án 30/09 áp ở đây:
--   * Thông tin nhạy cảm GIỮ 2 bảng riêng (nhan_vien_nhay_cam, employee_sensitive); STK khác nhau → lấy Tài chính.
--   * Công ty lưu THEO TỪNG PHÂN HỆ (nhan_vien_tc.cong_ty_id, ho_so_nhan_su.cong_ty_id) — nguoi không có công ty.
--   * NCC001 An Phát, NCC002 Minh Long (TC): ngừng dùng. "XD Anh Nam" (NCC.09): nhà thầu phụ.
--   * Ghép trùng theo file đối chiếu chủ dự án đã xác nhận (.local/doi-chieu/DOI_CHIEU_DANH_MUC_20260926_1419.xlsx,
--     sửa 30/09 11:11) — ghi dưới dạng MÃ (không dữ liệu cá nhân) ở mục 0.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. Bảng ghép mã đã xác nhận (schema gop — chỉ dùng khi chuyển đổi, không cấp cho app)
-- ---------------------------------------------------------------------
create schema if not exists gop;
revoke all on schema gop from public, anon, authenticated;

create table if not exists gop.cong_ty (ma_tc text primary key, ma_ns text not null unique);
insert into gop.cong_ty values ('BV', 'BaseVN'), ('TH', 'TH') on conflict do nothing;

-- Người có ở cả Tài chính và Nhân sự (mã NV TC → mã NV NS). NV0011 chỉ TC+Kho.
create table if not exists gop.nguoi (ma_nv_tc text primary key, ma_nv_ns text not null unique);
insert into gop.nguoi values
  ('NV_CT', 'BVT001'), ('NV0013', 'BVT004'), ('HCNS_Q', 'BVT019'), ('NV0010', 'THT002'),
  ('NV0012', 'BVT009'), ('NV006', 'BVT002'), ('QT-VU', 'BVT020')
on conflict do nothing;

-- Nhân viên Tài chính CHƯA có hồ sơ Nhân sự nhưng chủ dự án quyết đưa vào Nhân sự (30/09): tạo hồ sơ NS tối
-- thiểu (mã NV tạm = mã TC, không theo dõi chấm công); HCNS bổ sung thông tin sau.
create table if not exists gop.nguoi_them_ns (ma_nv_tc text primary key);
insert into gop.nguoi_them_ns values ('NV0015'), ('NV0020') on conflict do nothing;

-- Nhà cung cấp Tài chính ↔ mã kế toán (danh sách Kho).
create table if not exists gop.doi_tac (ma_tc text primary key, ma_ke_toan text not null unique);
insert into gop.doi_tac values
  ('NCC 001', 'NCC00001'), ('NCC.022', 'NCC000124'), ('NCC.023', 'NCC00075'), ('NCC.025', 'NCC00038'), ('NCC007', 'NCC005')
on conflict do nothing;

-- Công trường (phòng ban NS) → dự án Tài chính.
create table if not exists gop.phong_ban_cong_trinh (ma_phong_ban text primary key, ma_du_an text not null);
insert into gop.phong_ban_cong_trinh values
  ('P04', 'LSDA01'), ('P05', 'LSDA02'), ('P11', 'LSDA02'), ('P06', 'LSDA03')
on conflict do nothing;

-- Nhật ký những gì migration này đã đổi trên DỮ LIỆU (để đối chiếu).
create table if not exists gop.nhat_ky (
  id bigint generated always as identity primary key,
  luc timestamptz not null default now(),
  viec text not null,
  chi_tiet jsonb
);

-- ---------------------------------------------------------------------
-- Hàm tiện ích (chỉ trong lúc chuyển đổi)
-- ---------------------------------------------------------------------
-- Chép quyền bảng (và quyền theo cột trùng tên) của anon/authenticated từ đối tượng nguồn sang đích.
create or replace function gop.chep_quyen(p_nguon regclass, p_dich regclass) returns void
language plpgsql as $$
declare r record;
begin
  for r in
    select a.grantee::regrole::text as ai, a.privilege_type as quyen
    from pg_class c, aclexplode(c.relacl) a
    where c.oid = p_nguon and a.grantee in ('anon'::regrole, 'authenticated'::regrole)
  loop
    execute format('grant %s on %s to %I', r.quyen, p_dich, r.ai);
  end loop;
  for r in
    select at.attname as cot, a.grantee::regrole::text as ai, a.privilege_type as quyen
    from pg_attribute at, aclexplode(at.attacl) a
    where at.attrelid = p_nguon and at.attnum > 0 and at.attacl is not null
      and a.grantee in ('anon'::regrole, 'authenticated'::regrole)
      and exists (select 1 from pg_attribute d where d.attrelid = p_dich and d.attname = at.attname)
  loop
    execute format('grant %s (%I) on %s to %I', r.quyen, r.cot, p_dich, r.ai);
  end loop;
end $$;

-- Trỏ mọi khóa ngoại đang trỏ vào p_cu sang p_moi (giữ nguyên hành vi ON DELETE/UPDATE).
create or replace function gop.tro_khoa_ngoai(p_cu regclass, p_moi regclass) returns void
language plpgsql as $$
declare r record;
begin
  for r in
    select c.conname, c.conrelid::regclass as bang, pg_get_constraintdef(c.oid) as dn
    from pg_constraint c where c.contype = 'f' and c.confrelid = p_cu
  loop
    execute format('alter table %s drop constraint %I', r.bang, r.conname);
    execute format('alter table %s add constraint %I %s', r.bang, r.conname,
      regexp_replace(r.dn, 'REFERENCES [^(]+\(', 'REFERENCES ' || p_moi::text || '('));
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- Dữ liệu được chuyển trong migration → tắt trigger người dùng + kiểm khóa ngoại trong lúc đổi mã
-- (trigger tự sinh mã / chặn sửa kỳ lương đã khóa không được chạy khi chuyển dữ liệu nguyên trạng).
-- Khóa ngoại được tạo lại ở cuối từng mục → Postgres kiểm lại toàn bộ khi tạo.
-- ---------------------------------------------------------------------
set local session_replication_role = replica;

-- =====================================================================
-- 1. CÔNG TY: companies (NS) gộp vào cong_ty (TC) — giữ id Tài chính
-- =====================================================================
alter table public.cong_ty
  add column ma_nhan_su text unique,
  add column ten_phap_ly text,
  add column so_cong_chuan numeric check (so_cong_chuan > 0 and so_cong_chuan <= 31),
  add column han_xac_nhan_phieu_ngay integer check (han_xac_nhan_phieu_ngay > 0 and han_xac_nhan_phieu_ngay <= 90),
  add column gio_vao time,
  add column gio_ra time,
  add column nghi_tu time,
  add column nghi_den time,
  add constraint cty_khung_gio_du_doi check ((gio_vao is null) = (gio_ra is null)),
  add constraint cty_khung_gio_hop_le check (gio_vao is null or gio_ra > gio_vao),
  add constraint cty_nghi_du_doi check ((nghi_tu is null) = (nghi_den is null)),
  add constraint cty_nghi_trong_khung check (nghi_tu is null or (gio_vao is not null and nghi_den > nghi_tu and nghi_tu >= gio_vao and nghi_den <= gio_ra));

comment on column public.cong_ty.ma is 'Mã Tài chính (BV/TH) — in trên số đề nghị, KHÔNG đổi.';
comment on column public.cong_ty.ma_nhan_su is 'Mã công ty bên Nhân sự (BaseVN/TH) — view companies trả về cột này làm "code".';

-- Công ty NS đã ghép → bổ sung vào dòng Tài chính (tên pháp lý + MST lấy Nhân sự).
update public.cong_ty t set
  ma_nhan_su = c.code, ten_phap_ly = c.name,
  ma_so_thue = coalesce(nullif(t.ma_so_thue, ''), c.tax_code),
  dia_chi = coalesce(nullif(t.dia_chi, ''), c.address),
  so_cong_chuan = c.standard_days, han_xac_nhan_phieu_ngay = c.han_xac_nhan_phieu_ngay,
  gio_vao = c.gio_vao, gio_ra = c.gio_ra, nghi_tu = c.nghi_tu, nghi_den = c.nghi_den
from gop.cong_ty g join public.companies c on c.code = g.ma_ns
where t.ma = g.ma_tc;

-- Công ty chỉ có ở NS → thêm vào cong_ty, giữ id.
insert into public.cong_ty (id, ma, ten, ten_phap_ly, ma_nhan_su, ma_so_thue, dia_chi, dang_dung, created_at, updated_at,
                            so_cong_chuan, han_xac_nhan_phieu_ngay, gio_vao, gio_ra, nghi_tu, nghi_den)
select c.id, upper(regexp_replace(c.code, '[^A-Za-z0-9]', '', 'g')), c.name, c.name, c.code, c.tax_code, c.address,
       c.is_active, c.created_at, c.updated_at, c.standard_days, c.han_xac_nhan_phieu_ngay, c.gio_vao, c.gio_ra, c.nghi_tu, c.nghi_den
from public.companies c
where not exists (select 1 from public.cong_ty t where t.ma_nhan_su = c.code);

-- Đổi company_id của các bảng NS sang id cong_ty, rồi trỏ khóa ngoại sang cong_ty.
create temp table tam_cty on commit drop as
  select c.id as id_ns, t.id as id_tc from public.companies c join public.cong_ty t on t.ma_nhan_su = c.code;
do $$
declare r record;
begin
  for r in
    select c.conrelid::regclass as bang, a.attname as cot
    from pg_constraint c join pg_attribute a on a.attrelid = c.conrelid and a.attnum = c.conkey[1]
    where c.contype = 'f' and c.confrelid = 'public.companies'::regclass
  loop
    execute format('update %s x set %I = m.id_tc from tam_cty m where x.%I = m.id_ns and m.id_ns <> m.id_tc', r.bang, r.cot, r.cot);
  end loop;
end $$;
select gop.tro_khoa_ngoai('public.companies', 'public.cong_ty');
insert into gop.nhat_ky (viec, chi_tiet)
select 'cong_ty: doi company_id NS sang id TC', jsonb_agg(jsonb_build_object('ns', id_ns, 'tc', id_tc)) from tam_cty where id_ns <> id_tc;

-- Quyền của NS trên companies → áp thêm lên cong_ty (policy PERMISSIVE: cộng với policy Tài chính).
create policy cong_ty_ns_doc on public.cong_ty for select to authenticated
  using ((select public.current_app_role()) is not null);
create policy cong_ty_ns_them on public.cong_ty for insert to authenticated
  with check ((select public.current_app_role()) = 'admin'::public.user_role);
create policy cong_ty_ns_sua on public.cong_ty for update to authenticated
  using ((select public.current_app_role()) = 'admin'::public.user_role)
  with check ((select public.current_app_role()) = 'admin'::public.user_role);
create policy cong_ty_ns_xoa on public.cong_ty for delete to authenticated
  using ((select public.current_app_role()) = 'admin'::public.user_role);

create temp table tam_quyen_companies on commit drop as select relacl from pg_class where oid = 'public.companies'::regclass;
drop table public.companies;

create view public.companies with (security_invoker = true) as
select id, coalesce(ma_nhan_su, ma) as code, coalesce(ten_phap_ly, ten) as name, ma_so_thue as tax_code,
       dia_chi as address, dang_dung as is_active, created_at, updated_at, so_cong_chuan as standard_days,
       han_xac_nhan_phieu_ngay, gio_vao, gio_ra, nghi_tu, nghi_den
from public.cong_ty;
comment on view public.companies is 'Tương thích Nhân sự — đọc/ghi bảng chung cong_ty (chuẩn hoá 30/09/2026).';
alter view public.companies alter column id set default gen_random_uuid();
alter view public.companies alter column is_active set default true;
alter view public.companies alter column created_at set default now();
alter view public.companies alter column updated_at set default now();

create or replace function public.companies_ghi() returns trigger
language plpgsql set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    insert into public.cong_ty (id, ma, ten, ten_phap_ly, ma_nhan_su, ma_so_thue, dia_chi, dang_dung,
                                so_cong_chuan, han_xac_nhan_phieu_ngay, gio_vao, gio_ra, nghi_tu, nghi_den)
    values (new.id, upper(regexp_replace(new.code, '[^A-Za-z0-9]', '', 'g')), new.name, new.name, new.code,
            new.tax_code, new.address, new.is_active, new.standard_days, new.han_xac_nhan_phieu_ngay,
            new.gio_vao, new.gio_ra, new.nghi_tu, new.nghi_den);
    return new;
  elsif tg_op = 'UPDATE' then
    -- Không đụng mã/tên Tài chính (ma, ten): mã TC in trên số đề nghị.
    update public.cong_ty set ma_nhan_su = new.code, ten_phap_ly = new.name, ma_so_thue = new.tax_code,
           dia_chi = new.address, dang_dung = new.is_active, so_cong_chuan = new.standard_days,
           han_xac_nhan_phieu_ngay = new.han_xac_nhan_phieu_ngay, gio_vao = new.gio_vao, gio_ra = new.gio_ra,
           nghi_tu = new.nghi_tu, nghi_den = new.nghi_den
    where id = old.id;
    return new;
  else
    delete from public.cong_ty where id = old.id;
    return old;
  end if;
end $$;
create trigger ghi instead of insert or update or delete on public.companies
  for each row execute function public.companies_ghi();

do $$
declare r record;
begin
  for r in select a.grantee::regrole::text as ai, a.privilege_type as quyen
           from tam_quyen_companies t, aclexplode(t.relacl) a
           where a.grantee in ('anon'::regrole, 'authenticated'::regrole)
  loop execute format('grant %s on public.companies to %I', r.quyen, r.ai); end loop;
end $$;

-- =====================================================================
-- 2. PHÒNG BAN: departments → phong_ban (tên cột tiếng Việt) + view departments
-- =====================================================================
alter table public.departments rename to phong_ban;
alter table public.phong_ban rename column code to ma;
alter table public.phong_ban rename column name to ten;
alter table public.phong_ban rename column parent_id to cha_id;
alter table public.phong_ban rename column manager_id to truong_phong_id;
alter table public.phong_ban rename column is_active to dang_dung;
alter table public.phong_ban rename column company_id to cong_ty_id;
-- (cột cong_trinh_id thêm ở mục 3, sau khi có bảng cong_trinh)

create view public.departments with (security_invoker = true) as
select id, ma as code, ten as name, cha_id as parent_id, truong_phong_id as manager_id, dang_dung as is_active,
       created_at, updated_at, cong_ty_id as company_id
from public.phong_ban;
comment on view public.departments is 'Tương thích Nhân sự — bảng chung phong_ban (chuẩn hoá 30/09/2026).';
alter view public.departments alter column id set default gen_random_uuid();
alter view public.departments alter column is_active set default true;
alter view public.departments alter column created_at set default now();
alter view public.departments alter column updated_at set default now();
select gop.chep_quyen('public.phong_ban', 'public.departments');

-- =====================================================================
-- 3. CÔNG TRÌNH: du_an → cong_trinh + view du_an; công trường NS nối vào công trình
-- =====================================================================
alter table public.du_an rename to cong_trinh;
create view public.du_an with (security_invoker = true) as
select id, ma, ten, cong_ty_id, khach_hang_id, dia_diem, ngay_bat_dau, ngay_ket_thuc, chu_nhiem_id, du_toan,
       trang_thai, dang_dung, created_at, updated_at
from public.cong_trinh;
comment on view public.du_an is 'Tương thích Tài chính — bảng chung cong_trinh (chuẩn hoá 30/09/2026).';
alter view public.du_an alter column id set default gen_random_uuid();
alter view public.du_an alter column trang_thai set default 'dang_chay';
alter view public.du_an alter column dang_dung set default true;
alter view public.du_an alter column created_at set default now();
alter view public.du_an alter column updated_at set default now();
select gop.chep_quyen('public.cong_trinh', 'public.du_an');

alter table public.phong_ban add column cong_trinh_id uuid references public.cong_trinh (id);
comment on column public.phong_ban.cong_trinh_id is 'Phòng ban là CÔNG TRƯỜNG thì trỏ tới công trình (dự án Tài chính).';
update public.phong_ban p set cong_trinh_id = ct.id
from gop.phong_ban_cong_trinh g join public.cong_trinh ct on ct.ma = g.ma_du_an
where p.ma = g.ma_phong_ban;

-- =====================================================================
-- 4. ĐỐI TÁC: nha_cung_cap + khach_hang → doi_tac (giữ id) + view nha_cung_cap, khach_hang
-- =====================================================================
alter table public.nha_cung_cap rename to doi_tac;
alter table public.doi_tac
  add column ma_ke_toan text unique,
  add column la_nha_cung_cap boolean not null default false,
  add column la_khach_hang boolean not null default false,
  add column la_nha_thau_phu boolean not null default false;
update public.doi_tac set la_nha_cung_cap = true;
comment on column public.doi_tac.ma_ke_toan is 'Mã nhà cung cấp trong phần mềm kế toán (NCC00001…) — Kho dùng mã này.';

-- Khách hàng: chuyển vào doi_tac, giữ id + mã KH (trigger tự sinh mã đang tắt).
insert into public.doi_tac (id, ma, ten, ma_so_thue, dia_chi, nguoi_lien_he, dien_thoai, email, dang_dung,
                            created_at, updated_at, la_khach_hang)
select id, ma, ten, ma_so_thue, dia_chi, nguoi_lien_he, dien_thoai, email, dang_dung, created_at, updated_at, true
from public.khach_hang;
select gop.tro_khoa_ngoai('public.khach_hang', 'public.doi_tac');

-- Ghép mã kế toán, nhà thầu phụ, NCC demo ngừng dùng.
update public.doi_tac d set ma_ke_toan = g.ma_ke_toan from gop.doi_tac g where d.ma = g.ma_tc;
update public.doi_tac set la_nha_thau_phu = true where ma = 'NCC.09';
update public.doi_tac set dang_dung = false where ma in ('NCC001', 'NCC002') and la_nha_cung_cap;
insert into gop.nhat_ky (viec, chi_tiet)
select 'doi_tac: ngung dung NCC demo', jsonb_agg(ma) from public.doi_tac where ma in ('NCC001', 'NCC002');

-- Mã tự sinh: nhà cung cấp/nhà thầu phụ "NCC…", khách hàng "KH…" (trước đây mỗi bảng một trigger).
create or replace function private.tg_ma_doi_tac() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    new.ma := private.ma_danh_muc_tiep_theo(
      'doi_tac',
      case when new.la_khach_hang and not new.la_nha_cung_cap and not new.la_nha_thau_phu then 'KH' else 'NCC' end);
  elsif new.ma is distinct from old.ma
        and coalesce(current_setting('app.danh_lai_ma', true), '') <> 'on' then
    raise exception 'Mã "%" do hệ thống tự sinh, không sửa được.', old.ma;
  end if;
  return new;
end $$;
drop trigger tg_ma_danh_muc on public.doi_tac;
create trigger tg_ma_danh_muc before insert or update of ma on public.doi_tac
  for each row execute function private.tg_ma_doi_tac();

create temp table tam_quyen_khach_hang on commit drop as select relacl from pg_class where oid = 'public.khach_hang'::regclass;
drop table public.khach_hang;

create view public.nha_cung_cap with (security_invoker = true) as
select id, ma, ten, ma_so_thue, dia_chi, nguoi_lien_he, dien_thoai, email, so_tai_khoan, ten_ngan_hang, dang_dung,
       created_at, updated_at
from public.doi_tac where la_nha_cung_cap;
create view public.khach_hang with (security_invoker = true) as
select id, ma, ten, ma_so_thue, dia_chi, nguoi_lien_he, dien_thoai, email, dang_dung, created_at, updated_at
from public.doi_tac where la_khach_hang;
comment on view public.nha_cung_cap is 'Tương thích Tài chính — doi_tac là nhà cung cấp (chuẩn hoá 30/09/2026).';
comment on view public.khach_hang is 'Tương thích Tài chính — doi_tac là khách hàng (chuẩn hoá 30/09/2026).';
alter view public.nha_cung_cap alter column id set default gen_random_uuid();
alter view public.khach_hang alter column id set default gen_random_uuid();
alter view public.nha_cung_cap alter column dang_dung set default true;
alter view public.khach_hang alter column dang_dung set default true;

-- Thêm qua view phải bật đúng cờ (sửa/xoá qua view: Postgres tự làm vì view một bảng).
create or replace function public.doi_tac_them_qua_view() returns trigger
language plpgsql set search_path = '' as $$
declare v_ma text;
begin
  if tg_table_name = 'nha_cung_cap' then
    insert into public.doi_tac (id, ma, ten, ma_so_thue, dia_chi, nguoi_lien_he, dien_thoai, email, so_tai_khoan,
                                ten_ngan_hang, dang_dung, la_nha_cung_cap)
    values (new.id, coalesce(new.ma, ''), new.ten, new.ma_so_thue, new.dia_chi, new.nguoi_lien_he, new.dien_thoai,
            new.email, new.so_tai_khoan, new.ten_ngan_hang, new.dang_dung, true)
    returning ma, created_at, updated_at into v_ma, new.created_at, new.updated_at;
  else
    insert into public.doi_tac (id, ma, ten, ma_so_thue, dia_chi, nguoi_lien_he, dien_thoai, email, dang_dung, la_khach_hang)
    values (new.id, coalesce(new.ma, ''), new.ten, new.ma_so_thue, new.dia_chi, new.nguoi_lien_he, new.dien_thoai,
            new.email, new.dang_dung, true)
    returning ma, created_at, updated_at into v_ma, new.created_at, new.updated_at;
  end if;
  new.ma := v_ma;
  return new;
end $$;
create trigger them instead of insert on public.nha_cung_cap for each row execute function public.doi_tac_them_qua_view();
create trigger them instead of insert on public.khach_hang for each row execute function public.doi_tac_them_qua_view();

select gop.chep_quyen('public.doi_tac', 'public.nha_cung_cap');
do $$
declare r record;
begin
  for r in select a.grantee::regrole::text as ai, a.privilege_type as quyen
           from tam_quyen_khach_hang t, aclexplode(t.relacl) a
           where a.grantee in ('anon'::regrole, 'authenticated'::regrole)
  loop execute format('grant %s on public.khach_hang to %I', r.quyen, r.ai); end loop;
end $$;

-- =====================================================================
-- 5. NGƯỜI: bảng chung danh tính
-- =====================================================================
create table public.nguoi (
  id                  uuid primary key default gen_random_uuid(),
  ho_ten              text not null,
  ngay_sinh           date,
  gioi_tinh           text check (gioi_tinh = any (array['nam', 'nu', 'khac'])),
  dien_thoai          text,
  email               text,
  dia_chi_thuong_tru  text,
  user_id             uuid unique references auth.users (id) on delete set null,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);
comment on table public.nguoi is 'MỘT dòng cho mỗi người (danh tính). Vai trò trong từng phân hệ ở nhan_vien_tc / ho_so_nhan_su / kho.nguoi_dung. Không có công ty (công ty lưu theo từng phân hệ).';
comment on column public.nguoi.user_id is 'Tài khoản đăng nhập (một tài khoản cho cả 3 phân hệ). Trống = không đăng nhập (vd công nhân).';
create trigger nguoi_updated_at before update on public.nguoi
  for each row execute function private.tu_dong_cap_nhat_updated_at();

-- 5a. Người từ hồ sơ Nhân sự: giữ nguyên id (mọi bảng NS đang trỏ tới id này).
insert into public.nguoi (id, ho_ten, ngay_sinh, gioi_tinh, dien_thoai, email, dia_chi_thuong_tru, user_id, created_at, updated_at)
select e.id, e.full_name, e.dob, e.gender, e.phone, e.personal_email, e.permanent_address,
       (select u.id from public.app_users u where u.employee_id = e.id order by u.is_active desc, u.created_at limit 1),
       e.created_at, e.updated_at
from public.employees e;

-- 5b. Người từ Tài chính: đã ghép → dùng người NS; chưa ghép → người mới.
create temp table tam_nguoi_tc on commit drop as
select nv.id as nhan_vien_id, nv.user_id, nv.ho_ten,
       (select e.id from gop.nguoi g join public.employees e on e.employee_code = g.ma_nv_ns where g.ma_nv_tc = nv.ma) as nguoi_ns,
       gen_random_uuid() as nguoi_moi
from public.nhan_vien nv;

insert into public.nguoi (id, ho_ten, user_id, created_at, updated_at)
select t.nguoi_moi, t.ho_ten,
       case when not exists (select 1 from public.nguoi n where n.user_id = t.user_id) then t.user_id end,
       nv.created_at, nv.updated_at
from tam_nguoi_tc t join public.nhan_vien nv on nv.id = t.nhan_vien_id
where t.nguoi_ns is null;

-- Người đã ghép: tài khoản giữ bên Nhân sự nếu có; NS chưa có tài khoản thì lấy tài khoản TC.
update public.nguoi n set user_id = t.user_id
from tam_nguoi_tc t
where n.id = t.nguoi_ns and n.user_id is null and t.user_id is not null
  and not exists (select 1 from public.nguoi x where x.user_id = t.user_id);
insert into gop.nhat_ky (viec, chi_tiet)
select 'nguoi: nguoi trung giu tai khoan NS, bo tai khoan TC',
       jsonb_agg(jsonb_build_object('nhan_vien_tc', t.nhan_vien_id, 'tai_khoan_tc_bo', t.user_id, 'tai_khoan_giu', n.user_id))
from tam_nguoi_tc t join public.nguoi n on n.id = t.nguoi_ns
where t.user_id is not null and n.user_id is distinct from t.user_id;

-- =====================================================================
-- 6. NHÂN VIÊN TÀI CHÍNH: nhan_vien → nhan_vien_tc (vai trò) + view nhan_vien
-- =====================================================================
-- View phụ thuộc nhan_vien (v_nhap_quy_trung, v_so_du_quy_ca_nhan…): lưu định nghĩa, xoá, dựng lại sau.
create temp table tam_view on commit drop as
with recursive phu as (
  select distinct v.oid, 1 as tang
  from pg_depend d join pg_rewrite r on r.oid = d.objid join pg_class v on v.oid = r.ev_class
  where d.refobjid = 'public.nhan_vien'::regclass and v.oid <> 'public.nhan_vien'::regclass and v.relkind = 'v'
  union
  select distinct v.oid, p.tang + 1
  from phu p join pg_depend d on d.refobjid = p.oid join pg_rewrite r on r.oid = d.objid join pg_class v on v.oid = r.ev_class
  where v.oid <> p.oid and v.relkind = 'v'
)
select c.oid, c.relname as ten, max(p.tang) as tang, pg_get_viewdef(c.oid) as dn, c.reloptions, c.relacl,
       obj_description(c.oid, 'pg_class') as ghi_chu
from phu p join pg_class c on c.oid = p.oid
group by c.oid, c.relname, c.reloptions, c.relacl;

do $$
declare r record;
begin
  for r in select ten from tam_view order by tang desc loop
    execute format('drop view public.%I', r.ten);
  end loop;
end $$;

alter table public.nhan_vien rename to nhan_vien_tc;
alter table public.nhan_vien_tc add column nguoi_id uuid references public.nguoi (id);
update public.nhan_vien_tc t set nguoi_id = coalesce(m.nguoi_ns, m.nguoi_moi)
from tam_nguoi_tc m where m.nhan_vien_id = t.id;
alter table public.nhan_vien_tc alter column nguoi_id set not null;
alter table public.nhan_vien_tc add constraint nhan_vien_tc_nguoi_key unique (nguoi_id);
alter table public.nhan_vien_tc drop column ho_ten, drop column user_id;
comment on table public.nhan_vien_tc is 'Vai trò Tài chính của một người (id = id nhan_vien cũ — mọi bảng Tài chính trỏ tới đây). Danh tính ở nguoi.';

create view public.nhan_vien with (security_invoker = true) as
select t.id, n.user_id, t.ma, n.ho_ten, t.cong_ty_id, t.chuc_vu, t.dang_dung, t.created_at, t.updated_at
from public.nhan_vien_tc t join public.nguoi n on n.id = t.nguoi_id;
comment on view public.nhan_vien is 'Tương thích Tài chính — nhan_vien_tc + nguoi (chuẩn hoá 30/09/2026).';
alter view public.nhan_vien alter column id set default gen_random_uuid();
alter view public.nhan_vien alter column dang_dung set default true;
alter view public.nhan_vien alter column created_at set default now();
alter view public.nhan_vien alter column updated_at set default now();
select gop.chep_quyen('public.nhan_vien_tc', 'public.nhan_vien');

create or replace function public.nhan_vien_ghi() returns trigger
language plpgsql set search_path = '' as $$
declare v_nguoi uuid;
begin
  if tg_op = 'INSERT' then
    insert into public.nguoi (ho_ten, user_id) values (new.ho_ten, new.user_id) returning id into v_nguoi;
    insert into public.nhan_vien_tc (id, nguoi_id, ma, cong_ty_id, chuc_vu, dang_dung)
    values (new.id, v_nguoi, coalesce(new.ma, ''), new.cong_ty_id, new.chuc_vu, new.dang_dung)
    returning ma, created_at, updated_at into new.ma, new.created_at, new.updated_at;
    return new;
  elsif tg_op = 'UPDATE' then
    update public.nguoi set ho_ten = new.ho_ten, user_id = new.user_id
    where id = (select nguoi_id from public.nhan_vien_tc where id = old.id);
    update public.nhan_vien_tc set ma = new.ma, cong_ty_id = new.cong_ty_id, chuc_vu = new.chuc_vu,
           dang_dung = new.dang_dung
    where id = old.id;
    return new;
  else
    delete from public.nhan_vien_tc where id = old.id;
    return old;
  end if;
end $$;
create trigger ghi instead of insert or update or delete on public.nhan_vien
  for each row execute function public.nhan_vien_ghi();

-- Dựng lại các view phụ thuộc (định nghĩa cũ gọi "nhan_vien" → nay là view tương thích).
do $$
declare r record;
begin
  for r in select * from tam_view order by tang loop
    execute format('create view public.%I %s as %s',
      r.ten,
      case when r.reloptions is null then '' else 'with (' || array_to_string(r.reloptions, ', ') || ')' end,
      r.dn);
    if r.ghi_chu is not null then
      execute format('comment on view public.%I is %L', r.ten, r.ghi_chu);
    end if;
  end loop;
end $$;
do $$
declare r record;
begin
  for r in select t.ten, a.grantee::regrole::text as ai, a.privilege_type as quyen
           from tam_view t, aclexplode(t.relacl) a
           where a.grantee in ('anon'::regrole, 'authenticated'::regrole)
  loop execute format('grant %s on public.%I to %I', r.quyen, r.ten, r.ai); end loop;
end $$;

-- =====================================================================
-- 7. HỒ SƠ NHÂN SỰ: employees → ho_so_nhan_su (vai trò NS, tên cột tiếng Việt) + view employees
-- =====================================================================
alter table public.employees rename to ho_so_nhan_su;
alter table public.ho_so_nhan_su rename column id to nguoi_id;
alter table public.ho_so_nhan_su rename column employee_code to ma_nv;
alter table public.ho_so_nhan_su rename column department_id to phong_ban_id;
alter table public.ho_so_nhan_su rename column manager_id to quan_ly_id;
alter table public.ho_so_nhan_su rename column region to vung;
alter table public.ho_so_nhan_su rename column hire_date to ngay_vao;
alter table public.ho_so_nhan_su rename column status to trang_thai;
alter table public.ho_so_nhan_su rename column avatar_url to anh_dai_dien;
alter table public.ho_so_nhan_su rename column company_id to cong_ty_id;
alter table public.ho_so_nhan_su rename column deleted_at to xoa_luc;
alter table public.ho_so_nhan_su rename column deleted_by to xoa_boi;
alter table public.ho_so_nhan_su alter column nguoi_id drop default;
alter table public.ho_so_nhan_su add constraint ho_so_nhan_su_nguoi_fkey foreign key (nguoi_id) references public.nguoi (id);
alter table public.ho_so_nhan_su drop constraint employees_gender_check;
alter table public.ho_so_nhan_su
  drop column full_name, drop column dob, drop column gender, drop column permanent_address,
  drop column phone, drop column personal_email;
comment on table public.ho_so_nhan_su is 'Vai trò Nhân sự của một người (nguoi_id = id employees cũ — mọi bảng Nhân sự trỏ tới đây). Danh tính ở nguoi.';

create view public.employees with (security_invoker = true) as
select h.nguoi_id as id, h.ma_nv as employee_code, n.ho_ten as full_name, n.ngay_sinh as dob, n.gioi_tinh as gender,
       n.dia_chi_thuong_tru as permanent_address, n.dien_thoai as phone, n.email as personal_email,
       h.phong_ban_id as department_id, h.quan_ly_id as manager_id, h.vung as region, h.ngay_vao as hire_date,
       h.trang_thai as status, h.anh_dai_dien as avatar_url, h.created_at, h.updated_at, h.theo_doi_cham_cong,
       h.cong_ty_id as company_id, h.xoa_luc as deleted_at, h.xoa_boi as deleted_by, h.ly_do_xoa
from public.ho_so_nhan_su h join public.nguoi n on n.id = h.nguoi_id;
comment on view public.employees is 'Tương thích Nhân sự — ho_so_nhan_su + nguoi (chuẩn hoá 30/09/2026).';
alter view public.employees alter column id set default gen_random_uuid();
alter view public.employees alter column status set default 'thu_viec'::public.employee_status;
alter view public.employees alter column theo_doi_cham_cong set default true;
alter view public.employees alter column created_at set default now();
alter view public.employees alter column updated_at set default now();
select gop.chep_quyen('public.ho_so_nhan_su', 'public.employees');

create or replace function public.employees_ghi() returns trigger
language plpgsql set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    insert into public.nguoi (id, ho_ten, ngay_sinh, gioi_tinh, dia_chi_thuong_tru, dien_thoai, email)
    values (new.id, new.full_name, new.dob, new.gender, new.permanent_address, new.phone, new.personal_email);
    insert into public.ho_so_nhan_su (nguoi_id, ma_nv, phong_ban_id, quan_ly_id, vung, ngay_vao, trang_thai,
                                      anh_dai_dien, theo_doi_cham_cong, cong_ty_id, xoa_luc, xoa_boi, ly_do_xoa)
    values (new.id, new.employee_code, new.department_id, new.manager_id, new.region, new.hire_date, new.status,
            new.avatar_url, new.theo_doi_cham_cong, new.company_id, new.deleted_at, new.deleted_by, new.ly_do_xoa)
    returning created_at, updated_at into new.created_at, new.updated_at;
    return new;
  elsif tg_op = 'UPDATE' then
    update public.nguoi set ho_ten = new.full_name, ngay_sinh = new.dob, gioi_tinh = new.gender,
           dia_chi_thuong_tru = new.permanent_address, dien_thoai = new.phone, email = new.personal_email
    where id = old.id;
    update public.ho_so_nhan_su set ma_nv = new.employee_code, phong_ban_id = new.department_id,
           quan_ly_id = new.manager_id, vung = new.region, ngay_vao = new.hire_date, trang_thai = new.status,
           anh_dai_dien = new.avatar_url, theo_doi_cham_cong = new.theo_doi_cham_cong, cong_ty_id = new.company_id,
           xoa_luc = new.deleted_at, xoa_boi = new.deleted_by, ly_do_xoa = new.ly_do_xoa
    where nguoi_id = old.id;
    return new;
  else
    delete from public.ho_so_nhan_su where nguoi_id = old.id;
    return old;
  end if;
end $$;
create trigger ghi instead of insert or update or delete on public.employees
  for each row execute function public.employees_ghi();

-- Hồ sơ Nhân sự tối thiểu cho nhân viên TC chủ dự án quyết đưa vào NS (gop.nguoi_them_ns).
-- theo_doi_cham_cong = false: chưa vào bảng công; chưa có hợp đồng nên chưa vào bảng lương.
insert into public.ho_so_nhan_su (nguoi_id, ma_nv, cong_ty_id, trang_thai, theo_doi_cham_cong)
select t.nguoi_id, t.ma, t.cong_ty_id, 'chinh_thuc'::public.employee_status, false
from public.nhan_vien_tc t join gop.nguoi_them_ns g on g.ma_nv_tc = t.ma
where not exists (select 1 from public.ho_so_nhan_su h where h.nguoi_id = t.nguoi_id);
insert into gop.nhat_ky (viec, chi_tiet)
select 'ho_so_nhan_su: tao ho so toi thieu cho NV TC', jsonb_agg(g.ma_nv_tc) from gop.nguoi_them_ns g;

-- =====================================================================
-- 8. QUYỀN XEM / GHI bảng nguoi: thấy người khi thấy được vai trò của họ ở ít nhất một phân hệ
-- (truy vấn con trong policy chịu RLS của bảng vai trò → quyền mỗi phân hệ giữ nguyên, không cộng dồn thêm).
-- =====================================================================
alter table public.nguoi enable row level security;
create policy nguoi_doc on public.nguoi for select to authenticated using (
  user_id = (select auth.uid())
  or exists (select 1 from public.ho_so_nhan_su h where h.nguoi_id = nguoi.id)
  or exists (select 1 from public.nhan_vien_tc t where t.nguoi_id = nguoi.id)
);
create policy nguoi_them on public.nguoi for insert to authenticated with check (
  (select public.is_hr_or_admin()) or private.co_vai_tro('quan_tri')
);
create policy nguoi_sua on public.nguoi for update to authenticated
  using ((select public.is_hr_or_admin()) or private.co_vai_tro('quan_tri'))
  with check ((select public.is_hr_or_admin()) or private.co_vai_tro('quan_tri'));
revoke all on public.nguoi from anon, authenticated;
grant select, insert, update on public.nguoi to authenticated;

-- =====================================================================
-- 9. STK ngân hàng: người trùng, Tài chính có STK → Nhân sự lấy theo Tài chính (quyết định 30/09)
-- =====================================================================
insert into gop.nhat_ky (viec, chi_tiet)
select 'stk: nhan su lay theo tai chinh',
       jsonb_agg(jsonb_build_object('nguoi', t.nguoi_id, 'ns_cu_4_so', right(s.bank_account_no, 4), 'tc_4_so', right(k.so_tai_khoan, 4)))
from public.nhan_vien_tc t
join public.nhan_vien_nhay_cam k on k.nhan_vien_id = t.id and nullif(k.so_tai_khoan, '') is not null
join public.ho_so_nhan_su h on h.nguoi_id = t.nguoi_id
left join public.employee_sensitive s on s.employee_id = h.nguoi_id
where s.bank_account_no is distinct from k.so_tai_khoan or s.bank_name is distinct from k.ten_ngan_hang;

insert into public.employee_sensitive (employee_id, bank_account_no, bank_name)
select h.nguoi_id, k.so_tai_khoan, k.ten_ngan_hang
from public.nhan_vien_tc t
join public.nhan_vien_nhay_cam k on k.nhan_vien_id = t.id and nullif(k.so_tai_khoan, '') is not null
join public.ho_so_nhan_su h on h.nguoi_id = t.nguoi_id
on conflict (employee_id) do update set bank_account_no = excluded.bank_account_no, bank_name = excluded.bank_name;

-- =====================================================================
-- 10. QUYỀN VÀO PHÂN HỆ
-- =====================================================================
create table public.quyen_phan_he (
  user_id     uuid not null references auth.users (id) on delete cascade,
  phan_he     text not null check (phan_he in ('tc', 'ns', 'kho', 'ht')),
  dang_dung   boolean not null default true,
  created_at  timestamptz not null default now(),
  primary key (user_id, phan_he)
);
comment on table public.quyen_phan_he is 'Ai được vào phân hệ nào (bộ chọn phân hệ đọc bảng này). Vai trò CHI TIẾT vẫn do từng phân hệ giữ. Ẩn phân hệ KHÔNG phải phân quyền.';
alter table public.quyen_phan_he enable row level security;
create policy quyen_phan_he_doc_cua_minh on public.quyen_phan_he for select to authenticated
  using (user_id = (select auth.uid()));
revoke all on public.quyen_phan_he from anon, authenticated;
grant select on public.quyen_phan_he to authenticated;

insert into public.quyen_phan_he (user_id, phan_he)
select distinct n.user_id, 'tc' from public.nhan_vien_tc t join public.nguoi n on n.id = t.nguoi_id
where t.dang_dung and n.user_id is not null
union
select distinct u.id, 'ns' from public.app_users u where u.is_active
on conflict do nothing;

-- =====================================================================
-- Kết thúc
-- =====================================================================
set local session_replication_role = origin;
drop function gop.chep_quyen(regclass, regclass);
drop function gop.tro_khoa_ngoai(regclass, regclass);
notify pgrst, 'reload schema';
