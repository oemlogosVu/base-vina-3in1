// TẢI TOÀN BỘ ẢNH CHỨNG TỪ CỦA PHÂN HỆ KHO (Vercel Blob)
// ------------------------------------------------------
// Dùng thư viện @vercel/blob có sẵn trong repo Inventory (không cài thêm gì).
// Token đọc từ file .env.local của repo Inventory qua --env-file, không in ra.
//
// CÁCH CHẠY (từ thư mục "Combine 3 in 1"):
//   node --env-file="../Inventory manager/.env.local" scripts/sao-luu/tai-anh-kho-blob.mjs "F:\SaoLuu_BaseVina"
import { createRequire } from "node:module";
import { mkdirSync, writeFileSync, existsSync, statSync, appendFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";

const THU_MUC = process.argv[2] || "F:\\SaoLuu_BaseVina";
const require = createRequire(resolve("../Inventory manager/package.json"));
const { list } = require("@vercel/blob");
if (!process.env.BLOB_READ_WRITE_TOKEN) throw new Error("Thiếu BLOB_READ_WRITE_TOKEN (chạy kèm --env-file như hướng dẫn).");

const goc = join(THU_MUC, "blob_Kho");
mkdirSync(goc, { recursive: true });
const csv = join(goc, "DANH_SACH.csv");
if (!existsSync(csv)) writeFileSync(csv, "\uFEFFpathname,kich_thuoc,url,ngay_tai_len\n");

let cursor, tong = 0, tai = 0, loi = 0;
do {
  const trang = await list({ cursor, limit: 1000 });
  for (const b of trang.blobs) {
    tong++;
    const dich = join(goc, ...b.pathname.split("/"));
    if (existsSync(dich) && statSync(dich).size === b.size) continue;
    try {
      const r = await fetch(b.downloadUrl ?? b.url);
      if (!r.ok) throw new Error(`HTTP ${r.status}`);
      mkdirSync(dirname(dich), { recursive: true });
      writeFileSync(dich, Buffer.from(await r.arrayBuffer()));
      appendFileSync(csv, `"${b.pathname}",${b.size},${b.url},${new Date(b.uploadedAt).toISOString()}\n`);
      tai++;
    } catch (e) { loi++; console.error(`LỖI ${b.pathname}: ${e.message}`); }
  }
  cursor = trang.hasMore ? trang.cursor : undefined;
} while (cursor);
console.log(`Blob Kho: ${tong} file — tải mới ${tai}, lỗi ${loi}. Thư mục: ${goc}`);
