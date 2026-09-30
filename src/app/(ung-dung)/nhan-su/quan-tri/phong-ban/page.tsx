import { createClient } from '@ns/lib/supabase/server'
import { batBuocVaiTro } from '@ns/lib/phien'
import { KhungTrang, Khoi } from '@ns/components/khung-trang'
import { FormSuaPhongBan, FormTaoPhongBan } from './bieu-mau'
import { NutXoaDanhMuc } from '@ns/components/nut-xoa'

export default async function QuanTriPhongBanPage() {
  const phien = await batBuocVaiTro('admin')
  const supabase = await createClient()

  const [{ data: phongBan, error: loi }, { data: nhanSu }] = await Promise.all([
    supabase
      .from('departments')
      .select('id, code, name, parent_id, manager_id, is_active')
      .order('code'),
    supabase.from('employees').select('id, full_name').neq('status', 'nghi_viec').order('full_name'),
  ])

  if (loi) throw new Error(`Không đọc được danh sách phòng ban: ${loi.message}`)

  const danhSach = phongBan ?? []

  return (
    <KhungTrang phien={phien} tieuDe="Phòng ban">
      <Khoi tieuDe="Thêm phòng ban">
        <FormTaoPhongBan phongBan={danhSach} />
      </Khoi>

      <Khoi
        tieuDe={`Danh sách (${danhSach.length})`}
        ghiChu="Xoá được khi phòng ban chưa có nhân viên và chưa có phòng con. Còn người thì bỏ tick “Đang dùng” để ngừng sử dụng mà dữ liệu lịch sử vẫn giữ nguyên."
      >
        {danhSach.length === 0 ? (
          <p className="text-sm text-slate-500">Chưa có phòng ban nào.</p>
        ) : (
          <ul className="space-y-5">
            {danhSach.map((p) => (
              <li key={p.id} className="border-t border-slate-100 pt-5 first:border-0 first:pt-0 dark:border-slate-800">
                <FormSuaPhongBan phong={p} phongBan={danhSach} nhanSu={nhanSu ?? []} />
                <div className="mt-3">
                  <NutXoaDanhMuc bang="departments" id={p.id} ten={p.name} />
                </div>
              </li>
            ))}
          </ul>
        )}
      </Khoi>
    </KhungTrang>
  )
}
