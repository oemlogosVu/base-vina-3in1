// Kiểu prop của các component nguồn (app Tài chính, design/tham-chieu-tai-chinh/components-ui/*.tsx).
// Chỉ để làm tài liệu: design system này không kèm bundle JS, component là class CSS trong bundle.css.
import type { ComponentProps, ReactNode } from "react";

export type TenBieuTuong =
  | "home" | "file" | "wallet" | "check-sq" | "card" | "more" | "search"
  | "plus" | "trash" | "right" | "down" | "back" | "clip" | "cog" | "users"
  | "chart" | "swap" | "down-tray" | "warn" | "clock" | "check" | "x"
  | "folder" | "bank" | "out" | "key" | "cal" | "pencil" | "filter" | "book"
  | "table";

/** Biểu tượng SVG từ sprite. Cỡ 20 trong nút, 24 trên thanh điều hướng, 26 ở trạng thái trống. */
export declare function BieuTuong(p: { ten: TenBieuTuong; co?: number; className?: string }): JSX.Element;
/** Render một lần trong layout gốc: một <svg> ẩn chứa mọi <symbol id="i-…">. */
export declare function SpriteBieuTuong(): JSX.Element;

export type BienTheNut = "chinh" | "phu" | "nguy-hiem" | "chu" | "do-dac";
export type CoNut = "thuong" | "nho";
/** Nút. chinh: cao 48 nền navy · phu · nguy-hiem · chu · do-dac (chỉ trong KhoiXacNhan). */
export declare function Nut(p: ComponentProps<"button"> & {
  bienThe?: BienTheNut; co?: CoNut; bieuTuong?: TenBieuTuong;
  /** Vòng xoay + khóa nút khi chờ máy chủ. */ dangXuLy?: boolean; nhanDangXuLy?: string;
}): JSX.Element;
/** Link trông như nút (next/link). */
export declare function NutLink(p: { href: string; bienThe?: BienTheNut; co?: CoNut; bieuTuong?: TenBieuTuong; className?: string; children?: ReactNode }): JSX.Element;
export declare function lopNut(bienThe?: BienTheNut, co?: CoNut, them?: string): string;

/** Một ô trong form: nhãn · ô gốc (children) · gợi ý hoặc lỗi · «Giải thích» mở tại chỗ. */
export declare function OTruong(p: {
  nhan: ReactNode; htmlFor?: string; batBuoc?: boolean; goiY?: ReactNode;
  loi?: string | null; chiTiet?: ReactNode; className?: string; children: ReactNode;
}): JSX.Element;
/** Khung bọc <input type="file"> gốc. */
export declare function KhungTep(p: { children: ReactNode }): JSX.Element;

/** Ô nhập tiền: hiện 1.000.000, giá trị là số nguyên. */
export declare function OTien(p: {
  giaTri: number; onDoi: (so: number) => void; id?: string; name?: string;
  loi?: boolean; /** viền vàng: số bị sửa khác số gốc */ canhBao?: boolean; nho?: boolean;
  disabled?: boolean; className?: string; "aria-describedby"?: string; "aria-label"?: string;
}): JSX.Element;
export declare function chamNghin(so: number): string;

/** Khối xác nhận tại chỗ — thay cho mọi popup. */
export declare function KhoiXacNhan(p: {
  loai?: "thuong" | "do"; cauHoi: string; heQua?: ReactNode; nhanXacNhan: string;
  onXacNhan?: () => void; onThoi: () => void; dangXuLy?: boolean; loi?: string | null;
  className?: string; /** ô lý do */ children?: ReactNode;
}): JSX.Element;

export type NhomPill = "xam" | "vang" | "xanh" | "do" | "dong";
export declare function The(p: ComponentProps<"div"> & { dem?: boolean }): JSX.Element;
export declare function Pill(p: { nhom: NhomPill; className?: string; children: ReactNode; title?: string }): JSX.Element;
export declare function Tien(p: { giaTri: string | number | null | undefined; loai?: "vao" | "ra"; khongDonVi?: boolean; className?: string }): JSX.Element;
export declare function Bang(p: { nhan?: string; gon?: boolean; className?: string; children: ReactNode }): JSX.Element;
export declare function OSoLieu(p: { nhan: string; giaTri: ReactNode; loai?: "vao" | "ra"; className?: string }): JSX.Element;
export declare function ThanhTienDo(p: { nhan: string; daDung: number; tong: number }): JSX.Element;
export declare function ThongBao(p: { loai: "thanh-cong" | "loi"; tieuDe?: string; className?: string; children?: ReactNode }): JSX.Element;
export declare function TrangThaiTrong(p: { bieuTuong?: TenBieuTuong; chinh: string; phu?: ReactNode; children?: ReactNode }): JSX.Element;
export declare function KhungChoTai(p: { soThe?: number }): JSX.Element;

// ĐỀ XUẤT 3 trong 1 (chưa có trong code)
export type PhanHe = "tc" | "ns" | "kho" | "ht";
/** Bộ chọn phân hệ ở đầu thanh bên: <details> mở tại chỗ. */
export declare function BoChonPhanHe(p: { dangMo: PhanHe; duocPhep: PhanHe[]; soViec: Partial<Record<PhanHe, number>> }): JSX.Element;
