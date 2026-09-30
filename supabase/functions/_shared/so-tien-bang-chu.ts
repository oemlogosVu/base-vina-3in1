/**
 * Đọc số tiền thành chữ tiếng Việt — dòng "Bằng chữ:" trên chứng từ.
 *
 * VÌ SAO CHỨNG TỪ CẦN DÒNG NÀY: nó là cách chống sửa rẻ nhất mà kế toán Việt
 * Nam dùng từ trước khi có máy tính. Thêm một chữ số vào "12.000.000" thì dễ;
 * sửa cả dòng chữ cho khớp thì không làm lén được.
 *
 * Đặt ở `_shared` vì Edge Function (Deno) là nơi sinh PDF, còn bộ kiểm đơn vị
 * (vitest, Node) là nơi chứng minh nó đọc đúng. Một bản, hai nơi dùng — chứ
 * không phải hai bản.
 *
 * PHẠM VI CỐ Ý HẸP
 *
 *   • Chỉ số nguyên không âm. Lương và thanh toán nhân công ở đây luôn là số
 *     tròn đồng; hàm NÉM LỖI thay vì tự làm tròn, vì tự làm tròn trên chứng từ
 *     là sửa số tiền mà không ai biết.
 *   • Tối đa 15 chữ số (dưới một triệu tỷ). Vượt là dấu hiệu số liệu sai, chứ
 *     không phải nhu cầu thật.
 */

const CHU_SO = ['không', 'một', 'hai', 'ba', 'bốn', 'năm', 'sáu', 'bảy', 'tám', 'chín']

// Ba chữ số một nhóm, đúng cách người Việt ngắt khi đọc.
const HANG = ['', ' nghìn', ' triệu', ' tỷ', ' nghìn tỷ']

// Tra bảng qua hàm, không tra thẳng bằng chỉ số. `noUncheckedIndexedAccess`
// bật trong dự án này nên mọi phần tử mảng đều có thể là `undefined` với
// TypeScript — và ở một hàm đọc số tiền thì "undefined" lọt vào chuỗi kết quả
// là một chứng từ ghi sai chữ.
const chuSo = (i: number) => CHU_SO[i] ?? ''
const hang = (i: number) => HANG[i] ?? ''

/**
 * Đọc một nhóm ba chữ số.
 *
 * `dayDu = false` cho nhóm cao nhất: 105 đọc "một trăm lẻ năm", nhưng số 5
 * đứng một mình chỉ đọc "năm", không phải "không trăm lẻ năm".
 */
function docBaChuSo(n: number, dayDu: boolean): string {
  const tram = Math.floor(n / 100)
  const chuc = Math.floor((n % 100) / 10)
  const donVi = n % 10
  const phan: string[] = []

  if (tram > 0 || dayDu) phan.push(`${chuSo(tram)} trăm`)

  if (chuc === 0) {
    // "lẻ" chỉ xuất hiện khi còn hàng đơn vị và phía trước đã có hàng trăm.
    if (donVi > 0 && (tram > 0 || dayDu)) phan.push('lẻ', chuSo(donVi))
    else if (donVi > 0) phan.push(chuSo(donVi))
  } else if (chuc === 1) {
    phan.push('mười')
    // 11 = "mười một", 15 = "mười lăm" — không phải "mười năm".
    if (donVi === 5) phan.push('lăm')
    else if (donVi > 0) phan.push(chuSo(donVi))
  } else {
    phan.push(`${chuSo(chuc)} mươi`)
    // 21 = "hai mươi mốt", 25 = "hai mươi lăm", 24 = "hai mươi tư".
    if (donVi === 1) phan.push('mốt')
    else if (donVi === 4) phan.push('tư')
    else if (donVi === 5) phan.push('lăm')
    else if (donVi > 0) phan.push(chuSo(donVi))
  }

  return phan.join(' ')
}

export function docSoTienBangChu(soTien: number): string {
  if (!Number.isFinite(soTien) || !Number.isInteger(soTien)) {
    throw new Error(`Số tiền phải là số nguyên đồng, nhận được ${soTien}.`)
  }
  if (soTien < 0) {
    throw new Error(`Số tiền trên chứng từ không được âm, nhận được ${soTien}.`)
  }
  if (soTien >= 1e15) {
    throw new Error(`Số tiền ${soTien} vượt ngoài phạm vi đọc được — kiểm lại số liệu.`)
  }

  if (soTien === 0) return 'Không đồng'

  // Tách thành các nhóm ba chữ số, nhóm thấp nhất đứng trước.
  const nhom: number[] = []
  let con = soTien
  while (con > 0) {
    nhom.push(con % 1000)
    con = Math.floor(con / 1000)
  }

  const phan: string[] = []
  for (let i = nhom.length - 1; i >= 0; i -= 1) {
    // Nhóm 0 ở giữa thì bỏ hẳn: 1.000.007 đọc "một triệu lẻ bảy", không đọc
    // "một triệu không nghìn lẻ bảy".
    const g = nhom[i] ?? 0
    if (g === 0) continue
    // Nhóm cao nhất đọc gọn; các nhóm sau đọc đủ ba chữ số để không mất số 0
    // ở giữa (1.023.000 phải là "một triệu không trăm hai mươi ba nghìn").
    phan.push(docBaChuSo(g, i !== nhom.length - 1) + hang(i))
  }

  const chu = phan.join(' ').replace(/\s+/g, ' ').trim()
  return `${chu.charAt(0).toUpperCase()}${chu.slice(1)} đồng`
}

/** 1234567 → "1.234.567". Dấu chấm ngăn nghìn, đúng quy ước Việt Nam. */
export function dinhDangTien(n: number): string {
  const am = n < 0
  const so = Math.round(Math.abs(n)).toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.')
  return am ? `-${so}` : so
}
