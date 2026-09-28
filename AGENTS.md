# AGENTS.md — Base Vina 3 in 1

## 1. Bạn đang làm gì
Gộp 3 ứng dụng nội bộ đang chạy thật thành MỘT ứng dụng Next.js, một lần đăng nhập, 3 phân hệ:
- Tài chính  (nguồn: `../Finance Manager Base V3`, nhánh production `main` — Vercel đang chạy commit `992cdd7` KT-71.
  Nhánh `dung-ho-quy-cong-truong` (KT-72, migration 56) CHỈ có trên máy, chưa push, chưa deploy, chưa chạy lên DB → KHÔNG dùng làm nguồn khi chưa được chủ dự án quyết)
- Nhân sự    (nguồn: `../HRM manager`, v0.32.2, `main` commit `9a0b9a8`)
- Kho        (nguồn: `../Inventory manager`, `main` commit `6e8ae7f`)
Tài liệu gốc: docs/KE_HOACH_GOP_3_TRONG_1.md (đọc trước khi làm bất cứ việc gì).
Triển khai trên Vercel qua kết nối API sẵn có — xem mục 5.
Chủ dự án là Giám đốc tài chính, KHÔNG phải lập trình viên → giải thích bằng tiếng Việt,
ngắn, nói rõ hệ quả nghiệp vụ, không dùng thuật ngữ khi không cần.

## 2. Quyết định đã chốt (không tự ý thay đổi)
1. Một app Next.js duy nhất, route theo phân hệ: /tai-chinh, /nhan-su, /kho, /he-thong.
2. Supabase project chung = project Nhân sự `naglcxbpxnntiglrzeqx`. Gói: «CHƯA CHỐT: Free / Pro».
3. Kho giữ Google Sheet ở giai đoạn 1–6; chỉ thay đăng nhập Auth.js → Supabase.
4. Giữ shadcn/base-ui CHỈ trong phân hệ Kho (ngoại lệ duy nhất với quy tắc không thêm thư viện).
5. Không đăng nhập Google. Đăng nhập email hoặc SĐT (`<số>@sodienthoai.local`).
6. Tên hiển thị: «CHƯA CHỐT». Domain: «CHƯA CHỐT».
7. DB Tài chính gộp theo nguyên tắc "không gộp bảng": bảng trùng tên thêm hậu tố `_fmb`
   (hiện chỉ `chung_tu` → `chung_tu_fmb`); schema `private` mang sang nguyên.
8. Mỗi phân hệ GIỮ NGUYÊN hệ phân quyền nội bộ của nó ở giai đoạn 1–6.

## 3. Cấu trúc thư mục bắt buộc
```
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
scripts/sao-luu/                     script sao lưu (chủ dự án tự chạy)
docs/TIEN_DO.md                      nhật ký tiến độ (KHÔNG ghi mật khẩu, key, token)
```

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
  có mật khẩu, scripts/kiem-tra-rls-*.mjs của HRM có mật khẩu tài khoản test viết cứng — phải sửa
  sang đọc biến môi trường khi chép). Không chép lịch sử git cũ — repo mới bắt đầu sạch.
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
- Team Vercel `trieu-vu` (tài khoản `oemlogosvu`, gói Hobby). 3 project cũ:
  `finance-manager-base-vina`, `hr-base-vina`, `inventory-manager-basevina`.
  Kết nối: Vercel CLI qua `npx vercel` (đăng nhập sẵn trên máy). Luôn thêm `--scope trieu-vu`.
- Project mới: `base-vina-3in1` — tạo ở Giai đoạn 0 (sau khi chủ dự án duyệt tạo repo GitHub),
  KHÔNG dùng lại project cũ.
### Cách dùng kết nối
- Đầu mỗi phiên: `npx vercel whoami` để kiểm tra kết nối. Không tạo token mới, không in token,
  không ghi token vào repo/file.
- Mọi lệnh CLI trên project mới phải chỉ rõ project (`vercel link` trong repo mới, hoặc `--scope`
  + `--project`) để không thao tác nhầm sang project cũ.
- Biến môi trường thêm bằng `vercel env add <TÊN> <production|preview|development>` nhập giá trị
  tương tác; không đưa giá trị vào câu lệnh. Đọc giá trị từ project cũ bằng `vercel env pull`
  vào file tạm ngoài repo, dùng xong xoá; không hiển thị giá trị ra màn hình.
- Project mới: Framework Next.js, Node ≥ 20, Function Region `sin1` (đặt ở cả cấu hình project
  VÀ `vercel.json`), Production Branch `main`.
### Quyền của agent
- Được tự làm: đọc project/deployment/log của cả 4 project; deploy PREVIEW project mới;
  đọc log build/runtime để tự sửa lỗi build.
- Phải hỏi trước (nêu lệnh + ảnh hưởng): **mọi git commit / push**; tạo repo GitHub; tạo project
  Vercel mới; deploy production project mới; thêm/sửa/xoá biến môi trường; gắn domain; cấu hình
  redirect; promote/rollback.
- TUYỆT ĐỐI không: xoá bất kỳ project/deployment nào; deploy, sửa env, sửa domain của 3 project
  cũ (trừ việc cài redirect ở Giai đoạn 6 khi tôi duyệt); bật "auto-accept" cho lệnh Vercel.
### Kiểm soát hạn mức gói Hobby (dùng chung cho 4 project)
- Không deploy lặp vô ích: gom thay đổi, chạy `tsc --noEmit` + `next build` ở máy trước khi deploy.
- Cuối mỗi giai đoạn báo cáo mức dùng (Active CPU, Function Invocations, Fast Data Transfer,
  số deploy/ngày) nếu đọc được — API usage không mở cho Hobby, xem ở dashboard Vercel → Usage;
  cảnh báo khi vượt 70% hạn mức tháng.

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
