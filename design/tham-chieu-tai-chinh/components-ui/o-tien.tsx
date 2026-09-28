"use client";

/**
 * Ô NHẬP TIỀN — hiện 1.000.000 khi gõ, giá trị thật vẫn là số nguyên.
 *
 * Vì sao cần: kế toán quen nhìn số có dấu chấm ngăn nghìn. Gõ "5000000" mà không
 * thấy phân cách thì rất dễ thừa/thiếu một số 0 — sai 10 lần tiền.
 *
 * Tự chấm bằng regex chứ không qua toLocaleString: kết quả giống hệt nhau trên
 * máy chủ lẫn trình duyệt cũ (không lệch khi hydrate, không phụ thuộc dữ liệu
 * ngôn ngữ của máy).
 *
 * `name`: kèm một <input hidden> mang số trơn, để form gửi thẳng lên server
 * action mà không phải tự bóc dấu chấm.
 */
export function chamNghin(so: number): string {
  return so > 0 ? String(Math.trunc(so)).replace(/\B(?=(\d{3})+(?!\d))/g, ".") : "";
}

export function OTien({
  giaTri,
  onDoi,
  id,
  name,
  loi,
  canhBao,
  nho,
  disabled,
  className,
  "aria-describedby": moTa,
  "aria-label": nhan,
}: {
  giaTri: number;
  onDoi: (so: number) => void;
  id?: string;
  name?: string;
  loi?: boolean;
  /** Viền vàng — số đã bị sửa khác số gốc (vd KTT duyệt thấp hơn đề nghị). */
  canhBao?: boolean;
  /** Ô thấp 40px trong bảng máy tính. */
  nho?: boolean;
  disabled?: boolean;
  className?: string;
  "aria-describedby"?: string;
  "aria-label"?: string;
}) {
  return (
    <div className={`o-tien-khung ${className ?? ""}`}>
      <input
        id={id}
        type="text"
        inputMode="numeric"
        autoComplete="off"
        value={chamNghin(giaTri)}
        disabled={disabled}
        aria-invalid={loi || undefined}
        aria-describedby={moTa}
        aria-label={nhan}
        onChange={(e) => {
          // Bỏ mọi ký tự không phải số (kể cả dấu chấm người dùng gõ hoặc dán vào).
          // Tối đa 15 chữ số: quá nữa thì số của JavaScript bắt đầu mất chính xác.
          const so = Number(e.target.value.replace(/\D/g, "").slice(0, 15));
          onDoi(Number.isNaN(so) ? 0 : so);
        }}
        className={`o-nhap o-tien ${nho ? "o-nhap-nho" : ""} ${canhBao ? "o-giam" : ""}`}
      />
      <span className="hau-to" aria-hidden="true">
        đ
      </span>
      {name && <input type="hidden" name={name} value={giaTri > 0 ? String(giaTri) : ""} />}
    </div>
  );
}
