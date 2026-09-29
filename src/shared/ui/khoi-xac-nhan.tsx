import { Nut } from "./nut";
import { ThongBao } from "./hien-thi";

/**
 * KHỐI XÁC NHẬN TẠI CHỖ — thay cho MỌI popup / window.confirm.
 *
 * Mở rộng ngay dưới nút vừa bấm, không che nội dung. Popup từng làm vỡ giao diện
 * trên điện thoại cũ, nên app không có cái nào.
 *
 * Trình bày thuần: màn gọi tự giữ trạng thái mở/đóng, và khi khối mở thì tự
 * vô hiệu nút hành động đối lập (vd mở "Từ chối" thì khóa "Duyệt đợt").
 *
 * Nút xác nhận: truyền `onXacNhan` thì là nút thường; không truyền thì là nút
 * submit — đặt khối trong <form action={...}> để gửi thẳng server action.
 */
export function KhoiXacNhan({
  loai = "thuong",
  cauHoi,
  heQua,
  nhanXacNhan,
  onXacNhan,
  onThoi,
  dangXuLy,
  loi,
  className,
  children,
}: {
  /** "do" cho việc phá hủy (từ chối, hủy, xóa): nền đỏ nhạt + nút đặc đỏ. */
  loai?: "thuong" | "do";
  cauHoi: string;
  /** MỘT dòng hệ quả, vd "3 mục · 186.500.000 đ sẽ quay lại Kế toán trưởng." */
  heQua?: React.ReactNode;
  nhanXacNhan: string;
  onXacNhan?: () => void;
  onThoi: () => void;
  dangXuLy?: boolean;
  loi?: string | null;
  className?: string;
  /** Ô lý do (nếu cần) — đặt giữa câu hỏi và hai nút. */
  children?: React.ReactNode;
}) {
  return (
    <div
      role="group"
      aria-label={cauHoi}
      className={`khoi-xac-nhan ${loai === "do" ? "khoi-xac-nhan-do" : ""} ${className ?? ""}`}
    >
      <p className="cau-hoi">{cauHoi}</p>
      {heQua && <p className="he-qua">{heQua}</p>}
      {children && <div className="mt-3">{children}</div>}
      {loi && (
        <ThongBao loai="loi" className="mt-3">
          {loi}
        </ThongBao>
      )}
      <div className="mt-3 flex flex-wrap gap-2">
        <Nut
          bienThe={loai === "do" ? "do-dac" : "chinh"}
          type={onXacNhan ? "button" : "submit"}
          onClick={onXacNhan}
          dangXuLy={dangXuLy}
          nhanDangXuLy="Đang xử lý…"
          className="flex-1"
        >
          {nhanXacNhan}
        </Nut>
        <Nut bienThe="phu" onClick={onThoi} disabled={dangXuLy}>
          Thôi
        </Nut>
      </div>
    </div>
  );
}
