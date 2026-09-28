Nút bấm của app — 5 biến thể, cao ≥ 44px, bo `bo-12`, chữ 700; mỗi màn chỉ MỘT nút chính.

Nguồn: `design/tham-chieu-tai-chinh/components-ui/nut.tsx` (`Nut`, `NutLink`, `lopNut`) + class `.nut*` trong `globals.css`.

| bienThe | class | Dùng khi |
|---|---|---|
| `chinh` | `.nut` — cao 48, nền `navy`, chữ trắng, 16px | Hành động chính của màn (Gửi duyệt, Lập đề nghị). |
| `phu` | `.nut-phu` — viền `vien-dam`, chữ `navy` | Hành động phụ (Lưu nháp, Tải PDF). |
| `nguy-hiem` | `.nut-do` — viền `do-vien`, chữ `do` | Từ chối, Hủy, Xóa — bước đầu, mở `KhoiXacNhan`. |
| `chu` | `.nut-chu` — không viền, không nền | Thôi, Xem thêm. |
| `do-dac` | `.nut-do-dac` — nền `do`, chữ trắng | CHỈ nút xác nhận cuối trong `KhoiXacNhan` loại đỏ. |

- Cỡ `nho` (`.nut-nho`, 36px) chỉ dùng trên máy tính; điện thoại luôn ≥ 44px.
- `dangXuLy`: hiện vòng `.xoay` + chữ «Đang gửi…», khóa nút chống bấm hai lần; giữ màu đậm (`aria-busy`), không mờ như vô hiệu.
- Biểu tượng (prop `bieuTuong`) cỡ 20, đứng trước chữ; không bao giờ nút chỉ có biểu tượng mà không có chữ.
- Không bao giờ chữ trắng trên nền vàng (`vang` chỉ 3.7:1).
- `NutLink` = thẻ link trông như nút (chuyển trang); `lopNut()` trả class cho thẻ khác (vd `<a download>`).

Người dùng cung cấp: `children` (chữ nút), `bienThe`, `co`, `bieuTuong?`, `dangXuLy?`, `nhanDangXuLy?`, mọi prop của `<button>`.
