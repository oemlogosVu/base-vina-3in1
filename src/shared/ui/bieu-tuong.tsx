/**
 * BỘ BIỂU TƯỢNG — thay toàn bộ emoji (📎 ⚙️ 📁 💰...).
 *
 * Nét đơn kiểu Lucide, path lấy nguyên từ bản thiết kế
 * (design_handoff_thu_chi/tham-chieu/thiet-ke-dot-1.dc.html, khối <symbol>).
 *
 * Cách dùng: <SpriteBieuTuong /> render MỘT lần trong layout gốc (một <svg> ẩn
 * chứa mọi <symbol>), còn mỗi chỗ cần hình chỉ là <svg><use href="#i-..."/></svg>.
 * Nhờ vậy HTML mỗi trang không lặp lại hàng chục path, và màu hình ăn theo
 * `color` của chữ quanh nó (stroke = currentColor).
 */

export type TenBieuTuong =
  | "home" | "file" | "wallet" | "check-sq" | "card" | "more" | "search"
  | "plus" | "trash" | "right" | "down" | "back" | "clip" | "cog" | "users"
  | "chart" | "swap" | "down-tray" | "warn" | "clock" | "check" | "x"
  | "folder" | "bank" | "out" | "key" | "cal" | "pencil" | "filter" | "book"
  | "table";

/** Nét mặc định 1.8; mũi tên 1.9; dấu tích / dấu x 2. */
const HINH: Record<TenBieuTuong, { hinh: React.ReactNode; net?: number }> = {
  home: { hinh: <><path d="M3 10.6 12 3.4l9 7.2" /><path d="M5.6 9.5V20.6h12.8V9.5" /><path d="M9.8 20.6v-6h4.4v6" /></> },
  file: { hinh: <><path d="M13.5 3H6.6v18h10.8V6.9z" /><path d="M13.5 3v3.9h3.9" /><path d="M9.3 12h5.4M9.3 15.6h5.4" /></> },
  wallet: { hinh: <><path d="M3.4 7.6h17.2v12H3.4z" /><path d="M3.4 7.6 16 4.2v3.4" /><path d="M16.8 13.6h2.2" /></> },
  "check-sq": { hinh: <><path d="M3.6 3.6h16.8v16.8H3.6z" /><path d="m7.8 12.2 2.9 2.9 5.5-6" /></> },
  card: { hinh: <><path d="M2.8 5.4h18.4v13.2H2.8z" /><path d="M2.8 9.8h18.4" /><path d="M6.4 14.6h4" /></> },
  more: { hinh: <path d="M4 7h16M4 12h16M4 17h10" /> },
  search: { hinh: <><circle cx="10.6" cy="10.6" r="6.6" /><path d="m15.4 15.4 4.4 4.4" /></> },
  plus: { hinh: <path d="M12 5v14M5 12h14" />, net: 1.9 },
  trash: { hinh: <><path d="M4.4 6.6h15.2" /><path d="M9.2 6.6V4.2h5.6v2.4" /><path d="M6.6 6.6 7.6 20.4h8.8l1-13.8" /></> },
  right: { hinh: <path d="m9.4 5.2 6.8 6.8-6.8 6.8" />, net: 1.9 },
  down: { hinh: <path d="m5.2 9.4 6.8 6.8 6.8-6.8" />, net: 1.9 },
  back: { hinh: <><path d="M19 12H5.4" /><path d="m11 5.4-5.6 6.6 5.6 6.6" /></>, net: 1.9 },
  clip: { hinh: <path d="M18.4 11.2 11.6 18a4.1 4.1 0 0 1-5.8-5.8l7.4-7.4a2.7 2.7 0 0 1 3.9 3.9l-7.4 7.4a1.4 1.4 0 0 1-2-2l6.8-6.8" /> },
  cog: { hinh: <><circle cx="12" cy="12" r="3.1" /><path d="M12 2.8v2.6M12 18.6v2.6M4.5 4.5l1.9 1.9M17.6 17.6l1.9 1.9M2.8 12h2.6M18.6 12h2.6M4.5 19.5l1.9-1.9M17.6 6.4l1.9-1.9" /></> },
  users: { hinh: <><circle cx="9.4" cy="8.2" r="3.6" /><path d="M3.4 20.2c0-3.3 2.7-6 6-6s6 2.7 6 6" /><path d="M16.2 5.1a3.6 3.6 0 0 1 0 6.9M17.4 14.6c1.9.8 3.2 2.7 3.2 5" /></> },
  chart: { hinh: <><path d="M4 20.2h16.4" /><path d="M6.8 20.2V11M12 20.2V5.4M17.2 20.2v-6.4" /></> },
  swap: { hinh: <><path d="M4 8.4h14" /><path d="m14.6 4.8 3.6 3.6-3.6 3.6" /><path d="M20 15.6H6" /><path d="m9.4 12-3.6 3.6 3.6 3.6" /></> },
  "down-tray": { hinh: <><path d="M12 3.6v11.2" /><path d="m7.6 10.6 4.4 4.4 4.4-4.4" /><path d="M4.4 19.6h15.2" /></> },
  warn: { hinh: <><path d="M12 3.8 21 19.6H3z" /><path d="M12 9.6v4.2M12 16.6v.1" /></> },
  clock: { hinh: <><circle cx="12" cy="12" r="8.4" /><path d="M12 7v5.2l3.4 2" /></> },
  check: { hinh: <path d="m4.8 12.6 4.6 4.6L19.2 7" />, net: 2 },
  x: { hinh: <path d="M6 6l12 12M18 6 6 18" />, net: 2 },
  folder: { hinh: <path d="M3.4 19.4V5.2h5.6l2 2.6h9.6v11.6z" /> },
  bank: { hinh: <><path d="M3.4 9.4 12 4.2l8.6 5.2" /><path d="M5.6 9.4v9.2M10 9.4v9.2M14 9.4v9.2M18.4 9.4v9.2" /><path d="M3.4 20.4h17.2" /></> },
  out: { hinh: <><path d="M14.6 4.4H5.4v15.2h9.2" /><path d="M11 12h9.2" /><path d="m17 8.4 3.6 3.6L17 15.6" /></> },
  key: { hinh: <><circle cx="8" cy="12" r="4.2" /><path d="M12.2 12h8.2v3.2" /><path d="M17 12v2.6" /></> },
  cal: { hinh: <><path d="M4 5.8h16v14.4H4z" /><path d="M4 10h16M8.4 3.4v3.6M15.6 3.4v3.6" /></> },
  pencil: { hinh: <path d="M16.4 3.9 20.1 7.6 8.3 19.4l-4.6.9.9-4.6z" /> },
  filter: { hinh: <path d="M3.6 5.4h16.8l-6.6 7.8v6l-3.6 1.6v-7.6z" /> },
  // Sổ quỹ — không có trong bản thiết kế (bản đó chưa có mục Sổ quỹ riêng); vẽ
  // cùng nét 1.8 kiểu Lucide cho đồng bộ.
  book: { hinh: <><path d="M5 4.6A1.6 1.6 0 0 1 6.6 3H19v15.2H6.6A1.6 1.6 0 0 0 5 19.8z" /><path d="M5 19.8a1.6 1.6 0 0 0 1.6 1.6H19" /><path d="M9 7.4h6" /></> },
  // Sao kê — bảng có cột số tiền bên phải. Cố ý KHÁC "book" (Sổ quỹ): hai mục
  // nằm cạnh nhau trong nhóm "Tiền", trùng hình là không phân biệt được.
  table: { hinh: <><path d="M3.6 4.6h16.8v14.8H3.6z" /><path d="M3.6 9.4h16.8M3.6 14.6h16.8" /><path d="M14.6 4.6v14.8" /></> },
};

export const DS_BIEU_TUONG = Object.keys(HINH) as TenBieuTuong[];

/** Render MỘT lần trong layout gốc. */
export function SpriteBieuTuong() {
  return (
    <svg
      width="0"
      height="0"
      aria-hidden="true"
      focusable="false"
      className="absolute h-0 w-0 overflow-hidden"
    >
      {DS_BIEU_TUONG.map((ten) => (
        <symbol key={ten} id={`i-${ten}`} viewBox="0 0 24 24">
          <g
            fill="none"
            stroke="currentColor"
            strokeWidth={HINH[ten].net ?? 1.8}
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            {HINH[ten].hinh}
          </g>
        </symbol>
      ))}
    </svg>
  );
}

/**
 * Một biểu tượng. Cỡ 20 trong nút, 24 trên thanh điều hướng, 26 ở trạng thái trống.
 * Luôn aria-hidden: biểu tượng đi kèm chữ, chữ mới là nhãn cho trình đọc màn hình.
 */
export function BieuTuong({
  ten,
  co = 20,
  className,
}: {
  ten: TenBieuTuong;
  co?: number;
  className?: string;
}) {
  return (
    <svg width={co} height={co} aria-hidden="true" focusable="false" className={className}>
      <use href={`#i-${ten}`} />
    </svg>
  );
}
