# HƯỚNG DẪN SAO LƯU TRƯỚC KHI GỘP (Giai đoạn 0)

> Người chạy: **chủ dự án** (agent chỉ viết script, không chạy).
> Thời gian: khoảng 20–30 phút. Làm ngoài giờ duyệt chi.
> Nơi lưu mặc định: `F:\SaoLuu_BaseVina` (ổ C chỉ còn ~5 GB). **Không** lưu trong OneDrive
> dự án — bản sao lưu có lương, CCCD, số tài khoản, hash mật khẩu.

Dung lượng dự kiến (đo ngày 26/09/2026): DB Tài chính 19 MB, DB Nhân sự 18 MB,
file Tài chính 40 MB (144 file), file Nhân sự 24 MB (138 file), ảnh Kho trên Vercel Blob: chưa đo.

---

## 1. Cài công cụ pg_dump bản 17 (làm 1 lần)

DB của Supabase là Postgres 17 → pg_dump phải là bản **17 trở lên**.

1. Tải bộ cài: https://www.enterprisedb.com/downloads/postgres-postgresql-downloads → Windows x86-64 → bản 17.x.
2. Khi cài, ở màn "Select Components" **chỉ tích "Command Line Tools"** (bỏ Server, pgAdmin, Stack Builder).
3. Mở PowerShell mới, kiểm tra: `& "C:\Program Files\PostgreSQL\17\bin\pg_dump.exe" --version` → phải ra `17.x`.
   (Script tự tìm trong `C:\Program Files\PostgreSQL\*\bin`, không cần sửa PATH.)

**Máy hiện tại (29/09/2026):** đã có sẵn bản giải nén PostgreSQL 17.6 ở `F:\pgsql\bin` (không cài vào Windows) —
script tự tìm ở đó trước, bỏ qua bước cài.

## 2. Chuẩn bị mật khẩu database

Cần **mật khẩu database** (không phải mật khẩu đăng nhập app) của 2 project:
- Tài chính `eodrpyedatohsovobsxj` (thuchi-staging)
- Nhân sự `naglcxbpxnntiglrzeqx` (hr-base-vina)

Nếu quên: Supabase Dashboard → project → **Project Settings → Database → Reset database password**.
⚠ Đặt lại mật khẩu DB làm hỏng các chỗ đang dùng mật khẩu cũ:
- Tài chính: secret `SUPABASE_DB_URL` trong GitHub Actions (backup hằng đêm) → phải cập nhật.
- Nhân sự: biến môi trường `SUPABASE_DB_PASSWORD` trên máy này (script `db push` của HRM).
App trên Vercel **không** bị ảnh hưởng (app không dùng mật khẩu DB).

## 3. Sao lưu database (cả 2 project)

Mở PowerShell tại thư mục `Combine 3 in 1`:
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\sao-luu\sao-luu-db.ps1 -ThuMuc "F:\SaoLuu_BaseVina"
```
- Mật khẩu DB lấy từ biến môi trường User `SUPABASE_DB_PASSWORD_TAICHINH` / `SUPABASE_DB_PASSWORD` (Nhân sự);
  thiếu biến nào thì script hỏi (gõ không hiện chữ — bình thường).
- Chỉ 1 project: thêm `-ChiProject TaiChinh` hoặc `-ChiProject NhanSu`.
- Báo "password authentication failed" dù mật khẩu đúng → thêm `-TrucTiep` (kết nối thẳng `db.<ref>.supabase.co`
  qua IPv6, không qua Session pooler). **Không thử lại liên tục**: sai nhiều lần Supabase tạm chặn IP.
- Kết quả: thư mục `F:\SaoLuu_BaseVina\db_<ngày giờ>\` gồm 3 file/project + `KIEM_TRA.txt`.
- Đạt khi `KIEM_TRA.txt` ghi **"có dữ liệu auth.users: True"** cho cả 2 project.

## 4. Tải toàn bộ file đính kèm (Supabase Storage)

```powershell
node scripts/sao-luu/tai-file-storage.mjs "F:\SaoLuu_BaseVina"
```
- Không cần nhập gì (dùng quyền quản trị Supabase đã cài sẵn trên máy).
- Đạt khi: Tài chính `chung-tu` 144 file; Nhân sự `to-doi-cham-cong` 105 file, `chung-tu` 33 file,
  `attendance-selfies` 0 file (số có thể tăng nếu có người dùng thêm). Dòng "lỗi" phải = 0.
- Chạy lại được nhiều lần; file đã tải sẽ bỏ qua.

## 5. Tải ảnh chứng từ Kho (Vercel Blob)

```powershell
node --env-file="../Inventory manager/.env.local" scripts/sao-luu/tai-anh-kho-blob.mjs "F:\SaoLuu_BaseVina"
```
Đạt khi dòng cuối báo "lỗi 0".

## 6. Sao lưu Google Sheet Kho ("00_Theo dõi vật tư Thanh Miếu")

Làm tay, 2 bước:
1. Mở Sheet → **Tệp → Tạo bản sao** → đặt tên `SAOLUU_VATTU_KHO_<ngày>` → **bỏ tích** "Chia sẻ với cùng những người" → lưu vào Drive cá nhân.
2. **Tệp → Tải xuống → Microsoft Excel (.xlsx)** → lưu vào `F:\SaoLuu_BaseVina\sheet_kho_<ngày>.xlsx`.

Kiểm tra: bản sao có đủ **12 tab** (dm_vat_tu, dm_kho, dm_ncc, dm_bo_phan, dm_nguoi_dung, phieu,
chi_tiet, ton_kho_cache, log, dm_phan_quyen, de_xuat, de_xuat_chi_tiet).

## 7. Sau khi xong

- Chép cả thư mục `F:\SaoLuu_BaseVina` sang 1 nơi thứ hai (ổ cứng ngoài hoặc Google Drive cá nhân).
- Báo lại cho agent: ngày giờ sao lưu + nội dung `KIEM_TRA.txt` (file này không chứa bí mật).

## Khôi phục (chỉ dùng khi cần, làm trên project THỬ)
```powershell
& "C:\Program Files\PostgreSQL\17\bin\pg_restore.exe" --list "<file>.dump"      # xem nội dung
# Khôi phục vào project THỬ: agent sẽ viết lệnh cụ thể ở Giai đoạn 3a.
```
