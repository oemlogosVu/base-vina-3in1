'use client'

import { useActionState, useState } from 'react'
import { useFormStatus } from 'react-dom'
import { ROLE_LABELS } from '@ns/types/database'
import { MO_TA_QUYEN, O_DUYET_CONG, TABS_CAU_HINH_DUOC } from '@ns/lib/tabs'
import type { UserRole } from '@ns/types/database'
import {
  datKichHoat,
  datLaiMatKhau,
  datTabNguoiDung,
  doiVaiTro,
  noiHoSo,
  taoTaiKhoan,
  type TrangThaiForm,
} from './actions'

const O_NHAP =
  'w-full rounded-lg border border-slate-300 px-3 py-2 text-base outline-none focus:border-slate-900 dark:border-slate-700 dark:bg-slate-950'

const BAN_DAU: TrangThaiForm = { error: null }

export type ChonRut = { id: string; nhan: string }

function Nut({ nhan = 'Lưu', phu = false }: { nhan?: string; phu?: boolean }) {
  const { pending } = useFormStatus()
  return (
    <button
      type="submit"
      disabled={pending}
      className={
        phu
          ? 'rounded-lg border border-slate-300 px-3 py-1.5 text-sm disabled:opacity-60 dark:border-slate-700'
          : 'rounded-lg bg-slate-900 px-4 py-2 text-sm font-medium text-white disabled:opacity-60 dark:bg-slate-100 dark:text-slate-900'
      }
    >
      {pending ? 'Đang lưu…' : nhan}
    </button>
  )
}

/**
 * Mật khẩu vừa sinh, hiện đúng một lần.
 *
 * Không lưu ở đâu cả và không đọc lại được — mất là phải đặt lại. Nói thẳng
 * điều đó ngay cạnh mật khẩu, vì người dùng mặc định cho rằng thứ gì hiện
 * trên màn hình thì mở lại là thấy.
 */
function HienMatKhau({ matKhau }: { matKhau: string }) {
  return (
    <div className="rounded-lg border border-emerald-300 bg-emerald-50 p-3 dark:border-emerald-800 dark:bg-emerald-950">
      <p className="text-xs font-medium text-emerald-900 dark:text-emerald-200">
        Mật khẩu — chỉ hiện MỘT lần
      </p>
      <p className="my-2 select-all font-mono text-lg tracking-wider text-emerald-950 dark:text-emerald-100">
        {matKhau}
      </p>
      <p className="text-xs text-emerald-800 dark:text-emerald-300">
        Chép và trao tận tay người dùng. Rời khỏi trang là mất, không xem lại được — quên thì
        đặt lại mật khẩu mới. Nhắc họ tự đổi ở mục “Đổi mật khẩu” sau lần đăng nhập đầu.
      </p>
    </div>
  )
}

function BaoTrangThai({ trangThai }: { trangThai: TrangThaiForm }) {
  return (
    <>
      {trangThai.error !== null && (
        <p role="alert" className="text-sm text-red-600">
          {trangThai.error}
        </p>
      )}
      {trangThai.xong && (
        <p className="text-sm text-emerald-700 dark:text-emerald-400">{trangThai.xong}</p>
      )}
      {trangThai.matKhau && <HienMatKhau matKhau={trangThai.matKhau} />}
    </>
  )
}

function OVaiTro({ macDinh }: { macDinh?: UserRole }) {
  return (
    <select
      id="tk_vai_tro"
      name="vai_tro"
      defaultValue={macDinh ?? 'nhan_vien'}
      className={O_NHAP}
    >
      {(Object.keys(ROLE_LABELS) as UserRole[]).map((v) => (
        <option key={v} value={v}>
          {ROLE_LABELS[v]}
        </option>
      ))}
    </select>
  )
}

export function FormTaoTaiKhoan() {
  const [trangThai, gui] = useActionState(taoTaiKhoan, BAN_DAU)

  return (
    <form action={gui} className="space-y-3">
      <div className="grid gap-3 sm:grid-cols-2">
        <div>
          <label htmlFor="tk_email" className="mb-1 block text-sm font-medium">
            Email đăng nhập
          </label>
          <input
            id="tk_email"
            name="email"
            type="email"
            autoComplete="off"
            placeholder="nguyenvana@basevina.vn"
            className={O_NHAP}
          />
        </div>
        <div>
          <label htmlFor="tk_ho_ten" className="mb-1 block text-sm font-medium">
            Họ tên
          </label>
          <input id="tk_ho_ten" name="ho_ten" placeholder="Nguyễn Văn A" className={O_NHAP} />
        </div>
        <div>
          <label htmlFor="tk_vai_tro" className="mb-1 block text-sm font-medium">
            Vai trò
          </label>
          <OVaiTro />
        </div>
        <div>
          <label htmlFor="tk_mat_khau" className="mb-1 block text-sm font-medium">
            Mật khẩu <span className="font-normal text-slate-500">(để trống là tự sinh)</span>
          </label>
          <input
            id="tk_mat_khau"
            name="mat_khau"
            type="text"
            autoComplete="off"
            placeholder="để trống — nên vậy"
            className={O_NHAP}
          />
        </div>
      </div>

      <Nut nhan="Tạo tài khoản" />

      <p className="text-xs text-slate-500">
        Tài khoản được kích hoạt ngay nhưng <strong>chưa nối hồ sơ nhân sự</strong> — chưa nối
        thì đăng nhập vào màn nào cũng rỗng. Nối ở danh sách bên dưới.
      </p>

      <BaoTrangThai trangThai={trangThai} />
    </form>
  )
}

export function FormVaiTro({ id, vaiTro }: { id: string; vaiTro: UserRole }) {
  const [trangThai, gui] = useActionState(doiVaiTro, BAN_DAU)

  return (
    <form action={gui} className="flex flex-wrap items-end gap-2">
      <input type="hidden" name="id" value={id} />
      <div className="min-w-48">
        <label htmlFor={`vt_${id}`} className="mb-1 block text-xs text-slate-500">
          Vai trò
        </label>
        <select id={`vt_${id}`} name="role" defaultValue={vaiTro} className={O_NHAP}>
          {(Object.keys(ROLE_LABELS) as UserRole[]).map((v) => (
            <option key={v} value={v}>
              {ROLE_LABELS[v]}
            </option>
          ))}
        </select>
      </div>
      <Nut nhan="Đổi" phu />
      <BaoTrangThai trangThai={trangThai} />
    </form>
  )
}

export function FormNoiHoSo({
  id,
  employeeId,
  nhanSu,
}: {
  id: string
  employeeId: string | null
  nhanSu: ChonRut[]
}) {
  const [trangThai, gui] = useActionState(noiHoSo, BAN_DAU)

  return (
    <form action={gui} className="flex flex-wrap items-end gap-2">
      <input type="hidden" name="id" value={id} />
      <div className="min-w-64 flex-1">
        <label htmlFor={`hs_${id}`} className="mb-1 block text-xs text-slate-500">
          Hồ sơ nhân sự
        </label>
        <select
          id={`hs_${id}`}
          name="employee_id"
          defaultValue={employeeId ?? ''}
          className={O_NHAP}
        >
          <option value="">— chưa nối hồ sơ nào —</option>
          {nhanSu.map((n) => (
            <option key={n.id} value={n.id}>
              {n.nhan}
            </option>
          ))}
        </select>
      </div>
      <Nut nhan="Lưu" phu />
      <BaoTrangThai trangThai={trangThai} />
    </form>
  )
}

export function FormKichHoat({ id, dangBat }: { id: string; dangBat: boolean }) {
  const [trangThai, gui] = useActionState(datKichHoat, BAN_DAU)

  return (
    <form action={gui} className="flex flex-wrap items-center gap-2">
      <input type="hidden" name="id" value={id} />
      {dangBat ? null : <input type="hidden" name="bat" value="1" />}
      <Nut nhan={dangBat ? 'Khoá tài khoản' : 'Mở khoá'} phu />
      <BaoTrangThai trangThai={trangThai} />
    </form>
  )
}

export function FormDatLaiMatKhau({ id }: { id: string }) {
  const [trangThai, gui] = useActionState(datLaiMatKhau, BAN_DAU)

  return (
    <form action={gui} className="space-y-2">
      <input type="hidden" name="id" value={id} />
      <Nut nhan="Đặt lại mật khẩu" phu />
      <BaoTrangThai trangThai={trangThai} />
    </form>
  )
}


/**
 * Tab người này được vào (P0c, 24/08/2026).
 *
 * Bỏ tick "Tự chọn tab" = dùng nguyên quyền theo vai trò và chức danh. Tick
 * vào rồi bỏ hết = chỉ còn tab bắt buộc. Hai thứ ấy khác nhau, nên phải có ô
 * tick riêng chứ không suy từ danh sách rỗng.
 */
export function FormTabNguoiDung({
  id,
  tabs,
  duyetCong,
}: {
  id: string
  tabs: string[] | null
  duyetCong: boolean
}) {
  const [trangThai, gui] = useActionState(datTabNguoiDung, BAN_DAU)
  const [tuChon, setTuChon] = useState(tabs !== null)

  return (
    <form action={gui} className="mt-3 rounded-lg border border-slate-200 p-3 dark:border-slate-800">
      <input type="hidden" name="id" value={id} />

      <label className="flex items-center gap-2 text-sm font-medium">
        <input
          type="checkbox"
          name="tu_chon_tab"
          checked={tuChon}
          onChange={(e) => setTuChon(e.target.checked)}
        />
        Tự chọn tab cho người này
      </label>
      <p className="mt-1 text-xs text-slate-500">
        Mỗi ô tick vừa mở màn hình, vừa <strong>cấp quyền</strong> tương ứng ở database. Bỏ
        tick là <strong>thu hồi quyền thật</strong>, không phải chỉ giấu lối vào. Bỏ tick cả
        ô này = người đó dùng tab mặc định theo vai trò và <strong>không có quyền nào</strong>.
      </p>

      {tuChon && (
        <div className="mt-3 space-y-2">
          {TABS_CAU_HINH_DUOC.map((t) => (
            <div key={t.khoa}>
              <label className="flex items-start gap-2 text-sm">
                <input
                  type="checkbox"
                  name="tabs"
                  value={t.khoa}
                  defaultChecked={tabs?.includes(t.khoa) ?? true}
                  className="mt-1"
                />
                <span>
                  {t.nhan}
                  {(t.capQuyen ?? []).length > 0 && (
                    <span className="block text-xs text-amber-800 dark:text-amber-300">
                      Cấp quyền: {(t.capQuyen ?? []).map((q) => MO_TA_QUYEN[q]).join('; ')}
                    </span>
                  )}
                </span>
              </label>

              {/* Ô duy nhất không phải một tab — xem O_DUYET_CONG. Đặt thụt vào
                  ngay dưới tab tổ đội để đọc ra ngay là nó thuộc về tab ấy. */}
              {t.khoa === O_DUYET_CONG.duoiTab && (
                <label className="ml-6 mt-1 flex items-start gap-2 text-sm">
                  <input
                    type="checkbox"
                    name="duyet_cong"
                    defaultChecked={duyetCong}
                    className="mt-1"
                  />
                  <span>
                    {O_DUYET_CONG.nhan}
                    <span className="block text-xs text-amber-800 dark:text-amber-300">
                      Cấp quyền: {MO_TA_QUYEN[O_DUYET_CONG.quyen]}. Không tick vẫn vào được màn
                      tổ đội và chấm công như thường.
                    </span>
                  </span>
                </label>
              )}
            </div>
          ))}
          <p className="pt-1 text-xs text-slate-500">
            “Hồ sơ của tôi” không tắt được: đăng nhập được thì phải xem được hồ sơ của chính
            mình. Ngoài nó ra, <strong>bỏ tick là ẩn màn hình và mất quyền</strong>.
          </p>
        </div>
      )}

      <div className="mt-3 flex flex-wrap items-center gap-3">
        <Nut nhan="Lưu tab" />
        <BaoTrangThai trangThai={trangThai} />
      </div>
    </form>
  )
}
