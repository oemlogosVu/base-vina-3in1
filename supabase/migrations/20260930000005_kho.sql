-- =====================================================================
-- KHO — dựng schema `kho` từ 12 tab Google Sheet VATTU_KHO_DB
-- (Inventory manager main 6e8ae7f: docs/02-schema-sheet.md, lib/types.ts, lib/ton-kho.ts)
--
-- Quyết định 30/09/2026 (docs/KE_HOACH_DU_LIEU_DUNG_CHUNG.md §6):
--   * Kho chuyển vào database, bỏ Google Sheet.
--   * Danh mục dùng chung KHÔNG lặp lại ở đây: nhà cung cấp → public.doi_tac (ma_ke_toan),
--     công trình → public.cong_trinh, người → public.nguoi. Bảng chung tạo ở migration 000004.
--   * Tồn kho KHÔNG lưu (bỏ tab ton_kho_cache) — view kho.v_ton_kho tính lại từ phiếu đã duyệt,
--     chép đúng công thức lib/ton-kho.ts (kể cả cách làm tròn của Math.round).
--   * Sổ chỉ ghi thêm: không xoá dòng nào; phiếu/đề xuất chỉ được cập nhật các cột trạng thái
--     (đúng quy tắc hiện tại: phieu cột K–P, de_xuat cột J–S).
--   * Kho kiểm quyền ở MÁY CHỦ (kiemTraSession + kiemTraQuyen) → RLS bật, KHÔNG cấp gì cho
--     anon/authenticated; chỉ service_role (máy chủ app) đọc/ghi.
--
-- Mã chữ (so_phieu, ma_vt, ma_kho…) giữ làm khóa chính: code Kho đang dùng chúng, số phiếu in trên giấy.
-- Người tạo/duyệt/huỷ lưu EMAIL như Sheet (dấu vết lịch sử; QT-A so email người tạo với người duyệt).
-- Thời điểm trong Sheet là giờ VN không múi giờ → khi nạp đổi sang timestamptz (+07).
-- =====================================================================

create schema if not exists kho;
revoke all on schema kho from public, anon, authenticated;
grant usage on schema kho to service_role;

-- ---------------------------------------------------------------------
-- Danh mục riêng của Kho
-- ---------------------------------------------------------------------
create table kho.vat_tu (
  ma_vt       text primary key,
  ten_vt      text not null,
  dvt         text not null,
  quy_cach    text,
  nhom        text,
  ton_min     numeric,                       -- trống = không cảnh báo tồn thấp
  ghi_chu     text,
  trang_thai  text not null default 'HOAT_DONG' check (trang_thai in ('HOAT_DONG', 'NGUNG')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- "Kho = công trình": một công trình có thể có nhiều kho (KHO03, KHO04 cùng Thái Nguyên).
create table kho.kho (
  ma_kho        text primary key,
  ten_kho       text not null,
  dia_diem      text,
  thu_kho       text,                        -- tên người, như Sheet (không phải khóa ngoại)
  cong_trinh_id uuid references public.cong_trinh (id),
  trang_thai    text not null default 'HOAT_DONG' check (trang_thai in ('HOAT_DONG', 'NGUNG')),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- Bộ phận nhận hàng khi xuất kho. Sheet lẫn phòng ban văn phòng + công trường + tổ đội
-- → nối tùy chọn sang phong_ban hoặc to_doi (chủ dự án ghép tay).
create table kho.bo_phan (
  ma_bp          text primary key,
  ten_bp         text not null,
  email_quan_ly  text,
  phong_ban_id   uuid references public.phong_ban (id),
  to_doi_id      uuid references public.to_doi (id),
  cong_trinh_id  uuid references public.cong_trinh (id),  -- tổ đội nhận hàng tại công trình (BP05, BP06)
  trang_thai     text not null default 'HOAT_DONG' check (trang_thai in ('HOAT_DONG', 'NGUNG')),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

-- Người dùng Kho = vai trò Kho của một người (danh tính ở public.nguoi, đăng nhập ở auth.users).
-- Bỏ cột mat_khau_hash / doi_mk_lan_dau của Sheet: đăng nhập bằng Supabase.
create table kho.nguoi_dung (
  nguoi_id    uuid primary key references public.nguoi (id),
  email       text not null unique check (email = lower(email)),  -- email lưu trên phiếu (nguoi_tao…)
  vai_tro     text not null check (vai_tro in ('admin', 'thu_kho', 'duyet', 'xem')),
  trang_thai  text not null default 'HOAT_DONG' check (trang_thai in ('HOAT_DONG', 'NGUNG')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- Cột ma_kho_phu_trach ("KHO01,KHO03") của Sheet. Không có dòng nào = phụ trách MỌI kho.
create table kho.nguoi_dung_kho (
  nguoi_id  uuid not null references kho.nguoi_dung (nguoi_id),
  ma_kho    text not null references kho.kho (ma_kho),
  primary key (nguoi_id, ma_kho)
);

-- Tab dm_phan_quyen: 4 dòng, cờ CO/KHONG → boolean. tu_duyet_phieu chỉ có tác dụng ở dòng thu_kho.
create table kho.phan_quyen_vai_tro (
  vai_tro         text primary key check (vai_tro in ('admin', 'thu_kho', 'duyet', 'xem')),
  trang_chu       boolean not null default false,
  phieu           boolean not null default false,
  ton_kho         boolean not null default false,
  the_kho         boolean not null default false,
  bao_cao         boolean not null default false,
  danh_muc        boolean not null default false,
  dieu_chinh      boolean not null default false,
  de_xuat         boolean not null default false,
  tu_duyet_phieu  boolean not null default false,
  updated_at      timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Phiếu nhập / xuất / điều chỉnh
-- ---------------------------------------------------------------------
-- Số phiếu: {NK|XK|DC}-{YYMMDD}-{HHmmss}-{2 ký tự ngẫu nhiên} (lib/so-phieu.ts) — KHÔNG max+1.
-- Khóa chính bảo đảm không trùng (Sheet chỉ trùng "khó xảy ra").
create table kho.phieu (
  so_phieu         text primary key,
  loai             text not null check (loai in ('NHAP', 'XUAT', 'DIEU_CHINH')),
  ngay_ct          date not null,
  ma_kho           text not null references kho.kho (ma_kho),
  ma_ncc           text references public.doi_tac (ma_ke_toan),   -- chỉ phiếu NHAP
  ma_bp            text references kho.bo_phan (ma_bp),            -- chỉ phiếu XUAT
  so_ct_goc        text,
  nguoi_tao        text not null,                                   -- email
  thoi_gian_tao    timestamptz not null,
  trang_thai       text not null default 'CHO_DUYET' check (trang_thai in ('CHO_DUYET', 'DA_DUYET', 'HUY')),
  nguoi_duyet      text,
  thoi_gian_duyet  timestamptz,
  nguoi_huy        text,                                            -- email hoặc 'HE_THONG'
  thoi_gian_huy    timestamptz,
  ly_do_huy        text,
  ghi_chu          text                                             -- DIEU_CHINH: lý do điều chỉnh
);
create index phieu_kho_ngay_idx on kho.phieu (ma_kho, ngay_ct);
create index phieu_trang_thai_idx on kho.phieu (trang_thai);

-- Tab chi_tiet. id_dong "{so_phieu}#{n}" → (so_phieu, dong).
-- thu_tu: thứ tự ghi vào sổ (thay thứ tự dòng trong Sheet) — dùng khi hai lần nhập trùng
-- cả ngày chứng từ lẫn giờ tạo (lib/ton-kho.ts: dòng sau thắng).
create table kho.phieu_chi_tiet (
  so_phieu      text not null references kho.phieu (so_phieu),
  dong          integer not null check (dong > 0),
  ma_vt         text not null references kho.vat_tu (ma_vt),
  so_luong      numeric not null check (so_luong <> 0),   -- NHAP/XUAT > 0; DIEU_CHINH mang dấu
  don_gia_nhap  numeric,                                  -- chỉ NHAP
  thanh_tien    numeric,                                  -- chỉ NHAP = round(so_luong × don_gia_nhap)
  ghi_chu       text,
  thu_tu        bigint generated always as identity,
  primary key (so_phieu, dong)
);
create index phieu_chi_tiet_vt_idx on kho.phieu_chi_tiet (ma_vt);

-- Ảnh chứng từ (Sheet: URL nối bằng "|", tối đa 5). Ảnh chép sang bucket kho-chung-tu.
create table kho.phieu_anh (
  so_phieu    text not null references kho.phieu (so_phieu),
  thu_tu      smallint not null check (thu_tu between 1 and 5),
  duong_dan   text not null,
  primary key (so_phieu, thu_tu)
);

-- ---------------------------------------------------------------------
-- Đề xuất mua vật tư (không ảnh hưởng tồn kho)
-- ---------------------------------------------------------------------
create table kho.de_xuat (
  so_dx            text primary key,
  ngay_dx          date not null,
  ma_kho           text not null references kho.kho (ma_kho),
  ngay_can         date,
  ly_do            text not null,
  ghi_chu          text,
  nguoi_tao        text not null,
  thoi_gian_tao    timestamptz not null,
  trang_thai       text not null default 'CHO_DUYET'
                   check (trang_thai in ('CHO_DUYET', 'DA_DUYET', 'TU_CHOI', 'DA_MUA', 'HUY')),
  nguoi_duyet      text,
  thoi_gian_duyet  timestamptz,
  y_kien_duyet     text,
  nguoi_huy        text,
  thoi_gian_huy    timestamptz,
  ly_do_huy        text,
  nguoi_dong       text,
  thoi_gian_dong   timestamptz,
  ghi_chu_dong     text
);

create table kho.de_xuat_chi_tiet (
  so_dx               text not null references kho.de_xuat (so_dx),
  dong                integer not null check (dong > 0),
  ma_vt               text references kho.vat_tu (ma_vt),
  ten_tu_do           text,
  so_luong            numeric not null check (so_luong > 0),
  don_gia_du_kien     numeric,
  thanh_tien_du_kien  numeric,
  ghi_chu             text,
  primary key (so_dx, dong),
  -- đúng MỘT trong hai: vật tư có mã, hoặc tên tự do
  check ((ma_vt is null) <> (nullif(btrim(ten_tu_do), '') is null))
);

create table kho.de_xuat_anh (
  so_dx      text not null references kho.de_xuat (so_dx),
  thu_tu     smallint not null check (thu_tu between 1 and 5),
  duong_dan  text not null,
  primary key (so_dx, thu_tu)
);

-- ---------------------------------------------------------------------
-- Nhật ký (tab log) — chỉ ghi thêm. Dữ liệu trước/sau giữ dạng chữ: Sheet cắt ≤1000 ký tự
-- nên có thể không còn là JSON hợp lệ.
-- ---------------------------------------------------------------------
create table kho.nhat_ky (
  id            bigint generated always as identity primary key,
  thoi_gian     timestamptz not null default now(),
  email         text,
  hanh_dong     text not null,
  doi_tuong     text,
  du_lieu_truoc text,
  du_lieu_sau   text,
  ip            text
);
create index nhat_ky_thoi_gian_idx on kho.nhat_ky (thoi_gian);

-- ---------------------------------------------------------------------
-- Tồn kho — VIEW, không lưu. Chép lib/ton-kho.ts → tinhTonKho():
--   tồn = Σ NHAP − Σ XUAT + Σ DIEU_CHINH (DIEU_CHINH đã mang dấu), chỉ phiếu DA_DUYET
--   đơn giá BQ = Math.round(Σ thành tiền NHAP / Σ số lượng NHAP), không có NHAP → 0
--   đơn giá gần nhất = đơn giá của dòng NHAP có (ngay_ct, thoi_gian_tao) lớn nhất; trùng → dòng ghi sau
--   giá trị tồn = Math.round(tồn × đơn giá BQ)
-- Math.round của JS làm tròn .5 LÊN phía +∞ (−2,5 → −2) ≠ round() của Postgres (−2,5 → −3)
-- → dùng floor(x + 0.5) để khớp tuyệt đối.
-- ---------------------------------------------------------------------
create view kho.v_ton_kho with (security_invoker = true) as
with dong as (
  select p.ma_kho, c.ma_vt, p.loai, c.so_luong, c.thanh_tien, c.don_gia_nhap,
         p.ngay_ct, p.thoi_gian_tao, c.thu_tu
  from kho.phieu_chi_tiet c
  join kho.phieu p on p.so_phieu = c.so_phieu
  where p.trang_thai = 'DA_DUYET'
),
gop as (
  select ma_kho, ma_vt,
         sum(case loai when 'XUAT' then -so_luong else so_luong end)            as so_luong_ton,
         sum(case when loai = 'NHAP' then coalesce(thanh_tien, 0) else 0 end)  as tong_tien_nhap,
         sum(case when loai = 'NHAP' then so_luong else 0 end)                  as tong_sl_nhap
  from dong
  group by ma_kho, ma_vt
),
gan_nhat as (
  select distinct on (ma_kho, ma_vt) ma_kho, ma_vt, coalesce(don_gia_nhap, 0) as don_gia_gan_nhat
  from dong
  where loai = 'NHAP'
  order by ma_kho, ma_vt, ngay_ct desc, thoi_gian_tao desc, thu_tu desc
)
select g.ma_kho, g.ma_vt, g.so_luong_ton,
       coalesce(n.don_gia_gan_nhat, 0) as don_gia_gan_nhat,
       bq.don_gia_bq,
       floor(g.so_luong_ton * bq.don_gia_bq + 0.5) as gia_tri_ton
from gop g
left join gan_nhat n using (ma_kho, ma_vt)
cross join lateral (
  select case when g.tong_sl_nhap > 0 then floor(g.tong_tien_nhap / g.tong_sl_nhap + 0.5) else 0 end as don_gia_bq
) bq;

-- ---------------------------------------------------------------------
-- Sổ chỉ ghi thêm
-- ---------------------------------------------------------------------
create function kho.chan_xoa() returns trigger
language plpgsql set search_path = '' as $$
begin
  raise exception 'Sổ kho chỉ ghi thêm — không được xoá dòng ở bảng %', tg_table_name
    using errcode = 'check_violation';
end $$;

-- Phiếu: chỉ đổi các cột trạng thái (Sheet cột K–P). Không được xoá thông tin người duyệt khi huỷ.
create function kho.chi_sua_trang_thai_phieu() returns trigger
language plpgsql set search_path = '' as $$
begin
  if (new.so_phieu, new.loai, new.ngay_ct, new.ma_kho, new.ma_ncc, new.ma_bp, new.so_ct_goc,
      new.nguoi_tao, new.thoi_gian_tao, new.ghi_chu)
     is distinct from
     (old.so_phieu, old.loai, old.ngay_ct, old.ma_kho, old.ma_ncc, old.ma_bp, old.so_ct_goc,
      old.nguoi_tao, old.thoi_gian_tao, old.ghi_chu) then
    raise exception 'Phiếu % chỉ được đổi trạng thái — muốn sửa nội dung thì huỷ (có lý do) rồi lập phiếu mới', old.so_phieu
      using errcode = 'check_violation';
  end if;
  if old.nguoi_duyet is not null and new.nguoi_duyet is distinct from old.nguoi_duyet then
    raise exception 'Không được xoá/đổi người duyệt của phiếu %', old.so_phieu using errcode = 'check_violation';
  end if;
  return new;
end $$;

-- Đề xuất: chỉ đổi trạng thái + các cột duyệt/huỷ/đóng (Sheet cột J–S).
create function kho.chi_sua_trang_thai_de_xuat() returns trigger
language plpgsql set search_path = '' as $$
begin
  if (new.so_dx, new.ngay_dx, new.ma_kho, new.ngay_can, new.ly_do, new.ghi_chu, new.nguoi_tao, new.thoi_gian_tao)
     is distinct from
     (old.so_dx, old.ngay_dx, old.ma_kho, old.ngay_can, old.ly_do, old.ghi_chu, old.nguoi_tao, old.thoi_gian_tao) then
    raise exception 'Đề xuất % chỉ được đổi trạng thái', old.so_dx using errcode = 'check_violation';
  end if;
  return new;
end $$;

create function kho.chan_sua() returns trigger
language plpgsql set search_path = '' as $$
begin
  raise exception 'Bảng % chỉ ghi thêm — không được sửa', tg_table_name using errcode = 'check_violation';
end $$;

do $$
declare b text;
begin
  foreach b in array array['vat_tu','kho','bo_phan','nguoi_dung','nguoi_dung_kho','phan_quyen_vai_tro',
                           'phieu','phieu_chi_tiet','phieu_anh','de_xuat','de_xuat_chi_tiet','de_xuat_anh','nhat_ky']
  loop
    execute format('create trigger chan_xoa before delete on kho.%I for each statement execute function kho.chan_xoa()', b);
    execute format('alter table kho.%I enable row level security', b);
    execute format('revoke all on kho.%I from public, anon, authenticated', b);
    execute format('grant select, insert, update on kho.%I to service_role', b);
  end loop;
end $$;

-- Phân quyền phụ trách kho được SỬA (thêm/bớt kho) → cho phép xoá riêng bảng này.
drop trigger chan_xoa on kho.nguoi_dung_kho;
grant delete on kho.nguoi_dung_kho to service_role;

create trigger chi_sua_trang_thai before update on kho.phieu
  for each row execute function kho.chi_sua_trang_thai_phieu();
create trigger chi_sua_trang_thai before update on kho.de_xuat
  for each row execute function kho.chi_sua_trang_thai_de_xuat();
create trigger chan_sua before update on kho.phieu_chi_tiet for each row execute function kho.chan_sua();
create trigger chan_sua before update on kho.phieu_anh for each row execute function kho.chan_sua();
create trigger chan_sua before update on kho.de_xuat_chi_tiet for each row execute function kho.chan_sua();
create trigger chan_sua before update on kho.de_xuat_anh for each row execute function kho.chan_sua();
create trigger chan_sua before update on kho.nhat_ky for each row execute function kho.chan_sua();

revoke all on kho.v_ton_kho from public, anon, authenticated;
grant select on kho.v_ton_kho to service_role;
grant usage on all sequences in schema kho to service_role;

comment on schema kho is 'Phân hệ Kho (chuyển từ Google Sheet 30/09/2026). Chỉ máy chủ app (service_role) truy cập; quyền kiểm ở máy chủ.';
comment on view kho.v_ton_kho is 'Tồn kho tính lại từ phiếu DA_DUYET — chép lib/ton-kho.ts tinhTonKho(). KHÔNG lưu tồn.';
