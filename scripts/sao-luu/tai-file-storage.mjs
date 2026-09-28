// TẢI TOÀN BỘ FILE TRONG MỌI BUCKET CỦA 2 PROJECT SUPABASE (Tài chính + Nhân sự)
// ---------------------------------------------------------------------------
// - Khóa quản trị (service/secret key) được lấy TẠM trong bộ nhớ qua Management API bằng
//   SUPABASE_ACCESS_TOKEN (biến môi trường User đã có sẵn). Không lưu, không in ra.
// - Giữ nguyên đường dẫn file: <thư mục>/<Ten>_<ref>/<bucket>/<đường dẫn gốc>
// - Ghi DANH_SACH.csv (bucket, đường dẫn, kích thước, SHA256) để đối chiếu khi chép sang bucket mới.
// - Chạy lại được: file đã tải đủ kích thước sẽ bỏ qua.
//
// CÁCH CHẠY:  node scripts/sao-luu/tai-file-storage.mjs "F:\SaoLuu_BaseVina"
// Chạy thử (chỉ đếm file, không tải):  node scripts/sao-luu/tai-file-storage.mjs --chi-liet-ke
import { execSync } from "node:child_process";
import { createHash } from "node:crypto";
import { mkdirSync, writeFileSync, existsSync, statSync, appendFileSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";

const CHI_LIET_KE = process.argv.includes("--chi-liet-ke");
const THU_MUC = process.argv.slice(2).find((a) => !a.startsWith("--")) || "F:\\SaoLuu_BaseVina";
const PROJECTS = [
  { ten: "TaiChinh", ref: "eodrpyedatohsovobsxj" },
  { ten: "NhanSu", ref: "naglcxbpxnntiglrzeqx" },
];

let token = process.env.SUPABASE_ACCESS_TOKEN;
if (!token && process.platform === "win32") {
  token = execSync(`powershell -NoProfile -Command "[Environment]::GetEnvironmentVariable('SUPABASE_ACCESS_TOKEN','User')"`).toString().trim();
}
if (!token) throw new Error("Thiếu SUPABASE_ACCESS_TOKEN.");

async function layKhoaQuanTri(ref) {
  const r = await fetch(`https://api.supabase.com/v1/projects/${ref}/api-keys?reveal=true`, { headers: { Authorization: `Bearer ${token}` } });
  if (!r.ok) throw new Error(`Không lấy được khóa của ${ref}: HTTP ${r.status}`);
  const ds = await r.json();
  const secret = ds.find((k) => k.type === "secret" && k.api_key);
  const legacy = ds.find((k) => k.name === "service_role" && k.api_key);
  const k = secret ?? legacy;
  if (!k) throw new Error(`Project ${ref} không có secret/service_role key.`);
  return k.api_key;
}

function headers(key) {
  const h = { apikey: key };
  if (key.startsWith("eyJ")) h.Authorization = `Bearer ${key}`; // khóa JWT kiểu cũ
  return h;
}

async function lietKe(base, key, bucket, prefix = "") {
  const kq = [];
  for (let offset = 0; ; offset += 1000) {
    const r = await fetch(`${base}/storage/v1/object/list/${bucket}`, {
      method: "POST",
      headers: { ...headers(key), "Content-Type": "application/json" },
      body: JSON.stringify({ prefix, limit: 1000, offset, sortBy: { column: "name", order: "asc" } }),
    });
    if (!r.ok) throw new Error(`Liệt kê ${bucket}/${prefix} lỗi HTTP ${r.status}`);
    const trang = await r.json();
    for (const x of trang) {
      const duongDan = prefix ? `${prefix}/${x.name}` : x.name;
      if (x.id === null) kq.push(...(await lietKe(base, key, bucket, duongDan))); // thư mục
      else kq.push({ duongDan, size: x.metadata?.size ?? null });
    }
    if (trang.length < 1000) break;
  }
  return kq;
}

for (const p of PROJECTS) {
  const base = `https://${p.ref}.supabase.co`;
  const key = await layKhoaQuanTri(p.ref);
  if (CHI_LIET_KE) {
    const rb = await fetch(`${base}/storage/v1/bucket`, { headers: headers(key) });
    if (!rb.ok) throw new Error(`Không liệt kê được bucket của ${p.ref}: HTTP ${rb.status}`);
    for (const b of await rb.json()) {
      const files = await lietKe(base, key, b.id);
      const mb = files.reduce((s, f) => s + (f.size ?? 0), 0) / 1048576;
      console.log(`${p.ten} / ${b.id}: ${files.length} file, ${mb.toFixed(1)} MB`);
    }
    continue;
  }
  const goc = join(THU_MUC, `storage_${p.ten}_${p.ref}`);
  mkdirSync(goc, { recursive: true });
  const csv = join(goc, "DANH_SACH.csv");
  if (!existsSync(csv)) writeFileSync(csv, "\uFEFFbucket,duong_dan,kich_thuoc,sha256\n");
  const daGhi = new Set(readFileSync(csv, "utf8").split("\n").map((d) => d.split(",").slice(0, 2).join(",")));

  const rb = await fetch(`${base}/storage/v1/bucket`, { headers: headers(key) });
  if (!rb.ok) throw new Error(`Không liệt kê được bucket của ${p.ref}: HTTP ${rb.status}`);
  const buckets = await rb.json();
  console.log(`\n===== ${p.ten} (${p.ref}) — ${buckets.length} bucket: ${buckets.map((b) => b.id).join(", ")}`);

  for (const b of buckets) {
    const files = await lietKe(base, key, b.id);
    let tai = 0, boQua = 0, loi = 0;
    for (const f of files) {
      const dich = join(goc, b.id, ...f.duongDan.split("/"));
      if (existsSync(dich) && f.size !== null && statSync(dich).size === f.size) { boQua++; continue; }
      try {
        const r = await fetch(`${base}/storage/v1/object/${b.id}/${f.duongDan.split("/").map(encodeURIComponent).join("/")}`, { headers: headers(key) });
        if (!r.ok) throw new Error(`HTTP ${r.status}`);
        const buf = Buffer.from(await r.arrayBuffer());
        mkdirSync(dirname(dich), { recursive: true });
        writeFileSync(dich, buf);
        const dong = `${b.id},"${f.duongDan}"`;
        if (!daGhi.has(dong)) appendFileSync(csv, `${dong},${buf.length},${createHash("sha256").update(buf).digest("hex")}\n`);
        tai++;
      } catch (e) {
        loi++;
        console.error(`  LỖI ${b.id}/${f.duongDan}: ${e.message}`);
      }
    }
    console.log(`  ${b.id}: ${files.length} file — tải mới ${tai}, đã có ${boQua}, lỗi ${loi}`);
  }
}
console.log(`\nXONG. Thư mục: ${THU_MUC}`);
