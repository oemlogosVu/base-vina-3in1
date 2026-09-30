import { createClient } from '@ns/lib/supabase/server'

/**
 * Dữ liệu cho màn Sửa chữa công.
 *
 * Màn này xem theo NHÓM — một tổ đội hoặc một công ty, trong một ngày — chứ
 * không theo từng người. Triệu Vũ, 25/08/2026: *"tôi chọn theo tổ, công ty,
 * ngày hiện bảng để sửa chữa hoặc chấm backdate."*
 *
 * Đổi cách xem này quan trọng hơn nó nghe: hỏi "ai bị sót hôm 20/08" thì phải
 * nhìn cả nhóm mới trả lời được. Bản trước bắt chọn từng người, nghĩa là muốn
 * tìm người bị sót thì phải đoán trước tên họ.
 */

export type DongCongTy = {
  employeeId: string
  ma: string
  ten: string
  /** Các lần chấm còn hiệu lực trong ngày, đã sắp theo giờ. */
  lanCham: { id: string; loai: string; luc: string; laChamBu: boolean }[]
  phutLam: number
}

export type DongToDoi = {
  employeeId: string
  ma: string
  ten: string
  soCong: number | null
  soGio: number | null
  soGioOt: number
  thuong: number
  thuongLyDo: string | null
}

export type PhienTo = {
  id: string
  daDuyet: boolean
  coAnh: boolean
} | null

/**
 * Một ngày của một CÔNG TY: mọi người đang làm, kèm lần chấm của họ.
 *
 * Người KHÔNG có lần chấm nào vẫn có mặt trong danh sách — đó chính là những
 * người cần chấm bù, và một danh sách chỉ hiện người đã chấm thì không trả lời
 * được câu hỏi "ai bị sót".
 */
export async function layNgayTheoCongTy(
  companyId: string,
  ngay: string,
): Promise<DongCongTy[]> {
  const supabase = await createClient()

  const { data: nhanSu } = await supabase
    .from('employees')
    .select('id, employee_code, full_name')
    .eq('company_id', companyId)
    .is('deleted_at', null)
    .in('status', ['chinh_thuc', 'thu_viec'])
    .order('full_name')

  const ids = (nhanSu ?? []).map((e) => e.id)
  if (ids.length === 0) return []

  const [{ data: logs }, { data: ngayCong }] = await Promise.all([
    supabase
      .from('attendance_logs')
      .select('id, employee_id, check_type, logged_at, la_cham_bu')
      .in('employee_id', ids)
      .is('deleted_at', null)
      .gte('logged_at', `${ngay}T00:00:00+07:00`)
      .lt('logged_at', `${ngay}T24:00:00+07:00`)
      .order('logged_at'),
    supabase
      .from('attendance_days')
      .select('employee_id, worked_minutes')
      .in('employee_id', ids)
      .eq('work_date', ngay),
  ])

  const theoNguoi = new Map<string, DongCongTy['lanCham']>()
  for (const l of logs ?? []) {
    const cua = theoNguoi.get(l.employee_id) ?? []
    cua.push({
      id: l.id,
      loai: l.check_type,
      luc: l.logged_at,
      laChamBu: l.la_cham_bu ?? false,
    })
    theoNguoi.set(l.employee_id, cua)
  }
  const phut = new Map((ngayCong ?? []).map((d) => [d.employee_id, d.worked_minutes]))

  return (nhanSu ?? []).map((e) => ({
    employeeId: e.id,
    ma: e.employee_code,
    ten: e.full_name,
    lanCham: theoNguoi.get(e.id) ?? [],
    phutLam: phut.get(e.id) ?? 0,
  }))
}

/**
 * Một ngày của một TỔ ĐỘI: nhân công đang thuộc tổ, kèm số công đã chấm.
 *
 * Chỉ lấy thành viên còn hiệu lực TẠI NGÀY ĐANG XEM, không phải hiệu lực hôm
 * nay: sửa công của tháng trước thì phải thấy đúng đội hình của tháng trước.
 */
export async function layNgayTheoTo(
  toDoiId: string,
  ngay: string,
): Promise<{ phien: PhienTo; dong: DongToDoi[] }> {
  const supabase = await createClient()

  const { data: thanhVien } = await supabase
    .from('to_doi_thanh_vien')
    .select('employee_id, tu_ngay, den_ngay, employees ( employee_code, full_name )')
    .eq('to_doi_id', toDoiId)
    .lte('tu_ngay', ngay)
    .or(`den_ngay.is.null,den_ngay.gte.${ngay}`)

  const { data: ph } = await supabase
    .from('phien_cham_cong_to')
    .select('id, da_duyet, anh_path')
    .eq('to_doi_id', toDoiId)
    .eq('work_date', ngay)
    .maybeSingle()

  const phien: PhienTo = ph
    ? { id: ph.id, daDuyet: ph.da_duyet, coAnh: ph.anh_path !== null }
    : null

  const { data: cong } = phien
    ? await supabase
        .from('cham_cong_cong_nhat')
        .select('employee_id, so_cong, so_gio, so_gio_ot, thuong, thuong_ly_do')
        .eq('phien_id', phien.id)
    : { data: [] }

  const theoNguoi = new Map((cong ?? []).map((c) => [c.employee_id, c]))

  const dong: DongToDoi[] = (thanhVien ?? []).map((tv) => {
    const c = theoNguoi.get(tv.employee_id)
    const e = tv.employees as { employee_code?: string; full_name?: string } | null
    return {
      employeeId: tv.employee_id,
      ma: e?.employee_code ?? '—',
      ten: e?.full_name ?? '(không rõ)',
      soCong: c?.so_cong ?? null,
      soGio: c?.so_gio ?? null,
      soGioOt: Number(c?.so_gio_ot ?? 0),
      thuong: Number(c?.thuong ?? 0),
      thuongLyDo: c?.thuong_ly_do ?? null,
    }
  })

  dong.sort((a, b) => a.ten.localeCompare(b.ten, 'vi'))
  return { phien, dong }
}
