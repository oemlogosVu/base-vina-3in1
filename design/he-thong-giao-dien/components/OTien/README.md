Ô nhập tiền: hiện 1.000.000 khi gõ, giá trị thật vẫn là số nguyên — tránh gõ thừa/thiếu một số 0.

Nguồn: `design/tham-chieu-tai-chinh/components-ui/o-tien.tsx` (`OTien`, `chamNghin`) + `.o-tien-khung`, `.o-tien`, `.hau-to`, `.o-giam`.

- `<input type="text" inputMode="numeric">` class `.o-nhap .o-tien`: số căn PHẢI, 18px 700, tabular-nums; hậu tố «đ» (`muc-nhat`) đứng yên bên phải.
- Chấm ngăn nghìn bằng regex `\B(?=(\d{3})+(?!\d))` → «.», KHÔNG dùng `toLocaleString` (lệch giữa máy chủ và trình duyệt cũ). Bỏ mọi ký tự không phải số; tối đa 15 chữ số.
- `name` → kèm `<input type="hidden">` mang số trơn để form gửi thẳng server action.
- `canhBao` (`.o-giam`): viền 1.5px `vang` khi số bị sửa khác số gốc (KTT duyệt thấp hơn đề nghị).
- `nho`: ô 40px trong bảng máy tính.
- Tiền là `numeric` ở DB, không float; không số lẻ.

Người dùng cung cấp: `giaTri` (số), `onDoi(so)`, `id?`, `name?`, `loi?`, `canhBao?`, `nho?`, `disabled?`.
