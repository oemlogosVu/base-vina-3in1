-- =====================================================================
-- TÀI CHÍNH — cấu trúc gốc (bảng, view, hàm public + private, RLS, policy, trigger)
--
-- SINH TỰ ĐỘNG 30/09/2026 từ DB Tài chính đang chạy (eodrpyedatohsovobsxj, bản sao lưu
-- F:\SaoLuu_BaseVina\db_2026-09-30_0859) bằng pg_restore -s — KHÔNG dùng bản nháp migration 33
-- ngày 29/08 (đã cũ, làm mất sửa đổi của migration 36–55).
--
-- Đổi tên theo quyết định "không gộp bảng" (29/08): bảng chung_tu → chung_tu_fmb (trùng tên bảng
-- chung_tu của Nhân sự), kèm khóa/chỉ mục/policy chung_tu_* → chung_tu_fmb_*, bucket 'chung-tu' →
-- 'chung-tu-fmb'. Không đổi logic hàm nào (chỉ đổi tên bảng/bucket được nhắc tới).
--
-- KHÔNG có trong file này: dữ liệu (nạp bằng script), lịch pg_cron báo cáo 07:30, secret Telegram
-- (Telegram giữ mã, KHÔNG kích hoạt — quyết định 30/09).
-- Danh mục dùng chung (cong_ty, nhan_vien, du_an, nha_cung_cap, khach_hang…) được chuẩn hoá ở
-- migration 20260930000004.
-- =====================================================================

--
-- PostgreSQL database dump
--



-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: private; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA private;


--
-- Name: SCHEMA private; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA private IS 'Hàm hỗ trợ nội bộ. KHÔNG được thêm schema này vào danh sách API của Supabase (config.toml -> [api] schemas). Mọi thứ trong đây chỉ để RLS và RPC dùng.';


--
-- Name: tien_te; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN public.tien_te AS numeric(18,2);


--
-- Name: DOMAIN tien_te; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON DOMAIN public.tien_te IS 'Kiểu tiền tệ chuẩn của dự án. Luôn dùng domain này cho cột tiền, không dùng float.';


--
-- Name: bat_buoc_vai_tro(text, text); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.bat_buoc_vai_tro(p_vai_tro text, p_ten_viec text) RETURNS void
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
  if not private.co_vai_tro(p_vai_tro) then
    raise exception 'Bạn không có quyền %. Việc này chỉ dành cho vai trò: %.',
      p_ten_viec, p_vai_tro
      using errcode = '42501';
  end if;
end;
$$;


--
-- Name: bi_siet_theo_nguon_tien(); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.bi_siet_theo_nguon_tien() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
  select
    -- Không có phiên (service role, cron, migration, backfill): không có ai để
    -- kiểm quyền, và những lối đó vốn đã toàn quyền.
    --
    -- ĐÂY LÀ DÒNG ĐÃ TỪNG THIẾU VÀ GÂY HỎNG THẬT: mig 34 gắn bộ lọc vào
    -- `v_so_du_nguon_tien` mà không chừa lối này, nên cron daily-report (khoá
    -- service, auth.uid() NULL) đọc ra ĐÚNG 0 DÒNG. Suốt 30/08–07/09 tin Telegram
    -- vẫn in tiêu đề "Số dư hiện tại" rồi bỏ trống bên dưới, cron vẫn báo ok nên
    -- không ai biết. Mọi đường người dùng đều mang JWT nên không lọt nhánh này.
    auth.uid() is not null

    -- Kế toán trưởng / Chủ tịch / Quản trị nhìn toàn cục — họ cần đối chiếu và
    -- duyệt. Cố ý KHÔNG có ke_toan_thanh_toan: đó chính là nhóm cần siết.
    and not private.co_mot_trong_vai_tro(array['ke_toan_truong', 'chu_tich', 'quan_tri'])

    -- CHỐT MỚI 16/09 (đảo chốt 2 của mig 34): chưa được gán nguồn nào thì KHÔNG
    -- bị siết — xem toàn bộ, trong phạm vi quyền vốn có. Danh sách gán là để thu
    -- hẹp tầm nhìn của người giữ quỹ, không phải để mở tầm nhìn cho người khác.
    and exists (
          select 1
          from public.nguon_tien_nhan_vien g
          where g.nhan_vien_id = private.nhan_vien_hien_tai()
        );
$$;


--
-- Name: FUNCTION bi_siet_theo_nguon_tien(); Type: COMMENT; Schema: private; Owner: -
--

COMMENT ON FUNCTION private.bi_siet_theo_nguon_tien() IS 'Người đang đăng nhập có bị giới hạn theo nguồn tiền không (mig 48). Bị siết khi: có phiên đăng nhập, KHÔNG phải KTT/Chủ tịch/Quản trị, VÀ đã được gán ít nhất một nguồn. Chưa gán nguồn nào = không bị siết (chốt 16/09, đảo chốt 2 của mig 34). KHÔNG trả lời câu "có được xem sổ sách tiền không" — đó là private.la_nguoi_quan_ly_tai_chinh().';


--
-- Name: bu_cong_no_am_cho_nguoi(uuid, uuid, uuid, numeric, date, uuid, text); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.bu_cong_no_am_cho_nguoi(p_nguoi_id uuid, p_de_nghi_moi uuid, p_lan_tra_id uuid, p_toi_da numeric, p_ngay date, p_nguoi_tao uuid, p_ly_do text) RETURNS numeric
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_con    numeric := p_toi_da;
  v_bu     numeric;
  v_am     record;
  v_tong   numeric := 0;
begin
  if p_nguoi_id is null or v_con is null or v_con <= 0 then
    return 0;
  end if;

  -- Khoản âm CŨ NHẤT trước: nợ để lâu thì tất toán trước, đúng thứ tự người ta
  -- vẫn làm trên giấy.
  for v_am in
    select c.de_nghi_tam_ung_id, c.con_no
    from public.v_cong_no_tam_ung c
    where c.nhan_vien_nhan_ung_id = p_nguoi_id
      and c.con_no < 0
      and c.de_nghi_tam_ung_id <> p_de_nghi_moi
    order by c.ngay_de_nghi, c.so_de_nghi
  loop
    exit when v_con <= 0;

    v_bu := least(-v_am.con_no, v_con);

    insert into public.bu_cong_no_am (
      de_nghi_am_id, de_nghi_moi_id, lan_tra_tien_id,
      so_tien, ngay, ly_do, nguoi_tao_id)
    values (
      v_am.de_nghi_tam_ung_id, p_de_nghi_moi, p_lan_tra_id,
      v_bu, p_ngay, p_ly_do, p_nguoi_tao);

    v_con  := v_con - v_bu;
    v_tong := v_tong + v_bu;

    -- Khoản âm nay đã về 0 -> đợt quyết toán của nó không còn gì để chi, đóng
    -- lại. Không đóng thì nó treo mãi ở màn Thanh toán, đúng cái kẹt đang gặp.
    update public.dot_duyet dd
    set trang_thai    = 'da_dong',
        ly_do_dong    = 'Công nợ âm đã được bù bằng đợt ứng sau — không cần chi trả bù.',
        nguoi_dong_id = p_nguoi_tao,
        dong_luc      = now()
    from public.de_nghi qt
    where qt.id = dd.de_nghi_id
      and qt.loai = 'quyet_toan'
      and qt.de_nghi_tam_ung_goc_id = v_am.de_nghi_tam_ung_id
      and dd.trang_thai = 'da_duyet';

    perform private.ghi_nhat_ky('bu_cong_no_am', v_am.de_nghi_tam_ung_id, 'bu_cong_no_am',
      jsonb_build_object('con_no_truoc', v_am.con_no),
      jsonb_build_object('so_tien_bu', v_bu, 'de_nghi_moi', p_de_nghi_moi,
                         'lan_tra_tien_id', p_lan_tra_id));
  end loop;

  return v_tong;
end;
$$;


--
-- Name: but_toan_nhap_quy_trung(uuid, numeric, date); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.but_toan_nhap_quy_trung(p_quy_tien_mat_id uuid, p_so_tien numeric, p_ngay date) RETURNS uuid
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
  select b.id
  from public.but_toan_quy_cong_truong b
  where b.loai            = 'nhap'
    and b.quy_tien_mat_id = p_quy_tien_mat_id
    and b.so_tien         = p_so_tien
    and abs(b.ngay - p_ngay) <= 7
  order by abs(b.ngay - p_ngay), b.ngay
  limit 1;
$$;


--
-- Name: FUNCTION but_toan_nhap_quy_trung(p_quy_tien_mat_id uuid, p_so_tien numeric, p_ngay date); Type: COMMENT; Schema: private; Owner: -
--

COMMENT ON FUNCTION private.but_toan_nhap_quy_trung(p_quy_tien_mat_id uuid, p_so_tien numeric, p_ngay date) IS 'Bút toán NHẬP quỹ công trường (mig 42) trùng dấu vết với một khoản thu: cùng quỹ, ĐÚNG số tiền, lệch tối đa 7 ngày. null = không trùng. Nguồn công thức duy nhất cho trigger + RPC gợi ý + view cảnh báo (mig 55).';


--
-- Name: chan_nguon_khong_duoc_phan_quyen(); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.chan_nguon_khong_duoc_phan_quyen() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
  -- Không có phiên người dùng (service role, cron, migration, backfill) thì
  -- không có ai để kiểm — cho qua. Mọi đường người dùng đều mang JWT.
  if auth.uid() is null then
    return new;
  end if;

  -- Phiếu thu chỉ kiểm lúc tiền THẬT vào sổ ('da_thu'). Phiếu NHÁP nộp lại tiền
  -- thừa do người nhận ứng tự lập — thường là nhân viên không được gán nguồn
  -- nào — và Kế toán trưởng mới là người xác nhận. Chặn ở bước nháp là người ta
  -- không nộp tiền về được.
  --
  -- IF lồng chứ không gộp bằng AND: hàm dùng chung cho lan_tra_tien, bảng đó
  -- không có cột trang_thai; PL/pgSQL không hứa đoản mạch nên gộp một dòng là có
  -- lúc báo "record new has no field trang_thai".
  if tg_table_name = 'phieu_thu' then
    if new.trang_thai is distinct from 'da_thu' then
      return new;
    end if;
  end if;

  if not private.duoc_xem_nguon_tien(new.quy_tien_mat_id, new.tai_khoan_ngan_hang_id) then
    raise exception 'Bạn không được phân quyền nguồn tiền này nên không ghi giao dịch vào đó được. Nhờ Quản trị gán thêm (Quản trị → Quỹ quản lý), hoặc để Kế toán trưởng thực hiện.'
      using errcode = '42501';
  end if;

  return new;
end;
$$;


--
-- Name: FUNCTION chan_nguon_khong_duoc_phan_quyen(); Type: COMMENT; Schema: private; Owner: -
--

COMMENT ON FUNCTION private.chan_nguon_khong_duoc_phan_quyen() IS 'Trigger mig 45: chặn ghi lần chi / phiếu thu đã thu vào nguồn tiền người đang đăng nhập không được phân quyền (private.duoc_xem_nguon_tien). KTT / Chủ tịch / Quản trị luôn qua. Không có phiên (service role) thì không kiểm.';


--
-- Name: chan_phieu_thu_trung_nhap_quy(); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.chan_phieu_thu_trung_nhap_quy() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_bt_id  uuid;
  v_quy    text;
  v_ngay   date;
  v_de     text;
  v_nguoi  text;
begin
  -- Chỉ tiền mặt: bút toán quỹ công trường không bao giờ vào tài khoản ngân hàng.
  if new.quy_tien_mat_id is null then
    return new;
  end if;

  -- Phiếu thu NỘP LẠI TIỀN THỪA (gắn tạm ứng gốc) là luồng khác hẳn: nó trừ
  -- công nợ của người nhận ứng, và RPC nộp lại không có đường truyền cờ xác
  -- nhận. Chặn ở đây là khóa luôn lối nộp tiền về mà không có lối thoát nào.
  -- Cũng không mất gì: màn Thu tiền — cửa đã sinh ra hai phiếu trùng của Thái
  -- Nguyên — luôn để trống cột này.
  if new.de_nghi_tam_ung_goc_id is not null then
    return new;
  end if;

  -- Chỉ lúc tiền THẬT vào sổ. Phiếu nháp chưa nằm trong v_so_quy nên chưa cộng
  -- vào số dư — chặn ở bước nháp là người nộp tiền về không lập phiếu được
  -- (cùng lý do mig 45 chừa phiếu nháp).
  if new.trang_thai is distinct from 'da_thu' then
    return new;
  end if;

  -- Người lập đã nhìn cảnh báo và khẳng định là khoản khác.
  if new.xac_nhan_khong_trung_nhap_quy then
    return new;
  end if;

  v_bt_id := private.but_toan_nhap_quy_trung(new.quy_tien_mat_id, new.so_tien, new.ngay_thu);
  if v_bt_id is null then
    return new;
  end if;

  select q.ten, b.ngay, dn.so_de_nghi, nv.ho_ten
    into v_quy, v_ngay, v_de, v_nguoi
  from public.but_toan_quy_cong_truong b
  join public.quy_tien_mat q on q.id = b.quy_tien_mat_id
  join public.de_nghi dn     on dn.id = b.de_nghi_tam_ung_goc_id
  join public.nhan_vien nv   on nv.id = b.nhan_vien_id
  where b.id = v_bt_id;

  -- Câu này người dùng đọc thẳng trên màn hình nên phải nói đủ: trùng với cái
  -- gì, vì sao chặn, và làm gì tiếp. Cố ý KHÔNG chứa chữ "quyền" — lib/rpc.ts
  -- bắt chữ đó để dịch thành lỗi phân quyền.
  raise exception
    '% đã tự nhận % đồng ngày % khi chi tạm ứng % cho %. Từ mig 42 hệ thống nhập quỹ công trường tự động, lập thêm phiếu thu cùng số tiền là quỹ nhận hai lần một khoản tiền. Nếu đây thật sự là khoản tiền KHÁC, tích ô "Đây là khoản tiền khác" rồi lập lại.',
    v_quy, to_char(new.so_tien, 'FM999,999,999,999'), to_char(v_ngay, 'DD/MM/YYYY'), v_de, v_nguoi;
end;
$$;


--
-- Name: FUNCTION chan_phieu_thu_trung_nhap_quy(); Type: COMMENT; Schema: private; Owner: -
--

COMMENT ON FUNCTION private.chan_phieu_thu_trung_nhap_quy() IS 'Trigger mig 55: chặn phiếu thu đã thu vào quỹ tiền mặt khi trùng dấu vết với bút toán nhập quỹ công trường tự động (private.but_toan_nhap_quy_trung). Bỏ qua khi phiếu còn nháp, khi thu vào ngân hàng, hoặc khi người lập đã tích xac_nhan_khong_trung_nhap_quy.';


--
-- Name: chan_sua_khoan_muc_he_thong(); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.chan_sua_khoan_muc_he_thong() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO ''
    AS $$
begin
  if tg_op = 'DELETE' then
    if old.la_he_thong then
      raise exception 'Không thể xóa khoản mục hệ thống "%". Khoản mục này do hệ thống dùng khi quyết toán tạm ứng.', old.ma;
    end if;
    return old;
  end if;

  if old.la_he_thong and new.dang_dung = false then
    raise exception 'Không thể ẩn khoản mục hệ thống "%". Ẩn nó sẽ làm hỏng chức năng quyết toán tạm ứng.', old.ma;
  end if;
  if old.la_he_thong and new.la_he_thong = false then
    raise exception 'Không thể bỏ cờ hệ thống của khoản mục "%".', old.ma;
  end if;
  return new;
end;
$$;


--
-- Name: chan_sua_nhat_ky(); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.chan_sua_nhat_ky() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO ''
    AS $$
begin
  raise exception 'Nhật ký chỉ được ghi thêm, không được sửa hay xóa.';
end;
$$;


--
-- Name: chan_sua_so_quy(); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.chan_sua_so_quy() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO ''
    AS $$
begin
  if coalesce(current_setting('app.admin_dieu_chinh', true), '') = 'on' then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  raise exception 'Sổ quỹ chỉ được ghi thêm, không được sửa hay xóa. Ghi sai thì lập bút toán điều chỉnh ngược dấu.';
end;
$$;


--
-- Name: co_mot_trong_vai_tro(text[]); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.co_mot_trong_vai_tro(p_vai_tro text[]) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
  select exists (
    select 1
    from public.vai_tro_nhan_vien vt
    join public.nhan_vien nv on nv.id = vt.nhan_vien_id
    where nv.user_id = auth.uid()
      and nv.dang_dung
      and vt.vai_tro = any(p_vai_tro)
  );
$$;


--
-- Name: FUNCTION co_mot_trong_vai_tro(p_vai_tro text[]); Type: COMMENT; Schema: private; Owner: -
--

COMMENT ON FUNCTION private.co_mot_trong_vai_tro(p_vai_tro text[]) IS 'Người đang đăng nhập có ít nhất một trong các vai trò không.';


--
-- Name: co_tab(text); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.co_tab(p_duong_dan text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
  select exists (
    select 1
    from public.menu_nhan_vien m
    where m.nhan_vien_id = private.nhan_vien_hien_tai()
      and m.duong_dan = p_duong_dan
  );
$$;


--
-- Name: FUNCTION co_tab(p_duong_dan text); Type: COMMENT; Schema: private; Owner: -
--

COMMENT ON FUNCTION private.co_tab(p_duong_dan text) IS 'Tài khoản đang đăng nhập có được tick tab p_duong_dan không (bảng menu_nhan_vien, mig 29). Dùng trong policy — xem private.duoc_sua_danh_muc().';


--
-- Name: co_vai_tro(text); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.co_vai_tro(p_vai_tro text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
  select exists (
    select 1
    from public.vai_tro_nhan_vien vt
    join public.nhan_vien nv on nv.id = vt.nhan_vien_id
    where nv.user_id = auth.uid()
      and nv.dang_dung
      and vt.vai_tro = p_vai_tro
  );
$$;


--
-- Name: FUNCTION co_vai_tro(p_vai_tro text); Type: COMMENT; Schema: private; Owner: -
--

COMMENT ON FUNCTION private.co_vai_tro(p_vai_tro text) IS 'Người đang đăng nhập có vai trò p_vai_tro không. Dùng trong mọi policy RLS và mọi RPC.';


--
-- Name: con_phai_chi_that(uuid); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.con_phai_chi_that(p_dot_id uuid) RETURNS numeric
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
  select case
           when dn.loai = 'quyet_toan' and dn.de_nghi_tam_ung_goc_id is not null
             then 0::numeric
           else coalesce(v.so_tien_con_phai_tra, 0)
         end
  from public.v_dot_duyet_tong_hop v
  join public.de_nghi dn on dn.id = v.de_nghi_id
  where v.dot_duyet_id = p_dot_id;
$$;


--
-- Name: FUNCTION con_phai_chi_that(p_dot_id uuid); Type: COMMENT; Schema: private; Owner: -
--

COMMENT ON FUNCTION private.con_phai_chi_that(p_dot_id uuid) IS 'Đợt này hệ thống ĐÒI chi bao nhiêu (mig 53, sửa mig 54). Đợt thường = số còn phải trả. Đợt quyết toán = 0 LUÔN: trong hạn mức thì đã đối trừ, vượt hạn mức thì chờ đợt ứng sau đối trừ (chốt 19/09). Số KTTT ĐƯỢC PHÉP trả bù tay là private.tra_bu_toi_da().';


--
-- Name: dong_quyet_toan_da_can_doi(uuid, uuid); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.dong_quyet_toan_da_can_doi(p_dot_id uuid, p_nguoi_id uuid DEFAULT NULL::uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_tt   text;
  v_ct   uuid;
  v_loai text;
  v_goc  uuid;
  v_du   numeric;
begin
  select dd.trang_thai::text, dd.chu_tich_id, dn.loai::text, dn.de_nghi_tam_ung_goc_id
    into v_tt, v_ct, v_loai, v_goc
  from public.dot_duyet dd
  join public.de_nghi dn on dn.id = dd.de_nghi_id
  where dd.id = p_dot_id;

  if not found then return false; end if;
  if v_tt <> 'da_duyet' then return false; end if;
  if v_loai <> 'quyet_toan' or v_goc is null then return false; end if;

  v_du := private.so_du_han_muc_quyet_toan(v_goc);
  if v_du is null or v_du < 0 then return false; end if;

  -- Ràng buộc dong_phai_co_ly_do đòi nguoi_dong_id khác NULL. Ba lớp dự phòng:
  -- người gọi truyền vào -> phiên đăng nhập -> Chủ tịch đã duyệt đợt (lớp cuối
  -- cho lượt quét của migration, chạy bằng khóa hệ thống nên không có phiên).
  -- chu_tich_id chắc chắn khác NULL vì ràng buộc chu_tich_co_dau_vet bắt buộc thế
  -- với mọi đợt 'da_duyet'.
  update public.dot_duyet
  set trang_thai    = 'da_dong',
      ly_do_dong    = 'Quyết toán đã đối trừ vào hạn mức tạm ứng đã duyệt — không cần chi trả bù.',
      nguoi_dong_id = coalesce(p_nguoi_id, private.nhan_vien_hien_tai(), v_ct),
      dong_luc      = now()
  where id = p_dot_id;

  perform private.ghi_nhat_ky('dot_duyet', p_dot_id, 'tu_dong_dong_quyet_toan',
    null, jsonb_build_object('so_du_han_muc', v_du, 'nguon', 'mig 54'));

  return true;
end;
$$;


--
-- Name: FUNCTION dong_quyet_toan_da_can_doi(p_dot_id uuid, p_nguoi_id uuid); Type: COMMENT; Schema: private; Owner: -
--

COMMENT ON FUNCTION private.dong_quyet_toan_da_can_doi(p_dot_id uuid, p_nguoi_id uuid) IS 'Đóng đợt quyết toán khi số dư HẠN MỨC TẠM ỨNG ĐÃ DUYỆT còn >= 0 (mig 54, trước đó mig 53 hỏi công nợ tiền đã chi). Số dư âm thì cố ý KHÔNG đóng: giữ đợt mở để KTTT trả bù tay, hoặc để mig 43 bù bằng đợt ứng sau. Idempotent.';


--
-- Name: duoc_sua_danh_muc(); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.duoc_sua_danh_muc() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
  select private.co_mot_trong_vai_tro(array['ke_toan_truong', 'quan_tri'])
      or private.co_tab('/danh-muc');
$$;


--
-- Name: FUNCTION duoc_sua_danh_muc(); Type: COMMENT; Schema: private; Owner: -
--

COMMENT ON FUNCTION private.duoc_sua_danh_muc() IS 'Ai được THÊM/SỬA danh mục: Kế toán trưởng, Quản trị, HOẶC tài khoản được admin mở tab /danh-muc (mig 32). Vai trò là nền, tab là cộng thêm.';


--
-- Name: duoc_xem_de_nghi(uuid); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.duoc_xem_de_nghi(p_de_nghi_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
  select
    private.la_nguoi_quan_ly_tai_chinh()
    or exists (
      select 1
      from public.de_nghi dn
      where dn.id = p_de_nghi_id
        and dn.nguoi_de_xuat_id = private.nhan_vien_hien_tai()
    );
$$;


--
-- Name: FUNCTION duoc_xem_de_nghi(p_de_nghi_id uuid); Type: COMMENT; Schema: private; Owner: -
--

COMMENT ON FUNCTION private.duoc_xem_de_nghi(p_de_nghi_id uuid) IS 'Người đang đăng nhập có được xem đề nghị này không: người quản lý tài chính xem tất, nhân viên chỉ xem của mình.';


--
-- Name: duoc_xem_file(text); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.duoc_xem_file(p_duong_dan text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
  select exists (
    select 1
    from public.chung_tu_fmb ct
    where ct.duong_dan = p_duong_dan
      and (
        (ct.de_nghi_id is not null and private.duoc_xem_de_nghi(ct.de_nghi_id))

        or (ct.lan_tra_tien_id is not null and exists (
          select 1
          from public.lan_tra_tien ltt
          join public.dot_duyet dd on dd.id = ltt.dot_duyet_id
          where ltt.id = ct.lan_tra_tien_id
            and private.duoc_xem_de_nghi(dd.de_nghi_id)
        ))

        or (ct.phieu_thu_id is not null and private.la_nguoi_quan_ly_tai_chinh())

        -- Chứng từ chuyển quỹ (giấy nộp tiền): chỉ người quản lý tài chính.
        or (ct.chuyen_quy_id is not null and private.la_nguoi_quan_ly_tai_chinh())
      )
  );
$$;


--
-- Name: FUNCTION duoc_xem_file(p_duong_dan text); Type: COMMENT; Schema: private; Owner: -
--

COMMENT ON FUNCTION private.duoc_xem_file(p_duong_dan text) IS 'File này người đang đăng nhập có xem được không — xét theo bản ghi chung_tu_fmb trỏ vào nó, KHÔNG xét theo đường dẫn.';


--
-- Name: duoc_xem_nguon_tien(uuid, uuid); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.duoc_xem_nguon_tien(p_quy_id uuid, p_tk_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
  select not private.bi_siet_theo_nguon_tien()
      or exists (
           select 1
           from public.nguon_tien_nhan_vien g
           where g.nhan_vien_id = private.nhan_vien_hien_tai()
             and (
               (p_quy_id is not null and g.quy_tien_mat_id = p_quy_id)
               or (p_tk_id is not null and g.tai_khoan_ngan_hang_id = p_tk_id)
             )
         );
$$;


--
-- Name: FUNCTION duoc_xem_nguon_tien(p_quy_id uuid, p_tk_id uuid); Type: COMMENT; Schema: private; Owner: -
--

COMMENT ON FUNCTION private.duoc_xem_nguon_tien(p_quy_id uuid, p_tk_id uuid) IS 'Người đang đăng nhập có được xem nguồn tiền này không (truyền đúng một trong hai id). Không bị siết (private.bi_siet_theo_nguon_tien) thì được tất; bị siết thì phải có dòng gán trong nguon_tien_nhan_vien. Sửa mig 48: chưa gán nguồn nào giờ là XEM TOÀN BỘ, trước đây là không xem được gì.';


--
-- Name: file_da_gan_chung_tu(text); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.file_da_gan_chung_tu(p_duong_dan text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
  select exists (select 1 from public.chung_tu_fmb ct where ct.duong_dan = p_duong_dan);
$$;


--
-- Name: ghi_chi_quy_cong_truong(uuid, uuid); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.ghi_chi_quy_cong_truong(p_dot_id uuid, p_nguoi_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_loai   text;
  v_goc    uuid;
  v_nguoi  uuid;
  v_so_dn  text;
  v_quy    uuid;
  v_tong   numeric;
  v_bt_id  uuid;
begin
  select dn.loai, dn.de_nghi_tam_ung_goc_id
  into v_loai, v_goc
  from public.dot_duyet dd
  join public.de_nghi dn on dn.id = dd.de_nghi_id
  where dd.id = p_dot_id;

  if v_loai is distinct from 'quyet_toan' or v_goc is null then
    return;
  end if;

  select dn.nhan_vien_nhan_ung_id, dn.so_de_nghi
  into v_nguoi, v_so_dn
  from public.de_nghi dn where dn.id = v_goc;

  v_quy := private.quy_cua_nguoi_nhan_ung(v_nguoi);
  if v_quy is null then
    return;   -- người không quản lý quỹ nào: giữ nguyên luồng cũ
  end if;

  -- Số tiền = TỔNG BẢNG KÊ của đợt vừa duyệt, tức đúng số chi phí đợt này chốt.
  -- Cố ý không lấy theo công nợ: công nợ là hiệu của nhiều đợt, lấy nó thì đợt
  -- thứ hai trở đi sẽ ghi thiếu.
  select coalesce(sum(m.so_tien), 0)
  into v_tong
  from public.muc_de_nghi m
  where m.dot_duyet_id = p_dot_id
    and m.tu_choi_luc is null;

  if v_tong <= 0 then
    return;
  end if;

  -- KHÔNG kiểm số dư quỹ: chủ dự án chốt "chi quá sẽ giảm vào dư quỹ, không đủ
  -- tiền sẽ ghi âm để trừ vào tiền ứng kỳ sau". Quỹ âm ở đây là con số nghiệp vụ
  -- có nghĩa — công ty đang nợ lại người giữ quỹ — chứ không phải lỗi dữ liệu.
  insert into public.but_toan_quy_cong_truong (
    loai, quy_tien_mat_id, nhan_vien_id, de_nghi_tam_ung_goc_id,
    dot_duyet_id, so_tien, ngay, dien_giai, nguoi_tao_id
  )
  values (
    'chi', v_quy, v_nguoi, v_goc,
    p_dot_id, v_tong, current_date,
    'Chi từ quỹ công trường — quyết toán ' || coalesce(v_so_dn, ''), p_nguoi_id
  )
  on conflict (dot_duyet_id) where dot_duyet_id is not null do nothing
  returning id into v_bt_id;

  -- Conflict (đã ghi rồi) thì returning không trả dòng nào -> không ghi nhật ký
  -- lần hai. Nhật ký lặp lại làm người đọc tưởng tiền ra khỏi quỹ hai lần.
  if v_bt_id is not null then
    perform private.ghi_nhat_ky('but_toan_quy_cong_truong', v_bt_id, 'chi_quy_cong_truong',
      null, jsonb_build_object('quy_tien_mat_id', v_quy, 'so_tien', v_tong,
                               'dot_duyet_id', p_dot_id, 'de_nghi_tam_ung_goc', v_so_dn));
  end if;
end;
$$;


--
-- Name: ghi_nhat_ky(text, uuid, text, jsonb, jsonb); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.ghi_nhat_ky(p_bang text, p_ban_ghi_id uuid, p_hanh_dong text, p_gia_tri_cu jsonb DEFAULT NULL::jsonb, p_gia_tri_moi jsonb DEFAULT NULL::jsonb) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
  insert into public.nhat_ky (
    bang, ban_ghi_id, hanh_dong, gia_tri_cu, gia_tri_moi, nguoi_thuc_hien_id
  )
  values (
    p_bang, p_ban_ghi_id, p_hanh_dong, p_gia_tri_cu, p_gia_tri_moi,
    private.nhan_vien_hien_tai()
  );
end;
$$;


--
-- Name: FUNCTION ghi_nhat_ky(p_bang text, p_ban_ghi_id uuid, p_hanh_dong text, p_gia_tri_cu jsonb, p_gia_tri_moi jsonb); Type: COMMENT; Schema: private; Owner: -
--

COMMENT ON FUNCTION private.ghi_nhat_ky(p_bang text, p_ban_ghi_id uuid, p_hanh_dong text, p_gia_tri_cu jsonb, p_gia_tri_moi jsonb) IS 'Ghi một dòng nhật ký. Người thực hiện luôn lấy từ phiên đăng nhập, không nhận từ tham số.';


--
-- Name: han_muc_tam_ung_da_duyet(uuid); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.han_muc_tam_ung_da_duyet(p_de_nghi_id uuid) RETURNS numeric
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
  select coalesce(sum(m.so_tien), 0)
  from public.muc_de_nghi m
  join public.dot_duyet dd on dd.id = m.dot_duyet_id
  where m.de_nghi_id = p_de_nghi_id
    and dd.trang_thai in ('da_duyet', 'da_dong');
$$;


--
-- Name: FUNCTION han_muc_tam_ung_da_duyet(p_de_nghi_id uuid); Type: COMMENT; Schema: private; Owner: -
--

COMMENT ON FUNCTION private.han_muc_tam_ung_da_duyet(p_de_nghi_id uuid) IS 'Tổng tiền tạm ứng ĐÃ DUYỆT của một đề nghị tạm ứng (mig 54). Chỉ mục thuộc đợt da_duyet/da_dong — khớp đúng cách v_cong_no_tam_ung tính da_quyet_toan. KHÁC da_ung: da_ung là tiền đã CHI THẬT.';


--
-- Name: la_nguoi_quan_ly_tai_chinh(); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.la_nguoi_quan_ly_tai_chinh() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
  select private.co_mot_trong_vai_tro(array[
    'ke_toan_truong', 'chu_tich', 'ke_toan_thanh_toan', 'quan_tri'
  ]);
$$;


--
-- Name: FUNCTION la_nguoi_quan_ly_tai_chinh(); Type: COMMENT; Schema: private; Owner: -
--

COMMENT ON FUNCTION private.la_nguoi_quan_ly_tai_chinh() IS 'KTT / Chủ tịch / KT thanh toán / Quản trị — nhóm được xem toàn bộ đề nghị và sổ sách.';


--
-- Name: ma_danh_muc_tiep_theo(text, text); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.ma_danh_muc_tiep_theo(p_bang text, p_tien_to text) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
declare
  v_so int;
begin
  -- Khóa theo bảng tới hết transaction: hai người thêm cùng lúc không lấy trùng số.
  perform pg_advisory_xact_lock(hashtext('ma_danh_muc:' || p_bang));

  execute format(
    'select coalesce(max(substring(ma from %s)::int), 0) + 1 from public.%I where ma ~ %L',
    length(p_tien_to) + 1, p_bang, '^' || p_tien_to || '[0-9]+$')
  into v_so;

  return p_tien_to || lpad(v_so::text, greatest(3, length(v_so::text)), '0');
end;
$_$;


--
-- Name: mo_ta_giao_dich(text, jsonb); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.mo_ta_giao_dich(p_loai text, p_snap jsonb) RETURNS text
    LANGUAGE sql IMMUTABLE
    SET search_path TO ''
    AS $$
  select case p_loai
    when 'phieu_chi'       then 'Phiếu chi ngày ' || coalesce(p_snap->>'ngay_tra', '?')
    when 'phieu_thu'       then 'Phiếu thu ' || coalesce(p_snap->>'so_phieu', p_snap->>'ngay_thu', '?')
    when 'lich_su'         then coalesce(p_snap->>'noi_dung', 'Giao dịch lịch sử')
    when 'ton_dau_ky'      then 'Tồn đầu kỳ ngày ' || coalesce(p_snap->>'ngay', '?')
    when 'chuyen_quy'      then 'Chuyển quỹ ' || coalesce(p_snap->>'so_phieu', p_snap->>'ngay', '?')
    when 'quy_cong_truong' then coalesce(p_snap->>'dien_giai', 'Bút toán quỹ công trường')
    else p_loai
  end;
$$;


--
-- Name: nhan_vien_hien_tai(); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.nhan_vien_hien_tai() RETURNS uuid
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
  select nv.id
  from public.nhan_vien nv
  where nv.user_id = auth.uid()
    and nv.dang_dung
  limit 1;
$$;


--
-- Name: FUNCTION nhan_vien_hien_tai(); Type: COMMENT; Schema: private; Owner: -
--

COMMENT ON FUNCTION private.nhan_vien_hien_tai() IS 'Trả về nhan_vien.id của người đang đăng nhập. NULL nếu chưa đăng nhập hoặc tài khoản chưa nối nhân viên. Nhân viên bị ẩn (dang_dung=false) coi như không có quyền gì.';


--
-- Name: quy_cua_nguoi_nhan_ung(uuid); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.quy_cua_nguoi_nhan_ung(p_nhan_vien_id uuid) RETURNS uuid
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_ids uuid[];
begin
  if p_nhan_vien_id is null then return null; end if;

  select array_agg(g.quy_tien_mat_id)
  into v_ids
  from public.nguon_tien_nhan_vien g
  where g.nhan_vien_id = p_nhan_vien_id
    and g.quy_tien_mat_id is not null;

  if v_ids is null or array_length(v_ids, 1) = 0 then
    return null;
  end if;

  if array_length(v_ids, 1) > 1 then
    raise exception 'Người nhận ứng đang được gán % quỹ tiền mặt nên không xác định được nhập tiền vào quỹ nào. Vào Quản trị → Quỹ quản lý, để lại đúng một quỹ cho người này.',
      array_length(v_ids, 1);
  end if;

  return v_ids[1];
end;
$$;


--
-- Name: sinh_so_de_nghi(text, text, integer); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.sinh_so_de_nghi(p_loai text, p_ma_cong_ty text, p_nam integer) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_so int;
  v_tien_to text;
begin
  v_tien_to := case p_loai
    when 'thanh_toan' then 'DNTT'
    when 'tam_ung'    then 'DNTU'
    when 'quyet_toan' then 'QT'
    when 'phieu_thu'  then 'PT'
    when 'chuyen_quy' then 'CQ'
    else null
  end;

  if v_tien_to is null then
    raise exception 'Loại chứng từ không hợp lệ: %', p_loai;
  end if;

  insert into public.so_thu_tu_de_nghi (loai, ma_cong_ty, nam, so_cuoi)
  values (p_loai, p_ma_cong_ty, p_nam, 1)
  on conflict (loai, ma_cong_ty, nam)
    do update set so_cuoi = public.so_thu_tu_de_nghi.so_cuoi + 1
  returning so_cuoi into v_so;

  return v_tien_to || '-' || p_ma_cong_ty || '-' || p_nam::text || '-' || lpad(v_so::text, 4, '0');
end;
$$;


--
-- Name: FUNCTION sinh_so_de_nghi(p_loai text, p_ma_cong_ty text, p_nam integer); Type: COMMENT; Schema: private; Owner: -
--

COMMENT ON FUNCTION private.sinh_so_de_nghi(p_loai text, p_ma_cong_ty text, p_nam integer) IS 'Sinh số chứng từ dạng DNTT-BV-2026-0087. Chống trùng bằng INSERT..ON CONFLICT..RETURNING.';


--
-- Name: snapshot_va_xoa_giao_dich(text, uuid); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.snapshot_va_xoa_giao_dich(p_loai text, p_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_snap jsonb;
begin
  perform set_config('app.admin_dieu_chinh', 'on', true);  -- cờ qua trigger (local)

  if p_loai = 'phieu_chi' then
    select to_jsonb(ltt) into v_snap from public.lan_tra_tien ltt where id = p_id;
    if v_snap is null then raise exception 'Không tìm thấy phiếu chi.'; end if;
    v_snap := v_snap || jsonb_build_object(
      'chi_tiet', (select coalesce(jsonb_agg(to_jsonb(c)), '[]'::jsonb)
                   from public.chi_tiet_lan_tra c where c.lan_tra_tien_id = p_id),
      'chung_tu_fmb', (select coalesce(jsonb_agg(to_jsonb(ct)), '[]'::jsonb)
                   from public.chung_tu_fmb ct where ct.lan_tra_tien_id = p_id),
      -- Bút toán nhập quỹ công trường sinh kèm lần trả này (mig 42) phải đi theo:
      -- xóa phiếu chi mà để lại vế nhập là quỹ công trường tự dôi ra một khoản.
      'quy_cong_truong', (select coalesce(jsonb_agg(to_jsonb(b)), '[]'::jsonb)
                          from public.but_toan_quy_cong_truong b where b.lan_tra_tien_id = p_id));
    delete from public.but_toan_quy_cong_truong where lan_tra_tien_id = p_id;
    delete from public.chung_tu_fmb         where lan_tra_tien_id = p_id;
    delete from public.chi_tiet_lan_tra where lan_tra_tien_id = p_id;
    delete from public.lan_tra_tien     where id = p_id;

  elsif p_loai = 'phieu_thu' then
    select to_jsonb(pt) into v_snap from public.phieu_thu pt where id = p_id;
    if v_snap is null then raise exception 'Không tìm thấy phiếu thu.'; end if;
    v_snap := v_snap || jsonb_build_object(
      'chung_tu_fmb', (select coalesce(jsonb_agg(to_jsonb(ct)), '[]'::jsonb)
                   from public.chung_tu_fmb ct where ct.phieu_thu_id = p_id));
    delete from public.chung_tu_fmb  where phieu_thu_id = p_id;
    delete from public.phieu_thu where id = p_id;

  elsif p_loai = 'lich_su' then
    select to_jsonb(g) into v_snap from public.giao_dich_lich_su g where id = p_id;
    if v_snap is null then raise exception 'Không tìm thấy giao dịch lịch sử.'; end if;
    delete from public.giao_dich_lich_su where id = p_id;

  elsif p_loai = 'ton_dau_ky' then
    select to_jsonb(t) into v_snap from public.ton_dau_ky t where id = p_id;
    if v_snap is null then raise exception 'Không tìm thấy tồn đầu kỳ.'; end if;
    delete from public.ton_dau_ky where id = p_id;

  elsif p_loai = 'chuyen_quy' then
    select to_jsonb(cq) into v_snap from public.chuyen_quy cq where id = p_id;
    if v_snap is null then raise exception 'Không tìm thấy lệnh chuyển quỹ.'; end if;
    v_snap := v_snap || jsonb_build_object(
      'chung_tu_fmb', (select coalesce(jsonb_agg(to_jsonb(ct)), '[]'::jsonb)
                   from public.chung_tu_fmb ct where ct.chuyen_quy_id = p_id));
    delete from public.chung_tu_fmb   where chuyen_quy_id = p_id;
    delete from public.chuyen_quy where id = p_id;

  elsif p_loai = 'quy_cong_truong' then
    select to_jsonb(b) into v_snap from public.but_toan_quy_cong_truong b where id = p_id;
    if v_snap is null then raise exception 'Không tìm thấy bút toán quỹ công trường.'; end if;
    delete from public.but_toan_quy_cong_truong where id = p_id;

  else
    raise exception 'Loại giao dịch không hợp lệ: %', p_loai;
  end if;

  -- TẮT CỜ NGAY (mig 41): phạm vi nới lỏng trigger đúng bằng thân hàm này.
  perform set_config('app.admin_dieu_chinh', '', true);

  return v_snap;
end;
$$;


--
-- Name: so_du_han_muc_quyet_toan(uuid); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.so_du_han_muc_quyet_toan(p_de_nghi_tam_ung_id uuid) RETURNS numeric
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
  select private.han_muc_tam_ung_da_duyet(p_de_nghi_tam_ung_id)
       - coalesce((select cn.da_quyet_toan
                   from public.v_cong_no_tam_ung cn
                   where cn.de_nghi_tam_ung_id = p_de_nghi_tam_ung_id), 0);
$$;


--
-- Name: FUNCTION so_du_han_muc_quyet_toan(p_de_nghi_tam_ung_id uuid); Type: COMMENT; Schema: private; Owner: -
--

COMMENT ON FUNCTION private.so_du_han_muc_quyet_toan(p_de_nghi_tam_ung_id uuid) IS 'Hạn mức tạm ứng đã duyệt − đã quyết toán (mig 54). Dương = quyết toán còn nằm trong hạn mức, đối trừ xong, không phải chi tiền. Âm = chi vượt hạn mức, phần vượt chờ đợt ứng sau đối trừ (mig 43) hoặc KTTT trả bù tay.';


--
-- Name: so_du_nguon_tien(uuid, uuid); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.so_du_nguon_tien(p_quy_id uuid, p_tk_id uuid) RETURNS numeric
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
  select coalesce(sum(sq.tien_vao), 0) - coalesce(sum(sq.tien_ra), 0)
  from public.v_so_quy sq
  where (p_quy_id is not null and sq.quy_tien_mat_id = p_quy_id)
     or (p_tk_id  is not null and sq.tai_khoan_ngan_hang_id = p_tk_id);
$$;


--
-- Name: FUNCTION so_du_nguon_tien(p_quy_id uuid, p_tk_id uuid); Type: COMMENT; Schema: private; Owner: -
--

COMMENT ON FUNCTION private.so_du_nguon_tien(p_quy_id uuid, p_tk_id uuid) IS 'Số dư hiện tại của một nguồn tiền, tính từ sổ quỹ. Dùng trong tra_tien_dot để chặn chi âm.';


--
-- Name: sua_so_tien_phieu_chi(uuid, jsonb); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.sua_so_tien_phieu_chi(p_ltt_id uuid, p_chi_tiet jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_loai     text;
  v_so_dn    text;
  v_cu       jsonb;
  v_so_dong  int;
  v_tong_cu  numeric;
  v_tong_moi numeric := 0;
  v_item     jsonb;
  v_dong     record;
  v_so_moi   numeric;
  v_tran     numeric;
  v_da_bu    numeric;
begin
  if p_chi_tiet is null or jsonb_typeof(p_chi_tiet) <> 'array'
     or jsonb_array_length(p_chi_tiet) = 0 then
    raise exception 'Không có dòng chi tiết nào để sửa số tiền.';
  end if;

  -- Khóa phiếu: hai người sửa cùng lúc thì người sau đọc số người trước đã sửa.
  perform 1 from public.lan_tra_tien where id = p_ltt_id for update;
  if not found then
    raise exception 'Không tìm thấy phiếu chi.';
  end if;

  select dn.loai, dn.so_de_nghi into v_loai, v_so_dn
  from public.lan_tra_tien ltt
  join public.dot_duyet dd on dd.id = ltt.dot_duyet_id
  join public.de_nghi dn   on dn.id = dd.de_nghi_id
  where ltt.id = p_ltt_id;

  if v_loai = 'quyet_toan' then
    raise exception 'Không sửa được số tiền phiếu chi TRẢ BÙ quyết toán (%) — số này quyết định đợt quyết toán đóng hay mở. Hãy hủy phiếu rồi lập lại lần trả bù cho đúng.',
      v_so_dn;
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
           'id', c.id, 'muc_de_nghi_id', c.muc_de_nghi_id, 'so_tien', c.so_tien)
           order by c.id), '[]'::jsonb),
         count(*),
         coalesce(sum(c.so_tien), 0)
  into v_cu, v_so_dong, v_tong_cu
  from public.chi_tiet_lan_tra c
  where c.lan_tra_tien_id = p_ltt_id;

  -- Phải gửi ĐỦ và KHÔNG TRÙNG mọi dòng: tổng phiếu cộng từ đúng các dòng này.
  -- Thiếu một dòng mà vẫn cho qua thì tổng phiếu và tổng chi tiết lệch nhau.
  if jsonb_array_length(p_chi_tiet) <> v_so_dong
     or (select count(distinct x->>'id') from jsonb_array_elements(p_chi_tiet) x) <> v_so_dong then
    raise exception 'Phải gửi đủ % dòng chi tiết của phiếu chi, mỗi dòng một lần. Vui lòng tải lại trang.',
      v_so_dong;
  end if;

  for v_item in select * from jsonb_array_elements(p_chi_tiet)
  loop
    select c.id, c.so_tien, m.dien_giai, v.so_tien_con_no
    into v_dong
    from public.chi_tiet_lan_tra c
    join public.muc_de_nghi m    on m.id = c.muc_de_nghi_id
    join public.v_muc_tong_hop v on v.muc_id = c.muc_de_nghi_id
    where c.id = (v_item->>'id')::uuid
      and c.lan_tra_tien_id = p_ltt_id;

    if not found then
      raise exception 'Có dòng chi tiết không thuộc phiếu chi này. Vui lòng tải lại trang.';
    end if;

    v_so_moi := (v_item->>'so_tien')::numeric;
    if v_so_moi is null or v_so_moi <= 0 then
      raise exception 'Mục "%": số tiền phải lớn hơn 0. Muốn bỏ hẳn khoản này thì hủy phiếu chi.',
        v_dong.dien_giai;
    end if;

    -- Trần = phần mục còn nợ + chính số dòng này đang giữ: bỏ dòng này ra thì mục
    -- còn được trả tối đa bao nhiêu. Tính lại ở MỖI vòng (view đọc số đã sửa của
    -- vòng trước), nên hai dòng cùng một mục cũng không lọt trần.
    v_tran := v_dong.so_tien_con_no + v_dong.so_tien;
    if v_so_moi > v_tran then
      raise exception 'Mục "%": sửa thành % đ nhưng mục chỉ được trả tối đa % đ (số đã duyệt trừ các lần trả khác). Không được chi vượt số đã duyệt.',
        v_dong.dien_giai, v_so_moi, v_tran;
    end if;

    update public.chi_tiet_lan_tra set so_tien = v_so_moi where id = v_dong.id;
    v_tong_moi := v_tong_moi + v_so_moi;
  end loop;

  update public.lan_tra_tien set so_tien = v_tong_moi where id = p_ltt_id;

  -- Vế NHẬP quỹ công trường (mig 42) luôn bằng đúng số chi của lần trả sinh ra nó.
  update public.but_toan_quy_cong_truong
  set so_tien = v_tong_moi
  where lan_tra_tien_id = p_ltt_id
    and loai = 'nhap';

  select coalesce(sum(b.so_tien), 0) into v_da_bu
  from public.bu_cong_no_am b
  where b.lan_tra_tien_id = p_ltt_id;

  if v_tong_moi < v_da_bu then
    raise exception 'Phiếu chi này đã dùng % đ để bù khoản ứng âm trước đó — không sửa xuống dưới số đó được. Hãy hủy phiếu rồi lập lại.',
      v_da_bu;
  end if;

  return jsonb_build_object(
    'tong_cu',      v_tong_cu,
    'tong_moi',     v_tong_moi,
    'chi_tiet_cu',  v_cu,
    'chi_tiet_moi', (select jsonb_agg(jsonb_build_object(
                       'id', c.id, 'muc_de_nghi_id', c.muc_de_nghi_id, 'so_tien', c.so_tien)
                       order by c.id)
                     from public.chi_tiet_lan_tra c
                     where c.lan_tra_tien_id = p_ltt_id));
end;
$$;


--
-- Name: FUNCTION sua_so_tien_phieu_chi(p_ltt_id uuid, p_chi_tiet jsonb); Type: COMMENT; Schema: private; Owner: -
--

COMMENT ON FUNCTION private.sua_so_tien_phieu_chi(p_ltt_id uuid, p_chi_tiet jsonb) IS 'Sửa số tiền phiếu chi theo từng dòng chi tiết; tự cộng tổng phiếu, kéo theo vế nhập quỹ công trường (mig 42), chặn vượt số duyệt / trả bù quyết toán / xuống dưới phần đã bù công nợ âm (mig 43). Chỉ admin_sua_giao_dich gọi, khi cờ admin_dieu_chinh đang bật — mig 47.';


--
-- Name: tg_ma_danh_muc(); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.tg_ma_danh_muc() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
begin
  if tg_op = 'INSERT' then
    new.ma := private.ma_danh_muc_tiep_theo(tg_table_name, tg_argv[0]);
  elsif new.ma is distinct from old.ma
        and coalesce(current_setting('app.danh_lai_ma', true), '') <> 'on' then
    raise exception 'Mã "%" do hệ thống tự sinh, không sửa được.', old.ma;
  end if;
  return new;
end;
$$;


--
-- Name: tg_xet_lai_quyet_toan_sau_tra_tien(); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.tg_xet_lai_quyet_toan_sau_tra_tien() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_de_nghi uuid;
  v_dot     uuid;
  v_toi     uuid := private.nhan_vien_hien_tai();
begin
  perform private.dong_quyet_toan_da_can_doi(new.dot_duyet_id, v_toi);

  select dd.de_nghi_id into v_de_nghi
  from public.dot_duyet dd where dd.id = new.dot_duyet_id;

  for v_dot in
    select dd2.id
    from public.dot_duyet dd2
    join public.de_nghi qt on qt.id = dd2.de_nghi_id
    where qt.loai = 'quyet_toan'
      and qt.de_nghi_tam_ung_goc_id = v_de_nghi
      and dd2.trang_thai = 'da_duyet'
  loop
    perform private.dong_quyet_toan_da_can_doi(v_dot, v_toi);
  end loop;

  return null;
end;
$$;


--
-- Name: tra_bu_toi_da(uuid); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.tra_bu_toi_da(p_dot_id uuid) RETURNS numeric
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
  select case
           when dn.loai = 'quyet_toan' and dn.de_nghi_tam_ung_goc_id is not null
             then least(
                    greatest(0, -private.so_du_han_muc_quyet_toan(dn.de_nghi_tam_ung_goc_id)),
                    coalesce(v.so_tien_con_phai_tra, 0)
                  )
           else coalesce(v.so_tien_con_phai_tra, 0)
         end
  from public.v_dot_duyet_tong_hop v
  join public.de_nghi dn on dn.id = v.de_nghi_id
  where v.dot_duyet_id = p_dot_id;
$$;


--
-- Name: FUNCTION tra_bu_toi_da(p_dot_id uuid); Type: COMMENT; Schema: private; Owner: -
--

COMMENT ON FUNCTION private.tra_bu_toi_da(p_dot_id uuid) IS 'Số tiền KTTT ĐƯỢC PHÉP trả cho đợt này nếu chủ động chọn trả (mig 54). Đợt quyết toán = phần chi VƯỢT hạn mức đã duyệt, chặn trên bởi số còn phải trả của đợt (QĐ-08). Hệ thống KHÔNG đòi số này — xem private.con_phai_chi_that().';


--
-- Name: tu_dong_cap_nhat_updated_at(); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.tu_dong_cap_nhat_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO ''
    AS $$
begin
  new.updated_at := now();
  return new;
end;
$$;


--
-- Name: FUNCTION tu_dong_cap_nhat_updated_at(); Type: COMMENT; Schema: private; Owner: -
--

COMMENT ON FUNCTION private.tu_dong_cap_nhat_updated_at() IS 'Trigger function: tự đặt updated_at = now() mỗi lần UPDATE.';


--
-- Name: vuong_mac_nhan_vien(uuid); Type: FUNCTION; Schema: private; Owner: -
--

CREATE FUNCTION private.vuong_mac_nhan_vien(p_id uuid) RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
  select coalesce(jsonb_agg(jsonb_build_object('ten', ten, 'so_luong', sl) order by ten), '[]'::jsonb)
  from (
    -- Sổ sách nghiệp vụ: còn một dòng là còn "đã phát sinh giao dịch".
    select 'Đề nghị (người đề xuất / nhận ứng / người lập)' as ten,
           count(*) as sl
      from public.de_nghi
     where nguoi_de_xuat_id = p_id or nhan_vien_nhan_ung_id = p_id or nguoi_tao_id = p_id
    union all
    select 'Đợt duyệt (KTT / chủ tịch / người đóng đợt)',
           count(*)
      from public.dot_duyet
     where ktt_id = p_id or chu_tich_id = p_id or nguoi_dong_id = p_id
    union all
    select 'Mục đề nghị đã từ chối',
           count(*) from public.muc_de_nghi where nguoi_tu_choi_id = p_id
    union all
    select 'Phiếu chi (người xác nhận)',
           count(*) from public.lan_tra_tien where nguoi_xac_nhan_id = p_id
    union all
    select 'Phiếu thu (người lập / xác nhận)',
           count(*)
      from public.phieu_thu
     where nguoi_lap_id = p_id or nguoi_xac_nhan_id = p_id
    union all
    select 'Tồn đầu kỳ (người tạo)',
           count(*) from public.ton_dau_ky where nguoi_tao_id = p_id
    union all
    select 'Chứng từ đã tải lên',
           count(*) from public.chung_tu_fmb where nguoi_tai_len_id = p_id
    union all
    select 'Giao dịch đã hủy trong kho lưu trữ',
           count(*) from public.giao_dich_da_huy where nguoi_huy_id = p_id
    -- Danh mục đang trỏ tới người này: không phải giao dịch, nhưng xóa thì danh
    -- mục mất chủ. Bắt Quản trị chuyển người phụ trách trước cho tường minh.
    union all
    select 'Quỹ tiền mặt đang để làm thủ quỹ',
           count(*) from public.quy_tien_mat where thu_quy_id = p_id
    union all
    select 'Dự án đang để làm chủ nhiệm',
           count(*) from public.du_an where chu_nhiem_id = p_id
  ) t
  where sl > 0;
$$;


--
-- Name: admin_huy_giao_dich(text, uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_huy_giao_dich(p_loai text, p_id uuid, p_ly_do text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_toi        uuid := private.nhan_vien_hien_tai();
  v_snap       jsonb;
  v_archive_id uuid;
begin
  perform private.bat_buoc_vai_tro('quan_tri', 'hủy giao dịch');
  if p_ly_do is null or btrim(p_ly_do) = '' then
    raise exception 'Vui lòng ghi lý do hủy giao dịch.';
  end if;

  v_snap := private.snapshot_va_xoa_giao_dich(p_loai, p_id);

  insert into public.giao_dich_da_huy (loai, giao_dich_id, du_lieu, mo_ta, so_tien, ly_do, nguoi_huy_id)
  values (p_loai, p_id, v_snap, private.mo_ta_giao_dich(p_loai, v_snap),
          (v_snap->>'so_tien')::public.tien_te, p_ly_do, v_toi)
  returning id into v_archive_id;

  perform private.ghi_nhat_ky('giao_dich_da_huy', v_archive_id, 'admin_huy_giao_dich',
    v_snap, jsonb_build_object('loai', p_loai, 'giao_dich_id', p_id, 'ly_do', p_ly_do));

  return v_archive_id;
end;
$$;


--
-- Name: FUNCTION admin_huy_giao_dich(p_loai text, p_id uuid, p_ly_do text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.admin_huy_giao_dich(p_loai text, p_id uuid, p_ly_do text) IS 'Admin HỦY giao dịch: snapshot vào kho giao_dich_da_huy rồi xóa khỏi sổ sống (khôi phục được). Chỉ quan_tri.';


--
-- Name: admin_khoi_phuc_giao_dich(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_khoi_phuc_giao_dich(p_archive_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_row  public.giao_dich_da_huy%rowtype;
  v_snap jsonb;
begin
  perform private.bat_buoc_vai_tro('quan_tri', 'khôi phục giao dịch');
  select * into v_row from public.giao_dich_da_huy where id = p_archive_id;
  if not found then raise exception 'Không tìm thấy giao dịch đã hủy để khôi phục.'; end if;
  v_snap := v_row.du_lieu;

  -- INSERT được phép (không qua trigger chặn sửa/xóa). Dựng lại đúng id/ngày cũ.
  if v_row.loai = 'phieu_chi' then
    insert into public.lan_tra_tien
      select * from jsonb_populate_record(null::public.lan_tra_tien,
                                          v_snap - 'chi_tiet' - 'chung_tu_fmb' - 'quy_cong_truong');
    insert into public.chi_tiet_lan_tra
      select * from jsonb_populate_recordset(null::public.chi_tiet_lan_tra, v_snap->'chi_tiet');
    insert into public.chung_tu_fmb
      select * from jsonb_populate_recordset(null::public.chung_tu_fmb, v_snap->'chung_tu_fmb');
    insert into public.but_toan_quy_cong_truong
      select * from jsonb_populate_recordset(null::public.but_toan_quy_cong_truong,
                                             coalesce(v_snap->'quy_cong_truong', '[]'::jsonb));

  elsif v_row.loai = 'phieu_thu' then
    insert into public.phieu_thu
      select * from jsonb_populate_record(null::public.phieu_thu, v_snap - 'chung_tu_fmb');
    insert into public.chung_tu_fmb
      select * from jsonb_populate_recordset(null::public.chung_tu_fmb, v_snap->'chung_tu_fmb');

  elsif v_row.loai = 'lich_su' then
    insert into public.giao_dich_lich_su
      select * from jsonb_populate_record(null::public.giao_dich_lich_su, v_snap);

  elsif v_row.loai = 'ton_dau_ky' then
    insert into public.ton_dau_ky
      select * from jsonb_populate_record(null::public.ton_dau_ky, v_snap);

  elsif v_row.loai = 'chuyen_quy' then
    insert into public.chuyen_quy
      select * from jsonb_populate_record(null::public.chuyen_quy, v_snap - 'chung_tu_fmb');
    insert into public.chung_tu_fmb
      select * from jsonb_populate_recordset(null::public.chung_tu_fmb, v_snap->'chung_tu_fmb');

  elsif v_row.loai = 'quy_cong_truong' then
    insert into public.but_toan_quy_cong_truong
      select * from jsonb_populate_record(null::public.but_toan_quy_cong_truong, v_snap);
  else
    raise exception 'Loại giao dịch không hợp lệ: %', v_row.loai;
  end if;

  perform private.ghi_nhat_ky('giao_dich_da_huy', p_archive_id, 'admin_khoi_phuc_giao_dich',
    v_snap, jsonb_build_object('loai', v_row.loai, 'giao_dich_id', v_row.giao_dich_id));

  delete from public.giao_dich_da_huy where id = p_archive_id;  -- rời kho lưu trữ
end;
$$;


--
-- Name: FUNCTION admin_khoi_phuc_giao_dich(p_archive_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.admin_khoi_phuc_giao_dich(p_archive_id uuid) IS 'Admin KHÔI PHỤC giao dịch đã hủy: dựng lại bản ghi (+con) từ snapshot, rời kho. Chỉ quan_tri.';


--
-- Name: admin_kiem_xoa_nhan_vien(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_kiem_xoa_nhan_vien(p_id uuid) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_nv    public.nhan_vien%rowtype;
  v_vuong jsonb;
  v_toi   uuid := private.nhan_vien_hien_tai();
begin
  perform private.bat_buoc_vai_tro('quan_tri', 'xóa nhân viên');

  select * into v_nv from public.nhan_vien where id = p_id;
  if not found then raise exception 'Không tìm thấy nhân viên.'; end if;

  v_vuong := private.vuong_mac_nhan_vien(p_id);

  return jsonb_build_object(
    'ho_ten',        v_nv.ho_ten,
    'ma',            v_nv.ma,
    'co_tai_khoan',  v_nv.user_id is not null,
    'la_chinh_minh', p_id = v_toi,
    'vuong',         v_vuong,
    'xoa_duoc',      jsonb_array_length(v_vuong) = 0 and p_id is distinct from v_toi
  );
end;
$$;


--
-- Name: FUNCTION admin_kiem_xoa_nhan_vien(p_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.admin_kiem_xoa_nhan_vien(p_id uuid) IS 'Kiểm xem nhân viên này xóa hẳn được không: trả {xoa_duoc, vuong[], ho_ten, ma, co_tai_khoan, la_chinh_minh}. Chỉ đọc. Chỉ quan_tri.';


--
-- Name: admin_sua_giao_dich(text, uuid, jsonb, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_sua_giao_dich(p_loai text, p_id uuid, p_thay_doi jsonb, p_ly_do text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $_$
declare
  v_bang         text;
  v_cot_cho_phep text[];
  v_khoa_dac_biet text[];
  v_cot_gui      text[];
  v_cot_la       text[];
  v_ds_cot       text;
  v_cu           jsonb;
  v_moi          jsonb;
  v_sua_tien     jsonb;
begin
  perform private.bat_buoc_vai_tro('quan_tri', 'sửa giao dịch');

  if p_ly_do is null or btrim(p_ly_do) = '' then
    raise exception 'Vui lòng ghi lý do sửa giao dịch.';
  end if;
  if p_thay_doi is null or jsonb_typeof(p_thay_doi) <> 'object' then
    raise exception 'Không có thay đổi nào để lưu.';
  end if;

  v_bang := case p_loai
    when 'phieu_chi'  then 'lan_tra_tien'
    when 'phieu_thu'  then 'phieu_thu'
    when 'lich_su'    then 'giao_dich_lich_su'
    when 'ton_dau_ky' then 'ton_dau_ky'
    when 'chuyen_quy' then 'chuyen_quy'
    else null end;
  if v_bang is null then
    raise exception 'Loại giao dịch không hợp lệ: %', p_loai;
  end if;

  -- Danh sách trắng. Cột không có ở đây thì không ai sửa được qua đường này.
  v_cot_cho_phep := case p_loai
    when 'phieu_chi' then array[
      'ngay_tra', 'quy_tien_mat_id', 'tai_khoan_ngan_hang_id']
    when 'phieu_thu' then array[
      'ngay_thu', 'so_tien', 'dien_giai', 'quy_tien_mat_id',
      'tai_khoan_ngan_hang_id', 'khoan_muc_thu_id', 'cong_ty_id',
      'doi_tuong_vay_id']
    when 'lich_su' then array[
      'ngay', 'loai', 'noi_dung', 'so_tien', 'quy_tien_mat_id',
      'tai_khoan_ngan_hang_id', 'khoan_muc_thu_id', 'khoan_muc_chi_id',
      'cong_ty_id', 'du_an_id', 'ghi_chu', 'doi_tuong_vay_id']
    when 'ton_dau_ky' then array[
      'ngay', 'so_tien']
    when 'chuyen_quy' then array[
      'ngay', 'so_tien', 'dien_giai', 'tu_quy_tien_mat_id',
      'tu_tai_khoan_ngan_hang_id', 'den_quy_tien_mat_id',
      'den_tai_khoan_ngan_hang_id']
  end;

  -- MIG 47 — khóa được nhận nhưng KHÔNG phải cột: xử lý riêng, không ghi thẳng.
  v_khoa_dac_biet := case p_loai
    when 'phieu_chi' then array['chi_tiet']
    else array[]::text[] end;

  execute format('select to_jsonb(t) from public.%I t where t.id = $1', v_bang)
    into v_cu using p_id;
  if v_cu is null then
    raise exception 'Không tìm thấy giao dịch để sửa.';
  end if;

  v_cot_gui := array(select jsonb_object_keys(p_thay_doi));
  if coalesce(array_length(v_cot_gui, 1), 0) = 0 then
    raise exception 'Không có thay đổi nào để lưu.';
  end if;

  -- Số tiền phiếu chi: đi đường chi_tiet (mig 47), không gửi thẳng tổng.
  if p_loai = 'phieu_chi' and p_thay_doi ? 'so_tien' then
    raise exception 'Số tiền phiếu chi phải sửa theo từng dòng chi tiết (khóa chi_tiet), không sửa thẳng tổng — tổng phiếu do hệ thống tự cộng.';
  end if;

  v_cot_la := array(
    select k from unnest(v_cot_gui) k
    where not (k = any (v_cot_cho_phep || v_khoa_dac_biet)));
  if coalesce(array_length(v_cot_la, 1), 0) > 0 then
    raise exception 'Giao dịch loại % không cho sửa trường: %.',
      p_loai, array_to_string(v_cot_la, ', ');
  end if;

  -- Phiếu thu hoàn ứng: số tiền chốt trạng thái đợt quyết toán (mig 24, 27).
  if p_loai = 'phieu_thu' and p_thay_doi ? 'so_tien'
     and v_cu->>'de_nghi_tam_ung_goc_id' is not null then
    raise exception 'Không sửa được số tiền của phiếu thu hoàn ứng — số này chốt trạng thái đợt quyết toán. Hãy hủy phiếu rồi lập lại cho đúng.';
  end if;

  v_moi := v_cu || p_thay_doi;

  -- Cờ phiên cho qua trigger "sổ chỉ ghi thêm" (mig 28) — local nên hết
  -- transaction là tự tắt, không rò sang phiên khác.
  perform set_config('app.admin_dieu_chinh', 'on', true);

  -- Ghi cả danh sách trắng chứ không chỉ cột được gửi: cột không đổi thì gán lại
  -- đúng giá trị cũ, vô hại, mà câu lệnh luôn có từ hai cột trở lên nên dạng
  -- SET (a, b) = (SELECT a, b …) luôn hợp lệ. jsonb_populate_record ép kiểu
  -- theo đúng định nghĩa bảng (và bỏ qua khóa không phải cột như `chi_tiet`).
  v_ds_cot := (select string_agg(quote_ident(k), ', ' order by k)
               from unnest(v_cot_cho_phep) k);
  execute format(
    'update public.%I as t set (%s) = '
    || '(select %s from jsonb_populate_record(null::public.%I, $1)) '
    || 'where t.id = $2',
    v_bang, v_ds_cot, v_ds_cot, v_bang)
  using v_moi, p_id;

  -- MIG 47 — số tiền phiếu chi, kéo theo chi tiết / quỹ công trường / bù công nợ.
  if p_loai = 'phieu_chi' and p_thay_doi ? 'chi_tiet' then
    v_sua_tien := private.sua_so_tien_phieu_chi(p_id, p_thay_doi->'chi_tiet');
  end if;

  -- Đọc lại bản ghi sau khi sửa: nhật ký lưu giá trị CSDL thật (đã ép kiểu,
  -- đã qua trigger updated_at), không lưu thứ client gửi lên.
  execute format('select to_jsonb(t) from public.%I t where t.id = $1', v_bang)
    into v_moi using p_id;

  perform private.ghi_nhat_ky(v_bang, p_id, 'admin_sua_giao_dich', v_cu,
    v_moi || jsonb_build_object('ly_do', p_ly_do)
          || case when v_sua_tien is null then '{}'::jsonb
                  else jsonb_build_object('sua_so_tien', v_sua_tien) end);

  -- TẮT CỜ NGAY, đừng để nó sống hết transaction (lý do: xem mig 37/41).
  perform set_config('app.admin_dieu_chinh', '', true);
end;
$_$;


--
-- Name: FUNCTION admin_sua_giao_dich(p_loai text, p_id uuid, p_thay_doi jsonb, p_ly_do text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.admin_sua_giao_dich(p_loai text, p_id uuid, p_thay_doi jsonb, p_ly_do text) IS 'Admin SỬA giao dịch tại chỗ theo danh sách trắng cột của từng loại, ghi nhật ký cũ/mới kèm lý do. Mig 38: doi_tuong_vay_id. Mig 47: phiếu chi sửa được số tiền qua khóa chi_tiet (từng dòng), tự kéo theo quỹ công trường; phiếu thu hoàn ứng vẫn khóa số tiền. Chỉ quan_tri.';


--
-- Name: admin_xoa_giao_dich(text, uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_xoa_giao_dich(p_loai text, p_id uuid, p_ly_do text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_snap jsonb;
  v_bang text := case p_loai
    when 'phieu_chi'       then 'lan_tra_tien'
    when 'phieu_thu'       then 'phieu_thu'
    when 'lich_su'         then 'giao_dich_lich_su'
    when 'ton_dau_ky'      then 'ton_dau_ky'
    when 'chuyen_quy'      then 'chuyen_quy'
    when 'quy_cong_truong' then 'but_toan_quy_cong_truong'
    else p_loai end;
begin
  perform private.bat_buoc_vai_tro('quan_tri', 'xóa giao dịch');
  if p_ly_do is null or btrim(p_ly_do) = '' then
    raise exception 'Vui lòng ghi lý do xóa giao dịch.';
  end if;

  v_snap := private.snapshot_va_xoa_giao_dich(p_loai, p_id);

  perform private.ghi_nhat_ky(v_bang, p_id, 'admin_xoa_giao_dich',
    v_snap, jsonb_build_object('loai', p_loai, 'ly_do', p_ly_do));
end;
$$;


--
-- Name: FUNCTION admin_xoa_giao_dich(p_loai text, p_id uuid, p_ly_do text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.admin_xoa_giao_dich(p_loai text, p_id uuid, p_ly_do text) IS 'Admin XÓA hẳn giao dịch: snapshot vào nhật ký rồi xóa khỏi sổ sống (không khôi phục). Chỉ quan_tri.';


--
-- Name: admin_xoa_nhan_vien(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_xoa_nhan_vien(p_id uuid, p_ly_do text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_nv     public.nhan_vien%rowtype;
  v_vuong  jsonb;
  v_mo_ta  text;
  v_snap   jsonb;
  v_con_qt integer;
begin
  perform private.bat_buoc_vai_tro('quan_tri', 'xóa nhân viên');

  if p_ly_do is null or btrim(p_ly_do) = '' then
    raise exception 'Vui lòng ghi lý do xóa nhân viên.';
  end if;

  select * into v_nv from public.nhan_vien where id = p_id;
  if not found then raise exception 'Không tìm thấy nhân viên.'; end if;

  -- Tự xóa mình thì mất quyền ngay giữa chừng, màn hình đang mở thành vô chủ.
  if p_id = private.nhan_vien_hien_tai() then
    raise exception 'Không xóa được chính tài khoản bạn đang đăng nhập.';
  end if;

  -- Đừng để hệ thống không còn Quản trị nào — hết đường vào màn hình này.
  if exists (select 1 from public.vai_tro_nhan_vien
              where nhan_vien_id = p_id and vai_tro = 'quan_tri') then
    select count(*) into v_con_qt
      from public.vai_tro_nhan_vien vt
      join public.nhan_vien nv on nv.id = vt.nhan_vien_id
     where vt.vai_tro = 'quan_tri' and nv.dang_dung and nv.id <> p_id;
    if v_con_qt = 0 then
      raise exception 'Đây là tài khoản Quản trị còn hoạt động cuối cùng. Cấp quyền Quản trị cho người khác trước đã.';
    end if;
  end if;

  -- Còn đứng tên trong sổ thì không xóa. Câu lỗi nói rõ vướng ở đâu để Quản trị
  -- biết phải xử lý gì, thay vì "không xóa được" cụt lủn.
  v_vuong := private.vuong_mac_nhan_vien(p_id);
  if jsonb_array_length(v_vuong) > 0 then
    select string_agg(format('%s: %s', e->>'ten', e->>'so_luong'), '; ')
      into v_mo_ta
      from jsonb_array_elements(v_vuong) e;
    raise exception 'Không xóa được: nhân viên này đã phát sinh dữ liệu (%). Hãy dùng "Ngừng dùng" để khóa tài khoản.', v_mo_ta;
  end if;

  -- Chụp nguyên hồ sơ (kể cả phần đi theo) trước khi xóa — nhật ký còn dấu vết.
  v_snap := to_jsonb(v_nv) || jsonb_build_object(
    'nhay_cam', (select to_jsonb(nc) from public.nhan_vien_nhay_cam nc
                  where nc.nhan_vien_id = p_id),
    'vai_tro',  (select coalesce(jsonb_agg(vt.vai_tro), '[]'::jsonb)
                   from public.vai_tro_nhan_vien vt where vt.nhan_vien_id = p_id),
    'menu',     (select coalesce(jsonb_agg(m.duong_dan), '[]'::jsonb)
                   from public.menu_nhan_vien m where m.nhan_vien_id = p_id));

  -- Xóa. Ba bảng con (nhay_cam, vai_tro, menu) tự đi theo bằng cascade.
  delete from public.nhan_vien where id = p_id;

  perform private.ghi_nhat_ky('nhan_vien', p_id, 'admin_xoa_nhan_vien',
    v_snap, jsonb_build_object('ly_do', p_ly_do));

  -- user_id trả về để app gọi Edge Function xóa nốt tài khoản đăng nhập.
  return jsonb_build_object('user_id', v_nv.user_id, 'ho_ten', v_nv.ho_ten, 'ma', v_nv.ma);
end;
$$;


--
-- Name: FUNCTION admin_xoa_nhan_vien(p_id uuid, p_ly_do text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.admin_xoa_nhan_vien(p_id uuid, p_ly_do text) IS 'Admin XÓA HOÀN TOÀN nhân viên chưa phát sinh giao dịch (kèm hồ sơ nhạy cảm, vai trò, cấu hình tab). Chụp hồ sơ vào nhật ký. Trả user_id để app xóa nốt tài khoản đăng nhập. Chỉ quan_tri.';


--
-- Name: chu_tich_duyet_dot(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.chu_tich_duyet_dot(p_dot_id uuid, p_y_kien text DEFAULT NULL::text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_toi     uuid := private.nhan_vien_hien_tai();
  v_dot     public.dot_duyet%rowtype;
  v_vuot    record;
  v_loai    text;
  v_goc     uuid;
  v_con_no  numeric;
begin
  perform private.bat_buoc_vai_tro('chu_tich', 'duyệt đợt');

  select * into v_dot from public.dot_duyet where id = p_dot_id;
  if not found then
    raise exception 'Không tìm thấy đợt duyệt.';
  end if;
  if v_dot.trang_thai <> 'cho_chu_tich' then
    raise exception 'Đợt này đang ở trạng thái "%" nên không duyệt được.', v_dot.trang_thai;
  end if;

  select km.ten as khoan_muc, ns.con_lai, sum(m.so_tien) as dang_duyet
  into v_vuot
  from public.muc_de_nghi m
  join public.khoan_muc_chi km on km.id = m.khoan_muc_chi_id
  join public.de_nghi dn on dn.id = m.de_nghi_id
  join public.v_ngan_sach ns
    on ns.khoan_muc_chi_id = m.khoan_muc_chi_id
   and ns.nam = extract(year from current_date)::int
   and (ns.cong_ty_id is null or ns.cong_ty_id = dn.cong_ty_id)
   and (ns.du_an_id is null or ns.du_an_id = m.du_an_id)
  where m.dot_duyet_id = p_dot_id
    and km.kiem_soat_ngan_sach
  group by km.ten, ns.con_lai
  having sum(m.so_tien) > ns.con_lai
  limit 1;

  if found then
    raise exception 'Vượt ngân sách khoản mục "%": còn lại % đ, đợt này duyệt % đ.',
      v_vuot.khoan_muc, v_vuot.con_lai, v_vuot.dang_duyet;
  end if;

  update public.dot_duyet
  set trang_thai = 'da_duyet', chu_tich_id = v_toi, chu_tich_luc = now(),
      chu_tich_y_kien = p_y_kien
  where id = p_dot_id;

  perform private.ghi_nhat_ky('dot_duyet', p_dot_id, 'chu_tich_duyet',
    to_jsonb(v_dot), jsonb_build_object('y_kien', p_y_kien));

  -- MIG 42: quyết toán của người quản lý quỹ -> ghi CHI ra khỏi quỹ đó.
  -- Đặt TRƯỚC nhánh đóng đợt: đóng đợt chỉ đổi trạng thái, còn bút toán tiền
  -- phải ghi bất kể đợt đóng hay để mở chờ trả bù.
  perform private.ghi_chi_quy_cong_truong(p_dot_id, v_toi);

  select dn.loai, dn.de_nghi_tam_ung_goc_id
    into v_loai, v_goc
  from public.de_nghi dn where dn.id = v_dot.de_nghi_id;

  if v_loai = 'quyet_toan' and v_goc is not null then
    select con_no into v_con_no
    from public.v_cong_no_tam_ung where de_nghi_tam_ung_id = v_goc;

    if v_con_no is not null and v_con_no >= 0 then
      update public.dot_duyet
      set trang_thai    = 'da_dong',
          ly_do_dong    = 'Quyết toán đã cân đối bằng tiền tạm ứng — không cần chi trả bù.',
          nguoi_dong_id = v_toi,
          dong_luc      = now()
      where id = p_dot_id;

      perform private.ghi_nhat_ky('dot_duyet', p_dot_id, 'tu_dong_dong_quyet_toan',
        null, jsonb_build_object('con_no', v_con_no, 'ly_do', 'quyet toan can doi'));
    end if;
  end if;
end;
$$;


--
-- Name: FUNCTION chu_tich_duyet_dot(p_dot_id uuid, p_y_kien text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.chu_tich_duyet_dot(p_dot_id uuid, p_y_kien text) IS 'Chủ tịch duyệt đợt -> mở khóa cho KTTT trả tiền. Kiểm ngân sách tại đây. Quyết toán đã cân đối tự đóng đợt (mig 24). MIG 42: quyết toán của người quản lý quỹ thì ghi luôn bút toán CHI ra khỏi quỹ công trường.';


--
-- Name: chu_tich_duyet_dot_qua_bot(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.chu_tich_duyet_dot_qua_bot(p_dot_id uuid, p_nhan_vien_id uuid) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_dot    public.dot_duyet%rowtype;
  v_vuot   record;
  v_co_vai boolean;
  v_loai   text;
  v_goc    uuid;
  v_con_no numeric;
begin
  select exists (
    select 1
    from public.vai_tro_nhan_vien vt
    join public.nhan_vien nv on nv.id = vt.nhan_vien_id
    where vt.nhan_vien_id = p_nhan_vien_id
      and vt.vai_tro = 'chu_tich'
      and nv.dang_dung
  ) into v_co_vai;
  if not v_co_vai then
    raise exception 'Người này không có quyền Chủ tịch để duyệt.' using errcode = '42501';
  end if;

  select * into v_dot from public.dot_duyet where id = p_dot_id;
  if not found then
    raise exception 'Không tìm thấy đợt duyệt.';
  end if;
  if v_dot.trang_thai <> 'cho_chu_tich' then
    raise exception 'Đợt này đang ở trạng thái "%" nên không duyệt được.', v_dot.trang_thai;
  end if;

  select km.ten as khoan_muc, ns.con_lai, sum(m.so_tien) as dang_duyet
  into v_vuot
  from public.muc_de_nghi m
  join public.khoan_muc_chi km on km.id = m.khoan_muc_chi_id
  join public.de_nghi dn on dn.id = m.de_nghi_id
  join public.v_ngan_sach ns
    on ns.khoan_muc_chi_id = m.khoan_muc_chi_id
   and ns.nam = extract(year from current_date)::int
   and (ns.cong_ty_id is null or ns.cong_ty_id = dn.cong_ty_id)
   and (ns.du_an_id is null or ns.du_an_id = m.du_an_id)
  where m.dot_duyet_id = p_dot_id
    and km.kiem_soat_ngan_sach
  group by km.ten, ns.con_lai
  having sum(m.so_tien) > ns.con_lai
  limit 1;

  if found then
    raise exception 'Vượt ngân sách khoản mục "%": còn lại % đ, đợt này duyệt % đ.',
      v_vuot.khoan_muc, v_vuot.con_lai, v_vuot.dang_duyet;
  end if;

  update public.dot_duyet
  set trang_thai = 'da_duyet', chu_tich_id = p_nhan_vien_id, chu_tich_luc = now(),
      chu_tich_y_kien = 'Duyệt qua Telegram'
  where id = p_dot_id;

  perform private.ghi_nhat_ky('dot_duyet', p_dot_id, 'chu_tich_duyet_qua_bot',
    to_jsonb(v_dot), jsonb_build_object('nhan_vien_id', p_nhan_vien_id, 'kenh', 'telegram'));

  -- MIG 42: quyết toán của người quản lý quỹ -> ghi CHI ra khỏi quỹ đó.
  perform private.ghi_chi_quy_cong_truong(p_dot_id, p_nhan_vien_id);

  select dn.loai, dn.de_nghi_tam_ung_goc_id
    into v_loai, v_goc
  from public.de_nghi dn where dn.id = v_dot.de_nghi_id;

  if v_loai = 'quyet_toan' and v_goc is not null then
    select con_no into v_con_no
    from public.v_cong_no_tam_ung where de_nghi_tam_ung_id = v_goc;

    if v_con_no is not null and v_con_no >= 0 then
      update public.dot_duyet
      set trang_thai    = 'da_dong',
          ly_do_dong    = 'Quyết toán đã cân đối bằng tiền tạm ứng — không cần chi trả bù.',
          nguoi_dong_id = p_nhan_vien_id,
          dong_luc      = now()
      where id = p_dot_id;

      perform private.ghi_nhat_ky('dot_duyet', p_dot_id, 'tu_dong_dong_quyet_toan',
        null, jsonb_build_object('con_no', v_con_no, 'kenh', 'telegram'));
    end if;
  end if;

  return (
    select dn.so_de_nghi
    from public.de_nghi dn
    join public.dot_duyet dd on dd.de_nghi_id = dn.id
    where dd.id = p_dot_id
  );
end;
$$;


--
-- Name: FUNCTION chu_tich_duyet_dot_qua_bot(p_dot_id uuid, p_nhan_vien_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.chu_tich_duyet_dot_qua_bot(p_dot_id uuid, p_nhan_vien_id uuid) IS 'Chủ tịch duyệt đợt qua Telegram bot. Danh tính từ tham số (webhook đã xác thực) nhưng KIỂM vai trò trong DB. Chỉ service_role gọi. MIG 42: cũng ghi bút toán CHI quỹ công trường.';


--
-- Name: chu_tich_tu_choi_dot(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.chu_tich_tu_choi_dot(p_dot_id uuid, p_ly_do text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_toi uuid := private.nhan_vien_hien_tai();
  v_dot public.dot_duyet%rowtype;
  v_muc jsonb;
begin
  perform private.bat_buoc_vai_tro('chu_tich', 'từ chối đợt');

  if p_ly_do is null or btrim(p_ly_do) = '' then
    raise exception 'Vui lòng ghi lý do từ chối.';
  end if;

  select * into v_dot from public.dot_duyet where id = p_dot_id;
  if not found then
    raise exception 'Không tìm thấy đợt duyệt.';
  end if;
  if v_dot.trang_thai <> 'cho_chu_tich' then
    raise exception 'Đợt này đang ở trạng thái "%" nên không từ chối được.', v_dot.trang_thai;
  end if;

  -- Lưu lại đợt này gồm mục nào TRƯỚC KHI gỡ ra — sau khi gỡ thì không còn dấu vết.
  select jsonb_agg(jsonb_build_object('muc_id', id, 'dien_giai', dien_giai, 'so_tien', so_tien))
  into v_muc
  from public.muc_de_nghi where dot_duyet_id = p_dot_id;

  update public.dot_duyet
  set trang_thai = 'bi_tu_choi', chu_tich_id = v_toi, chu_tich_luc = now(),
      ly_do_tu_choi = p_ly_do
  where id = p_dot_id;

  -- Mục quay về chờ duyệt (Phần I giả định 3), KTT xử lý lại.
  update public.muc_de_nghi set dot_duyet_id = null where dot_duyet_id = p_dot_id;

  perform private.ghi_nhat_ky('dot_duyet', p_dot_id, 'chu_tich_tu_choi',
    jsonb_build_object('muc_trong_dot', v_muc),
    jsonb_build_object('ly_do', p_ly_do));
end;
$$;


--
-- Name: dinh_chung_tu_de_nghi(uuid, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.dinh_chung_tu_de_nghi(p_de_nghi_id uuid, p_chung_tu jsonb) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_toi   uuid := private.nhan_vien_hien_tai();
  v_dn    public.de_nghi%rowtype;
  v_item  jsonb;
  v_dem   int := 0;
begin
  if v_toi is null then
    raise exception 'Bạn chưa đăng nhập.' using errcode = '42501';
  end if;

  select * into v_dn from public.de_nghi where id = p_de_nghi_id;
  if not found then
    raise exception 'Không tìm thấy đề nghị.';
  end if;

  -- Chỉ người đề xuất, chỉ khi đề nghị còn nháp hoặc bị từ chối (đang sửa lại).
  if v_dn.nguoi_de_xuat_id <> v_toi then
    raise exception 'Bạn chỉ đính chứng từ cho đề nghị của chính mình.' using errcode = '42501';
  end if;
  if v_dn.trang_thai not in ('nhap', 'bi_tu_choi') then
    raise exception 'Đề nghị đã gửi duyệt thì không đính thêm chứng từ hồ sơ được nữa.';
  end if;

  if p_chung_tu is null or jsonb_array_length(p_chung_tu) = 0 then
    return 0;
  end if;

  for v_item in select * from jsonb_array_elements(p_chung_tu)
  loop
    insert into public.chung_tu_fmb (de_nghi_id, ten_file, duong_dan, loai_file, nguoi_tai_len_id)
    values (
      p_de_nghi_id,
      v_item->>'ten_file',
      v_item->>'duong_dan',
      nullif(v_item->>'loai_file',''),
      v_toi
    )
    on conflict (duong_dan) do nothing;  -- upload lại cùng file không nhân đôi
    v_dem := v_dem + 1;
  end loop;

  perform private.ghi_nhat_ky('de_nghi', p_de_nghi_id, 'dinh_chung_tu',
    null, jsonb_build_object('so_file', v_dem));

  return v_dem;
end;
$$;


--
-- Name: FUNCTION dinh_chung_tu_de_nghi(p_de_nghi_id uuid, p_chung_tu jsonb); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.dinh_chung_tu_de_nghi(p_de_nghi_id uuid, p_chung_tu jsonb) IS 'Đính chứng từ hồ sơ vào đề nghị (ảnh báo giá, hợp đồng...). Chỉ người đề xuất, chỉ khi nháp/bị từ chối.';


--
-- Name: dong_dot(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.dong_dot(p_dot_id uuid, p_ly_do text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_toi uuid := private.nhan_vien_hien_tai();
  v_dot public.dot_duyet%rowtype;
  v_con numeric;
begin
  perform private.bat_buoc_vai_tro('ke_toan_thanh_toan', 'đóng đợt thanh toán');

  if p_ly_do is null or btrim(p_ly_do) = '' then
    raise exception 'Vui lòng ghi lý do đóng đợt (ví dụ: hàng về thiếu, có chiết khấu).';
  end if;

  select * into v_dot from public.dot_duyet where id = p_dot_id;
  if not found then
    raise exception 'Không tìm thấy đợt duyệt.';
  end if;
  if v_dot.trang_thai <> 'da_duyet' then
    raise exception 'Chỉ đóng được đợt đã duyệt. Đợt này đang ở trạng thái "%".', v_dot.trang_thai;
  end if;

  select so_tien_con_phai_tra into v_con
  from public.v_dot_duyet_tong_hop where dot_duyet_id = p_dot_id;

  update public.dot_duyet
  set trang_thai = 'da_dong', ly_do_dong = p_ly_do, nguoi_dong_id = v_toi, dong_luc = now()
  where id = p_dot_id;

  perform private.ghi_nhat_ky('dot_duyet', p_dot_id, 'dong_dot',
    to_jsonb(v_dot), jsonb_build_object('ly_do', p_ly_do, 'so_tien_khong_tra_nua', v_con));
end;
$$;


--
-- Name: gui_duyet_de_nghi(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.gui_duyet_de_nghi(p_de_nghi_id uuid, p_ngoai_le_ly_do text DEFAULT NULL::text) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_toi       uuid := private.nhan_vien_hien_tai();
  v_dn        public.de_nghi%rowtype;
  v_ma_cty    text;
  v_so        text;
  v_thieu     int;
  v_qua_han   int;
  v_vuot      record;
begin
  select * into v_dn from public.de_nghi where id = p_de_nghi_id;
  if not found then
    raise exception 'Không tìm thấy đề nghị.';
  end if;
  if v_dn.nguoi_de_xuat_id <> v_toi then
    raise exception 'Bạn chỉ gửi duyệt được đề nghị do chính mình lập.' using errcode = '42501';
  end if;
  if v_dn.trang_thai not in ('nhap', 'bi_tu_choi') then
    raise exception 'Đề nghị đang ở trạng thái "%" nên không gửi duyệt được.', v_dn.trang_thai;
  end if;
  if not exists (select 1 from public.muc_de_nghi where de_nghi_id = p_de_nghi_id) then
    raise exception 'Đề nghị phải có ít nhất một mục trong bảng kê.';
  end if;

  -- Khoản mục nào bắt buộc chứng từ thì phải có ảnh đính vào hồ sơ đề nghị.
  select count(*) into v_thieu
  from public.muc_de_nghi m
  join public.khoan_muc_chi km on km.id = m.khoan_muc_chi_id
  where m.de_nghi_id = p_de_nghi_id
    and km.bat_buoc_chung_tu
    and not exists (
      select 1 from public.chung_tu_fmb ct where ct.de_nghi_id = p_de_nghi_id
    );
  if v_thieu > 0 then
    raise exception 'Đề nghị có khoản mục bắt buộc chứng từ. Vui lòng đính ảnh hóa đơn trước khi gửi duyệt.';
  end if;

  -- Tạm ứng: chặn nếu người nhận ứng còn khoản quá hạn chưa tất toán.
  if v_dn.loai = 'tam_ung' then
    select count(*) into v_qua_han
    from public.v_cong_no_tam_ung ct
    where ct.nhan_vien_nhan_ung_id = v_dn.nhan_vien_nhan_ung_id
      and ct.qua_han;

    if v_qua_han > 0 then
      -- Ngoại lệ: chỉ KTT hoặc Quản trị phá lệ được, và phải ghi lý do.
      if p_ngoai_le_ly_do is null
         or not private.co_mot_trong_vai_tro(array['ke_toan_truong','quan_tri']) then
        raise exception 'Người nhận ứng còn % khoản tạm ứng quá hạn chưa tất toán. Phải hoàn ứng xong mới được ứng tiếp. (Kế toán trưởng có thể duyệt ngoại lệ kèm lý do.)', v_qua_han;
      end if;
      perform private.ghi_nhat_ky('de_nghi', p_de_nghi_id, 'ngoai_le_tam_ung_qua_han',
        null, jsonb_build_object('ly_do', p_ngoai_le_ly_do, 'so_khoan_qua_han', v_qua_han));
    end if;
  end if;

  -- KIỂM NGÂN SÁCH SỚM (Phase 5): với khoản mục bật kiểm soát ngân sách, tổng
  -- bảng kê của đề nghị không được vượt phần ngân sách còn lại. Chủ tịch còn kiểm
  -- lần cuối ở chu_tich_duyet_dot — đây chỉ là cảnh báo sớm cho người đề xuất.
  select km.ten as khoan_muc, ns.con_lai, sum(m.so_tien) as dang_gui
  into v_vuot
  from public.muc_de_nghi m
  join public.khoan_muc_chi km on km.id = m.khoan_muc_chi_id
  join public.v_ngan_sach ns
    on ns.khoan_muc_chi_id = m.khoan_muc_chi_id
   and ns.nam = extract(year from current_date)::int
   and (ns.cong_ty_id is null or ns.cong_ty_id = v_dn.cong_ty_id)
   and (ns.du_an_id is null or ns.du_an_id = m.du_an_id)
  where m.de_nghi_id = p_de_nghi_id
    and km.kiem_soat_ngan_sach
  group by km.ten, ns.con_lai
  having sum(m.so_tien) > ns.con_lai
  limit 1;

  if found then
    raise exception 'Vượt ngân sách khoản mục "%": còn lại % đ, đề nghị này % đ. Giảm số tiền hoặc chờ cấp thêm ngân sách.',
      v_vuot.khoan_muc, v_vuot.con_lai, v_vuot.dang_gui;
  end if;

  -- Sinh số nếu chưa có (đề nghị bị từ chối gửi lại thì giữ số cũ).
  if v_dn.so_de_nghi is null then
    select ma into v_ma_cty from public.cong_ty where id = v_dn.cong_ty_id;
    v_so := private.sinh_so_de_nghi(v_dn.loai, v_ma_cty, extract(year from current_date)::int);
  else
    v_so := v_dn.so_de_nghi;
  end if;

  update public.de_nghi
  set so_de_nghi = v_so, trang_thai = 'dang_duyet', ly_do_tu_choi = null
  where id = p_de_nghi_id;

  perform private.ghi_nhat_ky('de_nghi', p_de_nghi_id, 'gui_duyet',
    to_jsonb(v_dn), jsonb_build_object('so_de_nghi', v_so));

  return v_so;
end;
$$;


--
-- Name: FUNCTION gui_duyet_de_nghi(p_de_nghi_id uuid, p_ngoai_le_ly_do text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.gui_duyet_de_nghi(p_de_nghi_id uuid, p_ngoai_le_ly_do text) IS 'Nháp/bị từ chối -> đang duyệt. Sinh số, kiểm chứng từ bắt buộc, chặn tạm ứng quá hạn (ngoại lệ KTT), và kiểm ngân sách sớm với khoản mục kiểm soát (Phase 5).';


--
-- Name: huy_de_nghi(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.huy_de_nghi(p_de_nghi_id uuid, p_ly_do text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_toi uuid := private.nhan_vien_hien_tai();
  v_dn  public.de_nghi%rowtype;
begin
  select * into v_dn from public.de_nghi where id = p_de_nghi_id;
  if not found then
    raise exception 'Không tìm thấy đề nghị.';
  end if;

  if not (v_dn.nguoi_de_xuat_id = v_toi or private.co_vai_tro('quan_tri')) then
    raise exception 'Bạn chỉ hủy được đề nghị do chính mình lập.' using errcode = '42501';
  end if;
  if v_dn.trang_thai not in ('nhap', 'bi_tu_choi') then
    raise exception 'Chỉ hủy được đề nghị còn nháp hoặc đã bị từ chối. Đề nghị đang duyệt thì phải để Kế toán trưởng trả về trước.';
  end if;
  if p_ly_do is null or btrim(p_ly_do) = '' then
    raise exception 'Vui lòng ghi lý do hủy.';
  end if;

  update public.de_nghi set trang_thai = 'da_huy' where id = p_de_nghi_id;

  perform private.ghi_nhat_ky('de_nghi', p_de_nghi_id, 'huy',
    to_jsonb(v_dn), jsonb_build_object('ly_do', p_ly_do));
end;
$$;


--
-- Name: huy_nop_lai_tien_thua(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.huy_nop_lai_tien_thua(p_phieu_thu_id uuid, p_ly_do text DEFAULT NULL::text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_toi uuid := private.nhan_vien_hien_tai();
  v_pt  public.phieu_thu%rowtype;
begin
  select * into v_pt from public.phieu_thu where id = p_phieu_thu_id;
  if not found then
    raise exception 'Không tìm thấy phiếu nộp lại.';
  end if;
  if v_pt.de_nghi_tam_ung_goc_id is null then
    raise exception 'Phiếu này không phải phiếu nộp lại tiền tạm ứng.';
  end if;
  if v_pt.trang_thai <> 'nhap' then
    raise exception 'Chỉ hủy được phiếu nộp lại đang ở trạng thái nháp.';
  end if;
  if v_pt.nguoi_lap_id is distinct from v_toi
     and not private.co_mot_trong_vai_tro(array['ke_toan_truong','ke_toan_thanh_toan','quan_tri']) then
    raise exception 'Chỉ người lập phiếu hoặc kế toán mới hủy được phiếu nộp lại này.'
      using errcode = '42501';
  end if;

  update public.phieu_thu set trang_thai = 'da_huy' where id = p_phieu_thu_id;

  perform private.ghi_nhat_ky('phieu_thu', p_phieu_thu_id, 'huy_nop_lai',
    to_jsonb(v_pt), jsonb_build_object('ly_do', p_ly_do));
end;
$$;


--
-- Name: FUNCTION huy_nop_lai_tien_thua(p_phieu_thu_id uuid, p_ly_do text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.huy_nop_lai_tien_thua(p_phieu_thu_id uuid, p_ly_do text) IS 'Hủy phiếu nộp lại còn nháp. Người lập hoặc kế toán hủy được (QĐ-19).';


--
-- Name: kiem_nhap_quy_trung(uuid, numeric, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.kiem_nhap_quy_trung(p_quy_tien_mat_id uuid, p_so_tien numeric, p_ngay date) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_bt_id uuid;
  v_kq    jsonb;
begin
  if p_quy_tien_mat_id is null or p_so_tien is null or p_ngay is null then
    return jsonb_build_object('trung', false);
  end if;

  -- Không được xem quỹ đó thì cũng không được dò xem quỹ đó có bút toán nào.
  if not private.duoc_xem_nguon_tien(p_quy_tien_mat_id, null) then
    return jsonb_build_object('trung', false);
  end if;

  v_bt_id := private.but_toan_nhap_quy_trung(p_quy_tien_mat_id, p_so_tien, p_ngay);
  if v_bt_id is null then
    return jsonb_build_object('trung', false);
  end if;

  select jsonb_build_object(
           'trung',          true,
           'quy',            q.ten,
           'so_tien',        b.so_tien,
           'ngay',           b.ngay,
           'tam_ung_goc',    dn.so_de_nghi,
           'nguoi_nhan_ung', nv.ho_ten
         )
    into v_kq
  from public.but_toan_quy_cong_truong b
  join public.quy_tien_mat q on q.id = b.quy_tien_mat_id
  join public.de_nghi dn     on dn.id = b.de_nghi_tam_ung_goc_id
  join public.nhan_vien nv   on nv.id = b.nhan_vien_id
  where b.id = v_bt_id;

  return v_kq;
end;
$$;


--
-- Name: FUNCTION kiem_nhap_quy_trung(p_quy_tien_mat_id uuid, p_so_tien numeric, p_ngay date); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.kiem_nhap_quy_trung(p_quy_tien_mat_id uuid, p_so_tien numeric, p_ngay date) IS 'Màn Thu tiền hỏi trước khi lập: khoản thu này có trùng bút toán nhập quỹ công trường tự động không (mig 55). Trả {trung:false} hoặc {trung:true, quy, so_tien, ngay, tam_ung_goc, nguoi_nhan_ung}. Đây chỉ là chỗ NHẮC — chốt chặn là trigger phieu_thu_khong_trung_nhap_quy.';


--
-- Name: ktt_tao_dot_duyet(uuid, uuid[], text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ktt_tao_dot_duyet(p_de_nghi_id uuid, p_muc_ids uuid[], p_y_kien text DEFAULT NULL::text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_toi     uuid := private.nhan_vien_hien_tai();
  v_dn      public.de_nghi%rowtype;
  v_dot_id  uuid;
  v_so_dot  int;
  v_hop_le  int;
begin
  perform private.bat_buoc_vai_tro('ke_toan_truong', 'duyệt đề nghị');

  select * into v_dn from public.de_nghi where id = p_de_nghi_id;
  if not found then
    raise exception 'Không tìm thấy đề nghị.';
  end if;
  if v_dn.trang_thai <> 'dang_duyet' then
    raise exception 'Đề nghị đang ở trạng thái "%" nên không duyệt được.', v_dn.trang_thai;
  end if;
  if p_muc_ids is null or array_length(p_muc_ids, 1) is null then
    raise exception 'Vui lòng chọn ít nhất một mục để duyệt.';
  end if;

  -- Mọi mục được chọn phải: thuộc đúng đề nghị này, CHƯA vào đợt nào, CHƯA bị từ chối.
  select count(*) into v_hop_le
  from public.muc_de_nghi m
  where m.id = any(p_muc_ids)
    and m.de_nghi_id = p_de_nghi_id
    and m.dot_duyet_id is null
    and m.tu_choi_luc is null;

  if v_hop_le <> array_length(p_muc_ids, 1) then
    raise exception 'Có mục đã được duyệt ở đợt khác, đã bị từ chối, hoặc không thuộc đề nghị này. Vui lòng tải lại trang.';
  end if;

  select coalesce(max(so_dot), 0) + 1 into v_so_dot
  from public.dot_duyet where de_nghi_id = p_de_nghi_id;

  insert into public.dot_duyet (de_nghi_id, so_dot, ktt_id, ktt_y_kien, trang_thai)
  values (p_de_nghi_id, v_so_dot, v_toi, p_y_kien, 'cho_chu_tich')
  returning id into v_dot_id;

  update public.muc_de_nghi set dot_duyet_id = v_dot_id where id = any(p_muc_ids);

  perform private.ghi_nhat_ky('dot_duyet', v_dot_id, 'ktt_tao_dot',
    null, jsonb_build_object('de_nghi_id', p_de_nghi_id, 'so_dot', v_so_dot,
                             'muc_ids', to_jsonb(p_muc_ids), 'y_kien', p_y_kien));

  return v_dot_id;
end;
$$;


--
-- Name: FUNCTION ktt_tao_dot_duyet(p_de_nghi_id uuid, p_muc_ids uuid[], p_y_kien text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.ktt_tao_dot_duyet(p_de_nghi_id uuid, p_muc_ids uuid[], p_y_kien text) IS 'KTT chọn mục duyệt lần này -> tạo đợt duyệt, chuyển sang chờ Chủ tịch. Duyệt trọn gói = chọn hết mục.';


--
-- Name: ktt_tao_dot_duyet(uuid, jsonb, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ktt_tao_dot_duyet(p_de_nghi_id uuid, p_muc jsonb, p_y_kien text DEFAULT NULL::text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_toi     uuid := private.nhan_vien_hien_tai();
  v_dn      public.de_nghi%rowtype;
  v_dot_id  uuid;
  v_so_dot  int;
  v_item    jsonb;
  v_muc     public.muc_de_nghi%rowtype;
  v_moi     public.tien_te;
  v_ids     uuid[] := array[]::uuid[];
begin
  perform private.bat_buoc_vai_tro('ke_toan_truong', 'duyệt đề nghị');

  select * into v_dn from public.de_nghi where id = p_de_nghi_id;
  if not found then
    raise exception 'Không tìm thấy đề nghị.';
  end if;
  if v_dn.trang_thai <> 'dang_duyet' then
    raise exception 'Đề nghị đang ở trạng thái "%" nên không duyệt được.', v_dn.trang_thai;
  end if;
  if p_muc is null or jsonb_array_length(p_muc) = 0 then
    raise exception 'Vui lòng chọn ít nhất một mục để duyệt.';
  end if;

  select coalesce(max(so_dot), 0) + 1 into v_so_dot
  from public.dot_duyet where de_nghi_id = p_de_nghi_id;

  insert into public.dot_duyet (de_nghi_id, so_dot, ktt_id, ktt_y_kien, trang_thai)
  values (p_de_nghi_id, v_so_dot, v_toi, p_y_kien, 'cho_chu_tich')
  returning id into v_dot_id;

  for v_item in select * from jsonb_array_elements(p_muc)
  loop
    -- Khóa mục để không ai đổi song song (kỷ luật FOR UPDATE của dự án).
    select * into v_muc from public.muc_de_nghi
    where id = (v_item->>'muc_id')::uuid
    for update;

    if not found then
      raise exception 'Không tìm thấy mục.';
    end if;
    if v_muc.de_nghi_id <> p_de_nghi_id then
      raise exception 'Có mục không thuộc đề nghị này. Vui lòng tải lại trang.';
    end if;
    if v_muc.dot_duyet_id is not null then
      raise exception 'Có mục đã được duyệt ở đợt khác. Vui lòng tải lại trang.';
    end if;
    if v_muc.tu_choi_luc is not null then
      raise exception 'Có mục đã bị từ chối. Vui lòng tải lại trang.';
    end if;

    v_moi := (v_item->>'so_tien_duyet')::public.tien_te;
    if v_moi is null or v_moi <= 0 then
      raise exception 'Số tiền duyệt của mỗi mục phải lớn hơn 0.';
    end if;
    if v_moi > v_muc.so_tien then
      raise exception 'Số tiền duyệt (%) không được lớn hơn số đề nghị (%). Chỉ được duyệt bằng hoặc thấp hơn; muốn tăng thì lập đề nghị bổ sung.',
        v_moi, v_muc.so_tien;
    end if;

    update public.muc_de_nghi
    set so_tien = v_moi, dot_duyet_id = v_dot_id
    where id = v_muc.id;

    v_ids := array_append(v_ids, v_muc.id);

    if v_moi <> v_muc.so_tien then
      perform private.ghi_nhat_ky('muc_de_nghi', v_muc.id, 'ktt_giam_so_tien',
        to_jsonb(v_muc),
        jsonb_build_object('so_tien_cu', v_muc.so_tien, 'so_tien_duyet', v_moi));
    end if;
  end loop;

  perform private.ghi_nhat_ky('dot_duyet', v_dot_id, 'ktt_tao_dot',
    null, jsonb_build_object('de_nghi_id', p_de_nghi_id, 'so_dot', v_so_dot,
                             'muc_ids', to_jsonb(v_ids), 'y_kien', p_y_kien));

  return v_dot_id;
end;
$$;


--
-- Name: FUNCTION ktt_tao_dot_duyet(p_de_nghi_id uuid, p_muc jsonb, p_y_kien text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.ktt_tao_dot_duyet(p_de_nghi_id uuid, p_muc jsonb, p_y_kien text) IS 'KTT gom mục thành đợt, DUYỆT ĐƯỢC SỐ TIỀN NHỎ HƠN từng mục (không cho lớn hơn). Chuyển chờ Chủ tịch.';


--
-- Name: ktt_tra_ve_de_nghi(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ktt_tra_ve_de_nghi(p_de_nghi_id uuid, p_ly_do text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_toi uuid := private.nhan_vien_hien_tai();
  v_dn  public.de_nghi%rowtype;
begin
  perform private.bat_buoc_vai_tro('ke_toan_truong', 'trả về đề nghị');

  if p_ly_do is null or btrim(p_ly_do) = '' then
    raise exception 'Vui lòng ghi lý do trả về để người lập biết cần sửa gì.';
  end if;

  select * into v_dn from public.de_nghi where id = p_de_nghi_id;
  if not found then
    raise exception 'Không tìm thấy đề nghị.';
  end if;
  if v_dn.trang_thai <> 'dang_duyet' then
    raise exception 'Chỉ trả về được đề nghị đang duyệt. Đề nghị này đang ở trạng thái "%".', v_dn.trang_thai;
  end if;
  if exists (select 1 from public.dot_duyet where de_nghi_id = p_de_nghi_id) then
    raise exception 'Đề nghị đã có đợt duyệt, không trả về cả cục được nữa. Xử lý từng mục / đợt.';
  end if;

  update public.de_nghi
  set trang_thai = 'bi_tu_choi', ly_do_tu_choi = p_ly_do
  where id = p_de_nghi_id;

  perform private.ghi_nhat_ky('de_nghi', p_de_nghi_id, 'ktt_tra_ve',
    to_jsonb(v_dn), jsonb_build_object('ly_do', p_ly_do));
end;
$$;


--
-- Name: FUNCTION ktt_tra_ve_de_nghi(p_de_nghi_id uuid, p_ly_do text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.ktt_tra_ve_de_nghi(p_de_nghi_id uuid, p_ly_do text) IS 'KTT trả cả đề nghị về cho người lập sửa lại (bi_tu_choi). Chỉ khi chưa có đợt duyệt nào.';


--
-- Name: ktt_tu_choi_muc(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ktt_tu_choi_muc(p_muc_id uuid, p_ly_do text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_toi uuid := private.nhan_vien_hien_tai();
  v_muc public.muc_de_nghi%rowtype;
begin
  perform private.bat_buoc_vai_tro('ke_toan_truong', 'từ chối mục đề nghị');

  if p_ly_do is null or btrim(p_ly_do) = '' then
    raise exception 'Vui lòng ghi lý do từ chối. Từ chối mà không nói vì sao thì người đề xuất không biết phải sửa gì.';
  end if;

  select * into v_muc from public.muc_de_nghi where id = p_muc_id;
  if not found then
    raise exception 'Không tìm thấy mục.';
  end if;
  if v_muc.dot_duyet_id is not null then
    raise exception 'Mục này đã thuộc một đợt duyệt, không từ chối riêng được nữa.';
  end if;
  if v_muc.tu_choi_luc is not null then
    raise exception 'Mục này đã bị từ chối rồi.';
  end if;

  update public.muc_de_nghi
  set ly_do_tu_choi = p_ly_do, nguoi_tu_choi_id = v_toi, tu_choi_luc = now()
  where id = p_muc_id;

  perform private.ghi_nhat_ky('muc_de_nghi', p_muc_id, 'ktt_tu_choi_muc',
    to_jsonb(v_muc), jsonb_build_object('ly_do', p_ly_do));
end;
$$;


--
-- Name: luu_ton_dau_ky(uuid, uuid, public.tien_te, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.luu_ton_dau_ky(p_quy_id uuid, p_tk_id uuid, p_so_tien public.tien_te, p_ngay date) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_toi uuid := private.nhan_vien_hien_tai();
  v_cu  public.ton_dau_ky%rowtype;
  v_id  uuid;
begin
  if v_toi is null then
    raise exception 'Phiên đăng nhập không hợp lệ.' using errcode = '42501';
  end if;
  if num_nonnulls(p_quy_id, p_tk_id) <> 1 then
    raise exception 'Phải chọn đúng một nguồn tiền: quỹ tiền mặt hoặc tài khoản ngân hàng.';
  end if;
  if p_so_tien is null or p_so_tien < 0 then
    raise exception 'Số dư đầu kỳ không được âm.';
  end if;
  if p_ngay is null then
    raise exception 'Vui lòng chọn ngày của số dư đầu kỳ.';
  end if;

  -- CHỐT CHẶN: chỉ người phụ trách chính nguồn đó (hoặc KTT/Chủ tịch/Quản trị).
  -- Dùng đúng hàm mà view đang dùng — quyền xem và quyền nhập đi cùng nhau,
  -- không thể lệch.
  if not private.duoc_xem_nguon_tien(p_quy_id, p_tk_id) then
    raise exception 'Bạn không phụ trách nguồn tiền này nên không nhập được số dư đầu kỳ.'
      using errcode = '42501';
  end if;

  select * into v_cu from public.ton_dau_ky
   where quy_tien_mat_id is not distinct from p_quy_id
     and tai_khoan_ngan_hang_id is not distinct from p_tk_id;

  if found then
    update public.ton_dau_ky
       set so_tien = p_so_tien, ngay = p_ngay
     where id = v_cu.id
     returning id into v_id;
    perform private.ghi_nhat_ky('ton_dau_ky', v_id, 'sua_ton_dau_ky',
      to_jsonb(v_cu), jsonb_build_object('so_tien', p_so_tien, 'ngay', p_ngay));
  else
    insert into public.ton_dau_ky (quy_tien_mat_id, tai_khoan_ngan_hang_id, so_tien, ngay, nguoi_tao_id)
    values (p_quy_id, p_tk_id, p_so_tien, p_ngay, v_toi)
    returning id into v_id;
    perform private.ghi_nhat_ky('ton_dau_ky', v_id, 'tao_ton_dau_ky',
      null, jsonb_build_object('so_tien', p_so_tien, 'ngay', p_ngay,
                               'quy_tien_mat_id', p_quy_id, 'tai_khoan_ngan_hang_id', p_tk_id));
  end if;

  return v_id;
end;
$$;


--
-- Name: FUNCTION luu_ton_dau_ky(p_quy_id uuid, p_tk_id uuid, p_so_tien public.tien_te, p_ngay date); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.luu_ton_dau_ky(p_quy_id uuid, p_tk_id uuid, p_so_tien public.tien_te, p_ngay date) IS 'Nhập / sửa số dư đầu kỳ của MỘT nguồn tiền. Chỉ người phụ trách nguồn đó, hoặc KTT/Chủ tịch/Quản trị. Mỗi nguồn một dòng (unique index từ mig 05) nên gọi lại là sửa. Ghi nhật ký cả hai chiều (mig 35).';


--
-- Name: tao_chuyen_quy(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.tao_chuyen_quy(p_payload jsonb) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_toi     uuid := private.nhan_vien_hien_tai();
  v_tu_quy  uuid := nullif(p_payload->>'tu_quy_tien_mat_id', '')::uuid;
  v_tu_tk   uuid := nullif(p_payload->>'tu_tai_khoan_ngan_hang_id', '')::uuid;
  v_den_quy uuid := nullif(p_payload->>'den_quy_tien_mat_id', '')::uuid;
  v_den_tk  uuid := nullif(p_payload->>'den_tai_khoan_ngan_hang_id', '')::uuid;
  v_so_tien public.tien_te := (p_payload->>'so_tien')::public.tien_te;
  v_ngay    date := coalesce((p_payload->>'ngay')::date, current_date);
  v_du      numeric;
  v_ma_cty  text;
  v_so      text;
  v_id      uuid;
  v_ct      jsonb;
begin
  if v_toi is null then
    raise exception 'Phiên đăng nhập không hợp lệ.' using errcode = '42501';
  end if;

  -- Vai trò: duyệt và thao tác tiền là hai việc khác nhau (QĐ-02) nên Chủ tịch
  -- KHÔNG nằm ở đây, dù hàm duoc_xem_nguon_tien() có mở cho Chủ tịch xem.
  if not private.co_mot_trong_vai_tro(
       array['ke_toan_thanh_toan', 'ke_toan_truong', 'quan_tri']) then
    raise exception 'Chỉ Kế toán thanh toán, Kế toán trưởng và Quản trị được chuyển quỹ.'
      using errcode = '42501';
  end if;

  if num_nonnulls(v_tu_quy, v_tu_tk) <> 1 then
    raise exception 'Chọn đúng một nguồn tiền để chuyển ĐI.';
  end if;
  if num_nonnulls(v_den_quy, v_den_tk) <> 1 then
    raise exception 'Chọn đúng một nguồn tiền để chuyển ĐẾN.';
  end if;
  if (v_tu_quy is not null and v_tu_quy = v_den_quy)
     or (v_tu_tk is not null and v_tu_tk = v_den_tk) then
    raise exception 'Nguồn đi và nguồn đến phải khác nhau.';
  end if;
  if v_so_tien is null or v_so_tien <= 0 then
    raise exception 'Số tiền chuyển phải lớn hơn 0.';
  end if;
  if coalesce(btrim(p_payload->>'dien_giai'), '') = '' then
    raise exception 'Vui lòng nhập diễn giải.';
  end if;

  -- CHỐT CHẶN CHÍNH: tiền rời khỏi nguồn nào thì phải được gán nguồn đó.
  if not private.duoc_xem_nguon_tien(v_tu_quy, v_tu_tk) then
    raise exception 'Bạn không phụ trách nguồn tiền này nên không chuyển đi được. Nhờ Quản trị gán nguồn tiền cho bạn.'
      using errcode = '42501';
  end if;

  -- Không cho chuyển quá số dư — cùng luật với chi tiền (tra_tien_dot).
  v_du := private.so_du_nguon_tien(v_tu_quy, v_tu_tk);
  if v_du < v_so_tien then
    raise exception 'Nguồn tiền chỉ còn % đ, không đủ để chuyển % đ.',
      to_char(v_du, 'FM999,999,999,999'), to_char(v_so_tien, 'FM999,999,999,999');
  end if;

  -- Số chứng từ theo công ty của NGUỒN ĐI; quỹ tiền mặt dùng chung -> mã QC.
  if v_tu_tk is not null then
    select c.ma into v_ma_cty
    from public.tai_khoan_ngan_hang tk
    join public.cong_ty c on c.id = tk.cong_ty_id
    where tk.id = v_tu_tk;
  end if;
  v_ma_cty := coalesce(v_ma_cty, 'QC');
  v_so := private.sinh_so_de_nghi('chuyen_quy', v_ma_cty, extract(year from v_ngay)::int);

  insert into public.chuyen_quy (
    so_phieu, ngay, so_tien,
    tu_quy_tien_mat_id, tu_tai_khoan_ngan_hang_id,
    den_quy_tien_mat_id, den_tai_khoan_ngan_hang_id,
    dien_giai, nguoi_lap_id
  )
  values (
    v_so, v_ngay, v_so_tien,
    v_tu_quy, v_tu_tk, v_den_quy, v_den_tk,
    btrim(p_payload->>'dien_giai'), v_toi
  )
  returning id into v_id;

  -- Chứng từ đính kèm (tùy chọn): giấy nộp tiền, UNC nội bộ.
  for v_ct in select * from jsonb_array_elements(coalesce(p_payload->'chung_tu_fmb', '[]'::jsonb))
  loop
    insert into public.chung_tu_fmb (chuyen_quy_id, ten_file, duong_dan, loai_file, nguoi_tai_len_id)
    values (v_id, v_ct->>'ten_file', v_ct->>'duong_dan', nullif(v_ct->>'loai_file', ''), v_toi);
  end loop;

  perform private.ghi_nhat_ky('chuyen_quy', v_id, 'tao_chuyen_quy',
    null, p_payload || jsonb_build_object('so_phieu', v_so));

  return v_id;
end;
$$;


--
-- Name: FUNCTION tao_chuyen_quy(p_payload jsonb); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.tao_chuyen_quy(p_payload jsonb) IS 'Chuyển tiền giữa hai nguồn: kiểm vai trò + phải được gán NGUỒN ĐI, kiểm số dư, ghi một dòng chuyen_quy (v_so_quy nở thành hai vế) + chứng từ + nhật ký. Mig 36.';


--
-- Name: tao_nop_lai_tien_thua(uuid, numeric, date, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.tao_nop_lai_tien_thua(p_de_nghi_tam_ung_id uuid, p_so_tien numeric, p_ngay_thu date DEFAULT NULL::date, p_quy_id uuid DEFAULT NULL::uuid, p_tk_id uuid DEFAULT NULL::uuid) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_toi     uuid := private.nhan_vien_hien_tai();
  v_dn      public.de_nghi%rowtype;
  v_kmt     uuid;
  v_con_no  numeric;
  v_pt_id   uuid;
  v_la_ke_toan boolean := private.co_mot_trong_vai_tro(
    array['ke_toan_truong','ke_toan_thanh_toan','quan_tri']);
begin
  if num_nonnulls(p_quy_id, p_tk_id) <> 1 then
    raise exception 'Vui lòng chọn đúng một nguồn tiền: quỹ tiền mặt hoặc tài khoản ngân hàng.';
  end if;

  select * into v_dn from public.de_nghi where id = p_de_nghi_tam_ung_id;
  if not found or v_dn.loai <> 'tam_ung' then
    raise exception 'Không tìm thấy đề nghị tạm ứng.';
  end if;

  -- Người nhập: chính người nhận ứng, hoặc kế toán lập hộ (nhiều nhân viên chưa
  -- có tài khoản đăng nhập).
  if v_dn.nhan_vien_nhan_ung_id is distinct from v_toi and not v_la_ke_toan then
    raise exception 'Chỉ người nhận tạm ứng hoặc kế toán mới lập được phiếu nộp lại cho khoản này.'
      using errcode = '42501';
  end if;

  if p_so_tien <= 0 then
    raise exception 'Số tiền nộp lại phải lớn hơn 0.';
  end if;

  select con_no into v_con_no
  from public.v_cong_no_tam_ung where de_nghi_tam_ung_id = p_de_nghi_tam_ung_id;
  if v_con_no is null or v_con_no <= 0 then
    raise exception 'Khoản tạm ứng này không còn tiền thừa để nộp lại (công nợ hiện tại: % đ).', coalesce(v_con_no, 0);
  end if;
  if p_so_tien > v_con_no then
    raise exception 'Nộp lại % đ nhưng chỉ còn thừa % đ.', p_so_tien, v_con_no;
  end if;

  select id into v_kmt from public.khoan_muc_thu where la_he_thong;
  if v_kmt is null then
    raise exception 'Thiếu khoản mục thu hệ thống (thu hoàn ứng). Báo quản trị viên.';
  end if;

  insert into public.phieu_thu (
    cong_ty_id, khoan_muc_thu_id, so_tien, ngay_thu,
    quy_tien_mat_id, tai_khoan_ngan_hang_id,
    doi_tac_loai, doi_tac_id, dien_giai,
    de_nghi_tam_ung_goc_id, trang_thai, nguoi_lap_id
  )
  values (
    v_dn.cong_ty_id, v_kmt, p_so_tien::public.tien_te, coalesce(p_ngay_thu, current_date),
    p_quy_id, p_tk_id,
    'nhan_vien', v_dn.nhan_vien_nhan_ung_id,
    'Nộp lại tiền tạm ứng thừa - ' || v_dn.so_de_nghi,
    p_de_nghi_tam_ung_id, 'nhap', v_toi
  )
  returning id into v_pt_id;

  perform private.ghi_nhat_ky('phieu_thu', v_pt_id, 'tao_nop_lai_nhap',
    null, jsonb_build_object('de_nghi_tam_ung_id', p_de_nghi_tam_ung_id, 'so_tien', p_so_tien));

  return v_pt_id;
end;
$$;


--
-- Name: FUNCTION tao_nop_lai_tien_thua(p_de_nghi_tam_ung_id uuid, p_so_tien numeric, p_ngay_thu date, p_quy_id uuid, p_tk_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.tao_nop_lai_tien_thua(p_de_nghi_tam_ung_id uuid, p_so_tien numeric, p_ngay_thu date, p_quy_id uuid, p_tk_id uuid) IS 'BƯỚC 1 nộp lại tiền ứng thừa: người nhận ứng (hoặc kế toán lập hộ) tạo phiếu thu THU_HOAN_UNG NHÁP. Chưa giảm công nợ — chờ KTT xác nhận (QĐ-19).';


--
-- Name: tao_phieu_thu(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.tao_phieu_thu(p_payload jsonb) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_toi        uuid := private.nhan_vien_hien_tai();
  v_id         uuid;
  v_cong_ty_id uuid := nullif(p_payload->>'cong_ty_id', '')::uuid;
  v_du_an_id   uuid := nullif(p_payload->>'du_an_id', '')::uuid;
  v_bat_buoc   boolean;
  v_ma_cty     text;
  v_so         text;
  v_ct         jsonb;
begin
  if not private.co_mot_trong_vai_tro(array['ke_toan_thanh_toan', 'ke_toan_truong']) then
    raise exception 'Chỉ Kế toán thanh toán và Kế toán trưởng được lập phiếu thu.'
      using errcode = '42501';
  end if;

  -- MIG 46 — khoản mục đánh dấu thì phải biết tiền của công trình nào, khách
  -- hàng nào. Không hỏi lúc lập thì sau này phải mò lại từng phiếu.
  select kmt.bat_buoc_cong_trinh into v_bat_buoc
  from public.khoan_muc_thu kmt
  where kmt.id = (p_payload->>'khoan_muc_thu_id')::uuid;

  if coalesce(v_bat_buoc, false) then
    if v_du_an_id is null then
      raise exception 'Khoản mục này bắt buộc gắn công trình — vui lòng chọn công trình.';
    end if;
    if nullif(p_payload->>'doi_tac_loai', '') is distinct from 'khach_hang'
       or nullif(p_payload->>'doi_tac_id', '') is null then
      raise exception 'Khoản mục này bắt buộc gắn khách hàng — vui lòng chọn khách hàng ở ô Đối tác.';
    end if;
  end if;

  if v_du_an_id is not null
     and not exists (select 1 from public.du_an da where da.id = v_du_an_id and da.dang_dung) then
    raise exception 'Công trình đã chọn không tồn tại hoặc đã ngừng dùng. Vui lòng tải lại trang.';
  end if;

  if v_cong_ty_id is null then
    v_ma_cty := 'QC';
  else
    select ma into v_ma_cty from public.cong_ty where id = v_cong_ty_id;
  end if;
  v_so := private.sinh_so_de_nghi('phieu_thu', v_ma_cty, extract(year from current_date)::int);

  insert into public.phieu_thu (
    cong_ty_id, khoan_muc_thu_id, so_tien, ngay_thu,
    quy_tien_mat_id, tai_khoan_ngan_hang_id,
    doi_tac_loai, doi_tac_id, doi_tac_ten, dien_giai,
    de_nghi_tam_ung_goc_id, so_phieu, trang_thai,
    nguoi_lap_id, nguoi_xac_nhan_id, xac_nhan_luc,
    doi_tuong_vay_id, du_an_id,
    xac_nhan_khong_trung_nhap_quy
  )
  values (
    v_cong_ty_id,
    (p_payload->>'khoan_muc_thu_id')::uuid,
    (p_payload->>'so_tien')::public.tien_te,
    coalesce((p_payload->>'ngay_thu')::date, current_date),
    nullif(p_payload->>'quy_tien_mat_id', '')::uuid,
    nullif(p_payload->>'tai_khoan_ngan_hang_id', '')::uuid,
    nullif(p_payload->>'doi_tac_loai', ''),
    nullif(p_payload->>'doi_tac_id', '')::uuid,
    nullif(p_payload->>'doi_tac_ten', ''),
    p_payload->>'dien_giai',
    nullif(p_payload->>'de_nghi_tam_ung_goc_id', '')::uuid,
    v_so, 'da_thu',
    v_toi, v_toi, now(),
    nullif(p_payload->>'doi_tuong_vay_id', '')::uuid,
    v_du_an_id,
    -- MIG 55: mặc định false. Chỉ true khi người lập đã nhìn cảnh báo trùng và
    -- tích ô khẳng định đây là khoản tiền khác.
    coalesce((p_payload->>'xac_nhan_khong_trung_nhap_quy')::boolean, false)
  )
  returning id into v_id;

  -- Chứng từ TÙY CHỌN: mảng rỗng/null thì vòng lặp 0 dòng.
  for v_ct in select * from jsonb_array_elements(coalesce(p_payload->'chung_tu_fmb', '[]'::jsonb))
  loop
    insert into public.chung_tu_fmb (phieu_thu_id, ten_file, duong_dan, loai_file, nguoi_tai_len_id)
    values (v_id, v_ct->>'ten_file', v_ct->>'duong_dan', nullif(v_ct->>'loai_file',''), v_toi);
  end loop;

  perform private.ghi_nhat_ky('phieu_thu', v_id, 'tao_va_thu',
    null, p_payload || jsonb_build_object('so_phieu', v_so));
  return v_id;
end;
$$;


--
-- Name: FUNCTION tao_phieu_thu(p_payload jsonb); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.tao_phieu_thu(p_payload jsonb) IS 'Lập phiếu thu 1 bước (sinh số + da_thu). Chứng từ ảnh tùy chọn. Mig 38: doi_tuong_vay_id cho khoản vay. Mig 46: du_an_id; khoản mục có bat_buoc_cong_trinh thì BẮT BUỘC công trình + khách hàng. Mig 55: xac_nhan_khong_trung_nhap_quy để qua được trigger chặn nhập quỹ trùng. QĐ-02: chỉ KTT/KTTT.';


--
-- Name: tao_sua_de_nghi_nhap(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.tao_sua_de_nghi_nhap(p_payload jsonb) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_toi     uuid := private.nhan_vien_hien_tai();
  v_id      uuid := nullif(p_payload->>'id', '')::uuid;
  v_loai    text := p_payload->>'loai';
  v_muc     jsonb := coalesce(p_payload->'muc', '[]'::jsonb);
  v_cu      jsonb;
  v_stt     int := 0;
  v_item    jsonb;
begin
  if v_toi is null then
    raise exception 'Bạn chưa đăng nhập hoặc tài khoản chưa được nối với nhân viên.'
      using errcode = '42501';
  end if;

  if jsonb_array_length(v_muc) = 0 then
    raise exception 'Đề nghị phải có ít nhất một mục trong bảng kê.';
  end if;

  if v_id is null then
    insert into public.de_nghi (
      loai, cong_ty_id, nguoi_de_xuat_id, noi_dung, ngay_de_nghi,
      nhan_vien_nhan_ung_id, han_hoan_ung, de_nghi_tam_ung_goc_id,
      doi_tac_loai, doi_tac_id, doi_tac_ten,
      trang_thai, nguoi_tao_id,
      doi_tuong_vay_id
    )
    values (
      v_loai,
      (p_payload->>'cong_ty_id')::uuid,
      v_toi,
      p_payload->>'noi_dung',
      coalesce((p_payload->>'ngay_de_nghi')::date, current_date),
      nullif(p_payload->>'nhan_vien_nhan_ung_id','')::uuid,
      nullif(p_payload->>'han_hoan_ung','')::date,
      nullif(p_payload->>'de_nghi_tam_ung_goc_id','')::uuid,
      nullif(p_payload->>'doi_tac_loai',''),
      nullif(p_payload->>'doi_tac_id','')::uuid,
      nullif(p_payload->>'doi_tac_ten',''),
      'nhap', v_toi,
      -- Đối tượng vay (mig 38): chỉ dùng cho đề nghị trả nợ / cho vay. Đề nghị
      -- thường thì null, luồng chạy y như trước.
      nullif(p_payload->>'doi_tuong_vay_id','')::uuid
    )
    returning id into v_id;
  else
    select to_jsonb(dn) into v_cu from public.de_nghi dn where dn.id = v_id;
    if v_cu is null then
      raise exception 'Không tìm thấy đề nghị.';
    end if;
    if (v_cu->>'nguoi_de_xuat_id')::uuid <> v_toi then
      raise exception 'Bạn chỉ sửa được đề nghị do chính mình lập.' using errcode = '42501';
    end if;
    -- ĐỔI Ở ĐÂY: cho sửa cả khi bị từ chối (để giải trình gửi lại).
    if v_cu->>'trang_thai' not in ('nhap', 'bi_tu_choi') then
      raise exception 'Đề nghị đang duyệt hoặc đã xử lý thì không sửa được nữa.';
    end if;

    update public.de_nghi set
      cong_ty_id             = (p_payload->>'cong_ty_id')::uuid,
      noi_dung               = p_payload->>'noi_dung',
      ngay_de_nghi           = coalesce((p_payload->>'ngay_de_nghi')::date, current_date),
      nhan_vien_nhan_ung_id  = nullif(p_payload->>'nhan_vien_nhan_ung_id','')::uuid,
      han_hoan_ung           = nullif(p_payload->>'han_hoan_ung','')::date,
      de_nghi_tam_ung_goc_id = nullif(p_payload->>'de_nghi_tam_ung_goc_id','')::uuid,
      doi_tac_loai           = nullif(p_payload->>'doi_tac_loai',''),
      doi_tac_id             = nullif(p_payload->>'doi_tac_id','')::uuid,
      doi_tac_ten            = nullif(p_payload->>'doi_tac_ten',''),
      doi_tuong_vay_id       = nullif(p_payload->>'doi_tuong_vay_id','')::uuid
    where id = v_id;

    delete from public.muc_de_nghi where de_nghi_id = v_id;
  end if;

  for v_item in select * from jsonb_array_elements(v_muc)
  loop
    v_stt := v_stt + 1;
    insert into public.muc_de_nghi (
      de_nghi_id, thu_tu, khoan_muc_chi_id, du_an_id, dien_giai, so_tien
    )
    values (
      v_id, v_stt,
      (v_item->>'khoan_muc_chi_id')::uuid,
      nullif(v_item->>'du_an_id','')::uuid,
      v_item->>'dien_giai',
      (v_item->>'so_tien')::public.tien_te
    );
  end loop;

  perform private.ghi_nhat_ky('de_nghi', v_id,
    case when v_cu is null then 'tao_nhap' else 'sua_nhap' end,
    v_cu, p_payload);

  return v_id;
end;
$$;


--
-- Name: FUNCTION tao_sua_de_nghi_nhap(p_payload jsonb); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.tao_sua_de_nghi_nhap(p_payload jsonb) IS 'Tạo hoặc sửa đề nghị còn nháp / bị từ chối. Mig 38: nhận thêm doi_tuong_vay_id cho đề nghị trả nợ vay hoặc cho vay.';


--
-- Name: tra_tam_ung_cap_tru(uuid, jsonb, jsonb, jsonb, date, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.tra_tam_ung_cap_tru(p_dot_id uuid, p_chi_tiet jsonb, p_cap_tru jsonb, p_chung_tu jsonb DEFAULT '[]'::jsonb, p_ngay_tra date DEFAULT NULL::date, p_quy_id uuid DEFAULT NULL::uuid, p_tk_id uuid DEFAULT NULL::uuid) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_toi        uuid := private.nhan_vien_hien_tai();
  v_dot        public.dot_duyet%rowtype;
  v_dn_moi     public.de_nghi%rowtype;
  v_dn_cu      public.de_nghi%rowtype;
  v_item       jsonb;
  v_so_tien    numeric;
  v_con_no     numeric;
  v_tong_ct    numeric := 0;   -- tổng cấn trừ
  v_tong_tra   numeric := 0;   -- tổng số trả cho đợt mới
  v_kmt        uuid;
  v_ma_cty     text;
  v_so         text;
  v_pt_id      uuid;
  v_pt_ids     uuid[] := array[]::uuid[];
  v_ngay       date := coalesce(p_ngay_tra, current_date);
  v_ltt_id     uuid;
begin
  perform private.bat_buoc_vai_tro('ke_toan_thanh_toan', 'xác nhận thanh toán');

  if num_nonnulls(p_quy_id, p_tk_id) <> 1 then
    raise exception 'Vui lòng chọn đúng một nguồn tiền: quỹ tiền mặt hoặc tài khoản ngân hàng.';
  end if;
  if p_cap_tru is null or jsonb_array_length(p_cap_tru) = 0 then
    raise exception 'Không có khoản nào để cấn trừ. Dùng chức năng trả tiền thường.';
  end if;

  select * into v_dot from public.dot_duyet where id = p_dot_id;
  if not found then
    raise exception 'Không tìm thấy đợt duyệt.';
  end if;
  select * into v_dn_moi from public.de_nghi where id = v_dot.de_nghi_id;
  if v_dn_moi.loai <> 'tam_ung' then
    raise exception 'Chỉ cấn trừ được giữa các khoản TẠM ỨNG. Đợt này thuộc đề nghị loại "%".',
      v_dn_moi.loai;
  end if;

  -- Tổng số sắp trả cho đợt mới — cấn trừ không được vượt quá số này.
  for v_item in select * from jsonb_array_elements(p_chi_tiet)
  loop
    v_tong_tra := v_tong_tra + (v_item->>'so_tien')::numeric;
  end loop;

  select id into v_kmt from public.khoan_muc_thu where la_he_thong;
  if v_kmt is null then
    raise exception 'Thiếu khoản mục thu hệ thống (thu hoàn ứng). Báo quản trị viên.';
  end if;

  -- ---------------------------------------------------------------------------
  -- VẾ 1 — tất toán các khoản ứng cũ bằng phiếu thu hoàn ứng (không tiền mặt)
  -- ---------------------------------------------------------------------------
  for v_item in select * from jsonb_array_elements(p_cap_tru)
  loop
    v_so_tien := (v_item->>'so_tien')::numeric;
    if v_so_tien is null or v_so_tien <= 0 then
      raise exception 'Số tiền cấn trừ phải lớn hơn 0.';
    end if;

    -- Khóa khoản cũ trước khi đọc công nợ: hai người cùng cấn trừ một khoản thì
    -- không được cùng đọc một số dư rồi cùng ghi (kỷ luật FOR UPDATE của mig 12).
    select * into v_dn_cu from public.de_nghi
    where id = (v_item->>'de_nghi_tam_ung_id')::uuid
    for update;

    if not found then
      raise exception 'Không tìm thấy khoản tạm ứng cần cấn trừ.';
    end if;
    if v_dn_cu.loai <> 'tam_ung' then
      raise exception 'Khoản cấn trừ phải là đề nghị tạm ứng.';
    end if;
    if v_dn_cu.id = v_dn_moi.id then
      raise exception 'Không cấn trừ một khoản tạm ứng vào chính nó.';
    end if;
    -- Chốt quan trọng nhất: tiền thừa của người này KHÔNG được gán sang người
    -- khác. Cấn trừ chéo người là làm sai công nợ của cả hai.
    if v_dn_cu.nhan_vien_nhan_ung_id is distinct from v_dn_moi.nhan_vien_nhan_ung_id then
      raise exception 'Chỉ cấn trừ được giữa các khoản tạm ứng của CÙNG một người nhận ứng.';
    end if;

    select con_no into v_con_no
    from public.v_cong_no_tam_ung where de_nghi_tam_ung_id = v_dn_cu.id;
    if v_con_no is null or v_con_no <= 0 then
      raise exception 'Khoản % không còn tiền thừa để cấn trừ (công nợ hiện tại % đ).',
        coalesce(v_dn_cu.so_de_nghi, '(chưa có số)'), coalesce(v_con_no, 0);
    end if;
    if v_so_tien > v_con_no then
      raise exception 'Cấn trừ % đ từ khoản % nhưng khoản đó chỉ còn thừa % đ.',
        v_so_tien, coalesce(v_dn_cu.so_de_nghi, '(chưa có số)'), v_con_no;
    end if;

    -- Thu vào tài khoản ngân hàng thì bảng phieu_thu bắt buộc có công ty.
    if p_tk_id is not null and v_dn_cu.cong_ty_id is null then
      raise exception 'Khoản % chưa gắn công ty nên không cấn trừ qua tài khoản ngân hàng được.',
        coalesce(v_dn_cu.so_de_nghi, '(chưa có số)');
    end if;

    if v_dn_cu.cong_ty_id is null then
      v_ma_cty := 'QC';
    else
      select ma into v_ma_cty from public.cong_ty where id = v_dn_cu.cong_ty_id;
    end if;
    v_so := private.sinh_so_de_nghi('phieu_thu', v_ma_cty, extract(year from v_ngay)::int);

    insert into public.phieu_thu (
      so_phieu, cong_ty_id, khoan_muc_thu_id, so_tien, ngay_thu,
      quy_tien_mat_id, tai_khoan_ngan_hang_id,
      doi_tac_loai, doi_tac_id, dien_giai,
      de_nghi_tam_ung_goc_id, trang_thai,
      nguoi_lap_id, nguoi_xac_nhan_id, xac_nhan_luc
    )
    values (
      v_so, v_dn_cu.cong_ty_id, v_kmt, v_so_tien::public.tien_te, v_ngay,
      p_quy_id, p_tk_id,
      'nhan_vien', v_dn_cu.nhan_vien_nhan_ung_id,
      'Cấn trừ sang ' || coalesce(v_dn_moi.so_de_nghi, 'đợt ứng mới')
        || ' — giữ lại tiền thừa của ' || coalesce(v_dn_cu.so_de_nghi, '(chưa có số)')
        || ', KHÔNG thu tiền mặt',
      v_dn_cu.id, 'da_thu',
      v_toi, v_toi, now()
    )
    returning id into v_pt_id;

    v_pt_ids := array_append(v_pt_ids, v_pt_id);
    v_tong_ct := v_tong_ct + v_so_tien;

    perform private.ghi_nhat_ky('phieu_thu', v_pt_id, 'cap_tru_tam_ung',
      null, jsonb_build_object('de_nghi_cu', v_dn_cu.id, 'dot_moi', p_dot_id,
                               'so_tien', v_so_tien, 'so_phieu', v_so));
  end loop;

  if v_tong_ct > v_tong_tra then
    raise exception 'Cấn trừ % đ nhưng đợt ứng mới chỉ có % đ. Không cấn trừ nhiều hơn số đang ứng — phần thừa còn lại phải nộp lại bằng tiền.',
      v_tong_ct, v_tong_tra;
  end if;

  -- ---------------------------------------------------------------------------
  -- VẾ 2 — trả TRỌN số duyệt của đợt mới
  -- ---------------------------------------------------------------------------
  -- Gọi lại tra_tien_dot chứ không chép logic: mọi chốt chặn của nó (đợt đã
  -- duyệt, không trả vượt từng mục, khóa nguồn tiền, kiểm số dư) phải áp y hệt.
  -- Vế 1 đã cộng tiền cấn trừ vào nguồn nên phép kiểm số dư ở đó chỉ thực sự đòi
  -- phần chênh — đúng bằng tiền mặt sắp rời két.
  v_ltt_id := public.tra_tien_dot(p_dot_id, p_chi_tiet, p_chung_tu, v_ngay, p_quy_id, p_tk_id);

  -- Nối hai vế lại. Làm sau vì lần trả chưa tồn tại lúc lập phiếu thu.
  update public.phieu_thu
  set cap_tru_lan_tra_id = v_ltt_id
  where id = any (v_pt_ids);

  perform private.ghi_nhat_ky('lan_tra_tien', v_ltt_id, 'tra_tam_ung_cap_tru',
    null, jsonb_build_object('dot_duyet_id', p_dot_id, 'tong_tra', v_tong_tra,
                             'tong_cap_tru', v_tong_ct,
                             'tien_mat_thuc_chi', v_tong_tra - v_tong_ct,
                             'phieu_thu_ids', to_jsonb(v_pt_ids)));

  return v_ltt_id;
end;
$$;


--
-- Name: FUNCTION tra_tam_ung_cap_tru(p_dot_id uuid, p_chi_tiet jsonb, p_cap_tru jsonb, p_chung_tu jsonb, p_ngay_tra date, p_quy_id uuid, p_tk_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.tra_tam_ung_cap_tru(p_dot_id uuid, p_chi_tiet jsonb, p_cap_tru jsonb, p_chung_tu jsonb, p_ngay_tra date, p_quy_id uuid, p_tk_id uuid) IS 'Trả một đợt tạm ứng có CẤN TRỪ tiền thừa của khoản ứng cũ cùng người: ghi hai vế (phiếu thu hoàn ứng không tiền mặt + lần trả trọn số duyệt) trong một transaction. Tiền mặt thật rời quỹ = số duyệt − số cấn trừ. Chỉ KTTT — mig 39.';


--
-- Name: tra_tien_dot(uuid, jsonb, jsonb, date, uuid, uuid, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.tra_tien_dot(p_dot_id uuid, p_chi_tiet jsonb, p_chung_tu jsonb, p_ngay_tra date DEFAULT NULL::date, p_quy_id uuid DEFAULT NULL::uuid, p_tk_id uuid DEFAULT NULL::uuid, p_bu_cong_no_am boolean DEFAULT true) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_toi       uuid := private.nhan_vien_hien_tai();
  v_dot       public.dot_duyet%rowtype;
  v_tong      public.tien_te := 0;
  v_so_du     numeric;
  v_ltt_id    uuid;
  v_item      jsonb;
  v_muc       record;
  v_ngay      date := coalesce(p_ngay_tra, current_date);
  v_loai      text;
  v_goc_id    uuid;
  v_con_no    numeric;
  v_nguoi_ung uuid;
  v_so_dn     text;
  v_quy_ct    uuid;
  v_bt_id     uuid;
begin
  perform private.bat_buoc_vai_tro('ke_toan_thanh_toan', 'xác nhận thanh toán');

  if num_nonnulls(p_quy_id, p_tk_id) <> 1 then
    raise exception 'Vui lòng chọn đúng một nguồn tiền: quỹ tiền mặt hoặc tài khoản ngân hàng.';
  end if;
  if p_chi_tiet is null or jsonb_array_length(p_chi_tiet) = 0 then
    raise exception 'Vui lòng chọn ít nhất một mục để trả tiền.';
  end if;

  select * into v_dot from public.dot_duyet where id = p_dot_id;
  if not found then
    raise exception 'Không tìm thấy đợt duyệt.';
  end if;
  if v_dot.trang_thai <> 'da_duyet' then
    raise exception 'Chỉ trả tiền được cho đợt đã được Chủ tịch duyệt. Đợt này đang ở trạng thái "%".', v_dot.trang_thai;
  end if;

  select dn.loai, dn.de_nghi_tam_ung_goc_id, dn.nhan_vien_nhan_ung_id, dn.so_de_nghi
  into v_loai, v_goc_id, v_nguoi_ung, v_so_dn
  from public.de_nghi dn where dn.id = v_dot.de_nghi_id;

  if p_quy_id is not null then
    perform 1 from public.quy_tien_mat where id = p_quy_id for update;
  else
    perform 1 from public.tai_khoan_ngan_hang where id = p_tk_id for update;
  end if;

  if v_loai = 'quyet_toan' and v_goc_id is not null then
    perform 1 from public.de_nghi where id = v_goc_id for update;
  end if;

  for v_item in select * from jsonb_array_elements(p_chi_tiet)
  loop
    select m.id, m.dien_giai, m.dot_duyet_id, m.tu_choi_luc, v.so_tien_con_no
    into v_muc
    from public.muc_de_nghi m
    join public.v_muc_tong_hop v on v.muc_id = m.id
    where m.id = (v_item->>'muc_de_nghi_id')::uuid;

    if not found then
      raise exception 'Không tìm thấy mục cần trả. Vui lòng tải lại trang.';
    end if;
    if v_muc.dot_duyet_id is distinct from p_dot_id then
      raise exception 'Mục "%" không thuộc đợt duyệt này.', v_muc.dien_giai;
    end if;
    if v_muc.tu_choi_luc is not null then
      raise exception 'Mục "%" đã bị từ chối, không trả tiền được.', v_muc.dien_giai;
    end if;
    if (v_item->>'so_tien')::public.tien_te <= 0 then
      raise exception 'Mục "%": số tiền trả phải lớn hơn 0.', v_muc.dien_giai;
    end if;
    if (v_item->>'so_tien')::public.tien_te > v_muc.so_tien_con_no then
      raise exception 'Mục "%": trả % đ nhưng chỉ còn nợ % đ. Không được trả vượt số đã duyệt — muốn trả thêm phải lập đề nghị bổ sung.',
        v_muc.dien_giai, (v_item->>'so_tien')::public.tien_te, v_muc.so_tien_con_no;
    end if;

    v_tong := v_tong + (v_item->>'so_tien')::public.tien_te;
  end loop;

  if v_tong <= 0 then
    raise exception 'Tổng số tiền trả phải lớn hơn 0.';
  end if;

  if v_loai = 'quyet_toan' and v_goc_id is not null then
    select con_no into v_con_no
    from public.v_cong_no_tam_ung where de_nghi_tam_ung_id = v_goc_id;

    if v_con_no is null then
      raise exception 'Không tìm thấy công nợ tạm ứng gốc để đối chiếu trả bù.';
    end if;

    if v_tong > -v_con_no then
      if v_con_no >= 0 then
        raise exception 'Khoản tạm ứng này đã tất toán (công nợ % đ), không cần trả bù thêm.', v_con_no;
      else
        raise exception 'Trả bù % đ nhưng công ty chỉ còn nợ lại nhân viên % đ. Không được trả vượt phần thực nợ.',
          v_tong, -v_con_no;
      end if;
    end if;
  end if;

  v_so_du := private.so_du_nguon_tien(p_quy_id, p_tk_id);
  if v_so_du < v_tong then
    raise exception 'Không đủ tiền. Nguồn tiền còn % đ, cần trả % đ.', v_so_du, v_tong;
  end if;

  insert into public.lan_tra_tien (
    dot_duyet_id, so_tien, ngay_tra, quy_tien_mat_id, tai_khoan_ngan_hang_id, nguoi_xac_nhan_id
  )
  values (p_dot_id, v_tong, v_ngay, p_quy_id, p_tk_id, v_toi)
  returning id into v_ltt_id;

  insert into public.chi_tiet_lan_tra (lan_tra_tien_id, muc_de_nghi_id, dot_duyet_id, so_tien)
  select v_ltt_id, (x->>'muc_de_nghi_id')::uuid, p_dot_id, (x->>'so_tien')::public.tien_te
  from jsonb_array_elements(p_chi_tiet) x;

  for v_item in select * from jsonb_array_elements(coalesce(p_chung_tu, '[]'::jsonb))
  loop
    insert into public.chung_tu_fmb (lan_tra_tien_id, ten_file, duong_dan, loai_file, nguoi_tai_len_id)
    values (v_ltt_id, v_item->>'ten_file', v_item->>'duong_dan',
            nullif(v_item->>'loai_file',''), v_toi);
  end loop;

  perform private.ghi_nhat_ky('lan_tra_tien', v_ltt_id, 'tra_tien',
    null, jsonb_build_object('dot_duyet_id', p_dot_id, 'so_tien', v_tong,
                             'ngay_tra', v_ngay, 'chi_tiet', p_chi_tiet));

  -- MIG 42 — tạm ứng cho người quản lý quỹ: nhập thẳng vào quỹ đó (chỉ vế VÀO;
  -- vế RA đã là chính lan_tra_tien vừa ghi).
  if v_loai = 'tam_ung' and v_nguoi_ung is not null then
    v_quy_ct := private.quy_cua_nguoi_nhan_ung(v_nguoi_ung);

    if v_quy_ct is not null then
      insert into public.but_toan_quy_cong_truong (
        loai, quy_tien_mat_id, nhan_vien_id, de_nghi_tam_ung_goc_id,
        lan_tra_tien_id, so_tien, ngay, dien_giai, nguoi_tao_id
      )
      values (
        'nhap', v_quy_ct, v_nguoi_ung, v_dot.de_nghi_id,
        v_ltt_id, v_tong, v_ngay,
        'Nhập quỹ công trường — ' || coalesce(v_so_dn, ''), v_toi
      )
      returning id into v_bt_id;

      perform private.ghi_nhat_ky('but_toan_quy_cong_truong', v_bt_id, 'nhap_quy_cong_truong',
        null, jsonb_build_object('quy_tien_mat_id', v_quy_ct, 'so_tien', v_tong,
                                 'ngay', v_ngay, 'de_nghi', v_so_dn));
    end if;
  end if;

  -- MIG 43 — người này còn khoản ứng cũ ÂM thì phần vừa chi bù vào đó trước.
  -- Chỉ đổi sổ công nợ, không sinh bút toán tiền: tiền đã chuyển động ở chính
  -- lan_tra_tien phía trên.
  if p_bu_cong_no_am and v_loai = 'tam_ung' and v_nguoi_ung is not null then
    perform private.bu_cong_no_am_cho_nguoi(
      v_nguoi_ung, v_dot.de_nghi_id, v_ltt_id, v_tong, v_ngay, v_toi,
      'Tự bù khi chi đợt ứng ' || coalesce(v_so_dn, ''));
  end if;

  -- QUYẾT TOÁN: trả bù xong (công nợ gốc SAU trả bù về >= 0) -> đóng đợt luôn.
  if v_loai = 'quyet_toan' and v_goc_id is not null then
    select con_no into v_con_no
    from public.v_cong_no_tam_ung where de_nghi_tam_ung_id = v_goc_id;

    if v_con_no is not null and v_con_no >= 0 then
      update public.dot_duyet
      set trang_thai    = 'da_dong',
          ly_do_dong    = 'Đã trả bù đủ, công nợ tạm ứng về 0 — đóng đợt quyết toán.',
          nguoi_dong_id = v_toi,
          dong_luc      = now()
      where id = p_dot_id;

      perform private.ghi_nhat_ky('dot_duyet', p_dot_id, 'tu_dong_dong_quyet_toan_sau_tra_bu',
        null, jsonb_build_object('con_no', v_con_no, 'ltt_id', v_ltt_id));
    end if;
  end if;

  return v_ltt_id;
end;
$$;


--
-- Name: FUNCTION tra_tien_dot(p_dot_id uuid, p_chi_tiet jsonb, p_chung_tu jsonb, p_ngay_tra date, p_quy_id uuid, p_tk_id uuid, p_bu_cong_no_am boolean); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.tra_tien_dot(p_dot_id uuid, p_chi_tiet jsonb, p_chung_tu jsonb, p_ngay_tra date, p_quy_id uuid, p_tk_id uuid, p_bu_cong_no_am boolean) IS 'KTTT trả tiền cho đợt. Khóa nguồn tiền, chặn trả vượt/trả bù vượt, kiểm số dư; quyết toán trả bù xong tự đóng đợt (mig 27). Mig 42: tạm ứng cho người có quỹ thì ghi bút toán NHẬP quỹ công trường. Mig 43: tự bù khoản ứng cũ đang ÂM của cùng người (tắt được bằng p_bu_cong_no_am = false).';


--
-- Name: xac_nhan_nop_lai_tien_thua(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.xac_nhan_nop_lai_tien_thua(p_phieu_thu_id uuid) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_toi     uuid := private.nhan_vien_hien_tai();
  v_pt      public.phieu_thu%rowtype;
  v_kmt     uuid;
  v_con_no  numeric;
  v_ma_cty  text;
  v_so      text;
begin
  -- QĐ-19: KTT xác nhận. Thu tiền vào không cần Chủ tịch (QĐ-01).
  perform private.bat_buoc_vai_tro('ke_toan_truong', 'xác nhận nộp lại tiền tạm ứng');

  select * into v_pt from public.phieu_thu where id = p_phieu_thu_id;
  if not found then
    raise exception 'Không tìm thấy phiếu nộp lại.';
  end if;
  if v_pt.trang_thai <> 'nhap' then
    raise exception 'Phiếu nộp lại này đã ở trạng thái "%".', v_pt.trang_thai;
  end if;
  if v_pt.de_nghi_tam_ung_goc_id is null then
    raise exception 'Phiếu này không phải phiếu nộp lại tiền tạm ứng.';
  end if;
  select id into v_kmt from public.khoan_muc_thu where la_he_thong;
  if v_pt.khoan_muc_thu_id is distinct from v_kmt then
    raise exception 'Phiếu này không phải phiếu nộp lại tiền tạm ứng.';
  end if;

  -- Khóa tạm ứng gốc: hai lần xác nhận song song không cùng đọc một số công nợ rồi
  -- ghi nhận vượt (giống chốt trả bù ở migration 12).
  perform 1 from public.de_nghi where id = v_pt.de_nghi_tam_ung_goc_id for update;

  select con_no into v_con_no
  from public.v_cong_no_tam_ung where de_nghi_tam_ung_id = v_pt.de_nghi_tam_ung_goc_id;
  if v_con_no is null or v_con_no <= 0 then
    raise exception 'Khoản tạm ứng đã tất toán, không còn tiền thừa để ghi nhận nộp lại.';
  end if;
  if v_pt.so_tien > v_con_no then
    raise exception 'Nộp lại % đ nhưng khoản này chỉ còn thừa % đ. Công nợ đã thay đổi — mời kiểm lại.',
      v_pt.so_tien, v_con_no;
  end if;

  -- Thu vào quỹ chung không gắn công ty thì dùng mã QC.
  if v_pt.cong_ty_id is null then
    v_ma_cty := 'QC';
  else
    select ma into v_ma_cty from public.cong_ty where id = v_pt.cong_ty_id;
  end if;
  v_so := private.sinh_so_de_nghi('phieu_thu', v_ma_cty, extract(year from current_date)::int);

  update public.phieu_thu
  set so_phieu = v_so, trang_thai = 'da_thu',
      nguoi_xac_nhan_id = v_toi, xac_nhan_luc = now()
  where id = p_phieu_thu_id;

  perform private.ghi_nhat_ky('phieu_thu', p_phieu_thu_id, 'xac_nhan_nop_lai',
    to_jsonb(v_pt), jsonb_build_object('so_phieu', v_so));

  return v_so;
end;
$$;


--
-- Name: FUNCTION xac_nhan_nop_lai_tien_thua(p_phieu_thu_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.xac_nhan_nop_lai_tien_thua(p_phieu_thu_id uuid) IS 'BƯỚC 2 nộp lại tiền ứng thừa: KTT xác nhận đã nhận tiền -> phiếu da_thu, công nợ giảm. Khóa tạm ứng gốc FOR UPDATE + tái kiểm không vượt phần còn thừa (QĐ-19).';


--
-- Name: xac_nhan_phieu_thu(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.xac_nhan_phieu_thu(p_phieu_thu_id uuid) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_toi    uuid := private.nhan_vien_hien_tai();
  v_pt     public.phieu_thu%rowtype;
  v_ma_cty text;
  v_so     text;
begin
  -- QĐ-01: thu không cần duyệt, nhưng chỉ KTTT mới ghi tiền vào quỹ được.
  -- Đây là chốt chặn thay cho bước duyệt đã bỏ.
  perform private.bat_buoc_vai_tro('ke_toan_thanh_toan', 'xác nhận thu tiền');

  select * into v_pt from public.phieu_thu where id = p_phieu_thu_id;
  if not found then
    raise exception 'Không tìm thấy phiếu thu.';
  end if;
  if v_pt.trang_thai <> 'nhap' then
    raise exception 'Phiếu thu này đã ở trạng thái "%".', v_pt.trang_thai;
  end if;

  -- Thu vào quỹ chung không gắn công ty thì dùng mã QC.
  if v_pt.cong_ty_id is null then
    v_ma_cty := 'QC';
  else
    select ma into v_ma_cty from public.cong_ty where id = v_pt.cong_ty_id;
  end if;

  v_so := private.sinh_so_de_nghi('phieu_thu', v_ma_cty, extract(year from current_date)::int);

  update public.phieu_thu
  set so_phieu = v_so, trang_thai = 'da_thu',
      nguoi_xac_nhan_id = v_toi, xac_nhan_luc = now()
  where id = p_phieu_thu_id;

  perform private.ghi_nhat_ky('phieu_thu', p_phieu_thu_id, 'xac_nhan_thu',
    to_jsonb(v_pt), jsonb_build_object('so_phieu', v_so));

  return v_so;
end;
$$;


--
-- Name: xoa_chung_tu_de_nghi(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.xoa_chung_tu_de_nghi(p_chung_tu_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_toi uuid := private.nhan_vien_hien_tai();
  v_ct  public.chung_tu_fmb%rowtype;
  v_dn  public.de_nghi%rowtype;
begin
  select * into v_ct from public.chung_tu_fmb where id = p_chung_tu_id;
  if not found then
    raise exception 'Không tìm thấy chứng từ.';
  end if;
  if v_ct.de_nghi_id is null then
    raise exception 'Chỉ gỡ được chứng từ hồ sơ đề nghị, không gỡ được chứng từ thanh toán.';
  end if;

  select * into v_dn from public.de_nghi where id = v_ct.de_nghi_id;
  if v_dn.nguoi_de_xuat_id <> v_toi then
    raise exception 'Bạn chỉ gỡ chứng từ của đề nghị mình.' using errcode = '42501';
  end if;
  if v_dn.trang_thai not in ('nhap', 'bi_tu_choi') then
    raise exception 'Đề nghị đã gửi duyệt thì không gỡ chứng từ được.';
  end if;

  delete from public.chung_tu_fmb where id = p_chung_tu_id;

  perform private.ghi_nhat_ky('de_nghi', v_ct.de_nghi_id, 'xoa_chung_tu',
    to_jsonb(v_ct), null);
end;
$$;


--
-- Name: FUNCTION xoa_chung_tu_de_nghi(p_chung_tu_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.xoa_chung_tu_de_nghi(p_chung_tu_id uuid) IS 'Gỡ một chứng từ hồ sơ khỏi đề nghị nháp. Không đụng chứng từ thanh toán.';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: bu_cong_no_am; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bu_cong_no_am (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    de_nghi_am_id uuid NOT NULL,
    de_nghi_moi_id uuid NOT NULL,
    lan_tra_tien_id uuid,
    so_tien public.tien_te NOT NULL,
    ngay date NOT NULL,
    ly_do text,
    nguoi_tao_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT bu_cong_no_am_so_tien_check CHECK (((so_tien)::numeric > (0)::numeric)),
    CONSTRAINT bu_khong_tu_bu CHECK ((de_nghi_am_id <> de_nghi_moi_id))
);


--
-- Name: TABLE bu_cong_no_am; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.bu_cong_no_am IS 'Chuyển công nợ: khoản tạm ứng ÂM (tiêu lẹm tiền túi) được bù bằng khoản ứng sau của CÙNG một người — mig 43. Thuần sổ công nợ, KHÔNG sinh bút toán tiền nào: tiền đã chuyển động thật ở lần chi của khoản ứng sau.';


--
-- Name: but_toan_quy_cong_truong; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.but_toan_quy_cong_truong (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    loai text NOT NULL,
    quy_tien_mat_id uuid NOT NULL,
    nhan_vien_id uuid NOT NULL,
    de_nghi_tam_ung_goc_id uuid NOT NULL,
    lan_tra_tien_id uuid,
    dot_duyet_id uuid,
    so_tien public.tien_te NOT NULL,
    ngay date NOT NULL,
    dien_giai text NOT NULL,
    nguoi_tao_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT but_toan_quy_cong_truong_loai_check CHECK ((loai = ANY (ARRAY['nhap'::text, 'chi'::text]))),
    CONSTRAINT but_toan_quy_cong_truong_so_tien_check CHECK (((so_tien)::numeric > (0)::numeric)),
    CONSTRAINT nguon_goc_dung_loai CHECK ((((loai = 'nhap'::text) AND (lan_tra_tien_id IS NOT NULL) AND (dot_duyet_id IS NULL)) OR ((loai = 'chi'::text) AND (dot_duyet_id IS NOT NULL) AND (lan_tra_tien_id IS NULL))))
);


--
-- Name: TABLE but_toan_quy_cong_truong; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.but_toan_quy_cong_truong IS 'Hai vế tiền của quỹ công trường (mig 42): nhập khi chi tạm ứng, chi khi duyệt quyết toán. CHỈ vào v_so_quy — cố ý không đụng v_chi_phi (chi phí đã ghi theo đợt quyết toán) và không đụng v_cong_no_tam_ung (công nợ đã tính theo lan_tra_tien). Quỹ ÂM là hợp lệ: tiêu quá số ứng thì trừ vào đợt ứng sau.';


--
-- Name: cau_hinh_he_thong; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cau_hinh_he_thong (
    id integer DEFAULT 1 NOT NULL,
    telegram_bot_token text,
    telegram_group_duyet text,
    telegram_group_baocao text,
    telegram_webhook_secret text,
    app_url text,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chi_mot_dong CHECK ((id = 1))
);


--
-- Name: TABLE cau_hinh_he_thong; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.cau_hinh_he_thong IS 'Cấu hình hệ thống (thông số Telegram) — MỘT dòng. Chứa bí mật (bot token) nên chỉ quan_tri đọc/ghi; Edge Function đọc qua service_role.';


--
-- Name: chi_tiet_lan_tra; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chi_tiet_lan_tra (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    lan_tra_tien_id uuid NOT NULL,
    muc_de_nghi_id uuid NOT NULL,
    dot_duyet_id uuid NOT NULL,
    so_tien public.tien_te NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT so_tien_chi_tiet_duong CHECK (((so_tien)::numeric > (0)::numeric))
);


--
-- Name: TABLE chi_tiet_lan_tra; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.chi_tiet_lan_tra IS 'SỔ CHI PHÍ: lần trả này trả cho mục nào, bao nhiêu. Chi phí ghi nhận tại đây (QĐ-14 + QĐ-17), đúng khoản mục đúng dự án của mục.';


--
-- Name: chung_tu_fmb; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chung_tu_fmb (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    de_nghi_id uuid,
    lan_tra_tien_id uuid,
    phieu_thu_id uuid,
    ten_file text NOT NULL,
    duong_dan text NOT NULL,
    loai_file text,
    kich_thuoc integer,
    nguoi_tai_len_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    chuyen_quy_id uuid,
    CONSTRAINT gan_dung_mot_cho CHECK ((num_nonnulls(de_nghi_id, lan_tra_tien_id, phieu_thu_id, chuyen_quy_id) = 1))
);


--
-- Name: COLUMN chung_tu_fmb.duong_dan; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.chung_tu_fmb.duong_dan IS 'Đường dẫn trong bucket private. KHÔNG lưu URL — URL công khai cho chứng từ tài chính là rò rỉ dữ liệu.';


--
-- Name: chuyen_quy; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chuyen_quy (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    so_phieu text NOT NULL,
    ngay date DEFAULT CURRENT_DATE NOT NULL,
    so_tien public.tien_te NOT NULL,
    tu_quy_tien_mat_id uuid,
    tu_tai_khoan_ngan_hang_id uuid,
    den_quy_tien_mat_id uuid,
    den_tai_khoan_ngan_hang_id uuid,
    dien_giai text NOT NULL,
    nguoi_lap_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chuyen_quy_khac_nguon CHECK (((tu_quy_tien_mat_id IS DISTINCT FROM den_quy_tien_mat_id) OR (tu_tai_khoan_ngan_hang_id IS DISTINCT FROM den_tai_khoan_ngan_hang_id))),
    CONSTRAINT chuyen_quy_mot_nguon_den CHECK ((num_nonnulls(den_quy_tien_mat_id, den_tai_khoan_ngan_hang_id) = 1)),
    CONSTRAINT chuyen_quy_mot_nguon_di CHECK ((num_nonnulls(tu_quy_tien_mat_id, tu_tai_khoan_ngan_hang_id) = 1)),
    CONSTRAINT chuyen_quy_so_tien_duong CHECK (((so_tien)::numeric > (0)::numeric))
);


--
-- Name: TABLE chuyen_quy; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.chuyen_quy IS 'Chuyển tiền giữa hai nguồn (nộp tiền mặt vào ngân hàng, rút về quỹ, chuyển giữa hai tài khoản). MỘT dòng, v_so_quy nở thành hai vế nên hai vế không bao giờ lệch. Ghi qua RPC tao_chuyen_quy — mig 36.';


--
-- Name: cong_ty; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cong_ty (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ma text NOT NULL,
    ten text NOT NULL,
    ten_viet_tat text,
    ma_so_thue text,
    dia_chi text,
    nguoi_dai_dien text,
    dang_dung boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ma_cong_ty_viet_hoa_khong_dau CHECK ((ma ~ '^[A-Z0-9]{2,10}$'::text))
);


--
-- Name: TABLE cong_ty; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.cong_ty IS 'Pháp nhân: Base Vina, Thái Hà.';


--
-- Name: COLUMN cong_ty.ma; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.cong_ty.ma IS 'Mã ngắn viết hoa, dùng trong số đề nghị (DNTT-BV-2026-0087). Không đổi sau khi đã có đề nghị.';


--
-- Name: de_nghi; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.de_nghi (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    so_de_nghi text,
    loai text NOT NULL,
    cong_ty_id uuid NOT NULL,
    nguoi_de_xuat_id uuid NOT NULL,
    nhan_vien_nhan_ung_id uuid,
    han_hoan_ung date,
    de_nghi_tam_ung_goc_id uuid,
    doi_tac_loai text,
    doi_tac_id uuid,
    doi_tac_ten text,
    noi_dung text NOT NULL,
    ngay_de_nghi date DEFAULT CURRENT_DATE NOT NULL,
    trang_thai text DEFAULT 'nhap'::text NOT NULL,
    ly_do_tu_choi text,
    nguoi_tao_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    doi_tuong_vay_id uuid,
    CONSTRAINT doi_tac_loai_hop_le CHECK (((doi_tac_loai IS NULL) OR (doi_tac_loai = ANY (ARRAY['nhan_vien'::text, 'nha_cung_cap'::text, 'khach_hang'::text, 'khac'::text])))),
    CONSTRAINT loai_de_nghi_hop_le CHECK ((loai = ANY (ARRAY['thanh_toan'::text, 'tam_ung'::text, 'quyet_toan'::text]))),
    CONSTRAINT quyet_toan_co_goc CHECK (((loai <> 'quyet_toan'::text) OR (de_nghi_tam_ung_goc_id IS NOT NULL))),
    CONSTRAINT so_de_nghi_dung_luc CHECK ((((trang_thai = 'nhap'::text) AND (so_de_nghi IS NULL)) OR (trang_thai = 'da_huy'::text) OR ((trang_thai = ANY (ARRAY['dang_duyet'::text, 'bi_tu_choi'::text])) AND (so_de_nghi IS NOT NULL)))),
    CONSTRAINT tam_ung_du_thong_tin CHECK (((loai <> 'tam_ung'::text) OR ((nhan_vien_nhan_ung_id IS NOT NULL) AND (han_hoan_ung IS NOT NULL)))),
    CONSTRAINT thanh_toan_khong_lan_thong_tin CHECK (((loai <> 'thanh_toan'::text) OR ((nhan_vien_nhan_ung_id IS NULL) AND (han_hoan_ung IS NULL) AND (de_nghi_tam_ung_goc_id IS NULL)))),
    CONSTRAINT trang_thai_de_nghi_hop_le CHECK ((trang_thai = ANY (ARRAY['nhap'::text, 'dang_duyet'::text, 'bi_tu_choi'::text, 'da_huy'::text])))
);


--
-- Name: TABLE de_nghi; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.de_nghi IS 'Đề nghị thanh toán / tạm ứng / quyết toán. KHÔNG phải phiếu chi — phiếu chi không tồn tại như chứng từ riêng (QĐ-06).';


--
-- Name: COLUMN de_nghi.so_de_nghi; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.de_nghi.so_de_nghi IS 'Dạng DNTT-BV-2026-0087. NULL khi còn nháp, sinh lúc gửi duyệt.';


--
-- Name: COLUMN de_nghi.trang_thai; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.de_nghi.trang_thai IS 'Chỉ 4 giá trị lưu được. Đã xong / Đã tất toán là trạng thái suy ra, xem view file 07.';


--
-- Name: COLUMN de_nghi.doi_tuong_vay_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.de_nghi.doi_tuong_vay_id IS 'Đối tượng vay của cả đề nghị. Đặt ở đề nghị chứ không ở từng mục: một đề nghị trả nợ là trả cho MỘT chủ nợ (mig 38).';


--
-- Name: doi_tuong_vay; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.doi_tuong_vay (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ma text NOT NULL,
    ten text NOT NULL,
    loai text DEFAULT 'ca_nhan'::text NOT NULL,
    ghi_chu text,
    dang_dung boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    nhan_vien_id uuid,
    CONSTRAINT doi_tuong_vay_loai_hop_le CHECK ((loai = ANY (ARRAY['ngan_hang'::text, 'ca_nhan'::text, 'to_chuc'::text, 'nhan_vien'::text])))
);


--
-- Name: TABLE doi_tuong_vay; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.doi_tuong_vay IS 'Danh mục đối tượng vay / cho vay — chủ nợ và con nợ. Danh mục riêng chứ không dùng nhà cung cấp: gom theo tên gõ tay thì lệch một chữ là tách đôi dòng công nợ (mig 38).';


--
-- Name: COLUMN doi_tuong_vay.loai; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.doi_tuong_vay.loai IS 'Chỉ để phân loại và lọc. KHÔNG ảnh hưởng cách tính công nợ — chiều nợ do nhom_cong_no của khoản mục quyết định.';


--
-- Name: COLUMN doi_tuong_vay.nhan_vien_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.doi_tuong_vay.nhan_vien_id IS 'Nhân viên tương ứng, nếu đối tượng vay này là người trong công ty (mig 44). NULL với ngân hàng, người ngoài, tổ chức khác. Có cột này thì công nợ vay nối được về hồ sơ nhân viên thay vì khớp theo tên gõ tay.';


--
-- Name: dot_duyet; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dot_duyet (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    de_nghi_id uuid NOT NULL,
    so_dot integer NOT NULL,
    ktt_id uuid NOT NULL,
    ktt_luc timestamp with time zone DEFAULT now() NOT NULL,
    ktt_y_kien text,
    trang_thai text DEFAULT 'cho_chu_tich'::text NOT NULL,
    chu_tich_id uuid,
    chu_tich_luc timestamp with time zone,
    chu_tich_y_kien text,
    ly_do_tu_choi text,
    ly_do_dong text,
    nguoi_dong_id uuid,
    dong_luc timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chi_dong_dot_da_duyet CHECK (((trang_thai <> 'da_dong'::text) OR (chu_tich_luc IS NOT NULL))),
    CONSTRAINT chu_tich_co_dau_vet CHECK (((trang_thai <> ALL (ARRAY['da_duyet'::text, 'bi_tu_choi'::text])) OR ((chu_tich_id IS NOT NULL) AND (chu_tich_luc IS NOT NULL)))),
    CONSTRAINT dong_phai_co_ly_do CHECK (((trang_thai <> 'da_dong'::text) OR ((ly_do_dong IS NOT NULL) AND (nguoi_dong_id IS NOT NULL) AND (dong_luc IS NOT NULL)))),
    CONSTRAINT trang_thai_dot_hop_le CHECK ((trang_thai = ANY (ARRAY['cho_chu_tich'::text, 'da_duyet'::text, 'bi_tu_choi'::text, 'da_dong'::text]))),
    CONSTRAINT tu_choi_phai_co_ly_do CHECK (((trang_thai <> 'bi_tu_choi'::text) OR (ly_do_tu_choi IS NOT NULL)))
);


--
-- Name: TABLE dot_duyet; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.dot_duyet IS 'Đợt duyệt: tập hợp các mục KTT duyệt cùng một lần. Chủ tịch duyệt đợt = chi phí ghi nhận ngay (QĐ-14).';


--
-- Name: COLUMN dot_duyet.trang_thai; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.dot_duyet.trang_thai IS 'Đang trả / Đã trả đủ KHÔNG nằm ở đây — chúng suy ra từ tổng các lần trả tiền (view file 07).';


--
-- Name: du_an; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.du_an (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ma text NOT NULL,
    ten text NOT NULL,
    cong_ty_id uuid NOT NULL,
    khach_hang_id uuid,
    dia_diem text,
    ngay_bat_dau date,
    ngay_ket_thuc date,
    chu_nhiem_id uuid,
    du_toan public.tien_te,
    trang_thai text DEFAULT 'dang_chay'::text NOT NULL,
    dang_dung boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT du_toan_khong_am CHECK (((du_toan IS NULL) OR ((du_toan)::numeric >= (0)::numeric))),
    CONSTRAINT ngay_ket_thuc_sau_ngay_bat_dau CHECK (((ngay_bat_dau IS NULL) OR (ngay_ket_thuc IS NULL) OR (ngay_ket_thuc >= ngay_bat_dau))),
    CONSTRAINT trang_thai_du_an_hop_le CHECK ((trang_thai = ANY (ARRAY['chuan_bi'::text, 'dang_chay'::text, 'tam_dung'::text, 'hoan_thanh'::text, 'da_huy'::text])))
);


--
-- Name: COLUMN du_an.du_toan; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.du_an.du_toan IS 'Dự toán tham khảo. KHÔNG dùng để chặn chi — chặn chi là việc của ngan_sach.';


--
-- Name: giao_dich_da_huy; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.giao_dich_da_huy (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    loai text NOT NULL,
    giao_dich_id uuid NOT NULL,
    du_lieu jsonb NOT NULL,
    mo_ta text,
    so_tien public.tien_te,
    ly_do text NOT NULL,
    nguoi_huy_id uuid NOT NULL,
    huy_luc timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT giao_dich_da_huy_loai_check CHECK ((loai = ANY (ARRAY['phieu_chi'::text, 'phieu_thu'::text, 'lich_su'::text, 'ton_dau_ky'::text, 'chuyen_quy'::text, 'quy_cong_truong'::text])))
);


--
-- Name: TABLE giao_dich_da_huy; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.giao_dich_da_huy IS 'Kho giao dịch admin đã HỦY — giữ snapshot để khôi phục (mig 28). Bản ghi sống đã bị xóa nên view tự loại khỏi sổ.';


--
-- Name: giao_dich_lich_su; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.giao_dich_lich_su (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ngay date NOT NULL,
    loai text NOT NULL,
    noi_dung text NOT NULL,
    so_tien public.tien_te NOT NULL,
    quy_tien_mat_id uuid,
    tai_khoan_ngan_hang_id uuid,
    khoan_muc_thu_id uuid,
    khoan_muc_chi_id uuid,
    cong_ty_id uuid,
    du_an_id uuid,
    nguoi_text text,
    ma_nguon text,
    ghi_chu text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    doi_tuong_vay_id uuid,
    CONSTRAINT dung_mot_nguon_tien_ls CHECK ((num_nonnulls(quy_tien_mat_id, tai_khoan_ngan_hang_id) = 1)),
    CONSTRAINT giao_dich_lich_su_loai_check CHECK ((loai = ANY (ARRAY['thu'::text, 'chi'::text]))),
    CONSTRAINT giao_dich_lich_su_so_tien_check CHECK (((so_tien)::numeric > (0)::numeric)),
    CONSTRAINT khoan_muc_dung_loai_ls CHECK ((((loai = 'thu'::text) AND (khoan_muc_thu_id IS NOT NULL) AND (khoan_muc_chi_id IS NULL)) OR ((loai = 'chi'::text) AND (khoan_muc_chi_id IS NOT NULL) AND (khoan_muc_thu_id IS NULL))))
);


--
-- Name: TABLE giao_dich_lich_su; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.giao_dich_lich_su IS 'SỔ LỊCH SỬ — giao dịch cũ nhập từ Google Sheet (A1). Chỉ đọc, không qua duyệt. Cộng vào v_so_quy + v_chi_phi.';


--
-- Name: khach_hang; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.khach_hang (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ma text NOT NULL,
    ten text NOT NULL,
    ma_so_thue text,
    dia_chi text,
    nguoi_lien_he text,
    dien_thoai text,
    email text,
    dang_dung boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: khoan_muc_chi; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.khoan_muc_chi (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ma text NOT NULL,
    ten text NOT NULL,
    nhom text,
    bat_buoc_chung_tu boolean DEFAULT false NOT NULL,
    kiem_soat_ngan_sach boolean DEFAULT false NOT NULL,
    dang_dung boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    nhom_cong_no text,
    CONSTRAINT khoan_muc_chi_nhom_cong_no_hop_le CHECK (((nhom_cong_no IS NULL) OR (nhom_cong_no = ANY (ARRAY['tra_no_vay'::text, 'cho_vay'::text, 'lai_vay'::text]))))
);


--
-- Name: COLUMN khoan_muc_chi.bat_buoc_chung_tu; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.khoan_muc_chi.bat_buoc_chung_tu IS 'Bắt buộc đính chứng từ khi gửi duyệt đề nghị có mục thuộc khoản mục này.';


--
-- Name: COLUMN khoan_muc_chi.kiem_soat_ngan_sach; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.khoan_muc_chi.kiem_soat_ngan_sach IS 'Có kiểm ngân sách khi duyệt đợt chứa mục thuộc khoản mục này.';


--
-- Name: COLUMN khoan_muc_chi.nhom_cong_no; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.khoan_muc_chi.nhom_cong_no IS 'Để trống = khoản mục thường. lai_vay hiện tách riêng, KHÔNG trừ vào nợ gốc — trả lãi không làm giảm gốc.';


--
-- Name: khoan_muc_thu; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.khoan_muc_thu (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ma text NOT NULL,
    ten text NOT NULL,
    nhom text,
    la_he_thong boolean DEFAULT false NOT NULL,
    dang_dung boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    nhom_cong_no text,
    bat_buoc_cong_trinh boolean DEFAULT false NOT NULL,
    CONSTRAINT khoan_muc_thu_nhom_cong_no_hop_le CHECK (((nhom_cong_no IS NULL) OR (nhom_cong_no = ANY (ARRAY['di_vay'::text, 'thu_no_cho_vay'::text]))))
);


--
-- Name: COLUMN khoan_muc_thu.la_he_thong; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.khoan_muc_thu.la_he_thong IS 'Khoản mục do hệ thống dùng (THU_HOAN_UNG). Không được ẩn hay xóa.';


--
-- Name: COLUMN khoan_muc_thu.nhom_cong_no; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.khoan_muc_thu.nhom_cong_no IS 'Để trống = khoản mục thường. Đặt giá trị thì mọi giao dịch của khoản mục này vào báo cáo công nợ vay (mig 38).';


--
-- Name: COLUMN khoan_muc_thu.bat_buoc_cong_trinh; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.khoan_muc_thu.bat_buoc_cong_trinh IS 'Bật = mọi phiếu thu của khoản mục này BẮT BUỘC chọn công trình và khách hàng (mig 46). Để tắt với khoản thu nội bộ (rút tiền, nhập quỹ, vay) — bắt các khoản đó chọn công trình là làm bẩn báo cáo doanh thu theo công trình.';


--
-- Name: lan_tra_tien; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lan_tra_tien (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    dot_duyet_id uuid NOT NULL,
    so_tien public.tien_te NOT NULL,
    ngay_tra date DEFAULT CURRENT_DATE NOT NULL,
    quy_tien_mat_id uuid,
    tai_khoan_ngan_hang_id uuid,
    nguoi_xac_nhan_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT dung_mot_nguon_tien CHECK ((num_nonnulls(quy_tien_mat_id, tai_khoan_ngan_hang_id) = 1)),
    CONSTRAINT so_tien_tra_duong CHECK (((so_tien)::numeric > (0)::numeric))
);


--
-- Name: TABLE lan_tra_tien; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.lan_tra_tien IS 'Mỗi lần trả tiền cho một đợt. ĐỒNG THỜI LÀ SỔ QUỸ (phần tiền ra). Chỉ ghi thêm — sai thì ghi bút toán ngược dấu.';


--
-- Name: COLUMN lan_tra_tien.so_tien; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.lan_tra_tien.so_tien IS 'Tổng lần trả. PHẢI bằng tổng chi_tiet_lan_tra — RPC tính lại, không tin số client gửi.';


--
-- Name: menu_nhan_vien; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.menu_nhan_vien (
    nhan_vien_id uuid NOT NULL,
    duong_dan text NOT NULL
);


--
-- Name: TABLE menu_nhan_vien; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.menu_nhan_vien IS 'Cấu hình ẩn/hiện Tab theo TỪNG tài khoản (chỉ dọn màn hình, KHÔNG phải phân quyền — chốt thật ở RLS/RPC). Nhân viên chưa có dòng nào thì app dùng mặc định theo vai trò trong src/lib/auth/menu.ts.';


--
-- Name: muc_de_nghi; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.muc_de_nghi (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    de_nghi_id uuid NOT NULL,
    thu_tu integer NOT NULL,
    khoan_muc_chi_id uuid NOT NULL,
    du_an_id uuid,
    dien_giai text NOT NULL,
    so_tien public.tien_te NOT NULL,
    dot_duyet_id uuid,
    ly_do_tu_choi text,
    nguoi_tu_choi_id uuid,
    tu_choi_luc timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT khong_vua_duyet_vua_tu_choi CHECK (((dot_duyet_id IS NULL) OR (tu_choi_luc IS NULL))),
    CONSTRAINT so_tien_muc_duong CHECK (((so_tien)::numeric > (0)::numeric)),
    CONSTRAINT tu_choi_muc_du_thong_tin CHECK (((tu_choi_luc IS NULL) OR ((ly_do_tu_choi IS NOT NULL) AND (nguoi_tu_choi_id IS NOT NULL))))
);


--
-- Name: TABLE muc_de_nghi; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.muc_de_nghi IS 'Bảng kê chi tiết của đề nghị. ĐỒNG THỜI LÀ SỔ CHI PHÍ: mục thuộc đợt đã duyệt = chi phí đã ghi nhận (QĐ-14).';


--
-- Name: COLUMN muc_de_nghi.dot_duyet_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.muc_de_nghi.dot_duyet_id IS 'Đợt duyệt chứa mục này. NULL = chưa duyệt. Một cột đơn = mỗi mục tối đa một đợt.';


--
-- Name: ngan_sach; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ngan_sach (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nam integer NOT NULL,
    thang integer,
    cong_ty_id uuid,
    du_an_id uuid,
    khoan_muc_chi_id uuid NOT NULL,
    so_tien public.tien_te NOT NULL,
    dang_dung boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT nam_hop_le CHECK (((nam >= 2020) AND (nam <= 2100))),
    CONSTRAINT so_tien_ngan_sach_duong CHECK (((so_tien)::numeric > (0)::numeric)),
    CONSTRAINT thang_hop_le CHECK (((thang IS NULL) OR ((thang >= 1) AND (thang <= 12))))
);


--
-- Name: TABLE ngan_sach; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.ngan_sach IS 'Ngân sách theo kỳ. KHÔNG có cột đã dùng/còn lại — xem view v_ngan_sach.';


--
-- Name: nguon_tien_nhan_vien; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.nguon_tien_nhan_vien (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nhan_vien_id uuid NOT NULL,
    quy_tien_mat_id uuid,
    tai_khoan_ngan_hang_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT dung_mot_nguon_tien_gan CHECK ((num_nonnulls(quy_tien_mat_id, tai_khoan_ngan_hang_id) = 1))
);


--
-- Name: TABLE nguon_tien_nhan_vien; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.nguon_tien_nhan_vien IS 'Nguồn tiền (quỹ tiền mặt HOẶC tài khoản ngân hàng) mà mỗi tài khoản được phụ trách — mig 35, thay bảng quy_nhan_vien của mig 34. Đây là PHÂN QUYỀN XEM và QUYỀN NHẬP TỒN ĐẦU KỲ, khác hẳn quy_tien_mat.thu_quy_id (chỉ là ô khai báo thủ quỹ trong danh mục).';


--
-- Name: nha_cung_cap; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.nha_cung_cap (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ma text NOT NULL,
    ten text NOT NULL,
    ma_so_thue text,
    dia_chi text,
    nguoi_lien_he text,
    dien_thoai text,
    email text,
    so_tai_khoan text,
    ten_ngan_hang text,
    dang_dung boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: nhan_vien; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.nhan_vien (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    ma text NOT NULL,
    ho_ten text NOT NULL,
    cong_ty_id uuid NOT NULL,
    chuc_vu text,
    dang_dung boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE nhan_vien; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.nhan_vien IS 'Nhân viên — chỉ thông tin công khai (tên, mã, chức vụ). Mọi người đăng nhập đọc được. Thông tin nhạy cảm nằm ở bảng nhan_vien_nhay_cam.';


--
-- Name: COLUMN nhan_vien.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.nhan_vien.user_id IS 'Nối tài khoản đăng nhập. Mọi RPC resolve auth.uid() -> nhan_vien qua cột này. NULL = chưa có tài khoản.';


--
-- Name: nhan_vien_nhay_cam; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.nhan_vien_nhay_cam (
    nhan_vien_id uuid NOT NULL,
    dien_thoai text,
    email text,
    so_tai_khoan text,
    ten_ngan_hang text,
    telegram_chat_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE nhan_vien_nhay_cam; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.nhan_vien_nhay_cam IS 'Thông tin nhạy cảm của nhân viên: số tài khoản nhận tiền, điện thoại, telegram. RLS chặt — xem policy ở file 04.';


--
-- Name: nhat_ky; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.nhat_ky (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    bang text NOT NULL,
    ban_ghi_id uuid,
    hanh_dong text NOT NULL,
    gia_tri_cu jsonb,
    gia_tri_moi jsonb,
    nguoi_thuc_hien_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE nhat_ky; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.nhat_ky IS 'Nhật ký chứng từ. Chỉ ghi thêm, không sửa không xóa — như sổ cái đã đóng dấu.';


--
-- Name: COLUMN nhat_ky.nguoi_thuc_hien_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.nhat_ky.nguoi_thuc_hien_id IS 'nhan_vien.id của người thao tác. CỐ Ý không có khóa ngoại (mig 30): nhật ký phải sống lâu hơn hồ sơ nhân sự — nhân viên bị xóa hẳn thì id ở đây thành id treo, tra ngược ở dòng nhật ký admin_xoa_nhan_vien.';


--
-- Name: phieu_thu; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.phieu_thu (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    so_phieu text,
    cong_ty_id uuid,
    khoan_muc_thu_id uuid NOT NULL,
    so_tien public.tien_te NOT NULL,
    ngay_thu date DEFAULT CURRENT_DATE NOT NULL,
    quy_tien_mat_id uuid,
    tai_khoan_ngan_hang_id uuid,
    doi_tac_loai text,
    doi_tac_id uuid,
    doi_tac_ten text,
    dien_giai text NOT NULL,
    de_nghi_tam_ung_goc_id uuid,
    trang_thai text DEFAULT 'nhap'::text NOT NULL,
    nguoi_lap_id uuid NOT NULL,
    nguoi_xac_nhan_id uuid,
    xac_nhan_luc timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    doi_tuong_vay_id uuid,
    cap_tru_lan_tra_id uuid,
    du_an_id uuid,
    xac_nhan_khong_trung_nhap_quy boolean DEFAULT false NOT NULL,
    CONSTRAINT da_thu_co_dau_vet CHECK (((trang_thai <> 'da_thu'::text) OR ((nguoi_xac_nhan_id IS NOT NULL) AND (xac_nhan_luc IS NOT NULL)))),
    CONSTRAINT doi_tac_loai_thu_hop_le CHECK (((doi_tac_loai IS NULL) OR (doi_tac_loai = ANY (ARRAY['nhan_vien'::text, 'nha_cung_cap'::text, 'khach_hang'::text, 'khac'::text])))),
    CONSTRAINT dung_mot_nguon_tien_thu CHECK ((num_nonnulls(quy_tien_mat_id, tai_khoan_ngan_hang_id) = 1)),
    CONSTRAINT so_phieu_thu_dung_luc CHECK ((((trang_thai = 'nhap'::text) AND (so_phieu IS NULL)) OR (trang_thai = 'da_huy'::text) OR ((trang_thai = 'da_thu'::text) AND (so_phieu IS NOT NULL)))),
    CONSTRAINT so_tien_thu_duong CHECK (((so_tien)::numeric > (0)::numeric)),
    CONSTRAINT thu_vao_ngan_hang_phai_co_cong_ty CHECK (((tai_khoan_ngan_hang_id IS NULL) OR (cong_ty_id IS NOT NULL))),
    CONSTRAINT trang_thai_phieu_thu_hop_le CHECK ((trang_thai = ANY (ARRAY['nhap'::text, 'da_thu'::text, 'da_huy'::text])))
);


--
-- Name: TABLE phieu_thu; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.phieu_thu IS 'Tiền vào quỹ. ĐỒNG THỜI LÀ SỔ QUỸ (phần tiền vào). Không qua duyệt (QĐ-01).';


--
-- Name: COLUMN phieu_thu.cap_tru_lan_tra_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.phieu_thu.cap_tru_lan_tra_id IS 'Khác null = phiếu này KHÔNG phải tiền thu thật, mà là vế đối trừ của lần tạm ứng trỏ tới: thủ quỹ giữ lại tiền thừa đợt trước thay vì nộp về rồi lĩnh lại (mig 39).';


--
-- Name: COLUMN phieu_thu.du_an_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.phieu_thu.du_an_id IS 'Công trình của khoản thu (mig 46). Bắt buộc khi khoản mục có bat_buoc_cong_trinh; còn lại tùy chọn.';


--
-- Name: COLUMN phieu_thu.xac_nhan_khong_trung_nhap_quy; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.phieu_thu.xac_nhan_khong_trung_nhap_quy IS 'Người lập đã xác nhận phiếu này KHÔNG trùng bút toán nhập quỹ công trường tự động (mig 55). Mặc định false; bật lên thì trigger chan_phieu_thu_trung_nhap_quy cho qua. Cố ý KHÔNG backfill true cho phiếu cũ: mặc định phải là "chưa ai xác nhận" để phiếu trùng nào còn sót lại vẫn hiện trong v_nhap_quy_trung.';


--
-- Name: quy_tien_mat; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quy_tien_mat (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ma text NOT NULL,
    ten text NOT NULL,
    thu_quy_id uuid,
    dang_dung boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE quy_tien_mat; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.quy_tien_mat IS 'Quỹ tiền mặt dùng chung 2 công ty. KHÔNG có cột số dư — xem view v_so_du_nguon_tien.';


--
-- Name: so_thu_tu_de_nghi; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.so_thu_tu_de_nghi (
    loai text NOT NULL,
    ma_cong_ty text NOT NULL,
    nam integer NOT NULL,
    so_cuoi integer DEFAULT 0 NOT NULL
);


--
-- Name: TABLE so_thu_tu_de_nghi; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.so_thu_tu_de_nghi IS 'Bộ đếm số đề nghị theo (loại + công ty + năm). Chỉ RPC sinh số được ghi. Không bao giờ sửa tay: sửa lùi số là sinh ra số trùng.';


--
-- Name: tai_khoan_ngan_hang; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tai_khoan_ngan_hang (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    cong_ty_id uuid NOT NULL,
    ten_ngan_hang text NOT NULL,
    chi_nhanh text,
    so_tai_khoan text NOT NULL,
    chu_tai_khoan text NOT NULL,
    dang_dung boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    la_tai_khoan_vay boolean DEFAULT false NOT NULL
);


--
-- Name: TABLE tai_khoan_ngan_hang; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.tai_khoan_ngan_hang IS 'Tài khoản ngân hàng, bắt buộc thuộc 1 công ty. KHÔNG có cột số dư.';


--
-- Name: COLUMN tai_khoan_ngan_hang.la_tai_khoan_vay; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tai_khoan_ngan_hang.la_tai_khoan_vay IS 'Bật = tài khoản tiền VAY (hạn mức ngân hàng cấp), KHÔNG cộng vào "tổng tiền công ty" ở màn Số dư, PDF tháng và tin Telegram sáng. Vẫn có sổ quỹ riêng, vẫn chuyển quỹ và nhập tồn đầu kỳ bình thường. Nhận diện bằng cờ này chứ KHÔNG theo tên tài khoản — mig 41.';


--
-- Name: ton_dau_ky; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ton_dau_ky (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    quy_tien_mat_id uuid,
    tai_khoan_ngan_hang_id uuid,
    so_tien public.tien_te NOT NULL,
    ngay date NOT NULL,
    nguoi_tao_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT dung_mot_nguon_tien_ton CHECK ((num_nonnulls(quy_tien_mat_id, tai_khoan_ngan_hang_id) = 1)),
    CONSTRAINT ton_dau_ky_khong_am CHECK (((so_tien)::numeric >= (0)::numeric))
);


--
-- Name: TABLE ton_dau_ky; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.ton_dau_ky IS 'Tồn đầu kỳ mỗi nguồn tiền, Quản trị nhập 1 lần lúc khai trương (QĐ-04).';


--
-- Name: v_cong_no_tam_ung; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_cong_no_tam_ung WITH (security_invoker='on') AS
 SELECT dn.id AS de_nghi_tam_ung_id,
    dn.so_de_nghi,
    dn.nhan_vien_nhan_ung_id,
    dn.cong_ty_id,
    dn.noi_dung,
    dn.ngay_de_nghi,
    dn.han_hoan_ung,
    COALESCE(u.da_ung, (0)::numeric) AS da_ung,
    COALESCE(q.da_quyet_toan, (0)::numeric) AS da_quyet_toan,
    COALESCE(b.da_tra_bu, (0)::numeric) AS da_tra_bu,
    COALESCE(n.da_nop_lai, (0)::numeric) AS da_nop_lai,
    (((((COALESCE(u.da_ung, (0)::numeric) - COALESCE(q.da_quyet_toan, (0)::numeric)) + COALESCE(b.da_tra_bu, (0)::numeric)) - COALESCE(n.da_nop_lai, (0)::numeric)) + COALESCE(bn.da_nhan_bu, (0)::numeric)) - COALESCE(bg.da_ganh_bu, (0)::numeric)) AS con_no,
    ((COALESCE(u.da_ung, (0)::numeric) > (0)::numeric) AND ((((((COALESCE(u.da_ung, (0)::numeric) - COALESCE(q.da_quyet_toan, (0)::numeric)) + COALESCE(b.da_tra_bu, (0)::numeric)) - COALESCE(n.da_nop_lai, (0)::numeric)) + COALESCE(bn.da_nhan_bu, (0)::numeric)) - COALESCE(bg.da_ganh_bu, (0)::numeric)) = (0)::numeric)) AS da_tat_toan,
    GREATEST(COALESCE(q.ngay_duyet_cuoi, '1900-01-01'::date), COALESCE(b.ngay_tra_bu_cuoi, '1900-01-01'::date), COALESCE(n.ngay_nop_cuoi, '1900-01-01'::date), COALESCE(bn.ngay_bu_cuoi, '1900-01-01'::date)) AS ngay_tat_toan,
    ((dn.han_hoan_ung < CURRENT_DATE) AND (COALESCE(u.da_ung, (0)::numeric) > (0)::numeric) AND ((((((COALESCE(u.da_ung, (0)::numeric) - COALESCE(q.da_quyet_toan, (0)::numeric)) + COALESCE(b.da_tra_bu, (0)::numeric)) - COALESCE(n.da_nop_lai, (0)::numeric)) + COALESCE(bn.da_nhan_bu, (0)::numeric)) - COALESCE(bg.da_ganh_bu, (0)::numeric)) <> (0)::numeric)) AS qua_han,
        CASE
            WHEN ((dn.han_hoan_ung < CURRENT_DATE) AND (COALESCE(u.da_ung, (0)::numeric) > (0)::numeric) AND ((((((COALESCE(u.da_ung, (0)::numeric) - COALESCE(q.da_quyet_toan, (0)::numeric)) + COALESCE(b.da_tra_bu, (0)::numeric)) - COALESCE(n.da_nop_lai, (0)::numeric)) + COALESCE(bn.da_nhan_bu, (0)::numeric)) - COALESCE(bg.da_ganh_bu, (0)::numeric)) <> (0)::numeric)) THEN (CURRENT_DATE - dn.han_hoan_ung)
            ELSE 0
        END AS so_ngay_qua_han,
    COALESCE(bn.da_nhan_bu, (0)::numeric) AS da_nhan_bu,
    COALESCE(bg.da_ganh_bu, (0)::numeric) AS da_ganh_bu
   FROM ((((((public.de_nghi dn
     LEFT JOIN LATERAL ( SELECT sum((ltt.so_tien)::numeric) AS da_ung
           FROM (public.lan_tra_tien ltt
             JOIN public.dot_duyet dd ON ((dd.id = ltt.dot_duyet_id)))
          WHERE (dd.de_nghi_id = dn.id)) u ON (true))
     LEFT JOIN LATERAL ( SELECT sum((mq.so_tien)::numeric) AS da_quyet_toan,
            (max(ddq.chu_tich_luc))::date AS ngay_duyet_cuoi
           FROM ((public.de_nghi qt
             JOIN public.dot_duyet ddq ON ((ddq.de_nghi_id = qt.id)))
             JOIN public.muc_de_nghi mq ON ((mq.dot_duyet_id = ddq.id)))
          WHERE ((qt.loai = 'quyet_toan'::text) AND (qt.de_nghi_tam_ung_goc_id = dn.id) AND (ddq.trang_thai = ANY (ARRAY['da_duyet'::text, 'da_dong'::text])))) q ON (true))
     LEFT JOIN LATERAL ( SELECT sum((lb.so_tien)::numeric) AS da_tra_bu,
            max(lb.ngay_tra) AS ngay_tra_bu_cuoi
           FROM ((public.lan_tra_tien lb
             JOIN public.dot_duyet db ON ((db.id = lb.dot_duyet_id)))
             JOIN public.de_nghi qb ON ((qb.id = db.de_nghi_id)))
          WHERE ((qb.loai = 'quyet_toan'::text) AND (qb.de_nghi_tam_ung_goc_id = dn.id))) b ON (true))
     LEFT JOIN LATERAL ( SELECT sum((pt.so_tien)::numeric) AS da_nop_lai,
            max(pt.ngay_thu) AS ngay_nop_cuoi
           FROM public.phieu_thu pt
          WHERE ((pt.de_nghi_tam_ung_goc_id = dn.id) AND (pt.trang_thai = 'da_thu'::text))) n ON (true))
     LEFT JOIN LATERAL ( SELECT sum((x.so_tien)::numeric) AS da_nhan_bu,
            max(x.ngay) AS ngay_bu_cuoi
           FROM public.bu_cong_no_am x
          WHERE (x.de_nghi_am_id = dn.id)) bn ON (true))
     LEFT JOIN LATERAL ( SELECT sum((x.so_tien)::numeric) AS da_ganh_bu
           FROM public.bu_cong_no_am x
          WHERE (x.de_nghi_moi_id = dn.id)) bg ON (true))
  WHERE ((dn.loai = 'tam_ung'::text) AND (dn.trang_thai = 'dang_duyet'::text));


--
-- Name: VIEW v_cong_no_tam_ung; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_cong_no_tam_ung IS 'Công nợ tạm ứng: đã ứng − đã quyết toán + đã trả bù − đã nộp lại + nhận bù − gánh bù (mig 43). Công nợ ÂM = công ty nợ lại nhân viên; khoản âm được bù bằng đợt ứng sau thì về 0 mà không đồng tiền nào chuyển động.';


--
-- Name: v_chi_phi; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_chi_phi WITH (security_invoker='on') AS
 SELECT ct.id AS chi_phi_id,
    m.id AS muc_id,
    dn.id AS de_nghi_id,
    dn.so_de_nghi,
    dn.loai AS loai_de_nghi,
    dn.cong_ty_id,
    m.dot_duyet_id,
    ltt.ngay_tra AS ngay_ghi_nhan,
    m.khoan_muc_chi_id,
    m.du_an_id,
    m.dien_giai,
    ct.so_tien,
    dn.nguoi_de_xuat_id,
    dn.doi_tac_loai,
    dn.doi_tac_id,
    dn.doi_tac_ten
   FROM (((public.chi_tiet_lan_tra ct
     JOIN public.lan_tra_tien ltt ON ((ltt.id = ct.lan_tra_tien_id)))
     JOIN public.muc_de_nghi m ON ((m.id = ct.muc_de_nghi_id)))
     JOIN public.de_nghi dn ON ((dn.id = m.de_nghi_id)))
  WHERE (dn.loai = 'thanh_toan'::text)
UNION ALL
 SELECT m.id AS chi_phi_id,
    m.id AS muc_id,
    dn.id AS de_nghi_id,
    dn.so_de_nghi,
    dn.loai AS loai_de_nghi,
    dn.cong_ty_id,
    m.dot_duyet_id,
    cn.ngay_tat_toan AS ngay_ghi_nhan,
    m.khoan_muc_chi_id,
    m.du_an_id,
    m.dien_giai,
    m.so_tien,
    dn.nguoi_de_xuat_id,
    dn.doi_tac_loai,
    dn.doi_tac_id,
    dn.doi_tac_ten
   FROM (((public.muc_de_nghi m
     JOIN public.de_nghi dn ON ((dn.id = m.de_nghi_id)))
     JOIN public.dot_duyet dd ON ((dd.id = m.dot_duyet_id)))
     JOIN public.v_cong_no_tam_ung cn ON ((cn.de_nghi_tam_ung_id = dn.de_nghi_tam_ung_goc_id)))
  WHERE ((dn.loai = 'quyet_toan'::text) AND (dd.trang_thai = ANY (ARRAY['da_duyet'::text, 'da_dong'::text])) AND cn.da_tat_toan)
UNION ALL
 SELECT gls.id AS chi_phi_id,
    NULL::uuid AS muc_id,
    NULL::uuid AS de_nghi_id,
    NULL::text AS so_de_nghi,
    'lich_su'::text AS loai_de_nghi,
    gls.cong_ty_id,
    NULL::uuid AS dot_duyet_id,
    gls.ngay AS ngay_ghi_nhan,
    gls.khoan_muc_chi_id,
    gls.du_an_id,
    gls.noi_dung AS dien_giai,
    gls.so_tien,
    NULL::uuid AS nguoi_de_xuat_id,
    NULL::text AS doi_tac_loai,
    NULL::uuid AS doi_tac_id,
    NULL::text AS doi_tac_ten
   FROM public.giao_dich_lich_su gls
  WHERE (gls.loai = 'chi'::text);


--
-- Name: VIEW v_chi_phi; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_chi_phi IS 'SỔ CHI PHÍ: thanh toán + quyết toán + SỔ LỊCH SỬ (chi cũ nhập vào). Tạm ứng không nằm ở đây.';


--
-- Name: v_cho_toi_xu_ly; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_cho_toi_xu_ly AS
SELECT
    NULL::text AS viec,
    NULL::uuid AS de_nghi_id,
    NULL::uuid AS dot_duyet_id,
    NULL::text AS so_de_nghi,
    NULL::text AS loai,
    NULL::uuid AS cong_ty_id,
    NULL::text AS noi_dung,
    NULL::numeric AS so_tien,
    NULL::timestamp with time zone AS created_at;


--
-- Name: VIEW v_cho_toi_xu_ly; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_cho_toi_xu_ly IS 'Hộp thư việc cần làm của người đang đăng nhập, tùy vai trò (QĐ-16). Từ mig 53: nhánh KT thanh toán hỏi private.con_phai_chi_that() nên quyết toán đã đối trừ hết bằng tiền tạm ứng không còn bị đòi chi.';


--
-- Name: v_muc_tong_hop; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_muc_tong_hop WITH (security_invoker='on') AS
 SELECT m.id AS muc_id,
    m.de_nghi_id,
    m.dot_duyet_id,
    m.khoan_muc_chi_id,
    m.du_an_id,
    m.dien_giai,
    m.so_tien AS so_tien_duyet,
    COALESCE(t.da_tra, (0)::numeric) AS so_tien_da_tra,
    ((m.so_tien)::numeric - COALESCE(t.da_tra, (0)::numeric)) AS so_tien_con_no,
    t.ngay_tra_gan_nhat,
    (m.tu_choi_luc IS NOT NULL) AS bi_tu_choi,
    m.ly_do_tu_choi
   FROM (public.muc_de_nghi m
     LEFT JOIN LATERAL ( SELECT sum((ct.so_tien)::numeric) AS da_tra,
            max(ltt.ngay_tra) AS ngay_tra_gan_nhat
           FROM (public.chi_tiet_lan_tra ct
             JOIN public.lan_tra_tien ltt ON ((ltt.id = ct.lan_tra_tien_id)))
          WHERE (ct.muc_de_nghi_id = m.id)) t ON (true));


--
-- Name: VIEW v_muc_tong_hop; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_muc_tong_hop IS 'Mỗi mục: được duyệt bao nhiêu, đã trả bao nhiêu, còn nợ bao nhiêu. Nền của mọi view khác (QĐ-17).';


--
-- Name: v_cong_no_phai_tra; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_cong_no_phai_tra WITH (security_invoker='on') AS
 SELECT dn.id AS de_nghi_id,
    dn.so_de_nghi,
    dn.loai AS loai_de_nghi,
    dn.cong_ty_id,
    dn.doi_tac_loai,
    dn.doi_tac_id,
    dn.doi_tac_ten,
    dn.noi_dung,
    v.muc_id,
    v.dien_giai AS muc_dien_giai,
    v.khoan_muc_chi_id,
    v.du_an_id,
    dd.id AS dot_duyet_id,
    dd.so_dot,
    dd.trang_thai AS trang_thai_dot,
    dd.chu_tich_luc AS ngay_duyet,
    dd.ly_do_dong,
    v.so_tien_duyet,
    v.so_tien_da_tra,
    v.so_tien_con_no,
        CASE
            WHEN (dd.trang_thai = 'da_duyet'::text) THEN (CURRENT_DATE - (dd.chu_tich_luc)::date)
            ELSE NULL::integer
        END AS so_ngay_no
   FROM ((public.v_muc_tong_hop v
     JOIN public.dot_duyet dd ON ((dd.id = v.dot_duyet_id)))
     JOIN public.de_nghi dn ON ((dn.id = v.de_nghi_id)))
  WHERE ((dd.trang_thai = ANY (ARRAY['da_duyet'::text, 'da_dong'::text])) AND (v.so_tien_con_no > (0)::numeric));


--
-- Name: VIEW v_cong_no_phai_tra; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_cong_no_phai_tra IS 'Công nợ phải trả theo TỪNG MỤC: đã duyệt − đã trả. Kèm tuổi nợ. Đợt da_dong còn dư = phần không bao giờ trả, xem ly_do_dong.';


--
-- Name: v_cong_no_tam_ung_theo_nguoi; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_cong_no_tam_ung_theo_nguoi WITH (security_invoker='on') AS
 SELECT nhan_vien_nhan_ung_id AS nhan_vien_id,
    count(*) FILTER (WHERE ((da_ung > (0)::numeric) AND (NOT da_tat_toan))) AS so_khoan_chua_tat_toan,
    count(*) FILTER (WHERE qua_han) AS so_khoan_qua_han,
    sum(da_ung) AS tong_da_ung,
    sum(da_quyet_toan) AS tong_da_quyet_toan,
    sum(con_no) AS tong_con_no,
    max(so_ngay_qua_han) AS so_ngay_qua_han_lon_nhat
   FROM public.v_cong_no_tam_ung ct
  GROUP BY nhan_vien_nhan_ung_id;


--
-- Name: VIEW v_cong_no_tam_ung_theo_nguoi; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_cong_no_tam_ung_theo_nguoi IS 'Tổng hợp công nợ tạm ứng theo từng nhân viên. Chỉ đếm khoản ĐÃ CHI (da_ung > 0) là công nợ (mig 26); khoản duyệt-chưa-chi theo dõi ở tab Thanh toán.';


--
-- Name: v_giao_dich_vay; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_giao_dich_vay WITH (security_invoker='on') AS
 SELECT g.id,
    'lich_su'::text AS nguon_ban_ghi,
    g.doi_tuong_vay_id,
    k.nhom_cong_no,
    g.ngay,
    g.so_tien,
    g.noi_dung AS dien_giai,
    g.cong_ty_id,
    g.quy_tien_mat_id,
    g.tai_khoan_ngan_hang_id
   FROM (public.giao_dich_lich_su g
     JOIN public.khoan_muc_thu k ON ((k.id = g.khoan_muc_thu_id)))
  WHERE ((g.loai = 'thu'::text) AND (k.nhom_cong_no IS NOT NULL))
UNION ALL
 SELECT g.id,
    'lich_su'::text AS nguon_ban_ghi,
    g.doi_tuong_vay_id,
    k.nhom_cong_no,
    g.ngay,
    g.so_tien,
    g.noi_dung AS dien_giai,
    g.cong_ty_id,
    g.quy_tien_mat_id,
    g.tai_khoan_ngan_hang_id
   FROM (public.giao_dich_lich_su g
     JOIN public.khoan_muc_chi k ON ((k.id = g.khoan_muc_chi_id)))
  WHERE ((g.loai = 'chi'::text) AND (k.nhom_cong_no IS NOT NULL))
UNION ALL
 SELECT p.id,
    'phieu_thu'::text AS nguon_ban_ghi,
    p.doi_tuong_vay_id,
    k.nhom_cong_no,
    p.ngay_thu AS ngay,
    p.so_tien,
    p.dien_giai,
    p.cong_ty_id,
    p.quy_tien_mat_id,
    p.tai_khoan_ngan_hang_id
   FROM (public.phieu_thu p
     JOIN public.khoan_muc_thu k ON ((k.id = p.khoan_muc_thu_id)))
  WHERE ((p.trang_thai = 'da_thu'::text) AND (k.nhom_cong_no IS NOT NULL))
UNION ALL
 SELECT ct.id,
    'phieu_chi'::text AS nguon_ban_ghi,
    dn.doi_tuong_vay_id,
    k.nhom_cong_no,
    ltt.ngay_tra AS ngay,
    ct.so_tien,
    ((dn.noi_dung || ' / '::text) || md.dien_giai) AS dien_giai,
    dn.cong_ty_id,
    ltt.quy_tien_mat_id,
    ltt.tai_khoan_ngan_hang_id
   FROM (((((public.chi_tiet_lan_tra ct
     JOIN public.lan_tra_tien ltt ON ((ltt.id = ct.lan_tra_tien_id)))
     JOIN public.muc_de_nghi md ON ((md.id = ct.muc_de_nghi_id)))
     JOIN public.khoan_muc_chi k ON ((k.id = md.khoan_muc_chi_id)))
     JOIN public.dot_duyet dd ON ((dd.id = ltt.dot_duyet_id)))
     JOIN public.de_nghi dn ON ((dn.id = dd.de_nghi_id)))
  WHERE (k.nhom_cong_no IS NOT NULL);


--
-- Name: VIEW v_giao_dich_vay; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_giao_dich_vay IS 'Từng dòng tiền vay / cho vay, gom sổ lịch sử + phiếu thu + tiền chi thật về một chỗ. Chỉ tiền ĐÃ CHẠY, không tính số mới duyệt (mig 38).';


--
-- Name: v_cong_no_vay; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_cong_no_vay WITH (security_invoker='on') AS
 SELECT dt.id AS doi_tuong_id,
    dt.ma AS doi_tuong_ma,
    COALESCE(dt.ten, '(chưa gán đối tượng)'::text) AS doi_tuong_ten,
    dt.loai AS doi_tuong_loai,
    sum((v.so_tien)::numeric) FILTER (WHERE (v.nhom_cong_no = 'di_vay'::text)) AS da_vay,
    sum((v.so_tien)::numeric) FILTER (WHERE (v.nhom_cong_no = 'tra_no_vay'::text)) AS da_tra_no,
    sum((v.so_tien)::numeric) FILTER (WHERE (v.nhom_cong_no = 'cho_vay'::text)) AS da_cho_vay,
    sum((v.so_tien)::numeric) FILTER (WHERE (v.nhom_cong_no = 'thu_no_cho_vay'::text)) AS da_thu_no,
    sum((v.so_tien)::numeric) FILTER (WHERE (v.nhom_cong_no = 'lai_vay'::text)) AS lai_da_tra,
    (COALESCE(sum((v.so_tien)::numeric) FILTER (WHERE (v.nhom_cong_no = 'di_vay'::text)), (0)::numeric) - COALESCE(sum((v.so_tien)::numeric) FILTER (WHERE (v.nhom_cong_no = 'tra_no_vay'::text)), (0)::numeric)) AS con_no,
    (COALESCE(sum((v.so_tien)::numeric) FILTER (WHERE (v.nhom_cong_no = 'cho_vay'::text)), (0)::numeric) - COALESCE(sum((v.so_tien)::numeric) FILTER (WHERE (v.nhom_cong_no = 'thu_no_cho_vay'::text)), (0)::numeric)) AS con_phai_thu,
    count(*) AS so_giao_dich,
    min(v.ngay) AS ngay_dau,
    max(v.ngay) AS ngay_cuoi
   FROM (public.v_giao_dich_vay v
     LEFT JOIN public.doi_tuong_vay dt ON ((dt.id = v.doi_tuong_vay_id)))
  GROUP BY dt.id, dt.ma, dt.ten, dt.loai;


--
-- Name: VIEW v_cong_no_vay; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_cong_no_vay IS 'Công nợ vay / cho vay theo TỪNG ĐỐI TƯỢNG. con_no = mình nợ họ (đã vay − đã trả gốc); con_phai_thu = họ nợ mình (đã cho vay − đã thu). Lãi vay để riêng, không trừ vào gốc. Dòng đối tượng null = giao dịch chưa gán tên, cố ý hiện ra chứ không bỏ (mig 38).';


--
-- Name: v_de_nghi_trong_pham_vi; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_de_nghi_trong_pham_vi AS
 SELECT id AS de_nghi_id
   FROM public.de_nghi d
  WHERE ((NOT private.bi_siet_theo_nguon_tien()) OR (nguoi_de_xuat_id = private.nhan_vien_hien_tai()) OR (nhan_vien_nhan_ung_id = private.nhan_vien_hien_tai()) OR (EXISTS ( SELECT 1
           FROM (public.dot_duyet dd
             JOIN public.lan_tra_tien l ON ((l.dot_duyet_id = dd.id)))
          WHERE ((dd.de_nghi_id = d.id) AND private.duoc_xem_nguon_tien(l.quy_tien_mat_id, l.tai_khoan_ngan_hang_id)))) OR ((loai = 'tam_ung'::text) AND (EXISTS ( SELECT 1
           FROM public.nguon_tien_nhan_vien g
          WHERE ((g.nhan_vien_id = d.nhan_vien_nhan_ung_id) AND private.duoc_xem_nguon_tien(g.quy_tien_mat_id, g.tai_khoan_ngan_hang_id))))) OR (EXISTS ( SELECT 1
           FROM (public.de_nghi goc
             JOIN public.nguon_tien_nhan_vien g ON ((g.nhan_vien_id = goc.nhan_vien_nhan_ung_id)))
          WHERE ((goc.id = d.de_nghi_tam_ung_goc_id) AND private.duoc_xem_nguon_tien(g.quy_tien_mat_id, g.tai_khoan_ngan_hang_id)))));


--
-- Name: VIEW v_de_nghi_trong_pham_vi; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_de_nghi_trong_pham_vi IS 'Id các đề nghị thuộc phạm vi nguồn tiền người đang đăng nhập phụ trách (mig 49), dùng cho MÀN DANH SÁCH ĐỀ NGHỊ. Gồm: đã chi từ nguồn mình, tạm ứng chạy vào quỹ mình, quyết toán của tạm ứng đó, và việc của chính mình. KTT/Chủ tịch/Quản trị thấy tất. ĐÂY LÀ LỌC MÀN HÌNH, không phải chốt chặn — cố ý không siết RLS bảng de_nghi vì sẽ giấu mất những phiếu chờ chi và làm tắc tab Chi tiền.';


--
-- Name: v_dot_duyet_tong_hop; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_dot_duyet_tong_hop WITH (security_invoker='on') AS
 SELECT dd.id AS dot_duyet_id,
    dd.de_nghi_id,
    dd.so_dot,
    dd.trang_thai AS trang_thai_duyet,
    dd.ktt_id,
    dd.ktt_luc,
    dd.chu_tich_id,
    dd.chu_tich_luc,
    dd.ly_do_dong,
    COALESCE(m.tong_duyet, (0)::numeric) AS so_tien_duyet,
    COALESCE(m.tong_da_tra, (0)::numeric) AS so_tien_da_tra,
    COALESCE(m.tong_con_no, (0)::numeric) AS so_tien_con_phai_tra,
    COALESCE(t.so_lan_tra, (0)::bigint) AS so_lan_tra,
    t.ngay_tra_gan_nhat,
        CASE
            WHEN (dd.trang_thai = 'bi_tu_choi'::text) THEN 'bi_tu_choi'::text
            WHEN (dd.trang_thai = 'cho_chu_tich'::text) THEN 'cho_chu_tich'::text
            WHEN (dd.trang_thai = 'da_dong'::text) THEN 'da_dong'::text
            WHEN (COALESCE(m.tong_da_tra, (0)::numeric) = (0)::numeric) THEN 'cho_tra'::text
            WHEN (COALESCE(m.tong_con_no, (0)::numeric) <= (0)::numeric) THEN 'da_tra_du'::text
            ELSE 'dang_tra'::text
        END AS trang_thai_tra
   FROM ((public.dot_duyet dd
     LEFT JOIN LATERAL ( SELECT sum((v.so_tien_duyet)::numeric) AS tong_duyet,
            sum(v.so_tien_da_tra) AS tong_da_tra,
            sum(v.so_tien_con_no) AS tong_con_no
           FROM public.v_muc_tong_hop v
          WHERE (v.dot_duyet_id = dd.id)) m ON (true))
     LEFT JOIN LATERAL ( SELECT count(*) AS so_lan_tra,
            max(ltt.ngay_tra) AS ngay_tra_gan_nhat
           FROM public.lan_tra_tien ltt
          WHERE (ltt.dot_duyet_id = dd.id)) t ON (true));


--
-- Name: VIEW v_dot_duyet_tong_hop; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_dot_duyet_tong_hop IS 'Mỗi đợt duyệt: số duyệt, đã trả, còn phải trả, trạng thái trả tiền. Tất cả cộng lên từ v_muc_tong_hop.';


--
-- Name: v_dot_can_chi; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_dot_can_chi WITH (security_invoker='on') AS
 SELECT dot_duyet_id,
    private.con_phai_chi_that(dot_duyet_id) AS he_thong_doi_chi,
    private.tra_bu_toi_da(dot_duyet_id) AS duoc_tra_bu
   FROM public.v_dot_duyet_tong_hop v;


--
-- Name: VIEW v_dot_can_chi; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_dot_can_chi IS 'Mỗi đợt duyệt: he_thong_doi_chi = số hệ thống ĐÒI chi (dựng Việc cần làm), duoc_tra_bu = số KTTT ĐƯỢC PHÉP chi nếu chủ động (mig 54). Với đợt quyết toán hai số này khác nhau: đòi 0, nhưng được trả bù phần vượt hạn mức đã duyệt. Giao diện đọc view này thay vì tự tính lại công thức.';


--
-- Name: v_khoan_am_cho_bu; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_khoan_am_cho_bu WITH (security_invoker='on') AS
 SELECT nhan_vien_nhan_ung_id,
    de_nghi_tam_ung_id,
    so_de_nghi,
    ngay_de_nghi,
    (- con_no) AS so_tien_am
   FROM public.v_cong_no_tam_ung c
  WHERE (con_no < (0)::numeric);


--
-- Name: VIEW v_khoan_am_cho_bu; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_khoan_am_cho_bu IS 'Các khoản tạm ứng đang ÂM (công ty nợ lại người nhận ứng) — màn Thanh toán đọc để báo "lần chi này sẽ bù vào đâu" trước khi bấm. Mig 43.';


--
-- Name: v_ngan_sach; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_ngan_sach WITH (security_invoker='on') AS
 SELECT ns.id AS ngan_sach_id,
    ns.nam,
    ns.thang,
    ns.cong_ty_id,
    ns.du_an_id,
    ns.khoan_muc_chi_id,
    ns.so_tien AS ngan_sach,
    COALESCE(cp.da_dung, (0)::numeric) AS da_dung,
    ((ns.so_tien)::numeric - COALESCE(cp.da_dung, (0)::numeric)) AS con_lai
   FROM (public.ngan_sach ns
     LEFT JOIN LATERAL ( SELECT sum((v.so_tien)::numeric) AS da_dung
           FROM public.v_chi_phi v
          WHERE ((v.khoan_muc_chi_id = ns.khoan_muc_chi_id) AND (EXTRACT(year FROM v.ngay_ghi_nhan) = (ns.nam)::numeric) AND ((ns.thang IS NULL) OR (EXTRACT(month FROM v.ngay_ghi_nhan) = (ns.thang)::numeric)) AND ((ns.cong_ty_id IS NULL) OR (v.cong_ty_id = ns.cong_ty_id)) AND ((ns.du_an_id IS NULL) OR (v.du_an_id = ns.du_an_id)))) cp ON (true))
  WHERE ns.dang_dung;


--
-- Name: VIEW v_ngan_sach; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_ngan_sach IS 'Ngân sách: đã dùng và còn lại, tính từ sổ chi phí. KHÔNG có cột da_dung lưu sẵn trong bảng ngan_sach.';


--
-- Name: v_nhap_quy_trung; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_nhap_quy_trung WITH (security_invoker='on') AS
 SELECT pt.id AS phieu_thu_id,
    pt.so_phieu,
    pt.ngay_thu,
    pt.so_tien,
    pt.dien_giai,
    pt.quy_tien_mat_id,
    q.ten AS quy_ten,
    b.id AS but_toan_id,
    b.ngay AS but_toan_ngay,
    dn.so_de_nghi AS tam_ung_goc,
    nv.ho_ten AS nguoi_nhan_ung
   FROM ((((public.phieu_thu pt
     JOIN public.quy_tien_mat q ON ((q.id = pt.quy_tien_mat_id)))
     JOIN public.but_toan_quy_cong_truong b ON (((b.quy_tien_mat_id = pt.quy_tien_mat_id) AND (b.loai = 'nhap'::text) AND ((b.so_tien)::numeric = (pt.so_tien)::numeric) AND (abs((b.ngay - pt.ngay_thu)) <= 7))))
     JOIN public.de_nghi dn ON ((dn.id = b.de_nghi_tam_ung_goc_id)))
     JOIN public.nhan_vien nv ON ((nv.id = b.nhan_vien_id)))
  WHERE ((pt.trang_thai = 'da_thu'::text) AND (pt.de_nghi_tam_ung_goc_id IS NULL) AND (NOT pt.xac_nhan_khong_trung_nhap_quy));


--
-- Name: VIEW v_nhap_quy_trung; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_nhap_quy_trung IS 'Phiếu thu đang NGHI nhận trùng với bút toán nhập quỹ công trường tự động (mig 55): cùng quỹ, đúng số tiền, lệch tối đa 7 ngày, và người lập chưa xác nhận là khoản khác. Mỗi dòng ở đây là quỹ đang khai THỪA đúng số tiền đó — Quản trị hủy phiếu ở màn Giao dịch, hoặc bật xac_nhan_khong_trung_nhap_quy nếu thật sự là khoản khác.';


--
-- Name: v_so_quy; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_so_quy WITH (security_invoker='on') AS
 SELECT tdk.id,
    'ton_dau_ky'::text AS loai,
    tdk.quy_tien_mat_id,
    tdk.tai_khoan_ngan_hang_id,
    tdk.ngay,
    tdk.so_tien AS tien_vao,
    (0)::public.tien_te AS tien_ra,
    NULL::uuid AS cong_ty_id,
    'Tồn đầu kỳ'::text AS dien_giai,
    NULL::text AS so_chung_tu,
    tdk.created_at
   FROM public.ton_dau_ky tdk
  WHERE private.duoc_xem_nguon_tien(tdk.quy_tien_mat_id, tdk.tai_khoan_ngan_hang_id)
UNION ALL
 SELECT pt.id,
    'thu'::text AS loai,
    pt.quy_tien_mat_id,
    pt.tai_khoan_ngan_hang_id,
    pt.ngay_thu AS ngay,
    pt.so_tien AS tien_vao,
    (0)::public.tien_te AS tien_ra,
    pt.cong_ty_id,
    pt.dien_giai,
    pt.so_phieu AS so_chung_tu,
    pt.created_at
   FROM public.phieu_thu pt
  WHERE ((pt.trang_thai = 'da_thu'::text) AND private.duoc_xem_nguon_tien(pt.quy_tien_mat_id, pt.tai_khoan_ngan_hang_id))
UNION ALL
 SELECT ltt.id,
    'chi'::text AS loai,
    ltt.quy_tien_mat_id,
    ltt.tai_khoan_ngan_hang_id,
    ltt.ngay_tra AS ngay,
    (0)::public.tien_te AS tien_vao,
    ltt.so_tien AS tien_ra,
    dn.cong_ty_id,
    dn.noi_dung AS dien_giai,
    dn.so_de_nghi AS so_chung_tu,
    ltt.created_at
   FROM ((public.lan_tra_tien ltt
     JOIN public.dot_duyet dd ON ((dd.id = ltt.dot_duyet_id)))
     JOIN public.de_nghi dn ON ((dn.id = dd.de_nghi_id)))
  WHERE private.duoc_xem_nguon_tien(ltt.quy_tien_mat_id, ltt.tai_khoan_ngan_hang_id)
UNION ALL
 SELECT gls.id,
    gls.loai,
    gls.quy_tien_mat_id,
    gls.tai_khoan_ngan_hang_id,
    gls.ngay,
        CASE
            WHEN (gls.loai = 'thu'::text) THEN gls.so_tien
            ELSE (0)::public.tien_te
        END AS tien_vao,
        CASE
            WHEN (gls.loai = 'chi'::text) THEN gls.so_tien
            ELSE (0)::public.tien_te
        END AS tien_ra,
    gls.cong_ty_id,
    gls.noi_dung AS dien_giai,
    gls.ma_nguon AS so_chung_tu,
    gls.created_at
   FROM public.giao_dich_lich_su gls
  WHERE private.duoc_xem_nguon_tien(gls.quy_tien_mat_id, gls.tai_khoan_ngan_hang_id)
UNION ALL
 SELECT cq.id,
    'chuyen_quy_di'::text AS loai,
    cq.tu_quy_tien_mat_id AS quy_tien_mat_id,
    cq.tu_tai_khoan_ngan_hang_id AS tai_khoan_ngan_hang_id,
    cq.ngay,
    (0)::public.tien_te AS tien_vao,
    cq.so_tien AS tien_ra,
    NULL::uuid AS cong_ty_id,
    ('Chuyển đi — '::text || cq.dien_giai) AS dien_giai,
    cq.so_phieu AS so_chung_tu,
    cq.created_at
   FROM public.chuyen_quy cq
  WHERE private.duoc_xem_nguon_tien(cq.tu_quy_tien_mat_id, cq.tu_tai_khoan_ngan_hang_id)
UNION ALL
 SELECT cq.id,
    'chuyen_quy_den'::text AS loai,
    cq.den_quy_tien_mat_id AS quy_tien_mat_id,
    cq.den_tai_khoan_ngan_hang_id AS tai_khoan_ngan_hang_id,
    cq.ngay,
    cq.so_tien AS tien_vao,
    (0)::public.tien_te AS tien_ra,
    NULL::uuid AS cong_ty_id,
    ('Nhận về — '::text || cq.dien_giai) AS dien_giai,
    cq.so_phieu AS so_chung_tu,
    cq.created_at
   FROM public.chuyen_quy cq
  WHERE private.duoc_xem_nguon_tien(cq.den_quy_tien_mat_id, cq.den_tai_khoan_ngan_hang_id)
UNION ALL
 SELECT b.id,
    ('quy_cong_truong_'::text || b.loai) AS loai,
    b.quy_tien_mat_id,
    NULL::uuid AS tai_khoan_ngan_hang_id,
    b.ngay,
        CASE
            WHEN (b.loai = 'nhap'::text) THEN b.so_tien
            ELSE (0)::public.tien_te
        END AS tien_vao,
        CASE
            WHEN (b.loai = 'chi'::text) THEN b.so_tien
            ELSE (0)::public.tien_te
        END AS tien_ra,
    dn.cong_ty_id,
    b.dien_giai,
    dn.so_de_nghi AS so_chung_tu,
    b.created_at
   FROM (public.but_toan_quy_cong_truong b
     JOIN public.de_nghi dn ON ((dn.id = b.de_nghi_tam_ung_goc_id)))
  WHERE private.duoc_xem_nguon_tien(b.quy_tien_mat_id, NULL::uuid);


--
-- Name: VIEW v_so_quy; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_so_quy IS 'SỔ QUỸ: tồn đầu kỳ + phiếu thu + lần trả + sổ lịch sử + chuyển quỹ (hai vế, mig 36) + quỹ công trường (hai vế, mig 42). Nguồn sự thật của số dư. TỪ MIG 48: mỗi nhánh lọc theo private.duoc_xem_nguon_tien() — ai được gán nguồn nào chỉ thấy giao dịch của nguồn đó; chưa gán nguồn nào, hoặc phiên hệ thống, thì thấy đủ. Lưu ý: id KHÔNG duy nhất (hai vế chuyển quỹ dùng chung id) — phân trang phải sắp theo (id, loai).';


--
-- Name: v_quy_chung_chi_ho; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_quy_chung_chi_ho WITH (security_invoker='on') AS
 SELECT quy_tien_mat_id,
    cong_ty_id,
    (date_trunc('month'::text, (ngay)::timestamp with time zone))::date AS thang,
    sum((tien_ra)::numeric) AS tong_chi_ho
   FROM public.v_so_quy sq
  WHERE ((loai = 'chi'::text) AND (quy_tien_mat_id IS NOT NULL) AND (cong_ty_id IS NOT NULL))
  GROUP BY quy_tien_mat_id, cong_ty_id, (date_trunc('month'::text, (ngay)::timestamp with time zone));


--
-- Name: VIEW v_quy_chung_chi_ho; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_quy_chung_chi_ho IS 'Quỹ chung đã chi hộ từng công ty bao nhiêu, theo tháng. Phục vụ đối chiếu nội bộ giữa 2 pháp nhân.';


--
-- Name: v_quy_tien_mat_theo_khoan_muc; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_quy_tien_mat_theo_khoan_muc WITH (security_invoker='on') AS
 SELECT d.id,
    d.nguon_ban_ghi,
    d.quy_tien_mat_id,
    q.ma AS quy_ma,
    q.ten AS quy_ten,
    d.ngay,
    d.chieu,
    d.khoan_muc_id,
    d.khoan_muc_ma,
    d.khoan_muc_ten,
    d.nhom_cong_no,
        CASE
            WHEN (d.nguon_ban_ghi = ANY (ARRAY['chuyen_quy'::text, 'quy_cong_truong'::text])) THEN 'noi_bo'::text
            WHEN (d.nhom_cong_no = ANY (ARRAY['di_vay'::text, 'tra_no_vay'::text, 'lai_vay'::text])) THEN 'vay'::text
            WHEN (d.nhom_cong_no = ANY (ARRAY['cho_vay'::text, 'thu_no_cho_vay'::text])) THEN 'cho_vay'::text
            WHEN (d.chieu = 'vao'::text) THEN 'thu'::text
            ELSE 'chi'::text
        END AS nhom_bao_cao,
    d.so_tien,
    d.dien_giai,
    d.so_chung_tu,
    d.cong_ty_id,
    d.du_an_id
   FROM (( SELECT pt.id,
            'phieu_thu'::text AS nguon_ban_ghi,
            pt.quy_tien_mat_id,
            pt.ngay_thu AS ngay,
            'vao'::text AS chieu,
            kt.id AS khoan_muc_id,
            kt.ma AS khoan_muc_ma,
            kt.ten AS khoan_muc_ten,
            kt.nhom_cong_no,
            pt.so_tien,
            pt.dien_giai,
            pt.so_phieu AS so_chung_tu,
            pt.cong_ty_id,
            pt.du_an_id
           FROM (public.phieu_thu pt
             LEFT JOIN public.khoan_muc_thu kt ON ((kt.id = pt.khoan_muc_thu_id)))
          WHERE ((pt.trang_thai = 'da_thu'::text) AND (pt.quy_tien_mat_id IS NOT NULL) AND private.duoc_xem_nguon_tien(pt.quy_tien_mat_id, NULL::uuid))
        UNION ALL
         SELECT gls.id,
            'lich_su'::text AS text,
            gls.quy_tien_mat_id,
            gls.ngay,
            'vao'::text AS text,
            kt.id,
            kt.ma,
            kt.ten,
            kt.nhom_cong_no,
            gls.so_tien,
            gls.noi_dung,
            gls.ma_nguon,
            gls.cong_ty_id,
            gls.du_an_id
           FROM (public.giao_dich_lich_su gls
             LEFT JOIN public.khoan_muc_thu kt ON ((kt.id = gls.khoan_muc_thu_id)))
          WHERE ((gls.loai = 'thu'::text) AND (gls.quy_tien_mat_id IS NOT NULL) AND private.duoc_xem_nguon_tien(gls.quy_tien_mat_id, NULL::uuid))
        UNION ALL
         SELECT gls.id,
            'lich_su'::text AS text,
            gls.quy_tien_mat_id,
            gls.ngay,
            'ra'::text AS text,
            kc.id,
            kc.ma,
            kc.ten,
            kc.nhom_cong_no,
            gls.so_tien,
            gls.noi_dung,
            gls.ma_nguon,
            gls.cong_ty_id,
            gls.du_an_id
           FROM (public.giao_dich_lich_su gls
             LEFT JOIN public.khoan_muc_chi kc ON ((kc.id = gls.khoan_muc_chi_id)))
          WHERE ((gls.loai = 'chi'::text) AND (gls.quy_tien_mat_id IS NOT NULL) AND private.duoc_xem_nguon_tien(gls.quy_tien_mat_id, NULL::uuid))
        UNION ALL
         SELECT ct.id,
            'lan_tra_tien'::text AS text,
            ltt.quy_tien_mat_id,
            ltt.ngay_tra,
            'ra'::text AS text,
            kc.id,
            kc.ma,
            kc.ten,
            kc.nhom_cong_no,
            ct.so_tien,
            COALESCE(m.dien_giai, dn.noi_dung) AS "coalesce",
            dn.so_de_nghi,
            dn.cong_ty_id,
            m.du_an_id
           FROM (((((public.chi_tiet_lan_tra ct
             JOIN public.lan_tra_tien ltt ON ((ltt.id = ct.lan_tra_tien_id)))
             JOIN public.muc_de_nghi m ON ((m.id = ct.muc_de_nghi_id)))
             JOIN public.dot_duyet dd ON ((dd.id = ltt.dot_duyet_id)))
             JOIN public.de_nghi dn ON ((dn.id = dd.de_nghi_id)))
             LEFT JOIN public.khoan_muc_chi kc ON ((kc.id = m.khoan_muc_chi_id)))
          WHERE ((ltt.quy_tien_mat_id IS NOT NULL) AND private.duoc_xem_nguon_tien(ltt.quy_tien_mat_id, NULL::uuid))
        UNION ALL
         SELECT cq.id,
            'chuyen_quy'::text AS text,
            cq.tu_quy_tien_mat_id,
            cq.ngay,
            'ra'::text AS text,
            NULL::uuid AS uuid,
            NULL::text AS text,
            NULL::text AS text,
            NULL::text AS text,
            cq.so_tien,
            ('Chuyển đi — '::text || cq.dien_giai),
            cq.so_phieu,
            NULL::uuid AS uuid,
            NULL::uuid AS uuid
           FROM public.chuyen_quy cq
          WHERE ((cq.tu_quy_tien_mat_id IS NOT NULL) AND private.duoc_xem_nguon_tien(cq.tu_quy_tien_mat_id, NULL::uuid))
        UNION ALL
         SELECT cq.id,
            'chuyen_quy'::text AS text,
            cq.den_quy_tien_mat_id,
            cq.ngay,
            'vao'::text AS text,
            NULL::uuid AS uuid,
            NULL::text AS text,
            NULL::text AS text,
            NULL::text AS text,
            cq.so_tien,
            ('Nhận về — '::text || cq.dien_giai),
            cq.so_phieu,
            NULL::uuid AS uuid,
            NULL::uuid AS uuid
           FROM public.chuyen_quy cq
          WHERE ((cq.den_quy_tien_mat_id IS NOT NULL) AND private.duoc_xem_nguon_tien(cq.den_quy_tien_mat_id, NULL::uuid))
        UNION ALL
         SELECT b.id,
            'quy_cong_truong'::text AS text,
            b.quy_tien_mat_id,
            b.ngay,
                CASE
                    WHEN (b.loai = 'nhap'::text) THEN 'vao'::text
                    ELSE 'ra'::text
                END AS "case",
            NULL::uuid AS uuid,
            NULL::text AS text,
            NULL::text AS text,
            NULL::text AS text,
            b.so_tien,
            b.dien_giai,
            dn.so_de_nghi,
            dn.cong_ty_id,
            NULL::uuid AS uuid
           FROM (public.but_toan_quy_cong_truong b
             JOIN public.de_nghi dn ON ((dn.id = b.de_nghi_tam_ung_goc_id)))
          WHERE private.duoc_xem_nguon_tien(b.quy_tien_mat_id, NULL::uuid)) d
     LEFT JOIN public.quy_tien_mat q ON ((q.id = d.quy_tien_mat_id)))
  WHERE ((auth.uid() IS NULL) OR private.co_vai_tro('quan_tri'::text));


--
-- Name: VIEW v_quy_tien_mat_theo_khoan_muc; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_quy_tien_mat_theo_khoan_muc IS 'Tiền vào/ra từng QUỸ TIỀN MẶT kèm KHOẢN MỤC (mig 50) — chỗ duy nhất nối được hai chiều đó. CHỈ QUẢN TRỊ đọc được (chốt 16/09); phiên hệ thống không có auth.uid() thì được. nhom_bao_cao: thu / chi / vay / cho_vay (suy từ cờ nhom_cong_no của mig 38) và noi_bo (chuyển quỹ + quỹ công trường, không có khoản mục nhưng vẫn làm đổi số dư nên phải giữ để cộng ra đúng sổ). Chi bổ qua chi_tiet_lan_tra để tách đúng từng khoản mục, ngày lấy lúc tiền RỜI QUỸ. Lưu ý: id KHÔNG duy nhất (hai vế chuyển quỹ chung id).';


--
-- Name: v_so_du_nguon_tien; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_so_du_nguon_tien AS
 SELECT 'quy_tien_mat'::text AS loai_nguon,
    q.id AS nguon_tien_id,
    q.ma,
    q.ten,
    NULL::uuid AS cong_ty_id,
    (COALESCE(sum((sq.tien_vao)::numeric), (0)::numeric) - COALESCE(sum((sq.tien_ra)::numeric), (0)::numeric)) AS so_du,
    false AS la_tai_khoan_vay
   FROM (public.quy_tien_mat q
     LEFT JOIN public.v_so_quy sq ON ((sq.quy_tien_mat_id = q.id)))
  WHERE (((auth.uid() IS NULL) OR private.la_nguoi_quan_ly_tai_chinh()) AND private.duoc_xem_nguon_tien(q.id, NULL::uuid))
  GROUP BY q.id, q.ma, q.ten
UNION ALL
 SELECT 'tai_khoan_ngan_hang'::text AS loai_nguon,
    tk.id AS nguon_tien_id,
    tk.so_tai_khoan AS ma,
    ((tk.ten_ngan_hang || ' - '::text) || tk.so_tai_khoan) AS ten,
    tk.cong_ty_id,
    (COALESCE(sum((sq.tien_vao)::numeric), (0)::numeric) - COALESCE(sum((sq.tien_ra)::numeric), (0)::numeric)) AS so_du,
    tk.la_tai_khoan_vay
   FROM (public.tai_khoan_ngan_hang tk
     LEFT JOIN public.v_so_quy sq ON ((sq.tai_khoan_ngan_hang_id = tk.id)))
  WHERE (((auth.uid() IS NULL) OR private.la_nguoi_quan_ly_tai_chinh()) AND private.duoc_xem_nguon_tien(NULL::uuid, tk.id))
  GROUP BY tk.id, tk.so_tai_khoan, tk.ten_ngan_hang, tk.cong_ty_id, tk.la_tai_khoan_vay;


--
-- Name: VIEW v_so_du_nguon_tien; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_so_du_nguon_tien IS 'Số dư từng nguồn tiền. Hai tầng lọc: phải là người quản lý tài chính (mig 48 — trước đây thiếu, nhân viên thường rơi ra ngoài chỉ nhờ chưa được gán nguồn), và nguồn phải nằm trong phần được phân quyền (mig 35). Phiên hệ thống không có auth.uid() thì thấy đủ — vá lỗi cron Telegram trống 30/08–07/09.';


--
-- Name: v_so_du_quy_ca_nhan; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_so_du_quy_ca_nhan WITH (security_invoker='on') AS
 SELECT nv.id AS nhan_vien_id,
    nv.ma,
    nv.ho_ten AS ten,
    sum(c.con_no) AS so_du,
    count(*) AS so_khoan,
    min(c.ngay_de_nghi) AS ung_som_nhat,
    min(c.han_hoan_ung) FILTER (WHERE (c.con_no > (0)::numeric)) AS han_hoan_ung_gan_nhat
   FROM (public.v_cong_no_tam_ung c
     JOIN public.nhan_vien nv ON ((nv.id = c.nhan_vien_nhan_ung_id)))
  WHERE (NOT (EXISTS ( SELECT 1
           FROM public.nguon_tien_nhan_vien g
          WHERE ((g.nhan_vien_id = nv.id) AND (g.quy_tien_mat_id IS NOT NULL)))))
  GROUP BY nv.id, nv.ma, nv.ho_ten
 HAVING (sum(c.con_no) <> (0)::numeric);


--
-- Name: VIEW v_so_du_quy_ca_nhan; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_so_du_quy_ca_nhan IS '"Quỹ công trường" ẢO của người KHÔNG quản lý quỹ nào: tiền tạm ứng họ còn đang cầm (tổng con_no). Người CÓ quỹ được gán đã bị loại khỏi view này từ mig 42 — tiền của họ nằm ở số dư quỹ thật, cộng cả hai là đếm hai lần.';


--
-- Name: v_so_quy_luy_ke; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_so_quy_luy_ke WITH (security_invoker='on') AS
 SELECT id,
    loai,
    quy_tien_mat_id,
    tai_khoan_ngan_hang_id,
    ngay,
    tien_vao,
    tien_ra,
    cong_ty_id,
    dien_giai,
    so_chung_tu,
    created_at,
    sum(((tien_vao)::numeric - (tien_ra)::numeric)) OVER (PARTITION BY COALESCE(quy_tien_mat_id, tai_khoan_ngan_hang_id) ORDER BY ngay, created_at, id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS so_du_luy_ke
   FROM public.v_so_quy sq;


--
-- Name: VIEW v_so_quy_luy_ke; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_so_quy_luy_ke IS 'Sổ quỹ chi tiết có số dư lũy kế sau mỗi dòng. Sắp theo ngày, rồi thời điểm ghi, rồi id — thứ tự ổn định, xem lại bao nhiêu lần cũng ra một kết quả.';


--
-- Name: v_tam_ung_con_giu; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_tam_ung_con_giu WITH (security_invoker='on') AS
 SELECT de_nghi_tam_ung_id,
    so_de_nghi,
    nhan_vien_nhan_ung_id,
    cong_ty_id,
    noi_dung,
    ngay_de_nghi,
    han_hoan_ung,
    da_ung,
    da_quyet_toan,
    con_no AS dang_giu
   FROM public.v_cong_no_tam_ung c
  WHERE (con_no > (0)::numeric);


--
-- Name: VIEW v_tam_ung_con_giu; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_tam_ung_con_giu IS 'Các khoản tạm ứng người nhận CÒN ĐANG GIỮ tiền (con_no > 0) — nguồn để cấn trừ sang đợt ứng sau (mig 39).';


--
-- Name: vai_tro_nhan_vien; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vai_tro_nhan_vien (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nhan_vien_id uuid NOT NULL,
    vai_tro text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT vai_tro_hop_le CHECK ((vai_tro = ANY (ARRAY['nhan_vien'::text, 'ke_toan_truong'::text, 'chu_tich'::text, 'ke_toan_thanh_toan'::text, 'quan_tri'::text])))
);


--
-- Name: TABLE vai_tro_nhan_vien; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.vai_tro_nhan_vien IS 'Vai trò hệ thống. Một người giữ nhiều vai trò được (KTT kiêm KT thanh toán).';


--
-- Name: bu_cong_no_am bu_cong_no_am_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bu_cong_no_am
    ADD CONSTRAINT bu_cong_no_am_pkey PRIMARY KEY (id);


--
-- Name: but_toan_quy_cong_truong but_toan_quy_cong_truong_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.but_toan_quy_cong_truong
    ADD CONSTRAINT but_toan_quy_cong_truong_pkey PRIMARY KEY (id);


--
-- Name: cau_hinh_he_thong cau_hinh_he_thong_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cau_hinh_he_thong
    ADD CONSTRAINT cau_hinh_he_thong_pkey PRIMARY KEY (id);


--
-- Name: chi_tiet_lan_tra chi_tiet_lan_tra_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chi_tiet_lan_tra
    ADD CONSTRAINT chi_tiet_lan_tra_pkey PRIMARY KEY (id);


--
-- Name: chung_tu_fmb chung_tu_fmb_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chung_tu_fmb
    ADD CONSTRAINT chung_tu_fmb_pkey PRIMARY KEY (id);


--
-- Name: chuyen_quy chuyen_quy_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chuyen_quy
    ADD CONSTRAINT chuyen_quy_pkey PRIMARY KEY (id);


--
-- Name: chuyen_quy chuyen_quy_so_phieu_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chuyen_quy
    ADD CONSTRAINT chuyen_quy_so_phieu_key UNIQUE (so_phieu);


--
-- Name: cong_ty cong_ty_ma_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cong_ty
    ADD CONSTRAINT cong_ty_ma_key UNIQUE (ma);


--
-- Name: cong_ty cong_ty_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cong_ty
    ADD CONSTRAINT cong_ty_pkey PRIMARY KEY (id);


--
-- Name: de_nghi de_nghi_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.de_nghi
    ADD CONSTRAINT de_nghi_pkey PRIMARY KEY (id);


--
-- Name: de_nghi de_nghi_so_de_nghi_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.de_nghi
    ADD CONSTRAINT de_nghi_so_de_nghi_key UNIQUE (so_de_nghi);


--
-- Name: doi_tuong_vay doi_tuong_vay_ma_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.doi_tuong_vay
    ADD CONSTRAINT doi_tuong_vay_ma_key UNIQUE (ma);


--
-- Name: doi_tuong_vay doi_tuong_vay_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.doi_tuong_vay
    ADD CONSTRAINT doi_tuong_vay_pkey PRIMARY KEY (id);


--
-- Name: dot_duyet dot_duyet_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dot_duyet
    ADD CONSTRAINT dot_duyet_pkey PRIMARY KEY (id);


--
-- Name: du_an du_an_ma_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.du_an
    ADD CONSTRAINT du_an_ma_key UNIQUE (ma);


--
-- Name: du_an du_an_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.du_an
    ADD CONSTRAINT du_an_pkey PRIMARY KEY (id);


--
-- Name: chung_tu_fmb duong_dan_khong_trung; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chung_tu_fmb
    ADD CONSTRAINT duong_dan_khong_trung UNIQUE (duong_dan);


--
-- Name: giao_dich_da_huy giao_dich_da_huy_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.giao_dich_da_huy
    ADD CONSTRAINT giao_dich_da_huy_pkey PRIMARY KEY (id);


--
-- Name: giao_dich_lich_su giao_dich_lich_su_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.giao_dich_lich_su
    ADD CONSTRAINT giao_dich_lich_su_pkey PRIMARY KEY (id);


--
-- Name: khach_hang khach_hang_ma_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.khach_hang
    ADD CONSTRAINT khach_hang_ma_key UNIQUE (ma);


--
-- Name: khach_hang khach_hang_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.khach_hang
    ADD CONSTRAINT khach_hang_pkey PRIMARY KEY (id);


--
-- Name: khoan_muc_chi khoan_muc_chi_ma_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.khoan_muc_chi
    ADD CONSTRAINT khoan_muc_chi_ma_key UNIQUE (ma);


--
-- Name: khoan_muc_chi khoan_muc_chi_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.khoan_muc_chi
    ADD CONSTRAINT khoan_muc_chi_pkey PRIMARY KEY (id);


--
-- Name: khoan_muc_thu khoan_muc_thu_ma_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.khoan_muc_thu
    ADD CONSTRAINT khoan_muc_thu_ma_key UNIQUE (ma);


--
-- Name: khoan_muc_thu khoan_muc_thu_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.khoan_muc_thu
    ADD CONSTRAINT khoan_muc_thu_pkey PRIMARY KEY (id);


--
-- Name: lan_tra_tien lan_tra_tien_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lan_tra_tien
    ADD CONSTRAINT lan_tra_tien_pkey PRIMARY KEY (id);


--
-- Name: lan_tra_tien lan_tra_va_dot; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lan_tra_tien
    ADD CONSTRAINT lan_tra_va_dot UNIQUE (id, dot_duyet_id);


--
-- Name: menu_nhan_vien menu_nhan_vien_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_nhan_vien
    ADD CONSTRAINT menu_nhan_vien_pkey PRIMARY KEY (nhan_vien_id, duong_dan);


--
-- Name: dot_duyet moi_dot_mot_so; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dot_duyet
    ADD CONSTRAINT moi_dot_mot_so UNIQUE (de_nghi_id, so_dot);


--
-- Name: chi_tiet_lan_tra moi_muc_mot_dong_moi_lan; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chi_tiet_lan_tra
    ADD CONSTRAINT moi_muc_mot_dong_moi_lan UNIQUE (lan_tra_tien_id, muc_de_nghi_id);


--
-- Name: muc_de_nghi moi_muc_mot_thu_tu; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.muc_de_nghi
    ADD CONSTRAINT moi_muc_mot_thu_tu UNIQUE (de_nghi_id, thu_tu);


--
-- Name: vai_tro_nhan_vien moi_vai_tro_mot_lan; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vai_tro_nhan_vien
    ADD CONSTRAINT moi_vai_tro_mot_lan UNIQUE (nhan_vien_id, vai_tro);


--
-- Name: muc_de_nghi muc_de_nghi_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.muc_de_nghi
    ADD CONSTRAINT muc_de_nghi_pkey PRIMARY KEY (id);


--
-- Name: muc_de_nghi muc_va_dot; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.muc_de_nghi
    ADD CONSTRAINT muc_va_dot UNIQUE (id, dot_duyet_id);


--
-- Name: ngan_sach ngan_sach_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ngan_sach
    ADD CONSTRAINT ngan_sach_pkey PRIMARY KEY (id);


--
-- Name: nguon_tien_nhan_vien nguon_tien_nhan_vien_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nguon_tien_nhan_vien
    ADD CONSTRAINT nguon_tien_nhan_vien_pkey PRIMARY KEY (id);


--
-- Name: nha_cung_cap nha_cung_cap_ma_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nha_cung_cap
    ADD CONSTRAINT nha_cung_cap_ma_key UNIQUE (ma);


--
-- Name: nha_cung_cap nha_cung_cap_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nha_cung_cap
    ADD CONSTRAINT nha_cung_cap_pkey PRIMARY KEY (id);


--
-- Name: nhan_vien nhan_vien_ma_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nhan_vien
    ADD CONSTRAINT nhan_vien_ma_key UNIQUE (ma);


--
-- Name: nhan_vien_nhay_cam nhan_vien_nhay_cam_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nhan_vien_nhay_cam
    ADD CONSTRAINT nhan_vien_nhay_cam_pkey PRIMARY KEY (nhan_vien_id);


--
-- Name: nhan_vien nhan_vien_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nhan_vien
    ADD CONSTRAINT nhan_vien_pkey PRIMARY KEY (id);


--
-- Name: nhan_vien nhan_vien_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nhan_vien
    ADD CONSTRAINT nhan_vien_user_id_key UNIQUE (user_id);


--
-- Name: nhat_ky nhat_ky_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nhat_ky
    ADD CONSTRAINT nhat_ky_pkey PRIMARY KEY (id);


--
-- Name: phieu_thu phieu_thu_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phieu_thu
    ADD CONSTRAINT phieu_thu_pkey PRIMARY KEY (id);


--
-- Name: phieu_thu phieu_thu_so_phieu_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phieu_thu
    ADD CONSTRAINT phieu_thu_so_phieu_key UNIQUE (so_phieu);


--
-- Name: quy_tien_mat quy_tien_mat_ma_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quy_tien_mat
    ADD CONSTRAINT quy_tien_mat_ma_key UNIQUE (ma);


--
-- Name: quy_tien_mat quy_tien_mat_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quy_tien_mat
    ADD CONSTRAINT quy_tien_mat_pkey PRIMARY KEY (id);


--
-- Name: tai_khoan_ngan_hang so_tai_khoan_khong_trung; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tai_khoan_ngan_hang
    ADD CONSTRAINT so_tai_khoan_khong_trung UNIQUE (ten_ngan_hang, so_tai_khoan);


--
-- Name: so_thu_tu_de_nghi so_thu_tu_de_nghi_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.so_thu_tu_de_nghi
    ADD CONSTRAINT so_thu_tu_de_nghi_pkey PRIMARY KEY (loai, ma_cong_ty, nam);


--
-- Name: tai_khoan_ngan_hang tai_khoan_ngan_hang_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tai_khoan_ngan_hang
    ADD CONSTRAINT tai_khoan_ngan_hang_pkey PRIMARY KEY (id);


--
-- Name: ton_dau_ky ton_dau_ky_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ton_dau_ky
    ADD CONSTRAINT ton_dau_ky_pkey PRIMARY KEY (id);


--
-- Name: vai_tro_nhan_vien vai_tro_nhan_vien_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vai_tro_nhan_vien
    ADD CONSTRAINT vai_tro_nhan_vien_pkey PRIMARY KEY (id);


--
-- Name: bu_cong_no_am_am_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX bu_cong_no_am_am_idx ON public.bu_cong_no_am USING btree (de_nghi_am_id);


--
-- Name: bu_cong_no_am_moi_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX bu_cong_no_am_moi_idx ON public.bu_cong_no_am USING btree (de_nghi_moi_id);


--
-- Name: but_toan_qct_goc_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX but_toan_qct_goc_idx ON public.but_toan_quy_cong_truong USING btree (de_nghi_tam_ung_goc_id);


--
-- Name: but_toan_qct_moi_dot_mot_dong; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX but_toan_qct_moi_dot_mot_dong ON public.but_toan_quy_cong_truong USING btree (dot_duyet_id) WHERE (dot_duyet_id IS NOT NULL);


--
-- Name: but_toan_qct_moi_lan_tra_mot_dong; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX but_toan_qct_moi_lan_tra_mot_dong ON public.but_toan_quy_cong_truong USING btree (lan_tra_tien_id) WHERE (lan_tra_tien_id IS NOT NULL);


--
-- Name: but_toan_qct_quy_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX but_toan_qct_quy_idx ON public.but_toan_quy_cong_truong USING btree (quy_tien_mat_id);


--
-- Name: chi_tiet_lan_tra_lan_tra_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX chi_tiet_lan_tra_lan_tra_idx ON public.chi_tiet_lan_tra USING btree (lan_tra_tien_id);


--
-- Name: chi_tiet_lan_tra_muc_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX chi_tiet_lan_tra_muc_idx ON public.chi_tiet_lan_tra USING btree (muc_de_nghi_id);


--
-- Name: chung_tu_fmb_chuyen_quy_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX chung_tu_fmb_chuyen_quy_idx ON public.chung_tu_fmb USING btree (chuyen_quy_id) WHERE (chuyen_quy_id IS NOT NULL);


--
-- Name: chung_tu_fmb_de_nghi_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX chung_tu_fmb_de_nghi_idx ON public.chung_tu_fmb USING btree (de_nghi_id) WHERE (de_nghi_id IS NOT NULL);


--
-- Name: chung_tu_fmb_lan_tra_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX chung_tu_fmb_lan_tra_idx ON public.chung_tu_fmb USING btree (lan_tra_tien_id) WHERE (lan_tra_tien_id IS NOT NULL);


--
-- Name: chung_tu_fmb_phieu_thu_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX chung_tu_fmb_phieu_thu_idx ON public.chung_tu_fmb USING btree (phieu_thu_id) WHERE (phieu_thu_id IS NOT NULL);


--
-- Name: chuyen_quy_den_quy_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX chuyen_quy_den_quy_idx ON public.chuyen_quy USING btree (den_quy_tien_mat_id) WHERE (den_quy_tien_mat_id IS NOT NULL);


--
-- Name: chuyen_quy_den_tk_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX chuyen_quy_den_tk_idx ON public.chuyen_quy USING btree (den_tai_khoan_ngan_hang_id) WHERE (den_tai_khoan_ngan_hang_id IS NOT NULL);


--
-- Name: chuyen_quy_ngay_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX chuyen_quy_ngay_idx ON public.chuyen_quy USING btree (ngay);


--
-- Name: chuyen_quy_tu_quy_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX chuyen_quy_tu_quy_idx ON public.chuyen_quy USING btree (tu_quy_tien_mat_id) WHERE (tu_quy_tien_mat_id IS NOT NULL);


--
-- Name: chuyen_quy_tu_tk_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX chuyen_quy_tu_tk_idx ON public.chuyen_quy USING btree (tu_tai_khoan_ngan_hang_id) WHERE (tu_tai_khoan_ngan_hang_id IS NOT NULL);


--
-- Name: de_nghi_cong_ty_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX de_nghi_cong_ty_idx ON public.de_nghi USING btree (cong_ty_id);


--
-- Name: de_nghi_created_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX de_nghi_created_idx ON public.de_nghi USING btree (created_at DESC);


--
-- Name: de_nghi_doi_tuong_vay_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX de_nghi_doi_tuong_vay_idx ON public.de_nghi USING btree (doi_tuong_vay_id) WHERE (doi_tuong_vay_id IS NOT NULL);


--
-- Name: de_nghi_han_hoan_ung_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX de_nghi_han_hoan_ung_idx ON public.de_nghi USING btree (han_hoan_ung) WHERE (han_hoan_ung IS NOT NULL);


--
-- Name: de_nghi_loai_trang_thai_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX de_nghi_loai_trang_thai_idx ON public.de_nghi USING btree (loai, trang_thai);


--
-- Name: de_nghi_nguoi_de_xuat_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX de_nghi_nguoi_de_xuat_idx ON public.de_nghi USING btree (nguoi_de_xuat_id);


--
-- Name: de_nghi_nhan_ung_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX de_nghi_nhan_ung_idx ON public.de_nghi USING btree (nhan_vien_nhan_ung_id) WHERE (nhan_vien_nhan_ung_id IS NOT NULL);


--
-- Name: de_nghi_tam_ung_goc_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX de_nghi_tam_ung_goc_idx ON public.de_nghi USING btree (de_nghi_tam_ung_goc_id) WHERE (de_nghi_tam_ung_goc_id IS NOT NULL);


--
-- Name: doi_tuong_vay_moi_nhan_vien_mot_dong; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX doi_tuong_vay_moi_nhan_vien_mot_dong ON public.doi_tuong_vay USING btree (nhan_vien_id) WHERE (nhan_vien_id IS NOT NULL);


--
-- Name: dot_duyet_de_nghi_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX dot_duyet_de_nghi_idx ON public.dot_duyet USING btree (de_nghi_id);


--
-- Name: dot_duyet_trang_thai_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX dot_duyet_trang_thai_idx ON public.dot_duyet USING btree (trang_thai);


--
-- Name: du_an_cong_ty_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX du_an_cong_ty_idx ON public.du_an USING btree (cong_ty_id);


--
-- Name: giao_dich_lich_su_doi_tuong_vay_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX giao_dich_lich_su_doi_tuong_vay_idx ON public.giao_dich_lich_su USING btree (doi_tuong_vay_id) WHERE (doi_tuong_vay_id IS NOT NULL);


--
-- Name: giao_dich_lich_su_ngay_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX giao_dich_lich_su_ngay_idx ON public.giao_dich_lich_su USING btree (ngay);


--
-- Name: giao_dich_lich_su_quy_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX giao_dich_lich_su_quy_idx ON public.giao_dich_lich_su USING btree (quy_tien_mat_id) WHERE (quy_tien_mat_id IS NOT NULL);


--
-- Name: khoan_muc_thu_mot_dong_he_thong; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX khoan_muc_thu_mot_dong_he_thong ON public.khoan_muc_thu USING btree (la_he_thong) WHERE la_he_thong;


--
-- Name: lan_tra_tien_dot_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX lan_tra_tien_dot_idx ON public.lan_tra_tien USING btree (dot_duyet_id);


--
-- Name: lan_tra_tien_ngay_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX lan_tra_tien_ngay_idx ON public.lan_tra_tien USING btree (ngay_tra);


--
-- Name: lan_tra_tien_quy_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX lan_tra_tien_quy_idx ON public.lan_tra_tien USING btree (quy_tien_mat_id) WHERE (quy_tien_mat_id IS NOT NULL);


--
-- Name: lan_tra_tien_tk_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX lan_tra_tien_tk_idx ON public.lan_tra_tien USING btree (tai_khoan_ngan_hang_id) WHERE (tai_khoan_ngan_hang_id IS NOT NULL);


--
-- Name: menu_nhan_vien_nv_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX menu_nhan_vien_nv_idx ON public.menu_nhan_vien USING btree (nhan_vien_id);


--
-- Name: muc_de_nghi_cho_duyet_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX muc_de_nghi_cho_duyet_idx ON public.muc_de_nghi USING btree (de_nghi_id) WHERE ((dot_duyet_id IS NULL) AND (tu_choi_luc IS NULL));


--
-- Name: muc_de_nghi_de_nghi_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX muc_de_nghi_de_nghi_idx ON public.muc_de_nghi USING btree (de_nghi_id);


--
-- Name: muc_de_nghi_dot_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX muc_de_nghi_dot_idx ON public.muc_de_nghi USING btree (dot_duyet_id);


--
-- Name: muc_de_nghi_du_an_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX muc_de_nghi_du_an_idx ON public.muc_de_nghi USING btree (du_an_id) WHERE (du_an_id IS NOT NULL);


--
-- Name: muc_de_nghi_khoan_muc_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX muc_de_nghi_khoan_muc_idx ON public.muc_de_nghi USING btree (khoan_muc_chi_id);


--
-- Name: ngan_sach_khong_trung_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ngan_sach_khong_trung_idx ON public.ngan_sach USING btree (nam, COALESCE(thang, 0), COALESCE(cong_ty_id, '00000000-0000-0000-0000-000000000000'::uuid), COALESCE(du_an_id, '00000000-0000-0000-0000-000000000000'::uuid), khoan_muc_chi_id);


--
-- Name: ngan_sach_ky_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ngan_sach_ky_idx ON public.ngan_sach USING btree (nam, thang);


--
-- Name: nguon_tien_nhan_vien_nv_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX nguon_tien_nhan_vien_nv_idx ON public.nguon_tien_nhan_vien USING btree (nhan_vien_id);


--
-- Name: nguon_tien_nv_quy_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX nguon_tien_nv_quy_idx ON public.nguon_tien_nhan_vien USING btree (nhan_vien_id, quy_tien_mat_id) WHERE (quy_tien_mat_id IS NOT NULL);


--
-- Name: nguon_tien_nv_tk_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX nguon_tien_nv_tk_idx ON public.nguon_tien_nhan_vien USING btree (nhan_vien_id, tai_khoan_ngan_hang_id) WHERE (tai_khoan_ngan_hang_id IS NOT NULL);


--
-- Name: nhan_vien_cong_ty_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX nhan_vien_cong_ty_idx ON public.nhan_vien USING btree (cong_ty_id);


--
-- Name: nhan_vien_dang_dung_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX nhan_vien_dang_dung_idx ON public.nhan_vien USING btree (dang_dung) WHERE dang_dung;


--
-- Name: nhat_ky_ban_ghi_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX nhat_ky_ban_ghi_idx ON public.nhat_ky USING btree (bang, ban_ghi_id);


--
-- Name: nhat_ky_nguoi_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX nhat_ky_nguoi_idx ON public.nhat_ky USING btree (nguoi_thuc_hien_id);


--
-- Name: nhat_ky_thoi_gian_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX nhat_ky_thoi_gian_idx ON public.nhat_ky USING btree (created_at DESC);


--
-- Name: phieu_thu_cap_tru_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phieu_thu_cap_tru_idx ON public.phieu_thu USING btree (cap_tru_lan_tra_id) WHERE (cap_tru_lan_tra_id IS NOT NULL);


--
-- Name: phieu_thu_doi_tuong_vay_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phieu_thu_doi_tuong_vay_idx ON public.phieu_thu USING btree (doi_tuong_vay_id) WHERE (doi_tuong_vay_id IS NOT NULL);


--
-- Name: phieu_thu_du_an_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phieu_thu_du_an_idx ON public.phieu_thu USING btree (du_an_id) WHERE (du_an_id IS NOT NULL);


--
-- Name: phieu_thu_ngay_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phieu_thu_ngay_idx ON public.phieu_thu USING btree (ngay_thu);


--
-- Name: phieu_thu_quy_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phieu_thu_quy_idx ON public.phieu_thu USING btree (quy_tien_mat_id) WHERE (quy_tien_mat_id IS NOT NULL);


--
-- Name: phieu_thu_tam_ung_goc_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phieu_thu_tam_ung_goc_idx ON public.phieu_thu USING btree (de_nghi_tam_ung_goc_id) WHERE (de_nghi_tam_ung_goc_id IS NOT NULL);


--
-- Name: phieu_thu_tk_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phieu_thu_tk_idx ON public.phieu_thu USING btree (tai_khoan_ngan_hang_id) WHERE (tai_khoan_ngan_hang_id IS NOT NULL);


--
-- Name: phieu_thu_trang_thai_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX phieu_thu_trang_thai_idx ON public.phieu_thu USING btree (trang_thai);


--
-- Name: tai_khoan_ngan_hang_cong_ty_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tai_khoan_ngan_hang_cong_ty_idx ON public.tai_khoan_ngan_hang USING btree (cong_ty_id);


--
-- Name: ton_dau_ky_moi_quy_mot_dong; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ton_dau_ky_moi_quy_mot_dong ON public.ton_dau_ky USING btree (quy_tien_mat_id) WHERE (quy_tien_mat_id IS NOT NULL);


--
-- Name: ton_dau_ky_moi_tk_mot_dong; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ton_dau_ky_moi_tk_mot_dong ON public.ton_dau_ky USING btree (tai_khoan_ngan_hang_id) WHERE (tai_khoan_ngan_hang_id IS NOT NULL);


--
-- Name: vai_tro_nhan_vien_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX vai_tro_nhan_vien_idx ON public.vai_tro_nhan_vien USING btree (nhan_vien_id);


--
-- Name: v_cho_toi_xu_ly _RETURN; Type: RULE; Schema: public; Owner: -
--

CREATE OR REPLACE VIEW public.v_cho_toi_xu_ly WITH (security_invoker='on') AS
 SELECT 'ktt_duyet_muc'::text AS viec,
    dn.id AS de_nghi_id,
    NULL::uuid AS dot_duyet_id,
    dn.so_de_nghi,
    dn.loai,
    dn.cong_ty_id,
    dn.noi_dung,
    sum((mdn.so_tien)::numeric) AS so_tien,
    dn.created_at
   FROM (public.de_nghi dn
     JOIN public.muc_de_nghi mdn ON ((mdn.de_nghi_id = dn.id)))
  WHERE ((dn.trang_thai = 'dang_duyet'::text) AND (mdn.dot_duyet_id IS NULL) AND (mdn.tu_choi_luc IS NULL) AND private.co_vai_tro('ke_toan_truong'::text))
  GROUP BY dn.id
UNION ALL
 SELECT 'chu_tich_duyet_dot'::text AS viec,
    dn.id AS de_nghi_id,
    v.dot_duyet_id,
    dn.so_de_nghi,
    dn.loai,
    dn.cong_ty_id,
    dn.noi_dung,
    v.so_tien_duyet AS so_tien,
    dn.created_at
   FROM (public.v_dot_duyet_tong_hop v
     JOIN public.de_nghi dn ON ((dn.id = v.de_nghi_id)))
  WHERE ((v.trang_thai_duyet = 'cho_chu_tich'::text) AND private.co_vai_tro('chu_tich'::text))
UNION ALL
 SELECT 'ktt_thanh_toan_tra_tien'::text AS viec,
    dn.id AS de_nghi_id,
    v.dot_duyet_id,
    dn.so_de_nghi,
    dn.loai,
    dn.cong_ty_id,
    dn.noi_dung,
    private.con_phai_chi_that(v.dot_duyet_id) AS so_tien,
    dn.created_at
   FROM (public.v_dot_duyet_tong_hop v
     JOIN public.de_nghi dn ON ((dn.id = v.de_nghi_id)))
  WHERE ((v.trang_thai_duyet = 'da_duyet'::text) AND (private.con_phai_chi_that(v.dot_duyet_id) > (0)::numeric) AND private.co_vai_tro('ke_toan_thanh_toan'::text))
UNION ALL
 SELECT 'giai_trinh_gui_lai'::text AS viec,
    dn.id AS de_nghi_id,
    NULL::uuid AS dot_duyet_id,
    dn.so_de_nghi,
    dn.loai,
    dn.cong_ty_id,
    dn.noi_dung,
    (NULL::numeric)::public.tien_te AS so_tien,
    dn.created_at
   FROM public.de_nghi dn
  WHERE ((dn.trang_thai = 'bi_tu_choi'::text) AND (dn.nguoi_de_xuat_id = private.nhan_vien_hien_tai()));


--
-- Name: bu_cong_no_am bu_cong_no_am_chi_ghi_them; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER bu_cong_no_am_chi_ghi_them BEFORE DELETE OR UPDATE ON public.bu_cong_no_am FOR EACH ROW EXECUTE FUNCTION private.chan_sua_so_quy();


--
-- Name: but_toan_quy_cong_truong but_toan_qct_chi_ghi_them; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER but_toan_qct_chi_ghi_them BEFORE DELETE OR UPDATE ON public.but_toan_quy_cong_truong FOR EACH ROW EXECUTE FUNCTION private.chan_sua_so_quy();


--
-- Name: cau_hinh_he_thong cau_hinh_he_thong_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER cau_hinh_he_thong_updated_at BEFORE UPDATE ON public.cau_hinh_he_thong FOR EACH ROW EXECUTE FUNCTION private.tu_dong_cap_nhat_updated_at();


--
-- Name: chi_tiet_lan_tra chi_tiet_lan_tra_chi_ghi_them; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER chi_tiet_lan_tra_chi_ghi_them BEFORE DELETE OR UPDATE ON public.chi_tiet_lan_tra FOR EACH ROW EXECUTE FUNCTION private.chan_sua_so_quy();


--
-- Name: chuyen_quy chuyen_quy_chi_ghi_them; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER chuyen_quy_chi_ghi_them BEFORE DELETE OR UPDATE ON public.chuyen_quy FOR EACH ROW EXECUTE FUNCTION private.chan_sua_so_quy();


--
-- Name: cong_ty cong_ty_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER cong_ty_updated_at BEFORE UPDATE ON public.cong_ty FOR EACH ROW EXECUTE FUNCTION private.tu_dong_cap_nhat_updated_at();


--
-- Name: de_nghi de_nghi_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER de_nghi_updated_at BEFORE UPDATE ON public.de_nghi FOR EACH ROW EXECUTE FUNCTION private.tu_dong_cap_nhat_updated_at();


--
-- Name: doi_tuong_vay doi_tuong_vay_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER doi_tuong_vay_updated_at BEFORE UPDATE ON public.doi_tuong_vay FOR EACH ROW EXECUTE FUNCTION private.tu_dong_cap_nhat_updated_at();


--
-- Name: dot_duyet dot_duyet_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER dot_duyet_updated_at BEFORE UPDATE ON public.dot_duyet FOR EACH ROW EXECUTE FUNCTION private.tu_dong_cap_nhat_updated_at();


--
-- Name: du_an du_an_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER du_an_updated_at BEFORE UPDATE ON public.du_an FOR EACH ROW EXECUTE FUNCTION private.tu_dong_cap_nhat_updated_at();


--
-- Name: khach_hang khach_hang_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER khach_hang_updated_at BEFORE UPDATE ON public.khach_hang FOR EACH ROW EXECUTE FUNCTION private.tu_dong_cap_nhat_updated_at();


--
-- Name: khoan_muc_chi khoan_muc_chi_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER khoan_muc_chi_updated_at BEFORE UPDATE ON public.khoan_muc_chi FOR EACH ROW EXECUTE FUNCTION private.tu_dong_cap_nhat_updated_at();


--
-- Name: khoan_muc_thu khoan_muc_thu_bao_ve_he_thong; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER khoan_muc_thu_bao_ve_he_thong BEFORE DELETE OR UPDATE ON public.khoan_muc_thu FOR EACH ROW EXECUTE FUNCTION private.chan_sua_khoan_muc_he_thong();


--
-- Name: khoan_muc_thu khoan_muc_thu_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER khoan_muc_thu_updated_at BEFORE UPDATE ON public.khoan_muc_thu FOR EACH ROW EXECUTE FUNCTION private.tu_dong_cap_nhat_updated_at();


--
-- Name: lan_tra_tien lan_tra_tien_chi_ghi_them; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER lan_tra_tien_chi_ghi_them BEFORE DELETE OR UPDATE ON public.lan_tra_tien FOR EACH ROW EXECUTE FUNCTION private.chan_sua_so_quy();


--
-- Name: lan_tra_tien lan_tra_tien_dung_nguon_duoc_gan; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER lan_tra_tien_dung_nguon_duoc_gan BEFORE INSERT ON public.lan_tra_tien FOR EACH ROW EXECUTE FUNCTION private.chan_nguon_khong_duoc_phan_quyen();


--
-- Name: muc_de_nghi muc_de_nghi_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER muc_de_nghi_updated_at BEFORE UPDATE ON public.muc_de_nghi FOR EACH ROW EXECUTE FUNCTION private.tu_dong_cap_nhat_updated_at();


--
-- Name: ngan_sach ngan_sach_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER ngan_sach_updated_at BEFORE UPDATE ON public.ngan_sach FOR EACH ROW EXECUTE FUNCTION private.tu_dong_cap_nhat_updated_at();


--
-- Name: nha_cung_cap nha_cung_cap_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER nha_cung_cap_updated_at BEFORE UPDATE ON public.nha_cung_cap FOR EACH ROW EXECUTE FUNCTION private.tu_dong_cap_nhat_updated_at();


--
-- Name: nhan_vien_nhay_cam nhan_vien_nhay_cam_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER nhan_vien_nhay_cam_updated_at BEFORE UPDATE ON public.nhan_vien_nhay_cam FOR EACH ROW EXECUTE FUNCTION private.tu_dong_cap_nhat_updated_at();


--
-- Name: nhan_vien nhan_vien_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER nhan_vien_updated_at BEFORE UPDATE ON public.nhan_vien FOR EACH ROW EXECUTE FUNCTION private.tu_dong_cap_nhat_updated_at();


--
-- Name: nhat_ky nhat_ky_chi_ghi_them; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER nhat_ky_chi_ghi_them BEFORE DELETE OR UPDATE ON public.nhat_ky FOR EACH ROW EXECUTE FUNCTION private.chan_sua_nhat_ky();


--
-- Name: phieu_thu phieu_thu_dung_nguon_duoc_gan; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER phieu_thu_dung_nguon_duoc_gan BEFORE INSERT OR UPDATE OF trang_thai, quy_tien_mat_id, tai_khoan_ngan_hang_id ON public.phieu_thu FOR EACH ROW EXECUTE FUNCTION private.chan_nguon_khong_duoc_phan_quyen();


--
-- Name: phieu_thu phieu_thu_khong_trung_nhap_quy; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER phieu_thu_khong_trung_nhap_quy BEFORE INSERT OR UPDATE OF trang_thai, quy_tien_mat_id, so_tien, ngay_thu, xac_nhan_khong_trung_nhap_quy ON public.phieu_thu FOR EACH ROW EXECUTE FUNCTION private.chan_phieu_thu_trung_nhap_quy();


--
-- Name: phieu_thu phieu_thu_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER phieu_thu_updated_at BEFORE UPDATE ON public.phieu_thu FOR EACH ROW EXECUTE FUNCTION private.tu_dong_cap_nhat_updated_at();


--
-- Name: quy_tien_mat quy_tien_mat_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER quy_tien_mat_updated_at BEFORE UPDATE ON public.quy_tien_mat FOR EACH ROW EXECUTE FUNCTION private.tu_dong_cap_nhat_updated_at();


--
-- Name: tai_khoan_ngan_hang tai_khoan_ngan_hang_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tai_khoan_ngan_hang_updated_at BEFORE UPDATE ON public.tai_khoan_ngan_hang FOR EACH ROW EXECUTE FUNCTION private.tu_dong_cap_nhat_updated_at();


--
-- Name: doi_tuong_vay tg_ma_danh_muc; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tg_ma_danh_muc BEFORE INSERT OR UPDATE OF ma ON public.doi_tuong_vay FOR EACH ROW EXECUTE FUNCTION private.tg_ma_danh_muc('DTV');


--
-- Name: du_an tg_ma_danh_muc; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tg_ma_danh_muc BEFORE INSERT OR UPDATE OF ma ON public.du_an FOR EACH ROW EXECUTE FUNCTION private.tg_ma_danh_muc('DA');


--
-- Name: khach_hang tg_ma_danh_muc; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tg_ma_danh_muc BEFORE INSERT OR UPDATE OF ma ON public.khach_hang FOR EACH ROW EXECUTE FUNCTION private.tg_ma_danh_muc('KH');


--
-- Name: khoan_muc_chi tg_ma_danh_muc; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tg_ma_danh_muc BEFORE INSERT OR UPDATE OF ma ON public.khoan_muc_chi FOR EACH ROW EXECUTE FUNCTION private.tg_ma_danh_muc('KMC');


--
-- Name: khoan_muc_thu tg_ma_danh_muc; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tg_ma_danh_muc BEFORE INSERT OR UPDATE OF ma ON public.khoan_muc_thu FOR EACH ROW EXECUTE FUNCTION private.tg_ma_danh_muc('KMT');


--
-- Name: nha_cung_cap tg_ma_danh_muc; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tg_ma_danh_muc BEFORE INSERT OR UPDATE OF ma ON public.nha_cung_cap FOR EACH ROW EXECUTE FUNCTION private.tg_ma_danh_muc('NCC');


--
-- Name: nhan_vien tg_ma_danh_muc; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tg_ma_danh_muc BEFORE INSERT OR UPDATE OF ma ON public.nhan_vien FOR EACH ROW EXECUTE FUNCTION private.tg_ma_danh_muc('NV');


--
-- Name: quy_tien_mat tg_ma_danh_muc; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tg_ma_danh_muc BEFORE INSERT OR UPDATE OF ma ON public.quy_tien_mat FOR EACH ROW EXECUTE FUNCTION private.tg_ma_danh_muc('QTM');


--
-- Name: lan_tra_tien tg_xet_lai_quyet_toan_sau_tra_tien; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER tg_xet_lai_quyet_toan_sau_tra_tien AFTER INSERT ON public.lan_tra_tien DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION private.tg_xet_lai_quyet_toan_sau_tra_tien();


--
-- Name: ton_dau_ky ton_dau_ky_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER ton_dau_ky_updated_at BEFORE UPDATE ON public.ton_dau_ky FOR EACH ROW EXECUTE FUNCTION private.tu_dong_cap_nhat_updated_at();


--
-- Name: vai_tro_nhan_vien vai_tro_nhan_vien_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER vai_tro_nhan_vien_updated_at BEFORE UPDATE ON public.vai_tro_nhan_vien FOR EACH ROW EXECUTE FUNCTION private.tu_dong_cap_nhat_updated_at();


--
-- Name: bu_cong_no_am bu_cong_no_am_de_nghi_am_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bu_cong_no_am
    ADD CONSTRAINT bu_cong_no_am_de_nghi_am_id_fkey FOREIGN KEY (de_nghi_am_id) REFERENCES public.de_nghi(id);


--
-- Name: bu_cong_no_am bu_cong_no_am_de_nghi_moi_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bu_cong_no_am
    ADD CONSTRAINT bu_cong_no_am_de_nghi_moi_id_fkey FOREIGN KEY (de_nghi_moi_id) REFERENCES public.de_nghi(id);


--
-- Name: bu_cong_no_am bu_cong_no_am_lan_tra_tien_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bu_cong_no_am
    ADD CONSTRAINT bu_cong_no_am_lan_tra_tien_id_fkey FOREIGN KEY (lan_tra_tien_id) REFERENCES public.lan_tra_tien(id);


--
-- Name: bu_cong_no_am bu_cong_no_am_nguoi_tao_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bu_cong_no_am
    ADD CONSTRAINT bu_cong_no_am_nguoi_tao_id_fkey FOREIGN KEY (nguoi_tao_id) REFERENCES public.nhan_vien(id);


--
-- Name: but_toan_quy_cong_truong but_toan_quy_cong_truong_de_nghi_tam_ung_goc_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.but_toan_quy_cong_truong
    ADD CONSTRAINT but_toan_quy_cong_truong_de_nghi_tam_ung_goc_id_fkey FOREIGN KEY (de_nghi_tam_ung_goc_id) REFERENCES public.de_nghi(id);


--
-- Name: but_toan_quy_cong_truong but_toan_quy_cong_truong_dot_duyet_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.but_toan_quy_cong_truong
    ADD CONSTRAINT but_toan_quy_cong_truong_dot_duyet_id_fkey FOREIGN KEY (dot_duyet_id) REFERENCES public.dot_duyet(id);


--
-- Name: but_toan_quy_cong_truong but_toan_quy_cong_truong_lan_tra_tien_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.but_toan_quy_cong_truong
    ADD CONSTRAINT but_toan_quy_cong_truong_lan_tra_tien_id_fkey FOREIGN KEY (lan_tra_tien_id) REFERENCES public.lan_tra_tien(id);


--
-- Name: but_toan_quy_cong_truong but_toan_quy_cong_truong_nguoi_tao_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.but_toan_quy_cong_truong
    ADD CONSTRAINT but_toan_quy_cong_truong_nguoi_tao_id_fkey FOREIGN KEY (nguoi_tao_id) REFERENCES public.nhan_vien(id);


--
-- Name: but_toan_quy_cong_truong but_toan_quy_cong_truong_nhan_vien_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.but_toan_quy_cong_truong
    ADD CONSTRAINT but_toan_quy_cong_truong_nhan_vien_id_fkey FOREIGN KEY (nhan_vien_id) REFERENCES public.nhan_vien(id);


--
-- Name: but_toan_quy_cong_truong but_toan_quy_cong_truong_quy_tien_mat_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.but_toan_quy_cong_truong
    ADD CONSTRAINT but_toan_quy_cong_truong_quy_tien_mat_id_fkey FOREIGN KEY (quy_tien_mat_id) REFERENCES public.quy_tien_mat(id);


--
-- Name: chi_tiet_lan_tra chi_tiet_dung_lan_tra; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chi_tiet_lan_tra
    ADD CONSTRAINT chi_tiet_dung_lan_tra FOREIGN KEY (lan_tra_tien_id, dot_duyet_id) REFERENCES public.lan_tra_tien(id, dot_duyet_id) ON DELETE CASCADE;


--
-- Name: chi_tiet_lan_tra chi_tiet_dung_muc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chi_tiet_lan_tra
    ADD CONSTRAINT chi_tiet_dung_muc FOREIGN KEY (muc_de_nghi_id, dot_duyet_id) REFERENCES public.muc_de_nghi(id, dot_duyet_id);


--
-- Name: chung_tu_fmb chung_tu_fmb_chuyen_quy_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chung_tu_fmb
    ADD CONSTRAINT chung_tu_fmb_chuyen_quy_id_fkey FOREIGN KEY (chuyen_quy_id) REFERENCES public.chuyen_quy(id) ON DELETE CASCADE;


--
-- Name: chung_tu_fmb chung_tu_fmb_de_nghi_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chung_tu_fmb
    ADD CONSTRAINT chung_tu_fmb_de_nghi_id_fkey FOREIGN KEY (de_nghi_id) REFERENCES public.de_nghi(id) ON DELETE CASCADE;


--
-- Name: chung_tu_fmb chung_tu_fmb_lan_tra_tien_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chung_tu_fmb
    ADD CONSTRAINT chung_tu_fmb_lan_tra_tien_id_fkey FOREIGN KEY (lan_tra_tien_id) REFERENCES public.lan_tra_tien(id) ON DELETE CASCADE;


--
-- Name: chung_tu_fmb chung_tu_fmb_nguoi_tai_len_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chung_tu_fmb
    ADD CONSTRAINT chung_tu_fmb_nguoi_tai_len_id_fkey FOREIGN KEY (nguoi_tai_len_id) REFERENCES public.nhan_vien(id);


--
-- Name: chung_tu_fmb chung_tu_fmb_phieu_thu_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chung_tu_fmb
    ADD CONSTRAINT chung_tu_fmb_phieu_thu_id_fkey FOREIGN KEY (phieu_thu_id) REFERENCES public.phieu_thu(id) ON DELETE CASCADE;


--
-- Name: chuyen_quy chuyen_quy_den_quy_tien_mat_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chuyen_quy
    ADD CONSTRAINT chuyen_quy_den_quy_tien_mat_id_fkey FOREIGN KEY (den_quy_tien_mat_id) REFERENCES public.quy_tien_mat(id);


--
-- Name: chuyen_quy chuyen_quy_den_tai_khoan_ngan_hang_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chuyen_quy
    ADD CONSTRAINT chuyen_quy_den_tai_khoan_ngan_hang_id_fkey FOREIGN KEY (den_tai_khoan_ngan_hang_id) REFERENCES public.tai_khoan_ngan_hang(id);


--
-- Name: chuyen_quy chuyen_quy_nguoi_lap_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chuyen_quy
    ADD CONSTRAINT chuyen_quy_nguoi_lap_id_fkey FOREIGN KEY (nguoi_lap_id) REFERENCES public.nhan_vien(id);


--
-- Name: chuyen_quy chuyen_quy_tu_quy_tien_mat_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chuyen_quy
    ADD CONSTRAINT chuyen_quy_tu_quy_tien_mat_id_fkey FOREIGN KEY (tu_quy_tien_mat_id) REFERENCES public.quy_tien_mat(id);


--
-- Name: chuyen_quy chuyen_quy_tu_tai_khoan_ngan_hang_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chuyen_quy
    ADD CONSTRAINT chuyen_quy_tu_tai_khoan_ngan_hang_id_fkey FOREIGN KEY (tu_tai_khoan_ngan_hang_id) REFERENCES public.tai_khoan_ngan_hang(id);


--
-- Name: de_nghi de_nghi_cong_ty_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.de_nghi
    ADD CONSTRAINT de_nghi_cong_ty_id_fkey FOREIGN KEY (cong_ty_id) REFERENCES public.cong_ty(id);


--
-- Name: de_nghi de_nghi_de_nghi_tam_ung_goc_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.de_nghi
    ADD CONSTRAINT de_nghi_de_nghi_tam_ung_goc_id_fkey FOREIGN KEY (de_nghi_tam_ung_goc_id) REFERENCES public.de_nghi(id);


--
-- Name: de_nghi de_nghi_doi_tuong_vay_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.de_nghi
    ADD CONSTRAINT de_nghi_doi_tuong_vay_id_fkey FOREIGN KEY (doi_tuong_vay_id) REFERENCES public.doi_tuong_vay(id);


--
-- Name: de_nghi de_nghi_nguoi_de_xuat_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.de_nghi
    ADD CONSTRAINT de_nghi_nguoi_de_xuat_id_fkey FOREIGN KEY (nguoi_de_xuat_id) REFERENCES public.nhan_vien(id);


--
-- Name: de_nghi de_nghi_nguoi_tao_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.de_nghi
    ADD CONSTRAINT de_nghi_nguoi_tao_id_fkey FOREIGN KEY (nguoi_tao_id) REFERENCES public.nhan_vien(id);


--
-- Name: de_nghi de_nghi_nhan_vien_nhan_ung_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.de_nghi
    ADD CONSTRAINT de_nghi_nhan_vien_nhan_ung_id_fkey FOREIGN KEY (nhan_vien_nhan_ung_id) REFERENCES public.nhan_vien(id);


--
-- Name: doi_tuong_vay doi_tuong_vay_nhan_vien_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.doi_tuong_vay
    ADD CONSTRAINT doi_tuong_vay_nhan_vien_id_fkey FOREIGN KEY (nhan_vien_id) REFERENCES public.nhan_vien(id);


--
-- Name: dot_duyet dot_duyet_chu_tich_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dot_duyet
    ADD CONSTRAINT dot_duyet_chu_tich_id_fkey FOREIGN KEY (chu_tich_id) REFERENCES public.nhan_vien(id);


--
-- Name: dot_duyet dot_duyet_de_nghi_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dot_duyet
    ADD CONSTRAINT dot_duyet_de_nghi_id_fkey FOREIGN KEY (de_nghi_id) REFERENCES public.de_nghi(id) ON DELETE CASCADE;


--
-- Name: dot_duyet dot_duyet_ktt_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dot_duyet
    ADD CONSTRAINT dot_duyet_ktt_id_fkey FOREIGN KEY (ktt_id) REFERENCES public.nhan_vien(id);


--
-- Name: dot_duyet dot_duyet_nguoi_dong_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dot_duyet
    ADD CONSTRAINT dot_duyet_nguoi_dong_id_fkey FOREIGN KEY (nguoi_dong_id) REFERENCES public.nhan_vien(id);


--
-- Name: du_an du_an_chu_nhiem_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.du_an
    ADD CONSTRAINT du_an_chu_nhiem_id_fkey FOREIGN KEY (chu_nhiem_id) REFERENCES public.nhan_vien(id);


--
-- Name: du_an du_an_cong_ty_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.du_an
    ADD CONSTRAINT du_an_cong_ty_id_fkey FOREIGN KEY (cong_ty_id) REFERENCES public.cong_ty(id);


--
-- Name: du_an du_an_khach_hang_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.du_an
    ADD CONSTRAINT du_an_khach_hang_id_fkey FOREIGN KEY (khach_hang_id) REFERENCES public.khach_hang(id);


--
-- Name: giao_dich_da_huy giao_dich_da_huy_nguoi_huy_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.giao_dich_da_huy
    ADD CONSTRAINT giao_dich_da_huy_nguoi_huy_id_fkey FOREIGN KEY (nguoi_huy_id) REFERENCES public.nhan_vien(id);


--
-- Name: giao_dich_lich_su giao_dich_lich_su_cong_ty_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.giao_dich_lich_su
    ADD CONSTRAINT giao_dich_lich_su_cong_ty_id_fkey FOREIGN KEY (cong_ty_id) REFERENCES public.cong_ty(id);


--
-- Name: giao_dich_lich_su giao_dich_lich_su_doi_tuong_vay_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.giao_dich_lich_su
    ADD CONSTRAINT giao_dich_lich_su_doi_tuong_vay_id_fkey FOREIGN KEY (doi_tuong_vay_id) REFERENCES public.doi_tuong_vay(id);


--
-- Name: giao_dich_lich_su giao_dich_lich_su_du_an_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.giao_dich_lich_su
    ADD CONSTRAINT giao_dich_lich_su_du_an_id_fkey FOREIGN KEY (du_an_id) REFERENCES public.du_an(id);


--
-- Name: giao_dich_lich_su giao_dich_lich_su_khoan_muc_chi_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.giao_dich_lich_su
    ADD CONSTRAINT giao_dich_lich_su_khoan_muc_chi_id_fkey FOREIGN KEY (khoan_muc_chi_id) REFERENCES public.khoan_muc_chi(id);


--
-- Name: giao_dich_lich_su giao_dich_lich_su_khoan_muc_thu_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.giao_dich_lich_su
    ADD CONSTRAINT giao_dich_lich_su_khoan_muc_thu_id_fkey FOREIGN KEY (khoan_muc_thu_id) REFERENCES public.khoan_muc_thu(id);


--
-- Name: giao_dich_lich_su giao_dich_lich_su_quy_tien_mat_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.giao_dich_lich_su
    ADD CONSTRAINT giao_dich_lich_su_quy_tien_mat_id_fkey FOREIGN KEY (quy_tien_mat_id) REFERENCES public.quy_tien_mat(id);


--
-- Name: giao_dich_lich_su giao_dich_lich_su_tai_khoan_ngan_hang_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.giao_dich_lich_su
    ADD CONSTRAINT giao_dich_lich_su_tai_khoan_ngan_hang_id_fkey FOREIGN KEY (tai_khoan_ngan_hang_id) REFERENCES public.tai_khoan_ngan_hang(id);


--
-- Name: lan_tra_tien lan_tra_tien_dot_duyet_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lan_tra_tien
    ADD CONSTRAINT lan_tra_tien_dot_duyet_id_fkey FOREIGN KEY (dot_duyet_id) REFERENCES public.dot_duyet(id);


--
-- Name: lan_tra_tien lan_tra_tien_nguoi_xac_nhan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lan_tra_tien
    ADD CONSTRAINT lan_tra_tien_nguoi_xac_nhan_id_fkey FOREIGN KEY (nguoi_xac_nhan_id) REFERENCES public.nhan_vien(id);


--
-- Name: lan_tra_tien lan_tra_tien_quy_tien_mat_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lan_tra_tien
    ADD CONSTRAINT lan_tra_tien_quy_tien_mat_id_fkey FOREIGN KEY (quy_tien_mat_id) REFERENCES public.quy_tien_mat(id);


--
-- Name: lan_tra_tien lan_tra_tien_tai_khoan_ngan_hang_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lan_tra_tien
    ADD CONSTRAINT lan_tra_tien_tai_khoan_ngan_hang_id_fkey FOREIGN KEY (tai_khoan_ngan_hang_id) REFERENCES public.tai_khoan_ngan_hang(id);


--
-- Name: menu_nhan_vien menu_nhan_vien_nhan_vien_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_nhan_vien
    ADD CONSTRAINT menu_nhan_vien_nhan_vien_id_fkey FOREIGN KEY (nhan_vien_id) REFERENCES public.nhan_vien(id) ON DELETE CASCADE;


--
-- Name: muc_de_nghi muc_de_nghi_de_nghi_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.muc_de_nghi
    ADD CONSTRAINT muc_de_nghi_de_nghi_id_fkey FOREIGN KEY (de_nghi_id) REFERENCES public.de_nghi(id) ON DELETE CASCADE;


--
-- Name: muc_de_nghi muc_de_nghi_dot_duyet_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.muc_de_nghi
    ADD CONSTRAINT muc_de_nghi_dot_duyet_id_fkey FOREIGN KEY (dot_duyet_id) REFERENCES public.dot_duyet(id) ON DELETE SET NULL;


--
-- Name: muc_de_nghi muc_de_nghi_du_an_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.muc_de_nghi
    ADD CONSTRAINT muc_de_nghi_du_an_id_fkey FOREIGN KEY (du_an_id) REFERENCES public.du_an(id);


--
-- Name: muc_de_nghi muc_de_nghi_khoan_muc_chi_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.muc_de_nghi
    ADD CONSTRAINT muc_de_nghi_khoan_muc_chi_id_fkey FOREIGN KEY (khoan_muc_chi_id) REFERENCES public.khoan_muc_chi(id);


--
-- Name: muc_de_nghi muc_de_nghi_nguoi_tu_choi_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.muc_de_nghi
    ADD CONSTRAINT muc_de_nghi_nguoi_tu_choi_id_fkey FOREIGN KEY (nguoi_tu_choi_id) REFERENCES public.nhan_vien(id);


--
-- Name: ngan_sach ngan_sach_cong_ty_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ngan_sach
    ADD CONSTRAINT ngan_sach_cong_ty_id_fkey FOREIGN KEY (cong_ty_id) REFERENCES public.cong_ty(id);


--
-- Name: ngan_sach ngan_sach_du_an_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ngan_sach
    ADD CONSTRAINT ngan_sach_du_an_id_fkey FOREIGN KEY (du_an_id) REFERENCES public.du_an(id);


--
-- Name: ngan_sach ngan_sach_khoan_muc_chi_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ngan_sach
    ADD CONSTRAINT ngan_sach_khoan_muc_chi_id_fkey FOREIGN KEY (khoan_muc_chi_id) REFERENCES public.khoan_muc_chi(id);


--
-- Name: nguon_tien_nhan_vien nguon_tien_nhan_vien_nhan_vien_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nguon_tien_nhan_vien
    ADD CONSTRAINT nguon_tien_nhan_vien_nhan_vien_id_fkey FOREIGN KEY (nhan_vien_id) REFERENCES public.nhan_vien(id) ON DELETE CASCADE;


--
-- Name: nguon_tien_nhan_vien nguon_tien_nhan_vien_quy_tien_mat_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nguon_tien_nhan_vien
    ADD CONSTRAINT nguon_tien_nhan_vien_quy_tien_mat_id_fkey FOREIGN KEY (quy_tien_mat_id) REFERENCES public.quy_tien_mat(id) ON DELETE CASCADE;


--
-- Name: nguon_tien_nhan_vien nguon_tien_nhan_vien_tai_khoan_ngan_hang_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nguon_tien_nhan_vien
    ADD CONSTRAINT nguon_tien_nhan_vien_tai_khoan_ngan_hang_id_fkey FOREIGN KEY (tai_khoan_ngan_hang_id) REFERENCES public.tai_khoan_ngan_hang(id) ON DELETE CASCADE;


--
-- Name: nhan_vien nhan_vien_cong_ty_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nhan_vien
    ADD CONSTRAINT nhan_vien_cong_ty_id_fkey FOREIGN KEY (cong_ty_id) REFERENCES public.cong_ty(id);


--
-- Name: nhan_vien_nhay_cam nhan_vien_nhay_cam_nhan_vien_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nhan_vien_nhay_cam
    ADD CONSTRAINT nhan_vien_nhay_cam_nhan_vien_id_fkey FOREIGN KEY (nhan_vien_id) REFERENCES public.nhan_vien(id) ON DELETE CASCADE;


--
-- Name: nhan_vien nhan_vien_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nhan_vien
    ADD CONSTRAINT nhan_vien_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: phieu_thu phieu_thu_cap_tru_lan_tra_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phieu_thu
    ADD CONSTRAINT phieu_thu_cap_tru_lan_tra_id_fkey FOREIGN KEY (cap_tru_lan_tra_id) REFERENCES public.lan_tra_tien(id);


--
-- Name: phieu_thu phieu_thu_cong_ty_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phieu_thu
    ADD CONSTRAINT phieu_thu_cong_ty_id_fkey FOREIGN KEY (cong_ty_id) REFERENCES public.cong_ty(id);


--
-- Name: phieu_thu phieu_thu_de_nghi_tam_ung_goc_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phieu_thu
    ADD CONSTRAINT phieu_thu_de_nghi_tam_ung_goc_id_fkey FOREIGN KEY (de_nghi_tam_ung_goc_id) REFERENCES public.de_nghi(id);


--
-- Name: phieu_thu phieu_thu_doi_tuong_vay_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phieu_thu
    ADD CONSTRAINT phieu_thu_doi_tuong_vay_id_fkey FOREIGN KEY (doi_tuong_vay_id) REFERENCES public.doi_tuong_vay(id);


--
-- Name: phieu_thu phieu_thu_du_an_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phieu_thu
    ADD CONSTRAINT phieu_thu_du_an_id_fkey FOREIGN KEY (du_an_id) REFERENCES public.du_an(id);


--
-- Name: phieu_thu phieu_thu_khoan_muc_thu_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phieu_thu
    ADD CONSTRAINT phieu_thu_khoan_muc_thu_id_fkey FOREIGN KEY (khoan_muc_thu_id) REFERENCES public.khoan_muc_thu(id);


--
-- Name: phieu_thu phieu_thu_nguoi_lap_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phieu_thu
    ADD CONSTRAINT phieu_thu_nguoi_lap_id_fkey FOREIGN KEY (nguoi_lap_id) REFERENCES public.nhan_vien(id);


--
-- Name: phieu_thu phieu_thu_nguoi_xac_nhan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phieu_thu
    ADD CONSTRAINT phieu_thu_nguoi_xac_nhan_id_fkey FOREIGN KEY (nguoi_xac_nhan_id) REFERENCES public.nhan_vien(id);


--
-- Name: phieu_thu phieu_thu_quy_tien_mat_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phieu_thu
    ADD CONSTRAINT phieu_thu_quy_tien_mat_id_fkey FOREIGN KEY (quy_tien_mat_id) REFERENCES public.quy_tien_mat(id);


--
-- Name: phieu_thu phieu_thu_tai_khoan_ngan_hang_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.phieu_thu
    ADD CONSTRAINT phieu_thu_tai_khoan_ngan_hang_id_fkey FOREIGN KEY (tai_khoan_ngan_hang_id) REFERENCES public.tai_khoan_ngan_hang(id);


--
-- Name: quy_tien_mat quy_tien_mat_thu_quy_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quy_tien_mat
    ADD CONSTRAINT quy_tien_mat_thu_quy_id_fkey FOREIGN KEY (thu_quy_id) REFERENCES public.nhan_vien(id);


--
-- Name: tai_khoan_ngan_hang tai_khoan_ngan_hang_cong_ty_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tai_khoan_ngan_hang
    ADD CONSTRAINT tai_khoan_ngan_hang_cong_ty_id_fkey FOREIGN KEY (cong_ty_id) REFERENCES public.cong_ty(id);


--
-- Name: ton_dau_ky ton_dau_ky_nguoi_tao_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ton_dau_ky
    ADD CONSTRAINT ton_dau_ky_nguoi_tao_id_fkey FOREIGN KEY (nguoi_tao_id) REFERENCES public.nhan_vien(id);


--
-- Name: ton_dau_ky ton_dau_ky_quy_tien_mat_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ton_dau_ky
    ADD CONSTRAINT ton_dau_ky_quy_tien_mat_id_fkey FOREIGN KEY (quy_tien_mat_id) REFERENCES public.quy_tien_mat(id);


--
-- Name: ton_dau_ky ton_dau_ky_tai_khoan_ngan_hang_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ton_dau_ky
    ADD CONSTRAINT ton_dau_ky_tai_khoan_ngan_hang_id_fkey FOREIGN KEY (tai_khoan_ngan_hang_id) REFERENCES public.tai_khoan_ngan_hang(id);


--
-- Name: vai_tro_nhan_vien vai_tro_nhan_vien_nhan_vien_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vai_tro_nhan_vien
    ADD CONSTRAINT vai_tro_nhan_vien_nhan_vien_id_fkey FOREIGN KEY (nhan_vien_id) REFERENCES public.nhan_vien(id) ON DELETE CASCADE;


--
-- Name: bu_cong_no_am; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.bu_cong_no_am ENABLE ROW LEVEL SECURITY;

--
-- Name: bu_cong_no_am bu_cong_no_am_doc; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY bu_cong_no_am_doc ON public.bu_cong_no_am FOR SELECT TO authenticated USING (true);


--
-- Name: but_toan_quy_cong_truong but_toan_qct_doc; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY but_toan_qct_doc ON public.but_toan_quy_cong_truong FOR SELECT TO authenticated USING ((private.la_nguoi_quan_ly_tai_chinh() AND private.duoc_xem_nguon_tien(quy_tien_mat_id, NULL::uuid)));


--
-- Name: but_toan_quy_cong_truong; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.but_toan_quy_cong_truong ENABLE ROW LEVEL SECURITY;

--
-- Name: cau_hinh_he_thong cau_hinh_doc; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cau_hinh_doc ON public.cau_hinh_he_thong FOR SELECT TO authenticated USING (private.co_vai_tro('quan_tri'::text));


--
-- Name: cau_hinh_he_thong; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cau_hinh_he_thong ENABLE ROW LEVEL SECURITY;

--
-- Name: cau_hinh_he_thong cau_hinh_sua; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cau_hinh_sua ON public.cau_hinh_he_thong FOR UPDATE TO authenticated USING (private.co_vai_tro('quan_tri'::text)) WITH CHECK (private.co_vai_tro('quan_tri'::text));


--
-- Name: chi_tiet_lan_tra; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.chi_tiet_lan_tra ENABLE ROW LEVEL SECURITY;

--
-- Name: chi_tiet_lan_tra chi_tiet_lan_tra_doc; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY chi_tiet_lan_tra_doc ON public.chi_tiet_lan_tra FOR SELECT TO authenticated USING ((private.la_nguoi_quan_ly_tai_chinh() OR (EXISTS ( SELECT 1
   FROM ((public.lan_tra_tien ltt
     JOIN public.dot_duyet dd ON ((dd.id = ltt.dot_duyet_id)))
     JOIN public.de_nghi dn ON ((dn.id = dd.de_nghi_id)))
  WHERE ((ltt.id = chi_tiet_lan_tra.lan_tra_tien_id) AND (dn.nguoi_de_xuat_id = private.nhan_vien_hien_tai()))))));


--
-- Name: chung_tu_fmb; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.chung_tu_fmb ENABLE ROW LEVEL SECURITY;

--
-- Name: chung_tu_fmb chung_tu_fmb_doc; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY chung_tu_fmb_doc ON public.chung_tu_fmb FOR SELECT TO authenticated USING ((((de_nghi_id IS NOT NULL) AND private.duoc_xem_de_nghi(de_nghi_id)) OR ((lan_tra_tien_id IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM (public.lan_tra_tien ltt
     JOIN public.dot_duyet dd ON ((dd.id = ltt.dot_duyet_id)))
  WHERE ((ltt.id = chung_tu_fmb.lan_tra_tien_id) AND private.duoc_xem_de_nghi(dd.de_nghi_id))))) OR ((phieu_thu_id IS NOT NULL) AND private.la_nguoi_quan_ly_tai_chinh()) OR ((chuyen_quy_id IS NOT NULL) AND private.la_nguoi_quan_ly_tai_chinh())));


--
-- Name: chuyen_quy; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.chuyen_quy ENABLE ROW LEVEL SECURITY;

--
-- Name: chuyen_quy chuyen_quy_doc; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY chuyen_quy_doc ON public.chuyen_quy FOR SELECT TO authenticated USING ((private.la_nguoi_quan_ly_tai_chinh() AND (private.duoc_xem_nguon_tien(tu_quy_tien_mat_id, tu_tai_khoan_ngan_hang_id) OR private.duoc_xem_nguon_tien(den_quy_tien_mat_id, den_tai_khoan_ngan_hang_id))));


--
-- Name: cong_ty; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cong_ty ENABLE ROW LEVEL SECURITY;

--
-- Name: cong_ty cong_ty_doc; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cong_ty_doc ON public.cong_ty FOR SELECT TO authenticated USING ((private.nhan_vien_hien_tai() IS NOT NULL));


--
-- Name: cong_ty cong_ty_sua; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cong_ty_sua ON public.cong_ty FOR UPDATE TO authenticated USING (private.duoc_sua_danh_muc()) WITH CHECK (private.duoc_sua_danh_muc());


--
-- Name: cong_ty cong_ty_them; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cong_ty_them ON public.cong_ty FOR INSERT TO authenticated WITH CHECK (private.duoc_sua_danh_muc());


--
-- Name: de_nghi; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.de_nghi ENABLE ROW LEVEL SECURITY;

--
-- Name: de_nghi de_nghi_doc; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY de_nghi_doc ON public.de_nghi FOR SELECT TO authenticated USING ((private.la_nguoi_quan_ly_tai_chinh() OR (nguoi_de_xuat_id = private.nhan_vien_hien_tai())));


--
-- Name: doi_tuong_vay; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.doi_tuong_vay ENABLE ROW LEVEL SECURITY;

--
-- Name: doi_tuong_vay doi_tuong_vay_doc; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY doi_tuong_vay_doc ON public.doi_tuong_vay FOR SELECT TO authenticated USING ((private.nhan_vien_hien_tai() IS NOT NULL));


--
-- Name: doi_tuong_vay doi_tuong_vay_sua; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY doi_tuong_vay_sua ON public.doi_tuong_vay FOR UPDATE TO authenticated USING (private.duoc_sua_danh_muc()) WITH CHECK (private.duoc_sua_danh_muc());


--
-- Name: doi_tuong_vay doi_tuong_vay_them; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY doi_tuong_vay_them ON public.doi_tuong_vay FOR INSERT TO authenticated WITH CHECK (private.duoc_sua_danh_muc());


--
-- Name: dot_duyet; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.dot_duyet ENABLE ROW LEVEL SECURITY;

--
-- Name: dot_duyet dot_duyet_doc; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY dot_duyet_doc ON public.dot_duyet FOR SELECT TO authenticated USING (private.duoc_xem_de_nghi(de_nghi_id));


--
-- Name: du_an; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.du_an ENABLE ROW LEVEL SECURITY;

--
-- Name: du_an du_an_doc; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY du_an_doc ON public.du_an FOR SELECT TO authenticated USING ((private.nhan_vien_hien_tai() IS NOT NULL));


--
-- Name: du_an du_an_sua; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY du_an_sua ON public.du_an FOR UPDATE TO authenticated USING (private.duoc_sua_danh_muc()) WITH CHECK (private.duoc_sua_danh_muc());


--
-- Name: du_an du_an_them; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY du_an_them ON public.du_an FOR INSERT TO authenticated WITH CHECK (private.duoc_sua_danh_muc());


--
-- Name: giao_dich_da_huy; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.giao_dich_da_huy ENABLE ROW LEVEL SECURITY;

--
-- Name: giao_dich_da_huy giao_dich_da_huy_doc; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY giao_dich_da_huy_doc ON public.giao_dich_da_huy FOR SELECT TO authenticated USING (private.co_vai_tro('quan_tri'::text));


--
-- Name: giao_dich_lich_su; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.giao_dich_lich_su ENABLE ROW LEVEL SECURITY;

--
-- Name: giao_dich_lich_su giao_dich_lich_su_doc; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY giao_dich_lich_su_doc ON public.giao_dich_lich_su FOR SELECT TO authenticated USING (private.la_nguoi_quan_ly_tai_chinh());


--
-- Name: giao_dich_lich_su giao_dich_lich_su_ghi; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY giao_dich_lich_su_ghi ON public.giao_dich_lich_su TO authenticated USING (private.co_vai_tro('quan_tri'::text)) WITH CHECK (private.co_vai_tro('quan_tri'::text));


--
-- Name: khach_hang; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.khach_hang ENABLE ROW LEVEL SECURITY;

--
-- Name: khach_hang khach_hang_doc; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY khach_hang_doc ON public.khach_hang FOR SELECT TO authenticated USING ((private.nhan_vien_hien_tai() IS NOT NULL));


--
-- Name: khach_hang khach_hang_sua; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY khach_hang_sua ON public.khach_hang FOR UPDATE TO authenticated USING (private.duoc_sua_danh_muc()) WITH CHECK (private.duoc_sua_danh_muc());


--
-- Name: khach_hang khach_hang_them; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY khach_hang_them ON public.khach_hang FOR INSERT TO authenticated WITH CHECK (private.duoc_sua_danh_muc());


--
-- Name: khoan_muc_chi; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.khoan_muc_chi ENABLE ROW LEVEL SECURITY;

--
-- Name: khoan_muc_chi khoan_muc_chi_doc; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY khoan_muc_chi_doc ON public.khoan_muc_chi FOR SELECT TO authenticated USING ((private.nhan_vien_hien_tai() IS NOT NULL));


--
-- Name: khoan_muc_chi khoan_muc_chi_sua; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY khoan_muc_chi_sua ON public.khoan_muc_chi FOR UPDATE TO authenticated USING (private.duoc_sua_danh_muc()) WITH CHECK (private.duoc_sua_danh_muc());


--
-- Name: khoan_muc_chi khoan_muc_chi_them; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY khoan_muc_chi_them ON public.khoan_muc_chi FOR INSERT TO authenticated WITH CHECK (private.duoc_sua_danh_muc());


--
-- Name: khoan_muc_thu; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.khoan_muc_thu ENABLE ROW LEVEL SECURITY;

--
-- Name: khoan_muc_thu khoan_muc_thu_doc; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY khoan_muc_thu_doc ON public.khoan_muc_thu FOR SELECT TO authenticated USING ((private.nhan_vien_hien_tai() IS NOT NULL));


--
-- Name: khoan_muc_thu khoan_muc_thu_sua; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY khoan_muc_thu_sua ON public.khoan_muc_thu FOR UPDATE TO authenticated USING (private.duoc_sua_danh_muc()) WITH CHECK (private.duoc_sua_danh_muc());


--
-- Name: khoan_muc_thu khoan_muc_thu_them; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY khoan_muc_thu_them ON public.khoan_muc_thu FOR INSERT TO authenticated WITH CHECK (private.duoc_sua_danh_muc());


--
-- Name: lan_tra_tien; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.lan_tra_tien ENABLE ROW LEVEL SECURITY;

--
-- Name: lan_tra_tien lan_tra_tien_doc; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY lan_tra_tien_doc ON public.lan_tra_tien FOR SELECT TO authenticated USING ((private.la_nguoi_quan_ly_tai_chinh() OR (EXISTS ( SELECT 1
   FROM (public.dot_duyet dd
     JOIN public.de_nghi dn ON ((dn.id = dd.de_nghi_id)))
  WHERE ((dd.id = lan_tra_tien.dot_duyet_id) AND (dn.nguoi_de_xuat_id = private.nhan_vien_hien_tai()))))));


--
-- Name: menu_nhan_vien; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.menu_nhan_vien ENABLE ROW LEVEL SECURITY;

--
-- Name: menu_nhan_vien menu_nhan_vien_doc; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY menu_nhan_vien_doc ON public.menu_nhan_vien FOR SELECT TO authenticated USING (true);


--
-- Name: menu_nhan_vien menu_nhan_vien_them; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY menu_nhan_vien_them ON public.menu_nhan_vien FOR INSERT TO authenticated WITH CHECK (private.co_vai_tro('quan_tri'::text));


--
-- Name: menu_nhan_vien menu_nhan_vien_xoa; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY menu_nhan_vien_xoa ON public.menu_nhan_vien FOR DELETE TO authenticated USING (private.co_vai_tro('quan_tri'::text));


--
-- Name: muc_de_nghi; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.muc_de_nghi ENABLE ROW LEVEL SECURITY;

--
-- Name: muc_de_nghi muc_de_nghi_doc; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY muc_de_nghi_doc ON public.muc_de_nghi FOR SELECT TO authenticated USING (private.duoc_xem_de_nghi(de_nghi_id));


--
-- Name: ngan_sach; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ngan_sach ENABLE ROW LEVEL SECURITY;

--
-- Name: ngan_sach ngan_sach_doc; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ngan_sach_doc ON public.ngan_sach FOR SELECT TO authenticated USING ((private.nhan_vien_hien_tai() IS NOT NULL));


--
-- Name: ngan_sach ngan_sach_sua; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ngan_sach_sua ON public.ngan_sach FOR UPDATE TO authenticated USING (private.duoc_sua_danh_muc()) WITH CHECK (private.duoc_sua_danh_muc());


--
-- Name: ngan_sach ngan_sach_them; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ngan_sach_them ON public.ngan_sach FOR INSERT TO authenticated WITH CHECK (private.duoc_sua_danh_muc());


--
-- Name: nguon_tien_nhan_vien; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.nguon_tien_nhan_vien ENABLE ROW LEVEL SECURITY;

--
-- Name: nguon_tien_nhan_vien nguon_tien_nhan_vien_doc; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY nguon_tien_nhan_vien_doc ON public.nguon_tien_nhan_vien FOR SELECT TO authenticated USING (true);


--
-- Name: nguon_tien_nhan_vien nguon_tien_nhan_vien_them; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY nguon_tien_nhan_vien_them ON public.nguon_tien_nhan_vien FOR INSERT TO authenticated WITH CHECK (private.co_vai_tro('quan_tri'::text));


--
-- Name: nguon_tien_nhan_vien nguon_tien_nhan_vien_xoa; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY nguon_tien_nhan_vien_xoa ON public.nguon_tien_nhan_vien FOR DELETE TO authenticated USING (private.co_vai_tro('quan_tri'::text));


--
-- Name: nha_cung_cap; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.nha_cung_cap ENABLE ROW LEVEL SECURITY;

--
-- Name: nha_cung_cap nha_cung_cap_doc; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY nha_cung_cap_doc ON public.nha_cung_cap FOR SELECT TO authenticated USING ((private.nhan_vien_hien_tai() IS NOT NULL));


--
-- Name: nha_cung_cap nha_cung_cap_sua; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY nha_cung_cap_sua ON public.nha_cung_cap FOR UPDATE TO authenticated USING (private.duoc_sua_danh_muc()) WITH CHECK (private.duoc_sua_danh_muc());


--
-- Name: nha_cung_cap nha_cung_cap_them; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY nha_cung_cap_them ON public.nha_cung_cap FOR INSERT TO authenticated WITH CHECK (private.duoc_sua_danh_muc());


--
-- Name: nhan_vien; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.nhan_vien ENABLE ROW LEVEL SECURITY;

--
-- Name: nhan_vien nhan_vien_doc; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY nhan_vien_doc ON public.nhan_vien FOR SELECT TO authenticated USING ((private.nhan_vien_hien_tai() IS NOT NULL));


--
-- Name: nhan_vien_nhay_cam; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.nhan_vien_nhay_cam ENABLE ROW LEVEL SECURITY;

--
-- Name: nhan_vien_nhay_cam nhan_vien_nhay_cam_doc; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY nhan_vien_nhay_cam_doc ON public.nhan_vien_nhay_cam FOR SELECT TO authenticated USING ((private.la_nguoi_quan_ly_tai_chinh() OR (nhan_vien_id = private.nhan_vien_hien_tai())));


--
-- Name: nhan_vien_nhay_cam nhan_vien_nhay_cam_sua; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY nhan_vien_nhay_cam_sua ON public.nhan_vien_nhay_cam FOR UPDATE TO authenticated USING (private.co_vai_tro('quan_tri'::text)) WITH CHECK (private.co_vai_tro('quan_tri'::text));


--
-- Name: nhan_vien_nhay_cam nhan_vien_nhay_cam_them; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY nhan_vien_nhay_cam_them ON public.nhan_vien_nhay_cam FOR INSERT TO authenticated WITH CHECK (private.co_vai_tro('quan_tri'::text));


--
-- Name: nhan_vien nhan_vien_sua; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY nhan_vien_sua ON public.nhan_vien FOR UPDATE TO authenticated USING (private.co_vai_tro('quan_tri'::text)) WITH CHECK (private.co_vai_tro('quan_tri'::text));


--
-- Name: nhan_vien nhan_vien_them; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY nhan_vien_them ON public.nhan_vien FOR INSERT TO authenticated WITH CHECK (private.co_vai_tro('quan_tri'::text));


--
-- Name: nhat_ky; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.nhat_ky ENABLE ROW LEVEL SECURITY;

--
-- Name: nhat_ky nhat_ky_doc; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY nhat_ky_doc ON public.nhat_ky FOR SELECT TO authenticated USING ((private.la_nguoi_quan_ly_tai_chinh() OR (nguoi_thuc_hien_id = private.nhan_vien_hien_tai()) OR ((bang = 'de_nghi'::text) AND private.duoc_xem_de_nghi(ban_ghi_id))));


--
-- Name: phieu_thu; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.phieu_thu ENABLE ROW LEVEL SECURITY;

--
-- Name: phieu_thu phieu_thu_doc; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY phieu_thu_doc ON public.phieu_thu FOR SELECT TO authenticated USING (((private.la_nguoi_quan_ly_tai_chinh() AND (private.duoc_xem_nguon_tien(quy_tien_mat_id, tai_khoan_ngan_hang_id) OR (de_nghi_tam_ung_goc_id IS NOT NULL) OR (EXISTS ( SELECT 1
   FROM public.khoan_muc_thu k
  WHERE ((k.id = phieu_thu.khoan_muc_thu_id) AND (k.nhom_cong_no IS NOT NULL)))))) OR (EXISTS ( SELECT 1
   FROM public.de_nghi dn
  WHERE ((dn.id = phieu_thu.de_nghi_tam_ung_goc_id) AND (dn.nhan_vien_nhan_ung_id = private.nhan_vien_hien_tai()))))));


--
-- Name: quy_tien_mat; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quy_tien_mat ENABLE ROW LEVEL SECURITY;

--
-- Name: quy_tien_mat quy_tien_mat_doc; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY quy_tien_mat_doc ON public.quy_tien_mat FOR SELECT TO authenticated USING ((private.nhan_vien_hien_tai() IS NOT NULL));


--
-- Name: quy_tien_mat quy_tien_mat_sua; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY quy_tien_mat_sua ON public.quy_tien_mat FOR UPDATE TO authenticated USING (private.duoc_sua_danh_muc()) WITH CHECK (private.duoc_sua_danh_muc());


--
-- Name: quy_tien_mat quy_tien_mat_them; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY quy_tien_mat_them ON public.quy_tien_mat FOR INSERT TO authenticated WITH CHECK (private.duoc_sua_danh_muc());


--
-- Name: so_thu_tu_de_nghi; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.so_thu_tu_de_nghi ENABLE ROW LEVEL SECURITY;

--
-- Name: tai_khoan_ngan_hang; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.tai_khoan_ngan_hang ENABLE ROW LEVEL SECURITY;

--
-- Name: tai_khoan_ngan_hang tai_khoan_ngan_hang_doc; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tai_khoan_ngan_hang_doc ON public.tai_khoan_ngan_hang FOR SELECT TO authenticated USING ((private.nhan_vien_hien_tai() IS NOT NULL));


--
-- Name: tai_khoan_ngan_hang tai_khoan_ngan_hang_sua; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tai_khoan_ngan_hang_sua ON public.tai_khoan_ngan_hang FOR UPDATE TO authenticated USING (private.duoc_sua_danh_muc()) WITH CHECK (private.duoc_sua_danh_muc());


--
-- Name: tai_khoan_ngan_hang tai_khoan_ngan_hang_them; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tai_khoan_ngan_hang_them ON public.tai_khoan_ngan_hang FOR INSERT TO authenticated WITH CHECK (private.duoc_sua_danh_muc());


--
-- Name: ton_dau_ky; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ton_dau_ky ENABLE ROW LEVEL SECURITY;

--
-- Name: ton_dau_ky ton_dau_ky_doc; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ton_dau_ky_doc ON public.ton_dau_ky FOR SELECT TO authenticated USING ((private.la_nguoi_quan_ly_tai_chinh() AND private.duoc_xem_nguon_tien(quy_tien_mat_id, tai_khoan_ngan_hang_id)));


--
-- Name: vai_tro_nhan_vien vai_tro_doc; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY vai_tro_doc ON public.vai_tro_nhan_vien FOR SELECT TO authenticated USING ((private.nhan_vien_hien_tai() IS NOT NULL));


--
-- Name: vai_tro_nhan_vien; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.vai_tro_nhan_vien ENABLE ROW LEVEL SECURITY;

--
-- Name: vai_tro_nhan_vien vai_tro_sua; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY vai_tro_sua ON public.vai_tro_nhan_vien FOR UPDATE TO authenticated USING (private.co_vai_tro('quan_tri'::text)) WITH CHECK (private.co_vai_tro('quan_tri'::text));


--
-- Name: vai_tro_nhan_vien vai_tro_them; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY vai_tro_them ON public.vai_tro_nhan_vien FOR INSERT TO authenticated WITH CHECK (private.co_vai_tro('quan_tri'::text));


--
-- Name: vai_tro_nhan_vien vai_tro_xoa; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY vai_tro_xoa ON public.vai_tro_nhan_vien FOR DELETE TO authenticated USING (private.co_vai_tro('quan_tri'::text));


--
-- Name: objects chung_tu_fmb_doc; Type: POLICY; Schema: storage; Owner: -
--

CREATE POLICY chung_tu_fmb_doc ON storage.objects FOR SELECT TO authenticated USING (((bucket_id = 'chung-tu-fmb'::text) AND ((owner = auth.uid()) OR private.duoc_xem_file(name))));


--
-- Name: objects chung_tu_fmb_tai_len; Type: POLICY; Schema: storage; Owner: -
--

CREATE POLICY chung_tu_fmb_tai_len ON storage.objects FOR INSERT TO authenticated WITH CHECK (((bucket_id = 'chung-tu-fmb'::text) AND (private.nhan_vien_hien_tai() IS NOT NULL) AND ((storage.foldername(name))[1] = (auth.uid())::text)));


--
-- Name: objects chung_tu_fmb_xoa_file_rac; Type: POLICY; Schema: storage; Owner: -
--

CREATE POLICY chung_tu_fmb_xoa_file_rac ON storage.objects FOR DELETE TO authenticated USING (((bucket_id = 'chung-tu-fmb'::text) AND (owner = auth.uid()) AND (NOT private.file_da_gan_chung_tu(name))));


--
-- Name: SCHEMA private; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA private TO authenticated;
GRANT USAGE ON SCHEMA private TO service_role;


--
-- Name: FUNCTION bat_buoc_vai_tro(p_vai_tro text, p_ten_viec text); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.bat_buoc_vai_tro(p_vai_tro text, p_ten_viec text) FROM PUBLIC;


--
-- Name: FUNCTION bi_siet_theo_nguon_tien(); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.bi_siet_theo_nguon_tien() FROM PUBLIC;
GRANT ALL ON FUNCTION private.bi_siet_theo_nguon_tien() TO authenticated;
GRANT ALL ON FUNCTION private.bi_siet_theo_nguon_tien() TO service_role;


--
-- Name: FUNCTION bu_cong_no_am_cho_nguoi(p_nguoi_id uuid, p_de_nghi_moi uuid, p_lan_tra_id uuid, p_toi_da numeric, p_ngay date, p_nguoi_tao uuid, p_ly_do text); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.bu_cong_no_am_cho_nguoi(p_nguoi_id uuid, p_de_nghi_moi uuid, p_lan_tra_id uuid, p_toi_da numeric, p_ngay date, p_nguoi_tao uuid, p_ly_do text) FROM PUBLIC;


--
-- Name: FUNCTION but_toan_nhap_quy_trung(p_quy_tien_mat_id uuid, p_so_tien numeric, p_ngay date); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.but_toan_nhap_quy_trung(p_quy_tien_mat_id uuid, p_so_tien numeric, p_ngay date) FROM PUBLIC;
GRANT ALL ON FUNCTION private.but_toan_nhap_quy_trung(p_quy_tien_mat_id uuid, p_so_tien numeric, p_ngay date) TO authenticated;
GRANT ALL ON FUNCTION private.but_toan_nhap_quy_trung(p_quy_tien_mat_id uuid, p_so_tien numeric, p_ngay date) TO service_role;


--
-- Name: FUNCTION chan_nguon_khong_duoc_phan_quyen(); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.chan_nguon_khong_duoc_phan_quyen() FROM PUBLIC;


--
-- Name: FUNCTION chan_phieu_thu_trung_nhap_quy(); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.chan_phieu_thu_trung_nhap_quy() FROM PUBLIC;


--
-- Name: FUNCTION co_mot_trong_vai_tro(p_vai_tro text[]); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.co_mot_trong_vai_tro(p_vai_tro text[]) FROM PUBLIC;
GRANT ALL ON FUNCTION private.co_mot_trong_vai_tro(p_vai_tro text[]) TO authenticated;
GRANT ALL ON FUNCTION private.co_mot_trong_vai_tro(p_vai_tro text[]) TO service_role;


--
-- Name: FUNCTION co_tab(p_duong_dan text); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.co_tab(p_duong_dan text) FROM PUBLIC;
GRANT ALL ON FUNCTION private.co_tab(p_duong_dan text) TO authenticated;
GRANT ALL ON FUNCTION private.co_tab(p_duong_dan text) TO service_role;


--
-- Name: FUNCTION co_vai_tro(p_vai_tro text); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.co_vai_tro(p_vai_tro text) FROM PUBLIC;
GRANT ALL ON FUNCTION private.co_vai_tro(p_vai_tro text) TO authenticated;
GRANT ALL ON FUNCTION private.co_vai_tro(p_vai_tro text) TO service_role;


--
-- Name: FUNCTION con_phai_chi_that(p_dot_id uuid); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.con_phai_chi_that(p_dot_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION private.con_phai_chi_that(p_dot_id uuid) TO authenticated;
GRANT ALL ON FUNCTION private.con_phai_chi_that(p_dot_id uuid) TO service_role;


--
-- Name: FUNCTION dong_quyet_toan_da_can_doi(p_dot_id uuid, p_nguoi_id uuid); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.dong_quyet_toan_da_can_doi(p_dot_id uuid, p_nguoi_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION private.dong_quyet_toan_da_can_doi(p_dot_id uuid, p_nguoi_id uuid) TO authenticated;
GRANT ALL ON FUNCTION private.dong_quyet_toan_da_can_doi(p_dot_id uuid, p_nguoi_id uuid) TO service_role;


--
-- Name: FUNCTION duoc_sua_danh_muc(); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.duoc_sua_danh_muc() FROM PUBLIC;
GRANT ALL ON FUNCTION private.duoc_sua_danh_muc() TO authenticated;
GRANT ALL ON FUNCTION private.duoc_sua_danh_muc() TO service_role;


--
-- Name: FUNCTION duoc_xem_de_nghi(p_de_nghi_id uuid); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.duoc_xem_de_nghi(p_de_nghi_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION private.duoc_xem_de_nghi(p_de_nghi_id uuid) TO authenticated;
GRANT ALL ON FUNCTION private.duoc_xem_de_nghi(p_de_nghi_id uuid) TO service_role;


--
-- Name: FUNCTION duoc_xem_file(p_duong_dan text); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.duoc_xem_file(p_duong_dan text) FROM PUBLIC;
GRANT ALL ON FUNCTION private.duoc_xem_file(p_duong_dan text) TO authenticated;
GRANT ALL ON FUNCTION private.duoc_xem_file(p_duong_dan text) TO service_role;


--
-- Name: FUNCTION duoc_xem_nguon_tien(p_quy_id uuid, p_tk_id uuid); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.duoc_xem_nguon_tien(p_quy_id uuid, p_tk_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION private.duoc_xem_nguon_tien(p_quy_id uuid, p_tk_id uuid) TO authenticated;
GRANT ALL ON FUNCTION private.duoc_xem_nguon_tien(p_quy_id uuid, p_tk_id uuid) TO service_role;


--
-- Name: FUNCTION file_da_gan_chung_tu(p_duong_dan text); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.file_da_gan_chung_tu(p_duong_dan text) FROM PUBLIC;
GRANT ALL ON FUNCTION private.file_da_gan_chung_tu(p_duong_dan text) TO authenticated;
GRANT ALL ON FUNCTION private.file_da_gan_chung_tu(p_duong_dan text) TO service_role;


--
-- Name: FUNCTION ghi_chi_quy_cong_truong(p_dot_id uuid, p_nguoi_id uuid); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.ghi_chi_quy_cong_truong(p_dot_id uuid, p_nguoi_id uuid) FROM PUBLIC;


--
-- Name: FUNCTION ghi_nhat_ky(p_bang text, p_ban_ghi_id uuid, p_hanh_dong text, p_gia_tri_cu jsonb, p_gia_tri_moi jsonb); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.ghi_nhat_ky(p_bang text, p_ban_ghi_id uuid, p_hanh_dong text, p_gia_tri_cu jsonb, p_gia_tri_moi jsonb) FROM PUBLIC;


--
-- Name: FUNCTION han_muc_tam_ung_da_duyet(p_de_nghi_id uuid); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.han_muc_tam_ung_da_duyet(p_de_nghi_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION private.han_muc_tam_ung_da_duyet(p_de_nghi_id uuid) TO authenticated;
GRANT ALL ON FUNCTION private.han_muc_tam_ung_da_duyet(p_de_nghi_id uuid) TO service_role;


--
-- Name: FUNCTION la_nguoi_quan_ly_tai_chinh(); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.la_nguoi_quan_ly_tai_chinh() FROM PUBLIC;
GRANT ALL ON FUNCTION private.la_nguoi_quan_ly_tai_chinh() TO authenticated;
GRANT ALL ON FUNCTION private.la_nguoi_quan_ly_tai_chinh() TO service_role;


--
-- Name: FUNCTION ma_danh_muc_tiep_theo(p_bang text, p_tien_to text); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.ma_danh_muc_tiep_theo(p_bang text, p_tien_to text) FROM PUBLIC;


--
-- Name: FUNCTION nhan_vien_hien_tai(); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.nhan_vien_hien_tai() FROM PUBLIC;
GRANT ALL ON FUNCTION private.nhan_vien_hien_tai() TO authenticated;
GRANT ALL ON FUNCTION private.nhan_vien_hien_tai() TO service_role;


--
-- Name: FUNCTION quy_cua_nguoi_nhan_ung(p_nhan_vien_id uuid); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.quy_cua_nguoi_nhan_ung(p_nhan_vien_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION private.quy_cua_nguoi_nhan_ung(p_nhan_vien_id uuid) TO authenticated;
GRANT ALL ON FUNCTION private.quy_cua_nguoi_nhan_ung(p_nhan_vien_id uuid) TO service_role;


--
-- Name: FUNCTION sinh_so_de_nghi(p_loai text, p_ma_cong_ty text, p_nam integer); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.sinh_so_de_nghi(p_loai text, p_ma_cong_ty text, p_nam integer) FROM PUBLIC;


--
-- Name: FUNCTION snapshot_va_xoa_giao_dich(p_loai text, p_id uuid); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.snapshot_va_xoa_giao_dich(p_loai text, p_id uuid) FROM PUBLIC;


--
-- Name: FUNCTION so_du_han_muc_quyet_toan(p_de_nghi_tam_ung_id uuid); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.so_du_han_muc_quyet_toan(p_de_nghi_tam_ung_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION private.so_du_han_muc_quyet_toan(p_de_nghi_tam_ung_id uuid) TO authenticated;
GRANT ALL ON FUNCTION private.so_du_han_muc_quyet_toan(p_de_nghi_tam_ung_id uuid) TO service_role;


--
-- Name: FUNCTION so_du_nguon_tien(p_quy_id uuid, p_tk_id uuid); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.so_du_nguon_tien(p_quy_id uuid, p_tk_id uuid) FROM PUBLIC;


--
-- Name: FUNCTION sua_so_tien_phieu_chi(p_ltt_id uuid, p_chi_tiet jsonb); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.sua_so_tien_phieu_chi(p_ltt_id uuid, p_chi_tiet jsonb) FROM PUBLIC;


--
-- Name: FUNCTION tra_bu_toi_da(p_dot_id uuid); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.tra_bu_toi_da(p_dot_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION private.tra_bu_toi_da(p_dot_id uuid) TO authenticated;
GRANT ALL ON FUNCTION private.tra_bu_toi_da(p_dot_id uuid) TO service_role;


--
-- Name: FUNCTION vuong_mac_nhan_vien(p_id uuid); Type: ACL; Schema: private; Owner: -
--

REVOKE ALL ON FUNCTION private.vuong_mac_nhan_vien(p_id uuid) FROM PUBLIC;


--
-- Name: FUNCTION admin_huy_giao_dich(p_loai text, p_id uuid, p_ly_do text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.admin_huy_giao_dich(p_loai text, p_id uuid, p_ly_do text) TO authenticated;
GRANT ALL ON FUNCTION public.admin_huy_giao_dich(p_loai text, p_id uuid, p_ly_do text) TO service_role;


--
-- Name: FUNCTION admin_khoi_phuc_giao_dich(p_archive_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.admin_khoi_phuc_giao_dich(p_archive_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.admin_khoi_phuc_giao_dich(p_archive_id uuid) TO service_role;


--
-- Name: FUNCTION admin_kiem_xoa_nhan_vien(p_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.admin_kiem_xoa_nhan_vien(p_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.admin_kiem_xoa_nhan_vien(p_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.admin_kiem_xoa_nhan_vien(p_id uuid) TO service_role;


--
-- Name: FUNCTION admin_sua_giao_dich(p_loai text, p_id uuid, p_thay_doi jsonb, p_ly_do text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.admin_sua_giao_dich(p_loai text, p_id uuid, p_thay_doi jsonb, p_ly_do text) TO authenticated;
GRANT ALL ON FUNCTION public.admin_sua_giao_dich(p_loai text, p_id uuid, p_thay_doi jsonb, p_ly_do text) TO service_role;


--
-- Name: FUNCTION admin_xoa_giao_dich(p_loai text, p_id uuid, p_ly_do text); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.admin_xoa_giao_dich(p_loai text, p_id uuid, p_ly_do text) TO authenticated;
GRANT ALL ON FUNCTION public.admin_xoa_giao_dich(p_loai text, p_id uuid, p_ly_do text) TO service_role;


--
-- Name: FUNCTION admin_xoa_nhan_vien(p_id uuid, p_ly_do text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.admin_xoa_nhan_vien(p_id uuid, p_ly_do text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.admin_xoa_nhan_vien(p_id uuid, p_ly_do text) TO authenticated;
GRANT ALL ON FUNCTION public.admin_xoa_nhan_vien(p_id uuid, p_ly_do text) TO service_role;


--
-- Name: FUNCTION chu_tich_duyet_dot(p_dot_id uuid, p_y_kien text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.chu_tich_duyet_dot(p_dot_id uuid, p_y_kien text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.chu_tich_duyet_dot(p_dot_id uuid, p_y_kien text) TO authenticated;
GRANT ALL ON FUNCTION public.chu_tich_duyet_dot(p_dot_id uuid, p_y_kien text) TO service_role;


--
-- Name: FUNCTION chu_tich_duyet_dot_qua_bot(p_dot_id uuid, p_nhan_vien_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.chu_tich_duyet_dot_qua_bot(p_dot_id uuid, p_nhan_vien_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.chu_tich_duyet_dot_qua_bot(p_dot_id uuid, p_nhan_vien_id uuid) TO service_role;


--
-- Name: FUNCTION chu_tich_tu_choi_dot(p_dot_id uuid, p_ly_do text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.chu_tich_tu_choi_dot(p_dot_id uuid, p_ly_do text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.chu_tich_tu_choi_dot(p_dot_id uuid, p_ly_do text) TO authenticated;
GRANT ALL ON FUNCTION public.chu_tich_tu_choi_dot(p_dot_id uuid, p_ly_do text) TO service_role;


--
-- Name: FUNCTION dinh_chung_tu_de_nghi(p_de_nghi_id uuid, p_chung_tu jsonb); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.dinh_chung_tu_de_nghi(p_de_nghi_id uuid, p_chung_tu jsonb) FROM PUBLIC;
GRANT ALL ON FUNCTION public.dinh_chung_tu_de_nghi(p_de_nghi_id uuid, p_chung_tu jsonb) TO authenticated;
GRANT ALL ON FUNCTION public.dinh_chung_tu_de_nghi(p_de_nghi_id uuid, p_chung_tu jsonb) TO service_role;


--
-- Name: FUNCTION dong_dot(p_dot_id uuid, p_ly_do text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.dong_dot(p_dot_id uuid, p_ly_do text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.dong_dot(p_dot_id uuid, p_ly_do text) TO authenticated;
GRANT ALL ON FUNCTION public.dong_dot(p_dot_id uuid, p_ly_do text) TO service_role;


--
-- Name: FUNCTION gui_duyet_de_nghi(p_de_nghi_id uuid, p_ngoai_le_ly_do text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.gui_duyet_de_nghi(p_de_nghi_id uuid, p_ngoai_le_ly_do text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.gui_duyet_de_nghi(p_de_nghi_id uuid, p_ngoai_le_ly_do text) TO authenticated;
GRANT ALL ON FUNCTION public.gui_duyet_de_nghi(p_de_nghi_id uuid, p_ngoai_le_ly_do text) TO service_role;


--
-- Name: FUNCTION huy_de_nghi(p_de_nghi_id uuid, p_ly_do text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.huy_de_nghi(p_de_nghi_id uuid, p_ly_do text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.huy_de_nghi(p_de_nghi_id uuid, p_ly_do text) TO authenticated;
GRANT ALL ON FUNCTION public.huy_de_nghi(p_de_nghi_id uuid, p_ly_do text) TO service_role;


--
-- Name: FUNCTION huy_nop_lai_tien_thua(p_phieu_thu_id uuid, p_ly_do text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.huy_nop_lai_tien_thua(p_phieu_thu_id uuid, p_ly_do text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.huy_nop_lai_tien_thua(p_phieu_thu_id uuid, p_ly_do text) TO authenticated;
GRANT ALL ON FUNCTION public.huy_nop_lai_tien_thua(p_phieu_thu_id uuid, p_ly_do text) TO service_role;


--
-- Name: FUNCTION kiem_nhap_quy_trung(p_quy_tien_mat_id uuid, p_so_tien numeric, p_ngay date); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.kiem_nhap_quy_trung(p_quy_tien_mat_id uuid, p_so_tien numeric, p_ngay date) FROM PUBLIC;
GRANT ALL ON FUNCTION public.kiem_nhap_quy_trung(p_quy_tien_mat_id uuid, p_so_tien numeric, p_ngay date) TO authenticated;
GRANT ALL ON FUNCTION public.kiem_nhap_quy_trung(p_quy_tien_mat_id uuid, p_so_tien numeric, p_ngay date) TO service_role;


--
-- Name: FUNCTION ktt_tao_dot_duyet(p_de_nghi_id uuid, p_muc_ids uuid[], p_y_kien text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.ktt_tao_dot_duyet(p_de_nghi_id uuid, p_muc_ids uuid[], p_y_kien text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.ktt_tao_dot_duyet(p_de_nghi_id uuid, p_muc_ids uuid[], p_y_kien text) TO authenticated;
GRANT ALL ON FUNCTION public.ktt_tao_dot_duyet(p_de_nghi_id uuid, p_muc_ids uuid[], p_y_kien text) TO service_role;


--
-- Name: FUNCTION ktt_tao_dot_duyet(p_de_nghi_id uuid, p_muc jsonb, p_y_kien text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.ktt_tao_dot_duyet(p_de_nghi_id uuid, p_muc jsonb, p_y_kien text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.ktt_tao_dot_duyet(p_de_nghi_id uuid, p_muc jsonb, p_y_kien text) TO authenticated;
GRANT ALL ON FUNCTION public.ktt_tao_dot_duyet(p_de_nghi_id uuid, p_muc jsonb, p_y_kien text) TO service_role;


--
-- Name: FUNCTION ktt_tra_ve_de_nghi(p_de_nghi_id uuid, p_ly_do text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.ktt_tra_ve_de_nghi(p_de_nghi_id uuid, p_ly_do text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.ktt_tra_ve_de_nghi(p_de_nghi_id uuid, p_ly_do text) TO authenticated;
GRANT ALL ON FUNCTION public.ktt_tra_ve_de_nghi(p_de_nghi_id uuid, p_ly_do text) TO service_role;


--
-- Name: FUNCTION ktt_tu_choi_muc(p_muc_id uuid, p_ly_do text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.ktt_tu_choi_muc(p_muc_id uuid, p_ly_do text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.ktt_tu_choi_muc(p_muc_id uuid, p_ly_do text) TO authenticated;
GRANT ALL ON FUNCTION public.ktt_tu_choi_muc(p_muc_id uuid, p_ly_do text) TO service_role;


--
-- Name: FUNCTION luu_ton_dau_ky(p_quy_id uuid, p_tk_id uuid, p_so_tien public.tien_te, p_ngay date); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.luu_ton_dau_ky(p_quy_id uuid, p_tk_id uuid, p_so_tien public.tien_te, p_ngay date) FROM PUBLIC;
GRANT ALL ON FUNCTION public.luu_ton_dau_ky(p_quy_id uuid, p_tk_id uuid, p_so_tien public.tien_te, p_ngay date) TO authenticated;
GRANT ALL ON FUNCTION public.luu_ton_dau_ky(p_quy_id uuid, p_tk_id uuid, p_so_tien public.tien_te, p_ngay date) TO service_role;


--
-- Name: FUNCTION tao_chuyen_quy(p_payload jsonb); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.tao_chuyen_quy(p_payload jsonb) FROM PUBLIC;
GRANT ALL ON FUNCTION public.tao_chuyen_quy(p_payload jsonb) TO authenticated;
GRANT ALL ON FUNCTION public.tao_chuyen_quy(p_payload jsonb) TO service_role;


--
-- Name: FUNCTION tao_nop_lai_tien_thua(p_de_nghi_tam_ung_id uuid, p_so_tien numeric, p_ngay_thu date, p_quy_id uuid, p_tk_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.tao_nop_lai_tien_thua(p_de_nghi_tam_ung_id uuid, p_so_tien numeric, p_ngay_thu date, p_quy_id uuid, p_tk_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.tao_nop_lai_tien_thua(p_de_nghi_tam_ung_id uuid, p_so_tien numeric, p_ngay_thu date, p_quy_id uuid, p_tk_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.tao_nop_lai_tien_thua(p_de_nghi_tam_ung_id uuid, p_so_tien numeric, p_ngay_thu date, p_quy_id uuid, p_tk_id uuid) TO service_role;


--
-- Name: FUNCTION tao_phieu_thu(p_payload jsonb); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.tao_phieu_thu(p_payload jsonb) FROM PUBLIC;
GRANT ALL ON FUNCTION public.tao_phieu_thu(p_payload jsonb) TO authenticated;
GRANT ALL ON FUNCTION public.tao_phieu_thu(p_payload jsonb) TO service_role;


--
-- Name: FUNCTION tao_sua_de_nghi_nhap(p_payload jsonb); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.tao_sua_de_nghi_nhap(p_payload jsonb) FROM PUBLIC;
GRANT ALL ON FUNCTION public.tao_sua_de_nghi_nhap(p_payload jsonb) TO authenticated;
GRANT ALL ON FUNCTION public.tao_sua_de_nghi_nhap(p_payload jsonb) TO service_role;


--
-- Name: FUNCTION tra_tam_ung_cap_tru(p_dot_id uuid, p_chi_tiet jsonb, p_cap_tru jsonb, p_chung_tu jsonb, p_ngay_tra date, p_quy_id uuid, p_tk_id uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.tra_tam_ung_cap_tru(p_dot_id uuid, p_chi_tiet jsonb, p_cap_tru jsonb, p_chung_tu jsonb, p_ngay_tra date, p_quy_id uuid, p_tk_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.tra_tam_ung_cap_tru(p_dot_id uuid, p_chi_tiet jsonb, p_cap_tru jsonb, p_chung_tu jsonb, p_ngay_tra date, p_quy_id uuid, p_tk_id uuid) TO service_role;


--
-- Name: FUNCTION tra_tien_dot(p_dot_id uuid, p_chi_tiet jsonb, p_chung_tu jsonb, p_ngay_tra date, p_quy_id uuid, p_tk_id uuid, p_bu_cong_no_am boolean); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.tra_tien_dot(p_dot_id uuid, p_chi_tiet jsonb, p_chung_tu jsonb, p_ngay_tra date, p_quy_id uuid, p_tk_id uuid, p_bu_cong_no_am boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION public.tra_tien_dot(p_dot_id uuid, p_chi_tiet jsonb, p_chung_tu jsonb, p_ngay_tra date, p_quy_id uuid, p_tk_id uuid, p_bu_cong_no_am boolean) TO authenticated;
GRANT ALL ON FUNCTION public.tra_tien_dot(p_dot_id uuid, p_chi_tiet jsonb, p_chung_tu jsonb, p_ngay_tra date, p_quy_id uuid, p_tk_id uuid, p_bu_cong_no_am boolean) TO service_role;


--
-- Name: FUNCTION xac_nhan_nop_lai_tien_thua(p_phieu_thu_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.xac_nhan_nop_lai_tien_thua(p_phieu_thu_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.xac_nhan_nop_lai_tien_thua(p_phieu_thu_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.xac_nhan_nop_lai_tien_thua(p_phieu_thu_id uuid) TO service_role;


--
-- Name: FUNCTION xac_nhan_phieu_thu(p_phieu_thu_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.xac_nhan_phieu_thu(p_phieu_thu_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.xac_nhan_phieu_thu(p_phieu_thu_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.xac_nhan_phieu_thu(p_phieu_thu_id uuid) TO service_role;


--
-- Name: FUNCTION xoa_chung_tu_de_nghi(p_chung_tu_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.xoa_chung_tu_de_nghi(p_chung_tu_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.xoa_chung_tu_de_nghi(p_chung_tu_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.xoa_chung_tu_de_nghi(p_chung_tu_id uuid) TO service_role;


--
-- Name: TABLE bu_cong_no_am; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.bu_cong_no_am TO authenticated;
GRANT ALL ON TABLE public.bu_cong_no_am TO service_role;


--
-- Name: TABLE but_toan_quy_cong_truong; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.but_toan_quy_cong_truong TO authenticated;
GRANT ALL ON TABLE public.but_toan_quy_cong_truong TO service_role;


--
-- Name: TABLE cau_hinh_he_thong; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.cau_hinh_he_thong TO authenticated;
GRANT ALL ON TABLE public.cau_hinh_he_thong TO service_role;


--
-- Name: TABLE chi_tiet_lan_tra; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.chi_tiet_lan_tra TO authenticated;
GRANT ALL ON TABLE public.chi_tiet_lan_tra TO service_role;


--
-- Name: TABLE chung_tu_fmb; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.chung_tu_fmb TO authenticated;
GRANT ALL ON TABLE public.chung_tu_fmb TO service_role;


--
-- Name: TABLE chuyen_quy; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.chuyen_quy TO authenticated;
GRANT ALL ON TABLE public.chuyen_quy TO service_role;


--
-- Name: TABLE cong_ty; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.cong_ty TO authenticated;
GRANT ALL ON TABLE public.cong_ty TO service_role;


--
-- Name: TABLE de_nghi; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.de_nghi TO authenticated;
GRANT ALL ON TABLE public.de_nghi TO service_role;


--
-- Name: TABLE doi_tuong_vay; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.doi_tuong_vay TO authenticated;
GRANT ALL ON TABLE public.doi_tuong_vay TO service_role;


--
-- Name: TABLE dot_duyet; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.dot_duyet TO authenticated;
GRANT ALL ON TABLE public.dot_duyet TO service_role;


--
-- Name: TABLE du_an; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.du_an TO authenticated;
GRANT ALL ON TABLE public.du_an TO service_role;


--
-- Name: TABLE giao_dich_da_huy; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.giao_dich_da_huy TO authenticated;
GRANT ALL ON TABLE public.giao_dich_da_huy TO service_role;


--
-- Name: TABLE giao_dich_lich_su; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.giao_dich_lich_su TO authenticated;
GRANT ALL ON TABLE public.giao_dich_lich_su TO service_role;


--
-- Name: TABLE khach_hang; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.khach_hang TO authenticated;
GRANT ALL ON TABLE public.khach_hang TO service_role;


--
-- Name: TABLE khoan_muc_chi; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.khoan_muc_chi TO authenticated;
GRANT ALL ON TABLE public.khoan_muc_chi TO service_role;


--
-- Name: TABLE khoan_muc_thu; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.khoan_muc_thu TO authenticated;
GRANT ALL ON TABLE public.khoan_muc_thu TO service_role;


--
-- Name: TABLE lan_tra_tien; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.lan_tra_tien TO authenticated;
GRANT ALL ON TABLE public.lan_tra_tien TO service_role;


--
-- Name: TABLE menu_nhan_vien; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.menu_nhan_vien TO authenticated;
GRANT ALL ON TABLE public.menu_nhan_vien TO service_role;


--
-- Name: TABLE muc_de_nghi; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.muc_de_nghi TO authenticated;
GRANT ALL ON TABLE public.muc_de_nghi TO service_role;


--
-- Name: TABLE ngan_sach; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.ngan_sach TO authenticated;
GRANT ALL ON TABLE public.ngan_sach TO service_role;


--
-- Name: TABLE nguon_tien_nhan_vien; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.nguon_tien_nhan_vien TO authenticated;
GRANT ALL ON TABLE public.nguon_tien_nhan_vien TO service_role;


--
-- Name: TABLE nha_cung_cap; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.nha_cung_cap TO authenticated;
GRANT ALL ON TABLE public.nha_cung_cap TO service_role;


--
-- Name: TABLE nhan_vien; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.nhan_vien TO authenticated;
GRANT ALL ON TABLE public.nhan_vien TO service_role;


--
-- Name: TABLE nhan_vien_nhay_cam; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.nhan_vien_nhay_cam TO authenticated;
GRANT ALL ON TABLE public.nhan_vien_nhay_cam TO service_role;


--
-- Name: TABLE nhat_ky; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.nhat_ky TO authenticated;
GRANT ALL ON TABLE public.nhat_ky TO service_role;


--
-- Name: TABLE phieu_thu; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.phieu_thu TO authenticated;
GRANT ALL ON TABLE public.phieu_thu TO service_role;


--
-- Name: TABLE quy_tien_mat; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.quy_tien_mat TO authenticated;
GRANT ALL ON TABLE public.quy_tien_mat TO service_role;


--
-- Name: TABLE so_thu_tu_de_nghi; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.so_thu_tu_de_nghi TO authenticated;
GRANT ALL ON TABLE public.so_thu_tu_de_nghi TO service_role;


--
-- Name: TABLE tai_khoan_ngan_hang; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.tai_khoan_ngan_hang TO authenticated;
GRANT ALL ON TABLE public.tai_khoan_ngan_hang TO service_role;


--
-- Name: TABLE ton_dau_ky; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.ton_dau_ky TO authenticated;
GRANT ALL ON TABLE public.ton_dau_ky TO service_role;


--
-- Name: TABLE v_cong_no_tam_ung; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.v_cong_no_tam_ung TO authenticated;
GRANT ALL ON TABLE public.v_cong_no_tam_ung TO service_role;


--
-- Name: TABLE v_chi_phi; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.v_chi_phi TO authenticated;
GRANT ALL ON TABLE public.v_chi_phi TO service_role;


--
-- Name: TABLE v_cho_toi_xu_ly; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.v_cho_toi_xu_ly TO authenticated;
GRANT ALL ON TABLE public.v_cho_toi_xu_ly TO service_role;


--
-- Name: TABLE v_muc_tong_hop; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.v_muc_tong_hop TO authenticated;
GRANT ALL ON TABLE public.v_muc_tong_hop TO service_role;


--
-- Name: TABLE v_cong_no_phai_tra; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.v_cong_no_phai_tra TO authenticated;
GRANT ALL ON TABLE public.v_cong_no_phai_tra TO service_role;


--
-- Name: TABLE v_cong_no_tam_ung_theo_nguoi; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.v_cong_no_tam_ung_theo_nguoi TO authenticated;
GRANT ALL ON TABLE public.v_cong_no_tam_ung_theo_nguoi TO service_role;


--
-- Name: TABLE v_giao_dich_vay; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.v_giao_dich_vay TO authenticated;
GRANT ALL ON TABLE public.v_giao_dich_vay TO service_role;


--
-- Name: TABLE v_cong_no_vay; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.v_cong_no_vay TO authenticated;
GRANT ALL ON TABLE public.v_cong_no_vay TO service_role;


--
-- Name: TABLE v_de_nghi_trong_pham_vi; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.v_de_nghi_trong_pham_vi TO authenticated;
GRANT ALL ON TABLE public.v_de_nghi_trong_pham_vi TO service_role;


--
-- Name: TABLE v_dot_duyet_tong_hop; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.v_dot_duyet_tong_hop TO authenticated;
GRANT ALL ON TABLE public.v_dot_duyet_tong_hop TO service_role;


--
-- Name: TABLE v_dot_can_chi; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.v_dot_can_chi TO authenticated;
GRANT ALL ON TABLE public.v_dot_can_chi TO service_role;


--
-- Name: TABLE v_khoan_am_cho_bu; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.v_khoan_am_cho_bu TO authenticated;
GRANT ALL ON TABLE public.v_khoan_am_cho_bu TO service_role;


--
-- Name: TABLE v_ngan_sach; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.v_ngan_sach TO authenticated;
GRANT ALL ON TABLE public.v_ngan_sach TO service_role;


--
-- Name: TABLE v_nhap_quy_trung; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.v_nhap_quy_trung TO authenticated;
GRANT ALL ON TABLE public.v_nhap_quy_trung TO service_role;


--
-- Name: TABLE v_so_quy; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.v_so_quy TO authenticated;
GRANT ALL ON TABLE public.v_so_quy TO service_role;


--
-- Name: TABLE v_quy_chung_chi_ho; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.v_quy_chung_chi_ho TO authenticated;
GRANT ALL ON TABLE public.v_quy_chung_chi_ho TO service_role;


--
-- Name: TABLE v_quy_tien_mat_theo_khoan_muc; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.v_quy_tien_mat_theo_khoan_muc TO authenticated;
GRANT ALL ON TABLE public.v_quy_tien_mat_theo_khoan_muc TO service_role;


--
-- Name: TABLE v_so_du_nguon_tien; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.v_so_du_nguon_tien TO authenticated;
GRANT ALL ON TABLE public.v_so_du_nguon_tien TO service_role;


--
-- Name: TABLE v_so_du_quy_ca_nhan; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.v_so_du_quy_ca_nhan TO authenticated;
GRANT ALL ON TABLE public.v_so_du_quy_ca_nhan TO service_role;


--
-- Name: TABLE v_so_quy_luy_ke; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.v_so_quy_luy_ke TO authenticated;
GRANT ALL ON TABLE public.v_so_quy_luy_ke TO service_role;


--
-- Name: TABLE v_tam_ung_con_giu; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.v_tam_ung_con_giu TO authenticated;
GRANT ALL ON TABLE public.v_tam_ung_con_giu TO service_role;


--
-- Name: TABLE vai_tro_nhan_vien; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.vai_tro_nhan_vien TO authenticated;
GRANT ALL ON TABLE public.vai_tro_nhan_vien TO service_role;


--
-- PostgreSQL database dump complete
--





-- Bucket file chứng từ riêng của Tài chính (Nhân sự giữ bucket chung-tu).
insert into storage.buckets (id, name, public) values ('chung-tu-fmb', 'chung-tu-fmb', false)
on conflict (id) do nothing;
