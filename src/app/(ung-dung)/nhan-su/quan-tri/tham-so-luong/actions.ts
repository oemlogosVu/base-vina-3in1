'use server'

import { revalidatePath } from 'next/cache'
import { createClient } from '@ns/lib/supabase/server'
import { batBuocVaiTro } from '@ns/lib/phien'

export type TrangThaiForm = { error: string | null; xong?: string }

/**
 * Nhập tham số tính lương.
 *
 * Mọi bảng ở đây đều có `effective_from`: nhập dòng mới chứ KHÔNG sửa dòng
 * cũ. Sửa dòng cũ là làm sai lại bảng lương của các kỳ đã tính trước đó —
 * engine chọn tham số theo ngày cuối kỳ, nên tính lại tháng 3 vào tháng 8
 * phải ra đúng con số của tháng 3.
 *
 * Chỉ admin. Lớp chặn thật là RLS: policy insert/update trên cfg_* chỉ mở
 * cho vai trò admin.
 */

const so = (form: FormData, ten: string): number | null => {
  const v = String(form.get(ten) ?? '').trim()
  if (v === '') return null
  const n = Number(v)
  return Number.isFinite(n) ? n : null
}

const ngay = (form: FormData): string | null => {
  const v = String(form.get('effective_from') ?? '').trim()
  return /^\d{4}-\d{2}-\d{2}$/.test(v) ? v : null
}

function loiTrung(error: { code?: string }, ten: string): string {
  return error.code === '23505'
    ? `Đã có ${ten} với ngày hiệu lực này. Chọn ngày khác hoặc sửa dòng cũ.`
    : ''
}

export async function themTyLeBaoHiem(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  await batBuocVaiTro('admin')
  const effective_from = ngay(form)
  if (!effective_from) return { error: 'Ngày hiệu lực không hợp lệ.' }

  const truong = [
    'bhxh_employee_pct', 'bhxh_employer_pct',
    'bhyt_employee_pct', 'bhyt_employer_pct',
    'bhtn_employee_pct', 'bhtn_employer_pct',
    'bhxh_cap_multiple', 'bhtn_cap_multiple',
  ] as const

  const giaTri: Record<string, number> = {}
  for (const t of truong) {
    const v = so(form, t)
    if (v === null) return { error: `Thiếu giá trị cho ${t}.` }
    giaTri[t] = v
  }

  const supabase = await createClient()
  const { error } = await supabase.from('cfg_insurance_rates').insert({
    effective_from,
    ...giaTri,
    nghi_khong_luong_mien_dong_ngay: so(form, 'nghi_khong_luong_mien_dong_ngay'),
    ghi_chu: String(form.get('ghi_chu') ?? '').trim() || null,
  } as never)

  if (error) return { error: loiTrung(error, 'tỷ lệ bảo hiểm') || `Không lưu được: ${error.message}` }

  revalidatePath('/nhan-su/quan-tri/tham-so-luong')
  return { error: null, xong: `Đã thêm tỷ lệ bảo hiểm hiệu lực từ ${effective_from}.` }
}

export async function themBacThue(_prev: TrangThaiForm, form: FormData): Promise<TrangThaiForm> {
  await batBuocVaiTro('admin')
  const effective_from = ngay(form)
  if (!effective_from) return { error: 'Ngày hiệu lực không hợp lệ.' }

  const level = so(form, 'level')
  const from_amount = so(form, 'from_amount')
  const to_amount = so(form, 'to_amount')
  const rate = so(form, 'rate')

  if (level === null || level < 1) return { error: 'Bậc phải là số nguyên từ 1.' }
  if (from_amount === null || from_amount < 0) return { error: 'Ngưỡng dưới không hợp lệ.' }
  if (rate === null || rate < 0 || rate > 100) return { error: 'Thuế suất phải từ 0 đến 100.' }
  if (to_amount !== null && to_amount <= from_amount) {
    return { error: 'Ngưỡng trên phải lớn hơn ngưỡng dưới. Bậc cuối cùng thì để trống.' }
  }

  const supabase = await createClient()
  const { error } = await supabase
    .from('cfg_pit_brackets')
    .insert({ effective_from, level, from_amount, to_amount, rate })

  if (error) return { error: loiTrung(error, 'bậc thuế') || `Không lưu được: ${error.message}` }

  revalidatePath('/nhan-su/quan-tri/tham-so-luong')
  return { error: null, xong: `Đã thêm bậc ${level}.` }
}

export async function themGiamTru(_prev: TrangThaiForm, form: FormData): Promise<TrangThaiForm> {
  await batBuocVaiTro('admin')
  const effective_from = ngay(form)
  const personal_amount = so(form, 'personal_amount')
  const dependent_amount = so(form, 'dependent_amount')

  if (!effective_from) return { error: 'Ngày hiệu lực không hợp lệ.' }
  if (personal_amount === null || dependent_amount === null) {
    return { error: 'Thiếu mức giảm trừ bản thân hoặc người phụ thuộc.' }
  }

  const supabase = await createClient()
  const { error } = await supabase
    .from('cfg_pit_deductions')
    .insert({ effective_from, personal_amount, dependent_amount })

  if (error) return { error: loiTrung(error, 'mức giảm trừ') || `Không lưu được: ${error.message}` }

  revalidatePath('/nhan-su/quan-tri/tham-so-luong')
  return { error: null, xong: 'Đã thêm mức giảm trừ gia cảnh.' }
}

export async function themLuongCoSo(_prev: TrangThaiForm, form: FormData): Promise<TrangThaiForm> {
  await batBuocVaiTro('admin')
  const effective_from = ngay(form)
  const amount = so(form, 'amount')
  if (!effective_from) return { error: 'Ngày hiệu lực không hợp lệ.' }
  if (amount === null || amount <= 0) return { error: 'Lương cơ sở phải lớn hơn 0.' }

  const supabase = await createClient()
  const { error } = await supabase.from('cfg_base_salary').insert({ effective_from, amount })
  if (error) return { error: loiTrung(error, 'lương cơ sở') || `Không lưu được: ${error.message}` }

  revalidatePath('/nhan-su/quan-tri/tham-so-luong')
  return { error: null, xong: 'Đã thêm lương cơ sở.' }
}

export async function themLuongToiThieu(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  await batBuocVaiTro('admin')
  const effective_from = ngay(form)
  const region = so(form, 'region')
  const amount = so(form, 'amount')
  if (!effective_from) return { error: 'Ngày hiệu lực không hợp lệ.' }
  if (region === null || region < 1 || region > 4) return { error: 'Vùng phải từ 1 đến 4.' }
  if (amount === null || amount <= 0) return { error: 'Mức lương phải lớn hơn 0.' }

  const supabase = await createClient()
  const { error } = await supabase
    .from('cfg_region_min_wage')
    .insert({ effective_from, region, amount })
  if (error) {
    return { error: loiTrung(error, 'lương tối thiểu vùng này') || `Không lưu được: ${error.message}` }
  }

  revalidatePath('/nhan-su/quan-tri/tham-so-luong')
  return { error: null, xong: `Đã thêm lương tối thiểu vùng ${region}.` }
}

export async function themHeSoLamThem(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  await batBuocVaiTro('admin')
  const effective_from = ngay(form)
  const ngay_thuong_pct = so(form, 'ngay_thuong_pct')
  const ngay_nghi_tuan_pct = so(form, 'ngay_nghi_tuan_pct')
  const ngay_le_pct = so(form, 'ngay_le_pct')

  if (!effective_from) return { error: 'Ngày hiệu lực không hợp lệ.' }
  if (ngay_thuong_pct === null || ngay_nghi_tuan_pct === null || ngay_le_pct === null) {
    return { error: 'Thiếu một trong ba hệ số.' }
  }
  if (ngay_thuong_pct < 100 || ngay_nghi_tuan_pct < 100 || ngay_le_pct < 100) {
    return { error: 'Hệ số làm thêm không được thấp hơn 100%.' }
  }

  const supabase = await createClient()
  const { error } = await supabase.from('cfg_overtime_rates').insert({
    effective_from,
    ngay_thuong_pct,
    ngay_nghi_tuan_pct,
    ngay_le_pct,
    ghi_chu: String(form.get('ghi_chu') ?? '').trim() || null,
  })

  if (error) return { error: loiTrung(error, 'hệ số làm thêm') || `Không lưu được: ${error.message}` }

  revalidatePath('/nhan-su/quan-tri/tham-so-luong')
  return { error: null, xong: 'Đã thêm hệ số làm thêm giờ.' }
}
