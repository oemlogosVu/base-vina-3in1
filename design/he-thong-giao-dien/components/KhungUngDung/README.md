Khung chung mọi trang cần đăng nhập: máy tính (≥ 1024px) = thanh trên navy 56px + thanh bên 248px chia nhóm; điện thoại = đầu trang navy + thanh 5 tab dán đáy.

Nguồn: `design/tham-chieu-tai-chinh/layout-ung-dung.tsx`, `dieu-huong.tsx` (`DauTrangDienThoai`, `ThanhTabDuoi`, `ThanhBen`), `layout-goc.tsx`; class `.thanh-tren`, `.thanh-ben`, `.muc-ben`, `.nhan-nhom-ben`, `.huy-hieu`, `.dau-trang`, `.thanh-tab`, `.tab-duoi`, `.noi-dung`, `.logo-tc`, `.logo-lon`, `.nut-noi`, `.phien-ban`.

- Máy tính: `.thanh-tren` dính (logo · tên app · «Tên · Vai trò» · Đăng xuất `.nut-tren-nen-toi`); `.thanh-ben` dính dưới 56px, nhóm (Công việc · Tiền · Báo cáo · Thiết lập · Tài khoản), mục `.muc-ben` cao 44, đang chọn nền `navy` chữ trắng; dấu phiên bản mono ở chân.
- Điện thoại: `.dau-trang` (tên trang + «Tên · Vai trò»); `.thanh-tab` tối đa 4 tab + «Thêm» (mở trang riêng, không popup); tab đang chọn chữ `navy` 700 + gạch 20×3 — không chỉ dựa vào màu. Nội dung chừa đáy `92px + safe-area`.
- Huy hiệu số việc chờ `.huy-hieu`: nền `vang-chu` (KHÔNG `vang`), gấp `.huy-hieu-gap` nền `do`; >99 hiện «99+»; kèm chữ ẩn «việc đang chờ».
- Vùng nội dung `.noi-dung`: trang cũ cột 768px; trang dựng lại gắn `.rong`. Lề 16px điện thoại, 32px máy tính.
- Menu theo vai trò người dùng (quyền thực thi ở DB, ẩn mục không phải phân quyền). Nút nổi `.nut-noi` («Lập đề nghị») đứng trên thanh tab.
- 3 trong 1: thêm `BoChonPhanHe` ở đầu thanh bên + `data-phan-he` trên khung (xem thẻ đó).
