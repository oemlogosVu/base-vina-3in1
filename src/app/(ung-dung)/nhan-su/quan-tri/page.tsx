import Link from 'next/link'
import { KhungTrang } from '@ns/components/khung-trang'
import { batBuocVaiTro } from '@ns/lib/phien'
import { createClient } from '@ns/lib/supabase/server'
import { MAN_QUAN_TRI } from '@ns/lib/tabs'

/**
 * Trang tổng hợp các màn quản trị.
 *
 * Gom 5 màn vào một mục "Quản trị" trên menu thay vì rải 5 link rời — thanh
 * menu có tới 11 mục thì người dùng không tìm thấy thứ mình cần.
 *
 * Trang này cũng là chỗ nói thẳng những việc còn dở của hệ thống: admin là
 * người duy nhất sửa được chúng, nên nhắc ở đây là nhắc đúng người.
 */
export default async function TrangQuanTri() {
  const phien = await batBuocVaiTro('admin')

  const supabase = await createClient()
  const [congTy, bacThue, nvChuaGan] = await Promise.all([
    supabase.from('companies').select('id', { count: 'exact', head: true }),
    supabase.from('cfg_pit_brackets').select('id', { count: 'exact', head: true }),
    supabase
      .from('employees')
      .select('id', { count: 'exact', head: true })
      .is('company_id', null)
      .in('status', ['thu_viec', 'chinh_thuc']),
  ])

  const viecCanLam: { viec: string; duongDan: string }[] = []
  if ((congTy.count ?? 0) === 0) {
    viecCanLam.push({ viec: 'Chưa khai báo công ty nào', duongDan: '/nhan-su/quan-tri/cong-ty' })
  }
  if ((nvChuaGan.count ?? 0) > 0) {
    viecCanLam.push({
      viec: `${nvChuaGan.count} nhân viên chưa được gán công ty — họ sẽ bị bỏ sót khỏi bảng lương`,
      duongDan: '/nhan-su/quan-tri/cong-ty',
    })
  }
  if ((bacThue.count ?? 0) === 0) {
    viecCanLam.push({
      viec: 'Chưa nhập biểu thuế TNCN — hệ thống sẽ từ chối tính lương',
      duongDan: '/nhan-su/quan-tri/tham-so-luong',
    })
  }

  return (
    <KhungTrang phien={phien} tieuDe="Quản trị">
      {viecCanLam.length > 0 && (
        <div className="mb-6 rounded-xl bg-amber-50 p-4 text-sm text-amber-900 dark:bg-amber-950 dark:text-amber-200">
          <p className="font-medium">Việc cần làm</p>
          <ul className="mt-2 space-y-1">
            {viecCanLam.map((v) => (
              <li key={v.viec}>
                <Link href={v.duongDan} className="underline">
                  {v.viec}
                </Link>
              </li>
            ))}
          </ul>
        </div>
      )}

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        {MAN_QUAN_TRI.map((m) => (
          <Link
            key={m.duongDan}
            href={m.duongDan}
            className="rounded-xl border border-slate-200 bg-white p-5 hover:border-slate-400 dark:border-slate-800 dark:bg-slate-900"
          >
            <h2 className="font-medium">{m.nhan}</h2>
            <p className="mt-1 text-sm text-slate-500">{m.moTa}</p>
          </Link>
        ))}
      </div>

      <p className="mt-6 text-sm text-slate-500">
        Các màn ở đây chỉ admin vào được, và <strong>không cấu hình theo chức danh</strong> —
        tắt nhầm đường vào đây là tắt luôn đường sửa cấu hình đã tắt nó.
      </p>
    </KhungTrang>
  )
}
