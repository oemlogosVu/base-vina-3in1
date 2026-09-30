import { describe, expect, it } from 'vitest'

import { chanEnterTuGui } from '@ns/lib/bieu-mau'

describe('chanEnterTuGui — chặn form tự gửi khi bấm Enter', () => {
  it('chặn Enter trong ô nhập văn bản — đây chính là lỗi được báo', () => {
    // Biểu mẫu hồ sơ nhân sự có 16 ô. Gõ xong bấm Enter để sang ô kế là thói
    // quen rất thường, và trước khi sửa thì nó lưu đè dữ liệu đang sửa dở rồi
    // chuyển trang luôn.
    expect(chanEnterTuGui('Enter', 'INPUT', 'text')).toBe(true)
    expect(chanEnterTuGui('Enter', 'INPUT', undefined)).toBe(true)
  })

  it('chặn cả ở ô ngày, email, số — chúng cũng là ô một dòng', () => {
    for (const loai of ['date', 'email', 'number', 'tel', 'checkbox']) {
      expect(chanEnterTuGui('Enter', 'INPUT', loai)).toBe(true)
    }
  })

  it('KHÔNG chặn ở textarea — Enter ở đó là xuống dòng', () => {
    expect(chanEnterTuGui('Enter', 'TEXTAREA', undefined)).toBe(false)
  })

  it('KHÔNG chặn ở nút — Enter ở đó là người dùng chủ động bấm', () => {
    // Nhờ nhánh này mà người dùng bàn phím vẫn Tab tới nút Lưu rồi Enter được.
    expect(chanEnterTuGui('Enter', 'BUTTON', undefined)).toBe(false)
    expect(chanEnterTuGui('Enter', 'INPUT', 'submit')).toBe(false)
    expect(chanEnterTuGui('Enter', 'INPUT', 'button')).toBe(false)
    expect(chanEnterTuGui('Enter', 'INPUT', 'reset')).toBe(false)
  })

  it('KHÔNG chặn phím khác', () => {
    for (const phim of ['Tab', 'a', 'Escape', 'ArrowDown', ' ']) {
      expect(chanEnterTuGui(phim, 'INPUT', 'text')).toBe(false)
    }
  })

  it('không phân biệt hoa thường ở tên thẻ và loại ô', () => {
    expect(chanEnterTuGui('Enter', 'input', 'TEXT')).toBe(true)
    expect(chanEnterTuGui('Enter', 'input', 'SUBMIT')).toBe(false)
  })
})
