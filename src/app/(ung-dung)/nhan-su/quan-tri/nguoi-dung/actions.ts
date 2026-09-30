'use server'

import { revalidatePath } from 'next/cache'
import { TABS_CAU_HINH_DUOC } from '@ns/lib/tabs'
import { createClient } from '@ns/lib/supabase/server'
import { batBuocVaiTro } from '@ns/lib/phien'
import { ROLE_LABELS } from '@ns/types/database'
import type { UserRole } from '@ns/types/database'

/**
 * Trạng thái form của màn quản trị người dùng.
 *
 * `matKhau` chỉ có mặt đúng một lần, ngay sau khi hệ thống tự sinh mật khẩu.
 * Nó KHÔNG được lưu ở đâu cả — đọc xong là mất. Project chưa có SMTP nên
 * không có đường gửi mật khẩu tự động; hiện một lần rồi để admin trao tay
 * vẫn hơn là lưu lại một bản đọc được.
 */
export type TrangThaiForm = {
  error: string | null
  xong?: string
  matKhau?: string
}

function chuoi(form: FormData, ten: string): string | null {
  const v = String(form.get(ten) ?? '').trim()
  return v === '' ? null : v
}

const VAI_TRO_HOP_LE = Object.keys(ROLE_LABELS) as UserRole[]

/**
 * Dịch lỗi database sang tiếng người.
 *
 * Trigger `chan_mat_quyen_admin` đã viết sẵn câu tiếng Việt đầy đủ nên giữ
 * nguyên. Riêng vi phạm chỉ mục duy nhất thì Postgres chỉ trả về tên chỉ mục
 * — không nói được cho người dùng.
 */
function dichLoi(msg: string): string {
  if (msg.includes('uniq_app_users_employee')) {
    return 'Hồ sơ nhân sự này đã được nối với một tài khoản khác. Gỡ nối ở tài khoản đó trước.'
  }
  return msg
}

export async function doiVaiTro(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  const phien = await batBuocVaiTro('admin')

  const id = chuoi(form, 'id')
  const vaiTro = chuoi(form, 'role')
  if (!id) return { error: 'Thiếu tài khoản.' }
  if (!vaiTro || !VAI_TRO_HOP_LE.includes(vaiTro as UserRole)) {
    return { error: 'Vai trò không hợp lệ.' }
  }

  // Trigger ở database chặn việc này rồi. Chặn thêm ở đây để câu thông báo
  // tới đúng chỗ người dùng đang nhìn, thay vì một mã lỗi Postgres.
  if (id === phien.userId && vaiTro !== 'admin') {
    return { error: 'Không tự hạ vai trò của chính mình. Nhờ một admin khác làm giúp.' }
  }

  const supabase = await createClient()
  const { error } = await supabase
    .from('app_users')
    .update({ role: vaiTro as UserRole })
    .eq('id', id)

  if (error) return { error: dichLoi(error.message) }

  revalidatePath('/nhan-su/quan-tri/nguoi-dung')
  return { error: null, xong: 'Đã đổi vai trò.' }
}

/**
 * Tab người này được vào (P0c, 24/08/2026).
 *
 * Trước 24/08 cấu hình này nằm ở CHỨC DANH. Triệu Vũ chuyển sang từng người:
 * hai người cùng chức danh vẫn có thể cần hai bộ màn hình khác nhau.
 *
 * Phân biệt "CHƯA cấu hình" với "cấu hình RỖNG", và đây là chỗ dễ sai nhất:
 *
 *   NULL      = dùng nguyên quyền theo vai trò và chức danh (mặc định của mọi
 *               tài khoản mới, nên không ai mất tab vì admin chưa kịp khai)
 *   mảng rỗng = admin CỐ Ý chỉ để lại tab bắt buộc
 *
 * Không phân biệt hai thứ này thì bỏ tick hết sẽ bị hiểu thành "chưa cấu hình"
 * và tab lại hiện ra đủ — trái hẳn ý người bấm.
 *
 * ⚠️ Đây là ĐIỀU HƯỚNG, không phải quyền đọc dữ liệu. Bỏ tick một tab không
 * thu hồi quyền đọc — RLS mới quyết định điều đó. Muốn chặn dữ liệu thì gỡ
 * QUYỀN ở Quản trị → Chức danh.
 */
export async function datTabNguoiDung(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  await batBuocVaiTro('admin')

  const id = chuoi(form, 'id')
  if (!id) return { error: 'Thiếu tài khoản.' }

  const tuChon = form.get('tu_chon_tab') === 'on'
  const khoaHopLe = new Set(TABS_CAU_HINH_DUOC.map((t) => t.khoa as string))
  const tabs = tuChon
    ? form.getAll('tabs').map(String).filter((k) => khoaHopLe.has(k))
    : null

  // Ô "Duyệt công tổ đội" lưu riêng vì nó không gắn với tab nào — xem
  // `O_DUYET_CONG`. Bỏ tự chọn thì tắt luôn: chưa khai gì thì không có quyền
  // gì, đúng nguyên tắc quyền phải là lời khẳng định có chủ ý.
  const duyetCong = tuChon && form.get('duyet_cong') === 'on'

  const supabase = await createClient()
  const { error } = await supabase
    .from('app_users')
    .update({ tabs, duyet_cong: duyetCong })
    .eq('id', id)

  if (error) return { error: `Không lưu được: ${error.message}` }

  // Đọc lại rồi mới báo — bài học 24/08: "không lỗi" chưa phải "đã ghi".
  //
  // Đọc luôn cột sinh `quyen` để câu báo nói đúng thứ NGƯỜI NÀY VỪA ĐƯỢC CẤP,
  // chứ không phải thứ tầng ứng dụng đoán là đã cấp. Đây là chỗ duy nhất
  // trong app đọc `quyen` sau khi ghi, và nó đáng: từ P0d một ô tick tab là
  // một lần đổi quyền thật.
  const { data: sau } = await supabase
    .from('app_users')
    .select('tabs, duyet_cong, quyen')
    .eq('id', id)
    .maybeSingle()

  if (
    sau === null ||
    (sau.tabs === null) !== (tabs === null) ||
    sau.duyet_cong !== duyetCong
  ) {
    return { error: 'Đã gọi lưu nhưng đọc lại không thấy đổi. Báo lại nguyên văn câu này.' }
  }

  revalidatePath('/nhan-su/quan-tri/nguoi-dung')
  // Thanh menu của người này dựng từ cấu hình vừa đổi.
  revalidatePath('/', 'layout')

  const soQuyen = (sau.quyen ?? []).length

  return {
    error: null,
    xong:
      tabs === null
        ? 'Đã bỏ tự chọn — người này dùng tab mặc định theo vai trò, và KHÔNG có quyền nào.'
        : `Đã lưu: ${tabs.length} tab, cấp ${soQuyen} quyền` +
          (soQuyen > 0 ? ` (${(sau.quyen ?? []).join(', ')}).` : '.'),
  }
}

export async function datKichHoat(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  const phien = await batBuocVaiTro('admin')

  const id = chuoi(form, 'id')
  const bat = form.get('bat') !== null
  if (!id) return { error: 'Thiếu tài khoản.' }

  if (id === phien.userId && !bat) {
    return { error: 'Không tự khoá tài khoản của chính mình.' }
  }

  const supabase = await createClient()
  const { error } = await supabase.from('app_users').update({ is_active: bat }).eq('id', id)

  if (error) return { error: dichLoi(error.message) }

  revalidatePath('/nhan-su/quan-tri/nguoi-dung')
  return { error: null, xong: bat ? 'Đã mở khoá tài khoản.' : 'Đã khoá tài khoản.' }
}

/**
 * Nối tài khoản đăng nhập với hồ sơ nhân sự.
 *
 * Đây là bước quyết định người đó thấy gì: mọi màn "của tôi" — hồ sơ, phiếu
 * lương, bảng công — đi qua `current_employee_id()`, và hàm đó trả NULL khi
 * tài khoản chưa nối. Chưa nối thì đăng nhập được nhưng màn nào cũng rỗng.
 *
 * Trước màn này, việc nối phải gõ tay một câu UPDATE trong SQL Editor: sai
 * một ký tự mã nhân viên là nối người này vào hồ sơ người khác, và người đó
 * đọc được lương lẫn CCCD của người kia. Chọn từ danh sách thì không gõ sai
 * được, và chỉ mục duy nhất ở database chặn nốt trường hợp hai tài khoản
 * cùng trỏ một hồ sơ.
 */
export async function noiHoSo(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  await batBuocVaiTro('admin')

  const id = chuoi(form, 'id')
  const employeeId = chuoi(form, 'employee_id')
  if (!id) return { error: 'Thiếu tài khoản.' }

  const supabase = await createClient()
  const { error } = await supabase
    .from('app_users')
    .update({ employee_id: employeeId })
    .eq('id', id)

  if (error) return { error: dichLoi(error.message) }

  revalidatePath('/nhan-su/quan-tri/nguoi-dung')
  return {
    error: null,
    xong: employeeId ? 'Đã nối với hồ sơ nhân sự.' : 'Đã gỡ nối hồ sơ nhân sự.',
  }
}

/**
 * Tạo tài khoản đăng nhập mới.
 *
 * Đi qua Edge Function `quan-tri-tai-khoan` vì việc này ghi vào `auth.users`,
 * mà bảng đó chỉ `service_role` chạm được — và `service_role` không bao giờ
 * được xuống trình duyệt.
 */
export async function taoTaiKhoan(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  await batBuocVaiTro('admin')

  const email = chuoi(form, 'email')
  const hoTen = chuoi(form, 'ho_ten')
  const vaiTro = chuoi(form, 'vai_tro')

  if (!email) return { error: 'Phải có email đăng nhập.' }
  if (!hoTen) return { error: 'Phải có họ tên.' }
  if (!vaiTro || !VAI_TRO_HOP_LE.includes(vaiTro as UserRole)) {
    return { error: 'Vai trò không hợp lệ.' }
  }

  const supabase = await createClient()
  const { data, error } = await supabase.functions.invoke('quan-tri-tai-khoan', {
    body: {
      hanh_dong: 'tao',
      email,
      ho_ten: hoTen,
      vai_tro: vaiTro,
      mat_khau: chuoi(form, 'mat_khau'),
    },
  })

  const loi = await docLoi(error, data)
  if (loi) return { error: loi }

  // Tài khoản mới chưa nối hồ sơ nhân sự — nối ở danh sách bên dưới. Cố ý
  // tách làm hai bước: gộp vào một form là bắt admin chọn hồ sơ đúng lúc
  // đang tập trung gõ email, và nối nhầm hồ sơ tốn kém hơn nhiều so với
  // thêm một cú bấm.
  revalidatePath('/nhan-su/quan-tri/nguoi-dung')
  return {
    error: null,
    xong: `Đã tạo tài khoản cho ${hoTen}. Bước tiếp theo: nối với hồ sơ nhân sự trong danh sách bên dưới.`,
    matKhau: typeof data?.mat_khau === 'string' ? data.mat_khau : undefined,
  }
}

export async function datLaiMatKhau(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  await batBuocVaiTro('admin')

  const id = chuoi(form, 'id')
  if (!id) return { error: 'Thiếu tài khoản.' }

  const supabase = await createClient()
  const { data, error } = await supabase.functions.invoke('quan-tri-tai-khoan', {
    body: { hanh_dong: 'dat-lai-mat-khau', user_id: id, mat_khau: chuoi(form, 'mat_khau') },
  })

  const loi = await docLoi(error, data)
  if (loi) return { error: loi }

  return {
    error: null,
    xong: 'Đã đặt lại mật khẩu.',
    matKhau: typeof data?.mat_khau === 'string' ? data.mat_khau : undefined,
  }
}

/**
 * Lấy câu lỗi thật của Edge Function.
 *
 * `functions.invoke` gói mọi mã trạng thái khác 2xx thành một `FunctionsHttpError`
 * với câu chữ chung chung ("Edge Function returned a non-2xx status code").
 * Câu lý do thật — email trùng, mật khẩu yếu hơn chính sách project — nằm
 * trong thân phản hồi, phải đọc ra. Không đọc thì admin nhìn thấy một thông
 * báo không nói gì và không biết phải sửa cái gì.
 */
async function docLoi(error: unknown, data: unknown): Promise<string | null> {
  if (error) {
    const ctx = (error as { context?: unknown }).context
    if (ctx instanceof Response) {
      try {
        const than = await ctx.json()
        if (typeof than?.loi === 'string') return than.loi
      } catch {
        // Thân phản hồi không phải JSON — rơi xuống thông báo mặc định.
      }
    }
    return error instanceof Error ? error.message : 'Không gọi được máy chủ.'
  }
  if (data && typeof (data as { loi?: unknown }).loi === 'string') {
    return (data as { loi: string }).loi
  }
  return null
}
