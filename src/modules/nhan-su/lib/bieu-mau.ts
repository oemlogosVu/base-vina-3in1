/**
 * Tiện ích dùng chung cho biểu mẫu.
 */

/**
 * Có nên chặn phím Enter để biểu mẫu không tự gửi không.
 *
 * VÌ SAO CẦN: theo chuẩn HTML, form có nút gửi thì bấm Enter trong bất kỳ ô
 * nhập MỘT DÒNG nào cũng gửi form ("implicit submission"). Với biểu mẫu ngắn
 * thì đó là tiện lợi. Với biểu mẫu hồ sơ nhân sự — 16 ô, ba nhóm — thì đó là
 * lỗi: gõ xong bấm Enter để sang ô kế là thói quen rất thường, và hệ quả là
 * lưu đè dữ liệu đang sửa dở rồi chuyển trang.
 *
 * KHÔNG chặn ở ba chỗ, vì chặn là hỏng thao tác bàn phím:
 *   - `textarea` — Enter là xuống dòng, không phải gửi.
 *   - `button` / `input[type=submit]` — Enter ở đó là BẤM nút, người dùng chủ
 *     động. Nhờ vậy người dùng bàn phím vẫn Tab tới nút Lưu rồi Enter được.
 *   - Phím khác Enter — không liên quan.
 */
export function chanEnterTuGui(
  phim: string,
  theHTML: string,
  loaiInput?: string,
): boolean {
  if (phim !== 'Enter') return false
  if (theHTML.toUpperCase() !== 'INPUT') return false
  const loai = (loaiInput ?? 'text').toLowerCase()
  if (loai === 'submit' || loai === 'button' || loai === 'reset') return false
  return true
}
