Dòng bấm được trong thẻ danh sách: việc cần làm (`.dong-viec`), dòng nhãn–tiền (`.dong-ds`), và thẻ việc máy tính (`.the-viec`).

Nguồn: `design/tham-chieu-tai-chinh/globals.css` (`.dong-viec`, `.dong-ds`, `.dong-tong-ds`, `.the-viec`, `.o-bieu-tuong*`, `.dem*`) và màn Trang chủ trong `thiet-ke-dot-1.dc.html`.

- `.dong-viec` cao ≥ 64px: ô biểu tượng 38px nền tint (`o-bieu-tuong-do` quá hạn/bị trả về, `-vang` đang chờ, `-xanh` xong) · việc gì · «n mục · tổng tiền» · số đếm tròn `.dem` · mũi tên `right` màu `muc-mo`.
- Số đếm vàng dùng `vang-chu` (chữ trắng đủ tương phản), đỏ dùng `do`. Dòng nào bằng 0 thì ẩn hẳn.
- `.dong-ds` cao ≥ 48px: nhãn trái, tiền phải; dòng tổng `.dong-tong-ds` nền `nen` 700.
- Máy tính: `.the .the-viec` xếp lưới 3 cột; tiền là chữ to nhất.
- Các dòng cách nhau bằng kẻ `xam-nen`; hover nền `nen`.

Người dùng cung cấp: link đích, biểu tượng, tiêu đề, dòng phụ (số mục · tiền), số đếm.
