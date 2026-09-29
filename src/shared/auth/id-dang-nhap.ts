/**
 * ID ĐĂNG NHẬP = email HOẶC số điện thoại.
 *
 * Supabase Auth chỉ đăng nhập bằng email. Để cho phép đăng nhập bằng SĐT mà
 * KHÔNG cần tra cứu (tránh lộ danh sách SĐT), ta quy đổi SĐT thành một email
 * TỔNG HỢP cố định: "<chỉ-số>@sodienthoai.local". Người dùng nhập SĐT, hệ thống
 * tự đổi ra đúng email đó rồi đăng nhập. Người nhập email thật thì dùng thẳng.
 *
 * Cùng một hàm dùng ở cả lúc TẠO tài khoản (đặt email) lẫn lúc ĐĂNG NHẬP (đối
 * chiếu email) nên hai bên luôn khớp.
 */

export const MIEN_SDT = "sodienthoai.local";

/** Chuỗi có phải email không (có ký tự @). */
export function laEmail(id: string): boolean {
  return id.includes("@");
}

/** Chỉ giữ chữ số của SĐT (bỏ dấu cách, gạch, dấu ngoặc). */
export function chuanHoaSdt(id: string): string {
  return id.replace(/\D/g, "");
}

/**
 * Quy đổi ID đăng nhập (email hoặc SĐT) → email dùng cho Supabase Auth.
 * Email → giữ nguyên (thường hóa chữ thường). SĐT → "<số>@sodienthoai.local".
 */
export function emailTuId(id: string): string {
  const s = id.trim();
  if (laEmail(s)) return s.toLowerCase();
  return `${chuanHoaSdt(s)}@${MIEN_SDT}`;
}

/** ID có hợp lệ để tạo/đăng nhập không (email có @, hoặc SĐT >= 8 chữ số). */
export function idHopLe(id: string): boolean {
  const s = id.trim();
  if (!s) return false;
  if (laEmail(s)) return s.length >= 3 && s.includes(".");
  return chuanHoaSdt(s).length >= 8;
}
