// SINH MIGRATION QUYỀN TRUY CẬP từ quyền thật của 2 DB nguồn (Nhân sự + Tài chính)
// ---------------------------------------------------------------------------
// Vì sao cần: project Supabase MỚI mặc định cấp ALL cho anon/authenticated trên mọi bảng tạo ra.
// Nạp cấu trúc bằng pg_restore chỉ THÊM quyền, không THU HỒI phần mặc định → bản thử lỏng hơn thật
// (phát hiện 30/09: anon có đủ quyền trên 90 bảng). Migration sinh ra đây đặt quyền ĐÚNG như DB thật:
// thu hồi hết từ anon/authenticated rồi cấp lại theo ACL nguồn (bảng, cột, hàm, sequence, schema private).
//
// Đầu vào: 2 file JSON đọc CHỈ-ĐỌC từ DB thật qua Management API (read-only), dạng
//   { bang:[{ten,loai,acl}], cot:[{bang,cot,acl}], ham:[{ham,acl}], schema:[{ten,acl}], mac_dinh:[...] }
// Chạy: node scripts/db/sinh-quyen-truy-cap.mjs <quyen-ns.json> <quyen-tc.json> <file-migration.sql>
import { readFileSync, writeFileSync } from "node:fs";

const [fNs, fTc, dich] = process.argv.slice(2);
const doc = (f) => JSON.parse(readFileSync(f, "utf8"))[0].kq;
const ns = doc(fNs);
const tc = doc(fTc);

// Tài chính: bảng chung_tu đổi tên chung_tu_fmb (migration 20260930000001).
const doiTenTc = (ten) => (ten === "chung_tu" ? "chung_tu_fmb" : ten);
const doiTenHamTc = (sig) => sig; // hàm không đổi tên

const QUYEN = { r: "SELECT", a: "INSERT", w: "UPDATE", d: "DELETE", D: "TRUNCATE", x: "REFERENCES", t: "TRIGGER", m: "MAINTAIN", X: "EXECUTE", U: "USAGE" };
const VAI = ["anon", "authenticated"];

/** "{postgres=arwd/postgres,authenticated=r/postgres,=X/postgres}" → [{ai:"authenticated", quyen:["SELECT"]}] */
function tachAcl(acl) {
  if (!acl) return null;
  return acl
    .replace(/^\{|\}$/g, "")
    .split(",")
    .map((muc) => {
      const [ai, phan] = muc.split("=");
      const chu = (phan || "").split("/")[0].replace(/\*/g, "");
      return { ai: ai === "" ? "public" : ai, quyen: [...chu].map((c) => QUYEN[c]).filter(Boolean) };
    });
}

const L = [];
const dong = (s) => L.push(s);

dong(`-- =====================================================================
-- QUYỀN TRUY CẬP — đặt đúng như DB thật (SINH TỰ ĐỘNG bởi scripts/db/sinh-quyen-truy-cap.mjs, 30/09/2026)
--
-- Nguồn: ACL thật đọc chỉ-đọc từ DB Nhân sự (naglcxbpxnntiglrzeqx) và Tài chính (eodrpyedatohsovobsxj).
-- Lý do: project Supabase mới tự cấp ALL cho anon/authenticated trên bảng mới; pg_restore không thu hồi
-- → bản thử lỏng hơn thật. File này THU HỒI rồi CẤP LẠI đúng như nguồn. Chạy lại nhiều lần được.
-- KHÔNG thêm/bớt quyền so với 2 DB thật (Tài chính vẫn cấp đủ quyền bảng cho authenticated như hiện tại,
-- RLS là lớp chặn) — siết thêm là việc riêng, phải được chủ dự án duyệt.
-- =====================================================================

-- Bảng tạo mới trong public KHÔNG tự cấp gì cho anon/authenticated (như Nhân sự đã siết từ 10/08).
alter default privileges for role postgres in schema public revoke all on tables from anon, authenticated;
`);

function quyenBang(nguon, doiTen, nhan) {
  dong(`\n-- ---- Bảng / view / sequence: ${nhan} ----`);
  for (const b of [...nguon.bang].sort((a, b2) => a.ten.localeCompare(b2.ten))) {
    const ten = doiTen(b.ten);
    const loai = b.loai === "S" ? "sequence" : "table";
    dong(`revoke all on ${loai} public.${ten} from anon, authenticated;`);
    for (const m of tachAcl(b.acl) || []) {
      if (!VAI.includes(m.ai) || m.quyen.length === 0) continue;
      dong(`grant ${m.quyen.join(", ")} on ${loai} public.${ten} to ${m.ai};`);
    }
  }
  const cot = nguon.cot || [];
  if (cot.length) dong(`\n-- ---- Quyền theo cột: ${nhan} ----`);
  for (const c of cot) {
    for (const m of tachAcl(c.acl) || []) {
      if (!VAI.includes(m.ai) || m.quyen.length === 0) continue;
      // Mỗi quyền phải đi kèm danh sách cột RIÊNG: "grant INSERT, UPDATE (c)" = INSERT CẢ BẢNG + UPDATE cột c.
      dong(`grant ${m.quyen.map((q) => `${q} (${c.cot})`).join(", ")} on public.${doiTen(c.bang)} to ${m.ai};`);
    }
  }
}

function quyenHam(nguon, doiTenHam, nhan) {
  dong(`\n-- ---- Hàm: ${nhan} ----`);
  for (const h of [...nguon.ham].sort((a, b) => a.ham.localeCompare(b.ham))) {
    const sig = doiTenHam(h.ham).replace(/^(?!public\.|private\.)/, "public.");
    dong(`revoke all on function ${sig} from public, anon, authenticated;`);
    const acl = tachAcl(h.acl);
    if (acl === null) {
      // ACL trống = mặc định của Postgres: PUBLIC được chạy.
      dong(`grant execute on function ${sig} to public;`);
      continue;
    }
    for (const m of acl) {
      if (![...VAI, "public"].includes(m.ai) || !m.quyen.includes("EXECUTE")) continue;
      dong(`grant execute on function ${sig} to ${m.ai};`);
    }
  }
}

quyenBang(ns, (t) => t, "Nhân sự");
quyenBang(tc, doiTenTc, "Tài chính");
quyenHam(ns, (s) => s, "Nhân sự");
quyenHam(tc, doiTenHamTc, "Tài chính");

const pv = (tc.schema || []).find((s) => s.ten === "private");
if (pv) {
  dong(`\n-- ---- Schema private (Tài chính) ----`);
  dong(`revoke all on schema private from public, anon, authenticated;`);
  for (const m of tachAcl(pv.acl) || []) {
    if (!VAI.includes(m.ai) || m.quyen.length === 0) continue;
    dong(`grant ${m.quyen.join(", ")} on schema private to ${m.ai};`);
  }
}

writeFileSync(dich, L.join("\n") + "\n");
console.log(`da sinh ${L.length} dong → ${dich}`);
