-- =========================================================
-- P5i — Thưởng trực tiếp theo ngày công của tổ đội
--
-- Triệu Vũ, 25/08/2026: "Tổ đội cần bổ sung thêm thưởng trực tiếp theo chấm
-- công hàng ngày, thưởng bằng số tiền ấn định luôn."
--
-- Số tiền ẤN ĐỊNH, không phải hệ số. Người chấm gõ thẳng "100000" cho một
-- người trong một ngày, không nhân với đơn giá, không nhân với số công. Đây
-- là cùng một quyết định đã chốt 24/08 cho công ngoài giờ: đơn giá ngoài giờ
-- "theo thoả thuận của từng người", không theo hệ số.
--
-- ĐI THEO ĐÚNG ĐƯỜNG CỦA SỐ CÔNG
--
-- Thưởng nằm trên `cham_cong_cong_nhat` — cùng dòng với số công của người ấy
-- trong ngày ấy. Nghĩa là nó tự thừa hưởng mọi thứ đã dựng quanh số công:
--
--   • Người chấm của tổ ghi được, người khác không.
--   • Phiên duyệt xong là khoá, sửa phải mở lại phiên (P7a).
--   • Vào bảng thanh toán theo đúng khoảng ngày, chỉ tính phiên ĐÃ DUYỆT.
--
-- Dựng một bảng thưởng riêng thì phải chép lại cả bốn thứ đó, và bốn bản sao
-- sẽ lệch nhau — đúng hình dạng đã lặp năm lần trong dự án này.
--
-- THƯỞNG PHẢI CÓ LÝ DO
--
-- Ràng buộc: `thuong > 0` thì bắt buộc có `thuong_ly_do`. Không đặt độ dài
-- tối thiểu như P7a — người chấm đang đứng ngoài công trường, "làm đêm" hay
-- "bốc hàng nặng" là đủ. Nhưng con số không có chữ nào đi kèm thì sáu tháng
-- sau kế toán nhìn một khoản 200.000đ trong bảng thanh toán và không ai trả
-- lời được nó là gì.
-- =========================================================

-- ---------------------------------------------------------
-- 1. Thưởng trên dòng chấm công
-- ---------------------------------------------------------
alter table public.cham_cong_cong_nhat
  add column thuong        numeric(15, 2) not null default 0 check (thuong >= 0),
  add column thuong_ly_do  text;

comment on column public.cham_cong_cong_nhat.thuong is
  'Tiền thưởng ẤN ĐỊNH cho người này trong ngày này. Không nhân với đơn giá hay số công — gõ thẳng số tiền.';

comment on column public.cham_cong_cong_nhat.thuong_ly_do is
  'Vì sao thưởng. Bắt buộc khi thuong > 0: một khoản tiền không có chữ nào đi kèm là một câu hỏi không ai trả lời được sau vài tháng.';

alter table public.cham_cong_cong_nhat
  add constraint cccn_thuong_phai_co_ly_do
  check (thuong = 0 or nullif(btrim(coalesce(thuong_ly_do, '')), '') is not null);

-- Người chấm ghi hai cột này y như ghi giờ vào/ra. Quyền cấp cột đi cùng bộ
-- với `ca_sang_tu`…, không cấp thêm gì ngoài hai cột mới.
grant insert (thuong, thuong_ly_do) on public.cham_cong_cong_nhat to authenticated;
grant update (thuong, thuong_ly_do) on public.cham_cong_cong_nhat to authenticated;
grant select (thuong, thuong_ly_do) on public.cham_cong_cong_nhat to authenticated;

-- ---------------------------------------------------------
-- 2. Thưởng trên dòng bảng thanh toán
--
--    `thanh_tien` là CỘT SINH nên phải drop rồi dựng lại — Postgres không
--    sửa biểu thức cột sinh tại chỗ. Cùng cái bẫy đã gặp với `app_users.quyen`
--    hôm qua, chỉ khác là ở đây nó bắt buộc chứ không phải chuyện dễ quên.
-- ---------------------------------------------------------
alter table public.dong_thanh_toan_to drop column thanh_tien;

alter table public.dong_thanh_toan_to
  add column thuong numeric(15, 2) not null default 0 check (thuong >= 0);

comment on column public.dong_thanh_toan_to.thuong is
  'Tổng tiền thưởng của người này trong khoảng ngày của bảng, cộng từ cham_cong_cong_nhat.thuong. Chụp lại lúc sinh bảng, không tính lại.';

alter table public.dong_thanh_toan_to
  add column thanh_tien numeric(15, 2)
  generated always as (so_luong * don_gia + so_gio_ot * don_gia_ot + thuong) stored;

comment on column public.dong_thanh_toan_to.thanh_tien is
  'CỘT SINH: số lượng × đơn giá + giờ ngoài giờ × đơn giá ngoài giờ + thưởng. Không bao giờ lệch khỏi ba thành phần của nó, kể cả khi admin sửa một trong số đó.';

grant select (thuong, thanh_tien) on public.dong_thanh_toan_to to authenticated;

-- ---------------------------------------------------------
-- 3. Hàm sinh bảng cộng thêm thưởng
--
--    Sửa tại chỗ trong định nghĩa ĐANG CHẠY. Hàm này đã qua sáu bản (P5b,
--    P5c, P1c, P5d, P5e, và bản đọc-theo-dữ-liệu 24/08); chép lại thân hàm từ
--    một migration cũ là quay ngược lịch sử của nó.
--
--    Mỗi lần thay đều KIỂM là nó có xảy ra không: `replace()` không tìm thấy
--    thì trả nguyên chuỗi cũ, êm ru, và migration báo thành công trong khi
--    bảng thanh toán vẫn không có đồng thưởng nào.
-- ---------------------------------------------------------
do $$
declare
  dn    text;
  truoc text;
begin
  select pg_get_functiondef(p.oid) into dn
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prokind = 'f'
    and p.proname = 'sinh_bang_thanh_toan_to';

  if dn is null then
    raise exception 'Không tìm thấy sinh_bang_thanh_toan_to() đang chạy.';
  end if;

  -- ---- a. Cộng thưởng trong phần gộp theo người ----
  truoc := dn;
  dn := replace(
    dn,
    'sum(coalesce(c.so_gio_ot, 0))                 as so_gio_ot,',
    'sum(coalesce(c.so_gio_ot, 0))                 as so_gio_ot,
    sum(coalesce(c.thuong, 0))                    as tong_thuong,');
  if dn = truoc then
    raise exception 'Không tìm thấy chỗ gộp so_gio_ot. Thân hàm đã đổi hình dạng — đọc lại pg_get_functiondef rồi sửa migration này.';
  end if;

  -- ---- b. Mang cột ấy ra ngoài bảng tạm ----
  --
  -- Neo phai nam gon MOT DONG. Dinh nghia ma pg_get_functiondef() tra ve giu
  -- nguyen ky tu xuong dong kieu Windows cua file goc, con chuoi viet trong
  -- migration nay chi co ky tu xuong dong thuong — nen moi neo bac qua hai
  -- dong deu khong khop. Lan dau viet ban nay toi neo hai dong va migration
  -- dung ngay o day; do la ly do moi buoc deu tu kiem thay vi tin replace().
  truoc := dn;
  dn := replace(
    dn,
    'g.don_gia_ot,',
    'g.don_gia_ot,
    g.tong_thuong,');
  if dn = truoc then
    raise exception 'Không tìm thấy danh sách cột của bảng tạm.';
  end if;

  -- ---- c. Đừng vứt bỏ người CHỈ có thưởng ----
  --
  -- Dòng cũ xoá mọi người không có công và không có giờ ngoài giờ. Một người
  -- được thưởng trong ngày nghỉ, hoặc thưởng riêng không kèm công, sẽ bị xoá
  -- khỏi bảng cùng khoản thưởng của họ — mất tiền, lặng lẽ.
  truoc := dn;
  dn := replace(
    dn,
    'delete from tam_cong where so_luong <= 0 and so_gio_ot <= 0;',
    'delete from tam_cong
  where so_luong <= 0 and so_gio_ot <= 0 and coalesce(tong_thuong, 0) <= 0;');
  if dn = truoc then
    raise exception 'Không tìm thấy dòng dọn người không có công.';
  end if;

  -- ---- d. Ghi vào bảng thanh toán ----
  truoc := dn;
  dn := replace(
    dn,
    '(bang_id, employee_id, kieu_tinh, so_luong, don_gia, so_gio_ot, don_gia_ot)',
    '(bang_id, employee_id, kieu_tinh, so_luong, don_gia, so_gio_ot, don_gia_ot, thuong)');
  if dn = truoc then
    raise exception 'Không tìm thấy danh sách cột khi chèn dòng thanh toán.';
  end if;

  truoc := dn;
  dn := replace(
    dn,
    'coalesce(t.don_gia, 0), t.so_gio_ot, coalesce(t.don_gia_ot, 0)',
    'coalesce(t.don_gia, 0), t.so_gio_ot, coalesce(t.don_gia_ot, 0),
    coalesce(t.tong_thuong, 0)');
  if dn = truoc then
    raise exception 'Không tìm thấy danh sách giá trị khi chèn dòng thanh toán.';
  end if;

  execute dn;
end $$;

-- ---------------------------------------------------------
-- 4. Người CHỈ có thưởng vẫn phải qua được cửa "thiếu đơn giá"
--
--    Hai phép kiểm ở giữa hàm từ chối khi `so_luong > 0` mà thiếu đơn giá.
--    Người chỉ có thưởng thì `so_luong = 0`, nên họ đi qua — không phải nới
--    gì. Ghi lại ở đây vì đó là câu hỏi đầu tiên người đọc sau sẽ đặt ra.
-- ---------------------------------------------------------
