/**
 * Quy đổi thời gian theo giờ Việt Nam.
 *
 * Đây là một trong hai chỗ dễ tính sai tiền nhất của cả dự án (chỗ kia là
 * biểu thuế TNCN ở P3). Hai cái bẫy được xử lý ở đây:
 *
 *   1. Múi giờ. `logged_at` lưu UTC, nhưng ngày công là ngày theo giờ Việt
 *      Nam. Ca đêm chấm ra 00:30 giờ VN là UTC 17:30 hôm trước — tổng hợp
 *      theo UTC là đẩy công sang nhầm ngày.
 *
 * ⚠️ Phép TÍNH CÔNG một ngày KHÔNG còn ở đây. Nó từng có một bản TypeScript
 * song song với bản SQL, và hai bản đã lệch nhau một lần (ceil vs floor).
 * Từ 12/08/2026 chỉ còn một bản duy nhất: hàm `public.tinh_cong_mot_ngay()`
 * trong database, và bộ kiểm tra gọi thẳng vào đó. Một công thức tiền lương
 * không nên có hai bản cài đặt.
 *
 * File TypeScript thuần, không dùng API Deno — chạy được cả trong Edge
 * Function lẫn Vitest.
 */

/**
 * Việt Nam là UTC+7 cố định, không có giờ mùa hè (bỏ từ 1975).
 *
 * Nhờ vậy dùng offset cố định là chính xác tuyệt đối, không cần thư viện múi
 * giờ. Nếu Việt Nam đổi luật giờ thì đây là chỗ duy nhất phải sửa.
 */
export const OFFSET_VN = '+07:00'
export const MUI_GIO_VN = 'Asia/Ho_Chi_Minh'

/** Một mốc giờ trong ngày, dạng 'HH:MM' hoặc 'HH:MM:SS' như Postgres trả về. */
export type GioTrongNgay = string

/**
 * Ngày làm việc theo giờ Việt Nam của một mốc thời gian, dạng 'YYYY-MM-DD'.
 *
 * Dùng `en-CA` vì locale đó cho ra đúng định dạng ISO. Không tự cộng 7 tiếng
 * rồi lấy phần ngày của UTC — cách đó đúng nhưng khó đọc và dễ bị người sau
 * "sửa cho gọn" thành sai.
 */
export function ngayLamViecVN(thoiDiem: Date): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: MUI_GIO_VN,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(thoiDiem)
}

/**
 * Ghép ngày làm việc với một mốc giờ trong ngày thành thời điểm tuyệt đối.
 *
 * Ví dụ ('2026-08-10', '08:00') → 2026-08-10T08:00+07:00 → UTC 01:00.
 */
export function thoiDiemVN(ngay: string, gio: GioTrongNgay): Date {
  const gioDayDu = gio.length === 5 ? `${gio}:00` : gio
  const t = new Date(`${ngay}T${gioDayDu}${OFFSET_VN}`)
  if (Number.isNaN(t.getTime())) {
    throw new Error(`Không dựng được thời điểm từ ngày "${ngay}" và giờ "${gio}".`)
  }
  return t
}

/**
 * Số phút giao nhau của hai khoảng thời gian, 0 nếu không giao.
 *
 * Trùng tên và trùng ý nghĩa với hàm `public.phut_giao_nhau()` trong
 * database. Hai nơi cùng công thức là cố ý: Edge Function tính khi ghi, SQL
 * tính khi tổng hợp, và cả hai phải ra cùng một con số. Test đơn vị ở đây
 * canh cho phía TypeScript; `p2_rls_check.sql` canh cho phía SQL.
 */
export function phutGiaoNhau(a1: Date, a2: Date, b1: Date, b2: Date): number {
  const batDau = Math.max(a1.getTime(), b1.getTime())
  const ketThuc = Math.min(a2.getTime(), b2.getTime())
  if (ketThuc <= batDau) return 0
  return Math.floor((ketThuc - batDau) / 60_000)
}
