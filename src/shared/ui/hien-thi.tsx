import type { ComponentProps } from "react";

import { BieuTuong, type TenBieuTuong } from "./bieu-tuong";

/**
 * Các thành phần HIỂN THỊ thuần (không trạng thái, render được ở máy chủ):
 * Thẻ, Pill, Bảng, Thông báo, Trạng thái trống, Khung chờ tải.
 * Kiểu dáng nằm ở globals.css (@layer components).
 *
 * Chép từ app Tài chính (src/components/ui/hien-thi.tsx, main 992cdd7). Các phần
 * gắn với tiền và trạng thái đề nghị (Tien, OSoLieu, ThanhTienDo, PillTrangThai)
 * dùng lib định dạng tiền của Tài chính → chép cùng phân hệ Tài chính ở GĐ3.
 */

/** Nhóm màu pill — cùng bộ với lib/de-nghi/trang-thai.ts của Tài chính. */
export type NhomPill = "xam" | "vang" | "xanh" | "do" | "dong";

/** Thẻ: LUÔN nền trắng + viền. `dem` = ruột 16px (tắt khi bên trong là bảng). */
export function The({
  dem = true,
  className,
  children,
  ...con
}: ComponentProps<"div"> & { dem?: boolean }) {
  return (
    <div className={`the ${dem ? "p-4" : ""} ${className ?? ""}`} {...con}>
      {children}
    </div>
  );
}

/** Pill: chấm + chữ, không bao giờ chỉ dựa vào màu. Xuống dòng được. */
export function Pill({
  nhom,
  className,
  children,
  title,
}: {
  nhom: NhomPill;
  className?: string;
  children: React.ReactNode;
  title?: string;
}) {
  return (
    <span className={`pill pill-${nhom} ${className ?? ""}`} title={title}>
      {children}
    </span>
  );
}

/**
 * Bảng — CHỈ dùng trên máy tính (điện thoại dùng thẻ). Bọc trong thẻ có cuộn
 * ngang để bảng rộng không đẩy vỡ trang. Ô tiền: <td className="cot-tien">;
 * dòng tổng: <tr className="dong-tong">.
 */
export function Bang({
  nhan,
  gon,
  className,
  children,
}: {
  /** Tên bảng cho trình đọc màn hình. */
  nhan?: string;
  /**
   * Bảng nhiều cột: chia cột theo <colgroup> và KHÔNG nong quá bề ngang khung
   * (table-layout: fixed) — máy tính khỏi phải trượt ngang. Đệm và cỡ chữ nhỏ
   * hơn một nấc. Đi kèm thì phải khai <colgroup>, không thì các cột chia đều.
   */
  gon?: boolean;
  className?: string;
  children: React.ReactNode;
}) {
  return (
    <div className={`the overflow-x-auto ${className ?? ""}`}>
      <table className={`bang ${gon ? "bang-gon" : ""}`} aria-label={nhan}>
        {children}
      </table>
    </div>
  );
}

/** Thông báo sau thao tác: thành công (xanh) hoặc lỗi (đỏ). */
export function ThongBao({
  loai,
  tieuDe,
  className,
  children,
}: {
  loai: "thanh-cong" | "loi";
  tieuDe?: string;
  className?: string;
  children?: React.ReactNode;
}) {
  const laLoi = loai === "loi";
  return (
    <div
      role={laLoi ? "alert" : "status"}
      className={`thong-bao ${laLoi ? "thong-bao-do" : "thong-bao-xanh"} ${className ?? ""}`}
    >
      <BieuTuong ten={laLoi ? "warn" : "check"} co={19} />
      <div>
        {tieuDe && <b>{tieuDe} </b>}
        {children}
      </div>
    </div>
  );
}

/** Danh sách rỗng: viền đứt + biểu tượng + một dòng chính + dòng phụ. */
export function TrangThaiTrong({
  bieuTuong = "file",
  chinh,
  phu,
  children,
}: {
  bieuTuong?: TenBieuTuong;
  chinh: string;
  phu?: React.ReactNode;
  /** Nút gợi ý bước tiếp (vd "Lập đề nghị"). */
  children?: React.ReactNode;
}) {
  return (
    <div className="trang-thai-trong">
      <BieuTuong ten={bieuTuong} co={26} className="inline-block" />
      <p className="chinh">{chinh}</p>
      {phu && <p className="phu">{phu}</p>}
      {children && <div className="mt-3">{children}</div>}
    </div>
  );
}

/** Khung chờ tải: các thanh xám TĨNH (không nhấp nháy — máy cũ giật). */
export function KhungChoTai({ soThe = 4 }: { soThe?: number }) {
  return (
    <div className="flex flex-col gap-3">
      <span className="sr-only" role="status">
        Đang tải…
      </span>
      <div className="xuong h-6 w-40" aria-hidden="true" />
      {Array.from({ length: soThe }, (_, i) => (
        <div key={i} className="the p-4" aria-hidden="true">
          <div className="xuong h-3 w-1/2" />
          <div className="xuong mt-2 h-4 w-5/6" />
          <div className="xuong mt-3.5 h-3 w-2/5" />
        </div>
      ))}
    </div>
  );
}
