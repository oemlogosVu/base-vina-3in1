// CHÉP PHÂN HỆ NHÂN SỰ từ repo HRM manager (nhánh main) vào app 3 trong 1 — Giai đoạn 2
// ---------------------------------------------------------------------------
// Nguyên tắc (AGENTS.md §4): CHỈ chép, đổi import, đổi đường dẫn. KHÔNG sửa logic chấm công/lương/thuế.
// Chạy lại được bất cứ lúc nào: đọc thẳng từ `git show main:<file>` của repo nguồn, ghi đè bản chép.
// Những file phải sửa tay SAU khi chép (khung trang, phiên…) được liệt kê trong TIEN_DO.md — chạy lại script
// sẽ ghi đè chúng, nên sau khi chạy lại phải xem `git diff` các file đó.
//
// CÁCH CHẠY:  node scripts/port/chep-nhan-su.mjs ["../HRM manager"]
//   → ghi file + scripts/port/bao-cao-duong-dan-nhan-su.txt (mọi chỗ đổi đường dẫn, để rà).
import { execFileSync } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";

const NGUON = process.argv[2] || "../HRM manager";
const REF = "main";
const git = (...a) => execFileSync("git", ["-C", NGUON, ...a], { encoding: "utf8", maxBuffer: 64 << 20 });
const dsFile = git("ls-tree", "-r", "--name-only", REF, "src", "tests").split("\n").filter(Boolean);

// ---- 1. Nơi đặt file ----------------------------------------------------------
const APP = "src/app/(ung-dung)/nhan-su";
const MOD = "src/modules/nhan-su";
/** Đường dẫn URL của HRM (/nhan-su/…, /ho-so…) → đường dẫn trong app 3 trong 1. */
function doiDuongDanUrl(p) {
  if (p === "/ho-so" || p.startsWith("/ho-so/") || p.startsWith("/ho-so?")) return "/nhan-su/ho-so-cua-toi" + p.slice(6);
  if (p === "/nhan-su" || /^\/nhan-su[/?#$]/.test(p)) return "/nhan-su/ho-so" + p.slice(8);
  if (p === "/login" || /^\/login[/?#]/.test(p)) return "/dang-nhap" + p.slice(6);
  if (p === "/doi-mat-khau") return p;
  if (/^\/(cham-cong|luong|quan-tri|sua-chua-cong|to-doi)([/?#$]|$)/.test(p)) return "/nhan-su" + p;
  return null; // không phải đường dẫn trang của HRM
}
/** Thư mục route HRM (vd "nhan-su/[id]") → thư mục trong app mới. */
function doiThuMucRoute(r) {
  if (r === "") return "";
  if (r === "ho-so" || r.startsWith("ho-so/")) return "ho-so-cua-toi" + r.slice(5);
  if (r === "nhan-su" || r.startsWith("nhan-su/")) return "ho-so" + r.slice(7);
  return r;
}
function dich(f) {
  if (/^src\/app\/(login|doi-mat-khau)\//.test(f)) return null; // dùng màn chung của app 3 trong 1
  if (f === "src/app/layout.tsx" || f === "src/app/globals.css") return null; // khung + CSS xử lý riêng
  if (f === "src/proxy.ts" || f === "src/lib/supabase/middleware.ts") return null; // proxy chung
  if (f.startsWith("src/app/")) {
    const rel = f.slice("src/app/".length);
    const thuMuc = rel.includes("/") ? rel.slice(0, rel.lastIndexOf("/")) : "";
    const ten = rel.slice(rel.lastIndexOf("/") + 1);
    const tm = doiThuMucRoute(thuMuc);
    return `${APP}/${tm ? tm + "/" : ""}${ten}`;
  }
  if (f.startsWith("src/lib/")) return f.endsWith(".test.ts") ? `${MOD}/tests/${f.slice(8)}` : `${MOD}/lib/${f.slice(8)}`;
  if (f.startsWith("src/components/")) return `${MOD}/components/${f.slice(15)}`;
  if (f.startsWith("src/types/")) return `${MOD}/types/${f.slice(10)}`;
  if (f.startsWith("tests/")) return `${MOD}/tests/${f.slice(6)}`;
  return null;
}

// ---- 2. Đổi import --------------------------------------------------------------
function doiImport(s, f) {
  s = s.replace(/(['"])@\/lib\//g, "$1@ns/lib/");
  s = s.replace(/(['"])@\/components\//g, "$1@ns/components/");
  s = s.replace(/(['"])@\/types\//g, "$1@ns/types/");
  // Đăng xuất: dùng hành động chung của app 3 trong 1 (HRM import từ @/app/login/actions hoặc ./login/actions).
  s = s.replace(/import\s*\{\s*signOut\s*\}\s*from\s*(['"])(?:@\/app\/login|\.\/login)\/actions\1/g,
    "import { dangXuat as signOut } from $1@/app/dang-nhap/actions$1");
  // import chéo giữa các route HRM: @/app/<route>/… → @/app/(ung-dung)/nhan-su/<route mới>/…
  s = s.replace(/(['"])@\/app\/(?!dang-nhap\/)([^'"]+)\1/g, (m, q, p) => {
    const thuMuc = p.includes("/") ? p.slice(0, p.lastIndexOf("/")) : p;
    const ten = p.includes("/") ? p.slice(p.lastIndexOf("/") + 1) : "";
    return `${q}@/app/(ung-dung)/nhan-su/${doiThuMucRoute(thuMuc)}${ten ? "/" + ten : ""}${q}`;
  });
  // tests/ của HRM (nay ở src/modules/nhan-su/tests/): "../src/lib/x" → @ns/lib/x;
  // "../supabase/functions/…" → lùi 4 cấp về gốc repo (Edge Function dùng chung được chép ở supabase/functions/).
  if (f.startsWith("tests/")) {
    s = s.replace(/(['"])\.\.\/src\/lib\//g, "$1@ns/lib/");
    s = s.replace(/(['"])\.\.\/supabase\/functions\//g, "$1../../../../supabase/functions/");
  }
  // test nằm cạnh file ở src/lib (vd safe-path.test.ts) nay ở tests/: "./x" → @ns/lib/x
  if (/^src\/lib\/[^/]+\.test\.ts$/.test(f)) s = s.replace(/(from\s+['"])\.\//g, "$1@ns/lib/");
  // Số phiên bản: đọc package.json của app 3 trong 1 (file nay sâu hơn 2 cấp).
  if (f === "src/lib/phien-ban.ts") s = s.replace(/(['"])\.\.\/\.\.\/package\.json\1/, "$1../../../../package.json$1");
  return s;
}

// ---- 3. Đổi đường dẫn URL trong chuỗi -------------------------------------------
const baoCao = [];
function doiDuongDan(s, f) {
  // Chuỗi/template bắt đầu bằng "/segment…" — dừng ở dấu đóng chuỗi hoặc ${ (phần động giữ nguyên).
  return s.replace(/(['"`])(\/[a-z][a-z0-9-]*(?:\/[^'"`$\s]*)?(?:[?#][^'"`$\s]*)?)/g, (m, q, p) => {
    const moi = doiDuongDanUrl(p);
    if (moi === null || moi === p) return m;
    baoCao.push(`${f}: ${p}  →  ${moi}`);
    return q + moi;
  });
}

// ---- 4. Khung trang: app 3 trong 1 đã vẽ thanh bên / đầu trang / đăng xuất / đổi mật khẩu ---------
// Chỉ thay hàm KhungTrang (giữ nguyên O, Khoi, Pill của HRM). Menu Nhân sự hiện ở thanh bên chung
// (src/app/(ung-dung)/layout.tsx đọc tabsChoPhep()).
const KHUNG_TRANG_MOI = `import { type Phien } from '@ns/lib/phien'

/**
 * KHUNG TRANG Nhân sự trong app 3 trong 1 (sửa khi chép từ HRM ${REF}, Giai đoạn 2).
 *
 * Bản HRM vẽ cả thanh bên, đầu trang, tên người dùng, "Đổi mật khẩu", "Đăng xuất" và dấu phiên bản.
 * Ở app 3 trong 1 những thứ đó do khung chung vẽ (src/app/(ung-dung)/layout.tsx) — menu Nhân sự
 * (tabsChoPhep) nằm trong thanh bên chung. Ở đây chỉ còn tiêu đề trang + nội dung.
 * Chữ ký hàm giữ nguyên để 26 trang HRM không phải sửa.
 */
export function KhungTrang({
  phien: _phien,
  tieuDe,
  children,
}: {
  phien: Phien
  tieuDe: string
  children: React.ReactNode
}) {
  return (
    <div className="khung-trang-ns">
      <h1 className="header-tieu-de khong-in">{tieuDe}</h1>
      <div className="than-trang-ns">{children}</div>
    </div>
  )
}

`;
function vaKhungTrang(s) {
  const i = s.indexOf("export function O(");
  if (i < 0) throw new Error("khung-trang.tsx của HRM đã đổi cấu trúc — sửa lại bước vá khung trang.");
  return KHUNG_TRANG_MOI + s.slice(i);
}

// ---- 5. CSS: giới hạn trong vỏ .ns-scope, oklch → hex (Android cũ không hiểu oklch) ----------------
function oklchHex(L, C, H) {
  const hr = (H * Math.PI) / 180, a = C * Math.cos(hr), b = C * Math.sin(hr);
  const l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3;
  const m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3;
  const s = (L - 0.0894841775 * a - 1.291485548 * b) ** 3;
  const lin = [
    4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
    -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    -0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s,
  ];
  return "#" + lin.map((x) => {
    const v = x <= 0.0031308 ? 12.92 * x : 1.055 * x ** (1 / 2.4) - 0.055;
    return Math.round(Math.min(1, Math.max(0, v)) * 255).toString(16).padStart(2, "0");
  }).join("");
}
function tachKhoi(css) {
  // → [{sel, body}] cấp 1 (body có thể chứa khối con).
  const kq = []; let i = 0;
  while (i < css.length) {
    const mo = css.indexOf("{", i); if (mo < 0) break;
    let sau = 1, j = mo + 1;
    while (j < css.length && sau > 0) { if (css[j] === "{") sau++; else if (css[j] === "}") sau--; j++; }
    kq.push({ sel: css.slice(i, mo).trim(), body: css.slice(mo + 1, j - 1) });
    i = j;
  }
  return kq;
}
function boc(sel) {
  return sel.split(",").map((x) => x.trim()).filter(Boolean).map((x) =>
    x === ":root" || x === "body" || x === "html" ? ".ns-scope" : `.ns-scope ${x}`).join(",\n");
}
function phamViCss(css) {
  return tachKhoi(css).map(({ sel, body }) => {
    if (sel.startsWith("@media") || sel.startsWith("@supports")) return `${sel} {\n${phamViCss(body)}\n}`;
    if (sel.startsWith("@page") || sel.startsWith("@keyframes")) return `${sel} {${body}}`;
    if (sel.startsWith("@theme")) {
      // Chỉ giữ các biến --color-slate-* (HRM kéo thang xám về bảng màu của mình) — đặt trong vỏ.
      const bien = body.split(";").map((d) => d.trim()).filter((d) => d.startsWith("--color-"));
      return bien.length ? `.ns-scope {\n  ${bien.join(";\n  ")};\n}` : "";
    }
    return `${boc(sel)} {${body}}`;
  }).filter(Boolean).join("\n\n");
}
function chepCss() {
  let css = git("show", `${REF}:src/app/globals.css`);
  css = css.replace(/\/\*[\s\S]*?\*\//g, "");
  css = css.replace(/@import[^;]+;/g, "").replace(/@custom-variant[^;]+;/g, "");
  css = css.replace(/oklch\(\s*([\d.]+)\s+([\d.]+)\s+([\d.]+)\s*\)/g, (m, L, C, H) => oklchHex(+L, +C, +H));
  const dau = `/*
 * CSS phân hệ Nhân sự — SINH TỰ ĐỘNG bởi scripts/port/chep-nhan-su.mjs từ HRM ${REF}:src/app/globals.css.
 * KHÔNG sửa tay (chạy lại script sẽ ghi đè) — chỉnh ở phần "ĐÈ CỦA APP 3 TRONG 1" cuối file qua script.
 *  - Mọi quy tắc nằm trong vỏ .ns-scope (layout /nhan-su) — HRM trùng tên class với phần dùng chung
 *    (.the, .bang, .pill*, .noi-dung) nên không được để ở phạm vi toàn cục.
 *  - oklch() đổi sang hex: Chrome Android < 111 không hiểu oklch.
 *  - Bỏ font riêng của HRM: dùng Be Vietnam Pro của app chung. Chế độ tối: tắt ở globals.css chung.
 */\n\n`;
  const de = `

/* ĐÈ CỦA APP 3 TRONG 1 (design/he-thong-giao-dien): nút chính, link, mục đang chọn dùng NAVY như cả app —
   màu nhấn phân hệ (tím) chỉ để nhận diện, đã có ở khung chung. Thanh xám đậm nhất (nút đen của HRM) → navy. */
.ns-scope {
  --mau-nhan: #1f3a5c;
  --mau-nhan-dam: #16293f;
  --mau-nhan-nen: #e9ebef;
  --color-slate-900: #1f3a5c;
  max-width: 1040px;
}
.ns-scope .header-tieu-de { margin-bottom: 4px; }
.ns-scope .than-trang-ns { margin-top: 16px; display: flex; flex-direction: column; gap: 20px; }
`;
  mkdirSync(MOD, { recursive: true });
  writeFileSync(`${MOD}/nhan-su.css`, dau + phamViCss(css) + de);
}

// ---- Chạy -----------------------------------------------------------------------
let dem = 0;
const boQua = [];
for (const f of dsFile) {
  const d = dich(f);
  if (!d) { boQua.push(f); continue; }
  let s = git("show", `${REF}:${f}`);
  if (/\.(ts|tsx)$/.test(f)) s = doiDuongDan(doiImport(s, f), f);
  if (f === "src/components/khung-trang.tsx") s = vaKhungTrang(s);
  mkdirSync(dirname(d), { recursive: true });
  writeFileSync(d, s);
  dem++;
}
chepCss();
const muc = git("rev-parse", "--short", REF).trim();
writeFileSync("scripts/port/bao-cao-duong-dan-nhan-su.txt",
  `Đổi đường dẫn khi chép Nhân sự (HRM ${REF} ${muc}) — ${baoCao.length} chỗ\n\n` + baoCao.join("\n") + "\n");
console.log(`Đã chép ${dem} file từ HRM ${REF} ${muc}; bỏ qua ${boQua.length}: ${boQua.join(", ")}`);
console.log(`Đổi đường dẫn: ${baoCao.length} chỗ (xem scripts/port/bao-cao-duong-dan-nhan-su.txt)`);
