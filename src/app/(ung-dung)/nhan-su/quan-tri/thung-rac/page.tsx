import { createClient } from '@ns/lib/supabase/server'
import { batBuocVaiTro } from '@ns/lib/phien'
import { KhungTrang, Khoi } from '@ns/components/khung-trang'
import { FormKhoiPhucChamCong, FormKhoiPhucNhanSu } from './bieu-mau'

const GIO_VN = new Intl.DateTimeFormat('vi-VN', {
  dateStyle: 'short',
  timeStyle: 'short',
  timeZone: 'Asia/Ho_Chi_Minh',
})

const NHAN_LOAI: Record<string, string> = {
  in: 'Vào',
  out: 'Ra',
  ot_in: 'Bắt đầu thêm giờ',
  ot_out: 'Kết thúc thêm giờ',
}

/**
 * Thùng rác — nơi duy nhất xem được dữ liệu đã xoá mềm.
 *
 * Đọc qua RPC chứ không truy vấn thẳng bảng: policy RESTRICTIVE ẩn mọi dòng
 * đã xoá khỏi truy vấn thường, kể cả của admin. Nhờ vậy chỉ có đúng một
 * đường vào, và đường đó tự kiểm quyền trong database.
 */
export default async function TrangThungRac() {
  const phien = await batBuocVaiTro('admin')
  const supabase = await createClient()

  const [{ data: nhanSu, error: loiNS }, { data: chamCong, error: loiCC }] = await Promise.all([
    supabase.rpc('thung_rac_nhan_su'),
    supabase.rpc('thung_rac_cham_cong'),
  ])

  if (loiNS) throw new Error(`Không đọc được thùng rác nhân sự: ${loiNS.message}`)
  if (loiCC) throw new Error(`Không đọc được thùng rác chấm công: ${loiCC.message}`)

  const dsNhanSu = nhanSu ?? []
  const dsChamCong = chamCong ?? []

  return (
    <KhungTrang phien={phien} tieuDe="Thùng rác">
      <p className="mb-6 text-sm text-slate-500">
        Dữ liệu ở đây đã bị ẩn khỏi toàn bộ hệ thống nhưng <strong>chưa mất</strong>. Không có
        nút xoá vĩnh viễn — đó là chủ ý: thứ đã vào đây thì còn tra ngược được.
      </p>

      <Khoi
        tieuDe={`Hồ sơ nhân sự (${dsNhanSu.length})`}
        ghiChu="Khôi phục hồ sơ KHÔNG tự mở lại tài khoản đăng nhập — tài khoản có thể đã bị khoá vì lý do khác."
      >
        {dsNhanSu.length === 0 ? (
          <p className="text-sm text-slate-500">Không có hồ sơ nào trong thùng rác.</p>
        ) : (
          <ul className="space-y-4">
            {dsNhanSu.map((n) => (
              <li
                key={n.id}
                className="flex flex-wrap items-start justify-between gap-3 border-t border-slate-100 pt-4 first:border-0 first:pt-0 dark:border-slate-800"
              >
                <div>
                  <p className="font-medium">
                    {n.full_name}{' '}
                    <span className="font-mono text-sm text-slate-500">{n.employee_code}</span>
                  </p>
                  <p className="text-sm text-slate-500">
                    Xoá lúc {GIO_VN.format(new Date(n.deleted_at))}
                    {n.nguoi_xoa ? ` bởi ${n.nguoi_xoa}` : ''}
                  </p>
                  <p className="text-sm">Lý do: {n.ly_do_xoa}</p>
                </div>
                <FormKhoiPhucNhanSu employeeId={n.id} />
              </li>
            ))}
          </ul>
        )}
      </Khoi>

      <Khoi
        tieuDe={`Lần chấm công (${dsChamCong.length})`}
        ghiChu="Khôi phục sẽ tổng hợp lại bảng công của đúng ngày đó, nên số ngày công và tiền lương kỳ chưa chốt sẽ đổi theo."
      >
        {dsChamCong.length === 0 ? (
          <p className="text-sm text-slate-500">Không có lần chấm công nào trong thùng rác.</p>
        ) : (
          <ul className="space-y-4">
            {dsChamCong.map((c) => (
              <li
                key={c.id}
                className="flex flex-wrap items-start justify-between gap-3 border-t border-slate-100 pt-4 first:border-0 first:pt-0 dark:border-slate-800"
              >
                <div>
                  <p className="font-medium">
                    {c.full_name}{' '}
                    <span className="font-mono text-sm text-slate-500">{c.employee_code}</span>
                  </p>
                  <p className="text-sm">
                    {NHAN_LOAI[c.check_type] ?? c.check_type} lúc{' '}
                    {GIO_VN.format(new Date(c.logged_at))}
                  </p>
                  <p className="text-sm text-slate-500">
                    Xoá lúc {GIO_VN.format(new Date(c.deleted_at))}
                    {c.nguoi_xoa ? ` bởi ${c.nguoi_xoa}` : ''}
                    {c.ly_do_xoa ? ` — ${c.ly_do_xoa}` : ''}
                  </p>
                </div>
                <FormKhoiPhucChamCong logId={c.id} />
              </li>
            ))}
          </ul>
        )}
      </Khoi>
    </KhungTrang>
  )
}
