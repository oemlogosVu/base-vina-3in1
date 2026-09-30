'use client'

import { useActionState, useState } from 'react'
import { useFormStatus } from 'react-dom'
import { thacMacPhieu, xacNhanPhieu, type TrangThaiForm } from './actions'

const BAN_DAU: TrangThaiForm = { error: null }

function Nut({ nhan, phu = false }: { nhan: string; phu?: boolean }) {
  const { pending } = useFormStatus()
  return (
    <button
      type="submit"
      disabled={pending}
      className={
        phu
          ? 'rounded-lg border border-slate-300 px-4 py-2 text-sm font-medium disabled:opacity-60 dark:border-slate-700'
          : 'rounded-lg bg-slate-900 px-4 py-2 text-sm font-medium text-white disabled:opacity-60 dark:bg-slate-100 dark:text-slate-900'
      }
    >
      {pending ? 'Đang gửi…' : nhan}
    </button>
  )
}

function ThongBao({ trangThai }: { trangThai: TrangThaiForm }) {
  if (trangThai.error !== null) {
    return (
      <p role="alert" className="whitespace-pre-wrap text-sm text-red-600">
        {trangThai.error}
      </p>
    )
  }
  if (trangThai.xong) {
    return <p className="text-sm text-emerald-700 dark:text-emerald-400">{trangThai.xong}</p>
  }
  return null
}

export function KhoiXacNhan({
  payslipId,
  hanXacNhan,
}: {
  payslipId: string
  hanXacNhan: string | null
}) {
  const [trangThaiXN, guiXacNhan] = useActionState(xacNhanPhieu, BAN_DAU)
  const [trangThaiTM, guiThacMac] = useActionState(thacMacPhieu, BAN_DAU)
  const [moThacMac, datMoThacMac] = useState(false)

  return (
    <div className="mt-6 rounded-xl border border-amber-300 bg-amber-50 p-4 dark:border-amber-800 dark:bg-amber-950">
      <p className="font-medium">Kiểm lại phiếu này rồi xác nhận</p>
      <p className="mt-1 text-sm">
        Phiếu lương chỉ được coi là <strong>hợp lệ</strong> khi chính bạn bấm xác nhận. Đọc kỹ ngày
        công, các khoản phụ cấp và số thực nhận ở trên trước khi bấm.
        {hanXacNhan && (
          <>
            {' '}
            Hạn xác nhận: <strong>{hanXacNhan}</strong>. Quá hạn mà bạn chưa bấm gì thì hệ thống
            tự đánh dấu đã xác nhận, và có ghi rõ là tự động.
          </>
        )}
      </p>

      <div className="mt-4 flex flex-wrap items-center gap-3">
        <form action={guiXacNhan}>
          <input type="hidden" name="payslip_id" value={payslipId} />
          <Nut nhan="Tôi xác nhận phiếu này đúng" />
        </form>

        {!moThacMac && (
          <button
            type="button"
            onClick={() => datMoThacMac(true)}
            className="rounded-lg border border-slate-300 px-4 py-2 text-sm font-medium dark:border-slate-700"
          >
            Tôi có thắc mắc
          </button>
        )}
      </div>

      <ThongBao trangThai={trangThaiXN} />

      {moThacMac && (
        <form action={guiThacMac} className="mt-4 space-y-2">
          <input type="hidden" name="payslip_id" value={payslipId} />
          <label htmlFor="ly_do" className="block text-sm font-medium">
            Chỗ nào chưa đúng?
          </label>
          <textarea
            id="ly_do"
            name="ly_do"
            required
            rows={3}
            placeholder="Ví dụ: ngày 12/08 tôi có đi làm nhưng bảng công ghi thiếu."
            className="w-full rounded-lg border border-slate-300 px-3 py-2 text-base outline-none focus:border-slate-900 dark:border-slate-700 dark:bg-slate-950"
          />
          <div className="flex flex-wrap items-center gap-3">
            <Nut nhan="Gửi thắc mắc" phu />
            <button
              type="button"
              onClick={() => datMoThacMac(false)}
              className="text-sm underline"
            >
              Thôi, để sau
            </button>
          </div>
          <ThongBao trangThai={trangThaiTM} />
        </form>
      )}
    </div>
  )
}
