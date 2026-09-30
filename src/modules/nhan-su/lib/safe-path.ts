/**
 * Chỉ cho phép chuyển hướng tới đường dẫn nội bộ.
 *
 * Tham số ?next= đến từ client nên không được tin (AGENTS.md mục 2.2).
 * Nếu không lọc, kẻ tấn công gửi link /login?next=https://site-gia-mao
 * để lừa nhân viên nhập mật khẩu rồi bị đẩy sang trang giả.
 */
export function safeInternalPath(raw: unknown, fallback = '/'): string {
  if (typeof raw !== 'string') return fallback
  // Phải bắt đầu bằng một dấu / duy nhất. `//host` bị trình duyệt hiểu là
  // URL tuyệt đối theo protocol hiện tại, nên phải loại.
  if (!raw.startsWith('/') || raw.startsWith('//')) return fallback
  // `/\host` bị một số trình duyệt chuẩn hoá thành `//host`.
  if (raw.startsWith('/\\')) return fallback
  return raw
}
