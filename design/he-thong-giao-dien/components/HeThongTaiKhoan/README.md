Màn «Hệ thống → Tài khoản» (`/he-thong/tai-khoan`): một chỗ tạo, khóa, đặt lại mật khẩu và bật phân hệ cho từng người; gộp `tao-tai-khoan` (Tài chính) + `quan-tri-tai-khoan` (Nhân sự).

Chưa có trong code. Dựng từ `Bang`, `Chip`, `.o-tim`, `Pill`, `KhoiXacNhan`, `Nut`, `.o-tich` của Tài chính + `.pill-phan-he`, `.dai-nhan` (bundle.css phần 3). Phân hệ Hệ thống: `data-phan-he="ht"`.

- Máy tính: danh sách (trái) + khung chi tiết tài khoản đang chọn (phải, 340px, dính `.cot-dinh`). Điện thoại: danh sách dạng thẻ, bấm vào mở trang chi tiết riêng — không popup.
- Cột: Người dùng (tên 600 + email hoặc SĐT; SĐT hiển thị `0912 345 678`, lưu `<số>@sodienthoai.local`) · Phân hệ (pill màu nhấn TC / NS / KHO — luôn có chữ) · Trạng thái (`xanh` Đang dùng · `xam` Chưa đăng nhập · `dong` Đã khóa). Lần đăng nhập gần nhất, ngày tạo: trong khung chi tiết (`.dong-tt`).
- Lọc: ô tìm + chip Tất cả / Đang dùng / Đã khóa / Chưa đăng nhập (có số).
- «Phân hệ được dùng»: ô tích 22px gốc + ô chữ tắt + dòng phụ vai trò bên trong phân hệ. Vai trò chi tiết do TỪNG phân hệ quản lý (giai đoạn 1–6) — màn này chỉ bật/tắt quyền vào.
- Khóa tài khoản: `nut-do` → `KhoiXacNhan` đỏ tại chỗ, hệ quả ghi rõ «không đăng nhập được vào cả 3 phân hệ; chứng từ đã lập giữ nguyên», bắt buộc lý do. Không xoá tài khoản (sổ chỉ ghi thêm). Đặt lại mật khẩu: `KhoiXacNhan` thường, hiện mật khẩu tạm MỘT lần.
- Quyền thực thi ở Edge Function/DB (chỉ quản trị); ẩn màn với người khác không phải là phân quyền.

Người dùng cung cấp: danh sách tài khoản {tên, đăng nhập, phân hệ, trạng thái, lần đăng nhập cuối}, tài khoản đang chọn, hàm lưu/khóa/đặt lại mật khẩu.
