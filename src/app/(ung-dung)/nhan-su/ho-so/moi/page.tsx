import Link from 'next/link'
import { createClient } from '@ns/lib/supabase/server'
import { batBuocCong, CONG_SUA_NHAN_SU } from '@ns/lib/phien'
import { KhungTrang } from '@ns/components/khung-trang'
import { BieuMauNhanSu, type GiaTriHoSo } from '../bieu-mau-nhan-su'
import { layBoiCanhHopDong } from '@ns/lib/ho-so'
import { taoNhanSu } from '../actions'

const HO_SO_RONG: GiaTriHoSo = {
  id: null,
  employee_code: '',
  full_name: '',
  dob: null,
  gender: null,
  permanent_address: null,
  phone: null,
  personal_email: null,
  department_id: null,
  manager_id: null,
  region: null,
  hire_date: null,
  status: 'thu_viec',
  company_id: null,
  // Mặc định phải chấm công. Miễn là ngoại lệ, và ngoại lệ thì phải do người
  // ta chủ động bỏ tick.
  theo_doi_cham_cong: true,
  cccd: null,
  cccd_issue_date: null,
  cccd_issue_place: null,
  bank_account_no: null,
  bank_name: null,
  tax_code: null,
  social_insurance_no: null,
}

export default async function ThemNhanSuPage() {
  const phien = await batBuocCong(CONG_SUA_NHAN_SU)
  const supabase = await createClient()

  const [{ data: phongBan }, { data: chucDanh }, { data: quanLy }, { data: congTy }] =
    await Promise.all([
      supabase.from('departments').select('id, name').eq('is_active', true).order('name'),
      supabase.from('positions').select('id, name').eq('is_active', true).order('name'),
      supabase.from('employees').select('id, full_name').neq('status', 'nghi_viec').order('full_name'),
      supabase.from('companies').select('id, name').eq('is_active', true).order('code'),
    ])

  // Người mới chưa có hồ sơ và chưa chọn chức danh, nên chỉ cần danh mục
  // loại phụ cấp để dựng các ô nhập.
  const boiCanh = await layBoiCanhHopDong(null, null)

  return (
    <KhungTrang phien={phien} tieuDe="Thêm hồ sơ nhân sự">
      <p className="mb-5 text-sm">
        <Link href="/nhan-su/ho-so" className="underline">
          ← Danh sách nhân sự
        </Link>
      </p>

      <BieuMauNhanSu
        laTaoMoi
        hanhDong={taoNhanSu}
        banDau={HO_SO_RONG}
        hopDong={boiCanh.hopDong}
        loaiPhuCap={boiCanh.loaiPhuCap}
        mucTheoChucDanh={boiCanh.mucTheoChucDanh}
        phongBan={phongBan ?? []}
        chucDanh={chucDanh ?? []}
        quanLy={quanLy ?? []}
        congTy={congTy ?? []}
        laTao
      />
    </KhungTrang>
  )
}
