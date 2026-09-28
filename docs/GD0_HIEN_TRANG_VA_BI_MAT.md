# GIAI ĐOẠN 0 — HIỆN TRẠNG 3 APP CŨ, BÍ MẬT CẦN XỬ LÝ, ÁNH XẠ BIẾN MÔI TRƯỜNG

> Lập ngày 26/09/2026. Mọi số liệu đọc trực tiếp từ Vercel API, Supabase Management API (chỉ đọc)
> và git. Tài liệu này **không chứa giá trị bí mật nào**.

---

## 1. Vercel — 3 project cũ (team `trieu-vu`, gói Hobby)

| | Tài chính | Nhân sự | Kho |
|---|---|---|---|
| Project | `finance-manager-base-vina` | `hr-base-vina` | `inventory-manager-basevina` |
| Domain | finance-manager-base-vina.vercel.app | hr-base-vina.vercel.app | inventory-manager-basevina.vercel.app |
| Repo GitHub | oemlogosVu/Finance-manager-BaseVina | oemlogosVu/hr-base-vina | oemlogosVu/inventory-manager-basevina |
| Nhánh production | `main` | `main` | `main` |
| Commit đang chạy | **`992cdd7`** KT-71 | `9a0b9a8` (v0.32.2) | `6e8ae7f` (thủ kho tự duyệt) |
| Deploy cuối | 21/09/2026 14:11 | 15/09/2026 18:20 | 26/09/2026 10:59 |
| Vùng chạy hàm | `sin1` (do vercel.json; cấu hình project là iad1) | **`iad1` — Mỹ** (không có vercel.json) | `sin1` |
| Cron Vercel | không | không | không |
| Redirect/rewrite | không | không (chỉ header bảo mật trong next.config) | không |
| Tên biến môi trường | `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` | `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` | `GOOGLE_SERVICE_ACCOUNT_EMAIL`, `GOOGLE_PRIVATE_KEY` (tách riêng prod/preview/dev), `SHEET_ID`, `BLOB_READ_WRITE_TOKEN`, `AUTH_SECRET`, `AUTH_URL`, `AUTH_GOOGLE_ID`, `AUTH_GOOGLE_SECRET` |

**Nhánh production thật của Tài chính = `main` (`992cdd7`, KT-71).**
Nhánh `dung-ho-quy-cong-truong` (commit `01ff3b5`, KT-72 "Đứng hộ quỹ") chỉ nằm trên máy: **chưa push lên
GitHub, chưa deploy, migration 56 chưa chạy lên DB** (DB thật dừng ở migration 55, không có cột
`lan_tra_tien.dung_ho_quy`). → Cần chủ dự án quyết: đưa KT-72 lên app cũ trước khi gộp, hay gộp từ KT-71
rồi làm KT-72 trên app mới. Agent **không merge gì**.

Ghi chú: app Nhân sự chạy hàm ở Mỹ trong khi DB ở Singapore → mỗi thao tác chậm hơn cần thiết.
App mới sẽ đặt `sin1`. Không sửa project cũ.

**Mức dùng tháng:** API usage của Vercel không mở cho gói Hobby (trả lỗi 400). Chủ dự án xem tại
Vercel Dashboard → team trieu-vu → **Usage**. Agent sẽ nhắc kiểm tra cuối mỗi giai đoạn.

## 2. Supabase — 2 project

| | Tài chính `eodrpyedatohsovobsxj` | Nhân sự `naglcxbpxnntiglrzeqx` |
|---|---|---|
| Tên / vùng / Postgres | thuchi-staging / ap-southeast-1 / 17.6 | hr-base-vina / ap-southeast-1 / 17.6 |
| Migration ghi nhận | 53 (file 01→55, thiếu 31, 33 có chủ đích; lịch sử lệch file 1 dòng — xử lý ở 3a) | 71 (khớp 71 file) |
| Dung lượng DB | 19 MB | 18 MB |
| Storage | `chung-tu` 144 file / 40 MB | `to-doi-cham-cong` 105 / 23 MB, `chung-tu` 33 / 0,8 MB, `attendance-selfies` 0 |
| Tài khoản | 7 (4 đăng nhập SĐT, 3 gmail) | 4 (3 gmail, 1 @base.vina) |
| Edge Function | tao-tai-khoan, notify-telegram, daily-report, telegram-webhook (không JWT), gui-pdf-telegram, dat-lai-mat-khau, xoa-tai-khoan | cham-cong, anh-cham-cong-to, quan-tri-tai-khoan, chung-tu |
| pg_cron | `daily-report-0730-vn` (dùng khoá publishable — không phải bí mật) | `tong-hop-cong-hang-ngay` |
| Khoá API | anon + service_role (kiểu cũ) + publishable + secret (kiểu mới) | như bên trái |
| **Tự đăng ký tài khoản** | **ĐANG MỞ** ⚠ | Tắt |
| Site URL | http://localhost:3000 | http://localhost:3000 |

Gộp 2 DB: tổng ~37 MB DB + ~64 MB file → **vẫn nằm trong gói Free** (500 MB DB, 1 GB storage).

## 3. Bí mật đã lộ / cần xử lý

Quét toàn bộ file hiện tại + lịch sử git (mọi nhánh) của 3 repo. **Không tìm thấy** service_role key,
secret key, access token Supabase, GitHub token, Blob token trong git. Các mục cần xử lý:

| # | Mức | Nơi | Loại bí mật | Cần làm | Ai làm |
|---|---|---|---|---|---|
| B1 | **Cao** | Tài chính `Telegram_info.md` (không vào git, nhưng đồng bộ OneDrive) | Token bot Telegram + ID nhóm chat | @BotFather → `/revoke` → lấy token mới → cập nhật secret `TELEGRAM_BOT_TOKEN` ở Supabase Tài chính → đăng ký lại webhook (kèm `TELEGRAM_WEBHOOK_SECRET`) → xoá file hoặc chuyển ra khỏi OneDrive | Chủ dự án bấm BotFather; agent làm 2 bước sau (khi được duyệt) |
| B2 | **Cao** | Tài chính `docs/TIEN_DO.md` dòng 98–99 (**đã lên GitHub**, trong lịch sử từ commit `01faad4`) | Mật khẩu dạng chữ của **tài khoản admin cố định** | Đổi mật khẩu tài khoản admin trên app Tài chính; sau đó xoá dòng trong file (lịch sử git vẫn còn nên **đổi mật khẩu mới là cách sửa thật**) | Chủ dự án đổi MK; agent sửa file (khi được duyệt) |
| B3 | Thấp | Tài chính `docs/TIEN_DO.md` dòng 98, 525, 567, 614; `YEU_CAU_TEST.md` dòng 16 | Mật khẩu chung tài khoản demo | DB thật không có tài khoản demo (@demo.local) → chỉ xoá khỏi tài liệu | Agent (khi được duyệt) |
| B4 | **Cao** | Tài chính — theo `docs/RESET_JWT_SECRET.md` | service_role key kiểu cũ đã lộ qua lịch sử phiên bản OneDrive | Tắt khoá kiểu cũ (legacy JWT) — xem mục 4 vì **ảnh hưởng app đang chạy** | Chủ dự án duyệt; agent làm theo danh sách mục 4 |
| B5 | **Cao** | Tài chính — cấu hình Auth | Không phải bí mật: **tự đăng ký đang mở** → ai có địa chỉ app đều tạo được tài khoản (chưa xem được dữ liệu vì RLS đòi hồ sơ nhân viên, nhưng là lỗ hổng) | Tắt "Allow new users to sign up". Tài khoản vẫn tạo được qua màn Quản trị (dùng khoá quản trị) | Chủ dự án duyệt; 1 thao tác |
| B6 | Trung bình | Nhân sự `scripts/kiem-tra-rls-p1/p2/p3/that/to-doi.mjs`, `kiem-tra-chung-tu.mjs`, `kiem-tra-sua-chua-cong.mjs` (**đã lên GitHub**) | Mật khẩu tài khoản test viết cứng | Kiểm tra tài khoản test còn trên DB thật không (DB có 4 tài khoản: 3 gmail + 1 @base.vina); nếu còn → đổi MK/khoá. Khi chép sang repo mới: đọc MK từ biến môi trường | Chủ dự án xác nhận 4 tài khoản là ai; agent sửa khi chép (GĐ2) |
| B7 | Trung bình | Kho `.env.local` (không vào git, đồng bộ OneDrive) | Private key Service Account Google, Google OAuth client secret, AUTH_SECRET, Blob token | Giữ tạm (cần cho app Kho). Sau GĐ4: xoá OAuth client `vattu-kho-web` + AUTH_SECRET. Service Account `claude-agent@ecommercev2-494609` **dùng chung với các dự án khác** → đề xuất tạo SA riêng cho Kho ở GĐ4 | Agent đề xuất ở GĐ4 |
| B8 | Trung bình | Google Sheet Kho, tab `dm_nguoi_dung` cột F | Hash mật khẩu người dùng Kho | Rà danh sách người được chia sẻ Sheet ngay; sau nghiệm thu GĐ4 xoá cột hash | Chủ dự án |
| B9 | Thấp | Biến môi trường User trên máy này | `SUPABASE_ACCESS_TOKEN` (toàn quyền mọi project), `SUPABASE_DB_PASSWORD` | Giữ để làm việc; **đổi token khi kết thúc dự án gộp** | Chủ dự án |
| B10 | Thấp | Nhân sự `.env copy.local` | Bản trùng của .env.local (chỉ khoá công khai) | Xoá cho gọn | Chủ dự án |

Báo nhầm đã loại: đoạn `private_key` trong `Inventory/docs/03-kien-truc.md`, `05-setup.md` là mẫu giữ chỗ;
chuỗi kết nối Postgres trong `HRM/docs/NHAT-KY.md` là mẫu; các dòng trong code đăng nhập/đổi mật khẩu là tên biến.

## 4. Nếu đổi/thu hồi khoá — phải cập nhật lại ở đâu (DANH SÁCH CHỜ DUYỆT)

| Việc | Ảnh hưởng tới | Phải cập nhật | Thứ tự an toàn |
|---|---|---|---|
| Đổi token bot Telegram (B1) | Thông báo duyệt, nút duyệt qua bot, báo cáo 7:30, gửi PDF tháng | Supabase Tài chính → Edge secret `TELEGRAM_BOT_TOKEN`; gọi `setWebhook` tới `telegram-webhook` với `secret_token` cũ | Làm ngoài giờ duyệt; ~10 phút gián đoạn thông báo. Không đụng Vercel |
| Tắt khoá JWT kiểu cũ của Tài chính (B4) | **App Tài chính trên Vercel đang dùng anon key kiểu cũ** → tắt là app đăng nhập lỗi ngay | 1) Vercel `finance-manager-base-vina`: đổi `NEXT_PUBLIC_SUPABASE_ANON_KEY` (production + preview) sang khoá **publishable** → redeploy. 2) Edge Function đã ưu tiên `SB_SECRET_KEY`/`SB_PUBLISHABLE_KEY` (đã có) → kiểm tra log sau khi tắt. 3) Job cron 7:30 đã dùng khoá publishable → không đổi. 4) Script máy trong `.env.local` nếu có | Đổi env Vercel + redeploy → kiểm tra đăng nhập → mới tắt khoá cũ. Nếu lỗi: bật lại khoá cũ (Supabase cho bật lại). **Là thao tác trên project cũ → cần chủ dự án duyệt riêng** |
| Tắt tự đăng ký (B5) | Không ảnh hưởng người dùng hiện có, không ảnh hưởng tạo tài khoản qua Quản trị | Supabase Tài chính → Authentication → Sign In / Providers → tắt "Allow new users to sign up" | Làm bất kỳ lúc nào |
| Đổi mật khẩu admin (B2), khoá tài khoản test (B6) | Không | — | Bất kỳ lúc nào |
| Đặt lại mật khẩu DB (nếu quên, để sao lưu) | Backup hằng đêm GitHub Actions (Tài chính) | GitHub secret `SUPABASE_DB_URL` (repo Finance); biến `SUPABASE_DB_PASSWORD` trên máy (HRM) | Sau khi đổi, chạy thử workflow backup |

Lưu ý: vì DB Tài chính sẽ chuyển sang project chung ở GĐ3, **khoá của project Tài chính cũ sẽ bỏ hẳn sau
GĐ3**. Tuy vậy B4 vẫn nên làm ngay vì service_role key lộ = toàn quyền đọc/ghi/xoá DB Tài chính thật.

## 5. Ánh xạ biến môi trường: project cũ → project mới `base-vina-3in1`

| Biến (project cũ) | Nguồn | Project mới | Giai đoạn | Ghi chú |
|---|---|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | Nhân sự | **GIỮ** | GĐ1 | Trỏ project chung `naglcxbpxnntiglrzeqx` |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Nhân sự | **GIỮ** (giá trị nên là khoá **publishable** mới thay vì anon kiểu cũ) | GĐ1 | Giữ tên biến để khỏi sửa code 2 phân hệ |
| `NEXT_PUBLIC_SUPABASE_URL` | Tài chính | **BỎ** | — | Trỏ project Tài chính cũ, sẽ ngừng dùng |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Tài chính | **BỎ** | — | như trên |
| `GOOGLE_SERVICE_ACCOUNT_EMAIL` | Kho | **GIỮ** | GĐ4 | Chỉ server; kiểm tra prod/preview/dev cùng giá trị |
| `GOOGLE_PRIVATE_KEY` | Kho | **GIỮ** | GĐ4 | Chỉ server; giữ đúng ký tự xuống dòng |
| `SHEET_ID` | Kho | **GIỮ** | GĐ4 | Preview nên trỏ **bản sao Sheet** để thử, không trỏ Sheet thật |
| `BLOB_READ_WRITE_TOKEN` | Kho | **GIỮ** (nối Blob store hiện có) | GĐ4 | Không tạo store mới → ảnh cũ vẫn xem được |
| `AUTH_SECRET`, `AUTH_URL`, `AUTH_GOOGLE_ID`, `AUTH_GOOGLE_SECRET` | Kho | **BỎ** | — | Auth.js thay bằng Supabase |
| `VERCEL_OIDC_TOKEN` | (Vercel tự sinh) | tự có | — | Không thêm tay |

Biến **không** nằm trên Vercel (chuyển ở GĐ2/GĐ3): Edge secrets Tài chính (`TELEGRAM_*`, `APP_URL`,
`SB_SECRET_KEY`, `SB_PUBLISHABLE_KEY`) → Edge secrets của project chung, `APP_URL` đổi sang domain mới;
GitHub secret `SUPABASE_DB_URL` (backup) → trỏ project chung; `SUPABASE_ACCESS_TOKEN`, `SUPABASE_PROJECT_REF`
(dọn selfie) → repo mới.

## 6. Việc chủ dự án cần làm tay (theo thứ tự đề xuất)

1. **Quyết định KT-72** (nhánh "Đứng hộ quỹ" chưa lên production) — xem mục 1.
2. Cài pg_dump 17 và **chạy sao lưu** theo `docs/SAO_LUU.md` (DB + file + ảnh Kho + Sheet).
3. **Tắt tự đăng ký** ở Supabase Tài chính (B5) — hoặc cho agent làm.
4. **Đổi mật khẩu tài khoản admin cố định** của Tài chính (B2).
5. **Thu hồi token bot Telegram** qua @BotFather (B1), gửi token mới cho agent qua cách an toàn
   (agent sẽ hướng dẫn nhập thẳng vào Supabase, không gửi qua chat).
6. Duyệt kế hoạch tắt khoá kiểu cũ của Tài chính (B4, mục 4).
7. Xác nhận 4 tài khoản trên DB Nhân sự là ai; khoá tài khoản test nếu còn (B6).
8. Rà người được chia sẻ Google Sheet Kho (B8).
9. Xem mức dùng Vercel tháng này ở Dashboard → Usage.
10. Chốt các mục «CHƯA CHỐT» trong AGENTS.md: gói Supabase, tên hiển thị, domain, màu nhấn 3 phân hệ.
