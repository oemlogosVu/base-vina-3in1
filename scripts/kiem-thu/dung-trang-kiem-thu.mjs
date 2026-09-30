// DỰNG TRANG KIỂM THỬ (artifact https://claude.ai/artifact/9ctnM4V3uARiJN8iz2arkR) từ docs/KIEM_THU_NHAN_SU.md.
// Chạy: node scripts/kiem-thu/dung-trang-kiem-thu.mjs docs/KIEM_THU_NHAN_SU.md scripts/kiem-thu/mau-trang-kiem-thu.html <file-ra.html>
// rồi xuất bản lại artifact bằng URL trên (kết quả đã đánh dấu nằm ở db "ket_qua", giữ nguyên khi xuất bản lại).
import { readFileSync, writeFileSync } from "node:fs";
const [md, mau, ra] = process.argv.slice(2);
const L = readFileSync(md, "utf8").split(/\r?\n/);
const nhom = []; let hienTai = null; const hanChe = []; let vungHanChe = false;
const sach = (s) => s.replace(/`/g, "").trim();
for (const l of L) {
  const h = l.match(/^## (.+)$/);
  if (h) { vungHanChe = /Hạn chế/.test(h[1]); hienTai = vungHanChe ? null : { ten: h[1].replace(/\s*\(.*\)\s*$/, "").trim(), ca: [] }; if (hienTai) nhom.push(hienTai); continue; }
  if (vungHanChe) { if (/^- /.test(l)) hanChe.push(sach(l.slice(2))); else if (/^\s+\S/.test(l) && hanChe.length) hanChe[hanChe.length - 1] += " " + sach(l); continue; }
  const r = l.match(/^\| ([A-Z]+-\d+) \| (.+?) \| (.+?) \|\s*\|$/);
  if (r && hienTai) hienTai.ca.push({ ma: r[1], viec: sach(r[2]).replace(/\*\*/g, ""), dung: sach(r[3]) });
}
const ds = nhom.filter((n) => n.ca.length);
const so = ds.reduce((s, n) => s + n.ca.length, 0);
let h = readFileSync(mau, "utf8");
h = h.replaceAll("__SO_CA__", String(so)).replace("__LINK__", "https://base-vina-3in1-git-giai-doan-2-trieu-vu.vercel.app")
  .replace("__NHOM__", JSON.stringify(ds)).replace("__HAN_CHE__", JSON.stringify(hanChe));
writeFileSync(ra, h);
console.log("nhom:", ds.map((n) => `${n.ten} (${n.ca.length})`).join(" | "));
console.log("tong ca:", so, "| han che:", hanChe.length, "| ma trung:", ds.flatMap((n) => n.ca.map((c) => c.ma)).filter((m, i, a) => a.indexOf(m) !== i));
