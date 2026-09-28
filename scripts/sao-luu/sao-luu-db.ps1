<#
  SAO LƯU TOÀN BỘ DATABASE 2 PROJECT SUPABASE (Tài chính + Nhân sự)
  ------------------------------------------------------------------
  - Sao lưu MỌI schema: public, private, auth (tài khoản + mật khẩu đã băm), storage (danh mục file),
    cron, supabase_migrations (lịch sử migration)...
  - Mỗi project tạo 3 file:
      <ref>_day-du.dump   : bản đầy đủ (schema + dữ liệu), dùng để khôi phục bằng pg_restore
      <ref>_cau-truc.sql  : chỉ cấu trúc, dạng chữ đọc được (để đối chiếu)
      <ref>_du-lieu.sql   : chỉ dữ liệu public/private/auth dạng chữ (phòng khi .dump lỗi)
    + file KIEM_TRA.txt ghi dung lượng, mã SHA256 và số đối tượng trong bản .dump.
  - Mật khẩu DB được HỎI khi chạy, không lưu vào file, không in ra màn hình.

  YÊU CẦU: pg_dump bản 17 (xem docs/SAO_LUU.md mục 1).
  CÁCH CHẠY (PowerShell):
      powershell -ExecutionPolicy Bypass -File .\scripts\sao-luu\sao-luu-db.ps1
      powershell -ExecutionPolicy Bypass -File .\scripts\sao-luu\sao-luu-db.ps1 -ThuMuc "F:\SaoLuu_BaseVina"
  LƯU Ý: bản sao lưu chứa dữ liệu cá nhân + lương + hash mật khẩu → KHÔNG để trong OneDrive/repo.
#>
param(
  [string]$ThuMuc = "F:\SaoLuu_BaseVina"
)
# "Continue": PowerShell 5.1 coi mọi dòng cảnh báo của pg_dump là lỗi nếu để "Stop";
# lỗi thật được bắt qua $LASTEXITCODE và throw bên dưới.
$ErrorActionPreference = "Continue"

$PROJECTS = @(
  @{ Ten = "TaiChinh"; Ref = "eodrpyedatohsovobsxj" },
  @{ Ten = "NhanSu";   Ref = "naglcxbpxnntiglrzeqx" }
)

# 1) Kiểm tra pg_dump
$pgDump = Get-Command pg_dump -ErrorAction SilentlyContinue
if (-not $pgDump) {
  $thu = Get-ChildItem "C:\Program Files\PostgreSQL\*\bin\pg_dump.exe" -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1
  if ($thu) { $pgDump = $thu.FullName } else { throw "Không tìm thấy pg_dump. Cài PostgreSQL 17 (xem docs/SAO_LUU.md mục 1) rồi chạy lại." }
} else { $pgDump = $pgDump.Source }
$binDir = Split-Path $pgDump
$pgRestore = Join-Path $binDir "pg_restore.exe"
$ver = & $pgDump --version
Write-Host "Dùng: $ver"
if ($ver -notmatch " (1[7-9]|[2-9]\d)\.") { throw "pg_dump phải là bản 17 trở lên (DB Supabase đang là Postgres 17)." }

# 2) Token quản trị Supabase (đã có sẵn trong biến môi trường User) — chỉ để hỏi địa chỉ máy chủ kết nối
$token = [Environment]::GetEnvironmentVariable("SUPABASE_ACCESS_TOKEN", "User")
if (-not $token) { Write-Warning "Không có SUPABASE_ACCESS_TOKEN — sẽ phải nhập tay địa chỉ pooler." }

$ngay = Get-Date -Format "yyyy-MM-dd_HHmm"
$dich = Join-Path $ThuMuc "db_$ngay"
New-Item -ItemType Directory -Force $dich | Out-Null
$baoCao = Join-Path $dich "KIEM_TRA.txt"
"SAO LƯU DB — $ngay — $ver" | Out-File $baoCao -Encoding utf8

foreach ($p in $PROJECTS) {
  $ref = $p.Ref
  Write-Host "`n===== $($p.Ten) ($ref) =====" -ForegroundColor Cyan

  # Lấy địa chỉ Session pooler (IPv4) từ Management API
  $dbHost = $null; $dbUser = "postgres.$ref"
  if ($token) {
    try {
      $pool = Invoke-RestMethod -Uri "https://api.supabase.com/v1/projects/$ref/config/database/pooler" -Headers @{ Authorization = "Bearer $token" } -ErrorAction Stop
      $pool = @($pool)[0]
      $dbHost = $pool.db_host; if ($pool.db_user) { $dbUser = $pool.db_user }
    } catch { Write-Warning "Không lấy được địa chỉ pooler tự động: $($_.Exception.Message)" }
  }
  if (-not $dbHost) { $dbHost = Read-Host "Nhập Host của Session pooler (Supabase → Connect → Session pooler), ví dụ aws-0-ap-southeast-1.pooler.supabase.com" }

  $sec = Read-Host "Nhập MẬT KHẨU DATABASE của project $($p.Ten) ($ref)" -AsSecureString
  $env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
  $env:PGSSLMODE = "require"
  $conn = @("--host=$dbHost", "--port=5432", "--username=$dbUser", "--dbname=postgres")

  try {
    $fDump = Join-Path $dich "$($p.Ten)_$($ref)_day-du.dump"
    $fCauTruc = Join-Path $dich "$($p.Ten)_$($ref)_cau-truc.sql"
    $fDuLieu = Join-Path $dich "$($p.Ten)_$($ref)_du-lieu.sql"

    Write-Host "1/3 Bản đầy đủ (.dump)…"
    & $pgDump @conn --format=custom --file=$fDump
    if ($LASTEXITCODE -ne 0) { throw "pg_dump bản đầy đủ lỗi (xem thông báo phía trên)" }

    Write-Host "2/3 Cấu trúc (.sql)…"
    & $pgDump @conn --schema-only --file=$fCauTruc
    if ($LASTEXITCODE -ne 0) { throw "pg_dump cấu trúc lỗi" }

    Write-Host "3/3 Dữ liệu public/private/auth (.sql)…"
    & $pgDump @conn --data-only --schema=public --schema=private --schema=auth --schema=storage --schema=supabase_migrations --file=$fDuLieu
    if ($LASTEXITCODE -ne 0) { throw "pg_dump dữ liệu lỗi" }

    # Kiểm tra bản .dump đọc được
    $soDoiTuong = (& $pgRestore --list $fDump | Measure-Object -Line).Lines
    $bangAuth = (& $pgRestore --list $fDump | Select-String "TABLE DATA auth users").Count
    foreach ($f in @($fDump, $fCauTruc, $fDuLieu)) {
      $h = (Get-FileHash $f -Algorithm SHA256).Hash
      $mb = [math]::Round((Get-Item $f).Length / 1MB, 2)
      "$([IO.Path]::GetFileName($f))  $mb MB  SHA256=$h" | Out-File $baoCao -Append -Encoding utf8
    }
    "  $($p.Ten): $soDoiTuong mục trong .dump; có dữ liệu auth.users: $([bool]$bangAuth)" | Out-File $baoCao -Append -Encoding utf8
    Write-Host "OK — $soDoiTuong mục; có auth.users: $([bool]$bangAuth)" -ForegroundColor Green
  }
  finally {
    Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
  }
}
Write-Host "`nXONG. Thư mục: $dich" -ForegroundColor Green
Write-Host "Mở KIEM_TRA.txt để xem kết quả. Chép thêm 1 bản sang ổ ngoài/Google Drive cá nhân (không phải OneDrive dự án)."
