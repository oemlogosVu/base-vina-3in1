import { describe, expect, it } from 'vitest'
import {
  congTuPhut,
  docCong,
  laChuNhat,
  ngayTrongThang,
  phutChuanMotNgay,
  phutGiaoNhau,
  phutLamMotNgay,
  type CaChuan,
} from '@ns/lib/cong-ngay'

/**
 * Ca chuẩn thật của hệ thống: 08:00–17:00, nghỉ trưa 12:00–13:00.
 * Một ngày công đầy đủ = 540 − 60 = 480 phút.
 */
const CA: CaChuan = { tu: '08:00', den: '17:00', nghiTu: '12:00', nghiDen: '13:00' }

/**
 * Từng cặp số dưới đây ĐÃ ĐỐI CHIẾU với `tinh_cong_mot_ngay()` chạy trên
 * database thật (25/08/2026), không phải tự tôi tính ra.
 *
 * Đây là lý do bảng này tồn tại: file `cong-ngay.ts` là bản CHÉP LẠI công
 * thức của database để hiện xem trước trên màn hình. Hai bản cùng một công
 * thức thì sẽ có ngày lệch nhau — bảng này là chỗ phát hiện ra.
 *
 * Đổi công thức ở database mà quên sửa bên này thì mấy dòng này đỏ.
 */
const DOI_CHIEU: { vao: string; ra: string; phut: number; ghi: string }[] = [
  { vao: '08:00', ra: '17:00', phut: 480, ghi: 'cả ngày' },
  { vao: '08:00', ra: '12:00', phut: 240, ghi: 'buổi sáng, nghỉ đúng lúc tan' },
  { vao: '13:00', ra: '17:00', phut: 240, ghi: 'buổi chiều, vào đúng lúc hết nghỉ' },
  { vao: '08:00', ra: '14:00', phut: 300, ghi: 'sáng + 1 tiếng chiều, trừ nghỉ' },
  { vao: '08:00', ra: '15:00', phut: 360, ghi: 'sáng + 2 tiếng chiều' },
  { vao: '09:30', ra: '17:00', phut: 390, ghi: 'vào muộn 1,5 tiếng' },
  { vao: '07:00', ra: '18:00', phut: 480, ghi: 'tới sớm về muộn — KHÔNG cộng ngoài ca' },
  { vao: '11:00', ra: '13:30', phut: 90, ghi: 'nằm vắt qua giờ nghỉ' },
]

describe('phutLamMotNgay — khớp từng con số với database', () => {
  for (const c of DOI_CHIEU) {
    it(`${c.vao}–${c.ra} = ${c.phut} phút (${c.ghi})`, () => {
      expect(phutLamMotNgay(c.vao, c.ra, CA, false)).toBe(c.phut)
    })
  }

  it('CHỦ NHẬT luôn ra 0 phút, dù chấm cả ngày', () => {
    // Ngày nghỉ tuần không có giờ hành chính; giờ làm hôm đó là làm thêm và
    // đi đường khác. Chấm bù vào chủ nhật mà không biết thì ghi xong công vẫn
    // bằng 0 — giao diện phải cảnh báo trước.
    expect(phutLamMotNgay('08:00', '17:00', CA, true)).toBe(0)
  })

  it('giờ ra không sau giờ vào thì ra 0, không ra số âm', () => {
    expect(phutLamMotNgay('17:00', '08:00', CA, false)).toBe(0)
    expect(phutLamMotNgay('09:00', '09:00', CA, false)).toBe(0)
  })

  it('khoảng nằm trọn trong giờ nghỉ thì ra 0', () => {
    expect(phutLamMotNgay('12:10', '12:50', CA, false)).toBe(0)
  })

  it('ca không có giờ nghỉ thì không trừ gì', () => {
    const caLienTuc: CaChuan = { tu: '08:00', den: '17:00', nghiTu: null, nghiDen: null }
    expect(phutLamMotNgay('08:00', '17:00', caLienTuc, false)).toBe(540)
  })
})

describe('phutGiaoNhau', () => {
  it('không chồng nhau thì 0, không bao giờ âm', () => {
    expect(phutGiaoNhau(0, 100, 200, 300)).toBe(0)
    expect(phutGiaoNhau(200, 300, 0, 100)).toBe(0)
  })

  it('chồng một phần thì đúng phần chồng', () => {
    expect(phutGiaoNhau(0, 100, 50, 300)).toBe(50)
  })

  it('nằm trọn bên trong thì bằng chính nó', () => {
    expect(phutGiaoNhau(50, 80, 0, 300)).toBe(30)
  })
})

describe('congTuPhut — quy phút thành ngày công', () => {
  it('ngày công đầy đủ của ca chuẩn là 480 phút', () => {
    expect(phutChuanMotNgay(CA)).toBe(480)
  })

  it('nửa ngày ra đúng 0,5', () => {
    expect(congTuPhut(240, 480)).toBe(0.5)
  })

  it('ba phần tư ngày ra đúng 0,75', () => {
    expect(congTuPhut(360, 480)).toBe(0.75)
  })

  it('làm tròn 2 chữ số y như engine lương', () => {
    // 300/480 = 0,625 → engine `round(..., 2)` ra 0,63. Đây là con số THẬT SỰ
    // nhân với lương, nên bản xem trước phải hiện đúng nó chứ không hiện
    // 0,625 rồi để người dùng ngạc nhiên ở bảng lương.
    expect(congTuPhut(300, 480)).toBe(0.63)
  })

  it('cả ngày ra đúng 1', () => {
    expect(congTuPhut(480, 480)).toBe(1)
  })
})

describe('docCong — chữ hiện trên màn hình', () => {
  it('dấu phẩy thập phân, bỏ số 0 thừa', () => {
    expect(docCong(1)).toBe('1')
    expect(docCong(0.5)).toBe('0,5')
    expect(docCong(0.75)).toBe('0,75')
    expect(docCong(0.63)).toBe('0,63')
    expect(docCong(0)).toBe('0')
  })
})

describe('ngayTrongThang — trục ngang của bảng công tháng', () => {
  it('tháng đủ 31 ngày', () => {
    const ds = ngayTrongThang(2026, 8)
    expect(ds).toHaveLength(31)
    expect(ds[0]).toBe('2026-08-01')
    expect(ds[30]).toBe('2026-08-31')
  })

  it('tháng thiếu 30 ngày', () => {
    expect(ngayTrongThang(2026, 4)).toHaveLength(30)
  })

  it('tháng 2 năm thường 28 ngày, năm nhuận 29', () => {
    // Sai chỗ này thì bảng tháng 2 mất hoặc thừa một cột, và cột cuối lệch
    // sang tháng sau.
    expect(ngayTrongThang(2026, 2)).toHaveLength(28)
    expect(ngayTrongThang(2028, 2)).toHaveLength(29)
    expect(ngayTrongThang(2028, 2).at(-1)).toBe('2028-02-29')
  })

  it('tháng 12 không tràn sang năm sau', () => {
    const ds = ngayTrongThang(2026, 12)
    expect(ds).toHaveLength(31)
    expect(ds.at(-1)).toBe('2026-12-31')
  })

  it('luôn đệm 0 cho tháng và ngày một chữ số', () => {
    expect(ngayTrongThang(2026, 1)[0]).toBe('2026-01-01')
  })
})

describe('laChuNhat — cột tô xám của bảng tháng', () => {
  it('nhận đúng chủ nhật', () => {
    // 09/08/2026 là chủ nhật; đối chiếu với database ngày 25/08/2026.
    expect(laChuNhat('2026-08-09')).toBe(true)
    expect(laChuNhat('2026-08-16')).toBe(true)
  })

  it('không nhận nhầm ngày khác', () => {
    expect(laChuNhat('2026-08-11')).toBe(false)
    expect(laChuNhat('2026-08-08')).toBe(false)
  })

  it('đúng cả ở đầu và cuối tháng', () => {
    // Bẫy múi giờ: `new Date("2026-11-01")` hiểu là UTC, còn máy chủ chạy giờ
    // khác — lệch một ngày là tô nhầm cả cột.
    expect(laChuNhat('2026-11-01')).toBe(true)
    expect(laChuNhat('2026-08-30')).toBe(true)
  })
})
