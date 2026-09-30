import Link from 'next/link'
import { notFound } from 'next/navigation'
import { createClient } from '@ns/lib/supabase/server'
import { batBuocCong, CONG_SUA_NHAN_SU } from '@ns/lib/phien'
import { chucDanhChinhHienTai, layBoiCanhHopDong, layChiTietHoSo } from '@ns/lib/ho-so'
import { KhungTrang } from '@ns/components/khung-trang'
import { BieuMauNhanSu, type GiaTriHoSo } from '../../bieu-mau-nhan-su'
import { capNhatNhanSu } from '../../actions'

export default async function SuaNhanSuPage({ params }: { params: Promise<{ id: string }> }) {
  const phien = await batBuocCong(CONG_SUA_NHAN_SU)
  const { id } = await params

  const duLieu = await layChiTietHoSo(id)
  if (!duLieu) notFound()

  const supabase = await createClient()
  const [{ data: phongBan }, { data: chucDanh }, { data: quanLy }, { data: congTy }] =
    await Promise.all([
      supabase.from('departments').select('id, name').eq('is_active', true).order('name'),
      supabase.from('positions').select('id, name').eq('is_active', true).order('name'),
      supabase
        .from('employees')
        .select('id, full_name')
        .neq('status', 'nghi_viec')
        .order('full_name'),
      supabase.from('companies').select('id, name').eq('is_active', true).order('code'),
    ])

  const boiCanh = await layBoiCanhHopDong(
    id,
    chucDanhChinhHienTai(duLieu.chucDanh)?.position_id ?? null,
  )

  const nv = duLieu.employee
  const nc = duLieu.nhayCam

  const banDau: GiaTriHoSo = {
    id: nv.id,
    employee_code: nv.employee_code,
    full_name: nv.full_name,
    dob: nv.dob,
    gender: nv.gender,
    permanent_address: nv.permanent_address,
    phone: nv.phone,
    personal_email: nv.personal_email,
    department_id: nv.department_id,
    manager_id: nv.manager_id,
    company_id: nv.company_id,
    region: nv.region,
    hire_date: nv.hire_date,
    status: nv.status,
    theo_doi_cham_cong: nv.theo_doi_cham_cong,
    cccd: nc?.cccd ?? null,
    cccd_issue_date: nc?.cccd_issue_date ?? null,
    cccd_issue_place: nc?.cccd_issue_place ?? null,
    bank_account_no: nc?.bank_account_no ?? null,
    bank_name: nc?.bank_name ?? null,
    tax_code: nc?.tax_code ?? null,
    social_insurance_no: nc?.social_insurance_no ?? null,
  }

  return (
    <KhungTrang phien={phien} tieuDe={`Sửa hồ sơ — ${nv.full_name}`}>
      <p className="mb-5 text-sm">
        <Link href={`/nhan-su/ho-so/${id}`} className="underline">
          ← Quay lại hồ sơ
        </Link>
      </p>

      <BieuMauNhanSu
        hanhDong={capNhatNhanSu}
        banDau={banDau}
        hopDong={boiCanh.hopDong}
        loaiPhuCap={boiCanh.loaiPhuCap}
        mucTheoChucDanh={boiCanh.mucTheoChucDanh}
        phongBan={phongBan ?? []}
        chucDanh={chucDanh ?? []}
        quanLy={quanLy ?? []}
        congTy={congTy ?? []}
        laTao={false}
      />
    </KhungTrang>
  )
}
