import Link from 'next/link'
import { createClient } from '@ns/lib/supabase/server'
import { batBuocVaiTro } from '@ns/lib/phien'
import { KhungTrang, Khoi } from '@ns/components/khung-trang'
import { FormSuaLoaiPhuCap, FormTaoLoaiPhuCap } from './bieu-mau'
import { NutXoaDanhMuc } from '@ns/components/nut-xoa'

export default async function QuanTriLoaiPhuCapPage() {
  const phien = await batBuocVaiTro('admin')
  const supabase = await createClient()

  const { data, error: loi } = await supabase
    .from('allowance_types')
    .select('id, code, name, is_taxable, is_insurance, ghi_chu, is_active')
    .order('code')

  if (loi) throw new Error(`Không đọc được danh mục loại phụ cấp: ${loi.message}`)

  const danhSach = data ?? []

  return (
    <KhungTrang phien={phien} tieuDe="Loại phụ cấp">
      <Khoi
        tieuDe="Thêm loại phụ cấp"
        ghiChu="Khai một lần ở đây, rồi gán mức cho từng chức danh ở màn Chức danh."
      >
        <FormTaoLoaiPhuCap />
      </Khoi>

      <Khoi
        tieuDe={`Danh mục (${danhSach.length})`}
        ghiChu="Không có nút xoá: phiếu lương đã tính có thể đang tham chiếu tới loại này. Ngừng dùng bằng cách bỏ tick “Đang dùng” — loại đó biến mất khỏi màn Chức danh nhưng dữ liệu cũ vẫn tra được."
      >
        {danhSach.length === 0 ? (
          <p className="text-sm text-slate-500">
            Chưa có loại phụ cấp nào. Hệ thống cố tình không tạo sẵn: tên khoản phụ cấp và
            việc nó có chịu thuế hay không là chính sách của doanh nghiệp.
          </p>
        ) : (
          <ul className="space-y-5">
            {danhSach.map((l) => (
              <li
                key={l.id}
                className="border-t border-slate-100 pt-5 first:border-0 first:pt-0 dark:border-slate-800"
              >
                <FormSuaLoaiPhuCap loai={l} />
                <div className="mt-3">
                  <NutXoaDanhMuc bang="allowance_types" id={l.id} ten={l.name} />
                </div>
              </li>
            ))}
          </ul>
        )}
      </Khoi>

      <p className="text-sm text-slate-500">
        Mức tiền không nhập ở đây.{' '}
        <Link href="/nhan-su/quan-tri/chuc-danh" className="underline">
          Mỗi chức danh chọn loại nào và mức bao nhiêu
        </Link>{' '}
        — cùng một loại có thể khác mức giữa các chức danh.
      </p>
    </KhungTrang>
  )
}
