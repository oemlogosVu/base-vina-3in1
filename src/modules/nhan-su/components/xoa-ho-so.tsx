'use client'

import { useActionState, useState } from 'react'
import { useFormStatus } from 'react-dom'
import { xoaNhanSu, type TrangThaiForm } from '@/app/(ung-dung)/nhan-su/quan-tri/actions'

const BAN_DAU: TrangThaiForm = { error: null }

function NutGui() {
  const { pending } = useFormStatus()
  return (
    <button
      type="submit"
      disabled={pending}
      className="rounded-lg bg-red-700 px-4 py-2 text-sm font-medium text-white disabled:opacity-60"
    >
      {pending ? 'Đang xoá…' : 'Chuyển vào thùng rác'}
    </button>
  )
}

/**
 * Xoá hồ sơ nhân sự — chỉ admin thấy khối này.
 *
 * BẮT NHẬP LÝ DO, không phải để làm khó: thùng rác sẽ hiện lý do bên cạnh
 * mỗi hồ sơ, và người đọc sau vài tháng cần biết "xoá vì nhập trùng" khác
 * hẳn "xoá vì nghỉ việc". Ô bắt buộc cũng là một nhịp dừng trước một thao
 * tác không nên bấm theo quán tính.
 *
 * Không có nút xoá vĩnh viễn ở đâu trong app. Hồ sơ vào thùng rác thì nằm đó.
 */
export function XoaHoSo({ employeeId, hoTen }: { employeeId: string; hoTen: string }) {
  const [trangThai, gui] = useActionState(xoaNhanSu, BAN_DAU)
  const [mo, setMo] = useState(false)

  if (!mo) {
    return (
      <button
        type="button"
        onClick={() => setMo(true)}
        className="text-sm text-red-700 underline underline-offset-2 dark:text-red-400"
      >
        Xoá hồ sơ
      </button>
    )
  }

  return (
    <form
      action={gui}
      className="w-full space-y-3 rounded-xl border border-red-200 p-4 dark:border-red-900"
    >
      <input type="hidden" name="employee_id" value={employeeId} />

      <p className="text-sm">
        Chuyển hồ sơ <strong>{hoTen}</strong> vào thùng rác. Hồ sơ sẽ biến mất khỏi danh sách
        nhân sự và <strong>tài khoản đăng nhập của người này bị khoá</strong>. Admin khôi phục
        lại được ở màn Thùng rác.
      </p>
      <p className="text-sm text-slate-500">
        Người đã có phiếu lương thì không xoá được — bảng lương là chứng từ phải lưu 10 năm.
        Trường hợp đó hãy đổi trạng thái hồ sơ sang “nghỉ việc”.
      </p>

      <div>
        <label htmlFor="ly_do" className="mb-1 block text-sm font-medium">
          Lý do xoá *
        </label>
        <input
          id="ly_do"
          name="ly_do"
          required
          placeholder="Ví dụ: nhập trùng với hồ sơ NV-014"
          className="w-full rounded-lg border border-slate-300 px-3 py-2 text-base outline-none focus:border-slate-900 dark:border-slate-700 dark:bg-slate-950"
        />
      </div>

      <div className="flex items-center gap-3">
        <NutGui />
        <button
          type="button"
          onClick={() => setMo(false)}
          className="text-sm text-slate-500 underline underline-offset-2"
        >
          Thôi
        </button>
      </div>

      {trangThai.error !== null && (
        <p role="alert" className="text-sm text-red-600">
          {trangThai.error}
        </p>
      )}
      {trangThai.xong && <p className="text-sm text-green-700">{trangThai.xong}</p>}
    </form>
  )
}
