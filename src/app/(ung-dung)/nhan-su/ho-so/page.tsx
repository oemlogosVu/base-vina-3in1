import Link from 'next/link'
import { createClient } from '@ns/lib/supabase/server'
import { batBuocTab, CONG_SUA_NHAN_SU, quaCong } from '@ns/lib/phien'
import { KhungTrang, Pill } from '@ns/components/khung-trang'
import { EMPLOYEE_STATUS_LABELS } from '@ns/types/database'
import { sacNhanSu } from '@ns/lib/sac-trang-thai'
import { hoacGach } from '@ns/lib/dinh-dang'

/**
 * Ký tự có ý nghĩa cú pháp với PostgREST (`,` tách filter, `()` bọc giá trị,
 * `%` và `*` là ký tự đại diện của ilike). Người dùng gõ vào ô tìm kiếm nên
 * không được tin — lọc bỏ thay vì ghép thẳng vào query.
 */
function locTuKhoa(tho: string | undefined): string {
  return (tho ?? '').replace(/[%_,()*\\]/g, '').trim().slice(0, 60)
}

export default async function DanhSachNhanSuPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string }>
}) {
  const phien = await batBuocTab('nhan-su')
  const { q } = await searchParams
  const tuKhoa = locTuKhoa(q)

  const supabase = await createClient()

  // Truy vấn đi qua RLS: trưởng phòng chỉ nhận về phòng trực tiếp của mình,
  // HR/kế toán/admin nhận toàn bộ. Không cần lọc thêm ở đây.
  let truyVan = supabase
    .from('employees')
    .select(
      'id, employee_code, full_name, phone, status, department_id, nhan_vien_chuc_danh ( position_id, la_chinh, den_ngay )',
    )
    .order('employee_code')

  if (tuKhoa !== '') {
    truyVan = truyVan.or(`full_name.ilike.%${tuKhoa}%,employee_code.ilike.%${tuKhoa}%`)
  }

  const [{ data: nhanSu, error: loi }, { data: phongBan }, { data: chucDanh }] = await Promise.all([
    truyVan,
    supabase.from('departments').select('id, name'),
    supabase.from('positions').select('id, name'),
  ])

  if (loi) throw new Error(`Không đọc được danh sách nhân sự: ${loi.message}`)

  // Gộp bằng map thay vì embed của PostgREST: dữ liệu dưới 50 người, đọc code
  // dễ hơn nhiều so với cú pháp lồng, và kiểu dữ liệu rõ ràng.
  const tenPhong = new Map((phongBan ?? []).map((d) => [d.id, d.name]))
  const tenChucDanh = new Map((chucDanh ?? []).map((p) => [p.id, p.name]))

  const suaDuoc = quaCong(phien, CONG_SUA_NHAN_SU)

  return (
    <KhungTrang phien={phien} tieuDe="Hồ sơ nhân sự">
      <div className="mb-5 flex flex-wrap items-center gap-3">
        <form className="flex gap-2">
          <input
            type="search"
            name="q"
            defaultValue={tuKhoa}
            placeholder="Tìm theo tên hoặc mã nhân viên"
            className="w-64 rounded-lg border border-slate-300 px-3 py-2 text-base outline-none focus:border-slate-900 dark:border-slate-700"
          />
          <button type="submit" className="rounded-lg border border-slate-300 px-4 dark:border-slate-700">
            Tìm
          </button>
        </form>

        {suaDuoc && (
          <Link
            href="/nhan-su/ho-so/moi"
            className="ml-auto rounded-lg bg-slate-900 px-4 py-2 text-sm font-medium text-white"
          >
            Thêm nhân sự
          </Link>
        )}
      </div>

      {phien.role === 'truong_phong' && (
        <p className="mb-4 text-sm text-slate-500">
          Bạn đang xem nhân sự phòng ban của mình. Các trường CCCD, tài khoản ngân hàng và
          lương hợp đồng không hiển thị cho vai trò trưởng phòng.
        </p>
      )}

      {(nhanSu?.length ?? 0) === 0 ? (
        <p className="text-sm text-slate-500">
          {tuKhoa === '' ? 'Chưa có hồ sơ nhân sự nào.' : `Không tìm thấy hồ sơ khớp “${tuKhoa}”.`}
        </p>
      ) : (
        <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white dark:border-slate-800 dark:bg-slate-900">
          {/*
            Cột HỌ TÊN đứng đầu, mã nhân viên xuống sau.

            Dưới 900px mỗi dòng thành một thẻ, và ô đầu tiên là dòng tiêu đề
            của thẻ ấy — người ta tìm người bằng TÊN, không bằng mã. Trên
            desktop thứ tự này cũng đọc tự nhiên hơn.
          */}
          <table className="bang">
            <thead>
              <tr>
                <th>Họ tên</th>
                <th>Mã</th>
                <th>Phòng ban</th>
                <th>Chức danh</th>
                <th>Điện thoại</th>
                <th>Trạng thái</th>
              </tr>
            </thead>
            <tbody>
              {(nhanSu ?? []).map((nv) => (
                <tr key={nv.id}>
                  <td>
                    <Link href={`/nhan-su/ho-so/${nv.id}`} style={{ color: 'var(--mau-nhan)' }}>
                      {nv.full_name}
                    </Link>
                  </td>
                  <td data-nhan="Mã" className="font-mono" style={{ fontSize: 12.5 }}>
                    {nv.employee_code}
                  </td>
                  <td data-nhan="Phòng ban">
                    {nv.department_id ? hoacGach(tenPhong.get(nv.department_id)) : '—'}
                  </td>
                  <td data-nhan="Chức danh">
                    {(() => {
                      // Chức danh CHÍNH đang hiệu lực; chức danh kiêm đếm riêng.
                      const dangMo = (nv.nhan_vien_chuc_danh ?? []).filter(
                        (c) => c.den_ngay === null,
                      )
                      const chinh = dangMo.find((c) => c.la_chinh)
                      return chinh ? hoacGach(tenChucDanh.get(chinh.position_id)) : '—'
                    })()}
                    {(() => {
                      const soKiem = (nv.nhan_vien_chuc_danh ?? []).filter(
                        (c) => c.den_ngay === null && !c.la_chinh,
                      ).length
                      return soKiem > 0 ? (
                        <span
                          className="nhan-phu ml-2"
                          title="Số chức danh kiêm nhiệm đang hiệu lực"
                        >
                          +{soKiem} kiêm
                        </span>
                      ) : null
                    })()}
                  </td>
                  <td data-nhan="Điện thoại">{hoacGach(nv.phone)}</td>
                  <td data-nhan="Trạng thái">
                    <Pill sac={sacNhanSu(nv.status)}>{EMPLOYEE_STATUS_LABELS[nv.status]}</Pill>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </KhungTrang>
  )
}
