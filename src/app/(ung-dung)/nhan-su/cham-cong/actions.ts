'use server'

import { revalidatePath } from 'next/cache'
import { createClient } from '@ns/lib/supabase/server'
import { batBuocCong, CONG_XAC_NHAN_CHAM_CONG } from '@ns/lib/phien'

export type TrangThaiForm = { error: string | null; xong?: string }

/**
 * Xác nhận chấm công.
 *
 * Từ 11/08/2026: mọi lần chấm đều phải được nhân sự xác nhận mới được tính
 * công. Máy không còn phán xét hợp lệ hay không — nó chỉ ghi lại thời điểm.
 *
 * Kiểm vai trò ở đây chỉ để báo lỗi sớm. Lớp chặn thật là hai lớp ở database:
 * policy update chỉ mở cho nhân sự/admin, VÀ grant cấp cột chỉ cho sửa đúng
 * bốn cột xác nhận. Kể cả gọi thẳng PostgREST cũng không sửa được giờ đã chấm.
 */

export async function xacNhanMotLan(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  const phien = await batBuocCong(CONG_XAC_NHAN_CHAM_CONG)

  const id = String(form.get('id') ?? '').trim()
  const quyetDinh = String(form.get('quyet_dinh') ?? '')
  const ghiChu = String(form.get('ghi_chu') ?? '').trim()

  if (!id) return { error: 'Thiếu mã lần chấm công.' }
  if (quyetDinh !== 'cong_nhan' && quyetDinh !== 'tu_choi') {
    return { error: 'Quyết định không hợp lệ.' }
  }
  if (quyetDinh === 'tu_choi' && ghiChu === '') {
    // Từ chối mà không nói lý do thì nhân viên không có gì để phản hồi, và
    // người xem lại sau này không hiểu vì sao.
    return { error: 'Không công nhận thì phải ghi lý do.' }
  }

  const supabase = await createClient()
  const { error } = await supabase
    .from('attendance_logs')
    .update({
      da_xac_nhan: quyetDinh === 'cong_nhan',
      xac_nhan_boi: phien.userId,
      xac_nhan_luc: new Date().toISOString(),
      ghi_chu_xac_nhan: ghiChu === '' ? null : ghiChu,
    })
    .eq('id', id)

  if (error) return { error: `Không lưu được quyết định: ${error.message}` }

  revalidatePath('/nhan-su/cham-cong/xac-nhan')
  return {
    error: null,
    xong:
      quyetDinh === 'cong_nhan'
        ? 'Đã công nhận. Nhớ tổng hợp lại bảng công của ngày đó.'
        : 'Đã ghi nhận không công nhận.',
  }
}

/**
 * Xác nhận toàn bộ lần chấm chưa xử lý của một ngày.
 *
 * Không có nút này thì với 50 nhân viên chấm 2 lần/ngày, nhân sự phải bấm
 * 100 lần mỗi ngày — tính năng xác nhận sẽ không dùng được trong thực tế và
 * người ta sẽ tìm cách lách.
 *
 * Hàm database tự tổng hợp lại bảng công ngay sau khi xác nhận, để người dùng
 * không phải làm hai bước và không tưởng nút không ăn.
 */
export async function xacNhanCaNgay(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  await batBuocCong(CONG_XAC_NHAN_CHAM_CONG)

  const ngay = String(form.get('ngay') ?? '').trim()
  if (!/^\d{4}-\d{2}-\d{2}$/.test(ngay)) return { error: 'Ngày không hợp lệ.' }

  const ghiChu = String(form.get('ghi_chu') ?? '').trim()

  const supabase = await createClient()
  const { data, error } = await supabase.rpc('xac_nhan_cham_cong_ngay', {
    p_ngay: ngay,
    p_ghi_chu: ghiChu === '' ? undefined : ghiChu,
  })

  if (error) return { error: `Không xác nhận được: ${error.message}` }

  revalidatePath('/nhan-su/cham-cong/xac-nhan')
  return {
    error: null,
    xong: `Đã xác nhận ${data ?? 0} lần chấm của ngày ${ngay} và tổng hợp lại bảng công.`,
  }
}

/** Tổng hợp lại bảng công một ngày, dùng khi đã xác nhận lẻ từng lần. */
export async function tongHopLai(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  await batBuocCong(CONG_XAC_NHAN_CHAM_CONG)

  const ngay = String(form.get('ngay') ?? '').trim()
  if (!/^\d{4}-\d{2}-\d{2}$/.test(ngay)) return { error: 'Ngày không hợp lệ.' }

  const supabase = await createClient()
  const { data, error } = await supabase.rpc('tong_hop_cong_ngay_cua_toi', { p_ngay: ngay })

  if (error) return { error: `Không tổng hợp được: ${error.message}` }

  revalidatePath('/nhan-su/cham-cong/xac-nhan')
  return { error: null, xong: `Đã tổng hợp lại ngày ${ngay}: ${data ?? 0} dòng công.` }
}

/**
 * Đặt tỷ lệ % làm thêm riêng cho một ngày của một người.
 *
 * Yêu cầu 12/08/2026: "làm ngày chủ nhật cho phép lựa chọn tỷ lệ % linh
 * động". Để trống ô nhập = quay về hệ số mặc định theo loại ngày trong bảng
 * tham số lương.
 *
 * KHÔNG tự tính lại lương ở đây. Bảng công đổi thì kỳ lương phải được người
 * có quyền bấm tính lại — tự tính lại là sửa số tiền của một kỳ mà kế toán
 * không biết. Thông báo nói rõ việc còn phải làm.
 */
export async function datTyLeLamThem(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  await batBuocCong(CONG_XAC_NHAN_CHAM_CONG)

  const id = String(form.get('ngay_cong_id') ?? '').trim()
  if (id === '') return { error: 'Thiếu dòng bảng công.' }

  const tho = String(form.get('ty_le') ?? '').trim()
  let tyLe: number | null = null
  if (tho !== '') {
    const n = Number(tho)
    if (!Number.isFinite(n) || n < 100) {
      return { error: 'Tỷ lệ làm thêm phải là số từ 100 trở lên. Để trống nếu muốn dùng mặc định.' }
    }
    tyLe = n
  }

  const supabase = await createClient()
  const { error } = await supabase
    .from('attendance_days')
    .update({ ty_le_lam_them_pct: tyLe })
    .eq('id', id)

  if (error) return { error: `Không lưu được tỷ lệ: ${error.message}` }

  revalidatePath('/nhan-su/cham-cong/xac-nhan')
  return {
    error: null,
    xong:
      tyLe === null
        ? 'Đã bỏ tỷ lệ riêng, ngày này quay về hệ số mặc định. Nhớ tính lại kỳ lương.'
        : `Đã đặt ${tyLe}% cho ngày này. Nhớ tính lại kỳ lương để số tiền cập nhật.`,
  }
}
