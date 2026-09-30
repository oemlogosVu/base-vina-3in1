'use client'

import { useActionState } from 'react'
import { useFormStatus } from 'react-dom'
import { themMucLuong, type TrangThaiForm } from '../actions'

const O_NHAP =
  'w-full rounded-lg border border-slate-300 px-3 py-2 text-base outline-none focus:border-slate-900 dark:border-slate-700 dark:bg-slate-950'

const BAN_DAU: TrangThaiForm = { error: null }

function Nut() {
  const { pending } = useFormStatus()
  return (
    <button
      type="submit"
      disabled={pending}
      className="rounded-lg bg-slate-900 px-4 py-2 text-sm font-medium text-white disabled:opacity-60 dark:bg-slate-100 dark:text-slate-900"
    >
      {pending ? 'Đang lưu…' : 'Thêm mức lương'}
    </button>
  )
}

/**
 * Thêm một mức lương có ngày áp dụng.
 *
 * Cố ý KHÔNG điền sẵn mức hiện tại vào hai ô: điền sẵn thì người dùng sửa một
 * chữ số rồi bấm lưu, và thao tác đó cảm giác y hệt "sửa lương" cũ — trong khi
 * đây là một hành động khác hẳn về hệ quả. Gõ lại cả con số là một nhịp dừng
 * nhỏ, và nhịp dừng ấy đúng chỗ khi đang đổi tiền của người khác.
 */
export function FormThemMucLuong({
  contractId,
  homNay,
}: {
  contractId: string | null
  homNay: string
}) {
  const [trangThai, gui] = useActionState(themMucLuong, BAN_DAU)

  if (!contractId) {
    return (
      <p className="text-sm text-slate-500">
        Nhân viên này chưa có hợp đồng lao động đang hiệu lực, nên chưa gắn được mức lương.
        Tạo hợp đồng ở màn <strong>Sửa hồ sơ</strong> trước.
      </p>
    )
  }

  return (
    <form action={gui} className="space-y-3">
      <input type="hidden" name="contract_id" value={contractId} />

      <div className="grid gap-3 sm:grid-cols-4 sm:items-end">
        <div>
          <label htmlFor="tu_ngay" className="mb-1 block text-sm font-medium">
            Áp dụng từ ngày
          </label>
          <input id="tu_ngay" name="tu_ngay" type="date" defaultValue={homNay} className={O_NHAP} />
        </div>
        <div>
          <label htmlFor="position_salary" className="mb-1 block text-sm font-medium">
            Lương chức danh
          </label>
          <input
            id="position_salary"
            name="position_salary"
            type="number"
            min="0"
            step="1000"
            className={O_NHAP}
          />
        </div>
        <div>
          <label htmlFor="bhxh_salary" className="mb-1 block text-sm font-medium">
            Lương đóng BHXH
          </label>
          <input
            id="bhxh_salary"
            name="bhxh_salary"
            type="number"
            min="0"
            step="1000"
            className={O_NHAP}
          />
        </div>
        <div>
          <label htmlFor="ly_do" className="mb-1 block text-sm font-medium">
            Lý do
          </label>
          <input
            id="ly_do"
            name="ly_do"
            placeholder="Tăng lương định kỳ"
            className={O_NHAP}
          />
        </div>
      </div>

      <Nut />

      <p className="text-xs text-slate-500">
        Những ngày trước ngày áp dụng vẫn tính theo mức cũ. Riêng bảo hiểm đóng theo mức của
        ngày đầu kỳ lương, nên tăng lương giữa tháng thì tháng đó vẫn đóng mức cũ.
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
      {trangThai.error === null && !trangThai.canhBao && trangThai !== BAN_DAU && (
        <p className="text-sm text-emerald-700 dark:text-emerald-400">Đã thêm mức lương.</p>
      )}
    </form>
  )
}
