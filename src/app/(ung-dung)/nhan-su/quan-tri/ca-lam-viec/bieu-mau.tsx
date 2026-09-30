'use client'

import { useActionState } from 'react'
import { useFormStatus } from 'react-dom'
import { capNhatCaLamViec, type TrangThaiForm } from '../actions'

const O_NHAP =
  'w-full rounded-lg border border-slate-300 px-3 py-2 text-base outline-none focus:border-slate-900 dark:border-slate-700 dark:bg-slate-950'

const BAN_DAU: TrangThaiForm = { error: null }

export type CaRut = {
  id: string
  code: string
  name: string
  start_time: string
  end_time: string
  break_start: string | null
  break_end: string | null
  is_active: boolean
}

/** Postgres trả `time` dạng 'HH:MM:SS'; ô input type=time cần 'HH:MM'. */
const gioNgan = (t: string | null) => (t === null ? '' : t.slice(0, 5))

function Nut() {
  const { pending } = useFormStatus()
  return (
    <button
      type="submit"
      disabled={pending}
      className="rounded-lg bg-slate-900 px-4 py-2 text-sm font-medium text-white disabled:opacity-60 dark:bg-slate-100 dark:text-slate-900"
    >
      {pending ? 'Đang lưu…' : 'Lưu'}
    </button>
  )
}

export function FormSuaCa({ ca }: { ca: CaRut }) {
  const [trangThai, gui] = useActionState(capNhatCaLamViec, BAN_DAU)

  return (
    <form action={gui} className="space-y-3">
      <input type="hidden" name="id" value={ca.id} />

      <div className="grid gap-3 sm:grid-cols-6 sm:items-end">
        <div>
          <span className="mb-1 block text-xs uppercase tracking-wide text-slate-500">Mã</span>
          <span className="font-mono text-sm">{ca.code}</span>
        </div>

        <div className="sm:col-span-2">
          <label htmlFor={`name-${ca.id}`} className="mb-1 block text-sm font-medium">
            Tên ca
          </label>
          <input id={`name-${ca.id}`} name="name" defaultValue={ca.name} className={O_NHAP} />
        </div>

        <div>
          <label htmlFor={`start-${ca.id}`} className="mb-1 block text-sm font-medium">
            Giờ vào
          </label>
          <input
            id={`start-${ca.id}`}
            name="start_time"
            type="time"
            defaultValue={gioNgan(ca.start_time)}
            className={O_NHAP}
          />
        </div>

        <div>
          <label htmlFor={`end-${ca.id}`} className="mb-1 block text-sm font-medium">
            Giờ ra
          </label>
          <input
            id={`end-${ca.id}`}
            name="end_time"
            type="time"
            defaultValue={gioNgan(ca.end_time)}
            className={O_NHAP}
          />
        </div>

        <div className="flex items-center gap-3">
          <label className="flex items-center gap-2 text-sm">
            <input type="checkbox" name="is_active" defaultChecked={ca.is_active} />
            Đang dùng
          </label>
        </div>
      </div>

      <div className="grid gap-3 sm:grid-cols-6 sm:items-end">
        <div className="sm:col-start-4">
          <label htmlFor={`bs-${ca.id}`} className="mb-1 block text-sm font-medium">
            Nghỉ từ
          </label>
          <input
            id={`bs-${ca.id}`}
            name="break_start"
            type="time"
            defaultValue={gioNgan(ca.break_start)}
            className={O_NHAP}
          />
        </div>
        <div>
          <label htmlFor={`be-${ca.id}`} className="mb-1 block text-sm font-medium">
            Nghỉ đến
          </label>
          <input
            id={`be-${ca.id}`}
            name="break_end"
            type="time"
            defaultValue={gioNgan(ca.break_end)}
            className={O_NHAP}
          />
        </div>
        <div>
          <Nut />
        </div>
      </div>

      {trangThai.error !== null && (
        <p role="alert" className="text-sm text-red-600">
          {trangThai.error}
        </p>
      )}
    </form>
  )
}
