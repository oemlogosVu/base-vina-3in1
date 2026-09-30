import { KhungTrang, Khoi } from '@ns/components/khung-trang'
import { batBuocVaiTro } from '@ns/lib/phien'
import { createClient } from '@ns/lib/supabase/server'
import { FormSuaCa } from './bieu-mau'
import { NutXoaDanhMuc } from '@ns/components/nut-xoa'

export default async function TrangCaLamViec() {
  const phien = await batBuocVaiTro('admin')

  const supabase = await createClient()
  const { data, error } = await supabase.from('work_shifts').select('*').order('code')
  if (error) throw new Error(`Không đọc được ca làm việc: ${error.message}`)

  const ca = data ?? []

  return (
    <KhungTrang phien={phien} tieuDe="Ca làm việc">
      <Khoi
        tieuDe="Cách hệ thống tính giờ làm"
        ghiChu="Đọc mục này trước khi đổi giờ ca — nó quyết định con số công của mọi nhân viên."
      >
        <div className="space-y-3 text-sm">
          <p>
            Nhân viên chấm <strong>2 lần một ngày</strong>: vào buổi sáng và ra buổi chiều. Hệ
            thống không biết ai thực sự nghỉ trưa, nên giờ làm được tính bằng khoảng có mặt trừ
            đi <strong>phần thực sự chồng lấn</strong> với giờ nghỉ.
          </p>
          <p>
            Không phải trừ cứng một hằng số: người làm 08:00–12:00 được tính đủ 4 tiếng, không
            bị trừ oan 1 tiếng nghỉ trưa mà họ không nghỉ.
          </p>
          <p>
            Đi muộn tính so với giờ vào ca, về sớm tính so với giờ ra ca. Ngoài giờ{' '}
            <strong>chỉ tính phần sau giờ ra ca</strong> — đến sớm không thành ngoài giờ.
          </p>
          <p className="text-slate-500">
            Đổi giờ ca chỉ ảnh hưởng tới các lần tổng hợp <em>sau đó</em>. Muốn con số của ngày
            cũ đổi theo thì phải tổng hợp lại ngày đó ở màn Duyệt chấm công.
          </p>
        </div>
      </Khoi>

      <Khoi tieuDe={`Danh sách ca (${ca.length})`}>
        {ca.length === 0 ? (
          <p className="text-sm text-slate-500">
            Chưa có ca nào. Không có ca thì không tổng hợp được bảng công.
          </p>
        ) : (
          <ul className="space-y-6">
            {ca.map((c) => (
              <li
                key={c.id}
                className="border-t border-slate-100 pt-6 first:border-0 first:pt-0 dark:border-slate-800"
              >
                <FormSuaCa ca={c} />
                <div className="mt-3">
                  <NutXoaDanhMuc bang="work_shifts" id={c.id} ten={c.name} />
                </div>
              </li>
            ))}
          </ul>
        )}
      </Khoi>
    </KhungTrang>
  )
}
