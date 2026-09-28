Hồ sơ một nhân viên trên điện thoại. Việc cần làm ngay (hợp đồng sắp hết hạn) đặt trên cùng. Thông tin liên hệ và công tác hiện sẵn. Dữ liệu nhạy cảm bị che, các phần dài mở tại chỗ.

Thiết kế mới. Nghiệp vụ: hồ sơ, hợp đồng, giấy tờ, tài khoản nhận lương (HRM). Rủi ro «lộ dữ liệu chéo (lương, CCCD, chứng từ)» được ghi mức Cao trong kế hoạch gộp. Class mới: `.gia-tri-an` (bundle.css phần 4).

- Đầu hồ sơ: ô chữ tắt tên, tròn, nền `nhan-ns` (không dùng ảnh selfie chấm công làm ảnh đại diện) · họ tên · mã NV (`so-ct`) · chức danh · công ty.
- Cảnh báo hợp đồng: còn ≤ 30 ngày thì dùng thông báo vàng «Hợp đồng còn N ngày», quá hạn thì dùng thông báo đỏ. Việc gia hạn nằm ngay trong khối Hợp đồng.
- **Che mặc định:** CCCD chỉ hiện 4 số cuối, số tài khoản chỉ hiện 4 số cuối cùng tên ngân hàng; lương và bảo hiểm nằm trong khối đóng có pill «Ẩn». Chỉ người có quyền mới mở được, và mỗi lần mở đều ghi nhật ký. Ghi một dòng cho người dùng biết điều đó.
- Hợp đồng, Lương và bảo hiểm, Giấy tờ là `.khoi-phu` (`<details>` gốc). Không làm tab tự vẽ, không popup.
- Máy tính: hai cột. Cột trái là thẻ thông tin cùng các khối, cột phải là lịch sử (hợp đồng, điều chuyển, thay đổi lương) dạng `DongThoiGian`.
- Danh sách nhân viên (màn trước đó): thẻ trên điện thoại, `Bang` trên máy tính. Cột: Mã · Họ tên · Phòng ban · Công trình · Hợp đồng (pill hạn). **Không có cột lương.**

Người dùng cung cấp: hồ sơ {mã, tên, chức danh, công ty, liên hệ, phòng ban, công trình}, giá trị đã che từ máy chủ (máy chủ chỉ trả 4 số cuối khi người xem không có quyền), hợp đồng hiện hành, quyền xem.
