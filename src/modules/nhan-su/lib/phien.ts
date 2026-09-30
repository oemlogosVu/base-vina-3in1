import { cache } from 'react'
import { redirect } from 'next/navigation'
import { createClient } from '@ns/lib/supabase/server'
import { duocVaoTab, timTab, MO_TA_QUYEN, type KhoaQuyen, type KhoaTab } from '@ns/lib/tabs'
import type { UserRole } from '@ns/types/database'

/**
 * Phiên làm việc: người đang đăng nhập là ai, vai trò gì, gắn với hồ sơ nào.
 *
 * Đây là tiện ích cho UI (ẩn/hiện menu, chuyển hướng cho đúng), KHÔNG phải
 * lớp bảo mật. Lớp bảo mật thật là RLS trong Postgres — kể cả khi ai đó gọi
 * thẳng PostgREST và bỏ qua toàn bộ code này, họ vẫn không đọc được dữ liệu
 * ngoài quyền của mình.
 */
export type Phien = {
  userId: string
  fullName: string
  role: UserRole
  employeeId: string | null
  /**
   * Tab admin đã khai cho CHÍNH NGƯỜI NÀY, tại Quản trị → Người dùng (P0c).
   *
   * NULL = chưa cấu hình, dùng nguyên quyền theo vai trò và chức danh. Mảng
   * rỗng = chỉ còn tab bắt buộc. Trước 24/08/2026 cấu hình này nằm ở chức
   * danh; chuyển sang từng người vì hai người cùng chức danh vẫn có thể cần
   * hai bộ màn hình khác nhau.
   */
  tabsRieng: string[] | null
  /**
   * Quyền của người này, ĐỌC THẲNG từ cột sinh `app_users.quyen` (P0d).
   *
   * Không tự tính lại ở đây, và đó là điểm quan trọng: database sinh cột này
   * từ ô tick tab qua `quyen_tu_tab()`, nên đọc thẳng là chắc chắn khớp với
   * thứ RLS đang dùng. Mọi bản trước tính lại ở tầng ứng dụng, và tính lại là
   * mở đường cho hai bên lệch nhau.
   */
  quyen: KhoaQuyen[]
  /**
   * Được tự lập tổ đội công nhật và thêm nhân công (P5c).
   *
   * Đây là cờ ĐIỀU HƯỚNG cho giao diện. Lớp chặn thật là hàm
   * `la_quan_ly_to_doi()` ở database, và nó còn đòi thêm điều kiện nhân viên
   * chính thức đang đóng bảo hiểm mà cờ này không nói tới.
   */
  quanLyToDoi: boolean
}

/**
 * NULL khi chưa đăng nhập, hoặc tài khoản chưa được admin kích hoạt.
 *
 * Bọc trong `cache()` của React: một lần render trang gọi hàm này bao nhiêu
 * lần cũng chỉ chạy MỘT lần. Trước khi bọc, trang chủ gọi `getUser()` hai
 * lần và mỗi lần là một vòng mạng tới Supabase — thừa hẳn một vòng.
 *
 * Bộ nhớ đệm chỉ sống trong đúng một request, không rò rỉ phiên của người
 * này sang người khác. Đây là điểm khác nhau quan trọng giữa `cache()` của
 * React và bộ nhớ đệm ở tầng ứng dụng.
 */
/**
 * Lọc chuỗi từ database về đúng `KhoaQuyen`.
 *
 * Không nhận thẳng: một giá trị lạ — do bản sau thêm quyền ở database mà quên
 * sửa file này — sẽ bị bỏ qua thay vì lọt vào type như một lời nói dối. Bỏ qua
 * ở đây chỉ mất một mục menu; nhận bừa thì giao diện khẳng định một quyền mà
 * nó không hiểu.
 */
function locQuyen(tho: string[] | null): KhoaQuyen[] {
  const hopLe = new Set<string>(Object.keys(MO_TA_QUYEN))
  return (tho ?? []).filter((q): q is KhoaQuyen => hopLe.has(q))
}

export const layPhien = cache(async function layPhien(): Promise<Phien | null> {
  const supabase = await createClient()

  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) return null

  // Tất cả nằm trên một dòng `app_users` từ P0d — không còn nối sang chức danh
  // nữa, nên truy vấn này nay phẳng và rẻ hơn hẳn.
  const { data, error } = await supabase
    .from('app_users')
    .select('full_name, role, employee_id, is_active, quan_ly_to_doi, tabs, quyen')
    .eq('id', user.id)
    .maybeSingle()

  if (error) {
    // Không nuốt lỗi im lặng (AGENTS.md mục 4): màn hình trống khiến người
    // dùng tưởng mình không có dữ liệu, trong khi thực ra hệ thống đang hỏng.
    throw new Error(`Không đọc được hồ sơ tài khoản: ${error.message}`)
  }
  if (!data || !data.is_active) return null

  return {
    userId: user.id,
    fullName: data.full_name,
    role: data.role,
    employeeId: data.employee_id,
    tabsRieng: data.tabs,
    quyen: locQuyen(data.quyen),
    quanLyToDoi: data.quan_ly_to_doi ?? false,
  }
})

/**
 * Bắt buộc phiên hợp lệ VÀ được vào tab này.
 *
 * Chặn cả khi người dùng gõ thẳng URL, không chỉ ẩn khỏi menu. Nhưng vẫn nhắc
 * lại: đây là lớp điều hướng, không phải lớp bảo mật — RLS mới là thứ quyết
 * định họ đọc được dữ liệu gì.
 *
 * Không được vào thì đẩy về `/nhan-su/ho-so-cua-toi`: đó là tab bắt buộc, ai cũng vào được,
 * nên không bao giờ tạo vòng lặp chuyển hướng.
 */
export async function batBuocTab(khoa: KhoaTab): Promise<Phien> {
  const phien = await batBuocPhien()
  if (!duocVaoTab(phien.role, phien.tabsRieng, khoa)) {
    redirect(timTab('ho-so').duongDan)
  }
  return phien
}

/** Bắt buộc có phiên hợp lệ. Tài khoản chưa kích hoạt bị đẩy về `/` để thấy thông báo. */
export async function batBuocPhien(): Promise<Phien> {
  const phien = await layPhien()
  if (!phien) redirect('/')
  return phien
}

/** Bắt buộc phiên hợp lệ VÀ thuộc một trong các vai trò cho phép. */
export async function batBuocVaiTro(...vaiTroChoPhep: UserRole[]): Promise<Phien> {
  const phien = await batBuocPhien()
  if (!vaiTroChoPhep.includes(phien.role)) redirect('/nhan-su/ho-so-cua-toi')
  return phien
}

/**
 * Một CỔNG QUYỀN: hoặc thuộc một trong các vai trò, hoặc giữ một trong các
 * quyền theo chức danh.
 *
 * `batBuocVaiTro()` không đủ từ P1d: quyền gán theo chức danh nằm ngoài cột
 * `app_users.role`, nên một người được cấp quyền qua chức danh vẫn bị đẩy về
 * `/nhan-su/ho-so-cua-toi` dù RLS đã cho họ đi qua. Suốt từ P1d tới 24/08/2026 ba quyền của
 * bản ấy đúng là như vậy: RLS mở, giao diện đóng.
 *
 * Mỗi cổng phải khớp với ĐÚNG MỘT hàm phân quyền ở database — hằng số bên
 * dưới ghi rõ hàm nào. Lệch nhau thì hoặc người dùng thấy màn hình rồi bị RLS
 * chặn, hoặc có quyền mà không có đường vào; cả hai đều là lỗi của phía này,
 * không phải của RLS.
 */
export type CongQuyen = { vaiTro: UserRole[]; quyen: KhoaQuyen[] }

/** Người này qua được cổng không. Dùng để ẩn/hiện nút, không phải để chặn. */
export function quaCong(phien: Phien, cong: CongQuyen): boolean {
  return (
    cong.vaiTro.includes(phien.role) ||
    cong.quyen.some((q) => phien.quyen.includes(q))
  )
}

/** Bắt buộc phiên hợp lệ VÀ qua được cổng. Không qua thì đẩy về `/nhan-su/ho-so-cua-toi`. */
export async function batBuocCong(cong: CongQuyen): Promise<Phien> {
  const phien = await batBuocPhien()
  if (!quaCong(phien, cong)) redirect('/nhan-su/ho-so-cua-toi')
  return phien
}

/** Vai trò được vào màn quản lý nhân sự. Nhân viên thường chỉ xem hồ sơ mình. */
export const VAI_TRO_XEM_NHAN_SU: UserRole[] = ['truong_phong', 'hr', 'ke_toan', 'admin']

/**
 * Vai trò được thêm/sửa hồ sơ nhân sự.
 *
 * Từ 24/08/2026 (P1f) chỉ còn `admin`: quyền ấy nay đi theo CHỨC DANH, không
 * theo vai trò. Ai cần làm hồ sơ thì admin gán chức danh mang quyền
 * `quan_ly_nhan_su` — xem `CONG_SUA_NHAN_SU`.
 */
export const VAI_TRO_SUA_NHAN_SU: UserRole[] = ['admin']

/**
 * Vai trò được xác nhận chấm công.
 *
 * Từ 11/08/2026 MỌI lần chấm đều phải được xác nhận mới tính công, không chỉ
 * những lần bất thường. Trưởng phòng xem được chấm công của phòng mình nhưng
 * KHÔNG xác nhận: một đầu mối duy nhất chịu trách nhiệm về công.
 *
 * Phải khớp với `can_manage_attendance()` trong database — đây chỉ là bản sao
 * cho UI, lớp chặn thật nằm ở RLS. Từ P1f chỉ còn `admin`; đường còn lại là
 * chức danh mang quyền `xac_nhan_cham_cong`.
 */
export const VAI_TRO_XAC_NHAN_CHAM_CONG: UserRole[] = ['admin']

/**
 * Vai trò được tạo kỳ lương, bấm tính và chốt kỳ.
 *
 * Từ P1f chỉ còn `admin`. Đường còn lại là chức danh mang quyền `tinh_luong` —
 * "trưởng phòng kế toán" theo cách gọi của Triệu Vũ. Phải khớp với
 * `can_manage_payroll()` trong database.
 */
export const VAI_TRO_QUAN_LY_LUONG: UserRole[] = ['admin']

/* -------------------------------------------------------------------------
 * Bốn cổng quyền — NGUỒN DUY NHẤT cho mọi màn hình và server action.
 *
 * Mỗi cổng đứng cạnh tên hàm phân quyền tương ứng ở database. Khi sửa một
 * bên, mở bên kia ra đọc: hai bên lệch nhau là kiểu hỏng lặng lẽ nhất của hệ
 * thống này — người dùng thấy nút, bấm vào thì RLS chặn, và không ai biết
 * lỗi nằm ở đâu.
 * ------------------------------------------------------------------------- */

/** Thêm/sửa hồ sơ nhân sự, hợp đồng, người phụ thuộc. ↔ `is_hr_or_admin()`. */
export const CONG_SUA_NHAN_SU: CongQuyen = {
  vaiTro: VAI_TRO_SUA_NHAN_SU,
  quyen: ['quan_ly_nhan_su'],
}

/** Xác nhận chấm công hằng ngày. ↔ `can_manage_attendance()`. */
export const CONG_XAC_NHAN_CHAM_CONG: CongQuyen = {
  vaiTro: VAI_TRO_XAC_NHAN_CHAM_CONG,
  quyen: ['xac_nhan_cham_cong'],
}

/**
 * ĐỌC dữ liệu lương của người khác — bảng lương, bảng thanh toán tổ đội.
 * ↔ `can_read_payroll()`.
 *
 * Hẹp nhất trong các cổng. Từ 24/08/2026 (P1f) CỐ Ý không có
 * `quan_ly_nhan_su`: Triệu Vũ tách bạch "trưởng phòng xem thông tin nhân sự"
 * với "trưởng phòng kế toán tính lương". Làm hồ sơ không cần biết thực nhận
 * của từng người (NĐ 13/2023, truy cập tối thiểu).
 */
export const CONG_DOC_LUONG: CongQuyen = {
  vaiTro: ['admin'],
  // Nhận cả `xem_luong` từ P0d: tick tab "Báo cáo lương" là được ĐỌC lương
  // toàn công ty, nhưng không chốt được kỳ. Cổng chốt kỳ ở dưới chỉ nhận
  // `tinh_luong`.
  quyen: ['tinh_luong', 'xem_luong'],
}

/** Tạo kỳ lương, bấm tính, chốt kỳ. ↔ `can_manage_payroll()`. */
export const CONG_QUAN_LY_LUONG: CongQuyen = {
  vaiTro: VAI_TRO_QUAN_LY_LUONG,
  quyen: ['tinh_luong'],
}

/**
 * Chấm bù, xoá lần chấm sai, mở lại phiên tổ đội. ↔ `duoc_sua_chua_cong()`.
 *
 * CỐ Ý tách khỏi `CONG_XAC_NHAN_CHAM_CONG`. Xác nhận là nói "đúng rồi" về một
 * lần chấm CÓ THẬT; sửa chữa là tạo ra một lần chấm chưa từng xảy ra. Người
 * xác nhận sai thì công lệch một chút; người sửa chữa sai thì có công khống.
 */
export const CONG_SUA_CHUA_CONG: CongQuyen = {
  vaiTro: ['admin'],
  quyen: ['sua_chua_cong'],
}

/**
 * Duyệt và mở lại phiên chấm công tổ đội. ↔ `duoc_duyet_cong_to()`.
 *
 * "Người chấm công sẽ là người duyệt công hoặc cấp trưởng phòng" — Triệu Vũ,
 * 24/08/2026. NGƯỜI CHẤM của chính tổ ấy đi bằng policy riêng ở database
 * (`phien_duyet_boi_nguoi_cham`), không qua cổng này.
 *
 * Database còn chặn thêm hai việc mà cổng này không nói tới: duyệt bằng tên
 * người khác, và người CÓ TÊN TRONG TỔ duyệt công của tổ mình.
 */
export const CONG_DUYET_CONG_TO: CongQuyen = {
  vaiTro: ['truong_phong', 'admin'],
  quyen: ['duyet_cong'],
}
