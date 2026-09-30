import { describe, expect, it } from 'vitest'

// File này chỉ còn test phần quy đổi thời gian.
//
// Phép TÍNH CÔNG một ngày đã chuyển hẳn về SQL (`public.tinh_cong_mot_ngay`)
// ngày 12/08/2026, và bộ kiểm tra cấu trúc gọi thẳng hàm đó với 10 trường hợp
// mốc. Trước đây công thức có hai bản cài đặt — SQL và TypeScript — và chúng
// đã lệch nhau một lần. Test một bản sao không ai dùng thì không canh được gì.
//
// Phần Haversine bỏ ngày 11/08 cùng với tính năng địa điểm chấm công.
import {
  ngayLamViecVN,
  phutGiaoNhau,
  thoiDiemVN,
} from '../../../../supabase/functions/_shared/thoi-gian'

const NGAY = '2026-08-10'
const luc = (gio: string) => thoiDiemVN(NGAY, gio)

describe('ngayLamViecVN — cái bẫy múi giờ', () => {
  it('giữa trưa giờ VN vào đúng ngày của nó', () => {
    expect(ngayLamViecVN(new Date('2026-08-10T05:00:00Z'))).toBe('2026-08-10')
  })

  it('00:30 giờ VN thuộc ngày VN hôm đó, dù UTC vẫn là 17:30 hôm trước', () => {
    // Đây chính là ca đêm. Tổng hợp theo UTC sẽ đẩy công sang nhầm ngày.
    const t = new Date('2026-08-11T17:30:00Z')
    expect(t.toISOString().slice(0, 10)).toBe('2026-08-11') // ngày UTC
    expect(ngayLamViecVN(t)).toBe('2026-08-12') // ngày VN — cái đúng
  })

  it('23:30 giờ VN vẫn thuộc ngày hôm đó, chưa sang ngày mới', () => {
    expect(ngayLamViecVN(new Date('2026-08-10T16:30:00Z'))).toBe('2026-08-10')
  })
})

describe('thoiDiemVN', () => {
  it('nhận cả HH:MM lẫn HH:MM:SS như Postgres trả về', () => {
    expect(thoiDiemVN('2026-08-10', '08:00').toISOString()).toBe('2026-08-10T01:00:00.000Z')
    expect(thoiDiemVN('2026-08-10', '08:00:00').toISOString()).toBe('2026-08-10T01:00:00.000Z')
  })

  it('ném lỗi khi đầu vào không dựng được thời điểm', () => {
    expect(() => thoiDiemVN('khong-phai-ngay', '08:00')).toThrow()
  })
})

describe('phutGiaoNhau', () => {
  it('không giao thì bằng 0', () => {
    expect(phutGiaoNhau(luc('08:00'), luc('12:00'), luc('13:00'), luc('17:00'))).toBe(0)
  })

  it('chạm nhau ở đúng một điểm cũng là không giao', () => {
    expect(phutGiaoNhau(luc('08:00'), luc('12:00'), luc('12:00'), luc('13:00'))).toBe(0)
  })

  it('giao một phần thì trả về đúng phần đó', () => {
    expect(phutGiaoNhau(luc('08:00'), luc('12:30'), luc('12:00'), luc('13:00'))).toBe(30)
  })

  it('bao trọn thì trả về cả khoảng bên trong', () => {
    expect(phutGiaoNhau(luc('08:00'), luc('17:00'), luc('12:00'), luc('13:00'))).toBe(60)
  })
})
