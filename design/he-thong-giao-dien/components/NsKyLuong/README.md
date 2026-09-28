Màn kỳ lương trên máy tính. Người xem thấy ngay kỳ đang ở bước nào, tổng tiền bao nhiêu, ai đang giữ việc, rồi duyệt và chốt tại chỗ. Chốt xong thì đẩy sang Tài chính thành đề nghị chi lương.

Thiết kế mới. Nghiệp vụ theo mô tả HRM (tính lương, BHXH, thuế TNCN, phiếu lương, chứng từ PDF) và luồng «Nhân sự → Tài chính: kỳ lương đã chốt → đề nghị chi lương» trong kế hoạch gộp. Class mới: `.buoc` (bundle.css phần 4).

- Đầu trang: tên kỳ, pill trạng thái, dãy bước `.buoc` (đã xong `xanh`, bước hiện tại nền `nhan-ns`, bước sau `xam-nen`). Luồng: Tổng hợp công → HCNS lập bảng → KTT duyệt → Chốt kỳ → Đề nghị chi lương (Tài chính).
- Ba ô số liệu: tổng thực lĩnh (kèm số người), bảo hiểm người lao động (tiền ra, đỏ), chênh so với kỳ trước.
- Bảng lương dùng `Bang` gọn, cố định cột: Nhân viên (tên + mã NV · chức danh) · Công · Lương theo công · Phụ cấp · BH NLĐ (đỏ) · Thực lĩnh (đậm, to nhất). Có ô tìm kiếm và lọc theo phòng ban, có dòng cộng cho phần đang lọc. Trên điện thoại mỗi người là một thẻ và không hiện cột chi tiết.
- Duyệt ở khung bên phải, dùng `KhoiXacNhan` tại chỗ. Hệ quả phải ghi số người, tổng tiền, «không sửa được nữa» và «tạo đề nghị chi lương bên Tài chính». Trả về HCNS là khối đỏ, bắt buộc ghi lý do.
- **Quyền xem lương:** chỉ HCNS, KTT, Chủ tịch. Nhân viên chỉ thấy «Phiếu lương của tôi». Lương không bao giờ hiện ở «Việc chờ tôi», ở danh sách nhân viên, hay ở thông báo Telegram; chỉ ghi «Kỳ lương tháng 09 chờ bạn duyệt».
- Không viết lại công thức: tỷ lệ bảo hiểm và thuế lấy từ `cfg_*`, tiền là `numeric`. Giao diện chỉ hiển thị.

Người dùng cung cấp: kỳ lương {tháng, công ty, trạng thái, bước}, tổng số, danh sách dòng lương, quyền của người xem, hàm duyệt, chốt, trả về.
