'use client'

import { useActionState } from 'react'
import { useFormStatus } from 'react-dom'
import { capNhatLoaiPhuCap, taoLoaiPhuCap, type TrangThaiForm } from '../actions'

const O_NHAP =
  'w-full rounded-lg border border-slate-300 px-3 py-2 text-base outline-none focus:border-slate-900 dark:border-slate-700 dark:bg-slate-950'

const BAN_DAU: TrangThaiForm = { error: null }

export type LoaiPhuCapRut = {
  id: string
  code: string
  name: string
  is_taxable: boolean
  is_insurance: boolean
  ghi_chu: string | null
  is_active: boolean
}

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

/**
 * Hai cờ này quyết định tiền, nên nhãn phải nói ra HẬU QUẢ chứ không phải tên
 * cột. "is_taxable" thì người nhập không biết là ảnh hưởng gì; "cộng vào thu
 * nhập chịu thuế TNCN" thì biết.
 */
function OCoThue({ ten, mac, id }: { ten: string; mac: boolean; id?: string }) {
  return (
    <label className="flex items-start gap-2 text-sm">
      <input type="checkbox" name={ten} defaultChecked={mac} className="mt-1" id={id} />
      <span>
        {ten === 'is_taxable' ? 'Chịu thuế TNCN' : 'Tính vào lương đóng bảo hiểm'}
        <span className="block text-xs text-slate-500">
          {ten === 'is_taxable'
            ? 'Bỏ tick nếu khoản này được miễn thuế, ví dụ tiền ăn ca trong định mức.'
            : 'Tick nếu khoản này cộng vào nền tính BHXH / BHYT / BHTN.'}
        </span>
      </span>
    </label>
  )
}

export function FormTaoLoaiPhuCap() {
  const [trangThai, gui] = useActionState(taoLoaiPhuCap, BAN_DAU)

  return (
    <form action={gui} className="space-y-3">
      <div className="grid gap-3 sm:grid-cols-3">
        <div>
          <label htmlFor="code" className="mb-1 block text-sm font-medium">
            Mã loại *
          </label>
          <input id="code" name="code" required className={O_NHAP} placeholder="AN_CA" />
        </div>
        <div className="sm:col-span-2">
          <label htmlFor="name" className="mb-1 block text-sm font-medium">
            Tên loại *
          </label>
          <input id="name" name="name" required className={O_NHAP} placeholder="Phụ cấp ăn ca" />
        </div>
        <div className="sm:col-span-3">
          <label htmlFor="ghi_chu" className="mb-1 block text-sm font-medium">
            Ghi chú
          </label>
          <input id="ghi_chu" name="ghi_chu" className={O_NHAP} />
        </div>
      </div>

      <div className="grid gap-3 sm:grid-cols-2">
        <OCoThue ten="is_taxable" mac id="is_taxable" />
        <OCoThue ten="is_insurance" mac={false} id="is_insurance" />
      </div>

      <Nut nhan="Thêm loại phụ cấp" />
      {trangThai.error !== null && (
        <p role="alert" className="text-sm text-red-600">
          {trangThai.error}
        </p>
      )}
    </form>
  )
}

export function FormSuaLoaiPhuCap({ loai }: { loai: LoaiPhuCapRut }) {
  const [trangThai, gui] = useActionState(capNhatLoaiPhuCap, BAN_DAU)

  return (
    <form action={gui} className="space-y-3">
      <input type="hidden" name="id" value={loai.id} />

      <div className="grid gap-3 sm:grid-cols-3 sm:items-end">
        <div>
          <span className="mb-1 block text-xs uppercase tracking-wide text-slate-500">Mã</span>
          <span className="font-mono text-sm">{loai.code}</span>
        </div>
        <div>
          <label htmlFor={`ten-${loai.id}`} className="mb-1 block text-sm font-medium">
            Tên
          </label>
          <input
            id={`ten-${loai.id}`}
            name="name"
            defaultValue={loai.name}
            className={O_NHAP}
          />
        </div>
        <div>
          <label htmlFor={`gc-${loai.id}`} className="mb-1 block text-sm font-medium">
            Ghi chú
          </label>
          <input
            id={`gc-${loai.id}`}
            name="ghi_chu"
            defaultValue={loai.ghi_chu ?? ''}
            className={O_NHAP}
          />
        </div>
      </div>

      <div className="grid gap-3 sm:grid-cols-3 sm:items-center">
        <OCoThue ten="is_taxable" mac={loai.is_taxable} />
        <OCoThue ten="is_insurance" mac={loai.is_insurance} />
        <div className="flex items-center gap-3">
          <label className="flex items-center gap-2 text-sm">
            <input type="checkbox" name="is_active" defaultChecked={loai.is_active} />
            Đang dùng
          </label>
          <Nut nhan="Lưu" />
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
