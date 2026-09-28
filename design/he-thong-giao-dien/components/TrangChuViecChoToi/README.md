Trang chủ tổng «Việc chờ tôi» (`/`): gộp việc đang chờ chính người đăng nhập từ cả 3 phân hệ, mỗi phân hệ một thẻ nhóm.

Chưa có trong code. Dựng từ Trang chủ «Việc cần làm» của Tài chính (`.dong-viec`, `.o-bieu-tuong`, `.dem`, `thiet-ke-dot-1.dc.html` màn 3) + `.dau-nhom-viec`, `.o-bieu-tuong-nhan` (bundle.css phần 3).

- Đầu trang máy tính: «Chào chị Bình» (`tieu-de-trang`) + «Thứ, ngày · N việc chờ bạn ở M phân hệ» (`muc-nhat`). Điện thoại: đầu trang navy «Việc chờ tôi».
- Thứ tự thẻ cố định: Tài chính → Nhân sự → Kho → Hệ thống; máy tính lưới 2 cột, điện thoại 1 cột. Phân hệ hết việc hoặc không có quyền: ẩn thẻ.
- Đầu thẻ: ô chữ tắt màu nhấn · tên phân hệ · «n việc». Dòng việc (`.dong-viec`, ≥ 64px): việc gì · «bao nhiêu · chi tiết» · tổng tiền nếu có (dòng riêng, 17/700 — to nhất dòng) · số đếm · mũi tên.
- Màu dòng: gấp/quá hạn/bị trả về → ô biểu tượng `o-bieu-tuong-do` + số đếm `dem-do`, đứng ĐẦU thẻ; việc thường → ô tint màu nhấn phân hệ (`nhan-*-nen`) + số đếm `dem-vang`. Dòng bằng 0 ẩn hẳn; hết mọi việc → `TrangThaiTrong`.
- Mỗi dòng dẫn thẳng tới danh sách đã lọc sẵn trong phân hệ (vd `/tai-chinh/duyet`).
- Điện thoại: thanh tab ở trang chủ = Việc chờ · các phân hệ được phép (ô chữ tắt 24px) · Thêm; vào trong phân hệ thì thanh tab là tab riêng của phân hệ đó.
- Tiền và quyền tính ở DB/server — trang chủ chỉ ĐỌC số đếm từ từng phân hệ, không tự tính lại.

Người dùng cung cấp: người đăng nhập, danh sách phân hệ được phép, từng dòng việc {phân hệ, loại, số lượng, tổng tiền?, gấp?, link}.
