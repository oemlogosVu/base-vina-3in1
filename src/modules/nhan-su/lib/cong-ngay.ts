/**
 * Quy đổi GIỜ VÀO – GIỜ RA thành số phút làm việc và số ngày công.
 *
 * VÌ SAO CÓ FILE NÀY
 *
 * Công của nhân viên chính thức KHÔNG phải một con số người ta gõ vào — nó
 * tính ra từ giờ. Nửa ngày là 08:00–12:00, không phải "0,5". Nhưng người đang
 * chấm bù chỉ nhìn thấy hai ô giờ, và họ cần biết ngay hai ô ấy sẽ thành bao
 * nhiêu công TRƯỚC khi bấm lưu — chứ không phải mở bảng lương tháng sau mới
 * biết mình vừa ghi nhầm một ngày.
 *
 * ⚠️ ĐÂY LÀ BẢN XEM TRƯỚC, KHÔNG PHẢI NGUỒN SỰ THẬT.
 *
 * Con số đi vào lương do `tinh_cong_mot_ngay()` ở database quyết định. File
 * này chép lại đúng công thức ấy để hiện ngay trên màn hình:
 *
 *     phút làm = (giao của [vào,ra] với [ca vào, ca ra])
 *              − (giao của [vào,ra] với [nghỉ từ, nghỉ đến])
 *
 * Hai bản cùng một công thức là thứ dự án này vốn tránh. Chấp nhận ở đây vì
 * bản này KHÔNG ghi gì cả, và đổi lại người dùng thấy hệ quả trước khi bấm.
 * Bộ kiểm đơn vị ghim từng cặp số đã đối chiếu với hàm ở database — lệch nhau
 * thì đỏ ngay.
 */

/** "08:30" → 510 phút kể từ nửa đêm. "00:00" ở vế KẾT THÚC nghĩa là nửa đêm. */
export function phut(gio: string): number {
  const [g, p] = gio.split(':').map(Number)
  return (g ?? 0) * 60 + (p ?? 0)
}

/** Số phút hai khoảng chồng lên nhau. Không chồng thì 0, không bao giờ âm. */
export function phutGiaoNhau(a1: number, a2: number, b1: number, b2: number): number {
  return Math.max(0, Math.min(a2, b2) - Math.max(a1, b1))
}

export type CaChuan = {
  /** Giờ vào ca, ví dụ "08:00". */
  tu: string
  /** Giờ tan ca, ví dụ "17:00". */
  den: string
  /** Nghỉ giữa ca. `null` = ca không có giờ nghỉ. */
  nghiTu: string | null
  nghiDen: string | null
}

/**
 * Phút làm việc thường của một ngày.
 *
 * CHỦ NHẬT LUÔN RA 0, đúng như database: ngày nghỉ tuần không có giờ hành
 * chính, giờ làm hôm đó là làm thêm và đi đường khác. Chấm bù vào chủ nhật mà
 * không biết điều này thì ghi xong công vẫn bằng 0 — nên giao diện phải cảnh
 * báo trước, không để người dùng tự phát hiện.
 */
export function phutLamMotNgay(vao: string, ra: string, ca: CaChuan, laChuNhat: boolean): number {
  if (laChuNhat) return 0
  const v = phut(vao)
  const r = phut(ra)
  if (r <= v) return 0

  const trongCa = phutGiaoNhau(v, r, phut(ca.tu), phut(ca.den))
  const trungNghi =
    ca.nghiTu && ca.nghiDen ? phutGiaoNhau(v, r, phut(ca.nghiTu), phut(ca.nghiDen)) : 0

  return Math.max(0, trongCa - trungNghi)
}

/** Số phút của một ngày công đầy đủ: độ dài ca trừ giờ nghỉ. */
export function phutChuanMotNgay(ca: CaChuan): number {
  const dai = phut(ca.den) - phut(ca.tu)
  const nghi = ca.nghiTu && ca.nghiDen ? phut(ca.nghiDen) - phut(ca.nghiTu) : 0
  return Math.max(1, dai - nghi)
}

/**
 * Phút làm → ngày công, làm tròn 2 chữ số thập phân.
 *
 * Đúng cách engine lương làm: `round(phut_lam / phut_chuan_ngay, 2)`. Nên
 * 300 phút trên ca 480 phút ra 0,63 chứ không phải 0,625 — và đó là con số
 * thật sự nhân với lương.
 */
export function congTuPhut(phutLam: number, phutChuan: number): number {
  return Math.round((phutLam / phutChuan) * 100) / 100
}

/**
 * Mọi ngày của một tháng, dạng yyyy-mm-dd.
 *
 * `Date.UTC(nam, thang, 0)` cho ngày cuối của tháng `thang` — tháng ở đây đếm
 * từ 1, còn `Date.UTC` đếm từ 0, nên `thang` chính là "tháng sau, ngày 0".
 * Cách này tự đúng với tháng thiếu và năm nhuận, không phải bảng tra.
 */
export function ngayTrongThang(nam: number, thang: number): string[] {
  const soNgay = new Date(Date.UTC(nam, thang, 0)).getUTCDate()
  return Array.from({ length: soNgay }, (_, i) => {
    const d = String(i + 1).padStart(2, '0')
    return `${nam}-${String(thang).padStart(2, '0')}-${d}`
  })
}

/**
 * Ngày ấy có phải chủ nhật không.
 *
 * Dựng ngày ở UTC từ ba con số, KHÔNG dùng `new Date("2026-08-09")`: chuỗi
 * dạng ấy được hiểu là UTC còn máy chủ thì chạy múi giờ khác, và lệch một
 * ngày nghĩa là tô nhầm cột chủ nhật cho cả bảng.
 */
export function laChuNhat(ngay: string): boolean {
  const [n = 1970, t = 1, d = 1] = ngay.split('-').map(Number)
  return new Date(Date.UTC(n, t - 1, d)).getUTCDay() === 0
}

/** "0,5" — dấu phẩy thập phân, bỏ số 0 thừa ở cuối. */
export function docCong(cong: number): string {
  return cong.toFixed(2).replace(/\.?0+$/, '').replace('.', ',') || '0'
}
