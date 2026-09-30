import { batBuocTab } from '@ns/lib/phien'
import { layChiTietHoSo } from '@ns/lib/ho-so'
import { KhungTrang } from '@ns/components/khung-trang'
import { ChiTietHoSo } from '@ns/components/chi-tiet-ho-so'

/**
 * Hồ sơ của chính người đang đăng nhập — CHỈ XEM.
 *
 * Quyết định của người phụ trách ngày 09/08/2026: nhân viên không tự sửa hồ
 * sơ, kể cả số điện thoại. Không có policy UPDATE nào cho chính chủ ở tầng
 * database, nên màn hình này cố tình không có nút lưu.
 */
export default async function HoSoCuaToiPage() {
  const phien = await batBuocTab('ho-so')

  if (!phien.employeeId) {
    return (
      <KhungTrang phien={phien} tieuDe="Hồ sơ của tôi">
        <p className="text-sm text-slate-500">
          Tài khoản của bạn chưa được gắn với hồ sơ nhân sự nào. Liên hệ bộ phận nhân sự để
          được ghép hồ sơ.
        </p>
      </KhungTrang>
    )
  }

  const duLieu = await layChiTietHoSo(phien.employeeId)

  if (!duLieu) {
    return (
      <KhungTrang phien={phien} tieuDe="Hồ sơ của tôi">
        <p className="text-sm text-slate-500">
          Không đọc được hồ sơ gắn với tài khoản này. Liên hệ bộ phận nhân sự để kiểm tra lại.
        </p>
      </KhungTrang>
    )
  }

  return (
    <KhungTrang phien={phien} tieuDe="Hồ sơ của tôi">
      <p className="mb-5 text-sm text-slate-500">
        Hồ sơ chỉ để xem. Cần chỉnh sửa thông tin, vui lòng báo bộ phận nhân sự.
      </p>
      <ChiTietHoSo duLieu={duLieu} vaiTroNguoiXem={phien.role} />
    </KhungTrang>
  )
}
