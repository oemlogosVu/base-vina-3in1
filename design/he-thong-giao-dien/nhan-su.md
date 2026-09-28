# Nhân sự

Quy tắc riêng cho phân hệ Nhân sự (`/nhan-su`, `data-phan-he="ns"`, màu nhấn `nhan-ns`). Mọi quy tắc chung của brand book vẫn áp dụng. Mục này chỉ ghi phần Nhân sự khác Tài chính.

## Nhân sự khác Tài chính ở đâu

- **Dữ liệu cá nhân nhạy cảm:** lương, CCCD, số tài khoản, ảnh selfie chấm công, hợp đồng. Kế hoạch gộp xếp rủi ro lộ dữ liệu chéo ở mức Cao. Lỗi giao diện ở đây là lỗi lộ dữ liệu, không chỉ là lỗi thẩm mỹ.
- **Người dùng ở công trường:** đứng ngoài trời, điện thoại cũ, sóng yếu, và thường chấm công thay cho người khác. Phần lớn công nhân không có tài khoản (89 hồ sơ, 4 tài khoản).
- **Dữ liệu dạng lưới:** công người × ngày, bảng lương nhiều cột. Tài chính chủ yếu là danh sách chứng từ.

## Dữ liệu nhạy cảm

- Che mặc định. CCCD và số tài khoản chỉ hiện 4 số cuối (`.gia-tri-an`). Lương và bảo hiểm nằm trong khối `<details>` đóng, có pill «Ẩn».
- Máy chủ quyết định trả giá trị đầy đủ hay đã che, theo quyền của người xem. Giao diện không nhận số đầy đủ rồi tự che.
- Mỗi lần xem đầy đủ đều ghi nhật ký truy cập. Giao diện ghi một dòng cho người dùng biết điều đó.
- Lương **không bao giờ** xuất hiện ở «Việc chờ tôi», ở danh sách nhân viên, ở huy hiệu, ở thông báo hay tin Telegram. Chỉ ghi «Kỳ lương tháng 09 chờ bạn duyệt».
- Ảnh selfie chỉ người duyệt công xem, hiện dạng thu nhỏ `.anh-nho`, không dùng làm ảnh đại diện. Ghi rõ «tự xoá sau 90 ngày».
- Nhân viên chỉ thấy dữ liệu của chính mình: «Chấm công của tôi», «Phiếu lương của tôi».

## Màn cho công trường

- Mỗi màn một việc chính, một nút chính cao 48–56px (`.nut-cham`). Chữ thân 16px, không chữ xám nhạt (`muc-mo`) cho thông tin cần đọc dưới nắng.
- Chụp ảnh bằng `<input type="file" capture>` gốc, không dùng camera trực tiếp. Nén ảnh trước khi gửi.
- Giờ chấm là giờ máy chủ. Chỉ báo thành công khi máy chủ đã nhận; mất mạng thì báo lỗi rõ và cho chụp lại.
- Chấm công tổ đội: mặc định mọi người 1 công, chỉ huy chỉ sửa người vắng hoặc nửa công. Ô chọn 1 · ½ · 0 là radio gốc `.chon-cong`, mỗi ô ≥ 46×44px.
- Không có thao tác vuốt, kéo thả hay nhấn giữ. Mọi thao tác đều là một lần chạm.

## Trạng thái công và hợp đồng

| Nghĩa | Pill | Ví dụ nhãn |
|---|---|---|
| Đủ công, đã xác nhận | `xanh` | Đủ công · Đã xác nhận |
| Đang diễn ra, chờ người khác | `vang` | Đang làm · Muộn 18 phút · Chờ chỉ huy xác nhận · Còn 15 ngày |
| Thiếu, vắng, quá hạn | `do` | Thiếu chấm · Vắng không phép · Hợp đồng quá hạn |
| Nghỉ hợp lệ, chưa bắt đầu | `xam` | Nghỉ tuần · Nghỉ phép · Chưa chấm vào |
| Kỳ đã khóa | `dong` | Đã chốt |

- Trong lưới công: `1` màu `muc`, `½` màu `vang-chu`, `0` màu `do`, `—` màu `muc-mo`. Chủ nhật tô nền `xam-nen`. Luôn có dòng chú giải dưới bảng.
- Hợp đồng còn ≤ 30 ngày: pill vàng «Còn N ngày» và thông báo vàng trên đầu hồ sơ. Quá hạn thì chuyển sang đỏ.

## Điều hướng

- Thanh bên máy tính, 3 nhóm: **Con người** (Hồ sơ nhân viên, Hợp đồng) · **Chấm công** (Chấm công của tôi, Tổ đội) · **Lương** (Kỳ lương, Phiếu lương của tôi).
- Thanh tab điện thoại theo vai trò:
  - Nhân viên: Việc chờ · Chấm công · Phiếu lương · Thêm.
  - Chỉ huy: thêm Tổ đội.
  - HCNS và KTT: Chấm công · Tổ đội · Hồ sơ · Kỳ lương · Thêm.
- Đưa lên «Việc chờ tôi»:
  - Bảng công tổ đội chờ xác nhận.
  - Hợp đồng sắp hết hạn.
  - Kỳ lương chờ duyệt (không kèm số tiền).
  - Ngày thiếu chấm công của chính tôi.

## Chuyển app Nhân sự cũ sang

- Đổi màu chàm (indigo) sang token. Chữ nhấn dùng `nhan-ns`; nút chính, link và vòng focus vẫn dùng `navy` và `tieu-diem` như cả app. Màu nhấn phân hệ không thay màu nút chính.
- Đổi font hệ thống sang Be Vietnam Pro. Thanh bên 240px đổi thành 248px, dùng `.thanh-ben`.
- Mọi modal, popup, `confirm()` hay dropdown tự vẽ của app cũ (nếu có) thay bằng `KhoiXacNhan`, `<details>` và ô gốc.
- Kiểm tra từng màn ở khổ 360px và 1280px. App Nhân sự chưa được test tay đủ 11 phase, nên nghiệm thu giao diện làm cùng lúc với test tay ở giai đoạn 2.
- Không đổi công thức lương, bảo hiểm, thuế. Giao diện chỉ hiển thị số từ máy chủ; tham số lấy từ `cfg_*`.
