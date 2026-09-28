import type { ComponentProps } from "react";

import type { NhomPill, TrangThaiHienThi } from "@/lib/de-nghi/trang-thai";
import { soTien, tien, tienRa, tienVao } from "@/lib/dinh-dang";

import { BieuTuong, type TenBieuTuong } from "./bieu-tuong";

/**
 * Các thành phần HIỂN THỊ thuần (không trạng thái, render được ở máy chủ):
 * Thẻ, Pill, Tiền, Bảng, Ô số liệu, Thanh tiến độ, Thông báo, Trạng thái trống,
 * Khung chờ tải. Kiểu dáng nằm ở globals.css (@layer components).
 */

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

/** Pill từ kết quả của lib/de-nghi/trang-thai.ts. `dayDu` = nhãn đầy đủ (trang chi tiết). */
export function PillTrangThai({
  tt,
  dayDu,
  className,
}: {
  tt: TrangThaiHienThi;
  dayDu?: boolean;
  className?: string;
}) {
  return (
    <Pill nhom={tt.nhom} className={className} title={dayDu ? undefined : tt.nhanDayDu}>
      {dayDu ? tt.nhanDayDu : tt.nhan}
    </Pill>
  );
}

/** Số tiền chữ số đều cột. `loai="vao"` → "+ … đ" xanh, `"ra"` → "− … đ" đỏ. */
export function Tien({
  giaTri,
  loai,
  khongDonVi,
  className,
}: {
  giaTri: string | number | null | undefined;
  loai?: "vao" | "ra";
  /** Bỏ chữ "đ" — trong cột tiền của bảng. */
  khongDonVi?: boolean;
  className?: string;
}) {
  const chu =
    loai === "vao" ? tienVao(giaTri) : loai === "ra" ? tienRa(giaTri) : khongDonVi ? soTien(giaTri) : tien(giaTri);
  const mau = loai === "vao" ? "tien-vao" : loai === "ra" ? "tien-ra" : "";
  return <span className={`tien ${mau} ${className ?? ""}`}>{chu}</span>;
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

/** Ô số liệu (KPI): nhãn nhỏ + số lớn. Tiền ra tô đỏ. */
export function OSoLieu({
  nhan,
  giaTri,
  loai,
  className,
}: {
  nhan: string;
  giaTri: React.ReactNode;
  loai?: "vao" | "ra";
  className?: string;
}) {
  const mau = loai === "vao" ? "tien-vao" : loai === "ra" ? "tien-ra" : "";
  return (
    <div className={`the o-so-lieu ${className ?? ""}`}>
      <p className="nhan">{nhan}</p>
      <p className={`so tien ${mau}`}>{giaTri}</p>
    </div>
  );
}

/** Thanh tiến độ ngân sách: đã dùng / tổng. Vượt thì đỏ + pill "Vượt ngân sách". */
export function ThanhTienDo({
  nhan,
  daDung,
  tong,
}: {
  nhan: string;
  daDung: number;
  tong: number;
}) {
  const vuot = tong > 0 && daDung > tong;
  const phanTram = tong > 0 ? Math.min(100, Math.round((daDung / tong) * 100)) : 0;
  return (
    <div>
      <div className="flex items-baseline justify-between gap-3 text-sm">
        <span className="text-muc-phu">{nhan}</span>
        <span className={`tien font-bold ${vuot ? "tien-ra" : ""}`}>
          {soTien(daDung)} / {soTien(tong)}
        </span>
      </div>
      <div
        className={`thanh-tien-do mt-2 ${vuot ? "thanh-tien-do-vuot" : ""}`}
        role="progressbar"
        aria-label={nhan}
        aria-valuemin={0}
        aria-valuemax={100}
        aria-valuenow={phanTram}
      >
        {/* Độ rộng là chỗ DUY NHẤT được dùng style nội tuyến. */}
        <div style={{ width: `${vuot ? 100 : phanTram}%` }} />
      </div>
      {vuot && (
        <Pill nhom="do" className="mt-2">
          Vượt ngân sách
        </Pill>
      )}
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
