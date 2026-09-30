'use client'

import { useActionState, useState } from 'react'
import { useFormStatus } from 'react-dom'
import { datTyLeLamThem, tongHopLai, xacNhanCaNgay, xacNhanMotLan, type TrangThaiForm } from '../actions'
import { xoaChamCong } from '@/app/(ung-dung)/nhan-su/quan-tri/actions'

const O_NHAP =
  'w-full rounded-lg border border-slate-300 px-3 py-2 text-base outline-none focus:border-slate-900 dark:border-slate-700 dark:bg-slate-950'

const BAN_DAU: TrangThaiForm = { error: null }

function ThongBao({ trangThai }: { trangThai: TrangThaiForm }) {
  if (trangThai.error !== null) {
    return (
      <p role="alert" className="text-sm text-red-600">
        {trangThai.error}
      </p>
    )
  }
  if (trangThai.xong) {
    return <p className="text-sm text-emerald-700 dark:text-emerald-400">{trangThai.xong}</p>
  }
  return null
}

function Nut({ nhan, phu = false }: { nhan: string; phu?: boolean }) {
  const { pending } = useFormStatus()
  return (
    <button
      type="submit"
      disabled={pending}
      className={
        phu
          ? 'rounded-lg border border-slate-300 px-4 py-2 text-sm font-medium disabled:opacity-60 dark:border-slate-700'
          : 'rounded-lg bg-slate-900 px-4 py-2 text-sm font-medium text-white disabled:opacity-60 dark:bg-slate-100 dark:text-slate-900'
      }
    >
      {pending ? 'Đang chạy…' : nhan}
    </button>
  )
}

/**
 * Xác nhận cả ngày — đây là cách dùng chính.
 *
 * Nhân sự nhìn danh sách một ngày, thấy hợp lý thì xác nhận một lần cho cả
 * ngày. Xác nhận lẻ từng lần chỉ dùng cho trường hợp cá biệt.
 */
export function FormXacNhanCaNgay({ ngayMacDinh }: { ngayMacDinh: string }) {
  const [trangThai, gui] = useActionState(xacNhanCaNgay, BAN_DAU)

  return (
    <form action={gui} className="space-y-3">
      <div className="flex flex-wrap items-end gap-3">
        <div>
          <label htmlFor="ngay-xac-nhan" className="mb-1 block text-sm font-medium">
            Ngày cần xác nhận
          </label>
          <input
            id="ngay-xac-nhan"
            name="ngay"
            type="date"
            defaultValue={ngayMacDinh}
            className={O_NHAP}
          />
        </div>
        <div className="min-w-56 flex-1">
          <label htmlFor="ghi-chu-ngay" className="mb-1 block text-sm font-medium">
            Ghi chú (không bắt buộc)
          </label>
          <input id="ghi-chu-ngay" name="ghi_chu" className={O_NHAP} />
        </div>
        <Nut nhan="Xác nhận cả ngày" />
      </div>
      <ThongBao trangThai={trangThai} />
    </form>
  )
}

export function FormXacNhanMotLan({ id }: { id: string }) {
  const [trangThai, gui] = useActionState(xacNhanMotLan, BAN_DAU)

  return (
    <form action={gui} className="mt-3 space-y-2">
      <input type="hidden" name="id" value={id} />
      <input
        name="ghi_chu"
        placeholder="Ghi chú — bắt buộc khi không công nhận"
        className={O_NHAP}
        aria-label="Ghi chú"
      />
      <div className="flex flex-wrap gap-2">
        <button
          type="submit"
          name="quyet_dinh"
          value="cong_nhan"
          className="rounded-lg bg-emerald-700 px-4 py-2 text-sm font-medium text-white"
        >
          Công nhận
        </button>
        <button
          type="submit"
          name="quyet_dinh"
          value="tu_choi"
          className="rounded-lg border border-slate-300 px-4 py-2 text-sm font-medium dark:border-slate-700"
        >
          Không công nhận
        </button>
      </div>
      <ThongBao trangThai={trangThai} />
    </form>
  )
}

export function FormTongHopLai({ ngayMacDinh }: { ngayMacDinh: string }) {
  const [trangThai, gui] = useActionState(tongHopLai, BAN_DAU)

  return (
    <form action={gui} className="flex flex-wrap items-end gap-3">
      <div>
        <label htmlFor="ngay-tong-hop" className="mb-1 block text-sm font-medium">
          Ngày cần tổng hợp lại
        </label>
        <input
          id="ngay-tong-hop"
          name="ngay"
          type="date"
          defaultValue={ngayMacDinh}
          className={O_NHAP}
        />
      </div>
      <Nut nhan="Tổng hợp lại" phu />
      <div className="w-full">
        <ThongBao trangThai={trangThai} />
      </div>
    </form>
  )
}

/**
 * Xoá một lần chấm ĐÃ xác nhận.
 *
 * Hai bước, và bước hai nói thẳng hệ quả: xoá xong hệ thống tổng hợp lại
 * bảng công ngay, nên số ngày công của người đó đổi lập tức. Người bấm cần
 * biết điều đó TRƯỚC khi bấm, không phải sau.
 */
export function FormXoaLanCham({ id, moTa }: { id: string; moTa: string }) {
  const [trangThai, gui] = useActionState(xoaChamCong, BAN_DAU)
  const [hoi, setHoi] = useState(false)

  if (trangThai.xong) return <p className="mt-2 text-sm text-green-700">{trangThai.xong}</p>

  if (!hoi) {
    return (
      <button
        type="button"
        onClick={() => setHoi(true)}
        className="mt-2 text-sm text-red-700 underline underline-offset-2 dark:text-red-400"
      >
        Xoá lần chấm này
      </button>
    )
  }

  return (
    <form action={gui} className="mt-2 space-y-2">
      <input type="hidden" name="log_id" value={id} />
      <p className="text-sm">
        Xoá <strong>{moTa}</strong>? Bảng công ngày đó sẽ được tổng hợp lại ngay, nên số ngày
        công và tiền lương của kỳ chưa chốt sẽ đổi theo. Khôi phục được ở màn Thùng rác.
      </p>
      <div>
        <label htmlFor={`ly-do-${id}`} className="mb-1 block text-sm font-medium">
          Lý do (không bắt buộc)
        </label>
        <input
          id={`ly-do-${id}`}
          name="ly_do"
          placeholder="Ví dụ: bấm nhầm hộ người khác"
          className={O_NHAP}
        />
      </div>
      <div className="flex items-center gap-3">
        <Nut nhan="Xoá" />
        <button
          type="button"
          onClick={() => setHoi(false)}
          className="text-sm text-slate-500 underline underline-offset-2"
        >
          Thôi
        </button>
      </div>
      <ThongBao trangThai={trangThai} />
    </form>
  )
}

/**
 * Đặt tỷ lệ % làm thêm cho một ngày cụ thể của một người.
 *
 * Ô nhập để trống = dùng hệ số mặc định theo loại ngày. Nhãn phải nói rõ mặc
 * định đang là bao nhiêu, nếu không người dùng không biết mình đang đè lên
 * con số nào.
 */
export function FormTyLeLamThem({
  id,
  hienTai,
  macDinh,
}: {
  id: string
  hienTai: number | null
  macDinh: number
}) {
  const [trangThai, gui] = useActionState(datTyLeLamThem, BAN_DAU)

  return (
    <form action={gui} className="flex flex-wrap items-center gap-2">
      <input type="hidden" name="ngay_cong_id" value={id} />
      <input
        type="number"
        name="ty_le"
        min="100"
        step="10"
        defaultValue={hienTai ?? ''}
        placeholder={`${macDinh}`}
        aria-label="Tỷ lệ phần trăm làm thêm"
        className="w-28 rounded-lg border border-slate-300 px-3 py-1.5 text-right text-sm outline-none focus:border-slate-900 dark:border-slate-700 dark:bg-slate-950"
      />
      <span className="text-sm text-slate-500">%</span>
      <Nut nhan="Lưu" phu />
      <div className="w-full">
        <ThongBao trangThai={trangThai} />
      </div>
    </form>
  )
}
