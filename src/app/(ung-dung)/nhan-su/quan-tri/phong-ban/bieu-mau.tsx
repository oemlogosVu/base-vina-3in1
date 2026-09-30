'use client'

import { useActionState } from 'react'
import { useFormStatus } from 'react-dom'
import { capNhatPhongBan, taoPhongBan, type TrangThaiForm } from '../actions'

const O_NHAP =
  'w-full rounded-lg border border-slate-300 px-3 py-2 text-base outline-none focus:border-slate-900 dark:border-slate-700 dark:bg-slate-950'

const BAN_DAU: TrangThaiForm = { error: null }

export type PhongBanRut = { id: string; code: string; name: string; parent_id: string | null; manager_id: string | null; is_active: boolean }
export type NhanSuRut = { id: string; full_name: string }

function Nut({ nhan }: { nhan: string }) {
  const { pending } = useFormStatus()
  return (
    <button
      type="submit"
      disabled={pending}
      className="rounded-lg bg-slate-900 px-4 py-2 text-sm font-medium text-white disabled:opacity-60"
    >
      {pending ? 'Đang lưu…' : nhan}
    </button>
  )
}

export function FormTaoPhongBan({ phongBan }: { phongBan: PhongBanRut[] }) {
  const [trangThai, gui] = useActionState(taoPhongBan, BAN_DAU)

  return (
    <form action={gui} className="grid grid-cols-1 gap-3 sm:grid-cols-4 sm:items-end">
      <div>
        <label htmlFor="code" className="mb-1 block text-sm font-medium">
          Mã phòng ban *
        </label>
        <input id="code" name="code" required className={O_NHAP} />
      </div>
      <div>
        <label htmlFor="name" className="mb-1 block text-sm font-medium">
          Tên phòng ban *
        </label>
        <input id="name" name="name" required className={O_NHAP} />
      </div>
      <div>
        <label htmlFor="parent_id" className="mb-1 block text-sm font-medium">
          Trực thuộc
        </label>
        <select id="parent_id" name="parent_id" className={O_NHAP} defaultValue="">
          <option value="">— Cấp cao nhất —</option>
          {phongBan.map((p) => (
            <option key={p.id} value={p.id}>
              {p.name}
            </option>
          ))}
        </select>
      </div>
      <div className="flex flex-col gap-2">
        <Nut nhan="Thêm phòng ban" />
        {trangThai.error !== null && (
          <p role="alert" className="text-sm text-red-600 sm:col-span-4">
            {trangThai.error}
          </p>
        )}
      </div>
    </form>
  )
}

export function FormSuaPhongBan({
  phong,
  phongBan,
  nhanSu,
}: {
  phong: PhongBanRut
  phongBan: PhongBanRut[]
  nhanSu: NhanSuRut[]
}) {
  const [trangThai, gui] = useActionState(capNhatPhongBan, BAN_DAU)

  return (
    <form action={gui} className="grid grid-cols-1 gap-3 sm:grid-cols-5 sm:items-end">
      <input type="hidden" name="id" value={phong.id} />

      <div>
        <span className="mb-1 block text-xs uppercase tracking-wide text-slate-500">Mã</span>
        <span className="font-mono text-sm">{phong.code}</span>
      </div>

      <div>
        <label htmlFor={`name-${phong.id}`} className="mb-1 block text-sm font-medium">
          Tên
        </label>
        <input id={`name-${phong.id}`} name="name" defaultValue={phong.name} className={O_NHAP} />
      </div>

      <div>
        <label htmlFor={`parent-${phong.id}`} className="mb-1 block text-sm font-medium">
          Trực thuộc
        </label>
        <select
          id={`parent-${phong.id}`}
          name="parent_id"
          defaultValue={phong.parent_id ?? ''}
          className={O_NHAP}
        >
          <option value="">— Cấp cao nhất —</option>
          {phongBan
            .filter((p) => p.id !== phong.id)
            .map((p) => (
              <option key={p.id} value={p.id}>
                {p.name}
              </option>
            ))}
        </select>
      </div>

      <div>
        <label htmlFor={`manager-${phong.id}`} className="mb-1 block text-sm font-medium">
          Trưởng phòng
        </label>
        <select
          id={`manager-${phong.id}`}
          name="manager_id"
          defaultValue={phong.manager_id ?? ''}
          className={O_NHAP}
        >
          <option value="">— Chưa gán —</option>
          {nhanSu.map((n) => (
            <option key={n.id} value={n.id}>
              {n.full_name}
            </option>
          ))}
        </select>
      </div>

      <div className="flex items-center gap-3">
        <label className="flex items-center gap-2 text-sm">
          <input type="checkbox" name="is_active" defaultChecked={phong.is_active} />
          Đang dùng
        </label>
        <Nut nhan="Lưu" />
      </div>

      {trangThai.error !== null && (
        <p role="alert" className="text-sm text-red-600 sm:col-span-5">
          {trangThai.error}
        </p>
      )}
    </form>
  )
}
