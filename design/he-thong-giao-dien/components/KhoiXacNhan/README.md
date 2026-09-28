Khối xác nhận tại chỗ — mở ngay dưới nút vừa bấm, không che nội dung; app KHÔNG có popup nào.

Nguồn: `design/tham-chieu-tai-chinh/components-ui/khoi-xac-nhan.tsx` + `.khoi-xac-nhan`, `.khoi-xac-nhan-do`.

- Cấu trúc: câu hỏi (`.cau-hoi`, 16/700) → MỘT dòng hệ quả (`.he-qua`, 14px `muc-phu`, nêu số mục · số tiền · ai nhận lại) → ô lý do nếu cần → lỗi (`ThongBao` lỗi) → hai nút: xác nhận (`flex:1`) + «Thôi» (`nut-phu`).
- `loai="do"` cho việc phá hủy (từ chối, hủy, xóa, khóa tài khoản): nền `do-nen`, viền `do-vien`, câu hỏi `do-dam`, nút xác nhận `do-dac`. Loại thường: nền `nen`, viền `vien-dam`, nút `chinh`.
- Màn gọi tự giữ trạng thái mở/đóng; khi khối mở thì vô hiệu nút hành động đối lập (mở «Từ chối» thì khóa «Duyệt đợt»).
- Không truyền `onXacNhan` ⇒ nút xác nhận là `submit`: đặt khối trong `<form action>` để gửi thẳng server action.
- Quy tắc cứng: phân hệ Tài chính KHÔNG dùng modal. Đề xuất áp cho cả 3 phân hệ.

Người dùng cung cấp: `cauHoi`, `heQua?`, `nhanXacNhan`, `onThoi`, `onXacNhan?`, `dangXuLy?`, `loi?`, `loai?`, `children?` (ô lý do).
