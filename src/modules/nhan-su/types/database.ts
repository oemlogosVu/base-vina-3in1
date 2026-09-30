/**
 * Type nghiệp vụ, dựng trên schema sinh tự động.
 *
 * `database.generated.ts` do `npm run db:types` sinh ra từ schema thật —
 * KHÔNG sửa tay file đó, mọi thay đổi sẽ mất ở lần sinh sau.
 * Phần bổ sung của người viết (nhãn tiếng Việt, alias tiện dùng) nằm ở đây.
 */

import type { Database } from './database.generated'

export type { Database, Json } from './database.generated'

type Bang = Database['public']['Tables']
type Enums = Database['public']['Enums']

export type UserRole = Enums['user_role']
export type EmployeeStatus = Enums['employee_status']
export type ContractType = Enums['contract_type']
export type CheckType = Enums['check_type']
export type AttendanceDayStatus = Enums['attendance_day_status']
export type PeriodStatus = Enums['period_status']

export type AppUser = Bang['app_users']['Row']
export type Department = Bang['departments']['Row']
export type Position = Bang['positions']['Row']
export type Employee = Bang['employees']['Row']
export type EmployeeSensitive = Bang['employee_sensitive']['Row']
export type Dependent = Bang['dependents']['Row']
export type LaborContract = Bang['labor_contracts']['Row']
export type EmployeeDocument = Bang['employee_documents']['Row']
export type WorkShift = Bang['work_shifts']['Row']
export type Company = Bang['companies']['Row']
export type AttendanceLog = Bang['attendance_logs']['Row']
export type AttendanceDay = Bang['attendance_days']['Row']
export type PayrollPeriod = Bang['payroll_periods']['Row']
export type Payslip = Bang['payslips']['Row']
export type PayslipItem = Bang['payslip_items']['Row']
export type CfgInsuranceRates = Bang['cfg_insurance_rates']['Row']
export type CfgPitBracket = Bang['cfg_pit_brackets']['Row']
export type CfgPitDeductions = Bang['cfg_pit_deductions']['Row']
export type CfgOvertimeRates = Bang['cfg_overtime_rates']['Row']

/** Nhãn tiếng Việt của vai trò — chỉ để hiển thị, không dùng để so sánh logic. */
export const ROLE_LABELS: Record<UserRole, string> = {
  nhan_vien: 'Nhân viên',
  truong_phong: 'Trưởng phòng',
  hr: 'Nhân sự (HR)',
  ke_toan: 'Kế toán',
  admin: 'Quản trị hệ thống',
}

export const EMPLOYEE_STATUS_LABELS: Record<EmployeeStatus, string> = {
  thu_viec: 'Thử việc',
  chinh_thuc: 'Chính thức',
  cong_tac_vien: 'Cộng tác viên',
  nghi_viec: 'Đã nghỉ việc',
  tam_hoan: 'Tạm hoãn hợp đồng',
}

export const CONTRACT_TYPE_LABELS: Record<ContractType, string> = {
  thu_viec: 'Thử việc',
  xac_dinh_thoi_han: 'Xác định thời hạn',
  khong_xac_dinh: 'Không xác định thời hạn',
  thoi_vu: 'Thời vụ / theo mùa',
}

export const GENDER_LABELS: Record<string, string> = {
  nam: 'Nam',
  nu: 'Nữ',
  khac: 'Khác',
}

export const CHECK_TYPE_LABELS: Record<CheckType, string> = {
  in: 'Vào',
  out: 'Ra',
  ot_in: 'Thêm giờ — vào',
  ot_out: 'Thêm giờ — ra',
}

export const ATTENDANCE_DAY_STATUS_LABELS: Record<AttendanceDayStatus, string> = {
  du_cong: 'Đủ công',
  thieu_gio: 'Thiếu giờ',
  thieu_cham_ra: 'Quên chấm ra',
  nghi: 'Nghỉ',
  // Chủ nhật có người đi làm: giờ làm thường bằng 0, toàn bộ vào phút làm
  // thêm. Không dùng "Đủ công" vì nhìn bảng công sẽ thấy đủ công mà 0 giờ.
  lam_ngay_nghi: 'Làm ngày nghỉ',
}

export const PERIOD_STATUS_LABELS: Record<PeriodStatus, string> = {
  mo: 'Đang mở',
  da_chot: 'Đã chốt',
  da_tra: 'Đã trả',
}
