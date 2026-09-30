'use server'

import { revalidatePath } from 'next/cache'
import { createClient } from '@ns/lib/supabase/server'
import { sinhChungTu } from '@ns/lib/chung-tu'
import { batBuocCong, CONG_QUAN_LY_LUONG } from '@ns/lib/phien'

export type TrangThaiForm = { error: string | null; xong?: string }

const so = (form: FormData, ten: string): number | null => {
  const v = String(form.get(ten) ?? '').trim()
  if (v === '') return null
  const n = Number(v)
  return Number.isFinite(n) ? n : null
}

/**
 * Kỳ lương và engine tính lương.
 *
 * Kiểm vai trò ở đây chỉ để báo lỗi sớm và cho thông báo dễ đọc. Lớp chặn
 * thật nằm ở database: `tinh_luong_ky` và `thue_tncn` đã bị thu hồi quyền
 * execute của `authenticated`, chỉ các hàm vỏ bọc có kiểm vai trò mới gọi
 * được. Kể cả gọi thẳng PostgREST cũng không tính được lương.
 */

export async function taoKyLuong(_prev: TrangThaiForm, form: FormData): Promise<TrangThaiForm> {
  await batBuocCong(CONG_QUAN_LY_LUONG)

  const companyId = String(form.get('company_id') ?? '').trim()
  const month = so(form, 'month')
  const year = so(form, 'year')
  const standardDays = so(form, 'standard_days')

  // Kỳ lương thuộc về MỘT pháp nhân. Gộp hai công ty vào một kỳ là trộn sổ
  // sách của hai doanh nghiệp khác nhau — khai thuế và BHXH là việc riêng của
  // từng pháp nhân.
  if (companyId === '') return { error: 'Chọn công ty cho kỳ lương này.' }
  if (month === null || month < 1 || month > 12) return { error: 'Tháng phải từ 1 đến 12.' }
  if (year === null || year < 2020 || year > 2100) return { error: 'Năm không hợp lệ.' }
  if (standardDays !== null && (standardDays <= 0 || standardDays > 31)) {
    return { error: 'Công tiêu chuẩn phải lớn hơn 0 và không quá 31.' }
  }

  const supabase = await createClient()

  // Bỏ trống thì lấy mức của công ty, KHÔNG rơi về một hằng số của màn hình.
  // Con số 22 mặc định cũ là mẫu số do biểu mẫu bịa ra: không ai khai, không
  // ai đối chiếu được, mà nó chia toàn bộ bảng lương.
  //
  // Trigger `dat_cong_chuan_cho_ky` làm đúng việc này ở tầng database cho
  // script và PostgREST. Đọc lại ở đây chỉ để báo lỗi bằng tiếng người khi
  // công ty chưa khai, thay vì ném nguyên văn lỗi plpgsql lên màn hình.
  let congChuan = standardDays
  if (congChuan === null) {
    const { data: cty } = await supabase
      .from('companies')
      .select('name, standard_days')
      .eq('id', companyId)
      .maybeSingle()

    if (!cty) return { error: 'Không tìm thấy công ty này.' }
    if (cty.standard_days === null) {
      return {
        error: `${cty.name} chưa khai công tiêu chuẩn. Vào Quản trị → Công ty nhập số ngày công tiêu chuẩn, hoặc gõ số cho riêng kỳ này.`,
      }
    }
    congChuan = cty.standard_days
  }

  const { error } = await supabase
    .from('payroll_periods')
    .insert({ company_id: companyId, month, year, standard_days: congChuan })

  if (error) {
    if (error.code === '23505') {
      return { error: `Công ty này đã có kỳ lương ${month}/${year}.` }
    }
    // Trigger nói rõ công ty nào chưa khai công tiêu chuẩn — hiện nguyên văn.
    return { error: `Không tạo được kỳ lương: ${error.message}` }
  }

  revalidatePath('/nhan-su/luong/ky-luong')
  return { error: null, xong: `Đã tạo kỳ ${month}/${year}.` }
}

export async function tinhLuong(_prev: TrangThaiForm, form: FormData): Promise<TrangThaiForm> {
  await batBuocCong(CONG_QUAN_LY_LUONG)

  const id = String(form.get('period_id') ?? '').trim()
  if (!id) return { error: 'Thiếu mã kỳ lương.' }

  const supabase = await createClient()
  const { data, error } = await supabase.rpc('tinh_luong_ky_cua_toi', { p_period_id: id })

  if (error) {
    // Engine ném lỗi có nội dung khi thiếu tham số hoặc khi kết quả vô lý.
    // Hiện nguyên văn: nó nói rõ thiếu bảng nào hoặc nhân viên nào có vấn đề,
    // hữu ích hơn nhiều so với một câu chung chung.
    return { error: error.message }
  }

  revalidatePath('/nhan-su/luong/ky-luong')
  return { error: null, xong: `Đã tính xong ${data ?? 0} phiếu lương.` }
}

export async function chotKyLuong(_prev: TrangThaiForm, form: FormData): Promise<TrangThaiForm> {
  await batBuocCong(CONG_QUAN_LY_LUONG)

  const id = String(form.get('period_id') ?? '').trim()
  if (!id) return { error: 'Thiếu mã kỳ lương.' }

  const supabase = await createClient()
  const { error } = await supabase.rpc('chot_ky_luong', { p_period_id: id })

  if (error) return { error: error.message }

  // Chứng từ sinh NGAY SAU khi chốt, theo yêu cầu 24/08/2026 của Triệu Vũ.
  //
  // Ngoài giao dịch chốt, và cố ý: đây là một lời gọi mạng, buộc nó vào giao
  // dịch nghĩa là một lần Edge Function lỗi sẽ chặn luôn việc chốt kỳ. Kỳ đã
  // chốt rồi thì chốt xong là xong — chứng từ hỏng chỉ báo thêm một câu, và
  // màn kỳ lương có nút sinh lại.
  const { chungTu, loi: loiChungTu } = await sinhChungTu('ky_luong', id)

  revalidatePath('/nhan-su/luong/ky-luong')
  revalidatePath('/nhan-su/luong')

  const cauChinh =
    'Đã chốt kỳ và gửi phiếu cho người lao động. Phiếu chỉ hợp lệ khi chính họ bấm xác nhận.'

  if (loiChungTu) {
    return {
      error: null,
      xong: `${cauChinh} NHƯNG chưa sinh được chứng từ PDF: ${loiChungTu} — bấm "Sinh chứng từ" ở danh sách kỳ để làm lại.`,
    }
  }

  return {
    error: null,
    xong: `${cauChinh} Đã lưu chứng từ ${chungTu?.so_hieu ?? ''}.`,
  }
}

/**
 * Người lao động xác nhận hoặc thắc mắc phiếu lương của chính mình.
 *
 * KHÔNG kiểm vai trò ở đây: mọi người đều có quyền ký phiếu của mình, kể cả
 * nhân viên thường. Lớp chặn thật nằm trong hàm database — nó so
 * `employee_id` của phiếu với `current_employee_id()`, nên không ai ký hộ
 * được, kể cả admin gọi thẳng PostgREST.
 */
export async function xacNhanPhieu(_prev: TrangThaiForm, form: FormData): Promise<TrangThaiForm> {
  const id = String(form.get('payslip_id') ?? '').trim()
  if (!id) return { error: 'Thiếu mã phiếu lương.' }

  const supabase = await createClient()
  const { error } = await supabase.rpc('xac_nhan_phieu_luong', { p_payslip_id: id })

  if (error) return { error: error.message }

  revalidatePath('/nhan-su/luong')
  revalidatePath('/nhan-su/luong/ky-luong')
  return { error: null, xong: 'Đã ghi nhận xác nhận của bạn. Phiếu lương này giờ là hợp lệ.' }
}

export async function thacMacPhieu(_prev: TrangThaiForm, form: FormData): Promise<TrangThaiForm> {
  const id = String(form.get('payslip_id') ?? '').trim()
  const lyDo = String(form.get('ly_do') ?? '').trim()
  if (!id) return { error: 'Thiếu mã phiếu lương.' }
  if (lyDo === '') {
    return { error: 'Nêu rõ chỗ nào chưa đúng — nhân sự cần biết kiểm lại cái gì.' }
  }

  const supabase = await createClient()
  const { error } = await supabase.rpc('thac_mac_phieu_luong', {
    p_payslip_id: id,
    p_ly_do: lyDo,
  })

  if (error) return { error: error.message }

  revalidatePath('/nhan-su/luong')
  revalidatePath('/nhan-su/luong/ky-luong')
  return {
    error: null,
    xong: 'Đã gửi thắc mắc tới nhân sự. Kỳ lương này chưa được đánh dấu đã trả cho tới khi giải quyết xong.',
  }
}

export async function danhDauDaTra(_prev: TrangThaiForm, form: FormData): Promise<TrangThaiForm> {
  await batBuocCong(CONG_QUAN_LY_LUONG)

  const id = String(form.get('period_id') ?? '').trim()
  if (!id) return { error: 'Thiếu mã kỳ lương.' }

  const supabase = await createClient()
  const { error } = await supabase.rpc('danh_dau_da_tra', { p_period_id: id })

  // Lỗi từ hàm này nêu ĐÍCH DANH ai chưa xác nhận — hiện nguyên văn, vì đó
  // chính là danh sách người cần đi đôn.
  if (error) return { error: error.message }

  revalidatePath('/nhan-su/luong/ky-luong')
  return { error: null, xong: 'Đã đánh dấu kỳ lương này là đã trả.' }
}
