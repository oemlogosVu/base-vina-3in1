# KẾ HOẠCH GỘP 3 DỰ ÁN → "BASE VINA 3 IN 1"

> Ngày lập: 26/09/2026 · Phạm vi: Finance Manager Base V3 + HRM manager + Inventory manager
> Không thuộc phạm vi: `misa-agent`, `Theo_doi_quy_Duyet_chi`
> Trạng thái: **BẢN NHÁP — chờ chủ dự án duyệt các quyết định ở mục 9 trước khi làm**

---

## 1. Hiện trạng 3 dự án (tóm tắt)

| | **Tài chính** (Finance Manager Base V3) | **Nhân sự** (HRM manager) | **Kho** (Inventory manager) |
|---|---|---|---|
| Mục đích | Thu chi, đề nghị thanh toán/tạm ứng/quyết toán, duyệt 2 cấp (KTT → Chủ tịch), chi tiền, thu tiền, chuyển quỹ, công nợ tạm ứng/vay, ngân sách, báo cáo | Hồ sơ nhân sự, hợp đồng, chấm công cá nhân (selfie), chấm công tổ đội công nhật, tính lương + BHXH + thuế TNCN, phiếu lương, chứng từ PDF | Phiếu nhập/xuất/điều chỉnh kho, duyệt phiếu, tồn kho, thẻ kho, báo cáo N-X-T, đề xuất mua vật tư |
| Phiên bản | Bản 21/09 · KT-72 | v0.32.2 (đóng băng tính năng từ 26/08, chưa test tay) | Commit `6e8ae7f` (thủ kho tự duyệt QT-A1), đã push |
| Next.js / React | 16.2 / 19.2.4 | 16.3 / 19.2.8 | 16.3.1 / 19.2.8 |
| Thư viện UI | Không (CSS tự viết) | Không (CSS tự viết) | shadcn `base-nova` + base-ui + radix |
| Đăng nhập | Supabase Auth (email hoặc SĐT → `…@sodienthoai.local`) | Supabase Auth (email) | **Auth.js v5** (Google + mật khẩu, lưu trong Sheet) |
| Dữ liệu | Supabase `eodrpyedatohsovobsxj`, 31 bảng, 55 migration, schema `public` + `private` | Supabase `naglcxbpxnntiglrzeqx`, 37 bảng, 71 migration, schema `public` | **Google Sheet** 12 tab qua Service Account |
| Phân quyền | 5 vai trò + menu theo từng người + gán theo quỹ; **thực thi trong DB (RLS + RPC)** | admin + tick tab theo người → cột `quyen`; **RLS** | 4 vai trò (admin/thu_kho/duyet/xem) + ma trận màn hình; kiểm tra trong code API |
| Lưu file | Bucket `chung-tu` | Bucket `attendance-selfies`, `to-doi-cham-cong`, `chung-tu` | Vercel Blob |
| Tích hợp | Telegram bot (duyệt qua bot, báo cáo 7:30), pg_cron, backup DB hằng đêm | pg_cron tổng hợp công 00:15, GitHub Action xoá selfie > 90 ngày | Không có |
| Giao diện | Navy `#1f3a5c`, Be Vietnam Pro, sidebar desktop + tab bar dưới trên mobile, **không modal** | Chàm (indigo), font hệ thống, sidebar 240px | Xám trung tính, Geist, thanh menu trên |
| Dữ liệu thật | ~10 người dùng, 2 công ty (BV, TH) | 51 hồ sơ, 2 công ty (BaseVN, TH) | 355 vật tư, 172 NCC (mã theo phần mềm kế toán) |

**Điểm chung thuận lợi:** cùng Next.js 16 App Router (`proxy.ts`), Tailwind v4, TypeScript strict, tiếng Việt, deploy Vercel vùng `sin1`, Tài chính + Nhân sự cùng dùng Supabase và cùng triết lý "quyền nằm trong DB, sổ sách chỉ ghi thêm".

**Điểm khác biệt lớn nhất:** Kho dùng Google Sheet + Auth.js; hai app kia dùng Supabase.

---

## 2. Mục tiêu sau khi gộp

1. **Một địa chỉ web, một lần đăng nhập** → vào được 3 phân hệ: Tài chính · Nhân sự · Kho (tuỳ quyền).
2. **Một Supabase project** (gói free chỉ cho 2 project đang chạy — đúng hướng trong `Finance/docs/KE_HOACH_GOP_DB_HRM.md`).
3. **Danh mục dùng chung** (dần dần): công ty, nhân viên, phòng ban, nhà cung cấp, dự án/công trình.
4. **Không làm hỏng dữ liệu thật và không dừng vận hành**: 3 app cũ chạy song song đến khi app mới được nghiệm thu.
5. Giữ nguyên nghiệp vụ và quy tắc an toàn hiện có của từng app (không viết lại logic tiền, lương).

---

## 3. Kiến trúc đề xuất

### 3.1. Một ứng dụng Next.js, chia 3 phân hệ theo đường dẫn

Chọn **1 app** (không phải monorepo 3 app) vì: chủ dự án không phải lập trình viên, cả 3 cùng stack, cần 1 đăng nhập và 1 bộ điều hướng.

```
Combine 3 in 1/
├─ src/
│  ├─ proxy.ts                      ← kiểm tra phiên Supabase (gộp từ Finance/HRM)
│  ├─ app/
│  │  ├─ dang-nhap/                 ← 1 màn đăng nhập chung (email hoặc SĐT)
│  │  ├─ doi-mat-khau/
│  │  └─ (ung-dung)/
│  │     ├─ layout.tsx              ← khung chung: sidebar có bộ chọn phân hệ
│  │     ├─ page.tsx                ← trang chủ tổng (việc cần làm của cả 3 phân hệ)
│  │     ├─ tai-chinh/…             ← toàn bộ route Finance
│  │     ├─ nhan-su/…               ← toàn bộ route HRM
│  │     ├─ kho/…                   ← toàn bộ route Inventory
│  │     └─ he-thong/…              ← tài khoản chung, cấp quyền vào phân hệ
│  ├─ modules/
│  │  ├─ tai-chinh/{lib,components} ← alias @tc/*
│  │  ├─ nhan-su/{lib,components}   ← alias @ns/*
│  │  └─ kho/{lib,components}       ← alias @kho/*
│  └─ shared/                       ← alias @/shared/* : supabase client, phiên, UI chung, PDF, đọc số tiền
├─ supabase/
│  ├─ migrations/                   ← repo này làm "chủ" lịch sử migration duy nhất
│  └─ functions/                    ← 11 Edge Function (7 Tài chính + 4 Nhân sự)
└─ docs/
```

Mỗi module giữ alias riêng (`@tc/`, `@ns/`, `@kho/`) để khi chép code chỉ cần **đổi tiền tố import hàng loạt**, không phải sửa từng file.

### 3.2. Đổi đường dẫn (tránh trùng)

Trùng hiện tại: `/danh-muc`, `/quan-tri`, `/bao-cao`, `/doi-mat-khau`, `/dang-nhap`, `/` có ở nhiều app.

| App cũ | Ví dụ cũ | App mới |
|---|---|---|
| Tài chính | `/de-nghi/[id]`, `/duyet`, `/bao-cao/so-quy` | `/tai-chinh/de-nghi/[id]`, `/tai-chinh/duyet`, `/tai-chinh/bao-cao/so-quy` |
| Nhân sự | `/nhan-su/[id]`, `/cham-cong`, `/luong/ky-luong` | `/nhan-su/ho-so/[id]`, `/nhan-su/cham-cong`, `/nhan-su/luong/ky-luong` |
| Kho | `/phieu/[soPhieu]`, `/ton-kho`, `/de-xuat` | `/kho/phieu/[soPhieu]`, `/kho/ton-kho`, `/kho/de-xuat` |
| Kho API | `/api/phieu/…` | `/api/kho/phieu/…` |

⚠ **Link cũ cần cập nhật:** nút duyệt Telegram và báo cáo 7:30 (biến `APP_URL` + đường dẫn trong Edge Function `notify-telegram`, `daily-report`, `telegram-webhook`). Nên giữ redirect từ domain cũ sang đường dẫn mới 1–2 tháng.

### 3.3. Cơ sở dữ liệu: dùng Supabase project Nhân sự (`naglcxbpxnntiglrzeqx`) làm project chung

| Phân hệ | Cách đưa vào |
|---|---|
| Nhân sự | Giữ nguyên tại chỗ (schema `public`). |
| Tài chính | Theo đúng kế hoạch đã có `docs/KE_HOACH_GOP_DB_HRM.md` + quyết định chủ dự án 29/08: **không gộp bảng, bảng trùng tên thêm hậu tố `_fmb`**. Chỉ có 1 bảng trùng là `chung_tu` → `chung_tu_fmb` (migration 33 đã viết sẵn, chưa chạy). Schema `private` của Finance mang sang nguyên (HRM không có schema này). |
| Kho | **Giai đoạn 1: giữ Google Sheet** (chỉ đổi đăng nhập). **Giai đoạn sau (tuỳ chọn):** chuyển sang schema riêng `kho` trong Postgres. |

Việc bắt buộc khi gộp DB Tài chính (đã được đo trong tài liệu Finance):
- Bucket `chung-tu` trùng → Tài chính dùng `chung-tu-fmb`, chép file sang, sửa policy (nếu không, người dùng app này đọc được file của app kia vì policy cộng dồn).
- Trigger `on_auth_user_created` của HRM tự tạo dòng `app_users` cho **mọi** tài khoản mới → cần quyết định giữ (tạo dòng "khoá" vô hại) hay sửa.
- Lịch sử migration: Finance từng bị `db push` chạy lại migration 37 đè migration 47 (16/09). Khi gộp **phải lập "baseline" mới** trong repo Combine, không `db push` mù từ 2 repo cũ.

### 3.4. Đăng nhập & tài khoản (phần khó nhất)

**Nguyên tắc:** một bảng `auth.users` duy nhất (ở project chung), mỗi phân hệ **giữ nguyên hệ phân quyền bên trong của nó** ở giai đoạn đầu.

| Việc | Cách làm |
|---|---|
| Tài khoản Tài chính | Chép `auth.users` + `auth.identities` từ project Finance sang project chung **giữ nguyên UUID và mật khẩu đã mã hoá** → người dùng không phải đặt lại mật khẩu, `nhan_vien.user_id` vẫn đúng. |
| Người có tài khoản ở **cả** Tài chính và Nhân sự (cùng email) | Không chép; cập nhật `nhan_vien.user_id` (Tài chính) trỏ sang UUID bên Nhân sự. Cần 1 bảng đối chiếu làm tay. |
| Đăng nhập bằng SĐT (Tài chính) | Giữ quy ước `<số>@sodienthoai.local` cho cả app mới. |
| Tài khoản Kho | Bỏ Auth.js + đăng nhập Google. Người dùng Kho đăng nhập bằng Supabase; vai trò kho vẫn đọc từ tab `dm_nguoi_dung` **theo email** ở giai đoạn 1. Người chỉ dùng Kho → admin tạo tài khoản Supabase cho họ. |
| Quyền vào phân hệ | Người dùng thấy phân hệ nào được suy ra: **Tài chính** nếu có dòng `nhan_vien` đang dùng; **Nhân sự** nếu `app_users.is_active`; **Kho** nếu email có trong `dm_nguoi_dung` trạng thái `HOAT_DONG`. |
| Tạo tài khoản | Gộp 2 Edge Function trùng chức năng (`tao-tai-khoan` của Tài chính + `quan-tri-tai-khoan` của Nhân sự) thành một màn "Hệ thống → Tài khoản". |

### 3.5. Giao diện chung

- Khung chung: **sidebar desktop + tab bar dưới trên mobile** (lấy từ Tài chính, vì Chủ tịch/KTT dùng điện thoại Android cũ), thêm **bộ chọn phân hệ** ở đầu sidebar.
- Màu & font: token navy + Be Vietnam Pro của Tài chính làm chuẩn; mỗi phân hệ có 1 màu nhấn nhận diện.
- Nhân sự: CSS tự viết, gần với Tài chính → đổi token là khớp.
- Kho: đang dùng shadcn/base-ui. **Giai đoạn 1 giữ nguyên các component này, chỉ dùng trong `/kho`** (cần chủ dự án đồng ý vì AGENTS.md của 2 app kia cấm thêm thư viện). Lưu ý không để CSS nền của shadcn đè lên phân hệ khác. Giai đoạn sau có thể thay bằng component chung.
- Giữ ràng buộc của Tài chính: không modal trong phân hệ Tài chính, nút ≥ 44px, chế độ sáng.

### 3.6. Danh mục dùng chung (làm sau khi 3 phân hệ đã chạy ổn trong app mới)

| Thực thể | Tài chính | Nhân sự | Kho | Đề xuất |
|---|---|---|---|---|
| Công ty | `cong_ty` (BV, TH) | `companies` (BaseVN, TH) | — | Đối chiếu theo **mã số thuế**; dùng `companies` làm gốc, `cong_ty` thêm cột `company_id` |
| Nhân viên | `nhan_vien` | `employees` (gốc, có mã NV) | `dm_nguoi_dung` (email) | `employees` là gốc; `nhan_vien` thêm cột `employee_id` |
| Phòng ban | — | `departments` | `dm_bo_phan` | Kho dùng `departments` khi chuyển DB |
| Nhà cung cấp | `nha_cung_cap` | — | `dm_ncc` (mã kế toán NCC00001) | Dùng chung 1 danh sách theo mã kế toán |
| Công trình / kho | `du_an` | — | `dm_kho` (kho = công trình) | `dm_kho` gắn `du_an_id` |

Kết nối nghiệp vụ có thể làm sau:
- **Kho → Tài chính:** phiếu nhập kho/đề xuất mua đã duyệt → tạo nháp "đề nghị thanh toán" cho NCC.
- **Nhân sự → Tài chính:** kỳ lương đã chốt, bảng thanh toán tổ đội → tạo đề nghị chi lương.

---

## 4. Lộ trình theo giai đoạn

Mỗi giai đoạn kết thúc bằng: `tsc --noEmit` + `build` + chạy thử trên máy + chủ dự án nghiệm thu. **Không sang giai đoạn sau khi chưa được duyệt** (đúng quy tắc phase-gate của HRM).

### Giai đoạn 0 — Chuẩn bị & an toàn (1–2 ngày)
- [x] Kho: commit phần "thủ kho tự duyệt" — đã xong (`6e8ae7f`, đã push lên `origin/main`, kiểm tra 26/09).
- [x] Tài chính: nhánh production = `main` `992cdd7` (KT-71). KT-72 (`dung-ho-quy-cong-truong`) chưa push/deploy — chờ quyết.
- [ ] Sao lưu đầy đủ — **script đã viết** (`scripts/sao-luu/`, `docs/SAO_LUU.md`), chờ chủ dự án chạy.
- [ ] **Xử lý lộ bí mật trước khi gộp** — danh sách B1–B10 ở `docs/GD0_HIEN_TRANG_VA_BI_MAT.md`, chờ chủ dự án.
- [ ] Tạo git repo + Vercel project mới — đã `git init` (chưa commit); repo GitHub + project Vercel chờ duyệt.
- [ ] Thông báo đóng băng tính năng mới trên 3 app trong thời gian gộp (chỉ sửa lỗi).

### Giai đoạn 1 — Khung app mới (2–3 ngày)
- [ ] Khởi tạo Next.js 16.3 + Tailwind v4 (cùng phiên bản cho cả 3), alias `@/`, `@tc/`, `@ns/`, `@kho/`.
- [ ] `proxy.ts` + Supabase client dùng chung, kết nối project chung (`naglcxbpxnntiglrzeqx`).
- [ ] Màn đăng nhập chung (email/SĐT), đổi mật khẩu, khung sidebar + bộ chọn phân hệ, trang chủ tổng rỗng.
- [ ] Token màu, font Be Vietnam Pro.

### Giai đoạn 2 — Ghép Nhân sự (3–4 ngày) — dễ nhất vì DB đã ở đúng chỗ
- [ ] Chép `src/app/*` → `(ung-dung)/nhan-su/*`, `src/lib` → `modules/nhan-su/lib`, đổi import.
- [ ] Sửa mọi `href`/`redirect` sang tiền tố `/nhan-su`; `tabs.ts` và `safe-path.ts` theo đường dẫn mới.
- [ ] Chép 4 Edge Function + `_shared`; chép 135 unit test (vitest) + script kiểm RLS và cho chạy xanh.
- [ ] Chạy song song với app HRM cũ (cùng DB nên dữ liệu khớp ngay).

### Giai đoạn 3 — Gộp DB Tài chính & ghép code Tài chính (1–1,5 tuần) — rủi ro cao nhất
- [ ] Diễn tập toàn bộ trên **1 project Supabase thử** (khôi phục từ bản sao lưu) trước khi làm thật.
- [ ] Chạy migration 33 (`chung_tu` → `chung_tu_fmb`) cùng lúc đổi `BANG_CHUNG_TU` trong code.
- [ ] Tạo schema `private` + toàn bộ bảng/view/hàm/trigger/RLS của Tài chính trên project chung; nạp dữ liệu.
- [ ] Chép tài khoản (mục 3.4), đối chiếu người trùng email.
- [ ] Bucket `chung-tu-fmb` + chép file + sửa policy; kiểm tra chéo: người Nhân sự không đọc được file Tài chính và ngược lại.
- [ ] 7 Edge Function + secrets; cập nhật webhook Telegram & `APP_URL`; tạo lại pg_cron `daily-report-0730-vn`; workflow backup DB trỏ sang project chung.
- [ ] Chép code → `(ung-dung)/tai-chinh/*`, `modules/tai-chinh/*`; sửa link.
- [ ] Chạy lại bộ test SQL của Tài chính (Phase 1: 25, Phase 4: 40, bảo mật: 18) → phải xanh 100%.
- [ ] **Đối soát số dư:** so số dư từng quỹ/tài khoản, công nợ tạm ứng, công nợ vay giữa DB cũ và DB mới — phải khớp tới đồng.
- [ ] Chuyển đổi: khoá ghi app Tài chính cũ → nạp dữ liệu lần cuối → mở app mới (làm cuối ngày, ngoài giờ duyệt chi).

### Giai đoạn 4 — Ghép Kho, giữ Google Sheet (4–5 ngày)
- [ ] Chép `app/(app)/*` → `(ung-dung)/kho/*`, `app/api/*` → `app/api/kho/*`, `lib` → `modules/kho/lib`.
- [ ] Thay `auth()` / session Auth.js bằng phiên Supabase: hàm `kiemTraSession()` trả về `{email, vaiTro, maKhoPhuTrach}` đọc từ `dm_nguoi_dung` theo email → phần còn lại của code Kho gần như không đổi.
- [ ] Bỏ đăng nhập Google, màn đổi mật khẩu riêng, cột `mat_khau_hash` (không còn dùng).
- [ ] Biến môi trường server: `GOOGLE_SERVICE_ACCOUNT_EMAIL`, `GOOGLE_PRIVATE_KEY`, `SHEET_ID`, `BLOB_READ_WRITE_TOKEN` (giữ Vercel Blob giai đoạn này).
- [ ] Font PDF Tinos + `outputFileTracingIncludes` cho route PDF kho.
- [ ] Bật luôn backup hằng ngày của Sheet (trước đây chưa bật).

### Giai đoạn 5 — Trang chủ tổng & tài khoản chung (3 ngày)
- [ ] Trang chủ: "Việc chờ tôi" gộp từ cả 3 (đề nghị chờ duyệt, phiếu kho chờ duyệt, chấm công chờ xác nhận…).
- [ ] Màn Hệ thống → Tài khoản: tạo/khoá/đặt lại mật khẩu, bật phân hệ cho từng người.

### Giai đoạn 6 — Nghiệm thu & chuyển hẳn (1–2 tuần chạy song song)
- [ ] Người dùng thật dùng app mới; app cũ chỉ để tra cứu.
- [ ] Gắn domain chính; redirect domain cũ.
- [ ] Sau 2–4 tuần ổn định: tắt app cũ, tạm dừng (không xoá) Supabase project Tài chính cũ.

### Giai đoạn 7 (tuỳ chọn, sau khi ổn định) — Hợp nhất sâu
- [ ] Danh mục dùng chung (mục 3.6).
- [ ] Chuyển Kho từ Google Sheet sang schema `kho` trong Postgres (giữ quy tắc: chỉ ghi thêm, tồn tính lại từ phiếu đã duyệt, số phiếu không dùng max+1) + chuyển ảnh sang Supabase Storage.
- [ ] Liên kết Kho → Tài chính, Nhân sự → Tài chính.
- [ ] Thay component shadcn của Kho bằng component chung.

**Tổng ước lượng:** giai đoạn 0–6 khoảng **5–7 tuần** làm việc (chưa tính giai đoạn 7).

---

## 5. Biến môi trường của app mới

| Nơi | Biến |
|---|---|
| Vercel (công khai) | `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` |
| Vercel (bí mật, chỉ server — cho Kho) | `GOOGLE_SERVICE_ACCOUNT_EMAIL`, `GOOGLE_PRIVATE_KEY`, `SHEET_ID`, `BLOB_READ_WRITE_TOKEN` |
| Supabase Edge Function secrets | `SB_SECRET_KEY`, `SB_PUBLISHABLE_KEY`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_GROUP_DUYET`, `TELEGRAM_GROUP_BAOCAO`, `TELEGRAM_WEBHOOK_SECRET`, `APP_URL` |
| GitHub Actions | `SUPABASE_DB_URL` (backup), `SUPABASE_ACCESS_TOKEN`, `SUPABASE_PROJECT_REF` (xoá selfie) |

Bỏ: `AUTH_SECRET`, `AUTH_GOOGLE_ID`, `AUTH_GOOGLE_SECRET`, `AUTH_URL` (Auth.js).

---

## 6. Việc định kỳ sau khi gộp

| Việc | Lịch (giờ VN) | Nguồn |
|---|---|---|
| Tổng hợp công ngày hôm trước | 00:15 | pg_cron (Nhân sự) |
| Backup DB | 01:00 | GitHub Action (Tài chính) — nay backup cả DB chung |
| Backup Google Sheet Kho | 01:00–02:00 | Apps Script (bật mới) |
| Xoá ảnh selfie > 90 ngày | 02:30 | GitHub Action (Nhân sự) |
| Báo cáo Telegram | 07:30 | pg_cron → Edge Function (Tài chính) |

---

## 7. Rủi ro chính & cách phòng

| Rủi ro | Mức | Phòng ngừa |
|---|---|---|
| Sai lệch số dư quỹ/công nợ khi chuyển DB Tài chính | Rất cao | Diễn tập trên project thử; đối soát số dư tới đồng trước khi mở app mới; giữ project cũ ≥ 1 tháng |
| Lộ dữ liệu chéo (lương, CCCD, chứng từ) giữa phân hệ | Cao | Bucket riêng + chạy bộ kiểm RLS của cả 2 app (849 + 83 kiểm tra) trên project chung |
| Hỏng lịch sử migration (từng xảy ra 16/09) | Cao | 1 repo duy nhất giữ migration; baseline mới; cấm apply qua Management API mà không ghi lịch sử |
| Người dùng Telegram bấm link cũ | Trung bình | Redirect từ domain cũ; cập nhật `APP_URL` |
| Người dùng Kho mất đăng nhập Google | Trung bình | Tạo sẵn tài khoản + mật khẩu tạm, hướng dẫn trước |
| HRM chưa được test tay (11 phase) | Trung bình | Test tay HRM ngay trong giai đoạn 2, trên app mới |
| CSS shadcn của Kho đè phân hệ khác | Thấp | Chỉ nạp trong layout `/kho`; kiểm tra giao diện 2 phân hệ còn lại |
| Supabase free bị tạm dừng / vượt dung lượng khi gộp | Trung bình | Kiểm tra dung lượng DB + storage tổng; cân nhắc gói Pro khi 3 phân hệ chạy chung |

---

## 8. Quy ước chung cho app gộp (kế thừa từ 3 app)

- Không lưu số dư/tồn kho — luôn tính từ sổ; sổ chỉ ghi thêm, sửa/huỷ phải có lý do và nhật ký.
- Quyền thực thi ở DB (RLS/RPC) hoặc ở server; ẩn nút không phải là phân quyền.
- Tiền dùng `numeric`, không dùng số thực; tham số lương/thuế lấy từ bảng `cfg_*`, không viết cứng.
- Không dùng ORM; không thêm thư viện khi chưa được chủ dự án đồng ý.
- Service key chỉ ở Edge Function, không bao giờ lên Vercel/trình duyệt.
- Giao diện, chú thích nghiệp vụ bằng tiếng Việt.
- Mỗi bước: `tsc --noEmit` + `build` trước khi báo xong.

---

## 9. Quyết định cần chủ dự án chốt trước khi bắt đầu

1. **Một app (đề xuất)** hay giữ 3 app riêng nhưng dùng chung đăng nhập?
2. **Kho giữ Google Sheet ở giai đoạn 1 (đề xuất)** hay chuyển luôn sang Postgres (thêm ~2 tuần)?
3. **Project Supabase chung = project Nhân sự `naglcxbpxnntiglrzeqx` (đề xuất)**, hay tạo project mới rồi chuyển cả hai sang? Có nâng lên gói Pro không?
4. Đồng ý **giữ shadcn trong phân hệ Kho** ở giai đoạn đầu (ngoại lệ với quy tắc "không thêm thư viện")?
5. Đường dẫn phân hệ: `/tai-chinh`, `/nhan-su`, `/kho` — có muốn tên khác?
6. Tên miền và tên hiển thị của app mới?
7. Có cần giữ **đăng nhập bằng Google** cho người dùng Kho không (Supabase hỗ trợ, cần cấu hình thêm)?
