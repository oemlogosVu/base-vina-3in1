import { createClient } from '@ns/lib/supabase/server'
import { batBuocVaiTro } from '@ns/lib/phien'
import { KhungTrang, Khoi } from '@ns/components/khung-trang'
import { ngayGio } from '@ns/lib/dinh-dang'
import { ROLE_LABELS } from '@ns/types/database'
import type { UserRole } from '@ns/types/database'
import {
  FormDatLaiMatKhau,
  FormTabNguoiDung,
  FormKichHoat,
  FormNoiHoSo,
  FormTaoTaiKhoan,
  FormVaiTro,
  type ChonRut,
} from './bieu-mau'

/**
 * Quản trị người dùng — cấp tài khoản đăng nhập và nối với hồ sơ nhân sự.
 *
 * Danh sách đi qua hàm `ds_tai_khoan()` chứ không đọc thẳng bảng `app_users`,
 * chỉ vì một cột: email. Email nằm ở `auth.users`, mà bảng đó PostgREST không
 * cho đọc. Không có email thì màn này hiện hai dòng trùng tên và admin không
 * biết dòng nào là tài khoản nào.
 */
type DongTaiKhoan = {
  id: string
  full_name: string
  email: string
  role: UserRole
  is_active: boolean
  quan_ly_to_doi: boolean
  employee_id: string | null
  ma_nhan_vien: string | null
  ten_nhan_vien: string | null
  dang_nhap_cuoi: string | null
  tao_luc: string
}

export default async function QuanTriNguoiDungPage() {
  const phien = await batBuocVaiTro('admin')
  const supabase = await createClient()

  const [{ data: taiKhoan, error: loi }, { data: nhanSu, error: loiNS }, { data: dsTab }] =
    await Promise.all([
    supabase.rpc('ds_tai_khoan'),
    supabase
      .from('employees')
      .select('id, employee_code, full_name, status')
      .is('deleted_at', null)
      .neq('status', 'nghi_viec')
      .order('employee_code'),
    // `ds_tai_khoan()` không trả cột `tabs`; hỏi riêng thay vì sửa hàm ấy —
    // nó là hàm chung của cả màn, còn tab chỉ dùng ở một khối.
    supabase.from('app_users').select('id, tabs, duyet_cong'),
  ])

  if (loi) throw new Error(`Không đọc được danh sách tài khoản: ${loi.message}`)
  if (loiNS) throw new Error(`Không đọc được danh sách nhân sự: ${loiNS.message}`)

  const ds = (taiKhoan ?? []) as DongTaiKhoan[]
  const tabTheoNguoi = new Map((dsTab ?? []).map((t) => [t.id, t]))

  const chonNhanSu: ChonRut[] = (nhanSu ?? []).map((e) => ({
    id: e.id,
    nhan: `${e.full_name} (${e.employee_code})`,
  }))

  // Hồ sơ đã có tài khoản khác giữ. Bỏ khỏi danh sách chọn của các dòng còn
  // lại — chỉ mục duy nhất ở database vẫn chặn, nhưng để admin chọn rồi mới
  // báo lỗi là bắt họ đoán.
  const daNoi = new Map<string, string>()
  for (const t of ds) if (t.employee_id) daNoi.set(t.employee_id, t.id)

  const chuaNoiHoSo = ds.filter((t) => t.is_active && !t.employee_id)
  const chuaDangNhap = ds.filter((t) => t.is_active && !t.dang_nhap_cuoi)

  return (
    <KhungTrang phien={phien} tieuDe="Người dùng">
      {(chuaNoiHoSo.length > 0 || chuaDangNhap.length > 0) && (
        <div className="mb-6 rounded-xl bg-amber-50 p-4 text-sm text-amber-900 dark:bg-amber-950 dark:text-amber-200">
          <p className="font-medium">Việc cần làm</p>
          <ul className="mt-2 space-y-1">
            {chuaNoiHoSo.length > 0 && (
              <li>
                {chuaNoiHoSo.length} tài khoản chưa nối hồ sơ nhân sự (
                {chuaNoiHoSo.map((t) => t.full_name).join(', ')}) — họ đăng nhập được nhưng Hồ
                sơ và Phiếu lương sẽ rỗng.
              </li>
            )}
            {chuaDangNhap.length > 0 && (
              <li>
                {chuaDangNhap.length} tài khoản chưa từng đăng nhập — kiểm xem mật khẩu đã tới
                tay người dùng chưa.
              </li>
            )}
          </ul>
        </div>
      )}

      <Khoi
        tieuDe="Cấp tài khoản mới"
        ghiChu="Project chưa cấu hình SMTP nên hệ thống KHÔNG gửi được thư mời và cũng không có “quên mật khẩu”. Mật khẩu hiện một lần trên màn hình này, admin trao tận tay."
      >
        <FormTaoTaiKhoan />
      </Khoi>

      <Khoi
        tieuDe={`Danh sách tài khoản (${ds.length})`}
        ghiChu="Không xoá được tài khoản — Luật Kế toán buộc giữ dấu vết ai đã làm gì trên chứng từ. Người nghỉ việc thì khoá tài khoản."
      >
        <ul className="space-y-8">
          {ds.map((t) => {
            const laMinh = t.id === phien.userId
            const chonChoDong = chonNhanSu.filter(
              (n) => !daNoi.has(n.id) || daNoi.get(n.id) === t.id,
            )

            return (
              <li
                key={t.id}
                className="border-t border-slate-100 pt-8 first:border-0 first:pt-0 dark:border-slate-800"
              >
                <div className="mb-3 flex flex-wrap items-baseline gap-x-3 gap-y-1">
                  <span className="font-medium">{t.full_name}</span>
                  <span className="font-mono text-xs text-slate-500">{t.email}</span>
                  {!t.is_active && (
                    <span className="rounded bg-red-100 px-2 py-0.5 text-xs text-red-800 dark:bg-red-950 dark:text-red-300">
                      Đang khoá
                    </span>
                  )}
                  {laMinh && (
                    <span className="rounded bg-slate-200 px-2 py-0.5 text-xs dark:bg-slate-800">
                      Bạn
                    </span>
                  )}
                  {t.quan_ly_to_doi && (
                    <span className="rounded bg-slate-100 px-2 py-0.5 text-xs text-slate-600 dark:bg-slate-800 dark:text-slate-300">
                      Quản lý tổ đội
                    </span>
                  )}
                </div>

                <p className="mb-4 text-xs text-slate-500">
                  {t.employee_id
                    ? `Hồ sơ: ${t.ten_nhan_vien} (${t.ma_nhan_vien})`
                    : 'Chưa nối hồ sơ nhân sự'}
                  {' · '}
                  {t.dang_nhap_cuoi
                    ? `Đăng nhập cuối: ${ngayGio(t.dang_nhap_cuoi)}`
                    : 'Chưa từng đăng nhập'}
                  {' · '}
                  {ROLE_LABELS[t.role]}
                </p>

                <div className="space-y-3 rounded-lg bg-slate-50 p-4 dark:bg-slate-900">
                  <FormNoiHoSo
                    id={t.id}
                    employeeId={t.employee_id}
                    nhanSu={chonChoDong}
                  />
                  <FormVaiTro id={t.id} vaiTro={t.role} />

                  <FormTabNguoiDung
                    id={t.id}
                    tabs={tabTheoNguoi.get(t.id)?.tabs ?? null}
                    duyetCong={tabTheoNguoi.get(t.id)?.duyet_cong ?? false}
                  />

                  <div className="flex flex-wrap items-start gap-4 border-t border-slate-200 pt-3 dark:border-slate-800">
                    {!laMinh && <FormKichHoat id={t.id} dangBat={t.is_active} />}
                    <FormDatLaiMatKhau id={t.id} />
                  </div>
                </div>
              </li>
            )
          })}
        </ul>

        <p className="mt-6 text-xs text-slate-500">
          Cờ <strong>quản lý tổ đội</strong> đặt ở màn Tổ đội công nhật, không đặt ở đây — một
          thiết lập chỉ nên có một chỗ sửa.
        </p>
      </Khoi>
    </KhungTrang>
  )
}
