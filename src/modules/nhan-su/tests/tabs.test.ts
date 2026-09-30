import { describe, expect, it } from 'vitest'

import {
  MAN_QUAN_TRI,
  MO_TA_QUYEN,
  NHAN_NHOM,
  NHOM_MENU,
  NHOM_QUAN_TRI,
  O_DUYET_CONG,
  TABS,
  TABS_CAU_HINH_DUOC,
  duocVaoTab,
  tabsChoPhep,
  type KhoaQuyen,
} from '@ns/lib/tabs'

const khoa = (vaiTro: Parameters<typeof tabsChoPhep>[0], cauHinh: string[] | null) =>
  tabsChoPhep(vaiTro, cauHinh).map((t) => t.khoa)

describe('tabsChoPhep — chưa cấu hình thì giữ nguyên hành vi cũ', () => {
  it('nhân viên thấy đúng các tab của vai trò mình', () => {
    expect(khoa('nhan_vien', null)).toEqual([
      'ho-so',
      'cham-cong',
      'to-doi',
      'luong',
    ])
  })

  it('Chấm công tổ đội mở cho MỌI vai trò', () => {
    // Người được giao chấm công cho tổ công nhật thường là tổ trưởng hoặc chỉ
    // huy trưởng, tức tài khoản vai trò `nhan_vien`. Đóng tab này lại theo vai
    // trò là khoá đúng người cần dùng nó. Ai chưa được giao tổ nào vào đây sẽ
    // thấy màn nói rõ điều đó — RLS mới là thứ quyết định họ đọc được gì.
    for (const vt of ['nhan_vien', 'truong_phong', 'hr', 'ke_toan', 'admin'] as const) {
      expect(khoa(vt, null)).toContain('to-doi')
    }
  })

  it('trưởng phòng thấy thêm Nhân sự', () => {
    expect(khoa('truong_phong', null)).toContain('nhan-su')
    expect(khoa('truong_phong', null)).not.toContain('cham-cong-xac-nhan')
  })

  it('kế toán và nhân sự KHÔNG còn tab nào theo vai trò (P1f)', () => {
    // Từ 24/08/2026 quyền đi theo CHỨC DANH, không theo vai trò. Hai vai trò
    // này còn đúng những tab ai cũng có; muốn làm việc cũ thì admin gán chức
    // danh mang quyền tương ứng.
    for (const vt of ['hr', 'ke_toan'] as const) {
      expect(khoa(vt, null)).toEqual(['ho-so', 'cham-cong', 'to-doi', 'luong'])
    }
  })

  it('tick tab là họ có lại đúng màn cần', () => {
    // Từ P1f vai trò `hr` và `ke_toan` không tự mang quyền gì; từ P0d đường
    // duy nhất là ô tick tab của từng người.
    expect(khoa('ke_toan', ['luong-ky-luong'])).toContain('luong-ky-luong')
    expect(khoa('hr', ['cham-cong-xac-nhan'])).toContain('cham-cong-xac-nhan')
    expect(khoa('hr', ['nhan-su'])).toContain('nhan-su')
  })
})

describe('tabsChoPhep — lời khai tay quyết định', () => {
  it('bỏ tab khỏi cấu hình thì tab biến mất', () => {
    expect(khoa('nhan_vien', ['cham-cong'])).toEqual(['ho-so', 'cham-cong'])
  })

  it('admin bớt được Chấm công tổ đội khỏi chức danh không liên quan', () => {
    expect(khoa('nhan_vien', ['cham-cong'])).not.toContain('to-doi')
  })

  it('tick tab mà vai trò không có thì VẪN hiện — vì tick đã cấp quyền', () => {
    // Đảo chiều ở P0d. Trước đó phép này lấy giao với vai trò và kỳ vọng chỉ
    // còn 'ho-so'; đúng ở thời điểm ấy, vì ô tick chỉ bớt màn hình còn quyền
    // khai chỗ khác — hiện ra sẽ trống trơn. Nay ô tick CẤP quyền, nên không
    // hiện mới là sai: quyền đã cấp mà không có đường đi tới.
    expect(khoa('nhan_vien', ['nhan-su', 'luong-ky-luong', 'cham-cong-xac-nhan'])).toEqual([
      'ho-so',
      'nhan-su',
      'cham-cong-xac-nhan',
      'luong-ky-luong',
    ])
  })

  it('cấu hình rỗng vẫn còn tab bắt buộc — không ai bị vào ứng dụng trắng trơn', () => {
    expect(khoa('nhan_vien', [])).toEqual(['ho-so'])
    expect(khoa('hr', [])).toEqual(['ho-so'])
  })
})

describe('tabsChoPhep — lời khai tay là toàn bộ câu trả lời (P0d)', () => {
  // Triệu Vũ, 24/08/2026: "admin quyết định ai được xem những tab nào, bỏ luôn
  // phân quyền, vì nếu không xem được tab sẽ không thao tác được trên đó."
  //
  // Câu ấy chỉ đúng khi ô tick CẤP quyền, chứ không phải chỉ giấu lối đi. Nên
  // từ P0d hàm này không nhận tham số `quyen` nữa: quyền là HỆ QUẢ của ô tick,
  // không phải đầu vào thứ hai cạnh nó.

  it('đã khai thì hiện đúng những gì đã tick, không giao với vai trò', () => {
    // Nhân viên thường không có vai trò để vào màn Nhân sự. Nhưng tick nó là
    // cấp thật `quan_ly_nhan_su`, và RLS sẽ cho họ đi qua — nên tab PHẢI hiện.
    // Giữ phép giao như trước P0d thì admin tick mà màn không hiện, trong khi
    // quyền đã cấp: tệ hơn hẳn.
    expect(khoa('nhan_vien', ['nhan-su'])).toEqual(['ho-so', 'nhan-su'])
    expect(khoa('nhan_vien', ['luong-ky-luong'])).toEqual(['ho-so', 'luong-ky-luong'])
  })

  it('bỏ tick là mất tab VÀ mất quyền', () => {
    const ds = khoa('nhan_vien', ['cham-cong'])
    expect(ds).not.toContain('nhan-su')
    expect(ds).not.toContain('luong-ky-luong')
    expect(ds).not.toContain('luong-bao-cao')
  })

  it('chưa khai thì lấy mặc định theo vai trò', () => {
    expect(khoa('nhan_vien', null)).toEqual(khoa('nhan_vien', null))
    expect(khoa('nhan_vien', null)).not.toContain('nhan-su')
    expect(khoa('truong_phong', null)).toContain('nhan-su')
  })

  it('cấu hình rỗng vẫn còn tab bắt buộc — không ai vào ứng dụng trắng trơn', () => {
    expect(khoa('nhan_vien', [])).toEqual(['ho-so'])
    expect(khoa('truong_phong', [])).toEqual(['ho-so'])
  })
})

describe('ánh xạ tab → quyền (P0d)', () => {
  // Bảng ánh xạ THẬT nằm ở hàm `quyen_tu_tab()` trong database, và cột
  // `app_users.quyen` sinh ra từ nó. Danh sách ở đây chỉ để hiện chữ cho admin
  // đọc — nên phép kiểm này ghim từng cặp một, để lần ai đó đổi ánh xạ ở một
  // bên là bên kia đỏ ngay.
  it('đúng từng cặp tab ↔ quyền', () => {
    const capBoi = (k: string) => TABS.find((t) => t.khoa === k)?.capQuyen ?? []
    expect(capBoi('nhan-su')).toEqual(['quan_ly_nhan_su'])
    expect(capBoi('luong-ky-luong')).toEqual(['tinh_luong'])
    expect(capBoi('luong-bao-cao')).toEqual(['xem_luong'])
    expect(capBoi('cham-cong-xac-nhan')).toEqual(['xac_nhan_cham_cong'])
    expect(capBoi('sua-chua-cong')).toEqual(['sua_chua_cong'])
  })

  it('Sửa chữa công TÁCH khỏi Xác nhận chấm công', () => {
    // Xác nhận là nói "đúng rồi" về một lần chấm CÓ THẬT; sửa chữa là tạo ra
    // một lần chấm chưa từng xảy ra. Gộp hai ô là cho người xác nhận hằng ngày
    // cái quyền tạo công khống mà không ai cố ý cấp.
    const xacNhan = TABS.find((t) => t.khoa === 'cham-cong-xac-nhan')?.capQuyen ?? []
    const sua = TABS.find((t) => t.khoa === 'sua-chua-cong')?.capQuyen ?? []
    expect(xacNhan).not.toEqual(sua)
    expect(sua).not.toContain('xac_nhan_cham_cong')
  })

  it('Kỳ lương và Báo cáo lương KHÔNG cùng một quyền', () => {
    // Trước P0d cả hai cùng đòi `tinh_luong`, nghĩa là ai xem được báo cáo
    // cũng CHỐT được kỳ lương — một hành động một chiều. Tách ra là điều kiện
    // để "một tab một quyền" không thành lời hứa suông.
    const ky = TABS.find((t) => t.khoa === 'luong-ky-luong')?.capQuyen ?? []
    const bc = TABS.find((t) => t.khoa === 'luong-bao-cao')?.capQuyen ?? []
    expect(ky).not.toEqual(bc)
  })

  it('tab Quản lý tổ đội KHÔNG cấp quyền nào', () => {
    // Tab này mở cho mọi vai trò vì người chấm công thường là tài khoản
    // `nhan_vien`. Tick nó mà cấp luôn quyền duyệt thì mọi người chấm công
    // thành người duyệt công. Quyền duyệt có ô riêng.
    expect(TABS.find((t) => t.khoa === 'to-doi')?.capQuyen).toEqual([])
    expect(O_DUYET_CONG.quyen).toBe('duyet_cong')
    expect(O_DUYET_CONG.duoiTab).toBe('to-doi')
  })

  it('mọi quyền một tab cấp đều có mô tả để admin đọc trước khi tick', () => {
    for (const t of TABS) {
      for (const q of t.capQuyen ?? []) {
        expect(MO_TA_QUYEN[q]?.length ?? 0).toBeGreaterThan(0)
      }
    }
    expect(MO_TA_QUYEN[O_DUYET_CONG.quyen].length).toBeGreaterThan(0)
  })

  it('không quyền nào bị bỏ quên — mọi quyền phải có đường cấp', () => {
    // Một quyền có trong type mà không ô tick nào cấp là một quyền không ai
    // dùng được, và nó sẽ nằm đó cho tới khi có người tưởng nó hoạt động.
    const capDuoc = new Set<KhoaQuyen>([
      ...TABS.flatMap((t) => t.capQuyen ?? []),
      O_DUYET_CONG.quyen,
    ])
    for (const q of Object.keys(MO_TA_QUYEN) as KhoaQuyen[]) {
      expect(capDuoc.has(q)).toBe(true)
    }
  })
})

describe('tabsChoPhep — admin không bao giờ bị khoá', () => {
  it('admin thấy mọi tab dù cấu hình rỗng', () => {
    // Không có ngoại lệ này thì một cấu hình sai trên chức danh của admin sẽ
    // khoá luôn đường vào màn quản trị, tức khoá luôn đường sửa cấu hình đó.
    expect(khoa('admin', [])).toEqual(TABS.map((t) => t.khoa))
  })

  it('admin thấy mọi tab dù cấu hình chỉ có một tab', () => {
    expect(khoa('admin', ['cham-cong'])).toEqual(TABS.map((t) => t.khoa))
  })
})

describe('duocVaoTab — dùng để chặn khi gõ thẳng URL', () => {
  it('khớp với danh sách mà tabsChoPhep trả về', () => {
    expect(duocVaoTab('nhan_vien', null, 'luong')).toBe(true)
    expect(duocVaoTab('nhan_vien', ['cham-cong'], 'luong')).toBe(false)
    expect(duocVaoTab('nhan_vien', null, 'nhan-su')).toBe(false)
    expect(duocVaoTab('admin', [], 'luong-ky-luong')).toBe(true)
  })
})

describe('danh mục tab', () => {
  it('khoá tab không trùng nhau', () => {
    const ds = TABS.map((t) => t.khoa)
    expect(new Set(ds).size).toBe(ds.length)
  })

  it('đường dẫn không trùng nhau', () => {
    const ds = TABS.map((t) => t.duongDan)
    expect(new Set(ds).size).toBe(ds.length)
  })

  it('tab bắt buộc không nằm trong danh sách cấu hình được', () => {
    expect(TABS_CAU_HINH_DUOC.some((t) => t.batBuoc)).toBe(false)
  })

  it('mọi tab đều có nhãn và mô tả — thẻ trang chủ dựng từ đây', () => {
    for (const t of TABS) {
      expect(t.nhan.length).toBeGreaterThan(0)
      expect(t.moTa.length).toBeGreaterThan(0)
      expect(t.vaiTro.length).toBeGreaterThan(0)
    }
  })
})

describe('MO_TA_QUYEN — bản sao cho giao diện của quyen_tu_tab()', () => {
  // Viết thẳng năm khoá ra đây để lần thêm quyền sau phải sửa cả migration lẫn
  // file này mới xanh. Lệch nhau thì hoặc ô tick hứa một quyền database không
  // biết, hoặc database có một quyền không màn hình nào cấp được.
  it('đúng sáu quyền, khớp hàm quyen_tu_tab() ở database', () => {
    expect(Object.keys(MO_TA_QUYEN).sort()).toEqual([
      'duyet_cong',
      'quan_ly_nhan_su',
      'sua_chua_cong',
      'tinh_luong',
      'xac_nhan_cham_cong',
      'xem_luong',
    ])
  })

  it('quyền nào cũng có mô tả nói rõ tick vào là cấp cái gì', () => {
    for (const mo of Object.values(MO_TA_QUYEN)) {
      expect(mo.length).toBeGreaterThan(10)
    }
  })
})

describe('nhóm menu bên trái — thuần hiển thị, nhưng hỏng thì mất đường đi', () => {
  it('mọi tab đều thuộc một nhóm có thật', () => {
    for (const t of TABS) {
      expect(NHOM_MENU).toContain(t.nhom)
    }
  })

  it('nhóm nào cũng có nhãn tiếng Việt', () => {
    for (const n of NHOM_MENU) {
      expect(NHAN_NHOM[n].length).toBeGreaterThan(0)
    }
  })

  it('KHÔNG màn quản trị nào rơi khỏi sidebar', () => {
    // Sidebar chỉ vẽ những mục có tên trong NHOM_QUAN_TRI. Thêm một màn vào
    // MAN_QUAN_TRI mà quên xếp nhóm thì nó biến mất khỏi menu — vẫn vào được
    // bằng URL, nên không ai phát hiện cho tới khi có người đi tìm nó.
    const daXep = NHOM_QUAN_TRI.flatMap((n) => n.muc as readonly string[])
    for (const m of MAN_QUAN_TRI) {
      expect(daXep).toContain(m.nhan)
    }
  })

  it('và không nhóm nào trỏ tới một màn không tồn tại', () => {
    // Chiều ngược lại: đổi tên một màn mà quên sửa nhóm thì mục ấy lặng lẽ
    // không vẽ ra, vì component tìm theo NHÃN.
    const coThat = MAN_QUAN_TRI.map((m) => m.nhan as string)
    for (const n of NHOM_QUAN_TRI) {
      for (const m of n.muc) {
        expect(coThat).toContain(m)
      }
    }
  })

  it('mỗi màn quản trị chỉ nằm ở ĐÚNG MỘT nhóm', () => {
    const daXep = NHOM_QUAN_TRI.flatMap((n) => n.muc as readonly string[])
    expect(new Set(daXep).size).toBe(daXep.length)
  })
})
