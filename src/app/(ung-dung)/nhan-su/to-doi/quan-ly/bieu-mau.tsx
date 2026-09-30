'use client'

import { useActionState } from 'react'
import { useFormStatus } from 'react-dom'
import {
  capNhatToDoi,
  datChucDanhCongNhat,
  datToTruong,
  datQuyenQuanLyToDoi,
  datDonGiaThanhVien,
  giaoNguoiCham,
  goNguoiCham,
  datNgayThanhVien,
  suaNhanCong,
  taoToDoi,
  taoToDoiCuaToi,
  themNhanCong,
  themThanhVien,
  type TrangThaiForm,
} from './actions'

const O_NHAP =
  'w-full rounded-lg border border-slate-300 px-3 py-2 text-base outline-none focus:border-slate-900 dark:border-slate-700 dark:bg-slate-950'

const BAN_DAU: TrangThaiForm = { error: null }

export type ChonRut = { id: string; nhan: string }

export type ToDoiDayDu = {
  id: string
  code: string
  name: string
  company_id: string
  department_id: string | null
  to_truong_id: string | null
  ghi_chu: string | null
  is_active: boolean
}

function Nut({ nhan = 'Lưu' }: { nhan?: string }) {
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

function OChon({
  ten,
  nhan,
  ds,
  macDinh,
  trong,
}: {
  ten: string
  nhan: string
  ds: ChonRut[]
  macDinh?: string | null
  trong: string
}) {
  return (
    <div>
      <label htmlFor={ten} className="mb-1 block text-sm font-medium">
        {nhan}
      </label>
      <select id={ten} name={ten} defaultValue={macDinh ?? ''} className={O_NHAP}>
        <option value="">{trong}</option>
        {ds.map((x) => (
          <option key={x.id} value={x.id}>
            {x.nhan}
          </option>
        ))}
      </select>
    </div>
  )
}

export function FormTaoToDoi({
  congTy,
  phongBan,
}: {
  congTy: ChonRut[]
  phongBan: ChonRut[]
}) {
  const [trangThai, gui] = useActionState(taoToDoi, BAN_DAU)

  return (
    <form action={gui} className="space-y-3">
      <div className="grid gap-3 sm:grid-cols-3">
        <div>
          <label htmlFor="code" className="mb-1 block text-sm font-medium">
            Mã tổ
          </label>
          <input id="code" name="code" className={O_NHAP} placeholder="TO-01" />
        </div>
        <div className="sm:col-span-2">
          <label htmlFor="name" className="mb-1 block text-sm font-medium">
            Tên tổ
          </label>
          <input id="name" name="name" className={O_NHAP} placeholder="Tổ nề công trường Bắc Ninh" />
        </div>
      </div>

      <div className="grid gap-3 sm:grid-cols-2">
        <OChon ten="company_id" nhan="Công ty" ds={congTy} trong="— chọn công ty —" />
        <OChon ten="department_id" nhan="Công trường" ds={phongBan} trong="— không gắn —" />
      </div>

      <p className="text-sm text-slate-500">
        Người quản lý chấm công giao sau, ở phần dưới của từng tổ — một người phụ trách được
        nhiều tổ, và một tổ giao được cho nhiều người.
      </p>

      <Nut nhan="Tạo tổ" />
      <BaoTrangThai trangThai={trangThai} />
    </form>
  )
}

export function FormSuaToDoi({
  to,
  phongBan,
}: {
  to: ToDoiDayDu
  phongBan: ChonRut[]
}) {
  const [trangThai, gui] = useActionState(capNhatToDoi, BAN_DAU)

  return (
    <form action={gui} className="space-y-3">
      <input type="hidden" name="id" value={to.id} />

      <div className="grid gap-3 sm:grid-cols-2">
        <div>
          <label htmlFor={`name-${to.id}`} className="mb-1 block text-sm font-medium">
            Tên tổ
          </label>
          <input id={`name-${to.id}`} name="name" defaultValue={to.name} className={O_NHAP} />
        </div>
        <OChon
          ten="department_id"
          nhan="Công trường"
          ds={phongBan}
          macDinh={to.department_id}
          trong="— không gắn —"
        />
      </div>

      <div className="flex flex-wrap items-center gap-4">
        <label className="flex items-center gap-2 text-sm">
          <input type="checkbox" name="is_active" defaultChecked={to.is_active} />
          Đang hoạt động
        </label>
        <Nut />
      </div>

      <BaoTrangThai trangThai={trangThai} />
    </form>
  )
}

export function FormThemThanhVien({
  toDoiId,
  nhanSu,
  homNay,
}: {
  toDoiId: string
  nhanSu: ChonRut[]
  homNay: string
}) {
  const [trangThai, gui] = useActionState(themThanhVien, BAN_DAU)

  if (nhanSu.length === 0) {
    return (
      <p className="text-sm text-slate-500">
        Không còn nhân sự nào chưa thuộc tổ. Một người chỉ ở được một tổ đang mở — cho họ rời
        tổ cũ trước.
      </p>
    )
  }

  return (
    <form action={gui} className="flex flex-wrap items-end gap-3">
      <input type="hidden" name="to_doi_id" value={toDoiId} />
      <div className="min-w-56 flex-1">
        <OChon ten="employee_id" nhan="Thêm người vào tổ" ds={nhanSu} trong="— chọn người —" />
      </div>
      <div>
        <label htmlFor={`tu-${toDoiId}`} className="mb-1 block text-sm font-medium">
          Từ ngày
        </label>
        <input
          id={`tu-${toDoiId}`}
          name="tu_ngay"
          type="date"
          defaultValue={homNay}
          className={O_NHAP}
        />
      </div>
      <Nut nhan="Thêm" />
      <BaoTrangThai trangThai={trangThai} />
    </form>
  )
}

const O_NGAY =
  'rounded-lg border border-slate-300 px-2 py-1 text-sm dark:border-slate-700 dark:bg-slate-950'

/**
 * Khoảng thời gian một người ở trong tổ — sửa được cả hai đầu.
 *
 * Thay `FormKetThucThanhVien` từ 29/08/2026: bản cũ chỉ có ô ngày rời tổ và
 * một nút *Cho rời tổ*, nên gõ nhầm ngày nào cũng không sửa lại được. Hai ngày
 * này quyết định người ấy được tính công những hôm nào, tức quyết định tiền.
 *
 * Ô ngày rời để TRỐNG nghĩa là còn trong tổ — nên đây cũng là đường đưa người
 * bị cho rời nhầm quay lại.
 */
export function FormNgayThanhVien({
  id,
  tuNgay,
  denNgay,
}: {
  id: string
  tuNgay: string
  denNgay: string | null
}) {
  const [trangThai, gui] = useActionState(datNgayThanhVien, BAN_DAU)

  return (
    <form action={gui} className="flex flex-wrap items-center gap-2">
      <input type="hidden" name="id" value={id} />
      <span className="text-xs text-slate-500">Vào tổ</span>
      <input
        name="tu_ngay"
        type="date"
        defaultValue={tuNgay}
        aria-label="Ngày vào tổ"
        className={O_NGAY}
      />
      <span className="text-xs text-slate-500">Rời tổ</span>
      <input
        name="den_ngay"
        type="date"
        defaultValue={denNgay ?? ''}
        aria-label="Ngày rời tổ, để trống nếu còn trong tổ"
        title="Để trống nếu người này còn trong tổ"
        className={O_NGAY}
      />
      <button
        type="submit"
        className="rounded-lg border border-slate-300 px-3 py-1.5 text-sm dark:border-slate-700"
      >
        Lưu ngày
      </button>
      <BaoTrangThai trangThai={trangThai} />
    </form>
  )
}

export function FormGiaoNguoiCham({
  toDoiId,
  taiKhoan,
}: {
  toDoiId: string
  taiKhoan: ChonRut[]
}) {
  const [trangThai, gui] = useActionState(giaoNguoiCham, BAN_DAU)

  if (taiKhoan.length === 0) {
    return (
      <p className="text-sm text-slate-500">
        Không có tài khoản nào đủ điều kiện. Người quản lý chấm công phải là{' '}
        <strong>nhân viên chính thức</strong>, có hợp đồng lao động đang hiệu lực và đóng bảo
        hiểm, và tài khoản phải được nối với hồ sơ nhân sự. Khối{' '}
        <em>Người quản lý tổ đội</em> ở đầu trang nói rõ từng người còn thiếu gì.
      </p>
    )
  }

  return (
    <form action={gui} className="flex flex-wrap items-end gap-3">
      <input type="hidden" name="to_doi_id" value={toDoiId} />
      <div className="min-w-56 flex-1">
        <OChon
          ten="app_user_id"
          nhan="Giao thêm người quản lý chấm công"
          ds={taiKhoan}
          trong="— chọn người —"
        />
      </div>
      <Nut nhan="Giao quyền" />
      <BaoTrangThai trangThai={trangThai} />
    </form>
  )
}

export function FormGoNguoiCham({ id }: { id: string }) {
  const [trangThai, gui] = useActionState(goNguoiCham, BAN_DAU)
  return (
    <form action={gui} className="flex flex-wrap items-center gap-2">
      <input type="hidden" name="id" value={id} />
      <button
        type="submit"
        className="rounded-lg border border-slate-300 px-3 py-1.5 text-sm dark:border-slate-700"
      >
        Gỡ quyền
      </button>
      <BaoTrangThai trangThai={trangThai} />
    </form>
  )
}


export function FormDonGiaThanhVien({
  id,
  donGia,
}: {
  id: string
  donGia: number | null
}) {
  const [trangThai, gui] = useActionState(datDonGiaThanhVien, BAN_DAU)

  return (
    <form action={gui} className="flex flex-wrap items-center gap-2">
      <input type="hidden" name="id" value={id} />
      <input
        name="don_gia_gio"
        defaultValue={donGia === null ? '' : String(donGia)}
        placeholder="đ / giờ"
        aria-label="Đơn giá một giờ"
        className="w-32 rounded-lg border border-slate-300 px-2 py-1 text-sm dark:border-slate-700 dark:bg-slate-950"
      />
      <button
        type="submit"
        className="rounded-lg border border-slate-300 px-3 py-1.5 text-sm dark:border-slate-700"
      >
        Lưu giá
      </button>
      <BaoTrangThai trangThai={trangThai} />
    </form>
  )
}

/**
 * Người quản lý tự lập tổ.
 *
 * Không có ô chọn công ty — công ty suy từ hồ sơ của chính họ. Cho chọn là mở
 * đường lập tổ cho pháp nhân khác.
 */
export function FormTaoToDoiCuaToi({ phongBan }: { phongBan: ChonRut[] }) {
  const [trangThai, gui] = useActionState(taoToDoiCuaToi, BAN_DAU)

  return (
    <form action={gui} className="space-y-3">
      <div className="grid gap-3 sm:grid-cols-3">
        <div>
          <label htmlFor="code-moi" className="mb-1 block text-sm font-medium">
            Mã tổ
          </label>
          <input id="code-moi" name="code" className={O_NHAP} placeholder="TO-02" />
        </div>
        <div className="sm:col-span-2">
          <label htmlFor="name-moi" className="mb-1 block text-sm font-medium">
            Tên tổ
          </label>
          <input id="name-moi" name="name" className={O_NHAP} placeholder="Tổ nề Bắc Ninh" />
        </div>
      </div>

      <OChon ten="department_id" nhan="Công trường" ds={phongBan} trong="— không gắn —" />

      <Nut nhan="Lập tổ" />
      <p className="text-xs text-slate-500">
        Tổ thuộc công ty của bạn, và bạn thành người chấm công cho tổ vừa lập.
      </p>
      <BaoTrangThai trangThai={trangThai} />
    </form>
  )
}

export function FormThemNhanCong({
  toDoiId,
  homNay,
  coChucDanh,
}: {
  toDoiId: string
  homNay: string
  coChucDanh: boolean
}) {
  const [trangThai, gui] = useActionState(themNhanCong, BAN_DAU)

  if (!coChucDanh) {
    return (
      <p className="text-sm text-slate-500">
        Chưa đánh dấu chức danh nào là <strong>công nhật</strong>. Quản trị hệ thống chọn ở khối
        phía trên trước khi thêm nhân công.
      </p>
    )
  }

  return (
    <form action={gui} className="space-y-3">
      <input type="hidden" name="to_doi_id" value={toDoiId} />

      <div className="grid gap-3 sm:grid-cols-2">
        <div>
          <label htmlFor={`ht-${toDoiId}`} className="mb-1 block text-sm font-medium">
            Họ và tên
          </label>
          <input id={`ht-${toDoiId}`} name="ho_ten" className={O_NHAP} />
        </div>
        <div>
          <label htmlFor={`cccd-${toDoiId}`} className="mb-1 block text-sm font-medium">
            Số CCCD
          </label>
          <input id={`cccd-${toDoiId}`} name="cccd" inputMode="numeric" className={O_NHAP} />
        </div>
      </div>

      {/* Không còn ô chọn kiểu tính: từ 24/08/2026 công nhật chấm theo ca và
          trả theo giờ. Để lại một ô chọn chỉ còn một giá trị hợp lệ là mời
          người ta chọn nhầm. */}
      <div className="grid gap-3 sm:grid-cols-3">
        <div>
          <label htmlFor={`dg-${toDoiId}`} className="mb-1 block text-sm font-medium">
            Đơn giá một giờ
          </label>
          <input id={`dg-${toDoiId}`} name="don_gia_gio" className={O_NHAP} placeholder="45000" />
          <p className="mt-1 text-xs text-slate-500">Giờ làm trong khung giờ chuẩn.</p>
        </div>
        <div>
          <label htmlFor={`dgot-${toDoiId}`} className="mb-1 block text-sm font-medium">
            Đơn giá ngoài giờ
          </label>
          <input id={`dgot-${toDoiId}`} name="don_gia_ot" className={O_NHAP} placeholder="60000" />
          <p className="mt-1 text-xs text-slate-500">
            Tiền một giờ ngoài khung giờ chuẩn, <strong>thoả thuận riêng với người này</strong> —
            không nhân hệ số nào lên đơn giá thường. Để trống nếu chưa thoả thuận.
          </p>
        </div>
        <div>
          <label htmlFor={`tn-${toDoiId}`} className="mb-1 block text-sm font-medium">
            Vào tổ từ
          </label>
          <input id={`tn-${toDoiId}`} name="tu_ngay" type="date" defaultValue={homNay} className={O_NHAP} />
        </div>
      </div>

      <Nut nhan="Thêm nhân công" />
      <BaoTrangThai trangThai={trangThai} />
    </form>
  )
}

/**
 * Sửa thông tin một nhân công đã có trong tổ.
 *
 * Ô bỏ trống nghĩa là GIỮ NGUYÊN, không phải xoá — hàm `sua_nhan_cong_to()` ở
 * database dùng `coalesce(tham_số, giá_trị_cũ)`.
 *
 * Ô HỌ TÊN có mặt từ 29/08/2026. Hàm ở database nhận `p_ho_ten` ngay từ P5c và
 * `suaNhanCong` vẫn gửi nó đi, nhưng biểu mẫu chưa bao giờ vẽ ra ô ấy — nên
 * tham số luôn là null và KHÔNG AI, kể cả admin, sửa được một cái tên gõ nhầm.
 * Một tham số không có đường nhập là một tính năng trông như đã làm.
 */
export function FormSuaNhanCong({
  thanhVienId,
  hoTen,
  donGia,
  donGiaOt,
}: {
  thanhVienId: string
  hoTen: string
  donGia: number | null
  donGiaOt: number | null
}) {
  const [trangThai, gui] = useActionState(suaNhanCong, BAN_DAU)

  return (
    <form action={gui} className="flex flex-wrap items-center gap-2">
      <input type="hidden" name="thanh_vien_id" value={thanhVienId} />
      <input
        name="ho_ten"
        defaultValue={hoTen}
        placeholder="Họ và tên"
        aria-label="Họ và tên"
        className="w-44 rounded-lg border border-slate-300 px-2 py-1 text-sm dark:border-slate-700 dark:bg-slate-950"
      />
      <input
        name="don_gia_gio"
        defaultValue={donGia === null ? '' : String(donGia)}
        placeholder="đ / giờ"
        aria-label="Đơn giá một giờ"
        className="w-28 rounded-lg border border-slate-300 px-2 py-1 text-sm dark:border-slate-700 dark:bg-slate-950"
      />
      <input
        name="don_gia_ot"
        defaultValue={donGiaOt === null ? '' : String(donGiaOt)}
        placeholder="giá NG"
        title="Tiền một giờ ngoài giờ, thoả thuận riêng với người này"
        aria-label="Đơn giá ngoài giờ, thoả thuận riêng"
        className="w-28 rounded-lg border border-slate-300 px-2 py-1 text-sm dark:border-slate-700 dark:bg-slate-950"
      />
      <input
        name="cccd"
        placeholder="CCCD mới"
        aria-label="Số CCCD"
        className="w-36 rounded-lg border border-slate-300 px-2 py-1 text-sm dark:border-slate-700 dark:bg-slate-950"
      />
      <button
        type="submit"
        className="rounded-lg border border-slate-300 px-3 py-1.5 text-sm dark:border-slate-700"
      >
        Lưu
      </button>
      <BaoTrangThai trangThai={trangThai} />
    </form>
  )
}

export function FormQuyenQuanLyToDoi({
  appUserId,
  ten,
  dangBat,
}: {
  appUserId: string
  ten: string
  dangBat: boolean
}) {
  const [trangThai, gui] = useActionState(datQuyenQuanLyToDoi, BAN_DAU)

  return (
    <form action={gui} className="flex flex-wrap items-center gap-3 py-2">
      <input type="hidden" name="app_user_id" value={appUserId} />
      <span className="min-w-48 flex-1 text-sm">{ten}</span>
      <label className="flex items-center gap-2 text-sm">
        <input type="checkbox" name="bat" defaultChecked={dangBat} />
        Được lập tổ và thêm nhân công
      </label>
      <button
        type="submit"
        className="rounded-lg border border-slate-300 px-3 py-1.5 text-sm dark:border-slate-700"
      >
        Lưu
      </button>
      <BaoTrangThai trangThai={trangThai} />
    </form>
  )
}

export function FormChucDanhCongNhat({
  chucDanh,
  dangChon,
}: {
  chucDanh: ChonRut[]
  dangChon: string | null
}) {
  const [trangThai, gui] = useActionState(datChucDanhCongNhat, BAN_DAU)

  return (
    <form action={gui} className="flex flex-wrap items-end gap-3">
      <div className="min-w-56 flex-1">
        <OChon
          ten="position_id"
          nhan="Chức danh dùng cho nhân công công nhật"
          ds={chucDanh}
          macDinh={dangChon}
          trong="— chưa chọn —"
        />
      </div>
      <Nut nhan="Đặt làm mặc định" />
      <BaoTrangThai trangThai={trangThai} />
    </form>
  )
}

/**
 * Đặt / gỡ tổ trưởng, ngay trên dòng của người đó trong danh sách nhân công.
 */
export function FormDatToTruong({
  toDoiId,
  employeeId,
  dangLa,
}: {
  toDoiId: string
  employeeId: string
  dangLa: boolean
}) {
  const [trangThai, gui] = useActionState(datToTruong, BAN_DAU)

  return (
    <form action={gui} className="flex flex-wrap items-center gap-2">
      <input type="hidden" name="to_doi_id" value={toDoiId} />
      {/* Bỏ trống employee_id là GỠ chức — hành động ngược nằm trên cùng một nút. */}
      {!dangLa && <input type="hidden" name="employee_id" value={employeeId} />}
      <button
        type="submit"
        className={
          dangLa
            ? 'rounded-lg border border-amber-400 px-3 py-1.5 text-xs text-amber-800 dark:border-amber-700 dark:text-amber-300'
            : 'rounded-lg border border-slate-300 px-3 py-1.5 text-xs dark:border-slate-700'
        }
      >
        {dangLa ? 'Gỡ chức tổ trưởng' : 'Đặt làm tổ trưởng'}
      </button>
      <BaoTrangThai trangThai={trangThai} />
    </form>
  )
}
