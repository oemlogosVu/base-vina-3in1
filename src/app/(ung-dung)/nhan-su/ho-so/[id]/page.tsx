import Link from 'next/link'
import { notFound } from 'next/navigation'
import { batBuocTab, CONG_SUA_NHAN_SU, quaCong } from '@ns/lib/phien'
import { layChiTietHoSo } from '@ns/lib/ho-so'
import { KhungTrang } from '@ns/components/khung-trang'
import { ChiTietHoSo } from '@ns/components/chi-tiet-ho-so'
import { Khoi } from '@ns/components/khung-trang'
import { XoaHoSo } from '@ns/components/xoa-ho-so'
import { ngayHomNayVN } from '@ns/lib/dinh-dang'
import { FormThemMucLuong } from './muc-luong'
import {
  FormDoiChucDanhChinh,
  FormKetThucKiemNhiem,
  FormThemKiemNhiem,
} from './kiem-nhiem'
import { createClient } from '@ns/lib/supabase/server'

export default async function ChiTietNhanSuPage({
  params,
}: {
  params: Promise<{ id: string }>
}) {
  const phien = await batBuocTab('nhan-su')
  const { id } = await params

  const duLieu = await layChiTietHoSo(id)
  // RLS trả về rỗng cả khi hồ sơ không tồn tại lẫn khi người xem không có
  // quyền. Hiển thị 404 cho cả hai — không xác nhận sự tồn tại của hồ sơ
  // nằm ngoài quyền của người đang đăng nhập.
  if (!duLieu) notFound()

  const suaDuoc = quaCong(phien, CONG_SUA_NHAN_SU)

  // Bỏ sẵn chức danh chính và những chức danh đang kiêm khỏi danh sách chọn.
  // Database chặn cả hai, nhưng để người dùng chọn rồi mới báo lỗi là bắt họ đoán.
  const supabase = await createClient()
  const { data: chucDanh } = suaDuoc
    ? await supabase.from('positions').select('id, code, name').eq('is_active', true).order('code')
    : { data: null }

  const dangGiu = new Set(
    duLieu.chucDanh.filter((c) => c.den_ngay === null).map((c) => c.position_id),
  )
  const chonChucDanh = (chucDanh ?? [])
    .filter((c) => !dangGiu.has(c.id))
    .map((c) => ({ id: c.id, nhan: `${c.name} (${c.code})` }))

  return (
    <KhungTrang phien={phien} tieuDe={duLieu.employee.full_name}>
      <div className="mb-5 flex flex-wrap items-center gap-3 text-sm">
        <Link href="/nhan-su/ho-so" className="underline">
          ← Danh sách nhân sự
        </Link>
        {suaDuoc && (
          <Link
            href={`/nhan-su/ho-so/${id}/sua`}
            className="ml-auto rounded-lg bg-slate-900 px-4 py-2 font-medium text-white"
          >
            Sửa hồ sơ
          </Link>
        )}
      </div>

      <ChiTietHoSo duLieu={duLieu} vaiTroNguoiXem={phien.role} />

      {suaDuoc && (
        <Khoi
          tieuDe="Đổi chức danh chính"
          ghiChu="Chức danh cũ được đóng lại theo ngày, không bị xoá — lịch sử chức danh giữ nguyên."
        >
          <FormDoiChucDanhChinh
            employeeId={id}
            chucDanh={chonChucDanh}
            homNay={ngayHomNayVN()}
            tenHienTai={duLieu.tenChucDanh}
          />
        </Khoi>
      )}

      {suaDuoc && (
        <Khoi
          tieuDe="Giao thêm chức danh kiêm nhiệm"
          ghiChu="Chức danh chính giữ nguyên. Kiêm nhiệm có kỳ hiệu lực để phiếu lương cũ còn giải thích được khoản phụ cấp đi kèm."
        >
          <FormThemKiemNhiem
            employeeId={id}
            chucDanh={chonChucDanh}
            homNay={ngayHomNayVN()}
          />

          {duLieu.chucDanh.filter((k) => k.den_ngay === null && !k.la_chinh).length > 0 && (
            <div className="mt-5 border-t border-slate-100 pt-4 dark:border-slate-800">
              <p className="mb-3 text-sm font-medium">Đang kiêm nhiệm</p>
              <ul className="space-y-2">
                {duLieu.chucDanh
                  .filter((k) => k.den_ngay === null && !k.la_chinh)
                  .map((k) => (
                    <li key={k.id} className="flex flex-wrap items-center gap-3">
                      <span className="min-w-40 flex-1 text-sm">{k.positions?.name}</span>
                      <FormKetThucKiemNhiem id={k.id} homNay={ngayHomNayVN()} />
                    </li>
                  ))}
              </ul>
            </div>
          )}
        </Khoi>
      )}

      {suaDuoc && (
        <Khoi
          tieuDe="Thêm mức lương mới"
          ghiChu="Mỗi lần tăng hay giảm là một mức mới có ngày áp dụng — mức cũ được giữ lại làm căn cứ cho những kỳ lương đã trả."
        >
          <FormThemMucLuong
            contractId={duLieu.hopDong.find((h) => h.is_active)?.id ?? null}
            homNay={ngayHomNayVN()}
          />
        </Khoi>
      )}

      {phien.role === 'admin' && (
        <div className="mt-8 border-t border-slate-200 pt-5 dark:border-slate-800">
          <XoaHoSo employeeId={id} hoTen={duLieu.employee.full_name} />
        </div>
      )}
    </KhungTrang>
  )
}
