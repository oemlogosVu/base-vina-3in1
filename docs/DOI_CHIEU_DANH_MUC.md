# ĐỐI CHIẾU DANH MỤC TRÙNG NHAU GIỮA 3 APP

> Chạy ngày 26/09/2026 14:19 bằng `scripts/doi-chieu/doi-chieu-danh-muc.mjs` — **chỉ đọc**, chưa ghi gì
> vào DB/Sheet thật. File chi tiết (có dữ liệu cá nhân, git bỏ qua):
> `.local/doi-chieu/DOI_CHIEU_DANH_MUC_20260926_1419.xlsx` — mỗi sheet có cột **"Xác nhận"** để chủ dự án ghi ĐÚNG/SAI.
>
> Chạy lại: `node --env-file="../Inventory manager/.env.local" scripts/doi-chieu/doi-chieu-danh-muc.mjs`

## 1. Tổng quan

| Danh mục | Số bản ghi | Khớp chắc | Cần xác nhận | Chỉ có ở 1 app |
|---|---|---|---|---|
| Công ty | TC 2 / NS 2 | **2** | 0 | 0 |
| Người & tài khoản | TC 10 / NS 89 hồ sơ (4 tài khoản app) / Kho 8 | 6 | 2 | TC 2, Kho 4, NS 82 (công nhân, không có tài khoản — bình thường) |
| Công trình | Dự án TC 5 / Kho 6 / Phòng ban NS 11 / Tổ đội NS 5 / Bộ phận Kho 6 | — | 4 dự án gom được | 1 dự án, 1 kho |
| Phòng ban văn phòng | NS 7 / Kho 4 | 0 | 0 | NS 7, Kho 4 |
| Nhà cung cấp | TC 18 / Kho 175 | 0 | 5 | TC 13, Kho 170 |

## 2. Phát hiện chính

**Công ty** — 2 công ty trùng ở cả 2 app nhưng ghi khác nhau:

| Tài chính | Nhân sự | Khác biệt |
|---|---|---|
| `BV` Công ty Base Vina — **không có MST** | `BaseVN` Công ty CP TMXD và đầu tư Base Vina — MST 0111035431 | mã khác, TC thiếu MST + tên pháp lý |
| `TH` Công ty Thái Hà — **không có MST** | `TH` Công ty TNHH TMDV và XD Thái Hà — MST 4601654808 | TC thiếu MST + tên pháp lý |

**Người & tài khoản** — 8 người có mặt ở ≥ 2 app (4 người TC+NS, 3 người cả 3 app, 1 người TC+Kho).
2 cặp chỉ ghép được theo họ tên → cần xác nhận. 1 người ghi họ tên khác nhau giữa các app,
1 người ghi công ty khác nhau. Số tài khoản ngân hàng: chỉ 1 người có ở cả TC và NS (khớp); 5 người chỉ 1 bên có.
4 người dùng Kho không có ở TC/NS; 2 nhân viên TC không có ở NS.

**Công trình** — 1 công trình thực tế đang nằm rải rác ở 5 nơi:

| Dự án Tài chính | Kho (Kho) | Công trường (NS) | Tổ đội (NS) | Bộ phận nhận hàng (Kho) |
|---|---|---|---|---|
| Công trình Thái Nguyên | KHO03, KHO04 | P04 Bách Quang - Thái Nguyên | 5 tổ (TN-01, TN-02…) | BP05 |
| Nhà ở xã hội Thanh Miếu, Phú Thọ | KHO02, KHO05 | P06 Thanh Miếu - Phú Thọ | — | BP06 (tổ Anh Nam) |
| Đường dẫn cầu Trần Hưng Đạo | KHO06 | — | — | — |
| Công trình Bắc Ninh | — | P05 Quế Võ - Bắc Ninh (BaseVN), P11 Công trình Bắc Ninh (TH) | — | — |
| Công trình Cao Phong - Hoà Bình | — | — | — | — |
| (không dự án) | KHO01 Kho vật tư chính | | | |

**Nhà cung cấp** — Kho dùng mã phần mềm kế toán (NCC00001…), Tài chính tự đặt mã không thống nhất
(`NCC 001`, `NCC.008`, `NCC04`, `NCC.09`…) và 16/18 NCC **không có MST** → chỉ ghép được theo tên: 5 cặp.
`NCC001`, `NCC002` bên TC (tạo 17/07, tên "An Phát", "Minh Long") nhiều khả năng là **dữ liệu demo còn sót**.
"Công ty TNHH XD Anh Nam" là NCC bên TC nhưng là "tổ đội thi công" bên Kho.

**Phòng ban văn phòng** — không khớp tên: Kho có "Văn phòng", "Kho vận", "Kinh doanh", "Đội thi công số 1";
NS có Ban giám đốc (×2 công ty), Phòng kỹ thuật kế hoạch, Phòng quản trị, Kế toán - Tài chính, Kỹ thuật, Hành chính - Nhân sự.

## 3. Đề xuất nguồn gốc (bản "chuẩn") cho từng danh mục — CHỜ DUYỆT

| Danh mục | Bản chuẩn | Lý do | Việc đồng bộ đề xuất (chưa làm) |
|---|---|---|---|
| Công ty | **Nhân sự** (tên pháp lý + MST) | Có MST, dùng cho lương/BHXH | Bổ sung MST + tên pháp lý vào `cong_ty` Tài chính. Giữ mã `BV`/`TH` của TC vì đang in trên số đề nghị (DNTT-BV-…) |
| Người | **Nhân sự** (mã NV) | Hồ sơ đầy đủ nhất | Gắn mã NV vào nhân viên TC (thêm cột ở GĐ3/GĐ7); Kho nối theo email |
| STK ngân hàng | Chờ chủ dự án chọn | TC dùng để chi tạm ứng, NS dùng trả lương | Điền bên còn thiếu cho 5 người sau khi xác nhận |
| Công trình | **Dự án Tài chính** | Có ngân sách, chi phí gắn theo dự án | Gắn kho, công trường NS, tổ đội vào mã dự án (bảng mục 2) |
| Nhà cung cấp | **Mã kế toán (danh sách Kho)** | Trùng phần mềm kế toán, có MST | Đổi 5 NCC TC sang mã kế toán; rà 13 NCC TC còn lại; ngừng dùng NCC demo |
| Phòng ban | **Nhân sự** | Có cây tổ chức | Chủ dự án ghép tay 4 bộ phận Kho → phòng ban NS |

Mọi thao tác **ghi** vào DB/Sheet thật chỉ làm khi chủ dự án duyệt từng danh mục, sau khi có bản sao lưu,
và làm thử trên project THỬ trước (theo AGENTS.md §4).
