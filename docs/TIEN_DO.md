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

## 29/09/2026 — Giai đoạn 1: khung app (đang làm)
- Next.js 16.3.6 + React 19.2.8 + Tailwind v4 + TS strict; alias `@/*`, `@tc/*`, `@ns/*`, `@kho/*`. Thư viện: chỉ
  những gì 2 app cũ đang dùng (supabase-js, @supabase/ssr, vitest) — không thêm thư viện mới.
- `src/shared/`: supabase (env/client/server/proxy — chép Tài chính), `auth/id-dang-nhap` (chép Tài chính, KHÔNG đổi
  quy đổi SĐT), `auth/phien` (getUser), `an-toan-duong-dan` (chép safe-path Nhân sự, chặt hơn bản Tài chính),
  `phan-he` (danh sách 4 phân hệ; `layPhanHeDuocPhep` GĐ1 trả đủ 4 — phân quyền thật ở GĐ5), `ui/*` (chép Tài chính).
- `ui/hien-thi.tsx`: chỉ chép phần không dính tiền (The, Pill, Bang, ThongBao, TrangThaiTrong, KhungChoTai).
  Tien/OSoLieu/ThanhTienDo/PillTrangThai dùng lib tiền của Tài chính → chép cùng GĐ3.
- `globals.css` = bản Tài chính + khối "MỞ RỘNG 3 TRONG 1" (bộ chọn phân hệ, dải màu nhấn) ghi HEX theo từng phân hệ.
- Trang: /dang-nhap (chép Tài chính), /doi-mat-khau (xử lý của Nhân sự: bắt nhập lại mật khẩu cũ; giao diện Tài chính;
  đặt ở src/app/doi-mat-khau theo cấu trúc bắt buộc — có nút "Về trang chủ", không nằm trong khung),
  khung (ung-dung) + trang chủ rỗng + /them (điện thoại) + 4 trang giữ chỗ phân hệ.
- Kiểm tra: tsc sạch · eslint 0 lỗi · vitest 15/15 · next build OK · chạy thử máy (project thử) 13/13 luồng.
- Chạy thử trên máy dùng `.env.local` trỏ project THỬ (git bỏ qua).
- Vercel (chủ dự án duyệt): thêm `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` (project THỬ, loại config,
  CHỈ Preview). Commit `e3d897c` trên nhánh `giai-doan-1`.
- Sự cố: lần dựng tự động đầu tiên từ nhánh `giai-doan-1` bị Vercel gắn target **production** (project chưa từng có bản
  production; cấu hình productionBranch vẫn là `main`) → dựng LỖI vì thiếu biến (biến chỉ có ở Preview) → không có gì
  lên production (tên miền production trả 404). Đã dựng lại đích danh Preview qua API `/v13/deployments` (gitSource
  nhánh giai-doan-1, không đặt target) → Ready. Lưu ý các lần sau: kiểm target trước khi báo link.
- Preview: https://base-vina-3in1-git-giai-doan-1-trieu-vu.vercel.app (Vercel Authentication — phải đăng nhập Vercel).
- Còn lệch cấu hình project so với AGENTS.md mục 5: Framework Preset "Other" (vercel.json đã ghi nextjs), Function
  Region project = iad1 (vercel.json đã ghi sin1). Sửa trong Settings khi chủ dự án duyệt.

## ⏸ ĐIỂM DỪNG — 29/09/2026 (chủ dự án yêu cầu tạm dừng)
Đang ở: **Giai đoạn 1 — đã dựng xong, CHỜ chủ dự án bấm thử preview**. Chưa duyệt sang GĐ2.
Nhánh làm việc: `giai-doan-1` (chưa gộp vào `main`). Preview: base-vina-3in1-git-giai-doan-1-trieu-vu.vercel.app
(đăng nhập Vercel mới mở được; đăng nhập app bằng tài khoản Nhân sự + MAT_KHAU_THU).

Việc chờ chủ dự án quyết khi quay lại:
1. Kết quả bấm thử preview (luồng a–f trong báo cáo GĐ1) → duyệt/không duyệt sang GĐ2.
2. Duyệt sửa cấu hình project Vercel: Framework → Next.js, Function Region → sin1.
3. Cho Chủ tịch/KTT thử: tắt Vercel Authentication cho preview HAY tạo link chia sẻ tạm.
4. Việc tồn GĐ0: sao lưu DB Tài chính (trước GĐ3), Google Sheet Kho, bản sao lưu thứ hai.
5. File `Key.txt` ở thư mục gốc (chưa mở, KHÔNG commit) — chủ dự án tự xử lý.

Trạng thái trên máy (không nằm trong git):
- `F:\pgsql` (PostgreSQL 17.6), `F:\SaoLuu_BaseVina` (sao lưu DB Nhân sự 29/09 09:58 + file Storage + ảnh Kho).
- `.env.local` trỏ project THỬ. Biến User: SUPABASE_ACCESS_TOKEN_THU, SUPABASE_DB_PASSWORD_THU, MAT_KHAU_THU,
  SUPABASE_DB_PASSWORD (Nhân sự, đã đặt lại 29/09). Thiếu SUPABASE_DB_PASSWORD_TAICHINH.
- Project thử `rgcimlgfuwjxjapefzyj`: dữ liệu Nhân sự lúc 09:58 29/09; Free tự tạm dừng sau 7 ngày không dùng
  (vào Dashboard bấm Restore).

Bắt đầu phiên sau: `git checkout giai-doan-1`, `npx vercel whoami`, đọc AGENTS.md + mục này.

## 30/09/2026 — Chuẩn hoá database (chủ dự án duyệt, làm TRƯỚC GĐ2)
- GĐ1 đã nghiệm thu. Trước GĐ2: chuẩn hoá DB phủ cả 3 dự án, dựng trên project THỬ — thiết kế
  `docs/KE_HOACH_DU_LIEU_DUNG_CHUNG.md` (đã duyệt). Kho vào DB (schema `kho`), đổi AGENTS.md §2.3.
- Rà soát (chỉ đọc) DB thật: TC 31 bảng/66 hàm/66 policy; NS 37 bảng/88 hàm/147 policy. Hàm dùng danh mục: TC 16, NS 43;
  hàm GHI danh mục: TC 1, NS 6 → dùng VIEW tương thích, không viết lại logic tiền/lương.
- Phát hiện: khóa bot Telegram TC nằm TRONG bảng `cau_hinh_he_thong` → bản thử để trống cột này.
- Bản nháp migration 33 (đổi chung_tu → chung_tu_fmb, 29/08) đã cũ → sinh lại từ DB Tài chính hiện tại.
- Quyết định 30/09: STK trùng lấy TC; NCC001/NCC002 (TC) ngừng dùng; "XD Anh Nam" = nhà thầu phụ.
- Chờ: mật khẩu DB Tài chính.
- 30/09: sao lưu DB Tài chính `F:\SaoLuu_BaseVina\db_2026-09-30_0859` (1.309 mục, có auth.users). Chủ dự án đã
  đặt lại mật khẩu DB Tài chính (+ cập nhật secret SUPABASE_DB_URL repo Finance).
- Migration `20260930000001_tai_chinh_goc.sql`: sinh từ DB Tài chính hiện tại (pg_restore -s, chỉ public+private
  + 3 policy storage), đổi chung_tu → chung_tu_fmb (65 chỗ) + bucket chung-tu-fmb. Dò trùng tên: chỉ `chung_tu`,
  `chung_tu_pkey`. DB Tài chính KHÔNG gọi HTTP ra ngoài (Telegram do app/Edge Function gửi).
  ĐÃ CHẠY trên project THỬ (cấu trúc, chưa dữ liệu): 68 bảng public, 22 view, 37 hàm private, bucket chung-tu-fmb.
- Migration `20260930000003_kho.sql`: chạy thử trong giao dịch rồi huỷ — đạt (tồn khớp công thức app Kho, chặn xoá/sửa).
- 30/09: chủ dự án quyết thêm: thông tin nhạy cảm GIỮ 2 bảng riêng; công ty lưu THEO TỪNG PHÂN HỆ; công ty trùng giữ
  id `cong_ty` Tài chính (ghi vào KE_HOACH_DU_LIEU_DUNG_CHUNG.md mục 1).
- **Lỗ hổng phát hiện & đã sửa trên bản thử:** project Supabase mới tự cấp ALL cho anon/authenticated trên mọi bảng;
  pg_restore không thu hồi → bản thử có anon đủ quyền trên 90 bảng (thật: anon KHÔNG có quyền bảng nào).
  Sửa bằng migration `20260930000002_quyen_truy_cap.sql` SINH từ ACL thật (scripts/db/sinh-quyen-truy-cap.mjs):
  thu hồi rồi cấp lại đúng như thật. Kết quả so với DB thật: bảng/view/sequence 91/91, quyền theo cột 42/42,
  hàm 154/154 khớp; anon 0 bảng. (Lần sinh đầu sai cú pháp "grant INSERT, UPDATE (cột)" = INSERT cả bảng → đã sửa.)
  Bài học cho "làm thật": mọi bảng Tài chính tạo trong project Nhân sự cũng phải chạy migration quyền này.
- Đánh số lại: 000001 tài chính gốc · 000002 quyền · 000004 danh mục chung (đang viết) · 000005 kho.
- 30/09: chủ dự án xác nhận file đối chiếu (sửa 11:11): 2 công ty, 7 người TC↔NS (+ NV0011 TC↔Kho), 5 NCC, 5 dự án
  (kho/công trường/tổ đội) — ĐÚNG. 4 tài khoản thử Kho (@basevina.test): BỎ. KHO01: kho tổng, không công trình.
  BP01–04: giữ riêng ở Kho. NV0015 Phạm Văn Nghị, NV0020 Nguyễn Bá Hùng: "có hồ sơ NS dưới tên/mã khác" — CHỜ mã NS
  (không tìm thấy hồ sơ tên gần giống) → tạm chuyển như người chỉ ở TC.
- Migration `20260930000004_danh_muc_chung.sql` (bảng chung + view tương thích; ghép theo MÃ, không dữ liệu cá nhân).
  Chạy thử trên HRM data (giao dịch rồi huỷ): số liệu trước = sau (89/11/2/34/0); quản trị NS nhìn qua view thấy
  đúng như trước; thêm/sửa nhân viên qua view `employees` chạy; anon bị từ chối bảng `nguoi`. Bản thử không đổi.
- 30/09: chủ dự án quyết NV0015, NV0020 → tạo hồ sơ Nhân sự tối thiểu (mã NV tạm = mã TC, không chấm công),
  HCNS bổ sung sau (gop.nguoi_them_ns trong migration 000004).
- **Database mới đã DỰNG trên project THỬ** (chủ dự án chốt "database đã dựng xong" 30/09): chạy thật 000004 + 000005.
  68 bảng public, 29 view (7 view tương thích), 13 bảng kho, nguoi 89 = hồ sơ NS 89, anon 0 quyền. Lịch sử migration
  bản thử: 71 NS + 4 mới (000001, 000002, 000004, 000005).
- Dữ liệu trên bản thử: CHỈ Nhân sự (29/09 09:58). Dữ liệu Tài chính + Kho nạp ở GĐ3/GĐ4: dựng lại bản thử từ đầu
  theo đúng thứ tự (NS → 000001 → 000002 → nạp TC → 000004 → 000005 → nạp Kho) = diễn tập đầy đủ ngày gộp thật.

## 30/09/2026 — Giai đoạn 2: ghép Nhân sự (đang làm, nhánh `giai-doan-2`)
- Chủ dự án duyệt: gộp `giai-doan-1` + `chuan-hoa-db` vào `main` (fast-forward, main = a3e93ac; không có bản production
  nào được dựng — tên miền production vẫn 404). Agent tự sửa cài đặt Vercel: Framework Next.js, region sin1.
- Chủ dự án duyệt cài 4 Edge Function Nhân sự lên project THỬ: cham-cong, anh-cham-cong-to, chung-tu (kèm 2 font
  Roboto — đã xác nhận tải lên), quan-tri-tai-khoan — ACTIVE, verify_jwt = true. Chép từ HRM main 9a0b9a8, không đổi
  mã; chỉ dùng biến có sẵn của Supabase (SUPABASE_URL/ANON/SERVICE_ROLE), không Telegram.
- Deploy bằng `npx supabase functions deploy <tên> --project-ref rgcimlgfuwjxjapefzyj --use-api`
  (SUPABASE_ACCESS_TOKEN = token THỬ, chỉ trong biến môi trường tiến trình).
- Chép mã Nhân sự bằng `scripts/port/chep-nhan-su.mjs` (đọc thẳng HRM main 9a0b9a8, chạy lại được): 96 file
  (26 màn → `(ung-dung)/nhan-su/…`, lib/components/types → `src/modules/nhan-su`, 7 file test). Đổi 172 chỗ đường dẫn
  (danh sách: `scripts/port/bao-cao-duong-dan-nhan-su.txt`): /nhan-su→/nhan-su/ho-so, /ho-so→/nhan-su/ho-so-cua-toi,
  /cham-cong|/luong|/quan-tri|/sua-chua-cong|/to-doi → /nhan-su/…, /login→/dang-nhap. Không đổi logic.
- Sửa khi chép (script tự làm, xem trong script): KhungTrang chỉ còn tiêu đề + nội dung (khung chung vẽ thanh bên,
  đăng xuất, đổi mật khẩu); đăng xuất dùng hành động chung; CSS HRM → `src/modules/nhan-su/nhan-su.css` bọc trong
  `.ns-scope` (HRM trùng class .the/.bang/.pill/.noi-dung với phần chung), oklch → hex (Android cũ), nút chính navy.
  globals.css chung thêm `@custom-variant dark` (tắt ~338 chỗ dark:* như HRM đã làm).
- Menu Nhân sự trong thanh bên chung: `src/app/(ung-dung)/menu-phan-he.ts` đọc `tabsChoPhep()` của HRM (theo vai trò +
  tab tick từng người). Bộ chọn phân hệ: Nhân sự chỉ hiện khi có dòng `quyen_phan_he` 'ns' (`src/shared/phan-he-duoc-phep.ts`).
- Kiểm tra: tsc 0 lỗi · eslint 0 lỗi (1 cảnh báo) · vitest 150/150 (135 test HRM + 15) · next build OK (26 màn NS).
  Chạy thử máy (project THỬ, 4 tài khoản): 3 quản trị mở đủ 27/27 màn; tài khoản nhân viên: menu đúng tab được phép,
  8 màn quản lý đều chuyển về /nhan-su/ho-so-cua-toi, không lộ bảng dữ liệu. Nhật ký máy chủ: 0 lỗi.
- Build lỗi EPERM khi OneDrive khoá `.next` → xoá `.next` rồi build lại.
