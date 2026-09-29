/**
 * Chỉ cho phép chuyển hướng tới đường dẫn nội bộ.
 *
 * Chép từ app Nhân sự (src/lib/safe-path.ts, main 9a0b9a8) — bản chặt hơn bản
 * của Tài chính (Tài chính chưa chặn dạng `/\host`).
 *
 * Tham số ?tiep_tuc= đến từ trình duyệt nên không được tin. Nếu không lọc, kẻ
 * xấu gửi link /dang-nhap?tiep_tuc=https://site-gia-mao để lừa nhân viên nhập
 * mật khẩu rồi bị đẩy sang trang giả.
 */
export function duongDanNoiBo(raw: unknown, fallback = "/"): string {
  if (typeof raw !== "string") return fallback;
  // Phải bắt đầu bằng một dấu / duy nhất. `//host` bị trình duyệt hiểu là
  // URL tuyệt đối theo protocol hiện tại, nên phải loại.
  if (!raw.startsWith("/") || raw.startsWith("//")) return fallback;
  // `/\host` bị một số trình duyệt chuẩn hoá thành `//host`.
  if (raw.startsWith("/\\")) return fallback;
  return raw;
}
