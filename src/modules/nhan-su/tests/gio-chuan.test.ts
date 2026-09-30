import { describe, expect, it } from 'vitest'

import {
  docCapGio,
  gioTuKhoang,
  kiemGioMotNguoi,
  kiemKhungGioVaCa,
  phut,
  type CaKhai,
  type KhungGioCongTy,
} from '@ns/lib/gio-chuan'

const ca = (nhan: string, bd: string | null, kt: string | null): CaKhai => ({
  ma: nhan,
  nhan,
  gt: bd === null || kt === null ? undefined : { bd, kt },
})

const kiem = (
  khung: [string, string] | null,
  nghi: [string, string] | null,
  ds: CaKhai[] = [],
) =>
  kiemKhungGioVaCa(
    khung ? { bd: khung[0], kt: khung[1] } : undefined,
    nghi ? { bd: nghi[0], kt: nghi[1] } : undefined,
    ds,
  )

describe('phut — so sánh giờ bằng số phút', () => {
  it('đổi "HH:MM" thành số phút từ nửa đêm', () => {
    expect(phut('00:00')).toBe(0)
    expect(phut('07:30')).toBe(450)
    expect(phut('17:00')).toBe(1020)
  })
})

describe('docCapGio — một cặp giờ bắt đầu–kết thúc', () => {
  it('bỏ trống cả hai là "không dùng", không phải lỗi', () => {
    expect(docCapGio(null, null, 'Ca tối')).toEqual({ gt: undefined })
  })

  it('khai nửa vời thì nói rõ thiếu đầu nào', () => {
    expect(docCapGio(null, '11:00', 'Ca sáng')).toEqual({
      loi: 'Ca sáng: đã điền giờ kết thúc 11:00 nhưng bỏ trống giờ bắt đầu.',
    })
    expect(docCapGio('07:00', null, 'Ca sáng')).toEqual({
      loi: 'Ca sáng: đã điền giờ bắt đầu 07:00 nhưng bỏ trống giờ kết thúc.',
    })
  })

  it('hai đầu bằng nhau là khoảng dài 0 phút', () => {
    const kq = docCapGio('08:00', '08:00', 'Khung giờ chuẩn')
    expect('loi' in kq && kq.loi).toContain('dài 0 phút')
  })

  it('kết thúc sớm hơn bắt đầu thì nói rõ CHƯA nhận khoảng qua nửa đêm', () => {
    // Không im lặng từ chối: người dùng phải biết đây là giới hạn của hệ thống
    // chứ không phải họ gõ sai.
    const kq = docCapGio('22:00', '06:00', 'Khung giờ chuẩn')
    expect('loi' in kq && kq.loi).toContain('vắt qua nửa đêm')
  })

  it('khoảng hợp lệ thì trả về đúng hai đầu', () => {
    expect(docCapGio('07:30', '17:00', 'Khung giờ chuẩn')).toEqual({
      gt: { bd: '07:30', kt: '17:00' },
    })
  })
})

describe('kiemKhungGioVaCa — giờ nghỉ phải nằm trong khung', () => {
  it('khung giờ thường ngày là hợp lệ', () => {
    expect(kiem(['08:00', '17:00'], ['12:00', '13:00'])).toBeNull()
    expect(kiem(['07:30', '17:00'], ['11:30', '13:00'])).toBeNull()
  })

  it('không khai giờ nghỉ vẫn hợp lệ', () => {
    expect(kiem(['07:00', '17:00'], null)).toBeNull()
  })

  it('nghỉ trùng đúng mép khung vẫn hợp lệ', () => {
    expect(kiem(['12:00', '17:00'], ['12:00', '13:00'])).toBeNull()
    expect(kiem(['08:00', '13:00'], ['12:00', '13:00'])).toBeNull()
  })

  it('nghỉ bắt đầu trước giờ vào thì nói rõ hai con số', () => {
    expect(kiem(['08:00', '17:00'], ['07:00', '08:00'])).toBe(
      'Giờ nghỉ bắt đầu 07:00, sớm hơn giờ vào 08:00. Giờ nghỉ phải nằm trong khung giờ chuẩn.',
    )
  })

  it('nghỉ kết thúc sau giờ ra thì nói rõ hai con số', () => {
    expect(kiem(['08:00', '17:00'], ['16:30', '18:00'])).toBe(
      'Giờ nghỉ kết thúc 18:00, muộn hơn giờ ra 17:00. Giờ nghỉ phải nằm trong khung giờ chuẩn.',
    )
  })

  it('khai nghỉ mà chưa khai khung thì bảo khai khung trước', () => {
    const loi = kiem(null, ['12:00', '13:00'])
    expect(loi).toContain('chưa khai khung giờ chuẩn')
  })
})

describe('kiemKhungGioVaCa — hai ca không được chồng giờ', () => {
  const KHUNG: [string, string] = ['08:00', '17:00']

  it('ba ca rời nhau là hợp lệ', () => {
    expect(
      kiem(KHUNG, ['12:00', '13:00'], [
        ca('Ca sáng', '07:00', '11:00'),
        ca('Ca chiều', '13:00', '17:00'),
        ca('Ca tối', '18:00', '22:00'),
      ]),
    ).toBeNull()
  })

  it('ca liền kề chạm mép nhau KHÔNG phải chồng', () => {
    // 11:00–13:00 rồi 13:00–17:00: giờ 13:00 chỉ thuộc ca sau.
    expect(
      kiem(KHUNG, null, [ca('Ca sáng', '11:00', '13:00'), ca('Ca chiều', '13:00', '17:00')]),
    ).toBeNull()
  })

  it('ca chồng nhau thì gọi tên ĐÚNG HAI CA và giờ của chúng', () => {
    expect(
      kiem(KHUNG, null, [ca('Ca chiều', '13:00', '17:00'), ca('Ca tối', '16:00', '22:00')]),
    ).toBe(
      'Ca chiều (13:00–17:00) chồng giờ với Ca tối (16:00–22:00). ' +
        'Hai ca chồng nhau là đếm hai lần cùng một giờ làm.',
    )
  })

  it('ca bỏ trống không tham gia phép so chồng giờ', () => {
    expect(
      kiem(KHUNG, null, [ca('Ca sáng', '07:00', '11:00'), ca('Ca tối', null, null)]),
    ).toBeNull()
  })
})

describe('gioTuKhoang — số giờ hiện trên lưới chấm công', () => {
  // ĐÚNG BẢNG mà `gio_cong_nhat_tu_khoang()` ở database đã đối chiếu tay,
  // khung 08:00–17:00 nghỉ 12:00–13:00. Hai bản phải cho cùng kết quả; lệch
  // nhau thì bên sai là bên TypeScript — database là bên quyết định.
  const KHUNG: KhungGioCongTy = {
    gioVao: '08:00',
    gioRa: '17:00',
    nghiTu: '12:00',
    nghiDen: '13:00',
  }
  const k = (bd: string, kt: string) => ({ bd, kt })

  it.each([
    ['nghỉ cả ngày', [], 0, 0],
    ['sáng 07–11', [k('07:00', '11:00')], 3, 1],
    ['sáng 08:30–11 (đến muộn)', [k('08:30', '11:00')], 2.5, 0],
    ['chiều 13–17', [k('13:00', '17:00')], 4, 0],
    ['tối 18–22', [k('18:00', '22:00')], 0, 4],
    ['sáng + chiều', [k('07:00', '11:00'), k('13:00', '17:00')], 7, 1],
    ['cả ba ca', [k('07:00', '11:00'), k('13:00', '17:00'), k('18:00', '22:00')], 7, 5],
    ['vắt qua giờ nghỉ 11–15', [k('11:00', '15:00')], 3, 0],
    ['về sớm 13–15:30', [k('13:00', '15:30')], 2.5, 0],
  ])('%s', (_ten, khoang, thuong, ot) => {
    expect(gioTuKhoang(KHUNG, khoang)).toEqual({ thuong, ot })
  })

  it('chưa khai khung giờ chuẩn thì không tính ra giờ nào', () => {
    // Màn hình hiện 0 và nói ra thứ còn thiếu; database thì TỪ CHỐI ghi. Hai
    // cách xử lý khác nhau cho cùng một tình huống, và khác có chủ đích:
    // màn hình không được sập, database không được nhận số sai.
    expect(gioTuKhoang(null, [k('07:00', '11:00')])).toEqual({ thuong: 0, ot: 0 })
  })

  it('công ty không có giờ nghỉ trưa thì không trừ gì', () => {
    const khong: KhungGioCongTy = { gioVao: '08:00', gioRa: '17:00', nghiTu: null, nghiDen: null }
    expect(gioTuKhoang(khong, [k('08:00', '17:00')])).toEqual({ thuong: 9, ot: 0 })
  })

  // ĐÚNG BẢNG mà `gio_cong_nhat_tu_khoang()` đã đối chiếu tay ở P5g.
  describe('dòng ngoài giờ (P5g)', () => {
    it('toàn bộ dòng ngoài giờ tính là ngoài giờ', () => {
      expect(gioTuKhoang(KHUNG, [k('13:00', '17:00')], k('18:00', '21:30'))).toEqual({
        thuong: 4,
        ot: 3.5,
      })
    })

    it('ngoài giờ nằm TRONG khung giờ chuẩn vẫn là ngoài giờ', () => {
      // Không xét khung, không trừ giờ nghỉ: đây là khoảng người ta ở lại làm
      // thêm, hỏi nó có nằm trong giờ hành chính không là hỏi sai câu.
      expect(gioTuKhoang(KHUNG, [], k('09:00', '11:00'))).toEqual({ thuong: 0, ot: 2 })
    })

    it('chỉ có ngoài giờ, không ca nào', () => {
      expect(gioTuKhoang(KHUNG, [], k('18:00', '22:00'))).toEqual({ thuong: 0, ot: 4 })
    })

    it('cả ba ca cộng dòng ngoài giờ', () => {
      expect(
        gioTuKhoang(
          KHUNG,
          [k('07:00', '11:00'), k('13:00', '17:00'), k('18:00', '22:00')],
          k('22:00', '00:00'),
        ),
      ).toEqual({ thuong: 7, ot: 7 })
    })
  })

  describe('quy ước nửa đêm: giờ kết thúc 00:00', () => {
    it('20:00–00:00 là bốn giờ, không phải âm hai mươi', () => {
      expect(gioTuKhoang(KHUNG, [], k('20:00', '00:00'))).toEqual({ thuong: 0, ot: 4 })
    })

    it('00:00–02:00 ở đầu ngày vẫn là hai giờ sáng sớm', () => {
      // 00:00 ở ĐẦU khoảng là 0 giờ sáng; chỉ ở CUỐI mới là nửa đêm.
      expect(gioTuKhoang(KHUNG, [], k('00:00', '02:00'))).toEqual({ thuong: 0, ot: 2 })
    })

    it('một ca kết thúc lúc nửa đêm cũng đọc đúng', () => {
      expect(gioTuKhoang(KHUNG, [k('20:00', '00:00')])).toEqual({ thuong: 0, ot: 4 })
    })
  })
})

describe('docCapGio — quy ước nửa đêm và lời khuyên tách ngày', () => {
  it('kết thúc 00:00 KHÔNG bị coi là giờ ngược', () => {
    expect(docCapGio('20:00', '00:00', 'Ngoài giờ')).toEqual({
      gt: { bd: '20:00', kt: '00:00' },
    })
  })

  it('giờ ngược thật thì bảo TÁCH THEO NGÀY, không bảo "chưa hỗ trợ"', () => {
    // Quyết định 24/08/2026: làm qua nửa đêm thì tách hai phiếu. Câu lỗi phải
    // dạy đúng cách làm, không chỉ nói là sai.
    const kq = docCapGio('20:00', '02:00', 'Ngoài giờ')
    expect('loi' in kq && kq.loi).toContain('tách theo ngày')
  })
})

describe('kiemGioMotNguoi — lỗi Triệu Vũ gặp ngày 24/08/2026', () => {
  const kh = (nhan: string, bd: string | null, kt: string | null) => ({
    nhan,
    gt: bd === null || kt === null ? null : { bd, kt },
  })

  it('sạch thì trả null', () => {
    expect(
      kiemGioMotNguoi('Nguyễn Văn A', [
        kh('ca sáng', '07:00', '11:00'),
        kh('ca chiều', '13:00', '17:00'),
        kh('ngoài giờ', '18:00', '00:00'),
      ]),
    ).toBeNull()
  })

  it('ngoài giờ vắt qua nửa đêm: CHỈ CÁCH tách ngày, không nói mã ràng buộc', () => {
    // Nguyên văn Triệu Vũ nhận trước bản vá:
    //   violates check constraint "cccn_ngoai_gio_xuoi"
    // Ràng buộc chặn đúng, nhưng câu ấy không nói được ai, khoảng nào, sai gì.
    const loi = kiemGioMotNguoi('Nguyễn Văn A', [kh('ngoài giờ', '22:00', '02:00')])
    expect(loi).toContain('Nguyễn Văn A')
    expect(loi).toContain('ngoài giờ')
    expect(loi).toContain('22:00')
    expect(loi).toContain('02:00')
    expect(loi).toContain('tách theo ngày')
    expect(loi).not.toContain('constraint')
  })

  it('kết thúc 00:00 là nửa đêm, KHÔNG phải giờ ngược', () => {
    expect(kiemGioMotNguoi('A', [kh('ngoài giờ', '20:00', '00:00')])).toBeNull()
  })

  it('khoảng dài 0 phút bị bắt', () => {
    const loi = kiemGioMotNguoi('A', [kh('ca sáng', '08:00', '08:00')])
    expect(loi).toContain('dài 0 phút')
  })

  it('thiếu một đầu giờ thì bảo điền nốt hoặc bỏ chọn', () => {
    const loi = kiemGioMotNguoi('A', [{ nhan: 'ca tối', gt: { bd: '18:00', kt: '' } }])
    expect(loi).toContain('thiếu một đầu giờ')
  })

  it('ngoài giờ chồng lên ca thì gọi tên cả hai và giờ của chúng', () => {
    const loi = kiemGioMotNguoi('Trần Thị B', [
      kh('ca chiều', '13:00', '17:00'),
      kh('ngoài giờ', '16:00', '20:00'),
    ])
    expect(loi).toContain('Trần Thị B')
    expect(loi).toContain('ca chiều (13:00–17:00)')
    expect(loi).toContain('ngoài giờ (16:00–20:00)')
  })

  it('hai ca chạm mép nhau KHÔNG phải chồng', () => {
    expect(
      kiemGioMotNguoi('A', [kh('ca chiều', '13:00', '17:00'), kh('ngoài giờ', '17:00', '20:00')]),
    ).toBeNull()
  })
})
