Thông báo sau thao tác: thành công (xanh, `role="status"`) hoặc lỗi (đỏ, `role="alert"`).

Nguồn: `ThongBao` trong `design/tham-chieu-tai-chinh/components-ui/hien-thi.tsx` + `.thong-bao*`.

- Xanh: nền `xanh-nen`, viền `xanh-vien`, chữ `xanh-dam`, biểu tượng `check` màu `xanh`. Đỏ: nền `do-nen`, viền `do-vien`, chữ `do-dam`, biểu tượng `warn` màu `do`.
- Tiêu đề in đậm ngắn («Đã gửi duyệt.») + một câu chi tiết (số phiếu, lý do cụ thể). 14px, bo `bo-12`.
- Không toast tự biến mất; đặt tại chỗ, ngay trên/dưới vùng vừa thao tác.

Người dùng cung cấp: `loai` ("thanh-cong" | "loi"), `tieuDe?`, `children`.
