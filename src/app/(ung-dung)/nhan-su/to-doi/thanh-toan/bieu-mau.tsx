'use client'

import Link from 'next/link'
import { useActionState } from 'react'
import { useFormStatus } from 'react-dom'
import {
  sinhBangThanhToan,
  suaTayDongThanhToan,
  xoaBangThanhToan,
  type TrangThaiForm,
} from './actions'

const O_NHAP =
  'w-full rounded-lg border border-slate-300 px-3 py-2 text-base outline-none focus:border-slate-900 dark:border-slate-700 dark:bg-slate-950'

const BAN_DAU: TrangThaiForm = { error: null }

export type ToChon = { id: string; nhan: string }

function Nut({ nhan, dangChay }: { nhan: string; dangChay: string }) {
  const { pending } = useFormStatus()
  return (
    <button
      type="submit"
      disabled={pending}
      className="rounded-lg bg-slate-900 px-4 py-2 text-sm font-medium text-white disabled:opacity-60 dark:bg-slate-100 dark:text-slate-900"
    >
      {pending ? dangChay : nhan}
    </button>
  )
}

function BaoTrangThai({ trangThai }: { trangThai: TrangThaiForm }) {
  return (
    <>
      {trangThai.error !== null && (
        <p role="alert" className="text-sm text-red-600">
          {trangThai.error}
        </p>
      )}
      {trangThai.xong && (
        <p className="text-sm text-emerald-700 dark:text-emerald-400">{trangThai.xong}</p>
      )}
    </>
  )
}

export function FormSinhBang({
  danhSachTo,
  tuNgay,
  denNgay,
}: {
  danhSachTo: ToChon[]
  tuNgay: string
  denNgay: string
}) {
  const [trangThai, gui] = useActionState(sinhBangThanhToan, BAN_DAU)

  return (
    <form action={gui} className="space-y-3">
      <div className="grid gap-3 sm:grid-cols-4 sm:items-end">
        <div className="sm:col-span-2">
          <label htmlFor="to_doi_id" className="mb-1 block text-sm font-medium">
            Tổ
          </label>
          <select id="to_doi_id" name="to_doi_id" className={O_NHAP}>
            {danhSachTo.map((t) => (
              <option key={t.id} value={t.id}>
                {t.nhan}
              </option>
            ))}
          </select>
        </div>
        <div>
          <label htmlFor="tu_ngay" className="mb-1 block text-sm font-medium">
            Từ ngày
          </label>
          <input id="tu_ngay" name="tu_ngay" type="date" defaultValue={tuNgay} className={O_NHAP} />
        </div>
        <div>
          <label htmlFor="den_ngay" className="mb-1 block text-sm font-medium">
            Đến ngày
          </label>
          <input
            id="den_ngay"
            name="den_ngay"
            type="date"
            defaultValue={denNgay}
            className={O_NHAP}
          />
        </div>
      </div>

      <Nut nhan="Sinh bảng thanh toán" dangChay="Đang tính…" />
      <BaoTrangThai trangThai={trangThai} />
    </form>
  )
}

/** Năm con số của một dòng, đã viết sẵn thành chữ để rót vào ô. */
export type DongSua = {
  id: string
  /** "công" hoặc "giờ" — ô số lượng phải nói rõ đơn vị. */
  donVi: string
  soLuong: string
  donGia: string
  soGioOt: string
  donGiaOt: string
  thuong: string
}

/**
 * Sửa tay một dòng (P5j, 15/09/2026).
 *
 * Từ P5h (24/08) tới hôm ấy KHÔNG có biểu mẫu này: database đã thu hồi quyền
 * sửa, và một nút luôn báo lỗi thì tệ hơn không có nút. Nay nó gọi vào một
 * hàm riêng ở database — không phải lối UPDATE cũ, lối ấy vẫn đóng.
 */
export function FormSuaDong({ dong, huyHref }: { dong: DongSua; huyHref: string }) {
  const [trangThai, gui] = useActionState(suaTayDongThanhToan, BAN_DAU)

  const o = (ten: string, nhan: string, giaTri: string) => (
    <div>
      <label htmlFor={ten} className="mb-1 block text-sm font-medium">
        {nhan}
      </label>
      <input
        id={ten}
        name={ten}
        inputMode="decimal"
        defaultValue={giaTri}
        required
        className={O_NHAP}
      />
    </div>
  )

  return (
    <form action={gui} className="space-y-3 print:hidden">
      <input type="hidden" name="dong_id" value={dong.id} />
      <div className="grid gap-3 sm:grid-cols-5">
        {o('so_luong', `Số ${dong.donVi}`, dong.soLuong)}
        {o('don_gia', 'Đơn giá (đ)', dong.donGia)}
        {o('so_gio_ot', 'Giờ ngoài giờ', dong.soGioOt)}
        {o('don_gia_ot', 'Đơn giá NG (đ)', dong.donGiaOt)}
        {o('thuong', 'Thưởng (đ)', dong.thuong)}
      </div>
      <div>
        <label htmlFor="ly_do" className="mb-1 block text-sm font-medium">
          Lý do sửa
        </label>
        <textarea
          id="ly_do"
          name="ly_do"
          rows={2}
          required
          placeholder="Ví dụ: chấm thiếu 1 giờ ngày 12/09, đã đối chiếu với tổ trưởng"
          className={O_NHAP}
        />
      </div>
      <div className="flex flex-wrap items-center gap-4">
        <Nut nhan="Lưu và thay bảng" dangChay="Đang lưu…" />
        <Link href={huyHref} className="text-sm underline">
          Huỷ
        </Link>
      </div>
      <BaoTrangThai trangThai={trangThai} />
    </form>
  )
}

export function FormXoaBang({ id }: { id: string }) {
  const [trangThai, gui] = useActionState(xoaBangThanhToan, BAN_DAU)

  return (
    <form
      action={gui}
      className="print:hidden"
      // Từ P5j người chấm cũng xoá được, không chỉ admin — thêm một lần hỏi
      // lại cho cú bấm không lấy lại được.
      onSubmit={(e) => {
        if (!window.confirm('Xoá hẳn bảng thanh toán này? Chứng từ PDF đã sinh vẫn được giữ lại.')) {
          e.preventDefault()
        }
      }}
    >
      <input type="hidden" name="id" value={id} />
      <button
        type="submit"
        className="rounded-lg border border-red-300 px-3 py-1.5 text-sm text-red-700 dark:border-red-800 dark:text-red-400"
      >
        Xoá bảng này
      </button>
      <BaoTrangThai trangThai={trangThai} />
    </form>
  )
}
