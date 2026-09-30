'use client'

import { useActionState } from 'react'
import { useFormStatus } from 'react-dom'
import {
  chamBuCong,
  chamBuHangLoat,
  moLaiPhien,
  taoTruyLinh,
  xoaLanChamSai,
  type TrangThaiForm,
} from './actions'

const O_NHAP =
  'w-full rounded-lg border border-slate-300 px-3 py-2 text-base outline-none focus:border-slate-900 dark:border-slate-700 dark:bg-slate-950'

const BAN_DAU: TrangThaiForm = { error: null }

function Nut({ nhan, dangChay, mau = 'den' }: { nhan: string; dangChay: string; mau?: 'den' | 'do' }) {
  const { pending } = useFormStatus()
  const lop =
    mau === 'do'
      ? 'rounded-lg border border-red-500 px-4 py-2 text-sm font-medium text-red-700 disabled:opacity-60 dark:text-red-400'
      : 'rounded-lg bg-slate-900 px-4 py-2 text-sm font-medium text-white disabled:opacity-60 dark:bg-slate-100 dark:text-slate-900'
  return (
    <button type="submit" disabled={pending} className={lop}>
      {pending ? dangChay : nhan}
    </button>
  )
}

function BaoTrangThai({ trangThai }: { trangThai: TrangThaiForm }) {
  if (trangThai.error) {
    return (
      <p role="alert" className="text-sm text-red-600 dark:text-red-400">
        {trangThai.error}
      </p>
    )
  }
  if (trangThai.xong) {
    return <p className="text-sm text-green-700 dark:text-green-400">{trangThai.xong}</p>
  }
  return null
}

/**
 * Ô lý do — có mặt ở MỌI biểu mẫu trong màn này, không có ngoại lệ.
 *
 * Đây là dòng duy nhất, ba tháng sau, giải thích vì sao một ngày công xuất
 * hiện mà không ai bấm. Database cũng đòi tối thiểu 10 ký tự, nên bỏ trống là
 * bị từ chối ở cả hai tầng.
 */
function OLyDo({ goiY }: { goiY: string }) {
  return (
    <label className="block text-sm">
      <span className="mb-1 block font-medium">
        Lý do <span className="text-red-600">*</span>
      </span>
      <textarea name="ly_do" rows={2} required minLength={10} placeholder={goiY} className={O_NHAP} />
      <span className="mt-1 block text-xs text-slate-500">
        Ít nhất 10 ký tự. Câu này đi vào sổ ghi vết và không sửa được về sau.
      </span>
    </label>
  )
}

export function FormChamBu({ employeeId, ngay }: { employeeId: string; ngay: string }) {
  const [trangThai, chay] = useActionState(chamBuCong, BAN_DAU)
  return (
    <form action={chay} className="space-y-3">
      <input type="hidden" name="employee_id" value={employeeId} />
      <input type="hidden" name="work_date" value={ngay} />

      <div className="flex flex-wrap gap-3">
        <label className="text-sm">
          <span className="mb-1 block font-medium">Giờ vào</span>
          <input type="time" name="gio_vao" required defaultValue="08:00" className={O_NHAP} />
        </label>
        <label className="text-sm">
          <span className="mb-1 block font-medium">Giờ ra</span>
          <input type="time" name="gio_ra" required defaultValue="17:00" className={O_NHAP} />
        </label>
      </div>

      <OLyDo goiY="Ví dụ: quên bấm giờ ra, có xác nhận của tổ trưởng ngày 21/08" />

      <div className="flex flex-wrap items-center gap-3">
        <Nut nhan="Chấm bù ngày này" dangChay="Đang ghi…" />
        <BaoTrangThai trangThai={trangThai} />
      </div>
    </form>
  )
}

/**
 * Chấm bù cho cả nhóm: tick người, gõ một lần giờ và một lần lý do.
 *
 * Bảng người nằm BÊN TRONG form này (truyền qua `children`) để ô tick đi cùng
 * một lượt gửi với giờ và lý do. Tách ra hai form là phải tự đồng bộ trạng
 * thái giữa chúng, và thứ tự bấm sẽ quyết định dữ liệu nào được gửi.
 */
export function FormChamBuHangLoat({
  ngay,
  soNguoiCoTheBu,
  children,
}: {
  ngay: string
  soNguoiCoTheBu: number
  children: React.ReactNode
}) {
  const [trangThai, chay] = useActionState(chamBuHangLoat, BAN_DAU)

  return (
    <form action={chay}>
      <input type="hidden" name="work_date" value={ngay} />

      <div className="mb-3 flex flex-wrap items-end gap-3">
        <label className="text-sm">
          <span className="mb-1 block font-medium">Giờ vào</span>
          <input type="time" name="gio_vao" required defaultValue="08:00" className={O_NHAP} />
        </label>
        <label className="text-sm">
          <span className="mb-1 block font-medium">Giờ ra</span>
          <input type="time" name="gio_ra" required defaultValue="17:00" className={O_NHAP} />
        </label>
        <label className="min-w-64 flex-1 text-sm">
          <span className="mb-1 block font-medium">
            Lý do chung <span className="text-red-600">*</span>
          </span>
          <input
            type="text"
            name="ly_do"
            required
            minLength={10}
            placeholder="Ví dụ: máy chấm công hỏng cả ngày 20/08, tổ trưởng xác nhận"
            className={O_NHAP}
          />
        </label>
      </div>

      {children}

      {soNguoiCoTheBu > 0 && (
        <div className="mt-3 flex flex-wrap items-center gap-3">
          <Nut nhan="Chấm bù cho những người đã tick" dangChay="Đang ghi…" />
          <BaoTrangThai trangThai={trangThai} />
        </div>
      )}
      {soNguoiCoTheBu === 0 && <BaoTrangThai trangThai={trangThai} />}
    </form>
  )
}

export function FormXoaLanCham({ logId, nhan }: { logId: string; nhan: string }) {
  const [trangThai, chay] = useActionState(xoaLanChamSai, BAN_DAU)
  return (
    <form action={chay} className="mt-2 space-y-2">
      <input type="hidden" name="log_id" value={logId} />
      <input
        type="text"
        name="ly_do"
        required
        minLength={10}
        placeholder={`Vì sao xoá ${nhan}?`}
        className={O_NHAP}
      />
      <div className="flex flex-wrap items-center gap-3">
        <Nut nhan="Xoá lần chấm này" dangChay="Đang xoá…" mau="do" />
        <BaoTrangThai trangThai={trangThai} />
      </div>
    </form>
  )
}

export function FormMoLaiPhien({ phienId }: { phienId: string }) {
  const [trangThai, chay] = useActionState(moLaiPhien, BAN_DAU)
  return (
    <form action={chay} className="mt-3 space-y-2">
      <input type="hidden" name="phien_id" value={phienId} />
      <OLyDo goiY="Ví dụ: sót một người trong tổ, tổ trưởng báo lại chiều 22/08" />
      <div className="flex flex-wrap items-center gap-3">
        <Nut nhan="Mở lại phiên để sửa" dangChay="Đang mở…" mau="do" />
        <BaoTrangThai trangThai={trangThai} />
      </div>
    </form>
  )
}

export function FormTruyLinh({
  employeeId,
  ngayGoc,
  soTienGoiY,
  canCu,
}: {
  employeeId: string
  ngayGoc: string
  soTienGoiY: number | null
  canCu: string
}) {
  const [trangThai, chay] = useActionState(taoTruyLinh, BAN_DAU)
  return (
    <form action={chay} className="mt-3 space-y-3">
      <input type="hidden" name="employee_id" value={employeeId} />
      <input type="hidden" name="ngay_goc" value={ngayGoc} />
      <input type="hidden" name="can_cu" value={canCu} />

      <label className="block text-sm">
        <span className="mb-1 block font-medium">Số tiền bù (đồng)</span>
        <input
          type="text"
          inputMode="numeric"
          name="so_tien"
          required
          defaultValue={soTienGoiY ?? ''}
          className={O_NHAP}
        />
        <span className="mt-1 block text-xs text-slate-500">
          {canCu
            ? `Gợi ý tính theo: ${canCu}. Sửa được — người ký là người chốt con số.`
            : 'Hệ thống không đoán được mức lương tại thời điểm đó, phải nhập tay.'}
        </span>
      </label>

      <OLyDo goiY="Ví dụ: bù 1 công ngày 20/07 bị sót, đã đối chiếu với bảng chấm công tổ" />

      <div className="flex flex-wrap items-center gap-3">
        <Nut nhan="Tạo khoản truy lĩnh" dangChay="Đang tạo…" />
        <BaoTrangThai trangThai={trangThai} />
      </div>
    </form>
  )
}
