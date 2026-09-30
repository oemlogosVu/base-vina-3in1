import { createClient } from '@ns/lib/supabase/server'
import type { Dependent, Employee, EmployeeSensitive, LaborContract } from '@ns/types/database'

/**
 * Toàn bộ dữ liệu một hồ sơ nhân sự, đọc qua RLS.
 *
 * Các phần `nhayCam`, `hopDong`, `nguoiPhuThuoc` có thể rỗng vì hai lý do khác
 * nhau — chưa nhập dữ liệu, hoặc người đang xem không có quyền. Postgres cố ý
 * không phân biệt hai trường hợp này (nếu phân biệt thì chính việc báo "bạn
 * không có quyền" đã là rò rỉ thông tin). Tầng UI diễn giải theo vai trò.
 */
export type MucLuong = {
  id: string
  contract_id: string
  tu_ngay: string
  position_salary: number
  bhxh_salary: number
  ly_do: string | null
}

export type ChucDanhLichSu = {
  id: string
  position_id: string
  tu_ngay: string
  den_ngay: string | null
  la_chinh: boolean
  ly_do: string | null
  positions: { code: string; name: string } | null
}

/** Chức danh CHÍNH đang hiệu lực hôm nay, hoặc null nếu chưa gán. */
export function chucDanhChinhHienTai(ds: ChucDanhLichSu[]): ChucDanhLichSu | null {
  return ds.find((c) => c.la_chinh && c.den_ngay === null) ?? null
}

export type ChiTietHoSo = {
  employee: Employee
  nhayCam: EmployeeSensitive | null
  hopDong: LaborContract[]
  /** Lịch sử mức lương, mới nhất trước. Rỗng cũng có thể là do RLS chặn. */
  mucLuong: MucLuong[]
  /** Chức danh theo thời gian — cả chính lẫn kiêm, mới nhất trước. */
  chucDanh: ChucDanhLichSu[]
  nguoiPhuThuoc: Dependent[]
  tenPhongBan: string | null
  tenChucDanh: string | null
  tenQuanLy: string | null
}

/** NULL khi không tìm thấy hồ sơ HOẶC người đang xem không được phép thấy. */
export async function layChiTietHoSo(employeeId: string): Promise<ChiTietHoSo | null> {
  const supabase = await createClient()

  const { data: employee, error: loiNV } = await supabase
    .from('employees')
    .select('*')
    .eq('id', employeeId)
    .maybeSingle()

  if (loiNV) throw new Error(`Không đọc được hồ sơ: ${loiNV.message}`)
  if (!employee) return null

  const [{ data: nhayCam }, { data: hopDong }, { data: nguoiPhuThuoc }] = await Promise.all([
    supabase.from('employee_sensitive').select('*').eq('employee_id', employeeId).maybeSingle(),
    supabase
      .from('labor_contracts')
      .select('*')
      .eq('employee_id', employeeId)
      .order('start_date', { ascending: false }),
    supabase.from('dependents').select('*').eq('employee_id', employeeId).order('full_name'),
  ])

  // Chức danh KHÔNG còn là một cột trên hồ sơ từ 19/08/2026 — cả chức danh
  // chính lẫn chức danh kiêm đều là dòng có kỳ hiệu lực trong bảng này.
  const { data: chucDanh } = await supabase
    .from('nhan_vien_chuc_danh')
    .select('id, position_id, tu_ngay, den_ngay, la_chinh, ly_do, positions ( code, name )')
    .eq('employee_id', employeeId)
    .order('tu_ngay', { ascending: false })

  const chinhHienTai = chucDanhChinhHienTai(
    (chucDanh ?? []) as unknown as ChucDanhLichSu[],
  )

  // Lương cũng không nằm trên hợp đồng — mỗi mức có ngày hiệu lực riêng. Đọc
  // theo danh sách hợp đồng vừa lấy nên RLS đã lọc sẵn.
  const { data: mucLuong } = await supabase
    .from('muc_luong_hop_dong')
    .select('id, contract_id, tu_ngay, position_salary, bhxh_salary, ly_do')
    .in('contract_id', (hopDong ?? []).map((h) => h.id))
    .order('tu_ngay', { ascending: false })

  const [{ data: phong }, { data: tenCD }, { data: quanLy }] = await Promise.all([
    employee.department_id
      ? supabase.from('departments').select('name').eq('id', employee.department_id).maybeSingle()
      : Promise.resolve({ data: null }),
    chinhHienTai
      ? supabase.from('positions').select('name').eq('id', chinhHienTai.position_id).maybeSingle()
      : Promise.resolve({ data: null }),
    employee.manager_id
      ? supabase.from('employees').select('full_name').eq('id', employee.manager_id).maybeSingle()
      : Promise.resolve({ data: null }),
  ])

  return {
    employee,
    nhayCam: nhayCam ?? null,
    hopDong: hopDong ?? [],
    mucLuong: (mucLuong ?? []) as MucLuong[],
    chucDanh: (chucDanh ?? []) as unknown as ChucDanhLichSu[],
    nguoiPhuThuoc: nguoiPhuThuoc ?? [],
    tenPhongBan: phong?.name ?? null,
    tenChucDanh: tenCD?.name ?? null,
    tenQuanLy: quanLy?.full_name ?? null,
  }
}

/**
 * Dữ liệu cần cho khối "Hợp đồng lao động" trong biểu mẫu nhân sự.
 *
 * Gom về một chỗ vì cả màn THÊM lẫn màn SỬA đều cần, và hai bản chép sẽ lệch
 * — nhất là quy tắc tách dòng phụ cấp lạ, thứ quyết định có xoá mất tiền của
 * người ta hay không.
 *
 * @param employeeId null khi đang thêm người mới
 * @param positionId chức danh đang chọn, để hiện mức mặc định bên cạnh ô nhập
 */
export async function layBoiCanhHopDong(employeeId: string | null, positionId: string | null) {
  const supabase = await createClient()

  const [{ data: loai }, { data: hd }, { data: mucChucDanh }] = await Promise.all([
    supabase
      .from('allowance_types')
      .select('id, code, name, is_taxable, is_insurance')
      .eq('is_active', true)
      .order('code'),
    employeeId
      ? supabase
          .from('labor_contracts')
          .select('id, contract_no, type, start_date, end_date, allowances')
          .eq('employee_id', employeeId)
          .eq('is_active', true)
          .maybeSingle()
      : Promise.resolve({ data: null }),
    positionId
      ? supabase
          .from('position_allowances')
          .select('amount, allowance_types ( code )')
          .eq('position_id', positionId)
      : Promise.resolve({ data: null }),
  ])

  const danhMuc = loai ?? []
  const maBiet = new Set(danhMuc.map((l) => l.code))

  type Dong = { type_code?: string; name?: string; amount?: number }
  const dong: Dong[] = Array.isArray(hd?.allowances) ? (hd.allowances as Dong[]) : []

  // Dòng có mã loại đã biết → hiện lên ô nhập. Dòng còn lại → giữ nguyên,
  // hiện ra để người dùng biết nó tồn tại nhưng không sửa được ở đây.
  const phu_cap: Record<string, number> = {}
  const phuCapLa: { name: string; amount: number }[] = []
  for (const d of dong) {
    if (d?.type_code && maBiet.has(d.type_code)) phu_cap[d.type_code] = Number(d.amount ?? 0)
    else phuCapLa.push({ name: d?.name ?? 'Không tên', amount: Number(d?.amount ?? 0) })
  }

  const mucTheoChucDanh: Record<string, number> = {}
  for (const m of mucChucDanh ?? []) {
    const ma = (m.allowance_types as { code: string } | null)?.code
    if (ma) mucTheoChucDanh[ma] = Number(m.amount)
  }

  return {
    loaiPhuCap: danhMuc,
    mucTheoChucDanh,
    hopDong: {
      id: hd?.id ?? null,
      contract_no: hd?.contract_no ?? '',
      type: hd?.type ?? 'thu_viec',
      start_date: hd?.start_date ?? null,
      end_date: hd?.end_date ?? null,
      phu_cap,
      phuCapLa,
    },
  }
}
