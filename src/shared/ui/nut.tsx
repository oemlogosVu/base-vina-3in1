import Link from "next/link";
import type { ComponentProps } from "react";

import { BieuTuong, type TenBieuTuong } from "./bieu-tuong";

/**
 * NÚT — thay cho 7 kiểu nút tự chế của bản cũ (cao 36→48, bo 8 hoặc 12).
 *
 *   chinh     cao 48, nền navy — mỗi màn một nút chính
 *   phu       cao 44, viền xám
 *   nguy-hiem cao 44, viền đỏ nhạt — Từ chối, Hủy, Xóa
 *   chu       cao 44, không viền — Thôi, Xem thêm
 *   do-dac    nền đỏ chữ trắng — CHỈ cho nút xác nhận cuối trong KhoiXacNhan
 *
 * Cỡ `nho` (36px) chỉ dùng trên máy tính. Không bao giờ chữ trắng trên nền vàng
 * (lỗi tương phản "Xác nhận trả về" của bản cũ).
 */
export type BienTheNut = "chinh" | "phu" | "nguy-hiem" | "chu" | "do-dac";
export type CoNut = "thuong" | "nho";

const LOP: Record<BienTheNut, string> = {
  chinh: "nut",
  phu: "nut-phu",
  "nguy-hiem": "nut-do",
  chu: "nut-chu",
  "do-dac": "nut-do-dac",
};

/** Class của nút — cho chỗ cần bọc thẻ khác (vd <a download> tải PDF). */
export function lopNut(bienThe: BienTheNut = "chinh", co: CoNut = "thuong", them?: string) {
  return [LOP[bienThe], co === "nho" ? "nut-nho" : "", them ?? ""].filter(Boolean).join(" ");
}

type ChungNut = {
  bienThe?: BienTheNut;
  co?: CoNut;
  bieuTuong?: TenBieuTuong;
};

export function Nut({
  bienThe,
  co,
  bieuTuong,
  dangXuLy,
  nhanDangXuLy,
  className,
  children,
  disabled,
  type = "button",
  ...con
}: ComponentProps<"button"> &
  ChungNut & {
    /** Hiện vòng xoay + khóa nút trong lúc chờ máy chủ — chống bấm hai lần. */
    dangXuLy?: boolean;
    /** Chữ trong lúc xử lý, vd "Đang gửi…". Mặc định giữ chữ cũ. */
    nhanDangXuLy?: string;
  }) {
  return (
    <button
      type={type}
      disabled={disabled || dangXuLy}
      aria-busy={dangXuLy || undefined}
      className={lopNut(bienThe, co, className)}
      {...con}
    >
      {dangXuLy ? (
        <>
          <span className="xoay" aria-hidden="true" />
          {nhanDangXuLy ?? children}
        </>
      ) : (
        <>
          {bieuTuong && <BieuTuong ten={bieuTuong} />}
          {children}
        </>
      )}
    </button>
  );
}

/** Link trông như nút — chuyển trang (Lập đề nghị, Sửa...). */
export function NutLink({
  bienThe,
  co,
  bieuTuong,
  className,
  children,
  ...con
}: ComponentProps<typeof Link> & ChungNut) {
  return (
    <Link className={lopNut(bienThe, co, className)} {...con}>
      {bieuTuong && <BieuTuong ten={bieuTuong} />}
      {children}
    </Link>
  );
}
