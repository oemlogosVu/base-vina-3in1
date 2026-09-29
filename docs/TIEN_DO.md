# TIẾN ĐỘ — BASE VINA 3 IN 1

> Nhật ký theo phiên. KHÔNG ghi mật khẩu, key, token vào file này.

## Trạng thái hiện tại
- Giai đoạn: **0 — Chuẩn bị & an toàn** (đang làm, chờ chủ dự án làm các việc tay + duyệt)
- Repo: đã `git init` (nhánh `main`), **chưa commit** — chờ duyệt.
- Vercel project mới `base-vina-3in1`: **chưa tạo** — cần repo GitHub trước (chờ duyệt).

---

## 26/09/2026 — Phiên 1: Giai đoạn 0

**Đã làm**
- Đọc 3 dự án, lập kế hoạch `docs/KE_HOACH_GOP_3_TRONG_1.md`; xác nhận Kho đã commit + push `6e8ae7f`.
- Đọc Vercel (chỉ đọc): 3 project cũ, commit đang chạy, domain, tên biến môi trường.
- Xác định nhánh production thật của Tài chính = `main` `992cdd7` (KT-71). Nhánh `dung-ho-quy-cong-truong`
  (KT-72) chỉ có trên máy; DB thật dừng ở migration 55 (đã kiểm bằng truy vấn chỉ đọc).
- Đọc Supabase (chỉ đọc): số migration, dung lượng, bucket, tên khoá/secret, cron, cấu hình Auth.
- Quét bí mật 3 repo (file hiện tại + lịch sử git): kết quả trong `docs/GD0_HIEN_TRANG_VA_BI_MAT.md`.
- Viết script sao lưu (chưa chạy): `scripts/sao-luu/` + hướng dẫn `docs/SAO_LUU.md`.
  Đã chạy thử `tai-file-storage.mjs --chi-liet-ke` (chỉ đếm, không tải): khớp số file trong DB.
- Khởi tạo repo: `.gitignore` (chặn .env*, *.pem, Telegram_info*, bản sao lưu, *.xlsx), `AGENTS.md`, `CLAUDE.md`,
  chuyển kế hoạch + prompt vào `docs/`.

**Quyết định kỹ thuật tự chọn (an toàn nhất)**
- Bản sao lưu mặc định ở `F:\SaoLuu_BaseVina` (ổ C còn ~5 GB; không để trong OneDrive vì có dữ liệu cá nhân).
- Sao lưu DB qua Session pooler (IPv4) thay vì kết nối trực tiếp (IPv6, nhiều mạng gia đình không vào được).
- Tải file Storage bằng khoá quản trị lấy tạm trong bộ nhớ qua Management API — không lưu khoá ra file.
- `.gitignore` chặn luôn `*.xlsx` (file mẫu nhập liệu HRM chứa dữ liệu cá nhân thật).
- AGENTS.md: bổ sung "mọi git commit/push, tạo repo GitHub, tạo project Vercel phải hỏi trước"
  theo yêu cầu chủ dự án ngày 26/09.

**Phát hiện cần chủ dự án quyết**
- KT-72 chưa lên production (xem GĐ0 mục 1).
- Supabase Tài chính đang mở tự đăng ký tài khoản.
- App Nhân sự chạy hàm ở Mỹ (iad1) trong khi DB ở Singapore.

**Bổ sung cùng ngày — đối chiếu danh mục trùng (theo yêu cầu chủ dự án, chưa commit)**
- Viết `scripts/doi-chieu/doi-chieu-danh-muc.mjs`: đọc (read_only) DB Tài chính + Nhân sự, đọc Sheet Kho bằng
  quyền chỉ đọc, KHÔNG đọc cột hash mật khẩu. Xuất Excel vào `.local/doi-chieu/` (git bỏ qua).
- Luật ghép: MST/email/SĐT = chắc chắn; trùng tên = cần xác nhận; công trình gom theo địa danh (1 dự án ↔ nhiều kho/tổ đội);
  mã NCC chỉ tính khi tên cũng gần giống (TC tự đặt mã khác dãy kế toán).
- Kết quả tóm tắt: `docs/DOI_CHIEU_DANH_MUC.md`. Chưa ghi gì vào dữ liệu thật.

**Còn chờ**
- Chủ dự án: chạy sao lưu, xử lý bí mật B1–B8, chốt tên/domain/gói/màu.
- Duyệt: tạo project Vercel `base-vina-3in1`.

## 28/09/2026 — Tạo repo GitHub (chủ dự án duyệt)
- Tạo repo riêng tư `oemlogosVu/base-vina-3in1`, commit đầu `38b40f3` (tài liệu + script, đã quét không có bí mật), push `main`.
- Quy tắc: Claude Design chỉ gửi Pull Request, không đẩy thẳng `main` (ghi vào AGENTS.md mục 5).
- Chưa khoá nhánh `main` trên GitHub (thao tác tự động bị máy chặn) → chủ dự án tự bật trên trang GitHub.
- Phát hiện: repo GitHub cũ còn file chứa mật khẩu — Tài chính `docs/TIEN_DO.md`, Nhân sự `scripts/kiem-tra-rls-*.mjs` (5 file).
  KHÔNG kết nối Claude Design vào 3 repo cũ. Cần đổi các mật khẩu này (xem GĐ0 mục B3).

## 28/09/2026 — Bộ giao diện chuẩn (Claude Design)
- Claude Design dựng bộ giao diện trên claude.ai (không đẩy lên GitHub). Chép bản cố định vào
  `design/he-thong-giao-dien/` (65 file, chỉ dữ liệu mẫu giả; nguồn + phiên bản ghi ở `NGUON.md`).
- Chủ dự án duyệt: màu nhấn phương án B; không modal bắt buộc ở Tài chính/khung chung/Hệ thống, Nhân sự + Kho
  giữ hộp thoại đến GĐ7 (Kho có 9 file, Nhân sự 2 file đang dùng hộp thoại); tính năng Nhân sự mới trong bản vẽ
  (che CCCD/STK ở máy chủ, nhật ký xem dữ liệu nhạy cảm… — app Nhân sự hiện CHƯA có) để duyệt riêng sau GĐ6.

**Danh sách chờ duyệt sau GĐ6 — tính năng Nhân sự mới từ bộ giao diện**
- [ ] Che CCCD, số tài khoản (chỉ 4 số cuối) — máy chủ che theo quyền người xem.
- [ ] Nhật ký mỗi lần xem đầy đủ lương / CCCD / số tài khoản.
- [ ] Lương không hiện ở trang chủ, danh sách nhân viên, huy hiệu, thông báo, Telegram (kiểm tra app hiện tại).
- [ ] Chấm công tổ đội mặc định 1 công; bảng công đã xác nhận muốn sửa phải có lý do + nhật ký.
- [ ] Ảnh selfie không dùng làm ảnh đại diện; nén ảnh trước khi gửi.
- [ ] Kỳ lương đã chốt → tạo nháp đề nghị chi lương bên Tài chính (kế hoạch mục 3.6).

## 28/09/2026 — Sao lưu + Vercel (chủ dự án duyệt)
- Quyết định: KHÔNG đổi các mật khẩu bị lộ (chủ dự án chấp nhận rủi ro); Supabase gói **Free**.
- Sao lưu vào `F:\SaoLuu_BaseVina`: Storage Tài chính `chung-tu` 153 file, Nhân sự `to-doi-cham-cong` 105 +
  `chung-tu` 33 + `attendance-selfies` 0 (lỗi 0); ảnh Kho Vercel Blob 107 file (lỗi 0; token lấy tạm bằng
  `vercel env pull` ra file tạm, đã xoá).
- CHƯA sao lưu: database 2 project (máy chưa cài pg_dump 17, script cần chủ dự án gõ mật khẩu DB),
  Google Sheet Kho (làm tay). Chưa chép bản sao lưu sang nơi thứ hai.
- Tạo project Vercel `base-vina-3in1` (team trieu-vu), link repo này, nối GitHub `oemlogosVu/base-vina-3in1`.
  `vercel.json`: region `sin1`, TẮT tự deploy khi push `main` (deploy production phải hỏi trước).
  Nhánh khác vẫn tự tạo bản preview.

## 29/09/2026 — Project Supabase THỬ (tài khoản riêng)
- Free chỉ 2 project/tài khoản (đã dùng hết) → chủ dự án tạo tài khoản Supabase riêng cho bản thử
  (rủi ro điều khoản Supabase đã báo chủ dự án). Project `base-vina-3in1-thu` = `rgcimlgfuwjxjapefzyj`, ap-southeast-1, Postgres 17.6.
- Kiểm tra chỉ đọc: kết nối OK; token thử chỉ thấy project thử; DB trống (0 bảng, 0 tài khoản, 0 kho file).
- Quyết định: dữ liệu thử = dữ liệu THẬT (1a); mật khẩu = một mật khẩu thử chung cho mọi tài khoản (2b).
- Điều kiện trước khi nạp dữ liệu: có bản sao lưu DB (pg_dump).

## 29/09/2026 — Sao lưu DB Nhân sự + nạp vào project THỬ (chủ dự án duyệt kế hoạch)
- Công cụ: PostgreSQL 17.6 bản giải nén ở `F:\pgsql` (không cài vào Windows). Kết nối thẳng `db.<ref>.supabase.co`
  qua IPv6 (Session pooler báo sai mật khẩu dù mật khẩu đúng). Chủ dự án đặt lại mật khẩu DB Nhân sự.
- Sao lưu DB Nhân sự: `F:\SaoLuu_BaseVina\db_2026-09-29_0958` — 1.458 mục, có auth.users. DB Tài chính: CHƯA (chưa có mật khẩu).
- Nạp vào project thử bằng `scripts/ban-thu/nap-nhan-su-vao-ban-thu.ps1` (khóa an toàn theo mã project thử):
  public đủ 37 bảng / 1.774 dòng — khớp DB thật từng bảng; 144 policy, 37 bảng bật RLS, 88 hàm, 32 trigger,
  71 migration; 4 tài khoản + 4 identities; 3 bucket + 3 policy storage; trigger on_auth_user_created.
  KHÔNG có pg_cron (không tự tổng hợp công), không Edge Function (không gửi Telegram).
- Sự cố đã xử lý: auth.identities nạp trước auth.users → lỗi khóa ngoại; đã nạp lại riêng, script sửa thứ tự
  và sửa cách đếm lỗi (lần đầu báo 0 lỗi sai).
- Mật khẩu thử chung (MAT_KHAU_THU) đặt cho 4/4 tài khoản; đăng nhập thử qua API Auth 4/4 OK;
  0 tài khoản trong bản thử còn giữ mật khẩu thật.
- File: `scripts/ban-thu/tai-file-len-ban-thu.mjs` tải lên bản thử `chung-tu` 36, `to-doi-cham-cong` 121,
  `attendance-selfies` 0 — khớp bản thật (sao lưu file bổ sung ngày 29/09: NS +19, TC +19 file mới).
- Lưu ý: bản thử là ảnh chụp dữ liệu lúc 09:58 ngày 29/09; dữ liệu thật phát sinh sau đó chưa có trong bản thử.

## 29/09/2026 — ĐÓNG Giai đoạn 0 (chủ dự án duyệt chuyển giai đoạn)
Việc tồn, làm song song, KHÔNG chặn GĐ1–2:
- [ ] Sao lưu DB Tài chính (thiếu biến `SUPABASE_DB_PASSWORD_TAICHINH`) — BẮT BUỘC xong trước GĐ3.
- [ ] Sao lưu Google Sheet Kho (làm tay, docs/SAO_LUU.md mục 6).
- [ ] Chép `F:\SaoLuu_BaseVina` sang nơi thứ hai.
Quyết định cho GĐ1: bản preview nối vào project THỬ (không nối DB Nhân sự thật, không sửa Redirect URLs project thật).
