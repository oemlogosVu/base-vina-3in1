'use client'

import { useActionState, useState } from 'react'
import { useFormStatus } from 'react-dom'
import {
  chotKyLuong,
  danhDauDaTra,
  taoKyLuong,
  tinhLuong,
  type TrangThaiForm,
} from '../actions'

export type CongTyChonDuoc = { id: string; name: string; standard_days: number | null }

const O_NHAP =
  'w-full rounded-lg border border-slate-300 px-3 py-2 text-base outline-none focus:border-slate-900 dark:border-slate-700 dark:bg-slate-950'

const BAN_DAU: TrangThaiForm = { error: null }

function ThongBao({ trangThai }: { trangThai: TrangThaiForm }) {
  if (trangThai.error !== null) {
    return (
      <p role="alert" className="whitespace-pre-wrap text-sm text-red-600">
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

export function FormTaoKy({
  thangMacDinh,
  namMacDinh,
  congTy,
}: {
  thangMacDinh: number
  namMacDinh: number
  congTy: CongTyChonDuoc[]
}) {
  const [trangThai, gui] = useActionState(taoKyLuong, BAN_DAU)

  // Ô công chuẩn tự điền theo công ty vừa chọn, nhưng vẫn gõ đè được cho một
  // kỳ đặc biệt. Giữ trong state chứ không dùng `key` để ép dựng lại ô nhập:
  // đổi công ty rồi đổi lại phải trả về mức của công ty, không giữ số đã gõ
  // cho công ty kia — đó là đường ra một kỳ lương chia sai mẫu số.
  const [daChon, datDaChon] = useState<CongTyChonDuoc | null>(null)
  const [congChuan, datCongChuan] = useState('')

  function chonCongTy(id: string) {
    const c = congTy.find((x) => x.id === id) ?? null
    datDaChon(c)
    datCongChuan(c?.standard_days == null ? '' : String(c.standard_days))
  }

  const thieuCongChuan = daChon !== null && daChon.standard_days === null
  const daSuaKhacCongTy =
    daChon?.standard_days != null && congChuan !== '' && Number(congChuan) !== daChon.standard_days

  return (
    <form action={gui} className="grid gap-3 sm:grid-cols-5 sm:items-end">
      <div className="sm:col-span-2">
        <label htmlFor="company_id" className="mb-1 block text-sm font-medium">
          Công ty
        </label>
        <select
          id="company_id"
          name="company_id"
          className={O_NHAP}
          defaultValue=""
          onChange={(e) => chonCongTy(e.target.value)}
        >
          <option value="">— Chọn công ty —</option>
          {congTy.map((c) => (
            <option key={c.id} value={c.id}>
              {c.name}
            </option>
          ))}
        </select>
      </div>
      <div>
        <label htmlFor="month" className="mb-1 block text-sm font-medium">
          Tháng
        </label>
        <input
          id="month"
          name="month"
          type="number"
          min={1}
          max={12}
          defaultValue={thangMacDinh}
          className={O_NHAP}
        />
      </div>
      <div>
        <label htmlFor="year" className="mb-1 block text-sm font-medium">
          Năm
        </label>
        <input
          id="year"
          name="year"
          type="number"
          min={2020}
          max={2100}
          defaultValue={namMacDinh}
          className={O_NHAP}
        />
      </div>
      <div>
        <label htmlFor="standard_days" className="mb-1 block text-sm font-medium">
          Công tiêu chuẩn
        </label>
        <input
          id="standard_days"
          name="standard_days"
          type="number"
          step="0.5"
          min={1}
          max={31}
          value={congChuan}
          onChange={(e) => datCongChuan(e.target.value)}
          placeholder={daChon === null ? 'chọn công ty' : 'chưa khai'}
          className={O_NHAP}
        />
      </div>
      <div>
        <Nut nhan="Tạo kỳ" />
      </div>

      {thieuCongChuan && (
        <p className="text-sm text-amber-700 sm:col-span-5 dark:text-amber-400">
          {daChon?.name} chưa khai công tiêu chuẩn. Khai tại{' '}
          <strong>Quản trị → Công ty</strong> để mọi kỳ sau này dùng chung một mẫu số, hoặc gõ số
          cho riêng kỳ này.
        </p>
      )}

      {daSuaKhacCongTy && (
        <p className="text-sm text-amber-700 sm:col-span-5 dark:text-amber-400">
          Kỳ này sẽ chia cho <strong>{congChuan}</strong> thay vì mức{' '}
          <strong>{daChon?.standard_days}</strong> của {daChon?.name}. Cả bảng lương và đơn giá giờ
          làm thêm đều theo con số này.
        </p>
      )}

      <div className="sm:col-span-5">
        <ThongBao trangThai={trangThai} />
      </div>
    </form>
  )
}

export function FormTinhLuong({ periodId }: { periodId: string }) {
  const [trangThai, gui] = useActionState(tinhLuong, BAN_DAU)

  return (
    <form action={gui} className="space-y-2">
      <input type="hidden" name="period_id" value={periodId} />
      <Nut nhan="Tính lương kỳ này" />
      <ThongBao trangThai={trangThai} />
    </form>
  )
}

export function FormChotKy({ periodId }: { periodId: string }) {
  const [trangThai, gui] = useActionState(chotKyLuong, BAN_DAU)

  return (
    <form action={gui} className="space-y-2">
      <input type="hidden" name="period_id" value={periodId} />
      <Nut nhan="Chốt kỳ và gửi" phu />
      <p className="text-xs text-slate-500">
        Chốt là một chiều. Phiếu lương hết sửa được, và được gửi cho người lao động xác nhận.
      </p>
      <ThongBao trangThai={trangThai} />
    </form>
  )
}

export function FormDaTra({ periodId, conThieu }: { periodId: string; conThieu: number }) {
  const [trangThai, gui] = useActionState(danhDauDaTra, BAN_DAU)

  return (
    <form action={gui} className="space-y-2">
      <input type="hidden" name="period_id" value={periodId} />
      <Nut nhan="Đánh dấu đã trả" phu />
      <p className="text-xs text-slate-500">
        {conThieu > 0
          ? `Còn ${conThieu} người chưa xác nhận — bấm vào sẽ bị từ chối kèm danh sách tên.`
          : 'Mọi người đã xác nhận. Kỳ này đánh dấu trả được.'}
      </p>
      <ThongBao trangThai={trangThai} />
    </form>
  )
}
