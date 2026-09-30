/**
 * Luật của khung giờ chuẩn và ba ca công nhật — phần THUẦN, kiểm được bằng test.
 *
 * Tách khỏi server action vì đây là chỗ dễ sai và đắt khi sai: giờ ca quyết
 * định giờ nào là ngoài giờ, mà ngoài giờ là tiền. Nằm trong `'use server'`
 * thì không viết được test cho nó.
 *
 * ⚠️ Đây KHÔNG phải lớp chặn. Ràng buộc thật là bốn CHECK trên `companies` và
 * trigger `chan_ca_cong_nhat_chong_nhau` ở database. Việc của file này là nói
 * ra **ô nào sai và sai thế nào**, trước khi database từ chối bằng một mã lỗi.
 */

/** "07:30" → 450. So sánh giờ bằng số phút thì không phải nghĩ về chuỗi. */
export function phut(g: string): number {
  const [h, m] = g.split(':')
  return Number(h) * 60 + Number(m)
}

/**
 * Giờ KẾT THÚC quy ra phút, với quy ước nửa đêm.
 *
 * `00:00` ở cuối một khoảng nghĩa là **nửa đêm cuối ngày** (1440 phút), không
 * phải 0 giờ sáng. Cần quy ước này vì ô `<input type="time">` của trình duyệt
 * dừng ở 23:59, mà quyết định 24/08/2026 là làm qua nửa đêm thì tách theo
 * ngày — nên phải ghi được một khoảng kết thúc đúng lúc nửa đêm.
 *
 * Không nhập nhằng: một khoảng KẾT THÚC lúc 00:00 chỉ có thể là nửa đêm; còn
 * 00:00 ở đầu khoảng vẫn là 0 giờ sáng như thường. Phải khớp với
 * `phut_trong_ngay(gio, true)` ở database.
 */
export function phutKetThuc(g: string): number {
  const p = phut(g)
  return p === 0 ? 1440 : p
}

/** "07:30:00" → "07:30". Giây không nói thêm được gì cho người đọc. */
export const gioGon = (g: string) => g.slice(0, 5)

export type KhoangGio = { bd: string; kt: string }

/** `undefined` = bỏ trống cả hai, tức "không dùng" — khác hẳn "khai sai". */
export type DocCapGio = { loi: string } | { gt: KhoangGio | undefined }

export function docCapGio(
  bd: string | null,
  kt: string | null,
  nhan: string,
): DocCapGio {
  if (bd === null && kt === null) return { gt: undefined }

  if (bd === null) {
    return { loi: `${nhan}: đã điền giờ kết thúc ${gioGon(kt!)} nhưng bỏ trống giờ bắt đầu.` }
  }
  if (kt === null) {
    return { loi: `${nhan}: đã điền giờ bắt đầu ${gioGon(bd)} nhưng bỏ trống giờ kết thúc.` }
  }

  if (phutKetThuc(kt) === phut(bd)) {
    return {
      loi: `${nhan}: giờ bắt đầu và giờ kết thúc cùng là ${gioGon(bd)} — khoảng ấy dài 0 phút.`,
    }
  }
  if (phutKetThuc(kt) < phut(bd)) {
    return {
      loi:
        `${nhan}: giờ kết thúc ${gioGon(kt)} sớm hơn giờ bắt đầu ${gioGon(bd)}. ` +
        'Làm vắt qua nửa đêm thì tách theo ngày: phần đến 00:00 ghi vào hôm nay, phần còn lại ghi vào phiếu ngày mai.',
    }
  }

  return { gt: { bd, kt } }
}

export type CaKhai = { ma: string; nhan: string; gt: KhoangGio | undefined }

/**
 * Kiểm toàn bộ mười ô cùng lúc, trả câu lỗi ĐẦU TIÊN hoặc `null`.
 *
 * Kiểm hết rồi mới ghi. Bản đầu (24/08/2026) ghi khung giờ trước rồi ghi từng
 * ca sau, nên một lỗi ở giữa để lại trạng thái nửa vời — công ty BaseVN có 2 ca
 * mà không có khung giờ, đúng vì lý do đó.
 */
export function kiemKhungGioVaCa(
  khung: KhoangGio | undefined,
  nghi: KhoangGio | undefined,
  ca: CaKhai[],
): string | null {
  if (nghi && !khung) {
    return (
      `Đã khai giờ nghỉ ${gioGon(nghi.bd)}–${gioGon(nghi.kt)} nhưng chưa khai khung giờ chuẩn. ` +
      'Điền giờ vào và giờ ra trước — giờ nghỉ phải nằm trong khung ấy.'
    )
  }

  if (nghi && khung) {
    if (phut(nghi.bd) < phut(khung.bd)) {
      return (
        `Giờ nghỉ bắt đầu ${gioGon(nghi.bd)}, sớm hơn giờ vào ${gioGon(khung.bd)}. ` +
        'Giờ nghỉ phải nằm trong khung giờ chuẩn.'
      )
    }
    if (phut(nghi.kt) > phut(khung.kt)) {
      return (
        `Giờ nghỉ kết thúc ${gioGon(nghi.kt)}, muộn hơn giờ ra ${gioGon(khung.kt)}. ` +
        'Giờ nghỉ phải nằm trong khung giờ chuẩn.'
      )
    }
  }

  // Hai ca chồng giờ là đếm hai lần cùng một giờ làm. Database cũng chặn, nhưng
  // ở đây nói được ĐÚNG HAI CA NÀO và giờ của chúng.
  const dangDung = ca.flatMap((c) =>
    c.gt === undefined ? [] : [{ nhan: c.nhan, bd: c.gt.bd, kt: c.gt.kt }],
  )
  for (const [i, a] of dangDung.entries()) {
    for (const b of dangDung.slice(i + 1)) {
      if (phut(a.bd) < phutKetThuc(b.kt) && phutKetThuc(a.kt) > phut(b.bd)) {
        return (
          `${a.nhan} (${gioGon(a.bd)}–${gioGon(a.kt)}) chồng giờ với ` +
          `${b.nhan} (${gioGon(b.bd)}–${gioGon(b.kt)}). ` +
          'Hai ca chồng nhau là đếm hai lần cùng một giờ làm.'
        )
      }
    }
  }

  return null
}

/** Ba ca cố định. Phải khớp ràng buộc `ca_ma_hop_le` ở database. */
export const MA_CA = [
  { ma: 'sang', nhan: 'Ca sáng' },
  { ma: 'chieu', nhan: 'Ca chiều' },
  { ma: 'toi', nhan: 'Ca tối' },
] as const

/** Khung giờ chuẩn của một công ty — giờ nghỉ có thể không khai. */
export type KhungGioCongTy = {
  gioVao: string
  gioRa: string
  nghiTu: string | null
  nghiDen: string | null
}

/** Số phút giao nhau của hai khoảng giờ trong ngày. Bản TS của `phut_giao_gio`. */
function phutGiao(a1: string, a2: string, b1: string, b2: string): number {
  return Math.max(
    0,
    Math.min(phutKetThuc(a2), phutKetThuc(b2)) - Math.max(phut(a1), phut(b1)),
  )
}

/**
 * Giờ thường và giờ ngoài giờ của những khoảng giờ đã chấm.
 *
 * ⚠️ ĐÂY LÀ CON SỐ ĐỂ NHÌN. Con số đi vào bảng thanh toán do trigger
 * `trg_cccn_tinh_gio_tu_ca` tính lại lúc ghi, từ hàm
 * `gio_cong_nhat_tu_khoang()` ở database. Hàm này tồn tại vì lưới chấm công
 * phải hiện số giờ NGAY khi tổ trưởng gõ, mà hỏi database từng phím thì không
 * dùng được ngoài công trường.
 *
 * Hai bản phải cho cùng kết quả. Bộ kiểm hành vi tổ đội đối chiếu con số của
 * database với bảng tính tay; unit test đối chiếu hàm này với đúng bảng ấy.
 * Lệch nhau thì bên sai là bên này — database là bên quyết định.
 *
 * Luật: giờ nghỉ trưa không trả tiền; phần trong khung là giờ thường; phần
 * ngoài khung là ngoài giờ.
 */
export function gioTuKhoang(
  khung: KhungGioCongTy | null,
  ca: (KhoangGio | undefined)[],
  ngoaiGio?: KhoangGio,
): { thuong: number; ot: number } {
  const dung = ca.filter((k): k is KhoangGio => k !== undefined)
  const lam = (p: number) => Math.round((p / 60) * 100) / 100

  if (khung === null) return { thuong: 0, ot: 0 }

  let tong = 0
  let nghi = 0
  let trong = 0

  for (const k of dung) {
    tong += phutKetThuc(k.kt) - phut(k.bd)
    trong += phutGiao(k.bd, k.kt, khung.gioVao, khung.gioRa)
    if (khung.nghiTu !== null && khung.nghiDen !== null) {
      nghi += phutGiao(k.bd, k.kt, khung.nghiTu, khung.nghiDen)
    }
  }

  // Dòng ngoài giờ: TOÀN BỘ tính ngoài giờ, không xét khung, không trừ giờ
  // nghỉ. Nó là khoảng người ta ở lại làm thêm; hỏi nó có nằm trong giờ hành
  // chính không là hỏi sai câu.
  const phutNgoai = ngoaiGio ? phutKetThuc(ngoaiGio.kt) - phut(ngoaiGio.bd) : 0

  return { thuong: lam(trong - nghi), ot: lam(tong - trong + phutNgoai) }
}

/** Một khoảng giờ đã chấm, kèm tên để câu lỗi gọi đúng chỗ. */
export type KhoangCoTen = { nhan: string; gt: KhoangGio | null }

/**
 * Kiểm bốn khoảng giờ của MỘT NGƯỜI trong một ngày.
 *
 * VÌ SAO CÓ HÀM NÀY: bản P5g có đủ ràng buộc ở database nhưng lưới chấm công
 * không kiểm gì trước khi gửi, nên Triệu Vũ gõ một khoảng ngoài giờ vắt qua
 * nửa đêm và nhận nguyên văn:
 *
 *   new row for relation "cham_cong_cong_nhat" violates check constraint
 *   "cccn_ngoai_gio_xuoi"
 *
 * Ràng buộc chặn đúng, nhưng câu ấy không nói được ai, khoảng nào, sai gì, và
 * phải làm sao. Cùng bài học với "Khung giờ không hợp lệ" sáng nay: dịch mã
 * lỗi thôi chưa đủ, phải nói ra ô nào và số nào.
 *
 * Trả câu lỗi ĐẦU TIÊN, hoặc `null` khi sạch. Lớp chặn thật vẫn là bốn ràng
 * buộc `cccn_*` ở database.
 */
export function kiemGioMotNguoi(ten: string, khoang: KhoangCoTen[]): string | null {
  const dung: { nhan: string; bd: number; kt: number; goc: KhoangGio }[] = []

  for (const k of khoang) {
    if (k.gt === null) continue

    if (k.gt.bd === '' || k.gt.kt === '') {
      return `${ten} · ${k.nhan}: còn thiếu một đầu giờ. Điền cả giờ vào lẫn giờ ra, hoặc bỏ chọn khoảng này.`
    }

    const bd = phut(k.gt.bd)
    const kt = phutKetThuc(k.gt.kt)

    if (kt === bd) {
      return `${ten} · ${k.nhan}: giờ vào và giờ ra cùng là ${k.gt.bd} — khoảng ấy dài 0 phút.`
    }
    if (kt < bd) {
      return (
        `${ten} · ${k.nhan}: giờ ra ${k.gt.kt} không sau giờ vào ${k.gt.bd}. ` +
        'Làm vắt qua nửa đêm thì tách theo ngày — ghi đến 00:00 của hôm nay, ' +
        'phần còn lại ghi tiếp ở phiếu ngày mai.'
      )
    }

    dung.push({ nhan: k.nhan, bd, kt, goc: k.gt })
  }

  for (const [i, a] of dung.entries()) {
    for (const b of dung.slice(i + 1)) {
      if (a.bd < b.kt && a.kt > b.bd) {
        return (
          `${ten}: ${a.nhan} (${a.goc.bd}–${a.goc.kt}) chồng giờ với ` +
          `${b.nhan} (${b.goc.bd}–${b.goc.kt}). ` +
          'Chồng nhau là đếm hai lần cùng một giờ làm, và phần chồng được trả cả giá thường lẫn giá ngoài giờ.'
        )
      }
    }
  }

  return null
}
