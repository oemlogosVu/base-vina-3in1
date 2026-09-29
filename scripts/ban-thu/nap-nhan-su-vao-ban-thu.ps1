<#
  NẠP DATABASE NHÂN SỰ (từ bản sao lưu) VÀO PROJECT THỬ
  ------------------------------------------------------
  Chủ dự án duyệt 29/09/2026: bản thử dùng dữ liệu THẬT (quyết định 1a), project thử ở tài khoản Supabase riêng.
  - CHỈ chạy trên project thử rgcimlgfuwjxjapefzyj; mã khác → dừng ngay.
  - Chỉ nạp khi project thử chưa có bảng nào trong schema public (không ghi đè).
  - Nạp: toàn bộ schema public (bảng, dữ liệu, hàm, trigger, RLS, policy, quyền), lịch sử migration,
    tài khoản (auth.users + auth.identities), danh mục bucket, 3 policy storage, trigger on_auth_user_created.
  - KHÔNG nạp: lịch chạy pg_cron (tổng hợp công 00:15), phiên đăng nhập, vault, file thật (tải riêng).
  - Sau khi nạp: nếu có biến MAT_KHAU_THU thì đặt mật khẩu đó cho MỌI tài khoản trong project thử.

  CÁCH CHẠY:
    powershell -ExecutionPolicy Bypass -File .\scripts\ban-thu\nap-nhan-su-vao-ban-thu.ps1 -BanSao "F:\SaoLuu_BaseVina\db_<ngày>\NhanSu_naglcxbpxnntiglrzeqx_day-du.dump"
  Cần: F:\pgsql\bin (PostgreSQL 17), biến User SUPABASE_DB_PASSWORD_THU, mạng IPv6 (kết nối thẳng db.<ref>.supabase.co).
#>
param(
  [Parameter(Mandatory = $true)][string]$BanSao,
  [string]$Bin = "F:\pgsql\bin"
)
$ErrorActionPreference = "Continue"

$REF_THU = "rgcimlgfuwjxjapefzyj"
$REF_THAT = @("naglcxbpxnntiglrzeqx", "eodrpyedatohsovobsxj")
$dbHost = "db.$REF_THU.supabase.co"
if ($REF_THAT | Where-Object { $dbHost -like "*$_*" }) { throw "DỪNG: địa chỉ trỏ vào project THẬT." }
if (-not (Test-Path $BanSao)) { throw "Không thấy bản sao lưu: $BanSao" }

$psql = Join-Path $Bin "psql.exe"; $pgRestore = Join-Path $Bin "pg_restore.exe"
$mk = [Environment]::GetEnvironmentVariable("SUPABASE_DB_PASSWORD_THU", "User")
if (-not $mk) { throw "Thiếu biến môi trường SUPABASE_DB_PASSWORD_THU." }
$env:PGPASSWORD = $mk; $mk = $null; $env:PGSSLMODE = "require"
$conn = @("--host=$dbHost", "--port=5432", "--username=postgres", "--dbname=postgres")

try {
  # 1) Project thử phải còn trống
  $soBang = (& $psql @conn -tAc "select count(*) from information_schema.tables where table_schema='public'")
  if ($LASTEXITCODE -ne 0) { throw "Không kết nối được project thử." }
  if ([int]("$soBang".Trim()) -gt 0) { throw "DỪNG: project thử đã có $soBang bảng public — không nạp chồng." }

  # 2) Danh sách mục cần nạp (lọc từ bản sao lưu)
  $tatCa = & $pgRestore --list $BanSao
  $chon = $tatCa | Where-Object {
    $_ -match '^\d+; \d+ \d+ (TABLE DATA|FK CONSTRAINT|ROW SECURITY|SEQUENCE SET|SEQUENCE OWNED BY|MATERIALIZED VIEW|[A-Z]+) (public|supabase_migrations) ' -or
    $_ -match ' SCHEMA - supabase_migrations | POLICY storage objects | TRIGGER auth users on_auth_user_created | TABLE DATA (auth (users|identities)|storage buckets) '
  }
  # auth.identities tham chiếu auth.users → đưa dòng identities xuống cuối để nạp SAU users
  $chon = @($chon | Where-Object { $_ -notmatch ' TABLE DATA auth identities ' }) + @($chon | Where-Object { $_ -match ' TABLE DATA auth identities ' })
  $fList = Join-Path $env:TEMP "nap-nhan-su.list"
  $chon | Set-Content $fList -Encoding ascii
  Write-Host "Sẽ nạp $($chon.Count) mục."

  # 3) Nạp (không đổi chủ sở hữu; lỗi ghi ra file để soát)
  $fLoi = Join-Path (Split-Path $BanSao) "nap-ban-thu-loi.txt"
  & $pgRestore @conn --no-owner -L $fList $BanSao 2> $fLoi
  # PowerShell 5.1 bọc dòng stderr ("pg_restore.exe : pg_restore: error …") → không neo đầu dòng
  $soLoi = (Select-String -Path $fLoi -Pattern "pg_restore: error" | Measure-Object).Count
  Write-Host "Nạp xong. Số lỗi: $soLoi (chi tiết: $fLoi)"

  # 4) Mật khẩu thử chung (truyền qua biến môi trường, không in, không ghi file)
  $mkThu = [Environment]::GetEnvironmentVariable("MAT_KHAU_THU", "User")
  if ($mkThu) {
    $env:MKTHU = $mkThu; $mkThu = $null
    "\getenv mk MKTHU`nupdate auth.users set encrypted_password = extensions.crypt(:'mk', extensions.gen_salt('bf')) where encrypted_password is not null and encrypted_password <> '';" |
      & $psql @conn -v ON_ERROR_STOP=1 -q
    if ($LASTEXITCODE -eq 0) { Write-Host "Đã đặt mật khẩu thử chung cho các tài khoản." } else { Write-Warning "Đặt mật khẩu thử LỖI — tài khoản đang giữ mật khẩu THẬT." }
    Remove-Item Env:MKTHU
  } else { Write-Warning "Chưa có MAT_KHAU_THU — tài khoản trong bản thử đang giữ mật khẩu THẬT." }
}
finally {
  Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
}
