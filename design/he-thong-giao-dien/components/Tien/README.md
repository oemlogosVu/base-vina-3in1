Hiển thị số tiền: chữ số đều cột (tabular-nums), định dạng `1.000.000 đ`, không số lẻ.

Nguồn: `Tien` trong `design/tham-chieu-tai-chinh/components-ui/hien-thi.tsx` + `.tien`, `.tien-vao`, `.tien-ra`; quy tắc định dạng trong `thiet-ke-dot-1.dc.html`.

- `loai="vao"` → «+ … đ» màu `xanh`; `loai="ra"` → «− … đ» màu `do` (dấu trừ thật «−»). Trống → «—».
- `khongDonVi` bỏ chữ «đ» — dùng trong cột tiền của bảng (đầu cột đã ghi đơn vị).
- Số tiền là chữ TO NHẤT trên mỗi dòng/thẻ (style `tien` 20/700).
- Ngày `14/09/2026` · thời điểm `14/09/2026 15:42` · kỳ `Tháng 09/2026` · số chứng từ `DNTU-BV-2026-0016` (font `mono`, style `so-ct`).

Người dùng cung cấp: `giaTri`, `loai?`, `khongDonVi?`.
