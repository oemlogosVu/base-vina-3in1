# KẾ HOẠCH CHUẨN HOÁ DATABASE — BASE VINA 3 IN 1

> Lập 30/09/2026. Trạng thái: **ĐÃ DUYỆT 30/09** — đang dựng trên project THỬ.
> Dựng trên **project THỬ** `rgcimlgfuwjxjapefzyj` (tài khoản Supabase mới). Hệ thống thật chỉ bị ĐỌC.
>
> Nguồn rà soát (chỉ đọc, 30/09): cấu trúc thật DB Tài chính `eodrpyedatohsovobsxj` (31 bảng, 66 hàm, 66 policy)
> và Nhân sự `naglcxbpxnntiglrzeqx` (37 bảng, 88 hàm, 147 policy); Kho: `docs/02-schema-sheet.md` + `lib/types.ts`
> repo Inventory manager (main 6e8ae7f, 12 tab Sheet); đối chiếu dữ liệu trùng: `docs/DOI_CHIEU_DANH_MUC.md`.

---

## 1. Quyết định của chủ dự án

| Ngày | Quyết định |
|---|---|
| 30/09 | **Chuẩn hoá database TRƯỚC khi dựng app**: một CSDL mới phủ cả 3 dự án. |
| 30/09 | Mức: **chuẩn hoá danh mục chung** — dữ liệu nhập trùng gộp về MỘT bảng; bảng nghiệp vụ (đề nghị, sổ quỹ, chấm công, lương, phiếu kho) giữ cấu trúc, chỉ trỏ sang bảng chung. |
| 30/09 | Đặt tên **tiếng Việt không dấu**. Bảng nghiệp vụ tiếng Anh của Nhân sự giữ tên (không phải danh mục chung). |
| 30/09 | DB gộp ở tài khoản mới là **bản thử để diễn tập**; làm thật theo kế hoạch gộp khi chủ dự án nói "làm thật". |
| 30/09 | **Kho chuyển vào database** (bỏ Google Sheet) — thay AGENTS.md §2.3. |
| 30/09 | **Telegram: giữ mã, KHÔNG kích hoạt.** |
| 30/09 | Duyệt thiết kế bảng chung + view tương thích (mục 3–5). |
| 30/09 | STK ngân hàng cá nhân: 2 bên khác nhau → **lấy Tài chính** làm chuẩn. |
| 30/09 | NCC `NCC001` An Phát, `NCC002` Minh Long (TC): **ngừng dùng** (dang_dung = false, không xoá). |
| 30/09 | "Công ty TNHH XD Anh Nam" là **nhà thầu phụ** → `doi_tac` có cờ `la_nha_thau_phu`. |

---

## 2. Hiện trạng: dữ liệu nhập trùng giữa 3 app

| Thực thể | Tài chính | Nhân sự | Kho | Dữ liệu thật (26/09) |
|---|---|---|---|---|
| Công ty | `cong_ty` (2, không MST, mã BV/TH) | `companies` (2, có MST, mã BaseVN/TH) | — | khớp 2/2 |
| Người | `nhan_vien` (11) | `employees` (89, mã NV) | `dm_nguoi_dung` (8, email) | 8 người ở ≥ 2 app |
| Thông tin nhạy cảm (STK, SĐT…) | `nhan_vien_nhay_cam` | `employee_sensitive` (CCCD, STK, MST, số BHXH) | — | 1 người trùng STK, 5 người 1 bên |
| Công trình | `du_an` (6) | công trường trong `departments` (P04/P05/P06/P11) | `dm_kho` (kho = công trình) | 1 công trình rải tới 5 nơi |
| Phòng ban | — | `departments` (11, có cây) | `dm_bo_phan` (6, lẫn tổ đội) | không khớp tên |
| Đối tác | `nha_cung_cap` (25), `khach_hang` (5), `doi_tuong_vay` (2) | — | `dm_ncc` (175, mã kế toán) | 5 cặp NCC khớp tên |
| Vật tư | — | — | `dm_vat_tu` | chỉ Kho |

Đo mức ảnh hưởng tới logic (đọc từ DB thật 30/09):

| | Tài chính | Nhân sự |
|---|---|---|
| Hàm dùng tới bảng danh mục | 16 / 66 | 43 / 88 |
| Hàm **GHI** vào bảng danh mục | 1 (`admin_xoa_nhan_vien`) | 6 (`xoa_nhan_su`, `khoi_phuc_nhan_su`, `handle_new_auth_user`, `tao_to_doi`, `sua_nhan_cong_to`, `them_nhan_cong_to`) |

→ Không hàm tính tiền/lương/duyệt chi nào GHI vào danh mục; chúng chỉ ĐỌC (tên người, công ty, dự án).

---

## 3. Cách chuẩn hoá: bảng chung + lớp tương thích

1. **Lưu một lần:** mỗi thực thể dùng chung là MỘT bảng thật (mục 4).
2. **Lớp tương thích:** tên bảng cũ (`nhan_vien`, `employees`, `cong_ty`, `companies`, `du_an`, `nha_cung_cap`,
   `khach_hang`, `departments`, `employee_sensitive`, `nhan_vien_nhay_cam`) trở thành **VIEW** cùng tên, cùng cột,
   đọc từ bảng chung (`security_invoker` — quyền của người đang đăng nhập, RLS bảng chung vẫn áp dụng).
   → 59 hàm đang đọc danh mục + code app **chạy nguyên**, không viết lại logic tiền/lương.
3. **Ghi qua view:** màn quản trị danh mục (supabase-js) và 7 hàm ghi danh mục đi qua trigger `INSTEAD OF` trên view
   → ghi vào bảng chung. 7 hàm này được rà lại từng hàm (không phải hàm tiền).
4. **Giữ ID:** không đổi ID của bản ghi đang được bảng nghiệp vụ trỏ tới — khóa ngoại cũ vẫn đúng
   (chi tiết mục 5). Chỉ bản ghi TRÙNG (cùng một người/công ty ở 2 app) mới phải chọn 1 ID và cập nhật khóa ngoại
   của bên kia — làm trên bản thử, đối chiếu lại số liệu.
5. **Vai trò riêng từng phân hệ tách khỏi danh tính:** "Nguyễn Văn A" là MỘT dòng `nguoi`; việc A là nhân viên Tài
   chính (mã TC, chức vụ), hồ sơ Nhân sự (mã NV, ngày vào, phòng ban) hay người dùng Kho (vai trò thu_kho) nằm ở
   bảng vai trò của phân hệ đó, trỏ về `nguoi`.

---

## 4. Bảng chung (schema `public`, tên tiếng Việt)

| Bảng chung | Gộp từ | Cột chính |
|---|---|---|
| `cong_ty` | TC `cong_ty` + NS `companies` | id, **ma** (BV/TH — giữ mã TC vì in trên số đề nghị), ma_nhan_su (BaseVN/TH), ten, ten_phap_ly, ma_so_thue, dia_chi, nguoi_dai_dien, + cột cấu hình công của NS (so_cong_chuan, gio_vao, gio_ra, nghi_tu, nghi_den, han_xac_nhan_phieu_ngay), dang_dung |
| `nguoi` | TC `nhan_vien` (danh tính) + NS `employees` (danh tính) + Kho `dm_nguoi_dung` | id, ho_ten, ngay_sinh, gioi_tinh, dien_thoai, email, dia_chi_thuong_tru, cong_ty_id, **user_id** → auth.users (duy nhất, trống = không đăng nhập), dang_dung |
| `nguoi_nhay_cam` | TC `nhan_vien_nhay_cam` + NS `employee_sensitive` | nguoi_id (PK), cccd, ngay_cap, noi_cap, so_tai_khoan, ten_ngan_hang, ma_so_thue_ca_nhan, so_bhxh, telegram_chat_id — RLS chặt (chỉ chính mình + người có quyền của TỪNG phân hệ) |
| `phong_ban` | NS `departments` + Kho `dm_bo_phan` | id, ma, ten, cong_ty_id, cha_id (cây), truong_phong_id → nguoi, **cong_trinh_id** (nếu là công trường), dang_dung |
| `cong_trinh` | TC `du_an` + công trường NS | id, ma, ten, cong_ty_id, khach_hang_id → doi_tac, dia_diem, ngay_bat_dau, ngay_ket_thuc, chu_nhiem_id → nguoi, du_toan (numeric), trang_thai, dang_dung |
| `doi_tac` | TC `nha_cung_cap` + `khach_hang` + Kho `dm_ncc` | id, ma, **ma_ke_toan** (NCC00001… duy nhất), ten, ma_so_thue, dia_chi, nguoi_lien_he, dien_thoai, email, so_tai_khoan, ten_ngan_hang, **la_nha_cung_cap**, **la_khach_hang**, **la_nha_thau_phu**, dang_dung |
| `quyen_phan_he` | MỚI (thay suy luận ở kế hoạch §3.4) | user_id, phan_he (tc/ns/kho/ht), dang_dung — bộ chọn phân hệ đọc bảng này; vai trò CHI TIẾT vẫn ở từng phân hệ |

Bảng vai trò riêng từng phân hệ (trỏ về `nguoi`):

| Bảng | Thay cho | Cột |
|---|---|---|
| `nhan_vien_tc` | phần "vai trò" của TC `nhan_vien` | **id = id nhan_vien cũ** (giữ khóa ngoại của ~25 bảng TC), nguoi_id, ma, chuc_vu, dang_dung |
| `ho_so_nhan_su` | phần HR của NS `employees` | **nguoi_id = id employees cũ** (giữ khóa ngoại của mọi bảng NS), ma_nv, phong_ban_id, quan_ly_id, vung, ngay_vao, trang_thai, anh_dai_dien, theo_doi_cham_cong, deleted_at/by, ly_do_xoa |
| `kho.nguoi_dung` | Kho `dm_nguoi_dung` | nguoi_id, vai_tro (admin/thu_kho/duyet/xem), trang_thai — **bỏ cột mật khẩu** (đăng nhập Supabase) |

View tương thích (cùng tên, cùng cột như cũ): `nhan_vien` = nhan_vien_tc ⋈ nguoi; `employees` = ho_so_nhan_su ⋈ nguoi;
`companies`, `cong_ty`(view đọc từ bảng chung `cong_ty` — cùng tên nên TC không cần view), `du_an` = cong_trinh;
`nha_cung_cap` = doi_tac WHERE la_nha_cung_cap; `khach_hang` = doi_tac WHERE la_khach_hang; `departments` = phong_ban;
`employee_sensitive`, `nhan_vien_nhay_cam` = nguoi_nhay_cam.

**Giữ nguyên (không phải danh mục chung):** mọi bảng nghiệp vụ TC (de_nghi, dot_duyet, lan_tra_tien, phieu_thu, chuyen_quy,
giao_dich_*, quy_tien_mat, tai_khoan_ngan_hang, khoan_muc_*, ngan_sach, nhat_ky…); mọi bảng NS (attendance_*, payslips,
payroll_periods, labor_contracts, cfg_*, to_doi*, cham_cong_*…); `doi_tuong_vay` (chỉ TC); `positions` (chỉ NS);
`app_users` (vai trò NS — thêm cột nguoi_id). `chung_tu` TC → `chung_tu_fmb` (không đổi so với quyết định 29/08).

---

## 5. Giữ ID và xử lý bản ghi trùng

| Thực thể | ID giữ lại | Bên phải cập nhật khóa ngoại |
|---|---|---|
| Người | `nguoi.id` = id `employees` (NS) cho người có hồ sơ NS; người chỉ ở TC/Kho → id mới | TC: không (TC trỏ `nhan_vien_tc.id` = id cũ). NS: không. |
| Công ty (2 trùng) | id `companies` (NS) | TC: `cong_ty_id` ở ~10 bảng TC → id NS (bản thử) |
| Công trình | id `du_an` (TC) | NS: không có khóa ngoại; Kho: nối mới |
| Đối tác | id `nha_cung_cap`/`khach_hang` (TC) | Kho: nối theo ma_ke_toan (5 cặp khớp tên — chủ dự án xác nhận) |
| Tài khoản (auth.users) | NS giữ id; TC chép giữ id; người trùng → 1 id | cập nhật user_id ở bên bỏ id — chủ dự án xác nhận từng người |

---

## 6. Schema `kho` (dựng từ Sheet)

| Bảng | Từ tab | Ghi chú |
|---|---|---|
| `kho.vat_tu` | dm_vat_tu | ma_vt PK, ton_min numeric |
| `kho.kho` | dm_kho | ma_kho PK, **cong_trinh_id** → cong_trinh |
| (dùng `phong_ban`) | dm_bo_phan | ghép tay vào phong_ban/to_doi |
| (dùng `doi_tac`) | dm_ncc | ma_ke_toan |
| `kho.nguoi_dung`, `kho.nguoi_dung_kho` | dm_nguoi_dung + cột ma_kho_phu_trach | (nguoi_id, ma_kho); trống = mọi kho |
| `kho.phan_quyen_vai_tro` | dm_phan_quyen | cờ boolean |
| `kho.phieu`, `kho.phieu_chi_tiet`, `kho.phieu_anh` | phieu, chi_tiet, anh_chung_tu | so_phieu UNIQUE (giữ cách đánh số cũ, không max+1); tiền numeric; ảnh sang bucket `kho-chung-tu` |
| `kho.de_xuat`, `kho.de_xuat_chi_tiet`, `kho.de_xuat_anh` | de_xuat, de_xuat_chi_tiet, anh_dinh_kem | |
| `kho.nhat_ky` | log | chỉ ghi thêm |
| **`kho.v_ton_kho`** (VIEW) | thay ton_kho_cache | Σ NHAP − Σ XUAT + Σ DIEU_CHINH phiếu DA_DUYET; công thức chép từ `lib/ton-kho.ts` |

Chỉ ghi thêm (trigger chặn DELETE; UPDATE phieu/de_xuat chỉ cột trạng thái). RLS bật, không cấp cho anon/authenticated —
Kho đọc/ghi qua máy chủ app (`kiemTraSession` + `kiemTraQuyen`).

---

## 7. Telegram — giữ mã, không kích hoạt

- `cau_hinh_he_thong` (TC) đang chứa **khóa bot, nhóm duyệt, nhóm báo cáo, webhook secret NGAY TRONG DB**.
  Bản thử: chép bảng nhưng các cột này để **TRỐNG**. Khi làm thật đề xuất chuyển khóa sang biến môi trường Edge Function.
- Không cài secret TELEGRAM_* cho Edge Function; không tạo lịch pg_cron `daily-report-0730-vn`; không đặt webhook.
- Mã gửi thông báo (4 Edge Function + chỗ gọi trong app) giữ nguyên, tự bỏ qua khi thiếu cấu hình.

---

## 8. Thứ tự dựng trên project THỬ

| Bước | Việc | Điều kiện |
|---|---|---|
| 0 | Xoá dữ liệu Nhân sự đã nạp 29/09 trên bản thử, dựng lại từ đầu theo thiết kế mới | Chỉ project THỬ |
| 1 | Sao lưu DB Tài chính (chỉ đọc) | Mật khẩu DB Tài chính |
| 2 | Viết migration vào repo: bảng chung → vai trò phân hệ → bảng nghiệp vụ TC/NS (cấu trúc từ DB thật, khóa ngoại trỏ bảng chung) → view tương thích + trigger INSTEAD OF → RLS/policy → schema `kho` | Duyệt thiết kế này |
| 3 | Chạy migration trên bản thử; `tsc`/test của từng phân hệ không bị ảnh hưởng (chưa có code phân hệ trong repo) | — |
| 4 | Script chuyển dữ liệu từ 2 bản sao lưu + Sheet → bảng chung (gộp bản ghi trùng theo danh sách chủ dự án xác nhận) | Chế độ duyệt từng bước |
| 5 | Kiểm 59 hàm đọc danh mục + 7 hàm ghi danh mục chạy đúng qua view | — |
| 6 | Đối chiếu: số dòng; **số dư từng quỹ/TK** TC; **kết quả 1 kỳ lương thử** NS; **tồn từng vật tư × kho** = Sheet; RLS chéo | Kết quả ghi TIEN_DO.md |

Ước tính: **3–4 tuần làm việc** (thêm so với kế hoạch cũ). Hệ thống thật chỉ bị đọc.

---

## 9. Ảnh hưởng tới kế hoạch chung

- Code 3 app khi chép sang (GĐ2–4) **không phải sửa truy vấn danh mục** nhờ view tương thích; chỉ màn quản trị danh
  mục cần thử lại (ghi qua view).
- GĐ4 Kho: đổi lớp đọc/ghi Sheet → Postgres (~7 file lib + 9 route), logic Kho giữ nguyên.
- GĐ5: bộ chọn phân hệ đọc `quyen_phan_he`.
- Ngày chuyển hẳn (GĐ6): chạy lại script chuyển dữ liệu (bước 4) từ dữ liệu thật mới nhất; tạm ngừng nhập liệu cả 3
  app trong lúc chuyển (ước tính nửa ngày).
- GĐ7 (sau ổn định): bỏ dần view tương thích, sửa code dùng thẳng bảng chung.

---

## 10. Câu hỏi chủ dự án — ĐÃ TRẢ LỜI 30/09 (xem mục 1)

Còn chờ: mật khẩu DB Tài chính (biến `SUPABASE_DB_PASSWORD_TAICHINH`); danh sách người/công ty trùng để xác nhận từng trường hợp (lập ở bước 4).
