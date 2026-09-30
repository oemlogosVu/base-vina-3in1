'use server'

import { redirect } from 'next/navigation'
import { revalidatePath } from 'next/cache'
import { createClient } from '@ns/lib/supabase/server'
import { batBuocCong, CONG_SUA_NHAN_SU } from '@ns/lib/phien'
import type { ContractType, EmployeeStatus } from '@ns/types/database'

export type TrangThaiForm = { error: string | null; canhBao?: string }

const TRANG_THAI_HOP_LE: EmployeeStatus[] = [
  'thu_viec',
  'chinh_thuc',
  'cong_tac_vien',
  'nghi_viec',
  'tam_hoan',
]
const GIOI_TINH_HOP_LE = ['nam', 'nu', 'khac']

/** Chuỗi đã cắt khoảng trắng; rỗng thành NULL để không lưu chuỗi rỗng vào DB. */
function chuoi(form: FormData, ten: string): string | null {
  const v = String(form.get(ten) ?? '').trim()
  return v === '' ? null : v
}

/** Chỉ nhận đúng dạng yyyy-mm-dd của thẻ input[type=date]; sai dạng thì bỏ qua. */
function ngay(form: FormData, ten: string): string | null {
  const v = chuoi(form, ten)
  if (v === null) return null
  return /^\d{4}-\d{2}-\d{2}$/.test(v) ? v : null
}

/** Vùng lương tối thiểu 1..4. Giá trị ngoài khoảng bị loại, không tự ép về 1. */
function vung(form: FormData): number | null {
  const v = chuoi(form, 'region')
  if (v === null) return null
  const n = Number(v)
  return Number.isInteger(n) && n >= 1 && n <= 4 ? n : null
}

function motTrong(form: FormData, ten: string, choPhep: string[]): string | null {
  const v = chuoi(form, ten)
  return v !== null && choPhep.includes(v) ? v : null
}

/** Phần hồ sơ không nhạy cảm, đọc từ form. */
function docPhanChung(form: FormData) {
  return {
    full_name: String(form.get('full_name') ?? '').trim(),
    dob: ngay(form, 'dob'),
    gender: motTrong(form, 'gender', GIOI_TINH_HOP_LE),
    permanent_address: chuoi(form, 'permanent_address'),
    phone: chuoi(form, 'phone'),
    personal_email: chuoi(form, 'personal_email'),
    department_id: chuoi(form, 'department_id'),
    manager_id: chuoi(form, 'manager_id'),
    company_id: chuoi(form, 'company_id'),
    region: vung(form),
    hire_date: ngay(form, 'hire_date'),
    status: (motTrong(form, 'status', TRANG_THAI_HOP_LE) ?? 'thu_viec') as EmployeeStatus,
    // Checkbox không gửi gì khi bỏ tick, nên phải đọc theo kiểu "có mặt =
    // bật". Người mới mặc định phải chấm công; miễn là ngoại lệ và ngoại lệ
    // thì phải do người ta chủ động chọn.
    theo_doi_cham_cong: form.get('theo_doi_cham_cong') === 'on',
  }
}

/** Phần nhạy cảm, lưu ở bảng riêng employee_sensitive. */
function docPhanNhayCam(form: FormData) {
  return {
    cccd: chuoi(form, 'cccd'),
    cccd_issue_date: ngay(form, 'cccd_issue_date'),
    cccd_issue_place: chuoi(form, 'cccd_issue_place'),
    bank_account_no: chuoi(form, 'bank_account_no'),
    bank_name: chuoi(form, 'bank_name'),
    tax_code: chuoi(form, 'tax_code'),
    social_insurance_no: chuoi(form, 'social_insurance_no'),
  }
}

function coDuLieu(o: Record<string, string | null>): boolean {
  return Object.values(o).some((v) => v !== null)
}

/**
 * Hợp đồng lao động, đọc từ cùng biểu mẫu hồ sơ.
 *
 * Trước 12/08/2026 không màn nào ghi được vào `labor_contracts` — hợp đồng
 * chỉ vào bằng script. Mà engine lương nối bảng hợp đồng, nên người chưa có
 * hợp đồng thì KHÔNG có phiếu lương và không có gì báo cho ai biết.
 */
type DongPhuCap = {
  type_code?: string
  name: string
  amount: number
  taxable: boolean
  insurance: boolean
}

type KetQuaHopDong =
  | { bo_qua: true }
  | { bo_qua: false; loi: string }
  | {
      bo_qua: false
      loi: null
      id: string | null
      ghi: {
        contract_no: string
        type: ContractType
        start_date: string
        end_date: string | null
        allowances: DongPhuCap[]
      }
    }

const LOAI_HD_HOP_LE: ContractType[] = ['thu_viec', 'xac_dinh_thoi_han', 'khong_xac_dinh', 'thoi_vu']

function soTien(form: FormData, ten: string): number | null {
  const v = chuoi(form, ten)
  if (v === null) return null
  const n = Number(v)
  return Number.isFinite(n) && n >= 0 ? n : null
}

/**
 * Đọc phần hợp đồng. Trả về `bo_qua` khi người dùng để trống cả khối — chưa
 * ký hợp đồng là chuyện bình thường lúc mới lập hồ sơ.
 *
 * @param loai   danh mục loại phụ cấp, ĐỌC TỪ DATABASE chứ không tin form
 * @param phuCapLa dòng phụ cấp cũ không khớp mã loại nào, phải giữ nguyên
 */
function docHopDong(
  form: FormData,
  loai: { code: string; name: string; is_taxable: boolean; is_insurance: boolean }[],
  phuCapLa: DongPhuCap[],
): KetQuaHopDong {
  const contract_no = chuoi(form, 'hd_contract_no')
  const start_date = ngay(form, 'hd_start_date')

  // Lương KHÔNG còn đọc ở đây từ 19/08/2026: nó nằm ở `muc_luong_hop_dong` với
  // ngày hiệu lực riêng, và đặt bằng hành động `themMucLuong` bên dưới. Sửa đè
  // lên ô lương là cách cũ đã làm mất lịch sử — không mở lại đường đó.
  const trong = contract_no === null && start_date === null
  if (trong) return { bo_qua: true }

  if (!contract_no) return { bo_qua: false, loi: 'Có nhập hợp đồng thì phải có số hợp đồng.' }
  if (!start_date) return { bo_qua: false, loi: 'Hợp đồng phải có ngày bắt đầu.' }

  const end_date = ngay(form, 'hd_end_date')
  if (end_date !== null && end_date < start_date) {
    return { bo_qua: false, loi: 'Ngày kết thúc hợp đồng phải sau ngày bắt đầu.' }
  }

  const type = (chuoi(form, 'hd_type') ?? 'thu_viec') as ContractType
  if (!LOAI_HD_HOP_LE.includes(type)) {
    return { bo_qua: false, loi: 'Loại hợp đồng không hợp lệ.' }
  }

  // Dòng phụ cấp riêng: mang theo `type_code` để engine biết nó GHI ĐÈ mức
  // của chức danh chứ không cộng thêm. Thuộc tính thuế và bảo hiểm lấy từ
  // danh mục LOẠI, không cho biểu mẫu tự khai — cùng một khoản thì mọi người
  // phải chịu thuế như nhau.
  const phuCap: DongPhuCap[] = []
  for (const l of loai) {
    if (form.get(`pc_chon_${l.code}`) !== 'on') continue
    const muc = soTien(form, `pc_muc_${l.code}`)
    if (muc === null) {
      return { bo_qua: false, loi: `Phụ cấp “${l.name}” được tick nhưng mức nhập không hợp lệ.` }
    }
    phuCap.push({
      type_code: l.code,
      name: l.name,
      amount: muc,
      taxable: l.is_taxable,
      insurance: l.is_insurance,
    })
  }

  return {
    bo_qua: false,
    loi: null,
    id: chuoi(form, 'hd_id'),
    ghi: {
      contract_no,
      type,
      start_date,
      end_date,
      // Giữ nguyên dòng cũ không khớp mã loại nào: biểu mẫu không hiện chúng
      // để sửa, nên ghi đè bằng danh sách mới sẽ XOÁ MẤT tiền của người ta.
      allowances: [...phuCap, ...phuCapLa],
    },
  }
}

/** Danh mục loại phụ cấp + dòng phụ cấp lạ của hợp đồng đang hiệu lực. */
async function boiCanhPhuCap(
  supabase: Awaited<ReturnType<typeof createClient>>,
  employeeId: string | null,
) {
  const { data: loai } = await supabase
    .from('allowance_types')
    .select('code, name, is_taxable, is_insurance')
    .eq('is_active', true)
    .order('code')

  const danhMuc = loai ?? []
  if (!employeeId) return { danhMuc, phuCapLa: [] as DongPhuCap[] }

  const { data: hd } = await supabase
    .from('labor_contracts')
    .select('allowances')
    .eq('employee_id', employeeId)
    .eq('is_active', true)
    .maybeSingle()

  const maBiet = new Set(danhMuc.map((l) => l.code))
  const cu = Array.isArray(hd?.allowances) ? (hd.allowances as DongPhuCap[]) : []
  return { danhMuc, phuCapLa: cu.filter((d) => !d?.type_code || !maBiet.has(d.type_code)) }
}

export async function taoNhanSu(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  // Kiểm quyền ở đây chỉ để báo lỗi sớm và tử tế. Lớp chặn thật là RLS:
  // policy insert trên employees chỉ mở cho HR và admin.
  await batBuocCong(CONG_SUA_NHAN_SU)

  const employee_code = String(form.get('employee_code') ?? '').trim()
  const chung = docPhanChung(form)

  if (employee_code === '' || chung.full_name === '') {
    return { error: 'Mã nhân viên và họ tên là bắt buộc.' }
  }

  const supabase = await createClient()

  const { data: nv, error: loi } = await supabase
    .from('employees')
    .insert({ employee_code, ...chung })
    .select('id')
    .single()

  // Chức danh KHÔNG còn là một cột trên hồ sơ (P1c) — nó là dòng đầu tiên của
  // lịch sử chức danh, hiệu lực từ ngày vào làm.
  const chucDanhDau = chuoi(form, 'position_id')
  if (nv && chucDanhDau) {
    const { error: loiCD } = await supabase.from('nhan_vien_chuc_danh').insert({
      employee_id: nv.id,
      position_id: chucDanhDau,
      tu_ngay: ngay(form, 'hire_date') ?? new Date().toISOString().slice(0, 10),
      la_chinh: true,
      ly_do: 'Chức danh khi vào làm',
    })
    if (loiCD) {
      return { error: `Đã tạo hồ sơ nhưng chưa gán được chức danh: ${loiCD.message}` }
    }
  }

  if (loi) {
    if (loi.code === '23505') return { error: `Mã nhân viên “${employee_code}” đã tồn tại.` }
    return { error: `Không tạo được hồ sơ: ${loi.message}` }
  }

  const nhayCam = docPhanNhayCam(form)
  if (coDuLieu(nhayCam)) {
    const { error: loiNhayCam } = await supabase
      .from('employee_sensitive')
      .insert({ employee_id: nv.id, ...nhayCam })

    if (loiNhayCam) {
      // Hai lệnh ghi này không nằm chung một giao dịch. Nói thẳng trạng thái
      // thật thay vì báo lỗi chung chung khiến HR nhập lại từ đầu và tạo
      // trùng mã nhân viên.
      return {
        error: `Đã tạo hồ sơ nhưng chưa lưu được phần nhạy cảm: ${loiNhayCam.message}. Vào màn hình sửa để nhập lại phần này.`,
      }
    }
  }

  const { danhMuc } = await boiCanhPhuCap(supabase, null)
  const hd = docHopDong(form, danhMuc, [])
  if (!hd.bo_qua) {
    if (hd.loi !== null) {
      return { error: `Đã tạo hồ sơ nhưng chưa lưu được hợp đồng: ${hd.loi} Vào màn hình sửa để nhập lại.` }
    }
    const { error: loiHD } = await supabase
      .from('labor_contracts')
      .insert({ employee_id: nv.id, is_active: true, ...hd.ghi })
    if (loiHD) {
      return {
        error:
          loiHD.code === '23505'
            ? `Đã tạo hồ sơ nhưng số hợp đồng “${hd.ghi.contract_no}” đã tồn tại. Vào màn hình sửa để nhập số khác.`
            : `Đã tạo hồ sơ nhưng chưa lưu được hợp đồng: ${loiHD.message}. Vào màn hình sửa để nhập lại.`,
      }
    }
  }

  revalidatePath('/nhan-su/ho-so')
  redirect(`/nhan-su/ho-so/${nv.id}`)
}

export async function capNhatNhanSu(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  await batBuocCong(CONG_SUA_NHAN_SU)

  const id = String(form.get('id') ?? '').trim()
  const chung = docPhanChung(form)

  if (id === '' || chung.full_name === '') {
    return { error: 'Thiếu mã hồ sơ hoặc họ tên.' }
  }
  if (chung.manager_id === id) {
    return { error: 'Nhân viên không thể là quản lý trực tiếp của chính mình.' }
  }

  const supabase = await createClient()

  // employee_code cố ý KHÔNG cho sửa: nó là mã định danh dùng đối chiếu
  // chấm công và bảng lương ở các phase sau.
  const { error: loi } = await supabase.from('employees').update(chung).eq('id', id)
  if (loi) return { error: `Không lưu được hồ sơ: ${loi.message}` }

  const nhayCam = docPhanNhayCam(form)
  const { error: loiNhayCam } = await supabase
    .from('employee_sensitive')
    .upsert({ employee_id: id, ...nhayCam }, { onConflict: 'employee_id' })

  if (loiNhayCam) {
    return { error: `Đã lưu phần chung nhưng chưa lưu được phần nhạy cảm: ${loiNhayCam.message}` }
  }

  const { danhMuc, phuCapLa } = await boiCanhPhuCap(supabase, id)
  const hd = docHopDong(form, danhMuc, phuCapLa)
  if (!hd.bo_qua) {
    if (hd.loi !== null) return { error: `Đã lưu hồ sơ nhưng chưa lưu được hợp đồng: ${hd.loi}` }

    // Có hd.id nghĩa là đang sửa hợp đồng đang hiệu lực; không có thì đây là
    // hợp đồng đầu tiên của người này.
    const { error: loiHD } = hd.id
      ? await supabase.from('labor_contracts').update(hd.ghi).eq('id', hd.id)
      : await supabase
          .from('labor_contracts')
          .insert({ employee_id: id, is_active: true, ...hd.ghi })

    if (loiHD) {
      return {
        error:
          loiHD.code === '23505'
            ? `Đã lưu hồ sơ nhưng số hợp đồng “${hd.ghi.contract_no}” trùng với hợp đồng khác.`
            : `Đã lưu hồ sơ nhưng chưa lưu được hợp đồng: ${loiHD.message}`,
      }
    }
  }

  revalidatePath('/nhan-su/ho-so')
  revalidatePath(`/nhan-su/ho-so/${id}`)
  redirect(`/nhan-su/ho-so/${id}`)
}


/**
 * Thêm một mức lương có ngày áp dụng.
 *
 * KHÔNG sửa đè lên mức đang có — đó chính là cách cũ đã làm mất lịch sử lương
 * (dò ra 19/08/2026). Mỗi lần tăng hay giảm là một dòng mới, và những ngày
 * trước ngày áp dụng vẫn được engine tính theo mức cũ.
 *
 * Ngày áp dụng LÙI vào kỳ đã chốt thì vẫn nhận, nhưng phải cảnh báo rõ — quyết
 * định của Triệu Vũ 19/08/2026. Lý do: quyết định tăng lương ký muộn là chuyện
 * thường, và chặn cứng chỉ khiến người nhập gõ một ngày sai sự thật để vào cho
 * được. Phiếu lương đã phát hành KHÔNG được tính lại, nên phần chênh lệch phải
 * trả bù bằng tay.
 */
export async function themMucLuong(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  const phien = await batBuocCong(CONG_SUA_NHAN_SU)

  const contractId = chuoi(form, 'contract_id')
  const tuNgay = ngay(form, 'tu_ngay')
  const positionSalary = soTien(form, 'position_salary')
  const bhxhSalary = soTien(form, 'bhxh_salary')

  if (!contractId) return { error: 'Nhân viên này chưa có hợp đồng lao động đang hiệu lực.' }
  if (!tuNgay) return { error: 'Phải có ngày áp dụng.' }
  if (positionSalary === null) return { error: 'Lương theo chức danh phải là số không âm.' }
  if (bhxhSalary === null) return { error: 'Lương đóng bảo hiểm phải là số không âm.' }

  const supabase = await createClient()
  const { error } = await supabase.from('muc_luong_hop_dong').insert({
    contract_id: contractId,
    tu_ngay: tuNgay,
    position_salary: positionSalary,
    bhxh_salary: bhxhSalary,
    ly_do: chuoi(form, 'ly_do'),
    dat_boi: phien.userId,
  })

  if (error) {
    return {
      error:
        error.code === '23505'
          ? 'Đã có một mức lương áp dụng từ đúng ngày này. Sửa mức đó thay vì thêm mức trùng ngày.'
          : `Không lưu được mức lương: ${error.message}`,
    }
  }

  // Cảnh báo kỳ đã chốt: đọc SAU khi ghi thành công, vì đây là lời nhắc chứ
  // không phải điều kiện chặn.
  const { data: kyDaChot } = await supabase
    .from('payroll_periods')
    .select('month, year')
    .neq('status', 'mo')
    .order('year')
    .order('month')

  const anhHuong = (kyDaChot ?? []).filter((k) => {
    const cuoiKy = new Date(Date.UTC(k.year, k.month, 0)).toISOString().slice(0, 10)
    return cuoiKy >= tuNgay
  })

  revalidatePath('/nhan-su/ho-so')
  revalidatePath('/nhan-su/ho-so-cua-toi')

  if (anhHuong.length > 0) {
    return {
      error: null,
      canhBao:
        `Đã lưu. Nhưng ngày áp dụng này rơi vào ${anhHuong.length} kỳ lương ĐÃ CHỐT ` +
        `(${anhHuong.map((k) => `${k.month}/${k.year}`).join(', ')}). ` +
        'Phiếu lương đã phát hành không được tính lại — phần chênh lệch phải trả bù bằng tay.',
    }
  }

  return { error: null }
}

/**
 * Giao thêm một chức danh kiêm nhiệm.
 *
 * Có NGÀY ÁP DỤNG vì phụ cấp đi kèm chức danh: gỡ một chức danh mà không lưu
 * kỳ thì phiếu lương tháng trước hết giải thích được vì sao có khoản phụ cấp
 * đó. Cùng lý do với mức lương theo thời gian.
 *
 * Không kiểm "khác chức danh chính" ở đây — trigger ở database lo, và nó chặn
 * cả đường gọi thẳng PostgREST.
 */
export async function themKiemNhiem(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  await batBuocCong(CONG_SUA_NHAN_SU)

  const employeeId = chuoi(form, 'employee_id')
  const positionId = chuoi(form, 'position_id')
  const tuNgay = ngay(form, 'tu_ngay')

  if (!employeeId) return { error: 'Thiếu hồ sơ nhân sự.' }
  if (!positionId) return { error: 'Chưa chọn chức danh.' }
  if (!tuNgay) return { error: 'Phải có ngày bắt đầu kiêm nhiệm.' }

  const supabase = await createClient()
  const { error } = await supabase.from('nhan_vien_chuc_danh').insert({
    employee_id: employeeId,
    position_id: positionId,
    tu_ngay: tuNgay,
    la_chinh: false,
    ly_do: chuoi(form, 'ly_do'),
  })

  if (error) {
    return {
      error:
        error.code === '23505'
          ? 'Người này đang kiêm chức danh đó rồi.'
          : // Trigger đã viết sẵn câu tiếng Việt đầy đủ — giữ nguyên.
            error.message,
    }
  }

  revalidatePath('/nhan-su/ho-so')
  revalidatePath('/nhan-su/ho-so-cua-toi')
  return { error: null }
}

/**
 * Kết thúc một việc kiêm nhiệm.
 *
 * Đặt `den_ngay` chứ KHÔNG xoá dòng: những kỳ lương đã tính khi việc kiêm
 * nhiệm còn hiệu lực phải giải thích được vì sao có phụ cấp của chức danh đó.
 */
export async function ketThucKiemNhiem(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  await batBuocCong(CONG_SUA_NHAN_SU)

  const id = chuoi(form, 'id')
  const denNgay = ngay(form, 'den_ngay')

  if (!id) return { error: 'Thiếu dòng kiêm nhiệm.' }
  if (!denNgay) return { error: 'Ngày kết thúc không hợp lệ.' }

  const supabase = await createClient()
  const { error } = await supabase
    .from('nhan_vien_chuc_danh')
    .update({ den_ngay: denNgay })
    .eq('id', id)

  if (error) return { error: `Không lưu được: ${error.message}` }

  revalidatePath('/nhan-su/ho-so')
  revalidatePath('/nhan-su/ho-so-cua-toi')
  return { error: null }
}

/**
 * Đổi chức danh CHÍNH kể từ một ngày.
 *
 * Đi qua hàm `doi_chuc_danh_chinh` ở database vì nó làm hai việc không tách
 * rời: đóng chức danh chính đang mở tại ngày TRƯỚC ngày hiệu lực mới, rồi mở
 * dòng mới. Tách ra là có lúc một người mang hai chức danh chính chồng nhau,
 * hoặc không mang chức danh nào trong một khoảng.
 *
 * Ngày hiệu lực LÙI vẫn nhận — quyết định bổ nhiệm ký muộn là chuyện thường,
 * cùng lý do đã chốt cho mức lương. Cảnh báo nếu nó chạm kỳ lương đã chốt.
 */
export async function doiChucDanhChinh(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  await batBuocCong(CONG_SUA_NHAN_SU)

  const employeeId = chuoi(form, 'employee_id')
  const positionId = chuoi(form, 'position_id')
  const tuNgay = ngay(form, 'tu_ngay')

  if (!employeeId) return { error: 'Thiếu hồ sơ nhân sự.' }
  if (!positionId) return { error: 'Chưa chọn chức danh.' }
  if (!tuNgay) return { error: 'Phải có ngày hiệu lực.' }

  const supabase = await createClient()
  const { error } = await supabase.rpc('doi_chuc_danh_chinh', {
    p_employee_id: employeeId,
    p_position_id: positionId,
    p_tu_ngay: tuNgay,
    p_ly_do: chuoi(form, 'ly_do') ?? undefined,
  })

  // Hàm ở database viết sẵn câu tiếng Việt đầy đủ — giữ nguyên.
  if (error) return { error: error.message }

  const { data: kyDaChot } = await supabase
    .from('payroll_periods')
    .select('month, year')
    .neq('status', 'mo')

  const anhHuong = (kyDaChot ?? []).filter((k) => {
    const cuoiKy = new Date(Date.UTC(k.year, k.month, 0)).toISOString().slice(0, 10)
    return cuoiKy >= tuNgay
  })

  revalidatePath('/nhan-su/ho-so')
  revalidatePath('/nhan-su/ho-so-cua-toi')

  if (anhHuong.length > 0) {
    return {
      error: null,
      canhBao:
        `Đã đổi chức danh. Nhưng ngày hiệu lực rơi vào ${anhHuong.length} kỳ lương ĐÃ CHỐT ` +
        `(${anhHuong.map((k) => `${k.month}/${k.year}`).join(', ')}). ` +
        'Phiếu lương đã phát hành không được tính lại — phụ cấp theo chức danh của các kỳ đó giữ nguyên.',
    }
  }

  return { error: null }
}
