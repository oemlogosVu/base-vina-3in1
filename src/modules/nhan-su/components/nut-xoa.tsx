'use client'

import { useActionState, useState } from 'react'
import { useFormStatus } from 'react-dom'
import { xoaDanhMuc, type TrangThaiForm } from '@/app/(ung-dung)/nhan-su/quan-tri/actions'

const BAN_DAU: TrangThaiForm = { error: null }

function NutGui({ nhan }: { nhan: string }) {
  const { pending } = useFormStatus()
  return (
    <button
      type="submit"
      disabled={pending}
      className="rounded-lg border border-red-300 px-3 py-1.5 text-sm font-medium text-red-700 hover:bg-red-50 disabled:opacity-60 dark:border-red-800 dark:text-red-400 dark:hover:bg-red-950"
    >
      {pending ? 'Đang xoá…' : nhan}
    </button>
  )
}

/**
 * Nút xoá một dòng danh mục, có bước xác nhận.
 *
 * Hai bước chứ không phải `window.confirm`: hộp thoại của trình duyệt không
 * nói được dòng nào đang bị xoá cho rõ, bị chặn ở vài cấu hình, và không kiểm
 * tra tự động được. Ở đây bước xác nhận nhắc lại đúng TÊN dòng sắp mất.
 *
 * Không cần cảnh báo "không hoàn tác được": xoá chỉ thành công khi không còn
 * gì tham chiếu, tức là không có dữ liệu nào để mất. Nếu còn thì khoá ngoại
 * chặn và người dùng nhận câu giải thích thay vì mất dữ liệu.
 */
export function NutXoaDanhMuc({
  bang,
  id,
  ten,
}: {
  bang: 'departments' | 'positions' | 'work_shifts' | 'companies' | 'allowance_types'
  id: string
  ten: string
}) {
  const [trangThai, gui] = useActionState(xoaDanhMuc, BAN_DAU)
  const [hoi, setHoi] = useState(false)

  if (!hoi) {
    return (
      <div className="space-y-1">
        <button
          type="button"
          onClick={() => setHoi(true)}
          className="text-sm text-red-700 underline underline-offset-2 dark:text-red-400"
        >
          Xoá
        </button>
        {trangThai.error !== null && (
          <p role="alert" className="text-sm text-red-600">
            {trangThai.error}
          </p>
        )}
      </div>
    )
  }

  return (
    <form action={gui} className="space-y-2">
      <input type="hidden" name="bang" value={bang} />
      <input type="hidden" name="id" value={id} />
      <input type="hidden" name="ten" value={ten} />
      <p className="text-sm">
        Xoá <strong>{ten}</strong>?
      </p>
      <div className="flex items-center gap-3">
        <NutGui nhan="Xoá hẳn" />
        <button
          type="button"
          onClick={() => setHoi(false)}
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
    </form>
  )
}
