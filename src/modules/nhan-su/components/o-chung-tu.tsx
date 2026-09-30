'use client'

import { useActionState } from 'react'
import { useFormStatus } from 'react-dom'
import { sinhChungTuLai, type TrangThaiChungTu } from '@ns/lib/chung-tu-actions'

const BAN_DAU: TrangThaiChungTu = { error: null }

function NutSinh() {
  const { pending } = useFormStatus()
  return (
    <button
      type="submit"
      disabled={pending}
      className="rounded-lg border border-amber-500 px-3 py-1.5 text-xs font-medium text-amber-800 disabled:opacity-60 dark:text-amber-300"
    >
      {pending ? 'Đang sinh…' : 'Sinh chứng từ'}
    </button>
  )
}

/**
 * Ô chứng từ của một bảng thanh toán hoặc một kỳ lương.
 *
 * Hai trạng thái, và trạng thái THIẾU phải nhìn thấy được chứ không được im
 * lặng: chứng từ sinh sau khi chốt bằng một lời gọi mạng, mà lời gọi ấy hỏng
 * được. Im lặng thì ba tháng sau mới phát hiện không có chứng từ nào.
 */
export function OChungTu({
  loai,
  doiTuongId,
  soHieu,
  duongTai,
}: {
  loai: 'bang_thanh_toan_to' | 'ky_luong'
  doiTuongId: string
  soHieu?: string
  duongTai?: string | null
}) {
  const [trangThai, chay] = useActionState(sinhChungTuLai, BAN_DAU)

  if (soHieu) {
    return duongTai ? (
      <a
        href={duongTai}
        target="_blank"
        rel="noopener noreferrer"
        className="text-sm underline"
        title="Đường tải có hạn 10 phút"
      >
        Chứng từ {soHieu} (PDF)
      </a>
    ) : (
      <span className="text-sm text-slate-500">Chứng từ {soHieu}</span>
    )
  }

  return (
    <form action={chay} className="flex flex-wrap items-center gap-2">
      <input type="hidden" name="loai" value={loai} />
      <input type="hidden" name="doi_tuong_id" value={doiTuongId} />
      <span className="text-xs text-amber-800 dark:text-amber-300">Chưa có chứng từ</span>
      <NutSinh />
      {trangThai.error && (
        <span className="text-xs text-red-600 dark:text-red-400">{trangThai.error}</span>
      )}
      {trangThai.xong && <span className="text-xs text-green-700">{trangThai.xong}</span>}
    </form>
  )
}
