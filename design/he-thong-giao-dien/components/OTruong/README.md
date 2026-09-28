Một ô trong form: nhãn trên, ô ở giữa, gợi ý HOẶC lỗi dưới — bên trong luôn là ô GỐC của trình duyệt.

Nguồn: `design/tham-chieu-tai-chinh/components-ui/o-truong.tsx` (`OTruong`, `KhungTep`) + `.nhan-o`, `.o-nhap`, `.goi-y`, `.dong-loi`, `.khung-tep`, `.mo-rong`.

- Ô `<input>`, `<select>`, `<textarea>`, `type="date"` gốc mang class `.o-nhap` (cao 48, bo `bo-10`, viền `vien-dam`, chữ 16px). KHÔNG thay bằng dropdown hay lịch tự vẽ — máy Android cũ vỡ giao diện.
- Trong bảng máy tính dùng thêm `.o-nhap-nho` (cao 40, bo `bo-8`, 15px).
- Bắt buộc: `*` màu `do` (`.dau-bat-buoc`) sau nhãn.
- Lỗi: đặt `aria-invalid="true"` trên ô (viền 1.5px `do`) và hiện `.dong-loi` (biểu tượng `warn` 15 + chữ `do` 600) THAY cho gợi ý.
- Gợi ý tối đa MỘT dòng ngắn (`.goi-y`, 13px `muc-nhat`); giải thích dài vào `chiTiet` → dòng «Giải thích» mở tại chỗ bằng `<details>` — không tooltip, không popup.
- Focus: viền `tieu-diem` + vòng focus chung.
- `KhungTep` bọc `<input type="file">` gốc: nền `nen`, viền đứt, biểu tượng `clip`.

Người dùng cung cấp: `nhan`, `htmlFor`, `batBuoc?`, `goiY?`, `loi?`, `chiTiet?`, và ô gốc làm `children`.
