# Nguồn của thư mục này

Bản sao cố định của bộ giao diện chuẩn «Base Vina 3 in 1» do Claude Design dựng trên claude.ai:
https://claude.ai/artifact/Q7QcpDAXw17AZHoagjcqST — phiên bản `1790570181-4e74`, chép ngày 28/09/2026.

- Chỉ chép phần nội dung `project/` (hướng dẫn, `tokens.json`, `components/bundle.css`, bản xem trước HTML).
  Font nằm ở `design/tham-chieu-tai-chinh/font/`; biểu tượng SVG nằm trong `bieu-tuong.tsx` ở đó.
- Đây là TÀI LIỆU THAM CHIẾU, không build, không import trực tiếp. Khi dựng app: chép class cần dùng vào
  `src/`, ghi màu bằng HEX cố định (quy tắc Android cũ, xem `README.md` mục Màu).
- Bộ trên claude.ai đổi → chép lại thư mục này thành một commit riêng, ghi phiên bản mới ở đây.

## Quyết định của chủ dự án về bộ giao diện (28/09/2026)

1. Màu nhấn phương án B: Tài chính navy `#1f3a5c` · Nhân sự tím `#6b3589` · Kho `#0a6379` · Hệ thống `#5a5048`.
2. «Không modal» BẮT BUỘC cho Tài chính và khung chung/trang chủ/Hệ thống. Nhân sự và Kho GIỮ hộp thoại
   hiện có ở giai đoạn 1–6; đổi sang khối xác nhận tại chỗ ở giai đoạn 7.
3. Các màn Nhân sự trong bộ này (`NsChamCongCaNhan`, `NsChamCongToDoi`, `NsKyLuong`, `NsHoSo`, `nhan-su.md`)
   là THIẾT KẾ MỚI, chưa đối chiếu app Nhân sự thật. Giai đoạn 2 chép app Nhân sự cũ, chỉ đổi màu/font.
   Tính năng mới trong đó (che CCCD/số tài khoản ở máy chủ, nhật ký mỗi lần xem dữ liệu nhạy cảm,
   mặc định 1 công khi chấm tổ đội, không dùng selfie làm ảnh đại diện…) để danh sách riêng, duyệt từng mục sau GĐ6.
4. Luồng kỳ lương → đề nghị chi lương bên Tài chính: làm sau theo kế hoạch mục 3.6, không làm trong GĐ1–6.
