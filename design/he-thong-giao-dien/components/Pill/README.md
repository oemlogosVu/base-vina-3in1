Pill trạng thái: 5 nhóm màu, LUÔN có chấm + chữ — không bao giờ chỉ dựa vào màu; xuống dòng được.

Nguồn: `Pill`, `PillTrangThai` trong `design/tham-chieu-tai-chinh/components-ui/hien-thi.tsx` + `.pill`, `.pill-*`.

| nhom | Nghĩa | Màu |
|---|---|---|
| `xam` | nháp / chưa bắt đầu | nền `xam-nen`, chữ `muc-phu`, chấm `muc-nhat` |
| `vang` | đang chờ ai đó | nền `vang-nen`, chữ `vang-chu`, chấm `vang` |
| `xanh` | xong | nền `xanh-nen`, chữ `xanh-dam`, chấm `xanh` |
| `do` | hỏng / quá hạn / vượt | nền `do-nen`, chữ `do-dam`, chấm `do` |
| `dong` | đã đóng | nền `dong`, chữ trắng, chấm `vien-dam` |

- 12px 700, đệm 4px 11px, bo `bo-tron`, chấm 7px.
- Nhãn rút gọn trên danh sách («Chờ KTT duyệt»), nhãn đầy đủ ở trang chi tiết (`PillTrangThai dayDu`) và trong `title`.
- Nhóm lấy từ hàm trạng thái của từng phân hệ — không tự đặt màu theo cảm tính.

Người dùng cung cấp: `nhom`, `children` (nhãn), `title?`.
