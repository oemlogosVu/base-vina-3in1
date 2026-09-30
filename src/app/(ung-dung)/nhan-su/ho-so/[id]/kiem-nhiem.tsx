'use client'

import { useActionState } from 'react'
import { useFormStatus } from 'react-dom'
import {
  doiChucDanhChinh,
  ketThucKiemNhiem,
  themKiemNhiem,
  type TrangThaiForm,
} from '../actions'

const O_NHAP =
  'w-full rounded-lg border border-slate-300 px-3 py-2 text-base outline-none focus:border-slate-900 dark:border-slate-700 dark:bg-slate-950'

const BAN_DAU: TrangThaiForm = { error: null }

export type ChucDanhChon = { id: string; nhan: string }

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
 * Giao thêm một chức danh kiêm nhiệm.
 *
 * Danh sách chọn đã bỏ sẵn chức danh chính và những chức danh đang kiêm —
 * database cũng chặn cả hai, nhưng để người dùng chọn rồi mới báo lỗi là bắt
 * họ đoán.
 */
export function FormThemKiemNhiem({
  employeeId,
  chucDanh,
  homNay,
}: {
  employeeId: string
  chucDanh: ChucDanhChon[]
  homNay: string
}) {
  const [trangThai, gui] = useActionState(themKiemNhiem, BAN_DAU)

  if (chucDanh.length === 0) {
    return (
      <p className="text-sm text-slate-500">
        Không còn chức danh nào để kiêm — người này đã giữ hoặc đang kiêm hết các chức danh
        đang dùng.
      </p>
    )
  }

  return (
    <form action={gui} className="space-y-3">
      <input type="hidden" name="employee_id" value={employeeId} />

      <div className="grid gap-3 sm:grid-cols-3 sm:items-end">
        <div>
          <label htmlFor="kn_position" className="mb-1 block text-sm font-medium">
            Chức danh kiêm
          </label>
          <select id="kn_position" name="position_id" className={O_NHAP} defaultValue="">
            <option value="">— chọn chức danh —</option>
            {chucDanh.map((c) => (
              <option key={c.id} value={c.id}>
                {c.nhan}
              </option>
            ))}
          </select>
        </div>
        <div>
          <label htmlFor="kn_tu_ngay" className="mb-1 block text-sm font-medium">
            Từ ngày
          </label>
          <input
            id="kn_tu_ngay"
            name="tu_ngay"
            type="date"
            defaultValue={homNay}
            className={O_NHAP}
          />
        </div>
        <div>
          <label htmlFor="kn_ly_do" className="mb-1 block text-sm font-medium">
            Căn cứ
          </label>
          <input
            id="kn_ly_do"
            name="ly_do"
            placeholder="Quyết định 12/QĐ ngày…"
            className={O_NHAP}
          />
        </div>
      </div>

      <Nut nhan="Giao kiêm nhiệm" />

      <p className="text-xs text-slate-500">
        Phụ cấp của chức danh kiêm được cộng vào lương. Cùng một loại phụ cấp có ở nhiều chức
        danh thì chỉ hưởng mức cao nhất, không cộng hai suất.
      </p>

      {trangThai.error !== null && (
        <p role="alert" className="text-sm text-red-600">
          {trangThai.error}
        </p>
      )}
    </form>
  )
}

export function FormKetThucKiemNhiem({ id, homNay }: { id: string; homNay: string }) {
  const [trangThai, gui] = useActionState(ketThucKiemNhiem, BAN_DAU)

  return (
    <form action={gui} className="flex flex-wrap items-center gap-2">
      <input type="hidden" name="id" value={id} />
      <input
        name="den_ngay"
        type="date"
        defaultValue={homNay}
        aria-label="Ngày kết thúc kiêm nhiệm"
        className="rounded-lg border border-slate-300 px-2 py-1 text-sm dark:border-slate-700 dark:bg-slate-950"
      />
      <button
        type="submit"
        className="rounded-lg border border-slate-300 px-3 py-1.5 text-sm dark:border-slate-700"
      >
        Kết thúc
      </button>
      {trangThai.error !== null && (
        <span role="alert" className="text-xs text-red-600">
          {trangThai.error}
        </span>
      )}
    </form>
  )
}

/**
 * Đổi chức danh CHÍNH kể từ một ngày.
 *
 * Không phải "sửa ô chức danh" nữa: hành động này đóng chức danh chính đang
 * giữ tại ngày trước ngày hiệu lực, rồi mở dòng mới. Nhờ vậy ba tháng sau vẫn
 * tra được tháng 8 người này giữ chức danh gì — thứ mà biểu mẫu cũ làm mất.
 */
export function FormDoiChucDanhChinh({
  employeeId,
  chucDanh,
  homNay,
  tenHienTai,
}: {
  employeeId: string
  chucDanh: ChucDanhChon[]
  homNay: string
  tenHienTai: string | null
}) {
  const [trangThai, gui] = useActionState(doiChucDanhChinh, BAN_DAU)

  return (
    <form action={gui} className="space-y-3">
      <input type="hidden" name="employee_id" value={employeeId} />

      <p className="text-sm text-slate-500">
        Đang giữ: <strong>{tenHienTai ?? 'chưa gán chức danh nào'}</strong>
      </p>

      <div className="grid gap-3 sm:grid-cols-3 sm:items-end">
        <div>
          <label htmlFor="cd_position" className="mb-1 block text-sm font-medium">
            Chức danh mới
          </label>
          <select id="cd_position" name="position_id" className={O_NHAP} defaultValue="">
            <option value="">— chọn chức danh —</option>
            {chucDanh.map((c) => (
              <option key={c.id} value={c.id}>
                {c.nhan}
              </option>
            ))}
          </select>
        </div>
        <div>
          <label htmlFor="cd_tu_ngay" className="mb-1 block text-sm font-medium">
            Hiệu lực từ
          </label>
          <input
            id="cd_tu_ngay"
            name="tu_ngay"
            type="date"
            defaultValue={homNay}
            className={O_NHAP}
          />
        </div>
        <div>
          <label htmlFor="cd_ly_do" className="mb-1 block text-sm font-medium">
            Căn cứ
          </label>
          <input
            id="cd_ly_do"
            name="ly_do"
            placeholder="Quyết định bổ nhiệm số…"
            className={O_NHAP}
          />
        </div>
      </div>

      <Nut nhan="Đổi chức danh chính" />

      <p className="text-xs text-slate-500">
        Chức danh cũ được đóng lại vào ngày trước ngày hiệu lực, không bị xoá — phiếu lương
        các kỳ trước vẫn giải thích được phụ cấp theo chức danh của chúng.
      </p>

      {trangThai.error !== null && (
        <p role="alert" className="text-sm text-red-600">
          {trangThai.error}
        </p>
      )}
      {trangThai.canhBao && (
        <p
          role="alert"
          className="rounded-lg bg-amber-50 p-3 text-sm text-amber-900 dark:bg-amber-950 dark:text-amber-200"
        >
          {trangThai.canhBao}
        </p>
      )}
    </form>
  )
}
