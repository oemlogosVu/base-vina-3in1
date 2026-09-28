Màn chấm công cá nhân bằng ảnh selfie trên điện thoại. Một màn có một việc: một nút to, giờ máy chủ, trạng thái hôm nay, và tuần công của tôi.

Thiết kế mới cho phân hệ Nhân sự. Nghiệp vụ theo mô tả HRM trong `docs/KE_HOACH_GOP_3_TRONG_1.md` (chấm công cá nhân bằng selfie, bucket `attendance-selfies`, xoá ảnh sau 90 ngày, tổng hợp công lúc 00:15). Class mới: `.dong-ho`, `.nut-cham`, `.anh-nho`, `.dong-ngay` (bundle.css phần 4).

- Chụp ảnh bằng `<input type="file" accept="image/*" capture="user">` gốc, bọc trong nút chính `.nut .nut-cham` cao 56. KHÔNG dùng camera trực tiếp (`getUserMedia`), vì trình duyệt Android cũ hay lỗi quyền camera và màn đen.
- Nén ảnh trước khi gửi (cạnh dài ≤ 1024px, JPEG ~0.7) để gửi được khi sóng yếu ở công trường.
- Giờ hiển thị và giờ ghi nhận là **giờ máy chủ**, không lấy giờ điện thoại. Ghi rõ «Giờ máy chủ».
- Chỉ báo «Đã chấm» khi máy chủ đã nhận xong. Mất mạng thì hiện `ThongBao` lỗi và giữ nút để chụp lại; không lưu tạm rồi báo thành công giả.
- Trong lúc gửi: nút ở trạng thái đang xử lý «Đang gửi ảnh…», khóa bấm lần hai.
- Trạng thái ngày luôn là pill có chữ: `xanh` Đủ công · `vang` Đang làm / Muộn N phút · `do` Thiếu chấm / Vắng không phép · `xam` Nghỉ tuần / Nghỉ phép / Chưa chấm.
- Ghi một dòng về ảnh: ai xem được và bao lâu thì xoá.
- Thanh tab Nhân sự hiện theo vai trò. Nhân viên thấy Việc chờ · Chấm công · Phiếu lương · Thêm (như bản này). Chỉ huy thấy thêm Tổ đội. HCNS và KTT thấy Chấm công · Tổ đội · Hồ sơ · Kỳ lương · Thêm.

Người dùng cung cấp: người đăng nhập, trạng thái hôm nay (vào/ra, giờ), danh sách 7 ngày gần nhất, hàm gửi ảnh.
