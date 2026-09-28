# PROMPT DỰNG APP "BASE VINA 3 IN 1"

> Dùng cho Claude Code / Codex. Gồm 2 phần:
> - **Phần A – Prompt gốc:** lưu thành `AGENTS.md` (và `CLAUDE.md` trỏ về nó) ở gốc repo `Combine 3 in 1`. Mọi phiên làm việc đều đọc file này.
> - **Phần B – Prompt từng giai đoạn:** mỗi giai đoạn mở 1 phiên mới, dán đúng prompt của giai đoạn đó.
>
> Các chỗ `«…»` là thông tin cần điền trước khi dùng.

---

## PHẦN A — PROMPT GỐC (AGENTS.md)

```markdown
# AGENTS.md — Base Vina 3 in 1

## 1. Bạn đang làm gì
Gộp 3 ứng dụng nội bộ đang chạy thật thành MỘT ứng dụng Next.js, một lần đăng nhập, 3 phân hệ:
- Tài chính  (nguồn: repo «đường dẫn Finance Manager Base V3», nhánh production «dung-ho-quy-cong-truong / main»)
- Nhân sự    (nguồn: repo «đường dẫn HRM manager», v0.32.2)
- Kho        (nguồn: repo «đường dẫn Inventory manager», commit 6e8ae7f)
Tài liệu gốc: docs/KE_HOACH_GOP_3_TRONG_1.md (đọc trước khi làm bất cứ việc gì).
Triển khai trên Vercel qua kết nối API sẵn có — xem mục 5.
Chủ dự án là Giám đốc tài chính, KHÔNG phải lập trình viên → giải thích bằng tiếng Việt,
ngắn, nói rõ hệ quả nghiệp vụ, không dùng thuật ngữ khi không cần.

## 2. Quyết định đã chốt (không tự ý thay đổi)
1. Một app Next.js duy nhất, route theo phân hệ: /tai-chinh, /nhan-su, /kho, /he-thong.
2. Supabase project chung = project Nhân sự `naglcxbpxnntiglrzeqx`. Gói: «Free / Pro».
3. Kho giữ Google Sheet ở giai đoạn 1–6; chỉ thay đăng nhập Auth.js → Supabase.
4. Giữ shadcn/base-ui CHỈ trong phân hệ Kho (ngoại lệ duy nhất với quy tắc không thêm thư viện).
5. Không đăng nhập Google. Đăng nhập email hoặc SĐT (`<số>@sodienthoai.local`).
6. Tên hiển thị: «…». Domain: «…».
7. DB Tài chính gộp theo nguyên tắc "không gộp bảng": bảng trùng tên thêm hậu tố `_fmb`
   (hiện chỉ `chung_tu` → `chung_tu_fmb`); schema `private` mang sang nguyên.
8. Mỗi phân hệ GIỮ NGUYÊN hệ phân quyền nội bộ của nó ở giai đoạn 1–6.

## 3. Cấu trúc thư mục bắt buộc
src/proxy.ts                         kiểm tra phiên Supabase
src/app/dang-nhap, doi-mat-khau
src/app/(ung-dung)/layout.tsx        khung chung + bộ chọn phân hệ
src/app/(ung-dung)/page.tsx          trang chủ tổng "Việc chờ tôi"
src/app/(ung-dung)/{tai-chinh,nhan-su,kho,he-thong}/…
src/app/api/kho/…                    API của Kho
src/modules/{tai-chinh,nhan-su,kho}/{lib,components}   alias @tc/* @ns/* @kho/*
src/shared/                          alias @/shared/* : supabase client, phiên, UI chung, PDF, đọc số tiền
supabase/migrations/                 repo này là NGUỒN DUY NHẤT của lịch sử migration
supabase/functions/                  7 Edge Function Tài chính + 4 Nhân sự
docs/TIEN_DO.md                      nhật ký tiến độ (KHÔNG ghi mật khẩu, key, token)

Quy tắc import: code trong modules/tai-chinh không được import từ @ns/* hay @kho/* và ngược lại.
Dùng chung thì đưa vào src/shared.

## 4. Quy tắc bất biến (vi phạm = dừng lại hỏi)
### Dữ liệu & tiền
- Không lưu số dư quỹ / tồn kho / công nợ; luôn tính từ sổ. Sổ chỉ ghi thêm; sửa/huỷ phải có lý do + nhật ký.
- Tiền dùng `numeric`, không float. Tham số lương/thuế/BHXH lấy từ bảng `cfg_*`, không viết cứng.
- KHÔNG viết lại logic tiền, lương, thuế, duyệt chi. Chỉ chép, đổi import, đổi đường dẫn.
  Nếu buộc phải sửa logic → dừng, trình bày lý do + ảnh hưởng, chờ duyệt.
### Bảo mật
- Quyền thực thi ở DB (RLS/RPC) hoặc server. Ẩn nút KHÔNG phải phân quyền.
- Server luôn xác thực bằng `supabase.auth.getUser()` (không tin `getSession()` ở server).
- Service key / secret key chỉ ở Edge Function hoặc biến môi trường server; không bao giờ có
  tiền tố NEXT_PUBLIC_, không lên trình duyệt, không commit.
- API Kho không có RLS (dữ liệu ở Google Sheet) → MỌI route /api/kho/* phải gọi `kiemTraSession()`
  và kiểm vai trò trước khi đọc/ghi Sheet. Viết test cho việc này.
- Không chép sang repo mới các file chứa bí mật của repo cũ (Telegram_info.md, .env*, TIEN_DO.md cũ
  có mật khẩu). Không chép lịch sử git cũ — repo mới bắt đầu sạch.
### Database
- Không `supabase db push` từ repo cũ. Không apply SQL qua Management API/SQL editor mà không có
  file migration tương ứng trong repo.
- Mọi thay đổi DB làm trên project THỬ trước, có bản sao lưu, rồi mới làm project thật —
  và chỉ khi chủ dự án nói "làm thật".
- Không DROP / TRUNCATE / DELETE dữ liệu thật. Không sửa migration đã chạy.
### Code & giao diện
- Next.js 16.3, React 19.2.8, Tailwind v4, TypeScript strict. Không ORM.
- Không thêm thư viện khi chưa được duyệt (ngoại lệ: shadcn trong /kho).
- CSS của shadcn/Kho phải bị giới hạn trong vỏ `.kho-scope` ở layout /kho; biến CSS của shadcn
  (--background, --primary…) không được khai báo ở :root.
- Khung chung: sidebar desktop + tab bar dưới trên mobile; navy #1f3a5c; Be Vietnam Pro; chế độ sáng;
  nút ≥ 44px; phân hệ Tài chính KHÔNG dùng modal. Mỗi phân hệ 1 màu nhấn.
- Phải chạy tốt trên Android cũ (Chủ tịch/KTT dùng điện thoại).
- Giao diện, thông báo lỗi, chú thích nghiệp vụ bằng tiếng Việt.

## 5. Vercel (đã có kết nối API cho cả 3 app cũ)
### Hiện trạng
- 3 project cũ trên Vercel (tài khoản Hobby, vùng sin1): «tên project Finance», «tên project HRM»,
  «tên project Inventory». Máy đã kết nối Vercel qua API (CLI/MCP/token đã cấu hình sẵn).
- Project mới: «base-vina-3in1» — tạo ở Giai đoạn 0, KHÔNG dùng lại project cũ.
### Cách dùng kết nối
- Đầu mỗi phiên: kiểm tra kết nối nào đang có (`vercel whoami`, Vercel MCP, hoặc biến VERCEL_TOKEN)
  và dùng đúng kết nối đó. Không tạo token mới, không in token, không ghi token vào repo/file.
- Mọi lệnh CLI trên project mới phải chỉ rõ project (`vercel link` trong repo mới, hoặc `--scope`
  + `--project`) để không thao tác nhầm sang project cũ.
- Biến môi trường thêm bằng `vercel env add <TÊN> <production|preview|development>` nhập giá trị
  tương tác; không đưa giá trị vào câu lệnh. Đọc giá trị từ project cũ bằng `vercel env pull`
  vào file tạm ngoài repo, dùng xong xoá; không hiển thị giá trị ra màn hình.
- Project mới: Framework Next.js, Node ≥ 20, Function Region `sin1`, Production Branch `main`.
### Quyền của agent
- Được tự làm: đọc project/deployment/log của cả 4 project; tạo project mới; deploy PREVIEW
  project mới; đọc log build/runtime để tự sửa lỗi build.
- Phải hỏi trước (nêu lệnh + ảnh hưởng): deploy production project mới; thêm/sửa/xoá biến môi
  trường; gắn domain; cấu hình redirect; promote/rollback.
- TUYỆT ĐỐI không: xoá bất kỳ project/deployment nào; deploy, sửa env, sửa domain của 3 project
  cũ (trừ việc cài redirect ở Giai đoạn 6 khi tôi duyệt); bật "auto-accept" cho lệnh Vercel.
### Kiểm soát hạn mức gói Hobby (dùng chung cho 4 project)
- Không deploy lặp vô ích: gom thay đổi, chạy `tsc --noEmit` + `next build` ở máy trước khi deploy.
- Cuối mỗi giai đoạn báo cáo mức dùng (Active CPU, Function Invocations, Fast Data Transfer,
  số deploy/ngày) nếu đọc được; cảnh báo khi vượt 70% hạn mức tháng.

## 6. Cách làm việc (phase-gate)
- Mỗi phiên chỉ làm MỘT giai đoạn (xem docs/KE_HOACH_GOP_3_TRONG_1.md mục 4).
- Đầu phiên: đọc AGENTS.md, kế hoạch, docs/TIEN_DO.md; nêu lại mục tiêu giai đoạn + danh sách việc
  sẽ làm + việc có rủi ro với dữ liệu thật. Chờ chủ dự án xác nhận rồi mới làm.
- Trong phiên: gặp chỗ mơ hồ ảnh hưởng tiền/quyền/dữ liệu → dừng hỏi 1 câu. Chỗ mơ hồ kỹ thuật
  thuần tuý → tự chọn phương án an toàn nhất, ghi lại trong TIEN_DO.md.
- "Xong" nghĩa là: `tsc --noEmit` sạch + `next build` thành công + test của phân hệ xanh
  + đã chạy thử trên máy các luồng chính + cập nhật TIEN_DO.md.
- Cuối phiên, báo cáo cho chủ dự án theo mẫu:
  1. Đã làm gì (tối đa 10 dòng)
  2. Kết quả kiểm tra (tsc / build / test: số đạt/tổng)
  3. Việc chủ dự án cần tự bấm thử (danh sách luồng cụ thể, đăng nhập tài khoản nào)
  4. Việc còn tồn / rủi ro
  5. Đề nghị duyệt sang giai đoạn tiếp theo: CÓ / CHƯA
- KHÔNG tự sang giai đoạn sau.
```

---

## PHẦN B — PROMPT TỪNG GIAI ĐOẠN

### Giai đoạn 0 — Chuẩn bị & an toàn

```
Đọc AGENTS.md và docs/KE_HOACH_GOP_3_TRONG_1.md. Làm Giai đoạn 0.

Việc:
1. Kiểm tra repo Tài chính: nhánh nào đang deploy production trên Vercel (so commit Vercel với các nhánh).
   Báo cho tôi, KHÔNG merge gì.
2. Viết script sao lưu (chưa chạy, tôi sẽ chạy): pg_dump đầy đủ (schema + data, gồm schema auth,
   storage, private) cho 2 project Supabase; tải toàn bộ file trong mọi bucket; hướng dẫn tải bản sao
   Google Sheet Kho.
3. Quét cả 3 repo tìm bí mật đã lộ (token, key, mật khẩu, hash) trong file hiện tại VÀ lịch sử git.
   Lập danh sách: file – loại bí mật – cần thu hồi/đổi ở đâu – ai làm. Không in giá trị bí mật ra.
4. Khởi tạo repo mới "Combine 3 in 1": .gitignore chặn .env*, *.pem, Telegram_info*; chép AGENTS.md
   và kế hoạch vào docs/; tạo docs/TIEN_DO.md.
5. Vercel (qua kết nối API sẵn có, chỉ ĐỌC với 3 project cũ):
   a. Liệt kê 3 project cũ: tên, domain, nhánh production, commit đang chạy, ngày deploy cuối,
      danh sách TÊN biến môi trường (không lấy giá trị), redirect/rewrite đang có, cron (nếu có).
   b. Xác nhận nhánh production thật của Tài chính bằng commit Vercel đang chạy.
   c. Đọc mức dùng tháng này của tài khoản (nếu API cho phép) để biết còn dư bao nhiêu hạn mức.
   d. Tạo project mới «base-vina-3in1» nối với repo mới, region sin1, CHƯA gắn domain, CHƯA env.
   e. Lập bảng ánh xạ biến môi trường: tên biến ở project cũ → giữ / đổi tên / bỏ ở project mới
      (theo mục 5 kế hoạch). Không chép giá trị ở bước này.
6. Liệt kê những gì cần tôi làm tay (đổi token Telegram, rotate key Supabase…). Lưu ý: key nào
   được rotate thì phải cập nhật lại env của project cũ tương ứng — lập danh sách để tôi duyệt.

Tiêu chí xong: tôi có danh sách bí mật cần xử lý, script backup, repo mới sạch, project Vercel
mới đã tạo, bảng hiện trạng 3 project cũ + bảng ánh xạ biến môi trường.
```

### Giai đoạn 1 — Khung app

```
Đọc AGENTS.md, TIEN_DO.md. Làm Giai đoạn 1: dựng khung app, CHƯA chép nghiệp vụ.

Việc:
1. Next.js 16.3 + React 19.2.8 + Tailwind v4 + TS strict; alias @/, @/shared/*, @tc/*, @ns/*, @kho/*.
2. src/shared/supabase: client trình duyệt, client server (cookie), hàm layPhien() dùng getUser().
3. proxy.ts: chưa đăng nhập → /dang-nhap?next=…; kiểm tra `next` chỉ nhận đường dẫn nội bộ
   (chép safe-path.ts từ Nhân sự).
4. /dang-nhap: 1 ô "Email hoặc số điện thoại" + mật khẩu. Nếu nhập toàn số → chuẩn hoá SĐT
   (bỏ +84/0 đầu theo đúng quy ước Tài chính hiện tại — đọc code Tài chính để lấy đúng hàm) → `<số>@sodienthoai.local`.
5. /doi-mat-khau.
6. Layout (ung-dung): sidebar desktop + tab bar mobile, bộ chọn phân hệ ở đầu sidebar.
   Tạm thời hiển thị cả 3 phân hệ với trang giữ chỗ; hàm layPhanHeDuocPhep(user) để trống, trả cả 3.
7. Token màu navy #1f3a5c, font Be Vietnam Pro (next/font), màu nhấn: Tài chính «…», Nhân sự «…», Kho «…».
8. Kết nối project Supabase chung (chỉ đọc, chưa migration).
9. Vercel: xin duyệt rồi thêm NEXT_PUBLIC_SUPABASE_URL, NEXT_PUBLIC_SUPABASE_ANON_KEY cho
   preview + production của project mới (lấy từ project HRM cũ, không hiển thị giá trị).
   Deploy PREVIEW, đọc log build, sửa lỗi đến khi build xanh. Gửi tôi link preview.
10. Cấu hình Supabase Auth: thêm domain preview/production của project mới vào Redirect URLs
    (hỏi trước khi sửa, vì đây là project Nhân sự đang chạy thật).

Kiểm thử: đăng nhập bằng 1 tài khoản Nhân sự có sẵn TRÊN LINK PREVIEW; giao diện 360px và 1280px.
```

### Giai đoạn 2 — Ghép Nhân sự

```
Đọc AGENTS.md, TIEN_DO.md. Làm Giai đoạn 2: ghép phân hệ Nhân sự. DB đã ở đúng project, KHÔNG
tạo migration mới trừ khi thật cần (phải hỏi).

Việc:
1. Chép HRM: src/app/* → (ung-dung)/nhan-su/*, src/lib → modules/nhan-su/lib,
   components → modules/nhan-su/components. Đổi import hàng loạt sang @ns/*.
2. Đổi toàn bộ href, redirect, router.push, revalidatePath sang tiền tố /nhan-su
   (/nhan-su/[id] cũ → /nhan-su/ho-so/[id]). Cập nhật tabs.ts. Liệt kê mọi chỗ đã đổi.
3. Chép 4 Edge Function + _shared vào supabase/functions (chưa deploy lại nếu không đổi logic).
4. Chép 135 unit test vitest + script kiểm RLS; cho chạy xanh.
5. Nối layPhanHeDuocPhep: có Nhân sự nếu app_users.is_active = true.
6. Đổi CSS indigo → token chung + màu nhấn Nhân sự.
7. Lập checklist test tay 11 phase của HRM (chấm công selfie, tổ đội, kỳ lương, BHXH, TNCN,
   phiếu lương PDF…) để tôi bấm thử trên app mới.
8. Vercel: so danh sách env của project HRM cũ với bảng ánh xạ; xin duyệt rồi thêm biến còn
   thiếu vào project mới. Deploy PREVIEW, kiểm tra log runtime khi chạy các luồng (đặc biệt route
   PDF và upload selfie — kiểm tra giới hạn kích thước body và thời gian chạy hàm).

Tiêu chí xong: tsc/build sạch, 135 test + kiểm RLS xanh, luồng tính lương 1 kỳ thử cho kết quả
trùng khớp tuyệt đối với app cũ (so từng người, từng khoản).
```

### Giai đoạn 3 — Gộp DB & code Tài chính (rủi ro cao nhất)

Nên chia thành **3 phiên**: 3a diễn tập, 3b ghép code, 3c chuyển thật.

**3a — Diễn tập trên project thử**

```
Đọc AGENTS.md, TIEN_DO.md, docs/KE_HOACH_GOP_DB_HRM.md (từ repo Finance). Làm Giai đoạn 3a:
DIỄN TẬP gộp DB Tài chính vào một project Supabase THỬ «ref project thử» đã khôi phục từ bản
backup của project Nhân sự. Tuyệt đối không chạm project thật.

Việc:
1. Lập baseline migration mới trong repo này: dump schema hiện tại của project Nhân sự thành
   migration baseline + schema Tài chính (public đổi chung_tu → chung_tu_fmb, schema private
   nguyên vẹn) thành migration tiếp theo. Đối chiếu với 55 migration Finance, ghi rõ chỗ khác
   (đặc biệt vụ migration 37 đè 47 ngày 16/09): schema production thực tế mới là chuẩn, không phải file.
2. Kiểm tra xung đột tên: bảng, view, function, trigger, enum/type, sequence, policy, bucket,
   pg_cron job giữa 2 project. Lập bảng xung đột; mỗi dòng đề xuất cách xử lý. Chờ tôi duyệt.
3. Script nạp dữ liệu Tài chính:
   - Nạp với session_replication_role = replica để trigger "chỉ ghi thêm"/nhật ký không chặn
     hoặc nhân đôi dòng; sau đó bật lại.
   - Sau khi nạp: setval() mọi sequence = max(id) để số chứng từ/đề nghị không bị trùng.
4. Tài khoản:
   - Xuất danh sách email/SĐT của 2 project, lập bảng đối chiếu người trùng để TÔI xác nhận tay.
   - Người không trùng: chép auth.users + auth.identities giữ UUID + encrypted_password.
   - Người trùng: không chép; cập nhật nhan_vien.user_id sang UUID bên Nhân sự.
   - Trigger on_auth_user_created của HRM: đề xuất xử lý (tôi nghiêng về: tạo dòng app_users
     is_active = false). Chờ duyệt.
5. Storage: bucket chung-tu-fmb, chép file, sửa đường dẫn trong chung_tu_fmb, policy riêng.
6. Chạy toàn bộ test: SQL Tài chính (Phase 1: 25, Phase 4: 40, bảo mật: 18) + kiểm RLS HRM (849 + 83).
   Thêm test chéo: tài khoản chỉ có Nhân sự không đọc được bảng/file Tài chính và ngược lại.
7. ĐỐI SOÁT: viết script SQL so DB cũ vs DB thử, xuất bảng:
   số dư từng quỹ/tài khoản, công nợ tạm ứng từng người, công nợ vay, tổng thu/chi theo tháng,
   số đề nghị theo trạng thái, số dòng từng bảng. Chênh lệch phải = 0 đồng.
8. Ghi lại toàn bộ thứ tự thao tác thành runbook docs/RUNBOOK_CHUYEN_DB_TAI_CHINH.md
   (có thời gian ước tính từng bước + cách quay lui).

Tiêu chí xong: test 100% xanh, đối soát 0 chênh lệch, runbook đủ để làm thật.
```

**3b — Ghép code Tài chính**

```
Đọc AGENTS.md, TIEN_DO.md, runbook. Làm Giai đoạn 3b trên project THỬ:
1. Chép code Tài chính → (ung-dung)/tai-chinh/*, modules/tai-chinh/*; đổi import @tc/*.
2. Đổi mọi đường dẫn sang /tai-chinh/…; đổi hằng BANG_CHUNG_TU → chung_tu_fmb, bucket → chung-tu-fmb.
3. Chép 7 Edge Function; tìm mọi đường dẫn app bị viết cứng trong notify-telegram, daily-report,
   telegram-webhook và chuyển về APP_URL + đường dẫn mới.
4. Nối layPhanHeDuocPhep: có Tài chính nếu có dòng nhan_vien đang dùng.
5. Giữ nguyên: không modal, nút ≥ 44px, menu theo người, gán theo quỹ.
5b. Vercel: project mới ở preview trỏ vào Supabase THỬ (env preview), production vẫn trỏ project
    chung. Kiểm tra kỹ: env preview KHÔNG được trỏ vào DB thật khi đang diễn tập.
6. Chạy thử trên máy các luồng: tạo đề nghị → KTT duyệt → Chủ tịch duyệt → chi tiền → sổ quỹ;
   tạm ứng → quyết toán; chuyển quỹ; báo cáo. Kết quả phải khớp app cũ trên cùng dữ liệu.
```

**3c — Chuyển thật**

```
Đọc runbook. Chỉ làm khi tôi viết: "DUYỆT CHUYỂN THẬT NGÀY «…»".
Thực hiện đúng runbook, từng bước, báo cáo sau mỗi bước, dừng ngay nếu có bước lỗi:
khoá ghi app Tài chính cũ → backup lần cuối → nạp dữ liệu → setval sequence → chép tài khoản
→ chép file → deploy Edge Function + secrets → đổi webhook Telegram + APP_URL → tạo lại pg_cron
daily-report-0730-vn → cập nhật workflow backup → chạy test → ĐỐI SOÁT → chỉ mở app mới khi
chênh lệch = 0. Nếu đối soát lệch: mở khoá app cũ, không mở app mới, báo tôi.
Vercel trong 3c: trước khi bắt đầu, ghi lại ID deployment production đang chạy của project
Tài chính cũ (để rollback). "Khoá ghi app cũ" làm bằng biến môi trường chế độ chỉ đọc + redeploy
project cũ (xin duyệt riêng lệnh này). Deploy production project mới chỉ sau khi đối soát = 0.
Kế hoạch quay lui: tắt chế độ chỉ đọc ở project cũ + redeploy đúng deployment đã ghi lại.
```

### Giai đoạn 4 — Ghép Kho (giữ Google Sheet)

```
Đọc AGENTS.md, TIEN_DO.md. Làm Giai đoạn 4.

Việc:
1. Chép app/(app)/* → (ung-dung)/kho/*, app/api/* → app/api/kho/*, lib → modules/kho/lib; import @kho/*.
2. Viết kiemTraSession() trả {email, vaiTro, maKhoPhuTrach}: lấy user từ Supabase (getUser),
   tra dm_nguoi_dung theo email, trạng thái HOAT_DONG. Cache kết quả tra Sheet ngắn hạn
   (≈60 giây, theo email) để không vượt hạn mức Google Sheets API. Thay mọi auth() cũ.
3. Mọi route /api/kho/* bắt buộc gọi kiemTraSession() + kiểm vai trò theo ma trận hiện có.
   Viết test: chưa đăng nhập → 401; sai vai trò → 403; thu_kho chỉ thao tác kho mình phụ trách.
3b. Vercel: xin duyệt rồi thêm GOOGLE_SERVICE_ACCOUNT_EMAIL, GOOGLE_PRIVATE_KEY, SHEET_ID,
    BLOB_READ_WRITE_TOKEN vào project mới (lấy từ project Inventory cũ; GOOGLE_PRIVATE_KEY giữ
    đúng ký tự xuống dòng). Kết nối Blob store hiện có của Kho vào project mới (không tạo store mới,
    để ảnh cũ vẫn đọc được). KHÔNG chép AUTH_SECRET, AUTH_GOOGLE_* sang.
4. Bỏ Auth.js, đăng nhập Google, màn đổi mật khẩu riêng, cột mat_khau_hash (ngừng dùng, KHÔNG xoá
   dữ liệu Sheet lúc này; đề xuất bước xoá hash sau nghiệm thu).
5. shadcn chỉ nạp trong layout /kho, bọc .kho-scope; kiểm tra Tài chính và Nhân sự không bị đổi giao diện.
6. Font PDF Tinos + outputFileTracingIncludes cho route PDF kho.
7. Giữ quy tắc Kho: số phiếu không dùng max+1, tồn tính lại từ phiếu đã duyệt, thủ kho tự duyệt QT-A1.
8. Viết Apps Script backup Sheet hằng ngày 01:00–02:00 (giữ 30 bản) + hướng dẫn tôi bật trigger.
9. Lập danh sách người chỉ dùng Kho cần tạo tài khoản Supabase + mẫu tin nhắn hướng dẫn đăng nhập.

Kiểm thử: nhập → duyệt → xuất → điều chỉnh → thẻ kho → N-X-T; tồn khớp app cũ trên cùng Sheet.
```

### Giai đoạn 5 — Trang chủ tổng & Hệ thống → Tài khoản

```
Đọc AGENTS.md, TIEN_DO.md. Làm Giai đoạn 5.
1. Trang chủ "Việc chờ tôi": mỗi phân hệ cung cấp 1 hàm đếm việc chờ của user hiện tại
   (đề nghị chờ tôi duyệt, phiếu kho chờ duyệt, chấm công chờ xác nhận…) — hàm đặt trong module,
   trang chủ chỉ gọi. Chỉ hiện phân hệ người đó có quyền. Lỗi 1 phân hệ không làm hỏng cả trang.
2. Gộp tao-tai-khoan (Tài chính) + quan-tri-tai-khoan (Nhân sự) thành 1 Edge Function.
   Màn /he-thong/tai-khoan: tạo, khoá, đặt lại mật khẩu, bật/tắt từng phân hệ
   (bật phân hệ = tạo/kích hoạt đúng dòng nhan_vien / app_users / dm_nguoi_dung tương ứng).
   Chỉ admin hệ thống dùng được; kiểm quyền trong Edge Function, không chỉ ở giao diện.
3. Ghi nhật ký mọi thao tác tài khoản.
```

### Giai đoạn 6 — Nghiệm thu & chuyển hẳn

```
Đọc AGENTS.md, TIEN_DO.md. Làm Giai đoạn 6.
1. Lập kịch bản nghiệm thu cho từng vai trò (Chủ tịch, KTT, kế toán, thủ quỹ, nhân sự, thủ kho,
   người xem) — mỗi vai trò 5–10 thao tác, cột "Kết quả mong đợi" / "Đạt".
2. Vercel – domain (xin duyệt từng bước): gắn domain «…» vào project mới; deploy production;
   kiểm tra HTTPS, đăng nhập, 3 phân hệ trên domain thật.
3. Vercel – redirect: ở MỖI project cũ, thêm redirect trong vercel.json (hoặc cấu hình redirect
   của project) từ đường dẫn cũ → đường dẫn mới tương ứng (bảng ánh xạ mục 3.2 kế hoạch), mã 308,
   giữ 2 tháng. Không xoá code cũ; chỉ thêm redirect. Kiểm tra link duyệt trong tin Telegram cũ
   vẫn mở đúng màn hình trên app mới.
4. Cập nhật Supabase Auth: Site URL, Redirect URLs theo domain mới.
5. Checklist tắt app cũ (chỉ khi tôi duyệt): chế độ chỉ đọc → sau 2–4 tuần tạm dừng project
   Tài chính cũ trên Supabase (không xoá) → trên Vercel chỉ giữ redirect, gỡ biến môi trường
   bí mật khỏi 3 project cũ (không xoá project).
6. Báo cáo mức dùng Vercel tháng; nếu > 70% hạn mức Hobby → đề xuất nâng Pro.
```

---

## PHỤ LỤC — PROMPT KIỂM TRA ĐỘC LẬP (dùng sau giai đoạn 3 và 4)

```
Bạn là người kiểm tra độc lập, KHÔNG sửa code. Đọc AGENTS.md rồi rà repo và báo cáo:
1. Mọi route/API/Server Action: có xác thực getUser() + kiểm quyền ở server/DB không? Liệt kê chỗ thiếu.
2. Có key/secret nào có thể lọt ra trình duyệt hoặc nằm trong repo không?
3. Có chỗ nào logic tiền/lương/thuế/duyệt chi bị thay đổi so với repo gốc không? (diff theo hàm)
4. Có đường dẫn cũ nào còn sót (href, redirect, Telegram, email) không?
5. Có import chéo giữa @tc / @ns / @kho không?
6. CSS Kho có rò ra ngoài .kho-scope không?
Xếp theo mức độ: Nghiêm trọng / Cao / Thấp, kèm file:dòng.
```
