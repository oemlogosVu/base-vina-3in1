Danh sách rỗng: viền đứt `vien-dam`, biểu tượng 26px `muc-mo`, một dòng chính + dòng phụ, có thể kèm nút bước tiếp.

Nguồn: `TrangThaiTrong` trong `design/tham-chieu-tai-chinh/components-ui/hien-thi.tsx` + `.trang-thai-trong`.

- Dòng chính 15/600 `muc` nói rõ cái gì trống («Không có đề nghị nào»); dòng phụ 13px `muc-nhat` nói phạm vi (kỳ, bộ lọc).
- Khi hết việc, đưa nút gợi ý bước tiếp («Lập đề nghị»). Trang chủ: dòng việc bằng 0 thì ẩn hẳn; hết mọi việc mới hiện trạng thái trống.

Người dùng cung cấp: `chinh`, `phu?`, `bieuTuong?` (mặc định `file`), `children?` (nút).
