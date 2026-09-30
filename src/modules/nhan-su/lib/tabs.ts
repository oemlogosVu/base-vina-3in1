import type { UserRole } from '@ns/types/database'

/**
 * Danh mục tab của ứng dụng — NGUỒN DUY NHẤT.
 *
 * Menu, việc chặn khi gõ thẳng URL, và màn cấu hình theo chức danh đều đọc từ
 * đây. Trước khi có file này, danh sách tab nằm rải rác trong `khung-trang.tsx`
 * và các hằng số `VAI_TRO_*` — thêm một màn hình là phải nhớ sửa ba chỗ.
 *
 * ⚠️ ĐÂY KHÔNG PHẢI LỚP BẢO MẬT. Lớp bảo vệ thật là RLS ở database. File này
 * quyết định người dùng THẤY và ĐI TỚI được màn nào; nó không quyết định họ
 * ĐỌC được dữ liệu gì. Ai bỏ qua toàn bộ ứng dụng và gọi thẳng PostgREST vẫn
 * bị RLS chặn y như cũ.
 */

export type KhoaTab =
  | 'ho-so'
  | 'cham-cong'
  | 'to-doi'
  | 'cham-cong-xac-nhan'
  | 'sua-chua-cong'
  | 'nhan-su'
  | 'luong'
  | 'luong-ky-luong'
  | 'luong-bao-cao'

export type Tab = {
  khoa: KhoaTab
  nhan: string
  /** Mô tả một câu, dùng cho thẻ ở trang chủ. */
  moTa: string
  duongDan: string
  /** Vai trò được vào. Cấu hình theo chức danh chỉ bớt trong tập này, không mở rộng. */
  vaiTro: UserRole[]
  /**
   * Quyền mà TICK tab này CẤP ở database (P0d, 24/08/2026).
   *
   * Đây là điểm đảo chiều so với mọi bản trước. Trước kia quyền khai riêng ở
   * chức danh rồi *mở* tab; nay ô tick tab *sinh ra* quyền — Triệu Vũ:
   * "admin quyết định ai được xem những tab nào, bỏ luôn phân quyền, vì nếu
   * không xem được tab sẽ không thao tác được trên đó."
   *
   * Bỏ tick là mất quyền thật, không chỉ mất lối đi. Câu trên nay ĐÚNG.
   *
   * ⚠️ Bảng ánh xạ thật nằm ở hàm `quyen_tu_tab()` trong database, và cột
   * `app_users.quyen` là CỘT SINH từ nó. Danh sách ở đây chỉ để hiện chữ cho
   * admin đọc. Hai bên lệch nhau thì bên sai là bên này — và phép kiểm cấu
   * trúc p0 số 31 canh đúng chuyện đó.
   */
  capQuyen?: KhoaQuyen[]
  /**
   * Nhóm menu bên trái. THUẦN HIỂN THỊ — không dính gì tới phân quyền.
   *
   * Sidebar gom tab theo nhóm để mười mục không nằm thành một danh sách
   * phẳng. Thêm trường này ở đây chứ không viết bảng ánh xạ riêng trong
   * component: thêm một tab mới mà quên xếp nhóm thì TypeScript báo ngay,
   * còn bảng ánh xạ rời sẽ lặng lẽ bỏ sót nó.
   */
  nhom: NhomMenu
  /**
   * Tab luôn có, admin không tắt được.
   *
   * "Hồ sơ của tôi" nằm trong nhóm này: nếu đăng nhập được thì phải xem được
   * hồ sơ của chính mình. Không có tab bắt buộc thì một cấu hình sai sẽ đẩy ai
   * đó vào ứng dụng trắng trơn, và đó là một cuộc gọi hỗ trợ chứ không phải
   * một tính năng.
   */
  batBuoc?: boolean
}

/**
 * Nhóm trong thanh điều hướng bên trái, theo thứ tự hiện ra.
 *
 * "Cá nhân" là việc của chính mình; "Quản lý" là việc làm cho người khác;
 * "Lương" tách riêng vì nó là nhóm nhạy cảm nhất và người dùng đi tìm nó như
 * một khu vực, không như một mục lẻ.
 */
export const NHOM_MENU = ['ca-nhan', 'quan-ly', 'luong'] as const
export type NhomMenu = (typeof NHOM_MENU)[number]

export const NHAN_NHOM: Record<NhomMenu, string> = {
  'ca-nhan': 'Cá nhân',
  'quan-ly': 'Quản lý',
  luong: 'Lương',
}

const MOI_VAI_TRO: UserRole[] = ['nhan_vien', 'truong_phong', 'hr', 'ke_toan', 'admin']

export const TABS: readonly Tab[] = [
  {
    khoa: 'ho-so',
    nhom: 'ca-nhan',
    nhan: 'Hồ sơ của tôi',
    moTa: 'Thông tin cá nhân, hợp đồng và người phụ thuộc của bạn.',
    duongDan: '/nhan-su/ho-so-cua-toi',
    vaiTro: MOI_VAI_TRO,
    batBuoc: true,
  },
  {
    khoa: 'cham-cong',
    nhom: 'ca-nhan',
    nhan: 'Chấm công',
    moTa: 'Chấm vào/ra và làm thêm giờ, xem bảng công của bạn.',
    duongDan: '/nhan-su/cham-cong',
    vaiTro: MOI_VAI_TRO,
  },
  {
    khoa: 'nhan-su',
    nhom: 'quan-ly',
    nhan: 'Nhân sự',
    moTa: 'Hồ sơ nhân sự trong phạm vi quyền của bạn.',
    duongDan: '/nhan-su/ho-so',
    // Trưởng phòng vẫn vào được, nhưng CHỈ thấy phòng mình — RLS quyết định,
    // không phải danh sách này. Vai trò `hr` và `ke_toan` rời khỏi đây từ
    // 24/08/2026 (P1f): quyền nay đi theo chức danh.
    vaiTro: ['truong_phong', 'admin'],
    capQuyen: ['quan_ly_nhan_su'],
  },
  {
    khoa: 'to-doi',
    nhom: 'quan-ly',
    nhan: 'Quản lý tổ đội',
    moTa: 'Lập tổ và thêm nhân công, chấm công theo ca, duyệt công, bảng thanh toán.',
    duongDan: '/nhan-su/to-doi',
    // MỌI vai trò: người được giao chấm công thường là tổ trưởng hoặc chỉ huy
    // trưởng, tức tài khoản vai trò `nhan_vien`. Ai chưa được giao tổ nào vào
    // đây sẽ thấy màn nói rõ điều đó — RLS mới là thứ quyết định họ đọc được
    // gì, không phải danh sách này.
    vaiTro: MOI_VAI_TRO,
    // KHÔNG cấp quyền gì. Tab này mở cho mọi vai trò vì người chấm công
    // thường là tài khoản `nhan_vien`; nếu tick nó là cấp luôn quyền duyệt
    // thì mọi người chấm công thành người duyệt công. Quyền `duyet_cong` có ô
    // tick riêng ngay dưới tab này — xem `O_DUYET_CONG`.
    capQuyen: [],
  },
  {
    khoa: 'cham-cong-xac-nhan',
    nhom: 'quan-ly',
    // Đổi nhãn 25/08/2026: tab này nay có hai màn — xác nhận hằng ngày, và
    // bảng công tháng. Giữ nhãn cũ thì người đi tìm bảng tháng không nghĩ tới
    // việc bấm vào "Xác nhận chấm công".
    nhan: 'Chấm công công ty',
    moTa: 'Xác nhận chấm công từng ngày, và xem bảng công cả tháng của công ty hoặc tổ đội.',
    duongDan: '/nhan-su/cham-cong/xac-nhan',
    vaiTro: ['admin'],
    capQuyen: ['xac_nhan_cham_cong'],
  },
  {
    khoa: 'sua-chua-cong',
    nhom: 'quan-ly',
    nhan: 'Sửa chữa công',
    moTa: 'Chấm bù ngày công bị sót, xoá lần chấm sai, mở lại phiên tổ đội đã duyệt.',
    duongDan: '/nhan-su/sua-chua-cong',
    // KHÔNG cho vai trò nào theo mặc định, kể cả trưởng phòng. Đây là quyền
    // TẠO RA công chứ không phải công nhận công có sẵn — nó phải là một lần
    // tick có chủ ý cho đúng một người, không rơi vào ai theo vai trò.
    vaiTro: ['admin'],
    capQuyen: ['sua_chua_cong'],
  },
  {
    khoa: 'luong',
    nhom: 'ca-nhan',
    nhan: 'Phiếu lương',
    moTa: 'Thu nhập, bảo hiểm, thuế TNCN và thực nhận từng kỳ.',
    duongDan: '/nhan-su/luong',
    vaiTro: MOI_VAI_TRO,
  },
  {
    khoa: 'luong-ky-luong',
    nhom: 'luong',
    nhan: 'Kỳ lương',
    moTa: 'Tạo kỳ theo công ty, tính lương, chốt kỳ.',
    duongDan: '/nhan-su/luong/ky-luong',
    vaiTro: ['admin'],
    capQuyen: ['tinh_luong'],
  },
  {
    khoa: 'luong-bao-cao',
    nhom: 'luong',
    nhan: 'Báo cáo lương',
    moTa: 'Tổng hợp nhiều kỳ theo công ty, in ra giấy hoặc lưu PDF.',
    duongDan: '/nhan-su/luong/bao-cao',
    vaiTro: ['admin'],
    // `xem_luong` chứ KHÔNG phải `tinh_luong`: xem báo cáo là đọc, chốt kỳ là
    // hành động một chiều. Trước P0d hai tab này cùng đòi `tinh_luong`, nghĩa
    // là ai xem được báo cáo cũng chốt được kỳ — ô tick hứa một đằng làm một
    // nẻo.
    capQuyen: ['xem_luong'],
  },
]

/** Tab admin cấu hình được cho chức danh — bỏ những tab bắt buộc. */
export const TABS_CAU_HINH_DUOC = TABS.filter((t) => !t.batBuoc)

/**
 * Màn quản trị — CHỈ admin, và CỐ Ý không nằm trong danh mục tab ở trên.
 *
 * Không cấu hình được theo chức danh: tắt nhầm đường vào màn quản trị là tắt
 * luôn đường sửa cấu hình đã tắt nó.
 *
 * Gom thành một mục "Quản trị" dẫn tới trang tổng hợp thay vì rải 5 link rời
 * trong thanh menu. Bản đầu để rời: cộng với 6 tab thường là 11 link chen
 * nhau một hàng, xuống dòng lộn xộn và không có nhóm — người dùng đi tìm mục
 * "Quản trị" mà không thấy vì nó chưa bao giờ tồn tại.
 */
/**
 * Màn quản trị, gom thành ba nhóm con thu gọn được.
 *
 * Tám mục phẳng trong một sidebar đã có sẵn chín tab là một bức tường chữ.
 * Chia theo việc: dựng tổ chức, khai tham số trả lương, và trông coi hệ
 * thống. Người đi tìm "Ca làm việc" nghĩ tới chấm công chứ không nghĩ tới
 * "hệ thống", nên nó nằm ở nhóm giữa.
 */
export const NHOM_QUAN_TRI = [
  { nhan: 'Tổ chức', muc: ['Công ty', 'Phòng ban', 'Chức danh'] },
  { nhan: 'Lương & chấm công', muc: ['Loại phụ cấp', 'Ca làm việc', 'Tham số lương'] },
  { nhan: 'Hệ thống', muc: ['Người dùng', 'Thùng rác'] },
] as const

export const MAN_QUAN_TRI = [
  {
    nhan: 'Người dùng',
    moTa: 'Cấp tài khoản đăng nhập, nối tài khoản với hồ sơ nhân sự, phân vai trò.',
    duongDan: '/nhan-su/quan-tri/nguoi-dung',
  },
  {
    nhan: 'Công ty',
    moTa: 'Pháp nhân trả lương: kỳ lương, công chuẩn, khung giờ chuẩn và ba ca công nhật.',
    duongDan: '/nhan-su/quan-tri/cong-ty',
  },
  {
    nhan: 'Phòng ban',
    moTa: 'Cơ cấu tổ chức và trưởng phòng của từng phòng.',
    duongDan: '/nhan-su/quan-tri/phong-ban',
  },
  {
    nhan: 'Chức danh',
    moTa: 'Danh mục chức danh, tab được vào, và phụ cấp theo chức danh.',
    duongDan: '/nhan-su/quan-tri/chuc-danh',
  },
  {
    nhan: 'Loại phụ cấp',
    moTa: 'Khai từng khoản phụ cấp: có chịu thuế không, có đóng bảo hiểm không.',
    duongDan: '/nhan-su/quan-tri/loai-phu-cap',
  },
  {
    nhan: 'Ca làm việc',
    moTa: 'Giờ vào, giờ ra và giờ nghỉ — quyết định cách tính công.',
    duongDan: '/nhan-su/quan-tri/ca-lam-viec',
  },
  {
    nhan: 'Tham số lương',
    moTa: 'Biểu thuế TNCN, giảm trừ, bảo hiểm, hệ số làm thêm.',
    duongDan: '/nhan-su/quan-tri/tham-so-luong',
  },
  {
    nhan: 'Thùng rác',
    moTa: 'Hồ sơ và lần chấm công đã xoá. Khôi phục lại được.',
    duongDan: '/nhan-su/quan-tri/thung-rac',
  },
] as const

export const DUONG_DAN_QUAN_TRI = '/nhan-su/quan-tri'

export function timTab(khoa: KhoaTab): Tab {
  const t = TABS.find((x) => x.khoa === khoa)
  // Khoá tab là union type nên nhánh này chỉ chạy khi ai đó thêm khoá mới mà
  // quên khai báo. Ném lỗi to còn hơn im lặng ẩn mất một màn hình.
  if (!t) throw new Error(`Chưa khai báo tab "${khoa}" trong TABS.`)
  return t
}

/**
 * Tab một người được vào (P0d, 24/08/2026).
 *
 *   • `cauHinh = null` — CHƯA ai khai. Dùng mặc định theo vai trò. Đây là
 *     trạng thái của mọi tài khoản mới, nên không ai vào ứng dụng trắng trơn
 *     vì admin chưa kịp khai.
 *   • `cauHinh` là một mảng — admin ĐÃ khai. Lời khai ấy là toàn bộ câu trả
 *     lời, không giao với vai trò nữa.
 *
 * VÌ SAO KHÔNG CÒN GIAO VỚI VAI TRÒ. Trước P0d, tick một tab cho người không
 * có vai trò tương ứng thì tab vẫn không hiện — vì lúc ấy ô tick chỉ *bớt* màn
 * hình, còn quyền khai chỗ khác, nên hiện ra sẽ trống trơn.
 *
 * Nay ô tick *cấp* quyền: tick "Kỳ lương" cho một nhân viên thường là cấp thật
 * `tinh_luong`, và RLS sẽ cho họ đi qua. Giữ phép giao thì admin tick mà màn
 * không hiện, trong khi quyền đã cấp — tệ hơn hẳn cả hai bản trước.
 *
 * Vai trò nay chỉ còn hai việc: quyết định mặc định khi chưa khai, và giới hạn
 * những ô mà màn quản trị bày ra cho tick.
 *
 * @param cauHinh Mảng khoá tab khai riêng cho người này tại Quản trị → Người
 *   dùng. `null` = chưa khai.
 */
export function tabsChoPhep(vaiTro: UserRole, cauHinh: string[] | null): Tab[] {
  // Admin luôn thấy mọi thứ. Không có ngoại lệ này thì một lời khai sai trên
  // tài khoản admin sẽ khoá luôn đường vào màn quản trị — tức khoá luôn đường
  // sửa lời khai đó.
  if (vaiTro === 'admin') return [...TABS]

  return TABS.filter((t) => {
    if (t.batBuoc) return true
    if (cauHinh === null) return t.vaiTro.includes(vaiTro)
    return cauHinh.includes(t.khoa)
  })
}

export function duocVaoTab(
  vaiTro: UserRole,
  cauHinh: string[] | null,
  khoa: KhoaTab,
): boolean {
  return tabsChoPhep(vaiTro, cauHinh).some((t) => t.khoa === khoa)
}

/**
 * Ô tick "Duyệt công tổ đội" — quyền duy nhất KHÔNG gắn với một tab.
 *
 * Nằm ngay dưới tab *Quản lý tổ đội* trên màn Quản trị → Người dùng, nhưng lưu
 * riêng ở cột `app_users.duyet_cong`. Lý do: tab ấy mở cho mọi vai trò vì
 * người chấm công thường là tài khoản `nhan_vien` — tick tab mà cấp luôn quyền
 * duyệt thì mọi người chấm công thành người duyệt công.
 */
export const O_DUYET_CONG = {
  quyen: 'duyet_cong' as const,
  nhan: 'Duyệt công tổ đội',
  duoiTab: 'to-doi' as KhoaTab,
}

/**
 * Mọi quyền hệ thống biết tới.
 *
 * Phải khớp với hàm `quyen_tu_tab()` ở database — nơi cột sinh
 * `app_users.quyen` lấy giá trị. Đây chỉ là bản sao cho màn hình; lớp quyết
 * định thật vẫn là RLS, và nếu hai bên lệch thì bên sai là bên này.
 *
 * "Trưởng phòng" CỐ Ý không có mặt: quyền ấy gắn với việc phụ trách MỘT phòng
 * cụ thể. Hai người cùng chức danh "Trưởng phòng" ở hai phòng khác nhau phải
 * thấy hai tập hồ sơ khác nhau — một ô tick không nói được điều đó.
 *
 * "Quản trị hệ thống" cũng không: admin sửa được chính màn cấp quyền, nên cấp
 * admin bằng ô tick là mở đường tự cấp cho mình mọi thứ còn lại.
 */
export type KhoaQuyen =
  | 'quan_ly_nhan_su'
  | 'tinh_luong'
  | 'xem_luong'
  | 'xac_nhan_cham_cong'
  | 'sua_chua_cong'
  | 'duyet_cong'

/**
 * Chữ mô tả cho từng quyền — in ngay dưới tên tab ở màn Quản trị → Người dùng,
 * để admin biết tick vào là cấp cái gì.
 *
 * Không còn là "quyền gán theo chức danh": từ P0d quyền sinh ra từ ô tick tab
 * của TỪNG NGƯỜI, và bảng ánh xạ nằm ở `Tab.capQuyen` phía trên.
 */
export const MO_TA_QUYEN: Record<KhoaQuyen, string> = {
  quan_ly_nhan_su: 'xem và SỬA hồ sơ nhân sự toàn công ty, hợp đồng, người phụ thuộc',
  tinh_luong: 'tạo kỳ lương, bấm tính, CHỐT kỳ — chốt là hành động một chiều',
  xem_luong: 'xem lương toàn công ty. KHÔNG chốt được kỳ',
  xac_nhan_cham_cong: 'duyệt chấm công hằng ngày để công được tính vào bảng lương',
  sua_chua_cong:
    'CHẤM BÙ ngày công bị sót, xoá lần chấm sai, mở lại phiên tổ đội đã duyệt. ' +
    'Mạnh hơn xác nhận: nó tạo ra công chứ không chỉ công nhận công có sẵn',
  duyet_cong:
    'duyệt phiên chấm công của tổ thuê công nhật. Người có tên trong tổ thì không ' +
    'duyệt được công của chính tổ mình',
}
