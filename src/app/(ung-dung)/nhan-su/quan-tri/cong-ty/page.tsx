import { KhungTrang, Khoi } from '@ns/components/khung-trang'
import { batBuocVaiTro } from '@ns/lib/phien'
import { createClient } from '@ns/lib/supabase/server'
import { FormGioChuanVaCa, FormSuaCongTy, FormTaoCongTy, type CaRut } from './bieu-mau'
import { NutXoaDanhMuc } from '@ns/components/nut-xoa'

export default async function TrangCongTy() {
  const phien = await batBuocVaiTro('admin')

  const supabase = await createClient()
  const [dsCongTy, chuaGan, dsCa] = await Promise.all([
    supabase.from('companies').select('*').order('code'),
    supabase
      .from('employees')
      .select('employee_code, full_name')
      .is('company_id', null)
      .in('status', ['thu_viec', 'chinh_thuc'])
      .order('employee_code'),
    supabase.from('ca_cong_nhat').select('company_id, ma, gio_bat_dau, gio_ket_thuc'),
  ])

  if (dsCongTy.error) throw new Error(`Không đọc được danh sách công ty: ${dsCongTy.error.message}`)

  if (dsCa.error) throw new Error(`Không đọc được ca công nhật: ${dsCa.error.message}`)

  const congTy = dsCongTy.data ?? []
  const nvChuaGan = chuaGan.data ?? []
  // `ma` ở database là text có ràng buộc `ca_ma_hop_le`; bộ sinh type không
  // đọc được ràng buộc CHECK nên nó về đây là `string`.
  const ca = (dsCa.data ?? []) as CaRut[]

  return (
    <KhungTrang phien={phien} tieuDe="Công ty">
      <div className="mb-6 rounded-xl bg-slate-100 p-4 text-sm dark:bg-slate-800">
        <p className="font-medium">Công ty ở đây là pháp nhân, không phải phòng ban.</p>
        <p className="mt-1">
          Mỗi công ty có <strong>kỳ lương và bảng lương riêng</strong>, vì khai thuế TNCN và
          BHXH là việc của từng pháp nhân. Một kỳ lương gộp hai công ty là trộn sổ sách của
          hai doanh nghiệp khác nhau.
        </p>
      </div>

      {nvChuaGan.length > 0 && (
        <div className="mb-6 rounded-xl bg-amber-50 p-4 text-sm text-amber-900 dark:bg-amber-950 dark:text-amber-200">
          <p className="font-medium">
            {nvChuaGan.length} nhân viên chưa được gán công ty.
          </p>
          <p className="mt-1">
            Họ sẽ <strong>không nằm trong kỳ lương nào</strong>, tức bị bỏ sót khỏi bảng lương.
            Hệ thống sẽ từ chối tính lương cho tới khi gán xong — đây là chủ ý, để không ai bị
            quên mà không phát hiện ra.
          </p>
          <ul className="mt-2 list-disc pl-5">
            {nvChuaGan.map((e) => (
              <li key={e.employee_code}>
                {e.full_name} <span className="opacity-70">({e.employee_code})</span>
              </li>
            ))}
          </ul>
        </div>
      )}

      <Khoi tieuDe="Thêm công ty">
        <FormTaoCongTy />
      </Khoi>

      <Khoi tieuDe={`Danh sách (${congTy.length})`}>
        {congTy.length === 0 ? (
          <p className="text-sm text-slate-500">
            Chưa có công ty nào. Thêm ít nhất một công ty trước khi gán nhân viên và tạo kỳ lương.
          </p>
        ) : (
          <ul className="space-y-5">
            {congTy.map((c) => (
              <li
                key={c.id}
                className="border-t border-slate-100 pt-5 first:border-0 first:pt-0 dark:border-slate-800"
              >
                <FormSuaCongTy congTy={c} />
                <FormGioChuanVaCa
                  congTy={c}
                  ca={ca.filter((x) => x.company_id === c.id)}
                />
                <div className="mt-3">
                  <NutXoaDanhMuc bang="companies" id={c.id} ten={c.name} />
                </div>
              </li>
            ))}
          </ul>
        )}
      </Khoi>

      <p className="text-sm text-slate-500">
        Không xoá được công ty — bỏ đánh dấu “Đang dùng” để ngừng. Bảng lương đã phát hành phải
        còn trỏ về được pháp nhân đã trả nó.
      </p>
    </KhungTrang>
  )
}
