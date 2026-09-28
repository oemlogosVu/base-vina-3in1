# Tham chiếu giao diện — app Tài chính (chuẩn cho app 3 trong 1)

Chép nguyên từ repo Finance Manager Base V3, nhánh production `main` (commit `992cdd7`, KT-71).
Đây là **tài liệu tham chiếu**, không phải code chạy của app mới: không import, không build từ thư mục này.

| File | Nội dung |
|---|---|
| `globals.css` | Token màu (navy `#1f3a5c`…), cỡ chữ, khoảng cách, class dùng chung — **nguồn chuẩn** của bộ giao diện |
| `layout-goc.tsx` | Nạp font Be Vietnam Pro (`next/font`, biến `--font-be-vietnam`) |
| `layout-ung-dung.tsx` + `dieu-huong.tsx` | Khung: sidebar máy tính, đầu trang + tab bar dưới trên điện thoại, huy hiệu số việc chờ |
| `components-ui/` | Nút, ô nhập, ô nhập tiền, khối xác nhận (thay modal), hiển thị trạng thái, bộ biểu tượng SVG |
| `icons/` | Biểu tượng app (PWA) 192/512 |
| `font/` | Be Vietnam Pro Regular/Bold (giấy phép SIL OFL) — dùng cho PDF |
| `thiet-ke-dot-1.dc.html` | Bản thiết kế HTML đợt trước của Tài chính (mở bằng trình duyệt). Email mẫu đã thay bằng địa chỉ giả |

Cách dùng khi thiết kế app 3 trong 1:
- Giữ nguyên tinh thần của Tài chính (màu, font, khoảng cách, cách hiển thị số tiền, khối xác nhận thay modal),
  mở rộng thêm: bộ chọn phân hệ, màu nhấn cho Nhân sự / Kho / Hệ thống, trang chủ «Việc chờ tôi».
- Không có logo công ty trong repo cũ. Tạm dùng chữ «Base Vina» — tên hiển thị và logo CHƯA CHỐT.
