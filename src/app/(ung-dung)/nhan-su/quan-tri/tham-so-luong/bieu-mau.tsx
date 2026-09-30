'use client'

import { useActionState } from 'react'
import { useFormStatus } from 'react-dom'
import {
  themBacThue,
  themGiamTru,
  themHeSoLamThem,
  themLuongCoSo,
  themLuongToiThieu,
  themTyLeBaoHiem,
  type TrangThaiForm,
} from './actions'

const O_NHAP =
  'w-full rounded-lg border border-slate-300 px-3 py-2 text-base outline-none focus:border-slate-900 dark:border-slate-700 dark:bg-slate-950'

const BAN_DAU: TrangThaiForm = { error: null }

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

function O({
  ten,
  nhan,
  type = 'number',
  step,
  macDinh,
  batBuoc = true,
}: {
  ten: string
  nhan: string
  type?: string
  step?: string
  macDinh?: string | number
  batBuoc?: boolean
}) {
  return (
    <div>
      <label htmlFor={ten} className="mb-1 block text-sm font-medium">
        {nhan}
      </label>
      <input
        id={ten}
        name={ten}
        type={type}
        step={step}
        required={batBuoc}
        defaultValue={macDinh}
        className={O_NHAP}
      />
    </div>
  )
}

export function FormBaoHiem() {
  const [trangThai, gui] = useActionState(themTyLeBaoHiem, BAN_DAU)
  return (
    <form action={gui} className="space-y-3">
      <div className="grid gap-3 sm:grid-cols-3">
        <O ten="effective_from" nhan="Hiệu lực từ" type="date" />
        <O ten="bhxh_employee_pct" nhan="BHXH nhân viên (%)" step="0.01" />
        <O ten="bhxh_employer_pct" nhan="BHXH công ty (%)" step="0.01" />
        <O ten="bhyt_employee_pct" nhan="BHYT nhân viên (%)" step="0.01" />
        <O ten="bhyt_employer_pct" nhan="BHYT công ty (%)" step="0.01" />
        <O ten="bhtn_employee_pct" nhan="BHTN nhân viên (%)" step="0.01" />
        <O ten="bhtn_employer_pct" nhan="BHTN công ty (%)" step="0.01" />
        <O ten="bhxh_cap_multiple" nhan="Trần BHXH (× lương cơ sở)" step="0.01" />
        <O ten="bhtn_cap_multiple" nhan="Trần BHTN (× lương tối thiểu vùng)" step="0.01" />
        <O
          ten="nghi_khong_luong_mien_dong_ngay"
          nhan="Nghỉ không lương từ (ngày) thì miễn đóng"
          step="0.5"
          batBuoc={false}
        />
      </div>
      <p className="text-xs text-slate-500">
        Để trống ô cuối nghĩa là luôn đóng đủ bảo hiểm, kể cả tháng nghỉ nhiều — an toàn hơn
        theo hướng người lao động, vì không đóng là mất tháng bảo hiểm của họ.
      </p>
      <div>
        <label htmlFor="ghi_chu" className="mb-1 block text-sm font-medium">
          Căn cứ pháp lý
        </label>
        <input id="ghi_chu" name="ghi_chu" placeholder="Số hiệu văn bản" className={O_NHAP} />
      </div>
      <Nut nhan="Thêm tỷ lệ bảo hiểm" />
      <ThongBao trangThai={trangThai} />
    </form>
  )
}

export function FormBacThue() {
  const [trangThai, gui] = useActionState(themBacThue, BAN_DAU)
  return (
    <form action={gui} className="space-y-3">
      <div className="grid gap-3 sm:grid-cols-5">
        <O ten="effective_from" nhan="Hiệu lực từ" type="date" />
        <O ten="level" nhan="Bậc" macDinh={1} />
        <O ten="from_amount" nhan="Từ (đồng)" step="1" macDinh={0} />
        <O ten="to_amount" nhan="Đến (đồng)" step="1" batBuoc={false} />
        <O ten="rate" nhan="Thuế suất (%)" step="0.01" />
      </div>
      <p className="text-xs text-slate-500">
        Thêm từng bậc một, dùng chung một ngày hiệu lực. Bậc cuối cùng để trống ô “Đến”. Hệ
        thống không giới hạn số bậc — 5 bậc hay 7 bậc đều chạy đúng.
      </p>
      <Nut nhan="Thêm bậc thuế" />
      <ThongBao trangThai={trangThai} />
    </form>
  )
}

export function FormGiamTru() {
  const [trangThai, gui] = useActionState(themGiamTru, BAN_DAU)
  return (
    <form action={gui} className="space-y-3">
      <div className="grid gap-3 sm:grid-cols-3">
        <O ten="effective_from" nhan="Hiệu lực từ" type="date" />
        <O ten="personal_amount" nhan="Giảm trừ bản thân (đồng/tháng)" step="1" />
        <O ten="dependent_amount" nhan="Mỗi người phụ thuộc (đồng/tháng)" step="1" />
      </div>
      <Nut nhan="Thêm mức giảm trừ" />
      <ThongBao trangThai={trangThai} />
    </form>
  )
}

export function FormLuongCoSo() {
  const [trangThai, gui] = useActionState(themLuongCoSo, BAN_DAU)
  return (
    <form action={gui} className="space-y-3">
      <div className="grid gap-3 sm:grid-cols-2">
        <O ten="effective_from" nhan="Hiệu lực từ" type="date" />
        <O ten="amount" nhan="Lương cơ sở (đồng)" step="1" />
      </div>
      <Nut nhan="Thêm lương cơ sở" />
      <ThongBao trangThai={trangThai} />
    </form>
  )
}

export function FormLuongToiThieu() {
  const [trangThai, gui] = useActionState(themLuongToiThieu, BAN_DAU)
  return (
    <form action={gui} className="space-y-3">
      <div className="grid gap-3 sm:grid-cols-3">
        <O ten="effective_from" nhan="Hiệu lực từ" type="date" />
        <O ten="region" nhan="Vùng (1–4)" macDinh={1} />
        <O ten="amount" nhan="Mức lương (đồng)" step="1" />
      </div>
      <Nut nhan="Thêm lương tối thiểu vùng" />
      <ThongBao trangThai={trangThai} />
    </form>
  )
}

export function FormLamThem() {
  const [trangThai, gui] = useActionState(themHeSoLamThem, BAN_DAU)
  return (
    <form action={gui} className="space-y-3">
      <div className="grid gap-3 sm:grid-cols-4">
        <O ten="effective_from" nhan="Hiệu lực từ" type="date" />
        <O ten="ngay_thuong_pct" nhan="Ngày thường (%)" step="0.01" />
        <O ten="ngay_nghi_tuan_pct" nhan="Ngày nghỉ tuần (%)" step="0.01" />
        <O ten="ngay_le_pct" nhan="Ngày lễ (%)" step="0.01" />
      </div>
      <div>
        <label htmlFor="ghi_chu_ot" className="mb-1 block text-sm font-medium">
          Căn cứ pháp lý
        </label>
        <input id="ghi_chu_ot" name="ghi_chu" placeholder="Số hiệu văn bản" className={O_NHAP} />
      </div>
      <Nut nhan="Thêm hệ số làm thêm" />
      <ThongBao trangThai={trangThai} />
    </form>
  )
}
