import { BieuTuong } from "./bieu-tuong";

/**
 * MỘT Ô TRONG FORM: nhãn trên, ô ở giữa, gợi ý hoặc lỗi dưới.
 *
 * Bên trong là ô GỐC của trình duyệt (<input>, <select>, <textarea>) mang class
 * `o-nhap` — không thay bằng dropdown hay lịch tự vẽ: máy cũ vỡ giao diện.
 *
 * Gợi ý tối đa MỘT dòng ngắn. Giải thích dài hơn đưa vào `chiTiet`: hiện thành
 * dòng "Giải thích" mở rộng tại chỗ bằng <details> gốc — không tooltip, không
 * popup, không cần JavaScript.
 */
export function OTruong({
  nhan,
  htmlFor,
  batBuoc,
  goiY,
  loi,
  chiTiet,
  className,
  children,
}: {
  nhan: React.ReactNode;
  htmlFor?: string;
  batBuoc?: boolean;
  goiY?: React.ReactNode;
  /** Có lỗi thì hiện lỗi thay cho gợi ý. Nhớ đặt aria-invalid trên ô. */
  loi?: string | null;
  chiTiet?: React.ReactNode;
  className?: string;
  children: React.ReactNode;
}) {
  return (
    <div className={className}>
      <label htmlFor={htmlFor} className="nhan-o">
        {nhan}
        {batBuoc && <span className="dau-bat-buoc"> *</span>}
      </label>
      {children}
      {loi ? (
        <p className="dong-loi" role="alert">
          <BieuTuong ten="warn" co={15} />
          {loi}
        </p>
      ) : goiY ? (
        <p className="goi-y">{goiY}</p>
      ) : null}
      {chiTiet && (
        <details className="mo-rong">
          <summary>
            Giải thích
            <BieuTuong ten="down" co={16} className="mui-ten" />
          </summary>
          <div className="goi-y mt-0">{chiTiet}</div>
        </details>
      )}
    </div>
  );
}

/** Khung bọc <input type="file"> gốc — viền đứt + biểu tượng kẹp giấy. */
export function KhungTep({ children }: { children: React.ReactNode }) {
  return (
    <div className="khung-tep">
      <BieuTuong ten="clip" co={18} />
      {children}
    </div>
  );
}
