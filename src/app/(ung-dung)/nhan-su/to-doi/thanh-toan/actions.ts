'use server'

import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { createClient } from '@ns/lib/supabase/server'
import { batBuocPhien } from '@ns/lib/phien'
import { sinhChungTu } from '@ns/lib/chung-tu'

export type TrangThaiForm = { error: string | null; xong?: string; bangId?: string }

const LA_NGAY = /^\d{4}-\d{2}-\d{2}$/

const KHONG_PHU_TRACH =
  'Không làm được: bạn không phụ trách tổ này, hoặc tài khoản của bạn không còn đủ điều kiện làm người chấm công (phải là nhân viên chính thức, hợp đồng đang hiệu lực và đang đóng bảo hiểm). Đề nghị quản trị hệ thống kiểm tra lại.'

function chuoi(form: FormData, ten: string): string {
  return String(form.get(ten) ?? '').trim()
}

/** Số lẻ được — "7,5" giờ. Trống → null; gõ bậy → NaN. */
function soLe(form: FormData, ten: string): number | null {
  const v = chuoi(form, ten).replace(/\s/g, '').replace(',', '.')
  if (v === '') return null
  const n = Number(v)
  return Number.isFinite(n) ? n : Number.NaN
}

/** Tiền là số nguyên đồng: bỏ dấu phân cách hàng nghìn, "45.000" hay "45,000" đều được. */
function soTien(form: FormData, ten: string): number | null {
  const v = chuoi(form, ten).replace(/[.,\s]/g, '')
  if (v === '') return null
  const n = Number(v)
  return Number.isFinite(n) ? n : Number.NaN
}

/**
 * Sinh bảng thanh toán cho một tổ trong khoảng ngày tự chọn.
 *
 * Toàn bộ phần khó nằm ở hàm `sinh_bang_thanh_toan_to` trong database, và cố ý
 * như vậy: nó phải đọc đơn giá (bảng mà người quản lý không được đọc), phải
 * chỉ cộng công của phiên đã duyệt, và phải TỪ CHỐI khi thiếu đơn giá thay vì
 * lặng lẽ tính 0 đồng. Viết lại các quy tắc đó ở tầng này là tạo bản sao thứ
 * hai của cùng một logic tiền.
 *
 * KHÔNG kiểm vai trò ở đây — người quản lý chấm công thường mang vai trò
 * `nhan_vien`. Hàm ở database tự kiểm quyền ngay dòng đầu.
 */
export async function sinhBangThanhToan(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  await batBuocPhien()

  const toDoiId = chuoi(form, 'to_doi_id')
  const tuNgay = chuoi(form, 'tu_ngay')
  const denNgay = chuoi(form, 'den_ngay')

  if (!toDoiId) return { error: 'Chưa chọn tổ.' }
  if (!LA_NGAY.test(tuNgay) || !LA_NGAY.test(denNgay)) {
    return { error: 'Khoảng ngày không hợp lệ.' }
  }
  if (denNgay < tuNgay) return { error: 'Ngày cuối sớm hơn ngày đầu.' }

  const supabase = await createClient()
  const { data, error } = await supabase.rpc('sinh_bang_thanh_toan_to', {
    p_to_doi_id: toDoiId,
    p_tu_ngay: tuNgay,
    p_den_ngay: denNgay,
  })

  // Hàm ở database đã viết sẵn thông báo tiếng Việt đầy đủ — nêu cả tên người
  // thiếu đơn giá. Giữ nguyên thay vì gói lại thành câu chung chung.
  if (error) return { error: error.message }

  // Số của một bảng không đổi sau khi sinh (sửa tay thì THAY bằng bảng mới,
  // xem `suaTayDongThanhToan`), nên "sinh xong" chính là lúc phải có chứng từ.
  const bangId = data as string
  const { chungTu, loi: loiChungTu } = await sinhChungTu('bang_thanh_toan_to', bangId)

  revalidatePath('/nhan-su/to-doi/thanh-toan')

  if (loiChungTu) {
    return {
      error: null,
      xong: `Đã sinh bảng thanh toán, NHƯNG chưa sinh được chứng từ PDF: ${loiChungTu} — bấm "Sinh chứng từ" ở danh sách bảng để làm lại.`,
      bangId,
    }
  }

  return {
    error: null,
    xong: `Đã sinh bảng thanh toán và lưu chứng từ ${chungTu?.so_hieu ?? ''}.`,
    bangId,
  }
}

/**
 * Sửa tay một dòng của bảng đã sinh (P5j, 15/09/2026).
 *
 * P5h (24/08) khoá hẳn việc này. Triệu Vũ mở lại ngày 15/09 và, được hỏi,
 * chọn SỬA TAY thay vì tính lại từ số công và đơn giá gốc. Mọi quy tắc nằm ở
 * hàm `sua_tay_dong_thanh_toan_to` trong database: kiểm quyền, bắt lý do,
 * THAY bảng cũ bằng bảng mới, ghi sổ. Ở đây chỉ đọc biểu mẫu và báo lỗi.
 *
 * Bảng mới mang id mới, nên xong việc phải chuyển trang sang nó, và phải sinh
 * chứng từ cho nó. Chứng từ cũ thuộc về bảng cũ, mang số cũ, và ở lại đúng
 * như thế làm vết.
 */
export async function suaTayDongThanhToan(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  await batBuocPhien()

  const dongId = chuoi(form, 'dong_id')
  const lyDo = chuoi(form, 'ly_do')
  if (!dongId) return { error: 'Thiếu dòng cần sửa.' }
  if (!lyDo) return { error: 'Phải ghi lý do sửa.' }

  const so = {
    p_so_luong: soLe(form, 'so_luong'),
    p_don_gia: soTien(form, 'don_gia'),
    p_so_gio_ot: soLe(form, 'so_gio_ot'),
    p_don_gia_ot: soTien(form, 'don_gia_ot'),
    p_thuong: soTien(form, 'thuong'),
  }
  const NHAN: Record<keyof typeof so, string> = {
    p_so_luong: 'Số lượng',
    p_don_gia: 'Đơn giá',
    p_so_gio_ot: 'Giờ ngoài giờ',
    p_don_gia_ot: 'Đơn giá ngoài giờ',
    p_thuong: 'Thưởng',
  }
  for (const [khoa, giaTri] of Object.entries(so) as [keyof typeof so, number | null][]) {
    if (giaTri === null || Number.isNaN(giaTri)) {
      return { error: `Ô "${NHAN[khoa]}" phải là một số — không có thì ghi 0.` }
    }
    if (giaTri < 0) return { error: `Ô "${NHAN[khoa]}" không được âm.` }
  }

  const supabase = await createClient()
  const { data, error } = await supabase.rpc('sua_tay_dong_thanh_toan_to', {
    p_dong_id: dongId,
    ...(so as Record<keyof typeof so, number>),
    p_ly_do: lyDo,
  })

  // Hàm ở database viết sẵn câu tiếng Việt cho mọi lần từ chối — giữ nguyên.
  if (error) return { error: error.message }

  const bangMoi = data as string
  const { loi: loiChungTu } = await sinhChungTu('bang_thanh_toan_to', bangMoi)

  revalidatePath('/nhan-su/to-doi/thanh-toan')
  redirect(`/nhan-su/to-doi/thanh-toan?bang=${bangMoi}&da_sua=1${loiChungTu ? '&thieu_chung_tu=1' : ''}`)
}

/**
 * Xoá một bảng đã sinh. Admin, hoặc người chấm của chính tổ ấy (P5j,
 * 15/09/2026 — trước đó chỉ admin).
 *
 * Có mặt vì hàm sinh từ chối tạo trùng khoảng ngày: muốn sinh lại sau khi
 * duyệt thêm phiên thì phải xoá bảng cũ. Xoá cứng chấp nhận được vì bảng là
 * kết quả TÍNH RA — số công và đơn giá vẫn nằm nguyên chỗ của chúng; chứng từ
 * PDF và sổ sửa tay sống sót khi bảng bị xoá.
 *
 * KHÔNG kiểm vai trò ở đây: policy `bang_delete_admin_hoac_nguoi_cham` trả
 * lời. Nhưng PostgREST không coi RLS-chặn-hết-dòng là lỗi — xoá không trúng
 * dòng nào vẫn trả `error === null` — nên phải đếm lại số dòng đã xoá.
 */
export async function xoaBangThanhToan(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  await batBuocPhien()

  const id = chuoi(form, 'id')
  if (!id) return { error: 'Thiếu bảng cần xoá.' }

  const supabase = await createClient()
  const { data, error } = await supabase
    .from('bang_thanh_toan_to')
    .delete()
    .eq('id', id)
    .select('id')
  if (error) return { error: `Không xoá được: ${error.message}` }
  if ((data ?? []).length === 0) return { error: KHONG_PHU_TRACH }

  revalidatePath('/nhan-su/to-doi/thanh-toan')
  redirect('/nhan-su/to-doi/thanh-toan?da_xoa=1')
}
