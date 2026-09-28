Bộ giao diện chung của app Base Vina 3 in 1 — một lần đăng nhập, ba phân hệ Tài chính · Nhân sự · Kho, cộng phân hệ Hệ thống cho quản trị. Chuẩn gốc là giao diện app Tài chính đang chạy thật. Phần mở rộng cho 3 trong 1 là thiết kế mới; màu nhấn đã chốt. Quy tắc riêng của Nhân sự nằm ở mục «Nhân sự».

## Người dùng và bối cảnh

- Người dùng chính là Chủ tịch, Kế toán trưởng, kế toán, chỉ huy công trường, thủ kho của Base Vina và Thái Hà. Chủ tịch và KTT duyệt trên **điện thoại Android cũ**: mọi quyết định giao diện phải chạy tốt trên máy đó trước.
- Dựng cho điện thoại 360–390px trước, rồi máy tính 1280px. Kiểm cả hai khổ.

## Giọng văn

- Toàn bộ chữ trên giao diện, thông báo lỗi, chú thích nghiệp vụ: **tiếng Việt**, câu ngắn, xưng «bạn». Lời chào trang chủ theo danh xưng: «Chào chị Bình».
- Gọi đúng việc và hệ quả, có số: «7 mục · 186.500.000 đ sẽ quay lại Kế toán trưởng.», «Người nhận ứng đang có khoản quá hạn 12 ngày.»
- Nhãn ngắn trên danh sách, nhãn đầy đủ ở trang chi tiết: «Chờ KTT duyệt» / «Chờ Kế toán trưởng duyệt». Giữ nguyên thuật ngữ kế toán (Đề nghị thanh toán, tạm ứng, quyết toán).
- Không emoji, không dấu chấm than, không chữ giải thích dài: gợi ý tối đa một dòng, phần dài đưa vào dòng «Giải thích» mở tại chỗ.
- Định dạng: tiền `1.000.000 đ` (không số lẻ; trống «—»; vào «+» xanh, ra «−» đỏ) · ngày `14/09/2026` · thời điểm `14/09/2026 15:42` · kỳ `Tháng 09/2026` · số chứng từ `DNTT-BV-2026-0042` (font `mono`).

## Màu

- Chỉ **giao diện sáng**. Khóa bằng `color-scheme: only light` và `<meta name="color-scheme" content="light">`, `theme-color` `#1f3a5c`. Không tự bật giao diện tối.
- Nền trang `nen`; mọi thẻ nền `giay` viền `vien`. Chữ chính `muc`, chữ phụ `muc-phu`, nhãn và gợi ý `muc-nhat`. `muc-mo` chỉ cho mũi tên, biểu tượng mờ và dấu phiên bản (2.9:1: không dùng cho chữ mới mang nghĩa).
- `navy` là màu chính: nút chính, thanh trên, đầu trang điện thoại, mục đang chọn, link. Khi nhấn thì dùng `navy-dam`.
- Màu trạng thái có nghĩa cố định, không dùng để trang trí: `xanh` = tiền vào / xong · `do` = tiền ra / từ chối / quá hạn / lỗi · `vang` = đang chờ ai đó · `xam-nen` = nháp · `dong` = đã đóng. Chữ trên nền nhạt dùng bản đậm: `xanh-dam` trên `xanh-nen`, `do-dam` trên `do-nen`, `vang-chu` trên `vang-nen`.
- **Không bao giờ đặt chữ trắng trên `vang`**. Huy hiệu và số đếm vàng dùng `vang-chu`.
- Trạng thái luôn đi cùng chữ hoặc chấm + chữ (pill), không để màu tự nói.
- Vòng focus dùng chung: viền ngoài 3px `tieu-diem`, cách 2px, bo `bo-4`.
- **Trong code app, ghi màu bằng HEX CỐ ĐỊNH**, không qua `var()` (máy cũ từng không phân giải được biến màu), và không dùng `:has()`, `color-mix()`, nesting, `backdrop-filter`. Ở design system này màu đi qua token để xem và đổi dễ; khi chép sang app thì thay bằng hex.

### Màu nhấn phân hệ (đã chốt phương án B, 28/09/2026)

- Mỗi phân hệ có một màu nhấn và một nền nhạt: Tài chính `nhan-tc` (= `navy`), Nhân sự `nhan-ns` tím `#6b3589`, Kho `nhan-kho` xanh biển đậm `#0a6379`, Hệ thống `nhan-ht` nâu xám `#5a5048`; nền nhạt tương ứng là `nhan-*-nen`. Nhân sự đã đổi từ mận sang tím để không lẫn với đỏ trạng thái (xem thẻ `MauNhanPhanHe`).
- Màu nhấn chỉ dùng để **biết đang ở phân hệ nào**: ô chữ tắt TC / NS / KHO / HT, dải 4px dưới thanh trên, mục thanh bên đang chọn, ô chọn đang bật, nền nhạt các dòng việc của phân hệ. Không dùng màu nhấn để báo trạng thái và không đè lên màu trạng thái.
- Gắn `data-phan-he="tc|ns|kho|ht"` lên khung layout của phân hệ. Các class trong `bundle.css` phần 3–4 đọc màu nhấn từ thuộc tính này.
- Thanh trên, đầu trang điện thoại, nút chính, link và vòng focus giữ `navy` / `tieu-diem` ở mọi phân hệ.

## Chữ

- Một họ chữ: **Be Vietnam Pro** (`sans`), đủ dấu tiếng Việt. App nạp bằng `next/font/google` với các nét 400/500/600/700 và biến `--font-be-vietnam`. Tệp TTF Regular/Bold trong `fonts/` dùng cho PDF.
- Thang: `tieu-de-trang` 28 · `tieu-de-man` 22 · `tieu-de-khoi` 18 · `than` 16 (cỡ nhỏ nhất cho nội dung trên điện thoại, và là cỡ chữ trong ô nhập để iOS không phóng to) · `than-bang` 15 · `nhan-o` 13/600 · `nhan-nhom` 12/700 viết hoa, giãn .1em.
- Số tiền luôn `font-variant-numeric: tabular-nums` (class `.tien`) và là **chữ to nhất trên dòng**: `tien` 20/700, `tien-bang` 16/700 căn phải, `tien-tong` 19/700.
- Số chứng từ và dấu phiên bản dùng `mono` (`so-ct`).

## Khoảng cách, kích thước, bo góc

- Thang `khoang-4 · 8 · 12 · 16 · 20 · 24 · 32`. Lề trang điện thoại `khoang-16`, máy tính `khoang-32`. Ruột thẻ `khoang-16`. Giữa hai thẻ `khoang-12`. Giữa hai khối `khoang-24`. Dòng danh sách và khối xác nhận đệm 14px (`khoang-14`, đúng nguồn).
- Vùng bấm tối thiểu `cao-nut` 44px. Nút chính và ô nhập `cao-nut-chinh` 48px. Cỡ nhỏ 36px (`cao-nut-nho`) và ô 40px (`cao-o-nho`) **chỉ dùng trên máy tính**.
- Bo góc: thẻ `bo-14` · mọi nút và khối `bo-12` · ô nhập `bo-10` · ô trong bảng `bo-8` · pill và chip `bo-tron`.
- Thẻ **không đổ bóng**. Bóng duy nhất `bong-dinh` / `bong-day` dành cho thanh dính và nút nổi.
- Không dùng chuyển động nặng: chỉ đổi màu 0.15s và xoay mũi tên. Tôn trọng `prefers-reduced-motion`. Khung chờ tải đứng yên, không nhấp nháy.

## Bố cục và tương tác

- Khung (`KhungUngDung`): máy tính (≥ 1024px) có thanh trên navy 56px và thanh bên 248px chia nhóm; điện thoại có đầu trang navy và thanh tối đa 4 tab + «Thêm» dán đáy. Menu theo vai trò.
- **Không modal, không popup, không `window.confirm`, không tooltip.** Xác nhận bằng `KhoiXacNhan` mở tại chỗ ngay dưới nút. Thông tin phụ mở bằng `<details>` gốc. Trang «Thêm» và «Chọn phân hệ» là trang riêng, không phải lớp phủ. Đây là quy tắc cứng của phân hệ Tài chính và được đề xuất áp cho cả app.
- Ô nhập là **ô gốc của trình duyệt** (`input`, `select`, `input type=date`, `input type=file`) mang class `.o-nhap`. Không thay bằng dropdown hay lịch tự vẽ.
- Điện thoại hiển thị danh sách bằng `The`, máy tính bằng `Bang`. Mỗi màn chỉ một nút chính.
- Nút đang xử lý hiện vòng xoay kèm chữ «Đang gửi…» và bị khóa để không bấm hai lần. Sau thao tác, hiện `ThongBao` tại chỗ.
- Ẩn nút **không phải** là phân quyền: quyền thực thi ở DB/server. Giao diện chỉ phản ánh quyền.

## Biểu tượng

- Bộ 31 biểu tượng SVG nét 1.8, kiểu Lucide, `stroke="currentColor"` (nhóm tài sản **Icons**, thẻ `BieuTuong`). Render một sprite `<symbol>` trong layout gốc và dùng `<use href="#i-ten"/>`.
- Cỡ 20 trong nút, 24 trên thanh điều hướng, 26 ở trạng thái trống. Biểu tượng luôn đi kèm chữ và luôn `aria-hidden`.
- Không dùng emoji. Hình mới vẽ cùng nét, cùng `viewBox 0 0 24 24`.
- Phân hệ được nhận diện bằng **ô chữ tắt** (TC / NS / KHO / HT) trên nền màu nhấn, không bằng hình vẽ.

## Tên và logo

- Tên hiển thị app và logo **CHƯA CHỐT**. Tạm đặt chữ «Base Vina» bằng `sans` 700 trên thanh trên. Không tự vẽ logo.
- Nhóm tài sản **Bieu-tuong-app** là biểu tượng PWA của app Tài chính cũ. Chỉ dùng tạm cho đến khi có biểu tượng 3 trong 1.

## Phân hệ Kho

- Trong giai đoạn 1–6, Kho giữ shadcn/base-ui. Toàn bộ CSS của shadcn phải nằm trong vỏ `.kho-scope` ở layout `/kho`. Không khai báo biến shadcn (`--background`, `--primary`…) ở `:root`. Màu nhấn Kho áp lên khung chung (thanh bên, dải nhấn), không áp lên component shadcn.

## Phần chưa đồng bộ

- Nguồn là `oemlogosVu/base-vina-3in1@0deb1ed`, thư mục `design/tham-chieu-tai-chinh/` (chép từ Finance Manager Base V3 `main` 992cdd7).
- Không lấy sang: khối `:root[data-theme="dark"]` (đang tắt ở nguồn và chưa kiểm tương phản), khối `@theme inline` và các tiện ích Tailwind (trừ `sr-only`).
- Bản `thiet-ke-dot-1.dc.html` chỉ dùng để lấy thang chữ, thang khoảng cách và mẫu câu; không nhập nguyên.
- Component **không build**: thư mục tham chiếu không chạy được, và component là lớp bọc JSX mỏng trên class CSS. Mỗi thẻ là bản dựng tĩnh bằng chính class trong `bundle.css`, còn prop lấy từ tệp `.tsx` nguồn và ghi trong README của từng thẻ.
- Bốn tên màu `xanh-dam`, `xanh-vien`, `do-dam`, `nen-hover-the` do hệ thống đặt: ở nguồn các màu này ghi hex trực tiếp, không có tên biến.
- Các thẻ nhóm «3 trong 1» và «Nhân sự», màu nhấn và mục Nhân sự là thiết kế mới, chưa có trong code. Mục Nhân sự dựa trên nghiệp vụ ghi trong tài liệu kế hoạch. Chưa đối chiếu với màn hình thật của app Nhân sự cũ, vì mã nguồn app đó không có trong repo này.
