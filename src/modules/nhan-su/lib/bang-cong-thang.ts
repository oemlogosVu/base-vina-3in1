import { createClient } from '@ns/lib/supabase/server'
import {
  congTuPhut,
  laChuNhat,
  ngayTrongThang,
  phutChuanMotNgay,
  type CaChuan,
} from '@ns/lib/cong-ngay'

// Hai hàm thuần `ngayTrongThang` và `laChuNhat` sống ở `cong-ngay.ts` để bộ
// kiểm đơn vị nạp được — file này kéo theo `supabase/server`, mà thứ đó cần
// `next/headers` và không chạy trong vitest.
export { laChuNhat, ngayTrongThang }

/**
 * Bảng công tháng — ma trận NGƯỜI × NGÀY.
 *
 * Triệu Vũ, 25/08/2026: *"cần thiết kế một tab hoặc giao diện dạng bảng để xem
 * tình trạng chấm công theo thời gian."*
 *
 * Không màn nào trước đây trả lời được câu "tháng này ai hay nghỉ, ngày nào cả
 * công ty vắng": màn Chấm công chỉ có công của chính mình, màn Xác nhận và màn
 * Sửa chữa công đều xem MỘT ngày. Nhìn theo thời gian là một câu hỏi khác hẳn,
 * và nó cần một hình dạng khác hẳn.
 *
 * HAI ĐƠN VỊ, HAI BẢNG — CỐ Ý KHÔNG GỘP
 *
 * Nhân viên chính thức ăn công theo GIỜ (phút làm ÷ ca chuẩn). Nhân công tổ
 * đội ăn theo SỐ CÔNG khoán hoặc SỐ GIỜ thoả thuận. Đổ hai thứ vào một bảng
 * rồi cộng một cột "tổng công" là mời một phép cộng sai — nên phạm vi quyết
 * định bảng nào hiện ra, và không bao giờ hiện cả hai cùng lúc.
 */

/** Trạng thái một ô. Quyết định màu nền và cách đọc. */
export type LoaiO =
  | 'du_cong' // làm đủ ngày
  | 'nua_cong' // có công nhưng chưa đủ
  | 'nghi' // có dữ liệu và bằng 0
  | 'trong' // không có dữ liệu — chưa chấm, hoặc chưa tới ngày
  | 'chu_nhat'
  | 'tuong_lai'

export type ONgay = {
  ngay: string
  loai: LoaiO
  /** Số công của ô, đã làm tròn 2 chữ số y như engine lương. */
  cong: number
  /** Giờ ngoài giờ, nếu có. */
  gioOt: number
  /** Ô này do người khác KHAI HỘ, không phải người lao động tự bấm. */
  khaiHo: boolean
  /** Tổ đội: phiên của ngày ấy chưa được duyệt. */
  chuaDuyet: boolean
}

export type DongBangCong = {
  employeeId: string
  ma: string
  ten: string
  o: ONgay[]
  tongCong: number
  tongGioOt: number
  tongThuong: number
}

export type BangCongThang = {
  ngay: string[]
  dong: DongBangCong[]
  /** Số người CÓ công trong từng ngày, cùng thứ tự với `ngay`. */
  coMat: number[]
  donVi: 'gio' | 'cong'
}

/**
 * Ô trống của một ngày, phân biệt ba thứ trông giống nhau.
 *
 * Ngày chưa tới, chủ nhật, và ngày nghỉ thật đều là ô không có công. Vẽ chúng
 * giống nhau là buộc tội một người nghỉ vào ngày chưa xảy ra.
 */
function oTrong(ngay: string, homNay: string): ONgay {
  const loai: LoaiO = ngay > homNay ? 'tuong_lai' : laChuNhat(ngay) ? 'chu_nhat' : 'trong'
  return { ngay, loai, cong: 0, gioOt: 0, khaiHo: false, chuaDuyet: false }
}

/** Hôm nay theo giờ Việt Nam, dạng yyyy-mm-dd. */
function homNayVN(): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Ho_Chi_Minh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date())
}

function gopCoMat(dong: DongBangCong[], soNgay: number): number[] {
  return Array.from({ length: soNgay }, (_, i) =>
    dong.reduce((t, d) => t + ((d.o[i]?.cong ?? 0) > 0 ? 1 : 0), 0),
  )
}

/**
 * Bảng công tháng của NHÂN VIÊN CHÍNH THỨC một công ty.
 *
 * Công tính từ giờ: `worked_minutes ÷ phút chuẩn một ngày`. Cùng công thức mà
 * engine lương dùng, nên con số trên bảng này là con số sẽ nhân với lương.
 */
export async function bangCongCongTy(
  companyId: string,
  nam: number,
  thang: number,
  ca: CaChuan,
): Promise<BangCongThang> {
  const supabase = await createClient()
  const ngay = ngayTrongThang(nam, thang)
  const dauThang = ngay[0]!
  const cuoiThang = ngay[ngay.length - 1]!
  const homNay = homNayVN()
  const phutChuan = phutChuanMotNgay(ca)

  const { data: nhanSu } = await supabase
    .from('employees')
    .select('id, employee_code, full_name')
    .eq('company_id', companyId)
    .is('deleted_at', null)
    .in('status', ['chinh_thuc', 'thu_viec'])
    .order('full_name')

  const ids = (nhanSu ?? []).map((e) => e.id)
  if (ids.length === 0) {
    return { ngay, dong: [], coMat: ngay.map(() => 0), donVi: 'gio' }
  }

  const [{ data: ngayCong }, { data: logBu }] = await Promise.all([
    supabase
      .from('attendance_days')
      .select('employee_id, work_date, worked_minutes, ot_minutes')
      .in('employee_id', ids)
      .gte('work_date', dauThang)
      .lte('work_date', cuoiThang),
    // Ngày nào là công KHAI HỘ. Bảng tháng là chỗ dễ thấy nhất một người có
    // bất thường nhiều ngày khai hộ — nên nó phải hiện ra, không lẫn vào công
    // do chính người ấy bấm.
    supabase
      .from('attendance_logs')
      .select('employee_id, logged_at')
      .in('employee_id', ids)
      .is('deleted_at', null)
      .eq('la_cham_bu', true)
      .gte('logged_at', `${dauThang}T00:00:00+07:00`)
      .lte('logged_at', `${cuoiThang}T23:59:59+07:00`),
  ])

  const theoNgay = new Map<string, { phut: number; ot: number }>()
  for (const d of ngayCong ?? []) {
    theoNgay.set(`${d.employee_id}|${d.work_date}`, {
      phut: d.worked_minutes ?? 0,
      ot: d.ot_minutes ?? 0,
    })
  }

  const khaiHo = new Set<string>()
  for (const l of logBu ?? []) {
    const n = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Asia/Ho_Chi_Minh',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).format(new Date(l.logged_at))
    khaiHo.add(`${l.employee_id}|${n}`)
  }

  const dong: DongBangCong[] = (nhanSu ?? []).map((e) => {
    let tongCong = 0
    let tongGioOt = 0

    const o = ngay.map((n): ONgay => {
      const co = theoNgay.get(`${e.id}|${n}`)
      if (!co) return oTrong(n, homNay)

      const cong = congTuPhut(co.phut, phutChuan)
      const gioOt = Math.round((co.ot / 60) * 100) / 100
      tongCong += cong
      tongGioOt += gioOt

      return {
        ngay: n,
        loai: cong === 0 ? 'nghi' : cong >= 1 ? 'du_cong' : 'nua_cong',
        cong,
        gioOt,
        khaiHo: khaiHo.has(`${e.id}|${n}`),
        chuaDuyet: false,
      }
    })

    return {
      employeeId: e.id,
      ma: e.employee_code,
      ten: e.full_name,
      o,
      tongCong: Math.round(tongCong * 100) / 100,
      tongGioOt: Math.round(tongGioOt * 100) / 100,
      tongThuong: 0,
    }
  })

  return { ngay, dong, coMat: gopCoMat(dong, ngay.length), donVi: 'gio' }
}

/**
 * Bảng công tháng của một TỔ ĐỘI công nhật.
 *
 * Đơn vị lấy theo dữ liệu, không theo cột cấu hình — đúng quy tắc chốt
 * 24/08/2026: có `so_cong` là khoán ngày, không có là chấm theo ca.
 */
export async function bangCongToDoi(
  toDoiId: string,
  nam: number,
  thang: number,
): Promise<BangCongThang> {
  const supabase = await createClient()
  const ngay = ngayTrongThang(nam, thang)
  const dauThang = ngay[0]!
  const cuoiThang = ngay[ngay.length - 1]!
  const homNay = homNayVN()

  const { data: thanhVien } = await supabase
    .from('to_doi_thanh_vien')
    .select('employee_id, employees ( employee_code, full_name )')
    .eq('to_doi_id', toDoiId)
    .lte('tu_ngay', cuoiThang)
    .or(`den_ngay.is.null,den_ngay.gte.${dauThang}`)

  const { data: phien } = await supabase
    .from('phien_cham_cong_to')
    .select('id, work_date, da_duyet')
    .eq('to_doi_id', toDoiId)
    .gte('work_date', dauThang)
    .lte('work_date', cuoiThang)

  const duyetTheoPhien = new Map((phien ?? []).map((p) => [p.id, p.da_duyet]))
  const idPhien = (phien ?? []).map((p) => p.id)

  const { data: cong } = idPhien.length
    ? await supabase
        .from('cham_cong_cong_nhat')
        .select('phien_id, employee_id, work_date, so_cong, so_gio, so_gio_ot, thuong')
        .in('phien_id', idPhien)
    : { data: [] }

  // Đơn vị của cả bảng: có bất kỳ dòng nào khai `so_cong` thì bảng đọc theo
  // công, không thì theo giờ. Trộn hai đơn vị trong một cột là con số vô nghĩa.
  const coKhoanNgay = (cong ?? []).some((c) => c.so_cong !== null)
  const donVi: 'gio' | 'cong' = coKhoanNgay ? 'cong' : 'gio'

  const theoNgay = new Map<
    string,
    { luong: number; ot: number; thuong: number; chuaDuyet: boolean }
  >()
  for (const c of cong ?? []) {
    theoNgay.set(`${c.employee_id}|${c.work_date}`, {
      luong: Number(coKhoanNgay ? (c.so_cong ?? 0) : (c.so_gio ?? 0)),
      ot: Number(c.so_gio_ot ?? 0),
      thuong: Number(c.thuong ?? 0),
      chuaDuyet: duyetTheoPhien.get(c.phien_id) === false,
    })
  }

  const dong: DongBangCong[] = (thanhVien ?? []).map((tv) => {
    const e = tv.employees as { employee_code?: string; full_name?: string } | null
    let tongCong = 0
    let tongGioOt = 0
    let tongThuong = 0

    const o = ngay.map((n): ONgay => {
      const co = theoNgay.get(`${tv.employee_id}|${n}`)
      if (!co) return oTrong(n, homNay)

      tongCong += co.luong
      tongGioOt += co.ot
      tongThuong += co.thuong

      return {
        ngay: n,
        loai: co.luong === 0 ? 'nghi' : donVi === 'cong' && co.luong < 1 ? 'nua_cong' : 'du_cong',
        cong: co.luong,
        gioOt: co.ot,
        khaiHo: false,
        chuaDuyet: co.chuaDuyet,
      }
    })

    return {
      employeeId: tv.employee_id,
      ma: e?.employee_code ?? '—',
      ten: e?.full_name ?? '(không rõ)',
      o,
      tongCong: Math.round(tongCong * 100) / 100,
      tongGioOt: Math.round(tongGioOt * 100) / 100,
      tongThuong: tongThuong,
    }
  })

  dong.sort((a, b) => a.ten.localeCompare(b.ten, 'vi'))
  return { ngay, dong, coMat: gopCoMat(dong, ngay.length), donVi }
}
