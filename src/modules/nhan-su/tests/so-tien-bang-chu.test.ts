import { describe, expect, it } from 'vitest'
import { dinhDangTien, docSoTienBangChu } from '../../../../supabase/functions/_shared/so-tien-bang-chu'

/**
 * Dòng "Bằng chữ" trên chứng từ là lớp chống sửa số tiền. Nó chỉ chống được
 * nếu nó ĐÚNG — một chứng từ ghi số 12.500.000 mà chữ đọc thành "mười hai
 * triệu năm trăm nghìn" thiếu chữ nào là chứng từ tự mâu thuẫn.
 *
 * Nên bộ này soi đúng những chỗ tiếng Việt đọc số khác quy tắc chung: mốt, tư,
 * lăm, lẻ, và nhóm ba chữ số bằng 0 nằm giữa.
 */
describe('docSoTienBangChu', () => {
  it('đọc số nhỏ', () => {
    expect(docSoTienBangChu(0)).toBe('Không đồng')
    expect(docSoTienBangChu(1)).toBe('Một đồng')
    expect(docSoTienBangChu(10)).toBe('Mười đồng')
    expect(docSoTienBangChu(11)).toBe('Mười một đồng')
    expect(docSoTienBangChu(15)).toBe('Mười lăm đồng')
  })

  it('đọc đúng mốt, tư, lăm ở hàng đơn vị', () => {
    expect(docSoTienBangChu(21)).toBe('Hai mươi mốt đồng')
    expect(docSoTienBangChu(24)).toBe('Hai mươi tư đồng')
    expect(docSoTienBangChu(25)).toBe('Hai mươi lăm đồng')
    expect(docSoTienBangChu(95)).toBe('Chín mươi lăm đồng')
  })

  it('đọc "lẻ" khi mất hàng chục', () => {
    expect(docSoTienBangChu(105)).toBe('Một trăm lẻ năm đồng')
    expect(docSoTienBangChu(100)).toBe('Một trăm đồng')
  })

  it('nhóm cao nhất đọc gọn, nhóm sau đọc đủ ba chữ số', () => {
    // Nhóm sau phải giữ "không trăm", nếu không thì 1.023.000 và 1.230.000
    // đọc giống hệt nhau — hai số cách nhau hai trăm nghìn.
    expect(docSoTienBangChu(1_023_000)).toBe('Một triệu không trăm hai mươi ba nghìn đồng')
    expect(docSoTienBangChu(1_230_000)).toBe('Một triệu hai trăm ba mươi nghìn đồng')
  })

  it('bỏ hẳn nhóm ba chữ số bằng 0, nhưng giữ "không trăm" trong nhóm còn số', () => {
    // Kế toán đọc đầy đủ: "một triệu KHÔNG TRĂM lẻ bảy". Dạng nói gọn "một
    // triệu lẻ bảy" đúng trong đời thường nhưng trên chứng từ thì kém — nó bỏ
    // mất chỗ trống mà người sửa có thể điền thêm chữ số vào.
    expect(docSoTienBangChu(1_000_007)).toBe('Một triệu không trăm lẻ bảy đồng')
    // Nhóm nghìn bằng 0 thì bỏ hẳn, không đọc "hai triệu không nghìn".
    expect(docSoTienBangChu(2_000_000)).toBe('Hai triệu đồng')
    expect(docSoTienBangChu(1_000_000_500)).toBe('Một tỷ năm trăm đồng')
  })

  it('đọc số tiền cỡ một bảng thanh toán thật', () => {
    expect(docSoTienBangChu(12_500_000)).toBe('Mười hai triệu năm trăm nghìn đồng')
    expect(docSoTienBangChu(347_850_000)).toBe(
      'Ba trăm bốn mươi bảy triệu tám trăm năm mươi nghìn đồng',
    )
  })

  it('đọc tới hàng tỷ', () => {
    expect(docSoTienBangChu(1_000_000_000)).toBe('Một tỷ đồng')
    expect(docSoTienBangChu(2_500_000_000)).toBe('Hai tỷ năm trăm triệu đồng')
  })

  it('từ chối thay vì tự làm tròn hoặc tự sửa', () => {
    // Tự làm tròn trên chứng từ là đổi số tiền mà không ai biết.
    expect(() => docSoTienBangChu(1000.5)).toThrow(/số nguyên đồng/)
    expect(() => docSoTienBangChu(-1)).toThrow(/không được âm/)
    expect(() => docSoTienBangChu(Number.NaN)).toThrow(/số nguyên đồng/)
    expect(() => docSoTienBangChu(1e15)).toThrow(/vượt ngoài phạm vi/)
  })
})

describe('dinhDangTien', () => {
  it('ngăn nghìn bằng dấu chấm', () => {
    expect(dinhDangTien(0)).toBe('0')
    expect(dinhDangTien(999)).toBe('999')
    expect(dinhDangTien(1000)).toBe('1.000')
    expect(dinhDangTien(1_234_567)).toBe('1.234.567')
    expect(dinhDangTien(-1_234_567)).toBe('-1.234.567')
  })
})
