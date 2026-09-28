Bảng — CHỈ dùng trên máy tính (điện thoại dùng `The`); bọc trong thẻ có cuộn ngang.

Nguồn: `Bang` trong `design/tham-chieu-tai-chinh/components-ui/hien-thi.tsx` + `.bang`, `.bang-gon`, `.cot-tien`, `.dong-tong`, `.cat-chu`, `.dong-chon`.

- Đầu cột: nền `xam-nen`, 12px 700 viết hoa, `muc-phu`. Ô: đệm 12px 14px, kẻ trên `xam-nen`; hàng chẵn nền `nen`.
- Ô tiền `<td class="cot-tien">`: căn phải, 16/700, tabular-nums, không xuống dòng. Dòng tổng `<tr class="dong-tong">`: nền `xam-nen`, tiền 19px.
- Bảng nhiều cột (sao kê): `gon` → `.bang-gon` (`table-layout: fixed` + `<colgroup>` bắt buộc) để không phải trượt ngang; chữ dài cắt bằng `.cat-chu` — KHÔNG BAO GIỜ cắt cột tiền.
- Dòng đang chọn: `tr.dong-chon`. Ô nhập trong bảng: `.o-nhap-nho`.

Người dùng cung cấp: `nhan` (aria-label), `gon?`, `<thead>/<tbody>` làm `children`.
