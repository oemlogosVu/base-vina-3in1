'use client'

import { useActionState, useState } from 'react'
import { useFormStatus } from 'react-dom'
import Link from 'next/link'
import { capNhatChucDanh, luuPhuCapChucDanh, taoChucDanh, type TrangThaiForm } from '../actions'
import { chanEnterTuGui } from '@ns/lib/bieu-mau'

const O_NHAP =
  'w-full rounded-lg border border-slate-300 px-3 py-2 text-base outline-none focus:border-slate-900 dark:border-slate-700 dark:bg-slate-950'

const BAN_DAU: TrangThaiForm = { error: null }

export type ChucDanhRut = {
  id: string
  code: string
  name: string
  is_active: boolean
  /** Số người đang giữ chức danh này — đổi quyền là đổi cho tất cả họ. */
  soNguoiGiu: number
}

export type LoaiPhuCapChon = {
  id: string
  code: string
  name: string
  is_taxable: boolean
  is_insurance: boolean
}

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

export function FormTaoChucDanh() {
  const [trangThai, gui] = useActionState(taoChucDanh, BAN_DAU)

  return (
    <form action={gui} className="grid grid-cols-1 gap-3 sm:grid-cols-3 sm:items-end">
      <div>
        <label htmlFor="code" className="mb-1 block text-sm font-medium">
          Mã chức danh *
        </label>
        <input id="code" name="code" required className={O_NHAP} />
      </div>
      <div>
        <label htmlFor="name" className="mb-1 block text-sm font-medium">
          Tên chức danh *
        </label>
        <input id="name" name="name" required className={O_NHAP} />
      </div>
      <div>
        <Nut nhan="Thêm chức danh" />
      </div>
      {trangThai.error !== null && (
        <p role="alert" className="text-sm text-red-600 sm:col-span-3">
          {trangThai.error}
        </p>
      )}
    </form>
  )
}

export function FormSuaChucDanh({ chucDanh }: { chucDanh: ChucDanhRut }) {
  const [trangThai, gui] = useActionState(capNhatChucDanh, BAN_DAU)

  return (
    <form action={gui} className="space-y-4">
      <input type="hidden" name="id" value={chucDanh.id} />

      <div className="grid grid-cols-1 gap-3 sm:grid-cols-3 sm:items-end">
        <div>
          <span className="mb-1 block text-xs uppercase tracking-wide text-slate-500">Mã</span>
          <span className="font-mono text-sm">{chucDanh.code}</span>
        </div>

        <div>
          <label htmlFor={`name-${chucDanh.id}`} className="mb-1 block text-sm font-medium">
            Tên
          </label>
          <input
            id={`name-${chucDanh.id}`}
            name="name"
            defaultValue={chucDanh.name}
            className={O_NHAP}
          />
        </div>

        <div className="flex items-center gap-3">
          <label className="flex items-center gap-2 text-sm">
            <input type="checkbox" name="is_active" defaultChecked={chucDanh.is_active} />
            Đang dùng
          </label>
          <Nut nhan="Lưu" />
        </div>
      </div>

      <p className="rounded-lg bg-slate-100 p-3 text-xs text-slate-600 dark:bg-slate-800 dark:text-slate-300">
        <strong>Tab được vào và quyền</strong> nay khai cho <strong>từng người</strong> tại{' '}
        <strong>Quản trị → Người dùng</strong>, không khai ở đây nữa — và chúng là{' '}
        <strong>một thứ</strong>: tick tab nào là cấp quyền của tab đó. Màn này còn lại tên,
        trạng thái và phụ cấp.
      </p>

      {trangThai.error !== null && (
        <p role="alert" className="text-sm text-red-600">
          {trangThai.error}
        </p>
      )}
    </form>
  )
}

const TIEN = new Intl.NumberFormat('vi-VN')

/**
 * Phụ cấp mặc định của chức danh.
 *
 * Form riêng chứ không gộp vào form sửa tên/tab ở trên: HTML không cho lồng
 * form, và tách ra thì mỗi nút Lưu chỉ chịu trách nhiệm phần của nó — bấm
 * nhầm không kéo theo phần kia.
 *
 * Gửi lên TOÀN BỘ danh mục loại phụ cấp chứ không riêng dòng được tick, để
 * server phân biệt được "bỏ tick" với "không có trong form".
 */
export function FormPhuCapChucDanh({
  chucDanh,
  loaiPhuCap,
  dangCo,
}: {
  chucDanh: ChucDanhRut
  loaiPhuCap: LoaiPhuCapChon[]
  dangCo: Record<string, number>
}) {
  const [trangThai, gui] = useActionState(luuPhuCapChucDanh, BAN_DAU)
  const [chon, setChon] = useState<Record<string, boolean>>(() =>
    Object.fromEntries(loaiPhuCap.map((l) => [l.id, l.id in dangCo])),
  )

  if (loaiPhuCap.length === 0) {
    return (
      <p className="text-xs text-slate-500">
        Chưa có loại phụ cấp nào để gán.{' '}
        <Link href="/nhan-su/quan-tri/loai-phu-cap" className="underline">
          Khai danh mục loại phụ cấp
        </Link>{' '}
        trước.
      </p>
    )
  }

  // Tổng của những dòng ĐÃ LƯU, không phải của những ô đang gõ dở. Cộng theo
  // ô đang gõ thì con số này nhảy trước khi bấm Lưu và người xem sẽ tưởng đã
  // lưu rồi.
  const tongDaLuu = Object.values(dangCo).reduce((s, v) => s + v, 0)

  return (
    <form
      action={gui}
      // Biểu mẫu này có nhiều ô số. Bấm Enter sau khi gõ một mức là thói quen
      // rất thường, và theo chuẩn HTML nó gửi luôn cả form — lưu cả những mức
      // đang gõ dở ở dòng khác. Đúng lỗi đã gặp ở biểu mẫu hồ sơ nhân sự.
      onKeyDown={(e) => {
        const o = e.target as HTMLElement
        if (chanEnterTuGui(e.key, o.tagName, (o as HTMLInputElement).type)) e.preventDefault()
      }}
      className="space-y-3"
    >
      <input type="hidden" name="position_id" value={chucDanh.id} />

      <ul className="space-y-2">
        {loaiPhuCap.map((l) => (
          <li key={l.id} className="grid grid-cols-[auto_1fr_auto] items-center gap-3">
            <input
              type="checkbox"
              name={`chon_${l.id}`}
              checked={chon[l.id] ?? false}
              onChange={(e) => setChon((t) => ({ ...t, [l.id]: e.target.checked }))}
              id={`chon-${chucDanh.id}-${l.id}`}
            />
            <label htmlFor={`chon-${chucDanh.id}-${l.id}`} className="text-sm">
              {l.name}
              <span className="ml-2 text-xs text-slate-500">
                {l.is_taxable ? 'chịu thuế' : 'miễn thuế'} ·{' '}
                {l.is_insurance ? 'có đóng BH' : 'không đóng BH'}
              </span>
            </label>
            <input
              type="number"
              min="0"
              step="1000"
              name={`muc_${l.id}`}
              defaultValue={dangCo[l.id] ?? ''}
              disabled={!chon[l.id]}
              aria-label={`Mức ${l.name}`}
              placeholder="0"
              className="w-40 rounded-lg border border-slate-300 px-3 py-1.5 text-right text-sm outline-none focus:border-slate-900 disabled:bg-slate-100 disabled:text-slate-400 dark:border-slate-700 dark:bg-slate-950 dark:disabled:bg-slate-900"
            />
          </li>
        ))}
      </ul>

      <div className="flex items-center gap-3">
        <Nut nhan="Lưu phụ cấp" />
        <span className="text-xs text-slate-500">
          Đã lưu: {TIEN.format(tongDaLuu)} ₫/tháng
        </span>
      </div>

      {trangThai.error !== null && (
        <p role="alert" className="text-sm text-red-600">
          {trangThai.error}
        </p>
      )}
    </form>
  )
}
