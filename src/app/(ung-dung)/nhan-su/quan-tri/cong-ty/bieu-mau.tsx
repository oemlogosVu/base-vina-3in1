'use client'

import { useActionState } from 'react'
import { useFormStatus } from 'react-dom'
import { capNhatCongTy, datGioChuanVaCa, taoCongTy, type TrangThaiForm } from '../actions'

const O_NHAP =
  'w-full rounded-lg border border-slate-300 px-3 py-2 text-base outline-none focus:border-slate-900 dark:border-slate-700 dark:bg-slate-950'

const BAN_DAU: TrangThaiForm = { error: null }

export type CongTyRut = {
  id: string
  code: string
  name: string
  tax_code: string | null
  address: string | null
  standard_days: number | null
  han_xac_nhan_phieu_ngay: number | null
  is_active: boolean
  gio_vao: string | null
  gio_ra: string | null
  nghi_tu: string | null
  nghi_den: string | null
}

export type CaRut = {
  company_id: string
  ma: 'sang' | 'chieu' | 'toi'
  gio_bat_dau: string
  gio_ket_thuc: string
}

const GHI_CHU_CONG_CHUAN =
  'Mẫu số để quy lương tháng thành lương ngày: lương ngày = lương tháng ÷ công tiêu chuẩn. Là chính sách cố định của công ty, không phải số ngày làm việc thật của từng tháng.'

const GHI_CHU_HAN_XAC_NHAN =
  'Hạn xác nhận đếm từ lúc chốt kỳ lương. Quá hạn mà người lao động chưa bấm gì thì phiếu tự chuyển sang đã xác nhận, có ghi rõ là tự động. Người đang THẮC MẮC không bao giờ bị tự động. Để trống thì không bao giờ tự động — phiếu chờ tới khi có người bấm.'

function Nut({ nhan }: { nhan: string }) {
  const { pending } = useFormStatus()
  return (
    <button
      type="submit"
      disabled={pending}
      className="rounded-lg bg-slate-900 px-4 py-2 text-sm font-medium text-white disabled:opacity-60 dark:bg-slate-100 dark:text-slate-900"
    >
      {pending ? 'Đang lưu…' : nhan}
    </button>
  )
}

export function FormTaoCongTy() {
  const [trangThai, gui] = useActionState(taoCongTy, BAN_DAU)

  return (
    <form action={gui} className="space-y-3">
      <div className="grid gap-3 sm:grid-cols-4">
        <div>
          <label htmlFor="code" className="mb-1 block text-sm font-medium">
            Mã công ty *
          </label>
          <input id="code" name="code" required className={O_NHAP} placeholder="CTY-A" />
        </div>
        <div className="sm:col-span-2">
          <label htmlFor="name" className="mb-1 block text-sm font-medium">
            Tên công ty *
          </label>
          <input id="name" name="name" required className={O_NHAP} />
        </div>
        <div>
          <label htmlFor="tax_code" className="mb-1 block text-sm font-medium">
            Mã số thuế
          </label>
          <input id="tax_code" name="tax_code" inputMode="numeric" className={O_NHAP} />
        </div>
        <div>
          <label htmlFor="standard_days" className="mb-1 block text-sm font-medium">
            Công tiêu chuẩn
          </label>
          <input
            id="standard_days"
            name="standard_days"
            type="number"
            step="0.5"
            min={1}
            max={31}
            className={O_NHAP}
            placeholder="26"
          />
        </div>
        <div>
          <label htmlFor="han_xac_nhan_phieu_ngay" className="mb-1 block text-sm font-medium">
            Hạn xác nhận (ngày)
          </label>
          <input
            id="han_xac_nhan_phieu_ngay"
            name="han_xac_nhan_phieu_ngay"
            type="number"
            step="1"
            min={1}
            max={90}
            className={O_NHAP}
            placeholder="để trống"
          />
        </div>
        <div className="sm:col-span-2">
          <label htmlFor="address" className="mb-1 block text-sm font-medium">
            Địa chỉ
          </label>
          <input id="address" name="address" className={O_NHAP} />
        </div>
      </div>
      <p className="text-sm text-slate-500">{GHI_CHU_CONG_CHUAN}</p>
      <p className="text-sm text-slate-500">{GHI_CHU_HAN_XAC_NHAN}</p>
      <Nut nhan="Thêm công ty" />
      {trangThai.error !== null && (
        <p role="alert" className="text-sm text-red-600">
          {trangThai.error}
        </p>
      )}
    </form>
  )
}

export function FormSuaCongTy({ congTy }: { congTy: CongTyRut }) {
  const [trangThai, gui] = useActionState(capNhatCongTy, BAN_DAU)

  return (
    <form action={gui} className="grid gap-3 sm:grid-cols-3 lg:grid-cols-7 lg:items-end">
      <input type="hidden" name="id" value={congTy.id} />

      <div>
        <span className="mb-1 block text-xs uppercase tracking-wide text-slate-500">Mã</span>
        <span className="font-mono text-sm">{congTy.code}</span>
      </div>

      <div>
        <label htmlFor={`name-${congTy.id}`} className="mb-1 block text-sm font-medium">
          Tên
        </label>
        <input id={`name-${congTy.id}`} name="name" defaultValue={congTy.name} className={O_NHAP} />
      </div>

      <div>
        <label htmlFor={`tax-${congTy.id}`} className="mb-1 block text-sm font-medium">
          Mã số thuế
        </label>
        <input
          id={`tax-${congTy.id}`}
          name="tax_code"
          defaultValue={congTy.tax_code ?? ''}
          className={O_NHAP}
        />
      </div>

      <div>
        <label htmlFor={`dc-${congTy.id}`} className="mb-1 block text-sm font-medium">
          Địa chỉ
        </label>
        <input
          id={`dc-${congTy.id}`}
          name="address"
          defaultValue={congTy.address ?? ''}
          className={O_NHAP}
        />
      </div>

      <div>
        <label htmlFor={`cc-${congTy.id}`} className="mb-1 block text-sm font-medium">
          Công tiêu chuẩn
        </label>
        <input
          id={`cc-${congTy.id}`}
          name="standard_days"
          type="number"
          step="0.5"
          min={1}
          max={31}
          defaultValue={congTy.standard_days ?? ''}
          placeholder="chưa khai"
          className={O_NHAP}
        />
      </div>

      <div>
        <label htmlFor={`han-${congTy.id}`} className="mb-1 block text-sm font-medium">
          Hạn xác nhận (ngày)
        </label>
        <input
          id={`han-${congTy.id}`}
          name="han_xac_nhan_phieu_ngay"
          type="number"
          step="1"
          min={1}
          max={90}
          defaultValue={congTy.han_xac_nhan_phieu_ngay ?? ''}
          placeholder="không tự động"
          className={O_NHAP}
        />
      </div>

      <div className="flex items-center gap-3">
        <label className="flex items-center gap-2 text-sm">
          <input type="checkbox" name="is_active" defaultChecked={congTy.is_active} />
          Đang dùng
        </label>
        <Nut nhan="Lưu" />
      </div>

      {congTy.standard_days === null && (
        <p className="text-sm text-amber-700 sm:col-span-3 lg:col-span-7 dark:text-amber-400">
          Chưa khai công tiêu chuẩn — <strong>không tạo được kỳ lương</strong> cho công ty này.{' '}
          {GHI_CHU_CONG_CHUAN}
        </p>
      )}

      {trangThai.error !== null && (
        <p role="alert" className="text-sm text-red-600 sm:col-span-3 lg:col-span-7">
          {trangThai.error}
        </p>
      )}
    </form>
  )
}


/** "07:00:00" → "07:00". Ô <input type="time"> không nhận phần giây. */
const gioGon = (t: string | null) => (t === null ? '' : t.slice(0, 5))

const O_GIO =
  'w-full rounded-lg border border-slate-300 px-2 py-2 text-base outline-none focus:border-slate-900 dark:border-slate-700 dark:bg-slate-950'

const BA_CA = [
  { ma: 'sang', nhan: 'Ca sáng', vd: ['07:00', '11:00'] },
  { ma: 'chieu', nhan: 'Ca chiều', vd: ['13:00', '17:00'] },
  { ma: 'toi', nhan: 'Ca tối', vd: ['18:00', '22:00'] },
] as const

/**
 * Khung giờ chuẩn và ba ca công nhật của một công ty (P5e, 24/08/2026).
 *
 * Hai thứ nằm chung một biểu mẫu vì chúng chỉ có nghĩa cùng nhau: khai ca mà
 * chưa khai khung thì không biết giờ nào là ngoài giờ; khai khung mà chưa khai
 * ca thì tổ trưởng không có gì để tick.
 */
export function FormGioChuanVaCa({
  congTy,
  ca,
}: {
  congTy: CongTyRut
  ca: CaRut[]
}) {
  const [trangThai, gui] = useActionState(datGioChuanVaCa, BAN_DAU)
  const cua = (ma: string) => ca.find((c) => c.ma === ma)

  return (
    <form action={gui} className="mt-4 rounded-lg border border-slate-200 p-3 dark:border-slate-800">
      <input type="hidden" name="id" value={congTy.id} />

      <p className="text-sm font-medium">Khung giờ chuẩn và ba ca công nhật</p>
      <p className="mt-1 text-xs text-slate-500">
        Tổ đội công nhật chấm theo ca. Giờ làm <strong>trong khung</strong> tính là giờ thường,
        ngoài khung tính là <strong>ngoài giờ</strong>. Giờ nghỉ trưa không tính vào bên nào.
      </p>

      <div className="mt-3 grid gap-3 sm:grid-cols-4">
        {[
          { ten: 'gio_vao', nhan: 'Giờ vào', gt: congTy.gio_vao },
          { ten: 'gio_ra', nhan: 'Giờ ra', gt: congTy.gio_ra },
          { ten: 'nghi_tu', nhan: 'Nghỉ từ', gt: congTy.nghi_tu },
          { ten: 'nghi_den', nhan: 'Nghỉ đến', gt: congTy.nghi_den },
        ].map((o) => (
          <div key={o.ten}>
            <label htmlFor={`${o.ten}-${congTy.id}`} className="mb-1 block text-sm font-medium">
              {o.nhan}
            </label>
            <input
              id={`${o.ten}-${congTy.id}`}
              name={o.ten}
              type="time"
              defaultValue={gioGon(o.gt)}
              className={O_GIO}
            />
          </div>
        ))}
      </div>

      <div className="mt-3 grid gap-3 sm:grid-cols-3">
        {BA_CA.map((c) => (
          <div key={c.ma}>
            <span className="mb-1 block text-sm font-medium">{c.nhan}</span>
            <div className="flex items-center gap-2">
              <input
                name={`ca_${c.ma}_bat_dau`}
                type="time"
                defaultValue={gioGon(cua(c.ma)?.gio_bat_dau ?? null)}
                aria-label={`${c.nhan} bắt đầu`}
                className={O_GIO}
              />
              <span className="text-slate-400">–</span>
              <input
                name={`ca_${c.ma}_ket_thuc`}
                type="time"
                defaultValue={gioGon(cua(c.ma)?.gio_ket_thuc ?? null)}
                aria-label={`${c.nhan} kết thúc`}
                className={O_GIO}
              />
            </div>
            <p className="mt-1 text-xs text-slate-500">
              ví dụ {c.vd[0]}–{c.vd[1]}. Bỏ trống cả hai để không dùng ca này.
            </p>
          </div>
        ))}
      </div>

      <div className="mt-3">
        <Nut nhan="Lưu giờ chuẩn và ca" />
      </div>

      {congTy.gio_vao === null && (
        <p className="mt-2 text-sm text-amber-700 dark:text-amber-400">
          Chưa khai khung giờ chuẩn — <strong>tổ đội của công ty này chưa chấm công được</strong>.
        </p>
      )}

      {trangThai.error !== null && (
        <p role="alert" className="mt-2 text-sm text-red-600">
          {trangThai.error}
        </p>
      )}
      {trangThai.xong && (
        <p className="mt-2 text-sm text-emerald-700 dark:text-emerald-400">{trangThai.xong}</p>
      )}
    </form>
  )
}
