// ĐỐI CHIẾU DANH MỤC TRÙNG NHAU GIỮA 3 APP (CHỈ ĐỌC — không ghi gì vào DB/Sheet thật)
// -------------------------------------------------------------------------------
// Nguồn:
//   Tài chính : Supabase eodrpyedatohsovobsxj (qua Management API, truy vấn read_only)
//   Nhân sự   : Supabase naglcxbpxnntiglrzeqx (như trên)
//   Kho       : Google Sheet (Service Account, quyền CHỈ ĐỌC; KHÔNG đọc cột hash mật khẩu)
// Kết quả: .local/doi-chieu/DOI_CHIEU_DANH_MUC_<ngày>.xlsx (git bỏ qua — có dữ liệu cá nhân)
//   mỗi sheet có cột "Xác nhận" để chủ dự án đánh dấu ĐÚNG / SAI / GHI CHÚ.
//
// CÁCH CHẠY (từ thư mục "Combine 3 in 1"):
//   node --env-file="../Inventory manager/.env.local" scripts/doi-chieu/doi-chieu-danh-muc.mjs
// Dùng lại thư viện googleapis + xlsx có sẵn trong repo Inventory (không cài thêm).
import { execSync } from "node:child_process";
import { createRequire } from "node:module";
import { mkdirSync } from "node:fs";
import { resolve, join } from "node:path";

const requireKho = createRequire(resolve("../Inventory manager/package.json"));
const { google } = requireKho("googleapis");
const XLSX = requireKho("xlsx");

const REF_TC = "eodrpyedatohsovobsxj";
const REF_NS = "naglcxbpxnntiglrzeqx";

// ---------- Nguồn dữ liệu ----------
let token = process.env.SUPABASE_ACCESS_TOKEN;
if (!token && process.platform === "win32") {
  token = execSync(`powershell -NoProfile -Command "[Environment]::GetEnvironmentVariable('SUPABASE_ACCESS_TOKEN','User')"`).toString().trim();
}
if (!token) throw new Error("Thiếu SUPABASE_ACCESS_TOKEN.");

async function sql(ref, query) {
  const r = await fetch(`https://api.supabase.com/v1/projects/${ref}/database/query`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({ query, read_only: true }),
  });
  if (!r.ok) throw new Error(`Truy vấn ${ref} lỗi HTTP ${r.status}: ${(await r.text()).slice(0, 200)}`);
  return r.json();
}

async function docSheetKho() {
  const { GOOGLE_SERVICE_ACCOUNT_EMAIL: email, GOOGLE_PRIVATE_KEY: key, SHEET_ID: id } = process.env;
  if (!email || !key || !id) throw new Error("Thiếu biến Google/SHEET_ID — chạy kèm --env-file như hướng dẫn.");
  const auth = new google.auth.JWT({ email, key: key.replace(/\\n/g, "\n"), scopes: ["https://www.googleapis.com/auth/spreadsheets.readonly"] });
  const sheets = google.sheets({ version: "v4", auth });
  // dm_nguoi_dung chỉ đọc A:E (bỏ cột F = hash mật khẩu, G = cờ đổi MK)
  const ranges = ["dm_kho!A2:E", "dm_ncc!A2:F", "dm_bo_phan!A2:D", "dm_nguoi_dung!A2:E"];
  const r = await sheets.spreadsheets.values.batchGet({ spreadsheetId: id, ranges, valueRenderOption: "UNFORMATTED_VALUE" });
  const [kho, ncc, bp, nd] = r.data.valueRanges.map((v) => (v.values ?? []).filter((d) => d.some((o) => String(o ?? "").trim())));
  const s = (x) => String(x ?? "").trim();
  return {
    kho: kho.map((d) => ({ ma: s(d[0]), ten: s(d[1]), dia_diem: s(d[2]), thu_kho: s(d[3]), trang_thai: s(d[4]) })),
    ncc: ncc.map((d) => ({ ma: s(d[0]), ten: s(d[1]), mst: s(d[2]), dien_thoai: s(d[3]), dia_chi: s(d[4]), trang_thai: s(d[5]) })),
    boPhan: bp.map((d) => ({ ma: s(d[0]), ten: s(d[1]), email_quan_ly: s(d[2]), trang_thai: s(d[3]) })),
    nguoiDung: nd.map((d) => ({ email: s(d[0]).toLowerCase(), ho_ten: s(d[1]), vai_tro: s(d[2]), kho_phu_trach: s(d[3]), trang_thai: s(d[4]) })),
  };
}

// ---------- Chuẩn hoá để so ----------
const boDau = (s) => String(s ?? "").normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/đ/g, "d").replace(/Đ/g, "D");
const chuan = (s) => boDau(s).toLowerCase().replace(/[^a-z0-9 ]/g, " ").replace(/\s+/g, " ").trim();
const TU_PHAP_LY = /\b(cong ty|cty|ct|tnhh|co phan|cp|mtv|mot thanh vien|dntn|doanh nghiep tu nhan|ho kinh doanh|hkd|chi nhanh|tm|dv|xd|tmxd|tmdv|thuong mai|dich vu|xay dung|san xuat|va|dau tu|tap doan|viet nam|vn)\b/g;
// Từ chung của tên công trình/kho/tổ đội — bỏ đi để còn lại ĐỊA DANH dùng ghép công trình
const TU_CONG_TRINH = /\b(cong trinh|cong truong|ctr|du an|lam|kho|vat tu|cong cu|chu dau tu|cdt|chinh|base vina|to doi|doi|thi cong|so \d+|nha o xa hoi|xa hoi|nha o|phuong|tinh|xa|huyen|thanh pho|tp|duong dan|cau)\b/g;
const diaDanh = (s) => loi(s).replace(TU_CONG_TRINH, " ").replace(/\s+/g, " ").trim();
const bigram = (s) => { const t = s.split(" ").filter(Boolean); const b = new Set(); for (let i = 0; i + 1 < t.length; i++) b.add(`${t[i]} ${t[i + 1]}`); return b; };
const loi = (s) => chuan(s).replace(TU_PHAP_LY, " ").replace(/\s+/g, " ").trim();
const mst = (s) => String(s ?? "").replace(/[^0-9-]/g, "").replace(/-+$/, "");
const sdt = (s) => {
  let d = String(s ?? "").replace(/\D/g, "");
  if (d.startsWith("84") && d.length >= 11) d = "0" + d.slice(2);
  if (d.length === 9) d = "0" + d;
  return d.length >= 9 ? d : "";
};
const mail = (s) => String(s ?? "").trim().toLowerCase();
const tuSdtDangNhap = (email) => (email?.endsWith("@sodienthoai.local") ? sdt(email.split("@")[0]) : "");
const jaccard = (a, b) => {
  const A = new Set(a.split(" ").filter(Boolean)), B = new Set(b.split(" ").filter(Boolean));
  if (!A.size || !B.size) return 0;
  let chung = 0; for (const x of A) if (B.has(x)) chung++;
  return chung / (A.size + B.size - chung);
};
const duoi4 = (s) => { const d = String(s ?? "").replace(/\D/g, ""); return d ? `…${d.slice(-4)}` : ""; };

// Ghép danh sách A với B theo thứ tự luật; trả các cặp + phần lẻ
function ghep(A, B, luat) {
  const daB = new Set(), cap = [];
  for (const a of A) {
    let tim = null;
    for (const [ten, fn, tinCay] of luat) {
      const ung = B.map((b, i) => [b, i]).filter(([b, i]) => !daB.has(i) && fn(a, b));
      if (ung.length === 1) { tim = { b: ung[0][0], i: ung[0][1], can_cu: ten, tin_cay: tinCay }; break; }
      if (ung.length > 1) { tim = { b: ung[0][0], i: ung[0][1], can_cu: `${ten} (có ${ung.length} ứng viên!)`, tin_cay: "CẦN XÁC NHẬN" }; break; }
    }
    if (tim) { daB.add(tim.i); cap.push({ a, b: tim.b, can_cu: tim.can_cu, tin_cay: tim.tin_cay }); }
    else cap.push({ a, b: null, can_cu: "", tin_cay: "" });
  }
  B.forEach((b, i) => { if (!daB.has(i)) cap.push({ a: null, b, can_cu: "", tin_cay: "" }); });
  return cap;
}
const trangThai = (c, tenA, tenB) => (c.a && c.b ? (c.tin_cay === "CHẮC CHẮN" ? "KHỚP" : "CẦN XÁC NHẬN") : c.a ? `CHỈ CÓ Ở ${tenA}` : `CHỈ CÓ Ở ${tenB}`);

// ---------- Đọc dữ liệu ----------
console.log("Đang đọc Tài chính, Nhân sự, Kho (chỉ đọc)…");
const [tcCongTy, tcNhanVien, tcNcc, tcDuAn, nsCongTy, nsNhanVien, nsPhongBan, nsToDoi, kho] = await Promise.all([
  sql(REF_TC, "select ma, ten, ten_viet_tat, ma_so_thue, dia_chi, dang_dung from public.cong_ty order by ma"),
  sql(REF_TC, `select nv.ma, nv.ho_ten, ct.ma cong_ty, nv.chuc_vu, nv.dang_dung, u.email email_dang_nhap, nc.email, nc.dien_thoai, nc.so_tai_khoan, nc.ten_ngan_hang,
               (select string_agg(vai_tro, ', ' order by vai_tro) from public.vai_tro_nhan_vien v where v.nhan_vien_id = nv.id) vai_tro
               from public.nhan_vien nv left join public.cong_ty ct on ct.id = nv.cong_ty_id
               left join public.nhan_vien_nhay_cam nc on nc.nhan_vien_id = nv.id left join auth.users u on u.id = nv.user_id order by nv.ma`),
  sql(REF_TC, "select ma, ten, ma_so_thue, dien_thoai, dia_chi, dang_dung from public.nha_cung_cap order by ma"),
  sql(REF_TC, `select d.ma, d.ten, d.dia_diem, ct.ma cong_ty, d.trang_thai, d.dang_dung from public.du_an d left join public.cong_ty ct on ct.id = d.cong_ty_id order by d.ma`),
  sql(REF_NS, "select code, name, tax_code, address, is_active from public.companies order by code"),
  sql(REF_NS, `select e.employee_code, e.full_name, c.code cong_ty, d.name phong_ban, e.status::text trang_thai, e.phone, e.personal_email,
               e.deleted_at is not null da_xoa, u.email email_dang_nhap, au.is_active tk_hoat_dong, au.role::text vai_tro, s.bank_account_no, s.bank_name
               from public.employees e left join public.companies c on c.id = e.company_id left join public.departments d on d.id = e.department_id
               left join public.app_users au on au.employee_id = e.id left join auth.users u on u.id = au.id
               left join public.employee_sensitive s on s.employee_id = e.id order by e.employee_code`),
  sql(REF_NS, `select d.code, d.name, c.code cong_ty, p.name phong_ban_cha, d.is_active from public.departments d left join public.companies c on c.id = d.company_id left join public.departments p on p.id = d.parent_id order by d.code`),
  sql(REF_NS, `select t.code, t.name, c.code cong_ty, d.name phong_ban, t.is_active from public.to_doi t left join public.companies c on c.id = t.company_id left join public.departments d on d.id = t.department_id order by t.code`),
  docSheetKho(),
]);

// ---------- 1. Công ty ----------
const capCongTy = ghep(tcCongTy, nsCongTy, [
  ["Trùng mã số thuế", (a, b) => mst(a.ma_so_thue) && mst(a.ma_so_thue) === mst(b.tax_code), "CHẮC CHẮN"],
  ["Trùng tên (bỏ loại hình DN)", (a, b) => loi(a.ten) === loi(b.name), "CHẮC CHẮN"],
  ["Tên gần giống", (a, b) => jaccard(loi(a.ten), loi(b.name)) >= 0.5, "CẦN XÁC NHẬN"],
]);
// Bảng quy đổi mã công ty Tài chính → Nhân sự (dùng khi so công ty của từng người)
const maCtyTcSangNs = new Map(capCongTy.filter((c) => c.a && c.b).map((c) => [c.a.ma, c.b.code]));
const shCongTy = capCongTy.map((c) => ({
  "Trạng thái": trangThai(c, "TÀI CHÍNH", "NHÂN SỰ"), "Căn cứ ghép": c.can_cu,
  "TC · Mã": c.a?.ma, "TC · Tên": c.a?.ten, "TC · MST": c.a?.ma_so_thue,
  "NS · Mã": c.b?.code, "NS · Tên": c.b?.name, "NS · MST": c.b?.tax_code,
  "Lệch tên?": c.a && c.b && chuan(c.a.ten) !== chuan(c.b.name) ? "Tên ghi khác nhau" : "",
  "Lệch mã?": c.a && c.b && c.a.ma !== c.b.code ? `Mã khác: ${c.a.ma} ≠ ${c.b.code}` : "",
  "Thiếu MST?": c.a && c.b && !mst(c.a.ma_so_thue) && mst(c.b.tax_code) ? "Tài chính chưa có MST → lấy từ Nhân sự" : "",
  "Đề xuất": c.a && c.b ? `Dùng 1 công ty: tên pháp lý + MST theo Nhân sự; giữ mã TC "${c.a.ma}" làm mã viết tắt (đang in trên số đề nghị)` : "Kiểm tra: công ty chỉ có ở 1 app",
  "Xác nhận": "",
}));

// ---------- 2. Nhân sự / người dùng (Tài chính ↔ Nhân sự ↔ Kho) ----------
const nsSong = nsNhanVien;
const emailsNS = (b) => [mail(b.email_dang_nhap), mail(b.personal_email)].filter(Boolean);
const emailsTC = (a) => [mail(a.email_dang_nhap), mail(a.email)].filter((e) => e && !e.endsWith("@sodienthoai.local"));
const sdtTC = (a) => [sdt(a.dien_thoai), tuSdtDangNhap(a.email_dang_nhap)].filter(Boolean);
const capNguoi = ghep(tcNhanVien, nsSong, [
  ["Trùng email", (a, b) => emailsTC(a).some((e) => emailsNS(b).includes(e)), "CHẮC CHẮN"],
  ["Trùng số điện thoại", (a, b) => sdt(b.phone) && sdtTC(a).includes(sdt(b.phone)), "CHẮC CHẮN"],
  ["Trùng họ tên (khác email/SĐT)", (a, b) => chuan(a.ho_ten) === chuan(b.full_name) && !b.da_xoa, "CẦN XÁC NHẬN"],
]);
// Ghép thêm người dùng Kho vào từng cặp (theo email, rồi họ tên)
const daKho = new Set();
const timKho = (c) => {
  const es = [...(c.a ? emailsTC(c.a) : []), ...(c.b ? emailsNS(c.b) : [])];
  let i = kho.nguoiDung.findIndex((k, j) => !daKho.has(j) && es.includes(k.email));
  if (i >= 0) { daKho.add(i); return [kho.nguoiDung[i], "email"]; }
  const ten = chuan(c.a?.ho_ten ?? c.b?.full_name);
  const ds = kho.nguoiDung.map((k, j) => [k, j]).filter(([k, j]) => !daKho.has(j) && ten && chuan(k.ho_ten) === ten);
  if (ds.length === 1) { daKho.add(ds[0][1]); return [ds[0][0], "họ tên (cần xác nhận)"]; }
  return [null, ""];
};
const dongNguoi = [];
for (const c of capNguoi) {
  // Chỉ đưa hồ sơ NS lẻ vào bảng nếu còn liên quan (có tài khoản app hoặc khớp Kho) — hồ sơ công nhân thuần NS vẫn liệt kê ở cuối
  const [k, kCanCu] = timKho(c);
  dongNguoi.push({ c, k, kCanCu });
}
kho.nguoiDung.forEach((k, j) => { if (!daKho.has(j)) dongNguoi.push({ c: { a: null, b: null, can_cu: "", tin_cay: "" }, k, kCanCu: "" }); });

const soApp = (d) => [d.c.a, d.c.b, d.k].filter(Boolean).length;
const shNguoi = dongNguoi
  .map(({ c, k, kCanCu }) => {
    const coMat = [c.a && "TÀI CHÍNH", c.b && "NHÂN SỰ", k && "KHO"].filter(Boolean);
    let tt = coMat.length === 1 ? `CHỈ CÓ Ở ${coMat[0]}` : c.tin_cay === "CẦN XÁC NHẬN" || /xác nhận/.test(kCanCu) ? "CẦN XÁC NHẬN" : "KHỚP";
    const stkTC = String(c.a?.so_tai_khoan ?? "").replace(/\D/g, ""), stkNS = String(c.b?.bank_account_no ?? "").replace(/\D/g, "");
    return {
      "Trạng thái": tt, "Có ở": coMat.join(" + "),
      "Căn cứ ghép TC↔NS": c.can_cu, "Căn cứ ghép Kho": kCanCu,
      "TC · Mã NV": c.a?.ma, "TC · Họ tên": c.a?.ho_ten, "TC · Công ty": c.a?.cong_ty, "TC · Chức vụ": c.a?.chuc_vu,
      "TC · Vai trò": c.a?.vai_tro, "TC · Email/SĐT đăng nhập": c.a?.email_dang_nhap, "TC · SĐT": c.a?.dien_thoai, "TC · Đang dùng": c.a ? (c.a.dang_dung ? "Có" : "Không") : "",
      "NS · Mã NV": c.b?.employee_code, "NS · Họ tên": c.b?.full_name, "NS · Công ty": c.b?.cong_ty, "NS · Phòng ban": c.b?.phong_ban,
      "NS · Trạng thái": c.b ? (c.b.da_xoa ? "ĐÃ XOÁ" : c.b.trang_thai) : "", "NS · Email đăng nhập": c.b?.email_dang_nhap, "NS · Email cá nhân": c.b?.personal_email, "NS · SĐT": c.b?.phone,
      "Kho · Email": k?.email, "Kho · Họ tên": k?.ho_ten, "Kho · Vai trò": k?.vai_tro, "Kho · Trạng thái": k?.trang_thai,
      "Lệch họ tên?": [c.a?.ho_ten, c.b?.full_name, k?.ho_ten].filter(Boolean).map(chuan).some((x, _, arr) => x !== arr[0]) ? "Họ tên ghi khác nhau" : "",
      "Lệch công ty?": c.a && c.b && c.a.cong_ty && c.b.cong_ty && (maCtyTcSangNs.get(c.a.cong_ty) ?? c.a.cong_ty) !== c.b.cong_ty ? `TC: ${c.a.cong_ty} ≠ NS: ${c.b.cong_ty}` : "",
      "STK ngân hàng TC↔NS": c.a && c.b ? (!stkTC && !stkNS ? "" : !stkTC || !stkNS ? `Chỉ 1 bên có (${duoi4(stkTC || stkNS)})` : stkTC === stkNS ? `Khớp (${duoi4(stkTC)})` : `LỆCH (${duoi4(stkTC)} ≠ ${duoi4(stkNS)})`) : "",
      "Đề xuất": coMat.length > 1 ? "Gộp 1 người: hồ sơ gốc = Nhân sự (mã NV), liên kết tài khoản TC/Kho" : c.b && !c.b.email_dang_nhap ? "Hồ sơ NS không có tài khoản — không cần làm gì" : "Kiểm tra: chỉ có ở 1 app",
      "Xác nhận": "",
      _uuTien: tt === "CẦN XÁC NHẬN" ? 0 : soApp({ c, k }) > 1 ? 1 : c.a || k || c.b?.email_dang_nhap ? 2 : 3,
    };
  })
  .sort((x, y) => x._uuTien - y._uuTien)
  .map(({ _uuTien, ...r }) => r);

// ---------- 3. Công trình: gom theo ĐỊA DANH (1 dự án TC ↔ nhiều kho, công trường NS, tổ đội) ----------
// Mốc = dự án Tài chính. Mỗi mục khác gắn vào dự án có nhiều cặp-từ-địa-danh chung nhất.
const mocCT = tcDuAn.map((d) => ({ d, bg: new Set([...bigram(diaDanh(d.ten)), ...bigram(diaDanh(d.dia_diem))]), kho: [], pbNS: [], toNS: [], bpKho: [] }));
const ganCT = (ten) => {
  const bg = bigram(diaDanh(ten));
  let tot = null, diem = 0;
  for (const m of mocCT) { let n = 0; for (const x of bg) if (m.bg.has(x)) n++; if (n > diem) { diem = n; tot = m; } }
  return tot;
};
const khoLe = [], pbDaGan = new Set(), bpKhoDaGan = new Set();
for (const k of kho.kho) { const m = ganCT(`${k.ten} ${k.dia_diem}`); m ? m.kho.push(k) : khoLe.push(k); }
for (const p of nsPhongBan) { const m = ganCT(p.name); if (m) { m.pbNS.push(p); pbDaGan.add(p); } }
for (const t of nsToDoi) { const m = ganCT(t.name) ?? ganCT(t.phong_ban ?? ""); if (m) m.toNS.push(t); }
for (const b of kho.boPhan) { const m = ganCT(b.ten); if (m) { m.bpKho.push(b); bpKhoDaGan.add(b); } }
const shCT = [
  ...mocCT.map((m) => ({
    "Trạng thái": m.kho.length || m.pbNS.length || m.toNS.length ? "CẦN XÁC NHẬN" : "CHỈ CÓ Ở TÀI CHÍNH",
    "Địa danh dùng ghép": diaDanh(`${m.d.ten} ${m.d.dia_diem}`),
    "TC · Mã dự án": m.d.ma, "TC · Tên dự án": m.d.ten, "TC · Địa điểm": m.d.dia_diem, "TC · Công ty": m.d.cong_ty, "TC · Trạng thái": m.d.trang_thai,
    "Kho · Các kho": m.kho.map((k) => `${k.ma} ${k.ten}`).join("\n"),
    "NS · Phòng ban công trường": m.pbNS.map((p) => `${p.code} ${p.name} (${p.cong_ty ?? "dùng chung"})`).join("\n"),
    "NS · Tổ đội": m.toNS.map((t) => `${t.code} ${t.name}`).join("\n"),
    "Kho · Bộ phận/tổ đội nhận hàng": m.bpKho.map((b) => `${b.ma} ${b.ten}`).join("\n"),
    "Đề xuất": "Dự án TC làm mã công trình chung; gắn các kho/phòng ban/tổ đội bên phải vào dự án này",
    "Xác nhận": "",
  })),
  ...khoLe.map((k) => ({
    "Trạng thái": "CHỈ CÓ Ở KHO", "Địa danh dùng ghép": diaDanh(`${k.ten} ${k.dia_diem}`),
    "Kho · Các kho": `${k.ma} ${k.ten}`, "Đề xuất": "Kho chưa gắn dự án nào (kho tổng/văn phòng?) — chọn dự án hoặc để trống", "Xác nhận": "",
  })),
];

// ---------- 3b. Phòng ban văn phòng (Nhân sự ↔ Kho), phần KHÔNG thuộc công trình ----------
const capPB = ghep(nsPhongBan.filter((p) => !pbDaGan.has(p)), kho.boPhan.filter((b) => !bpKhoDaGan.has(b)), [
  ["Trùng mã", (a, b) => a.code && chuan(a.code) === chuan(b.ma), "CHẮC CHẮN"],
  ["Trùng tên", (a, b) => chuan(a.name) === chuan(b.ten), "CHẮC CHẮN"],
  ["Tên gần giống", (a, b) => jaccard(chuan(a.name), chuan(b.ten)) >= 0.5, "CẦN XÁC NHẬN"],
]);
const shPB = capPB.map((c) => ({
  "Trạng thái": trangThai(c, "NHÂN SỰ", "KHO"), "Căn cứ ghép": c.can_cu,
  "NS · Mã": c.a?.code, "NS · Tên": c.a?.name, "NS · Công ty": c.a?.cong_ty, "NS · Thuộc": c.a?.phong_ban_cha, "NS · Đang dùng": c.a ? (c.a.is_active ? "Có" : "Không") : "",
  "Kho · Mã": c.b?.ma, "Kho · Tên": c.b?.ten, "Kho · Email quản lý": c.b?.email_quan_ly, "Kho · Trạng thái": c.b?.trang_thai,
  "Đề xuất": c.a && c.b ? "Dùng phòng ban Nhân sự làm gốc; Kho trỏ theo mã NS" : c.b ? "Bộ phận Kho chưa có ở Nhân sự → thêm vào NS hoặc ghép tay" : "Chỉ ở Nhân sự — không cần làm gì",
  "Xác nhận": "",
}));

// ---------- 4. Nhà cung cấp (Tài chính ↔ Kho) ----------
const capNCC = ghep(tcNcc, kho.ncc, [
  ["Trùng mã số thuế", (a, b) => mst(a.ma_so_thue) && mst(a.ma_so_thue) === mst(b.mst), "CHẮC CHẮN"],
  // Mã NCC của Tài chính tự đặt (NCC 001, NCC.008…) khác dãy mã kế toán của Kho → chỉ tính khi tên cũng gần giống
  ["Trùng mã NCC + tên gần giống", (a, b) => a.ma && chuan(a.ma) === chuan(b.ma) && jaccard(loi(a.ten), loi(b.ten)) >= 0.3, "CẦN XÁC NHẬN"],
  ["Trùng tên", (a, b) => loi(a.ten) && loi(a.ten) === loi(b.ten), "CẦN XÁC NHẬN"],
  ["Tên gần giống", (a, b) => jaccard(loi(a.ten), loi(b.ten)) >= 0.6, "CẦN XÁC NHẬN"],
]);
const shNCC = capNCC
  .map((c) => ({
    "Trạng thái": trangThai(c, "TÀI CHÍNH", "KHO"), "Căn cứ ghép": c.can_cu,
    "TC · Mã": c.a?.ma, "TC · Tên": c.a?.ten, "TC · MST": c.a?.ma_so_thue, "TC · Đang dùng": c.a ? (c.a.dang_dung ? "Có" : "Không") : "",
    "Kho · Mã": c.b?.ma, "Kho · Tên": c.b?.ten, "Kho · MST": c.b?.mst, "Kho · Trạng thái": c.b?.trang_thai,
    "Lệch MST?": c.a && c.b && mst(c.a.ma_so_thue) && mst(c.b.mst) && mst(c.a.ma_so_thue) !== mst(c.b.mst) ? "MST KHÁC NHAU" : "",
    "Đề xuất": c.a && c.b ? "Dùng mã kế toán của Kho làm mã chung" : c.a ? "NCC Tài chính chưa có ở Kho (có thể là NCC dịch vụ, không phải vật tư)" : "NCC vật tư chưa phát sinh chi ở Tài chính",
    "Xác nhận": "",
    _u: c.a && c.b ? (c.tin_cay === "CHẮC CHẮN" ? 1 : 0) : c.a ? 2 : 3,
  }))
  .sort((x, y) => x._u - y._u)
  .map(({ _u, ...r }) => r);

const shToDoi = nsToDoi.map((t) => ({ "NS · Mã tổ": t.code, "NS · Tên tổ": t.name, "Công ty": t.cong_ty, "Phòng ban": t.phong_ban, "Đang dùng": t.is_active ? "Có" : "Không" }));

// ---------- Tổng quan ----------
const dem = (rows, cot = "Trạng thái") => rows.reduce((m, r) => ((m[r[cot]] = (m[r[cot]] ?? 0) + 1), m), {});
const tq = [
  ["Công ty", `TC ${tcCongTy.length} / NS ${nsCongTy.length}`, dem(shCongTy)],
  ["Nhân sự & tài khoản", `TC ${tcNhanVien.length} / NS ${nsNhanVien.length} (có TK app ${nsNhanVien.filter((x) => x.email_dang_nhap).length}) / Kho ${kho.nguoiDung.length}`, dem(shNguoi)],
  ["Công trình (dự án ↔ kho ↔ công trường ↔ tổ đội)", `Dự án TC ${tcDuAn.length} / Kho ${kho.kho.length} / Phòng ban NS ${nsPhongBan.length} / Tổ đội NS ${nsToDoi.length} / Bộ phận Kho ${kho.boPhan.length}`, dem(shCT)],
  ["Phòng ban văn phòng (ngoài công trình)", `NS ${nsPhongBan.length - pbDaGan.size} / Kho ${kho.boPhan.length - bpKhoDaGan.size}`, dem(shPB)],
  ["Nhà cung cấp", `TC ${tcNcc.length} / Kho ${kho.ncc.length}`, dem(shNCC)],
];
const shTQ = tq.map(([ten, so, d]) => ({
  "Danh mục": ten, "Số bản ghi mỗi app": so, "KHỚP": d["KHỚP"] ?? 0, "CẦN XÁC NHẬN": d["CẦN XÁC NHẬN"] ?? 0,
  "Chỉ có ở 1 app": Object.entries(d).filter(([k]) => k.startsWith("CHỈ CÓ")).map(([k, v]) => `${k.replace("CHỈ CÓ Ở ", "")}: ${v}`).join(", "),
}));
const shGhiChu = [
  { "Nội dung": "File này CHỈ ĐỌC dữ liệu 3 app lúc chạy; chưa ghi/sửa gì vào DB hay Sheet thật." },
  { "Nội dung": "KHỚP = trùng mã số thuế / email / số điện thoại. CẦN XÁC NHẬN = chỉ trùng tên hoặc gần giống → anh/chị kiểm tra." },
  { "Nội dung": "Cột 'Xác nhận': ghi ĐÚNG / SAI / ghi chú. Agent dùng cột này để lập bảng ánh xạ chính thức khi gộp." },
  { "Nội dung": "Số tài khoản ngân hàng chỉ hiện 4 số cuối. File có dữ liệu cá nhân — không gửi ra ngoài, không commit." },
  { "Nội dung": "Hồ sơ Nhân sự không có tài khoản app (công nhân) chỉ nằm ở Nhân sự — xếp cuối bảng, không cần xử lý." },
];

// ---------- Ghi Excel ----------
const wb = XLSX.utils.book_new();
const them = (ten, rows) => {
  const ws = XLSX.utils.json_to_sheet(rows.length ? rows : [{ "(trống)": "" }]);
  const cols = Object.keys(rows[0] ?? { x: 1 });
  ws["!cols"] = cols.map((c) => ({ wch: Math.min(45, Math.max(c.length + 2, ...rows.map((r) => String(r[c] ?? "").length + 1))) }));
  ws["!autofilter"] = { ref: ws["!ref"] };
  XLSX.utils.book_append_sheet(wb, ws, ten);
};
them("Tong_quan", shTQ); them("Cong_ty", shCongTy); them("Nhan_su", shNguoi); them("Phong_ban", shPB);
them("Nha_cung_cap", shNCC); them("Cong_trinh_Kho", shCT); them("To_doi_NS", shToDoi); them("Ghi_chu", shGhiChu);
const thuMuc = resolve(".local/doi-chieu");
mkdirSync(thuMuc, { recursive: true });
const ngay = new Date(Date.now() + 7 * 3600e3).toISOString().slice(0, 16).replace(/[-:T]/g, "").replace(/^(\d{8})(\d{4})$/, "$1_$2");
const file = join(thuMuc, `DOI_CHIEU_DANH_MUC_${ngay}.xlsx`);
XLSX.writeFile(wb, file);

// In tóm tắt (không in dữ liệu cá nhân)
console.table(shTQ);
console.log("Công ty:", shCongTy.map((r) => `${r["TC · Mã"] ?? "-"}↔${r["NS · Mã"] ?? "-"} [${r["Trạng thái"]}; ${r["Căn cứ ghép"] || "-"}]`).join(" | "));
console.log("Phòng ban:", shPB.map((r) => `${r["NS · Tên"] ?? "-"}↔${r["Kho · Tên"] ?? "-"} [${r["Trạng thái"]}]`).join(" | "));
for (const r of shCT) console.log(`CT: ${r["TC · Tên dự án"] ?? "(không dự án)"} ⇐ kho[${(r["Kho · Các kho"] ?? "").replace(/\n/g, "; ")}] pbNS[${(r["NS · Phòng ban công trường"] ?? "").replace(/\n/g, "; ")}] tổNS[${(r["NS · Tổ đội"] ?? "").replace(/\n/g, "; ")}] bpKho[${(r["Kho · Bộ phận/tổ đội nhận hàng"] ?? "").replace(/\n/g, "; ")}]`);
console.log("NCC khớp/cần xác nhận:", shNCC.filter((r) => !r["Trạng thái"].startsWith("CHỈ")).map((r) => `${r["TC · Tên"]}↔${r["Kho · Mã"]} [${r["Căn cứ ghép"]}]${r["Lệch MST?"] ? " " + r["Lệch MST?"] : ""}`).join(" | "));
console.log("Nhân sự — cột 'Có ở':", JSON.stringify(dem(shNguoi, "Có ở")));
console.log("Nhân sự — STK:", JSON.stringify(dem(shNguoi.filter((r) => r["STK ngân hàng TC↔NS"]).map((r) => ({ k: r["STK ngân hàng TC↔NS"].replace(/\s*\(.*\)/, "") })), "k")));
console.log("Nhân sự — lệch họ tên:", shNguoi.filter((r) => r["Lệch họ tên?"]).length, "| lệch công ty:", shNguoi.filter((r) => r["Lệch công ty?"] && r["Lệch công ty?"].split(" / ")[0] !== r["Lệch công ty?"].split(" / ")[1]).length);
console.log("\nĐã ghi:", file);
