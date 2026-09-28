Thẻ: LUÔN nền `giay`, viền 1px `vien`, bo `bo-14`, không bóng — khối chứa cơ bản của mọi màn điện thoại.

Nguồn: `The` trong `design/tham-chieu-tai-chinh/components-ui/hien-thi.tsx` + `.the`.

- Ruột 16px (`dem`, mặc định bật); tắt khi bên trong là bảng hoặc danh sách dòng (dòng tự có đệm 14px).
- Giữa hai thẻ 12px; giữa hai khối 24px.
- Điện thoại dùng thẻ, máy tính dùng `Bang` cho danh sách nhiều dòng. Thẻ đề nghị: dòng 1 số chứng từ (`so-ct`) + ngày; dòng 2 diễn giải; dòng 3 pill + tiền (to nhất).
- Thẻ đang được chọn: thêm `.the-chon` (viền 1.5px `navy`).

Người dùng cung cấp: `children`, `dem?`, props của `<div>`.
