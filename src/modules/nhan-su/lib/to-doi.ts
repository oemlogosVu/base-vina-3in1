import { createClient } from '@ns/lib/supabase/server'
import { CONG_SUA_NHAN_SU, quaCong, type Phien } from '@ns/lib/phien'
import { ngayHomNayVN } from '@ns/lib/dinh-dang'
import { gioGon, type KhungGioCongTy } from '@ns/lib/gio-chuan'

/**
 * Đọc dữ liệu tổ đội thuê công nhật.
 *
 * Mọi truy vấn ở đây đi qua client của NGƯỜI DÙNG, nên RLS lọc sẵn: người
 * được giao chấm công chỉ thấy tổ của mình, HR/kế toán/admin thấy tất cả.
 * Không hàm nào trong file này dùng service_role — chỗ duy nhất cần quyền đó
 * là Edge Function ghi ảnh.
 */

export type ToDoiRut = {
  id: string
  code: string
  name: string
  is_active: boolean
  company_id: string
  companies: { code: string; name: string } | null
  departments: { code: string; name: string } | null
}

const COT_TO_DOI =
  'id, code, name, is_active, company_id, companies ( code, name ), departments ( code, name )'

/**
 * Tổ mà người đang đăng nhập được giao chấm công.
 *
 * Lọc bằng phép nối `!inner` chứ không lọc sau: một người phụ trách nhiều tổ
 * và một tổ có nhiều người chấm, nên quan hệ nằm ở bảng gán. RLS vẫn là lớp
 * quyết định — câu này chỉ thu hẹp cho đúng việc của màn hình.
 */
export async function layToDoiToiCham(userId: string): Promise<ToDoiRut[]> {
  const supabase = await createClient()
  const { data, error } = await supabase
    .from('to_doi')
    .select(`${COT_TO_DOI}, to_doi_nguoi_cham!inner ( app_user_id )`)
    .eq('to_doi_nguoi_cham.app_user_id', userId)
    .eq('is_active', true)
    .order('code')

  if (error) throw new Error(`Không đọc được danh sách tổ: ${error.message}`)
  return (data ?? []) as unknown as ToDoiRut[]
}

/**
 * Người này có việc để làm ở màn Tổ đội & nhân công không.
 *
 * NGUỒN DUY NHẤT của câu hỏi ấy. Ba màn của tab dùng chung nó: `/nhan-su/to-doi/quan-ly`
 * để quyết định cho vào hay đá về, hai màn kia để quyết định có hiện đường dẫn
 * sang. Trước 29/08/2026 mỗi chỗ tự viết một điều kiện, và ba điều kiện lệch
 * nhau: người mang quyền `quan_ly_nhan_su` thấy đường dẫn mà vào thì bị đá,
 * người chấm của một tổ vào được mà không thấy đường nào.
 *
 * Bốn vế, theo đúng thứ tự rẻ trước đắt sau:
 *   - admin;
 *   - quyền `quan_ly_nhan_su` — khớp `is_hr_or_admin()`, cổng RLS dùng cho mọi
 *     lệnh ghi trên tổ;
 *   - cờ `quan_ly_to_doi` — người tự lập tổ ngoài công trường;
 *   - là người chấm của ít nhất một tổ — khớp `la_nguoi_cham_cong_to()`, và chỉ
 *     vế này mới tốn một vòng mạng.
 *
 * Vẫn là câu hỏi ĐIỀU HƯỚNG. RLS mới quyết định họ đọc/ghi được gì.
 */
export async function duocVaoQuanLyToDoi(phien: Phien): Promise<boolean> {
  if (phien.role === 'admin') return true
  if (quaCong(phien, CONG_SUA_NHAN_SU)) return true
  if (phien.quanLyToDoi) return true
  return (await layToDoiToiCham(phien.userId)).length > 0
}

export type NguoiChamRut = {
  id: string
  to_doi_id: string
  app_user_id: string
  app_users: { full_name: string; role: string } | null
}

/** Ai đang được giao chấm công, cho mọi tổ. Dùng ở màn quản trị. */
export async function layMoiNguoiCham(): Promise<NguoiChamRut[]> {
  const supabase = await createClient()
  const { data, error } = await supabase
    .from('to_doi_nguoi_cham')
    .select('id, to_doi_id, app_user_id, app_users ( full_name, role )')

  if (error) throw new Error(`Không đọc được người chấm công: ${error.message}`)
  return (data ?? []) as unknown as NguoiChamRut[]
}

export type UngVienQuanLyTo = {
  id: string
  full_name: string
  role: string
  duDieuKien: boolean
  /** Câu nói THIẾU GÌ, hoặc null khi đủ điều kiện. */
  thieu: string | null
}

/**
 * Mọi tài khoản đang hoạt động, kèm câu trả lời "người này đủ điều kiện làm
 * quản lý tổ đội chưa, và nếu chưa thì thiếu gì".
 *
 * Ba vế của điều kiện giống hệt hàm `la_nhan_vien_chinh_thuc()` ở database:
 * tài khoản còn hiệu lực, hồ sơ `chinh_thuc` chưa bị xoá, và có hợp đồng đang
 * hiệu lực với mức đóng bảo hiểm > 0. Đây là bản sao cho GIAO DIỆN; lớp chặn
 * thật vẫn là trigger ở database, và nếu hai chỗ lệch thì chỗ sai là chỗ này.
 *
 * VÌ SAO KHÔNG LỌC SẴN BẰNG `!inner` NHƯ BẢN TRƯỚC: bản trước hỏi database
 * "ai đủ điều kiện" và nhận về danh sách rỗng, nên màn hình chỉ nói được đúng
 * một câu — "chưa tài khoản nào đủ điều kiện" — mà không nói được ai thiếu gì.
 * Triệu Vũ mở màn Tổ đội ngày 22/08 và kết luận là **chưa có mục chỉ định
 * người quản lý tổ đội**, trong khi mục đó vẫn ở đó, chỉ là rỗng. Một danh
 * sách rỗng và một tính năng chưa làm trông giống hệt nhau.
 *
 * Nên câu truy vấn nay lấy VỀ tất cả rồi tự xét từng người, để mỗi dòng nói
 * được lý do của chính nó.
 */
export async function layUngVienQuanLyTo(): Promise<UngVienQuanLyTo[]> {
  const supabase = await createClient()
  const { data, error } = await supabase
    .from('app_users')
    .select(
      'id, full_name, role, employee_id, employees ( status, deleted_at, labor_contracts ( is_active, muc_luong_hop_dong ( tu_ngay, bhxh_salary ) ) )',
    )
    .eq('is_active', true)
    .order('full_name')

  if (error) throw new Error(`Không đọc được danh sách tài khoản: ${error.message}`)

  type MucLuong = { tu_ngay: string; bhxh_salary: number }
  type Nhung = {
    status: string
    deleted_at: string | null
    labor_contracts: { is_active: boolean; muc_luong_hop_dong: MucLuong[] }[]
  } | null

  const homNay = ngayHomNayVN()

  /**
   * Mức BHXH đang áp dụng HÔM NAY của một hợp đồng — chép đúng luật của
   * `luong_bhxh_tai_ngay()` ở database: lấy mức có `tu_ngay` gần nhất mà chưa
   * quá hôm nay; chưa có mức nào tới hạn thì lùi về mức sớm nhất.
   *
   * Bản trước hỏi "có mức nào > 0 không", không xét ngày hiệu lực. Một hợp
   * đồng có mức hiện hành bằng 0 và một mức sang năm mới khác 0 thì màn hình
   * xếp người ấy vào nhóm ĐỦ ĐIỀU KIỆN, admin bật cờ, rồi RLS vẫn trả rỗng —
   * người kia vào màn thấy trắng và không chỗ nào nói vì sao. Hai bên phải
   * cùng một luật, không phải hai luật gần giống.
   */
  const bhxhHomNay = (muc: MucLuong[]): number => {
    if (muc.length === 0) return 0
    const theoNgay = [...muc].sort((a, b) => a.tu_ngay.localeCompare(b.tu_ngay))
    const daToiHan = theoNgay.filter((m) => m.tu_ngay <= homNay)
    const chon = daToiHan.at(-1) ?? theoNgay[0]
    return chon ? Number(chon.bhxh_salary) : 0
  }

  return (data ?? []).map((u) => {
    const nv = u.employees as unknown as Nhung
    const thieu = ((): string | null => {
      if (!u.employee_id || !nv) return 'chưa nối với hồ sơ nhân sự'
      if (nv.deleted_at !== null) return 'hồ sơ nhân sự đã bị xoá'
      if (nv.status !== 'chinh_thuc') return 'hồ sơ chưa ở trạng thái chính thức'

      const hopDong = (nv.labor_contracts ?? []).filter((h) => h.is_active)
      if (hopDong.length === 0) return 'chưa có hợp đồng lao động đang hiệu lực'

      const coBaoHiem = hopDong.some((h) => bhxhHomNay(h.muc_luong_hop_dong ?? []) > 0)
      if (!coBaoHiem) return 'hợp đồng chưa khai mức đóng bảo hiểm đang áp dụng hôm nay'

      return null
    })()

    return {
      id: u.id,
      full_name: u.full_name,
      role: u.role,
      duDieuKien: thieu === null,
      thieu,
    }
  })
}

/** Toàn bộ tổ — RLS trả rỗng cho người không có quyền quản lý. */
export async function layMoiToDoi(): Promise<ToDoiRut[]> {
  const supabase = await createClient()
  const { data, error } = await supabase.from('to_doi').select(COT_TO_DOI).order('code')
  if (error) throw new Error(`Không đọc được danh sách tổ: ${error.message}`)
  return (data ?? []) as ToDoiRut[]
}

export type CaCongTyRut = {
  ma: 'sang' | 'chieu' | 'toi'
  nhan: string
  /** Giờ MẶC ĐỊNH của công ty. Tổ trưởng sửa được cho từng người (P5f). */
  bd: string
  kt: string
}

/**
 * Ba ca mặc định và khung giờ chuẩn của một công ty.
 *
 * Từ P5f (24/08/2026) giờ của ca chỉ còn là **giá trị mặc định** rót vào ô khi
 * tổ trưởng bấm chọn ca; giờ thật nằm trên từng dòng công của từng người. Nên
 * hàm này không hỏi database số giờ của ca nữa — số giờ tính từ giờ THẬT, và
 * tính ở đâu thì xem `gioTuKhoang()` (màn hình) và
 * `gio_cong_nhat_tu_khoang()` (database, bên quyết định).
 *
 * `khung` là NULL khi công ty chưa khai khung giờ chuẩn — màn hình phải nói ra
 * điều đó chứ không hiện một lưới chấm được mà lưu không được.
 */
export async function layCaCuaCongTy(companyId: string): Promise<{
  khung: KhungGioCongTy | null
  ca: CaCongTyRut[]
}> {
  const supabase = await createClient()

  const [{ data: cty, error: loiCty }, { data: ca, error: loiCa }] = await Promise.all([
    supabase
      .from('companies')
      .select('gio_vao, gio_ra, nghi_tu, nghi_den')
      .eq('id', companyId)
      .maybeSingle(),
    supabase
      .from('ca_cong_nhat')
      .select('ma, gio_bat_dau, gio_ket_thuc')
      .eq('company_id', companyId)
      .eq('is_active', true),
  ])

  if (loiCty) throw new Error(`Không đọc được khung giờ chuẩn: ${loiCty.message}`)
  if (loiCa) throw new Error(`Không đọc được ca của công ty: ${loiCa.message}`)

  const khung: KhungGioCongTy | null =
    cty?.gio_vao && cty.gio_ra
      ? {
          gioVao: gioGon(cty.gio_vao),
          gioRa: gioGon(cty.gio_ra),
          nghiTu: cty.nghi_tu ? gioGon(cty.nghi_tu) : null,
          nghiDen: cty.nghi_den ? gioGon(cty.nghi_den) : null,
        }
      : null

  const nhan: Record<CaCongTyRut['ma'], string> = {
    sang: 'Sáng',
    chieu: 'Chiều',
    toi: 'Tối',
  }
  const thuTu: CaCongTyRut['ma'][] = ['sang', 'chieu', 'toi']

  const ds = thuTu.flatMap((ma) => {
    const dong = (ca ?? []).find((c) => c.ma === ma)
    if (!dong) return []
    return [
      {
        ma,
        nhan: nhan[ma],
        bd: gioGon(dong.gio_bat_dau),
        kt: gioGon(dong.gio_ket_thuc),
      },
    ]
  })

  return { khung, ca: ds }
}

export type ThanhVienRut = {
  id: string
  employee_id: string
  kieu_tinh: 'ngay' | 'gio'
  /** LỊCH SỬ — tiền một CÔNG, của kiểu khoán ngày đã bỏ ngày 24/08/2026. */
  don_gia_cong: number | null
  don_gia_gio: number | null
  don_gia_ot: number | null
  employees: { employee_code: string; full_name: string } | null
}

/**
 * Thành viên của tổ CÒN HIỆU LỰC tại một ngày.
 *
 * Lọc theo ngày chứ không lấy cả danh sách: người đã rời tổ từ tháng trước
 * không được hiện ra trong lưới chấm công của hôm nay, và bảng công của
 * tháng trước vẫn phải giữ đúng danh sách của tháng trước.
 */
export async function layThanhVienTaiNgay(
  toDoiId: string,
  ngay: string,
): Promise<ThanhVienRut[]> {
  const supabase = await createClient()
  const { data, error } = await supabase
    .from('to_doi_thanh_vien')
    .select(
      'id, employee_id, kieu_tinh, don_gia_cong, don_gia_gio, don_gia_ot, employees ( employee_code, full_name )',
    )
    .eq('to_doi_id', toDoiId)
    .lte('tu_ngay', ngay)
    .or(`den_ngay.is.null,den_ngay.gte.${ngay}`)

  if (error) throw new Error(`Không đọc được thành viên tổ: ${error.message}`)

  const ds = (data ?? []) as unknown as ThanhVienRut[]
  return ds.sort((a, b) =>
    (a.employees?.full_name ?? '').localeCompare(b.employees?.full_name ?? '', 'vi'),
  )
}

export type PhienRut = {
  id: string
  to_doi_id: string
  work_date: string
  anh_path: string | null
  ghi_chu: string | null
  cham_luc: string
  da_duyet: boolean
  duyet_luc: string | null
}

export type DongCongRut = {
  employee_id: string
  /** Giờ vào–giờ ra của RIÊNG người này, từng ca. NULL = không làm ca ấy. */
  ca_sang_tu: string | null
  ca_sang_den: string | null
  ca_chieu_tu: string | null
  ca_chieu_den: string | null
  ca_toi_tu: string | null
  ca_toi_den: string | null
  ngoai_gio_tu: string | null
  ngoai_gio_den: string | null
  thuong: number | null
  thuong_ly_do: string | null
  /** Do trigger tính từ ba cặp giờ — không ai gõ tay hai con số này. */
  so_gio: number | null
  so_gio_ot: number
  /** LỊCH SỬ, chỉ có ở dòng chấm khoán ngày trước 24/08/2026. */
  so_cong: number | null
  ghi_chu: string | null
}

/** Phiên chấm của một tổ trong một ngày, kèm số công đã ghi. NULL = chưa chấm. */
export async function layPhienTheoNgay(
  toDoiId: string,
  ngay: string,
): Promise<{ phien: PhienRut; dong: DongCongRut[] } | null> {
  const supabase = await createClient()
  const { data, error } = await supabase
    .from('phien_cham_cong_to')
    .select('id, to_doi_id, work_date, anh_path, ghi_chu, cham_luc, da_duyet, duyet_luc')
    .eq('to_doi_id', toDoiId)
    .eq('work_date', ngay)
    .maybeSingle()

  if (error) throw new Error(`Không đọc được phiên chấm công: ${error.message}`)
  if (!data) return null

  const { data: dong, error: loiDong } = await supabase
    .from('cham_cong_cong_nhat')
    .select(
      'employee_id, ca_sang_tu, ca_sang_den, ca_chieu_tu, ca_chieu_den, ca_toi_tu, ca_toi_den, ngoai_gio_tu, ngoai_gio_den, thuong, thuong_ly_do, so_gio, so_gio_ot, so_cong, ghi_chu',
    )
    .eq('phien_id', data.id)

  if (loiDong) throw new Error(`Không đọc được số công: ${loiDong.message}`)

  return { phien: data as PhienRut, dong: (dong ?? []) as DongCongRut[] }
}

export type PhienChoDuyet = PhienRut & {
  to_doi: { code: string; name: string } | null
  so_dong: number
  so_nguoi: number
}

/**
 * Phiên chưa duyệt, mới nhất trước. Dành cho người duyệt được công tổ đội:
 * HR/admin, hoặc chức danh mang quyền `duyet_cong` (P1e).
 *
 * Cộng tổng ở tầng ứng dụng thay vì viết view: số phiên chờ duyệt của dưới 50
 * nhân sự là con số nhỏ, và một view nữa là một thứ nữa phải giữ cho khớp khi
 * đổi schema.
 */
export async function layPhienChoDuyet(gioiHan = 60): Promise<PhienChoDuyet[]> {
  const supabase = await createClient()
  const { data, error } = await supabase
    .from('phien_cham_cong_to')
    .select(
      'id, to_doi_id, work_date, anh_path, ghi_chu, cham_luc, da_duyet, duyet_luc, to_doi ( code, name ), cham_cong_cong_nhat ( so_cong, so_gio, so_gio_ot )',
    )
    .eq('da_duyet', false)
    .order('work_date', { ascending: false })
    .limit(gioiHan)

  if (error) throw new Error(`Không đọc được phiên chờ duyệt: ${error.message}`)

  // Đếm theo DÒNG chứ không cộng số công: một tổ có thể vừa có người khoán
  // ngày vừa có người tính giờ, và cộng công với giờ ra một số là cộng hai đơn
  // vị khác nhau.
  return (data ?? []).map((p) => {
    const dong = (p.cham_cong_cong_nhat ?? []) as {
      so_cong: number | null
      so_gio: number | null
      so_gio_ot: number
    }[]
    return {
      ...(p as unknown as PhienRut),
      to_doi: p.to_doi as { code: string; name: string } | null,
      so_dong: dong.length,
      so_nguoi: dong.filter(
        (d) => Number(d.so_cong ?? 0) > 0 || Number(d.so_gio ?? 0) > 0 || Number(d.so_gio_ot) > 0,
      ).length,
    }
  })
}

/**
 * Link xem ảnh chấm công tổ, hết hạn sau 60 giây.
 *
 * Cùng khuôn với `layLinkAnhHangLoat` của chấm công cá nhân, khác bucket.
 * Bucket private nên không có URL cố định nào đọc được; việc cấp link vẫn đi
 * qua policy, người không có quyền nhận null chứ không nhận link hỏng.
 */
export async function layLinkAnhToDoi(
  duongDans: readonly (string | null)[],
): Promise<Map<string, string>> {
  const canLay = [...new Set(duongDans.filter((d): d is string => d !== null))]
  if (canLay.length === 0) return new Map()

  const supabase = await createClient()
  const { data } = await supabase.storage.from('to-doi-cham-cong').createSignedUrls(canLay, 60)

  const ketQua = new Map<string, string>()
  for (const m of data ?? []) {
    if (m.path && m.signedUrl && !m.error) ketQua.set(m.path, m.signedUrl)
  }
  return ketQua
}

/** Nhân sự đủ điều kiện xếp vào tổ: cộng tác viên, chưa thuộc tổ nào đang mở. */
export async function layNhanSuChuaCoTo(): Promise<
  { id: string; employee_code: string; full_name: string }[]
> {
  const supabase = await createClient()

  const [{ data: nhanSu, error }, { data: daCoTo }] = await Promise.all([
    supabase
      .from('employees')
      .select('id, employee_code, full_name')
      .is('deleted_at', null)
      .order('employee_code'),
    supabase.from('to_doi_thanh_vien').select('employee_id').is('den_ngay', null),
  ])

  if (error) throw new Error(`Không đọc được danh sách nhân sự: ${error.message}`)

  const dangCoTo = new Set((daCoTo ?? []).map((r) => r.employee_id))
  return (nhanSu ?? []).filter((n) => !dangCoTo.has(n.id))
}

// =========================================================
// P5b — Bảng thanh toán
// =========================================================

export type BangThanhToanRut = {
  id: string
  to_doi_id: string
  tu_ngay: string
  den_ngay: string
  tao_luc: string
  dong_cho_duyet: number
  ghi_chu: string | null
  to_doi: { code: string; name: string } | null
}

/** Bảng thanh toán đã sinh. RLS lo phạm vi: quản lý chỉ thấy tổ mình. */
export async function layBangThanhToan(toDoiId?: string): Promise<BangThanhToanRut[]> {
  const supabase = await createClient()
  let cau = supabase
    .from('bang_thanh_toan_to')
    .select('id, to_doi_id, tu_ngay, den_ngay, tao_luc, dong_cho_duyet, ghi_chu, to_doi ( code, name )')
    .order('tu_ngay', { ascending: false })

  if (toDoiId) cau = cau.eq('to_doi_id', toDoiId)

  const { data, error } = await cau
  if (error) throw new Error(`Không đọc được bảng thanh toán: ${error.message}`)
  return (data ?? []) as unknown as BangThanhToanRut[]
}

export type DongThanhToanRut = {
  id: string
  employee_id: string
  kieu_tinh: 'ngay' | 'gio'
  so_luong: number
  don_gia: number
  so_gio_ot: number
  don_gia_ot: number
  thuong: number
  thanh_tien: number
  ghi_chu: string | null
  employees: { employee_code: string; full_name: string } | null
}

/** Chi tiết một bảng. Trả null khi RLS không cho đọc — màn hình nói rõ thay vì hiện trống. */
export async function layChiTietBang(
  bangId: string,
): Promise<{ bang: BangThanhToanRut; dong: DongThanhToanRut[] } | null> {
  const supabase = await createClient()

  const { data: bang, error } = await supabase
    .from('bang_thanh_toan_to')
    .select('id, to_doi_id, tu_ngay, den_ngay, tao_luc, dong_cho_duyet, ghi_chu, to_doi ( code, name )')
    .eq('id', bangId)
    .maybeSingle()

  if (error) throw new Error(`Không đọc được bảng thanh toán: ${error.message}`)
  if (!bang) return null

  const { data: dong, error: loiDong } = await supabase
    .from('dong_thanh_toan_to')
    .select(
      'id, employee_id, kieu_tinh, so_luong, don_gia, so_gio_ot, don_gia_ot, thuong, thanh_tien, ghi_chu, employees ( employee_code, full_name )',
    )
    .eq('bang_id', bangId)

  if (loiDong) throw new Error(`Không đọc được dòng thanh toán: ${loiDong.message}`)

  const ds = (dong ?? []) as unknown as DongThanhToanRut[]
  ds.sort((a, b) =>
    (a.employees?.full_name ?? '').localeCompare(b.employees?.full_name ?? '', 'vi'),
  )

  return { bang: bang as unknown as BangThanhToanRut, dong: ds }
}

// =========================================================
// P5j — Sổ sửa tay bảng thanh toán
// =========================================================

export type SuaTayRut = {
  id: string
  employee_id: string
  ten_nhan_cong: string
  truoc: Record<string, number>
  sau: Record<string, number>
  ly_do: string
  nguoi_sua_ten: string
  sua_luc: string
}

/**
 * Lịch sử sửa tay của một bảng, mới nhất trước.
 *
 * Mỗi lần sửa tay đẻ ra một bảng MỚI, nên hỏi sổ theo id bảng đang xem thì
 * chỉ thấy lần sửa cuối. Dòng sổ trỏ tới bảng đang xem cho biết GỐC của chuỗi;
 * mọi lần sửa trong chuỗi mang cùng gốc. Bảng chưa sửa lần nào thì không có
 * dòng sổ nào trỏ tới nó.
 */
export async function layLichSuSuaTay(bangId: string): Promise<SuaTayRut[]> {
  const supabase = await createClient()
  const { data: noi, error: loiNoi } = await supabase
    .from('sua_tay_bang_thanh_toan')
    .select('bang_goc_id')
    .eq('bang_moi_id', bangId)
    .limit(1)
    .maybeSingle()

  if (loiNoi) throw new Error(`Không đọc được sổ sửa tay: ${loiNoi.message}`)
  if (!noi) return []

  const { data, error } = await supabase
    .from('sua_tay_bang_thanh_toan')
    .select('id, employee_id, ten_nhan_cong, truoc, sau, ly_do, nguoi_sua_ten, sua_luc')
    .eq('bang_goc_id', noi.bang_goc_id)
    .order('sua_luc', { ascending: false })

  if (error) throw new Error(`Không đọc được sổ sửa tay: ${error.message}`)
  return (data ?? []) as unknown as SuaTayRut[]
}

/** Bảng nào trong danh sách là bản đã sửa tay — để danh sách nói ra điều đó. */
export async function layBangDaSuaTay(ids: string[]): Promise<Set<string>> {
  if (ids.length === 0) return new Set()
  const supabase = await createClient()
  const { data, error } = await supabase
    .from('sua_tay_bang_thanh_toan')
    .select('bang_moi_id')
    .in('bang_moi_id', ids)

  if (error) throw new Error(`Không đọc được sổ sửa tay: ${error.message}`)
  return new Set((data ?? []).map((s) => s.bang_moi_id))
}




/** Chức danh được đánh dấu dùng cho nhân công công nhật. NULL = chưa ai tích. */
export async function layChucDanhCongNhat(): Promise<{ id: string; name: string } | null> {
  const supabase = await createClient()
  const { data } = await supabase
    .from('positions')
    .select('id, name')
    .eq('la_cong_nhat', true)
    .maybeSingle()
  return data ?? null
}

/**
 * Tài khoản đang được bật cờ quản lý tổ đội.
 *
 * Tách khỏi `layUngVienQuanLyTo` vì hai câu hỏi khác nhau: ai ĐỦ TƯ CÁCH
 * được giao, và ai ĐANG ĐƯỢC giao. Trộn hai thứ là chỗ dễ hiểu nhầm nhất của
 * mọi màn phân quyền.
 */
export async function layTaiKhoanQuanLyToDoi(): Promise<Set<string>> {
  const supabase = await createClient()
  const { data } = await supabase
    .from('app_users')
    .select('id')
    .eq('quan_ly_to_doi', true)
  return new Set((data ?? []).map((u) => u.id))
}
