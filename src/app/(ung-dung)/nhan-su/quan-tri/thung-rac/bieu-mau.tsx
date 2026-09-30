'use client'

import { useActionState } from 'react'
import { useFormStatus } from 'react-dom'
import {
  khoiPhucChamCong,
  khoiPhucNhanSu,
  type TrangThaiForm,
} from '../actions'

const BAN_DAU: TrangThaiForm = { error: null }

function Nut() {
  const { pending } = useFormStatus()
  return (
    <button
      type="submit"
      disabled={pending}
      className="rounded-lg border border-slate-300 px-3 py-1.5 text-sm font-medium hover:bg-slate-50 disabled:opacity-60 dark:border-slate-700 dark:hover:bg-slate-800"
    >
      {pending ? 'Đang khôi phục…' : 'Khôi phục'}
    </button>
  )
}

function KetQua({ trangThai }: { trangThai: TrangThaiForm }) {
  if (trangThai.error !== null) {
    return (
      <p role="alert" className="mt-1 text-sm text-red-600">
        {trangThai.error}
      </p>
    )
  }
  if (trangThai.xong) return <p className="mt-1 text-sm text-green-700">{trangThai.xong}</p>
  return null
}

export function FormKhoiPhucNhanSu({ employeeId }: { employeeId: string }) {
  const [trangThai, gui] = useActionState(khoiPhucNhanSu, BAN_DAU)
  return (
    <form action={gui}>
      <input type="hidden" name="employee_id" value={employeeId} />
      <Nut />
      <KetQua trangThai={trangThai} />
    </form>
  )
}

export function FormKhoiPhucChamCong({ logId }: { logId: string }) {
  const [trangThai, gui] = useActionState(khoiPhucChamCong, BAN_DAU)
  return (
    <form action={gui}>
      <input type="hidden" name="log_id" value={logId} />
      <Nut />
      <KetQua trangThai={trangThai} />
    </form>
  )
}
