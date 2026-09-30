-- =========================================================
-- P7a — Engine lương cộng khoản truy lĩnh
--
-- Khoản truy lĩnh chỉ có nghĩa khi bảng lương thật sự trả nó. Bản này là chỗ
-- duy nhất trong P7a chạm vào TIỀN của kỳ lương, nên nó tách riêng và sửa ít
-- nhất có thể.
--
-- SỬA TẠI CHỖ TRONG ĐỊNH NGHĨA ĐANG CHẠY
--
-- `tinh_luong_ky()` dài hơn 200 dòng và đã qua nhiều bản. Chép lại thân hàm từ
-- migration cũ là quay ngược lịch sử của nó — đúng lỗi đã mắc 24/08 với
-- `them_nhan_cong_to`. Nên đọc `pg_get_functiondef()` của bản ĐANG CHẠY rồi
-- thay đúng ba đoạn.
--
-- Mỗi lần thay đều KIỂM là nó có xảy ra không. `replace()` không tìm thấy thì
-- trả về nguyên chuỗi cũ, êm ru — và migration sẽ báo thành công trong khi
-- không đổi gì. Đó là kiểu hỏng tệ nhất ở một hàm tính lương.
--
-- BA ĐIỂM CHẠM, VÀ VÌ SAO CHỈ CÓ BA
--
--   1. Khai biến `truy_linh_tong`.
--   2. Cộng vào `gross`, ngay trước dòng tính gross.
--   3. Ghi một dòng `payslip_items` cho từng khoản, để phiếu lương nói rõ
--      "bù công ngày nào" chứ không phải một cục tiền không tên.
--
-- KHÔNG chạm vào nền đóng bảo hiểm: nền BH là lương ghi trong hợp đồng, không
-- phụ thuộc tháng này trả thêm bao nhiêu. Truy lĩnh CÓ chịu thuế TNCN, và nó
-- tự chịu vì `tn_chiu_thue` tính từ `gross` — không phải sửa gì thêm.
-- =========================================================

do $$
declare
  dn    text;
  truoc text;
begin
  select pg_get_functiondef(p.oid) into dn
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prokind = 'f' and p.proname = 'tinh_luong_ky';

  if dn is null then
    raise exception 'Không tìm thấy tinh_luong_ky() đang chạy.';
  end if;

  if dn like '%truy_linh_tong%' then
    raise notice 'tinh_luong_ky() đã cộng truy lĩnh rồi — bỏ qua.';
    return;
  end if;

  -- ---- 1. Khai biến ----
  truoc := dn;
  dn := replace(
    dn,
    'tien_ot          numeric := 0;',
    'tien_ot          numeric := 0;
      truy_linh_tong   numeric := 0;');
  if dn = truoc then
    raise exception 'Không tìm thấy chỗ khai biến tien_ot. Thân hàm đã đổi hình dạng — đọc lại pg_get_functiondef rồi sửa migration này.';
  end if;

  -- ---- 2. Cộng vào gross ----
  truoc := dn;
  dn := replace(
    dn,
    'gross := luong_theo_cong + phu_cap_tong + tien_ot;',
    '-- Truy lĩnh: công bị sót của một kỳ ĐÃ CHỐT, trả vào kỳ này (P7a).
      -- Cộng mọi dòng của kỳ, mỗi lần tính lại đều cộng đúng như thế — không
      -- có cờ "đã tính", vì cờ ấy sẽ sai ngay lần tính lại thứ hai.
      select coalesce(sum(tl.so_tien), 0) into truy_linh_tong
      from public.truy_linh_luong tl
      where tl.period_id = p_period_id and tl.employee_id = nv.employee_id;

      gross := luong_theo_cong + phu_cap_tong + tien_ot + truy_linh_tong;');
  if dn = truoc then
    raise exception 'Không tìm thấy dòng tính gross. Thân hàm đã đổi hình dạng — đọc lại pg_get_functiondef rồi sửa migration này.';
  end if;

  -- ---- 3. Dòng chi tiết trên phiếu lương ----
  truoc := dn;
  dn := replace(
    dn,
    'so_phieu := so_phieu + 1;',
    'insert into public.payslip_items (payslip_id, item_type, name, amount, is_taxable, is_insurance)
      select phieu_id, ''thuong'',
             ''Truy lĩnh công ngày '' || to_char(tl.ngay_goc, ''DD/MM/YYYY''),
             tl.so_tien, true, false
      from public.truy_linh_luong tl
      where tl.period_id = p_period_id and tl.employee_id = nv.employee_id;

      so_phieu := so_phieu + 1;');
  if dn = truoc then
    raise exception 'Không tìm thấy dòng đếm so_phieu. Thân hàm đã đổi hình dạng — đọc lại pg_get_functiondef rồi sửa migration này.';
  end if;

  execute dn;
end $$;

comment on function public.tinh_luong_ky(uuid) is
  'Tính lương toàn bộ nhân viên của một kỳ. Chỉ chạy khi kỳ đang mở. Chạy lại được nhiều lần. Cộng cả khoản truy lĩnh của kỳ (P7a). Ném lỗi nếu thiếu bất kỳ tham số nào — không bao giờ lặng lẽ tính ra 0.';
