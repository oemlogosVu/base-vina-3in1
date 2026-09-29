// TẢI FILE ĐÍNH KÈM NHÂN SỰ (từ bản sao lưu) LÊN PROJECT THỬ
// ---------------------------------------------------------------------------
// - CHỈ chạy trên project thử rgcimlgfuwjxjapefzyj; mã khác → dừng ngay.
// - Khóa quản trị của project thử lấy TẠM trong bộ nhớ qua Management API bằng SUPABASE_ACCESS_TOKEN_THU
//   (token này chỉ thấy project thử). Không lưu, không in ra.
// - Nguồn: <thư mục>/storage_NhanSu_naglcxbpxnntiglrzeqx/<bucket>/<đường dẫn gốc> (do scripts/sao-luu/tai-file-storage.mjs tạo).
// - Giữ nguyên bucket + đường dẫn (bảng dữ liệu trỏ tới file theo đường dẫn). Bucket phải có sẵn
//   (tạo khi nạp database bằng nap-nhan-su-vao-ban-thu.ps1).
// - Chạy lại được: file đã có trên bản thử (cùng kích thước) sẽ bỏ qua.
//
// CÁCH CHẠY:  node scripts/ban-thu/tai-file-len-ban-thu.mjs "F:\SaoLuu_BaseVina"
import { execSync } from "node:child_process";
import { readdirSync, readFileSync, statSync, existsSync } from "node:fs";
import { join, relative, extname } from "node:path";

const REF_THU = "rgcimlgfuwjxjapefzyj";
const REF_THAT = ["naglcxbpxnntiglrzeqx", "eodrpyedatohsovobsxj"];
if (REF_THAT.includes(REF_THU)) throw new Error("DỪNG: mã project là project THẬT.");
const THU_MUC = process.argv[2] || "F:\\SaoLuu_BaseVina";
const GOC = join(THU_MUC, "storage_NhanSu_naglcxbpxnntiglrzeqx");
if (!existsSync(GOC)) throw new Error(`Không thấy bản sao lưu file: ${GOC}`);

let token = process.env.SUPABASE_ACCESS_TOKEN_THU;
if (!token && process.platform === "win32") {
  token = execSync(`powershell -NoProfile -Command "[Environment]::GetEnvironmentVariable('SUPABASE_ACCESS_TOKEN_THU','User')"`).toString().trim();
}
if (!token) throw new Error("Thiếu SUPABASE_ACCESS_TOKEN_THU.");

const r0 = await fetch(`https://api.supabase.com/v1/projects/${REF_THU}/api-keys?reveal=true`, { headers: { Authorization: `Bearer ${token}` } });
if (!r0.ok) throw new Error(`Không lấy được khóa project thử: HTTP ${r0.status}`);
const ds = await r0.json();
const key = (ds.find((k) => k.type === "secret" && k.api_key) ?? ds.find((k) => k.name === "service_role" && k.api_key))?.api_key;
if (!key) throw new Error("Project thử không có secret/service_role key.");
const headers = { apikey: key, ...(key.startsWith("eyJ") ? { Authorization: `Bearer ${key}` } : {}) };
const base = `https://${REF_THU}.supabase.co`;

const LOAI = { ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".png": "image/png", ".webp": "image/webp", ".heic": "image/heic", ".pdf": "application/pdf" };

function lietKeFile(thuMuc) {
  return readdirSync(thuMuc, { withFileTypes: true }).flatMap((d) =>
    d.isDirectory() ? lietKeFile(join(thuMuc, d.name)) : [join(thuMuc, d.name)]);
}

async function kichThuocTrenBanThu(bucket, duongDan) {
  const r = await fetch(`${base}/storage/v1/object/info/${bucket}/${duongDan.split("/").map(encodeURIComponent).join("/")}`, { headers });
  if (!r.ok) return null;
  const j = await r.json();
  return j.size ?? j.metadata?.size ?? null;
}

let tongLoi = 0;
for (const bucket of readdirSync(GOC, { withFileTypes: true }).filter((d) => d.isDirectory()).map((d) => d.name)) {
  const files = lietKeFile(join(GOC, bucket));
  let tai = 0, boQua = 0, loi = 0;
  for (const f of files) {
    const duongDan = relative(join(GOC, bucket), f).split("\\").join("/");
    const size = statSync(f).size;
    if ((await kichThuocTrenBanThu(bucket, duongDan)) === size) { boQua++; continue; }
    try {
      const r = await fetch(`${base}/storage/v1/object/${bucket}/${duongDan.split("/").map(encodeURIComponent).join("/")}`, {
        method: "POST",
        headers: { ...headers, "Content-Type": LOAI[extname(f).toLowerCase()] ?? "application/octet-stream", "x-upsert": "true" },
        body: readFileSync(f),
      });
      if (!r.ok) throw new Error(`HTTP ${r.status} ${(await r.text()).slice(0, 120)}`);
      tai++;
    } catch (e) {
      loi++;
      console.error(`  LỖI ${bucket}/${duongDan}: ${e.message}`);
    }
  }
  tongLoi += loi;
  console.log(`${bucket}: ${files.length} file — tải lên ${tai}, đã có ${boQua}, lỗi ${loi}`);
}
console.log(tongLoi ? `\nXONG nhưng có ${tongLoi} lỗi.` : "\nXONG, không lỗi.");
