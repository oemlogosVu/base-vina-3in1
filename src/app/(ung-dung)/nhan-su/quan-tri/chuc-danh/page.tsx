import { createClient } from '@ns/lib/supabase/server'
import { batBuocVaiTro } from '@ns/lib/phien'
import { KhungTrang, Khoi } from '@ns/components/khung-trang'
import { FormPhuCapChucDanh, FormSuaChucDanh, FormTaoChucDanh } from './bieu-mau'
import { NutXoaDanhMuc } from '@ns/components/nut-xoa'

export default async function QuanTriChucDanhPage() {
  const phien = await batBuocVaiTro('admin')
  const supabase = await createClient()

  const [
    { data: chucDanh, error: loi },
    { data: loaiPhuCap, error: loiLoai },
    { data: mucPhuCap, error: loiMuc },
    { data: dangGiu },
  ] = await Promise.all([
    supabase.from('positions').select('id, code, name, is_active').order('code'),
    supabase
      .from('allowance_types')
      .select('id, code, name, is_taxable, is_insurance')
      .eq('is_active', true)
      .order('code'),
    supabase.from('position_allowances').select('position_id, allowance_type_id, amount'),
    // Đếm người đang giữ từng chức danh — đổi quyền là đổi cho tất cả họ,
    // nên con số này phải nằm ngay cạnh ô tick chứ không ở màn khác.
    supabase
      .from('nhan_vien_chuc_danh')
      .select('position_id, den_ngay')
      .is('den_ngay', null),
  ])

  if (loi) throw new Error(`Không đọc được danh sách chức danh: ${loi.message}`)
  if (loiLoai) throw new Error(`Không đọc được danh mục loại phụ cấp: ${loiLoai.message}`)
  if (loiMuc) throw new Error(`Không đọc được mức phụ cấp: ${loiMuc.message}`)

  const soNguoiGiu = new Map<string, number>()
  for (const g of dangGiu ?? []) {
    soNguoiGiu.set(g.position_id, (soNguoiGiu.get(g.position_id) ?? 0) + 1)
  }

  const danhSach = (chucDanh ?? []).map((c) => ({
    ...c,
    soNguoiGiu: soNguoiGiu.get(c.id) ?? 0,
  }))
  const loai = loaiPhuCap ?? []

  // Gom mức phụ cấp theo chức danh một lần, thay vì mỗi dòng một truy vấn.
  const mucTheoChucDanh = new Map<string, Record<string, number>>()
  for (const m of mucPhuCap ?? []) {
    const cua = mucTheoChucDanh.get(m.position_id) ?? {}
    cua[m.allowance_type_id] = Number(m.amount)
    mucTheoChucDanh.set(m.position_id, cua)
  }

  return (
    <KhungTrang phien={phien} tieuDe="Chức danh">
      <Khoi tieuDe="Thêm chức danh">
        <FormTaoChucDanh />
      </Khoi>

      <Khoi
        tieuDe={`Danh sách (${danhSach.length})`}
        ghiChu="Xoá được khi chưa có ai giữ chức danh này. Còn người giữ thì bỏ tick “Đang dùng” để ngừng sử dụng mà hồ sơ cũ vẫn giữ tham chiếu. Lưu ý: xoá chức danh sẽ xoá luôn phần phụ cấp cấu hình cho nó."
      >
        {danhSach.length === 0 ? (
          <p className="text-sm text-slate-500">Chưa có chức danh nào.</p>
        ) : (
          <ul className="space-y-5">
            {danhSach.map((c) => (
              <li key={c.id} className="border-t border-slate-100 pt-5 first:border-0 first:pt-0 dark:border-slate-800">
                <FormSuaChucDanh chucDanh={c} />

                <div className="mt-4 rounded-lg border border-slate-200 p-3 dark:border-slate-800">
                  <p className="mb-1 text-sm font-medium">Phụ cấp theo chức danh</p>
                  <p className="mb-3 text-xs text-slate-500">
                    Đây là mức <strong>mặc định</strong>. Nếu hợp đồng của một người có dòng
                    phụ cấp cùng mã loại thì mức trong hợp đồng <strong>thay thế</strong> mức ở
                    đây cho riêng người đó — không cộng dồn.
                  </p>
                  <FormPhuCapChucDanh
                    chucDanh={c}
                    loaiPhuCap={loai}
                    dangCo={mucTheoChucDanh.get(c.id) ?? {}}
                  />
                </div>

                <div className="mt-3">
                  <NutXoaDanhMuc bang="positions" id={c.id} ten={c.name} />
                </div>
              </li>
            ))}
          </ul>
        )}
      </Khoi>
    </KhungTrang>
  )
}
