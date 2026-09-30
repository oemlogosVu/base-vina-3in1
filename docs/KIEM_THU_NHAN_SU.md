# KIỂM THỬ TAY — PHÂN HỆ NHÂN SỰ (Giai đoạn 2)

> Lập 30/09/2026 từ tài liệu gốc app Nhân sự (HRM main 9a0b9a8, v0.32.2: docs/P0…P5c, DOI-CHIEU-LUONG-08-2026, NHAT-KY)
> — nghiệp vụ và kết quả mong đợi lấy đúng như app cũ đã thiết kế, KHÔNG phải nghiệp vụ mới.
>
> **Nơi thử:** bản xem thử https://base-vina-3in1-git-giai-doan-2-trieu-vu.vercel.app (đăng nhập Vercel trước),
> dữ liệu = project THỬ (bản chụp dữ liệu thật 29/09 09:58). Mọi thao tác KHÔNG ảnh hưởng app Nhân sự đang chạy.
> Mật khẩu mọi tài khoản có sẵn trên bản thử = **mật khẩu thử chung**; tài khoản tạo mới ở ca TK-01 dùng mật khẩu
> app hiện ra một lần.
>
> **Cách ghi kết quả:** cột "KQ" ghi **Đ** (đúng), **S** (sai — ghi thêm thấy gì), **—** (chưa thử). Gửi lại file/ảnh
> chụp các dòng S cho agent.
>
> Lưu ý: app cũ CHƯA TỪNG được thử tay 11 phase làm ngày 24–26/08 và phần chấm công cá nhân + lương (theo nhật ký
> HRM). Lỗi tìm thấy ở đây có thể là lỗi SẴN CÓ của app cũ — agent sẽ phân loại: lỗi do chép sang, hay lỗi gốc.

---

## 0. Chuẩn bị (làm một lần, bằng tài khoản quản trị của anh/chị)

| Mã | Việc làm | Kết quả đúng | KQ |
|---|---|---|---|
| CB-01 | Đăng nhập, chọn phân hệ **Nhân sự** | Thanh bên có nhóm Cá nhân · Quản lý · Lương · Quản trị; dải màu tím dưới thanh trên | |
| CB-02 | Trang **Tổng quan** Nhân sự (`/nhan-su`) | Có cảnh báo đỏ nếu còn hồ sơ thiếu **vùng lương tối thiểu** (thiếu → engine coi là vùng 1, trần BHTN sai) | |
| CB-03 | Quản trị → **Công ty** | Khai **khung giờ chuẩn** (vd 08:00–17:00, nghỉ 12:00–13:00) và **3 ca công nhật** cho từng công ty; Lưu được | |
| CB-04 | Tạo **tài khoản thử theo vai trò** ở ca TK-01 dưới đây: 1 trưởng phòng, 1 nhân viên, 1 người chấm tổ đội, 1 kế toán (chỉ tick "Báo cáo lương") — email đuôi `@basevina.test` | Có đủ 4 tài khoản để thử quyền | |

## 1. Tài khoản & phân quyền (Quản trị → Người dùng)

| Mã | Việc làm | Kết quả đúng | KQ |
|---|---|---|---|
| TK-01 | Tạo tài khoản mới | Mật khẩu 16 ký tự hiện **đúng một lần**; tài khoản mới ở trạng thái **khoá** tới khi kích hoạt | |
| TK-02 | Nối tài khoản với một hồ sơ, kích hoạt, đăng nhập bằng tài khoản đó | Đăng nhập được; thấy "Hồ sơ của tôi" đúng người | |
| TK-03 | Nối **tài khoản thứ hai** vào cùng hồ sơ đó | **Bị từ chối** | |
| TK-04 | Tự hạ vai trò admin của chính mình / khoá admin cuối cùng | **Bị từ chối** | |
| TK-05 | Bỏ tick tab "Kỳ lương" của một người (không phải admin) → người đó tải lại trang | Tab **biến mất**; gõ thẳng đường dẫn `/nhan-su/luong/ky-luong` → bị đưa về "Hồ sơ của tôi" | |
| TK-06 | Tick lại tab đó | Tab hiện lại **ngay**, không phải đăng nhập lại | |
| TK-07 | Tài khoản kế toán chỉ tick "Báo cáo lương" | **Xem** được báo cáo lương; **không** chốt / tính được kỳ lương | |
| TK-08 | Tài khoản có quyền "Nhân sự" nhưng không có quyền lương mở một hồ sơ | **Không** thấy mức lương | |
| TK-09 | Không có chức năng xoá tài khoản; chỉ **khoá** | Khoá xong → tài khoản đó không đăng nhập được | |

## 2. Hồ sơ nhân sự (Quản lý → Nhân sự; `/nhan-su/ho-so`)

| Mã | Việc làm | Kết quả đúng | KQ |
|---|---|---|---|
| HS-01 | Tạo hồ sơ mới (Thêm nhân sự) | Lưu được; **mã NV không sửa được** sau khi tạo | |
| HS-02 | Thêm **hợp đồng** thứ hai khi đang có một hợp đồng hiệu lực | **Bị từ chối** (tối đa 1 hợp đồng hiệu lực) | |
| HS-03 | Thêm người phụ thuộc | Lưu được; hiện trong hồ sơ | |
| HS-04 | **Đổi chức danh chính** có ngày hiệu lực | Lịch sử chức danh ghi đúng ngày; ô chức danh chỉ hiện khi tạo mới | |
| HS-05 | Kiêm nhiệm: người có ăn ca 730k + chức vụ 2tr, kiêm thêm chức danh có ăn ca 900k + xăng 1tr | Phụ cấp = **ăn ca 900k + chức vụ 2tr + xăng 1tr** (cùng loại lấy cao nhất, khác loại cộng) | |
| HS-06 | Hai chức danh chính cùng mở / kiêm một chức danh 2 lần / phụ cấp âm | **Bị từ chối** cả 3 | |
| HS-07 | **Thêm mức lương mới** lùi ngày vào kỳ đã chốt | Vẫn lưu, **kèm cảnh báo** nêu tên kỳ bị ảnh hưởng | |
| HS-08 | Đăng nhập **trưởng phòng**, mở danh sách | Chỉ thấy phòng **trực tiếp** của mình; CCCD, STK, MST, số BHXH, hợp đồng, lương của cấp dưới **trống** | |
| HS-09 | Đăng nhập **nhân viên**, mở "Hồ sơ của tôi" | Chỉ xem, **không có nút Lưu** | |
| HS-10 | **Xoá** một hồ sơ (chưa có phiếu lương) | Hồ sơ vào **Thùng rác**; tài khoản của người đó **bị khoá cùng lúc** | |
| HS-11 | Khôi phục hồ sơ ở Quản trị → Thùng rác | Hồ sơ trở lại; tài khoản **KHÔNG tự mở lại** | |
| HS-12 | Xoá hồ sơ **đã có phiếu lương** | **Bị từ chối** | |
| HS-13 | Sửa tên một người ở hồ sơ | Tên mới hiện ở mọi nơi trong Nhân sự (dữ liệu nay ở bảng chung `nguoi`) | |

## 3. Chấm công cá nhân (Cá nhân → Chấm công; Quản lý → Chấm công công ty)

| Mã | Việc làm | Kết quả đúng | KQ |
|---|---|---|---|
| CC-01 | Nhân viên bấm **chấm vào**, sau đó **chấm ra** (ảnh tuỳ chọn) | Ghi được; giờ = **giờ máy chủ**; không hỏi vị trí GPS | |
| CC-02 | Xem bảng công của mình trước khi được xác nhận | Ngày đó **0 phút công** | |
| CC-03 | Quản trị vào **Chấm công công ty** → "Xác nhận cả ngày" | Ngày 08:00–17:00 ra **480 phút** | |
| CC-04 | Các ca có mặt (ca 08–12 / 13–17): 08:00–12:00 · 08:00–12:30 · 10:00–15:00 | **240 · 240 · 240** phút | |
| CC-05 | Ở lại tới 19:00 **không** bấm "thêm giờ" | 480 phút, **0 phút làm thêm**; đến sớm không thành làm thêm | |
| CC-06 | **Quên chấm ra** | Trạng thái "thiếu chấm ra", **0 công** (hệ thống không đoán giờ về) | |
| CC-07 | Chấm công **Chủ nhật** | Toàn bộ là **làm thêm**, không cộng ngày công | |
| CC-08 | Người được **miễn chấm công** bấm chấm | **Bị từ chối** kèm giải thích | |
| CC-09 | Trưởng phòng / kế toán xem chấm công | Xem được phòng mình nhưng **không xem ảnh** | |
| CC-10 | Chấm công công ty → **Bảng công tháng** → Xuất PDF | 31 cột lọt **một tờ A4 ngang**; ô chưa tới ngày / chủ nhật / nghỉ có 3 dấu khác nhau | |
| CC-11 | Bảng công tháng trên **điện thoại** | Cuộn ngang được, cột họ tên **dính bên trái** | |

## 4. Sửa chữa công (Quản lý → Sửa chữa công)

| Mã | Việc làm | Kết quả đúng | KQ |
|---|---|---|---|
| SC-01 | Chọn tổ/công ty + ngày, tick 3 người, nhập giờ riêng, **một lý do chung** → chấm bù | Báo kiểu "Đã chấm bù 2/3 người" + lý do từng người trượt (nếu có) | |
| SC-02 | Chấm bù 08:00–12:00 · 08:00–14:00 · chọn Chủ nhật | **0,5 công · 0,63 công · cảnh báo đỏ 0 công** | |
| SC-03 | Lý do < 10 ký tự · ngày tương lai · giờ ra trước giờ vào | **Bị từ chối** cả 3 | |
| SC-04 | Chấm bù ngày đã có lần chấm | Báo "Ngày … đã có … lần chấm. Xoá lần chấm sai trước…" | |
| SC-05 | Sửa giờ = xoá lần sai (vào Thùng rác) + chấm bù lần đúng | Cả hai bước **ghi sổ** trước/sau | |
| SC-06 | Chấm bù vào **kỳ lương đã chốt** | Báo "Kỳ lương … đã chốt… Dùng nút 'Tạo khoản truy lĩnh'" | |
| SC-07 | Tạo truy lĩnh khi kỳ **còn mở** / số tiền ≤ 0 | **Bị từ chối** ("…làm cả hai là trả tiền hai lần") | |
| SC-08 | Lương 26tr, công chuẩn 26: chấm bù 1 công + truy lĩnh 1 công → tính lại kỳ **nhiều lần** | Phiếu ghi **2.000.000**, tính lại không cộng dồn | |

## 5. Lương nhân viên chính thức (Lương → Kỳ lương / Báo cáo lương; Cá nhân → Phiếu lương)

| Mã | Việc làm | Kết quả đúng | KQ |
|---|---|---|---|
| LG-01 | Tạo kỳ lương cho **một công ty + tháng** | Công chuẩn tự lấy từ công ty; tạo kỳ trùng công ty + tháng → **bị từ chối** | |
| LG-02 | **Tính** kỳ khi thiếu tham số / có làm thêm mà chưa có hệ số / có người chưa gán công ty | **Từ chối** (không ra số 0) và **nêu tên** người/thiếu gì | |
| LG-03 | Mức lương đổi giữa kỳ: 10 ngày × 20tr + 10 ngày × 31tr, công chuẩn 20 | Lương = **25.500.000**; bảo hiểm theo mức **đầu kỳ** | |
| LG-04 | Đối chiếu ca mẫu (tham số: giảm trừ 15,5tr/6,2tr; trần BHXH 50,6tr; BHTN vùng 1 106,2tr): lương 15tr + ăn ca 730k, công đủ | Gross **15.730.000**, BH **1.575.000**, thuế 0, thực nhận **14.155.000** | |
| LG-05 | Lương 30tr + phụ cấp 6,73tr, 1 người phụ thuộc | Thuế **562.500**, thực nhận **32.492.500** | |
| LG-06 | Đi làm 3/26 ngày | Nghỉ quá 14 ngày → **BH = 0** | |
| LG-07 | **Chốt** kỳ | PDF chứng từ sinh ngay (tiếng Việt có dấu, dòng "Bằng chữ"); kỳ đã chốt **không tính lại / sửa được** | |
| LG-08 | Nhân viên mở Phiếu lương → **Xác nhận** / **Thắc mắc** (không ghi lý do) | Xác nhận được; thắc mắc **bắt buộc lý do**; đã ký thì không chuyển sang thắc mắc | |
| LG-09 | Admin ký hộ phiếu của người khác | **Không** làm được | |
| LG-10 | **Đánh dấu Đã trả** khi còn người chưa ký | **Bị từ chối**, nêu tên người chưa ký | |
| LG-11 | Tham số lương (Quản trị → Tham số lương): đổi tỷ lệ/mức | Chỉ **thêm dòng mới có ngày hiệu lực**, không sửa dòng cũ | |
| LG-12 | Nhân viên xem phiếu người khác / xem tham số lương; trưởng phòng xem lương cấp dưới | **Không** được | |
| LG-13 | Báo cáo lương nhiều kỳ → in / lưu PDF | Tổng khớp phép cộng tay | |

## 6. Tổ đội công nhật (Quản lý → Quản lý tổ đội)

| Mã | Việc làm | Kết quả đúng | KQ |
|---|---|---|---|
| TD-01 | Lập tổ, thêm nhân công (mã CN…) | Người lập tổ tự thành **người chấm** của tổ | |
| TD-02 | Gán người chấm là người **không có hợp đồng / không đóng BHXH** | **Bị từ chối** | |
| TD-03 | Chọn tổ trưởng không phải thành viên / cho tổ trưởng rời tổ khi đang giữ chức | **Bị từ chối** (tổ trưởng chỉ là chức danh, KHÔNG có quyền) | |
| TD-04 | Chấm công ngày: ca sáng 07:00–11:00 (khung 08–17) · ca tối 18:00–22:00 | **3 giờ thường + 1 giờ ngoài giờ** · **4 giờ ngoài giờ** | |
| TD-05 | Hai khoảng giờ chồng nhau / chấm một người ở 2 tổ cùng ngày | **Bị từ chối** | |
| TD-06 | Thêm **thưởng theo ngày** không ghi lý do | **Bị từ chối** | |
| TD-07 | Lưu công **không có ảnh** → bấm Duyệt | Lưu được nhưng **không duyệt được** | |
| TD-08 | Tải ảnh xác minh (1 ảnh/tổ/ngày) → Duyệt | Duyệt được; duyệt xong **khoá** (muốn sửa: mở lại ở Sửa chữa công) | |
| TD-09 | Người **có tên trong tổ** (kể cả admin) duyệt công tổ mình | **Bị từ chối** | |
| TD-10 | Lập **bảng thanh toán** khi có người thiếu đơn giá / trùng khoảng ngày | **Từ chối**, nêu tên người thiếu | |
| TD-11 | Bảng thanh toán hợp lệ | Chỉ cộng phiên **đã duyệt**; cảnh báo số công chờ duyệt; thành tiền = giờ × đơn giá giờ + giờ ngoài giờ × đơn giá ngoài giờ + thưởng; có **PDF** | |
| TD-12 | **Sửa tay** bảng (vd 8 → 9 công × 61.250) có lý do | Tạo bảng + chứng từ **mới** = **551.250 đ**; khối "Lịch sử sửa tay" hiện trước/sau | |
| TD-13 | **Xoá** bảng thanh toán | Hỏi lại trước khi xoá; chứng từ cũ **vẫn còn** | |
| TD-14 | Kế toán xem bảng thanh toán | Thấy bảng, **không** có nút Sửa/Xoá; không xem ảnh xác minh | |

## 7. Chứng từ PDF

| Mã | Việc làm | Kết quả đúng | KQ |
|---|---|---|---|
| CT-01 | Mở PDF kỳ lương / bảng thanh toán | Tiếng Việt có dấu, "Bằng chữ", mã kiểm tra (sha256), có cột Thưởng; tổng khớp cộng tay | |
| CT-02 | Tìm cách xoá / sửa chứng từ (kể cả admin) | **Không** có cách nào | |

## 8. Riêng app 3 trong 1 (phần mới, không có ở app cũ)

| Mã | Việc làm | Kết quả đúng | KQ |
|---|---|---|---|
| G-01 | Đăng nhập **một lần**, chuyển qua lại Nhân sự ↔ trang chủ ↔ Nhân sự | Không phải đăng nhập lại | |
| G-02 | Thanh bên: mục đang mở tô **tím**; dải tím dưới thanh trên | Đúng màu nhận diện Nhân sự; nút chính vẫn **navy** | |
| G-03 | Điện thoại: thanh tab dưới, trang "Thêm" → chọn Nhân sự | Vào được mọi màn Nhân sự qua các thẻ ở trang Tổng quan | |
| G-04 | Máy đặt **giao diện tối** | App vẫn **sáng**, chữ rõ | |
| G-05 | Đổi mật khẩu (Thêm → Đổi mật khẩu) sai mật khẩu cũ | Báo "Mật khẩu hiện tại không đúng" | |

---

## Hạn chế ĐÃ BIẾT của app Nhân sự gốc (không tính là lỗi khi thử)

- Toàn bộ tiền làm thêm đang bị tính thuế TNCN; phụ cấp không chia theo ngày công; phụ cấp miễn thuế không có trần;
  đơn giá làm thêm không cộng phụ cấp; phiếu lương không báo tiền bị trừ do lỗi chấm công (chưa có căn cứ pháp lý).
- Chưa có lịch **ngày lễ** (lễ tính như ngày thường); mỗi công ty một ca; chưa có **đơn nghỉ phép**.
- Truy lĩnh chỉ cho nhân viên chính thức (chưa cho công nhật); phiếu lương chưa hiện các mức lương đã áp trong kỳ.
- PDF bảng đã sửa tay không ghi chữ "đã sửa tay"; người chấm không mở lại được PDF của bảng đã bị thay/xoá.
- Tự xác nhận phiếu quá hạn 7 ngày chỉ chạy khi bấm "Đã trả" (chưa có lịch tự chạy); chưa xoá ảnh selfie sau 90 ngày.
- Độ dài mật khẩu tối thiểu hiện là 6; chưa có "quên mật khẩu" qua email.
