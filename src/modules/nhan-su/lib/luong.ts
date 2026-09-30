import { createClient } from '@ns/lib/supabase/server'
import type { PayrollPeriod, Payslip, PayslipItem } from '@ns/types/database'

/**
 * Truy vấn lương phía server. Đi qua client thường nên RLS vẫn áp dụng.
 *
 * Nhân viên chỉ thấy phiếu của mình; trưởng phòng KHÔNG thấy phiếu của cấp
 * dưới; HR đọc; kế toán và admin đọc và ghi. Rỗng có thể là "không có dữ
 * liệu" hoặc "không có quyền" — cố ý không phân biệt.
 */

export type PhieuVoiKy = Payslip & {
  payroll_periods:
    | (Pick<PayrollPeriod, 'month' | 'year' | 'status' | 'closed_at'> & {
        companies: { name: string; han_xac_nhan_phieu_ngay: number | null } | null
      })
    | null
}

/**
 * Hạn xác nhận của một phiếu, hoặc null nếu công ty chưa khai hạn.
 *
 * Đếm từ lúc CHỐT kỳ chứ không phải lúc tính lương: chốt mới là lúc phiếu
 * được gửi đi, và trước đó con số còn đổi được.
 */
export function hanXacNhan(phieu: PhieuVoiKy): Date | null {
  const ky = phieu.payroll_periods
  const soNgay = ky?.companies?.han_xac_nhan_phieu_ngay
  if (!ky?.closed_at || soNgay == null) return null
  const han = new Date(ky.closed_at)
  han.setDate(han.getDate() + soNgay)
  return han
}

export async function layKyLuong(): Promise<PayrollPeriod[]> {
  const supabase = await createClient()
  const { data, error } = await supabase
    .from('payroll_periods')
    .select('*')
    .order('year', { ascending: false })
    .order('month', { ascending: false })

  if (error) throw new Error(`Không đọc được danh sách kỳ lương: ${error.message}`)
  return data ?? []
}

export async function layPhieuCuaToi(): Promise<PhieuVoiKy[]> {
  const supabase = await createClient()
  const { data, error } = await supabase
    .from('payslips')
    .select(
      '*, payroll_periods ( month, year, status, closed_at, companies ( name, han_xac_nhan_phieu_ngay ) )',
    )
    .order('created_at', { ascending: false })
    .limit(24)

  if (error) throw new Error(`Không đọc được phiếu lương: ${error.message}`)
  return data ?? []
}

export type PhieuVoiNguoi = Payslip & {
  employees: { employee_code: string; full_name: string } | null
}

export async function layBangLuongCuaKy(periodId: string): Promise<PhieuVoiNguoi[]> {
  const supabase = await createClient()
  const { data, error } = await supabase
    .from('payslips')
    .select('*, employees ( employee_code, full_name )')
    .eq('period_id', periodId)

  if (error) throw new Error(`Không đọc được bảng lương: ${error.message}`)
  // Sắp theo mã nhân viên ở phía JS: PostgREST không sắp được theo cột của
  // bảng nhúng mà không dùng cú pháp khó đọc. Dưới 50 người nên không đáng kể.
  return (data ?? []).sort((a, b) =>
    (a.employees?.employee_code ?? '').localeCompare(b.employees?.employee_code ?? ''),
  )
}

export type DongTienDo = {
  employee_code: string
  full_name: string
  trang_thai: 'cho_xac_nhan' | 'da_xac_nhan' | 'thac_mac'
  tu_dong: boolean
  xac_nhan_luc: string | null
  ly_do: string | null
}

/**
 * Ai đã xác nhận, ai chưa, ai đang thắc mắc.
 *
 * Hàm SQL chạy SECURITY INVOKER nên RLS của `payslips` vẫn áp: nhân viên
 * thường gọi vào chỉ thấy đúng dòng của mình. Không cần kiểm vai trò ở đây.
 */
export async function layTienDoXacNhan(periodId: string): Promise<DongTienDo[]> {
  const supabase = await createClient()
  const { data, error } = await supabase.rpc('tien_do_xac_nhan_ky', { p_period_id: periodId })

  if (error) throw new Error(`Không đọc được tiến độ xác nhận: ${error.message}`)
  return (data ?? []) as DongTienDo[]
}

export async function layChiTietPhieu(payslipId: string): Promise<PayslipItem[]> {
  const supabase = await createClient()
  const { data, error } = await supabase
    .from('payslip_items')
    .select('*')
    .eq('payslip_id', payslipId)
    .order('item_type')

  if (error) throw new Error(`Không đọc được chi tiết phiếu lương: ${error.message}`)
  return data ?? []
}

/** Bộ tham số lương hiện có — dùng cho màn quản trị và để cảnh báo khi thiếu. */
export async function layThamSoLuong() {
  const supabase = await createClient()
  const [bh, bac, gt, ls, ltt, ot] = await Promise.all([
    supabase.from('cfg_insurance_rates').select('*').order('effective_from', { ascending: false }),
    supabase.from('cfg_pit_brackets').select('*').order('effective_from', { ascending: false }).order('level'),
    supabase.from('cfg_pit_deductions').select('*').order('effective_from', { ascending: false }),
    supabase.from('cfg_base_salary').select('*').order('effective_from', { ascending: false }),
    supabase.from('cfg_region_min_wage').select('*').order('effective_from', { ascending: false }).order('region'),
    supabase.from('cfg_overtime_rates').select('*').order('effective_from', { ascending: false }),
  ])

  return {
    baoHiem: bh.data ?? [],
    bacThue: bac.data ?? [],
    giamTru: gt.data ?? [],
    luongCoSo: ls.data ?? [],
    luongToiThieu: ltt.data ?? [],
    lamThem: ot.data ?? [],
  }
}
