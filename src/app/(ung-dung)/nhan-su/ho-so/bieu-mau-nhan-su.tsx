'use client'

import { useActionState, useState } from 'react'
import { useFormStatus } from 'react-dom'
import type { TrangThaiForm } from './actions'
import { chanEnterTuGui } from '@ns/lib/bieu-mau'
import {
  CONTRACT_TYPE_LABELS,
  EMPLOYEE_STATUS_LABELS,
  GENDER_LABELS,
  type EmployeeStatus,
} from '@ns/types/database'

export type GiaTriHoSo = {
  id: string | null
  employee_code: string
  full_name: string
  dob: string | null
  gender: string | null
  permanent_address: string | null
  phone: string | null
  personal_email: string | null
  department_id: string | null
  manager_id: string | null
  region: number | null
  company_id: string | null
  hire_date: string | null
  status: EmployeeStatus
  theo_doi_cham_cong: boolean
  cccd: string | null
  cccd_issue_date: string | null
  cccd_issue_place: string | null
  bank_account_no: string | null
  bank_name: string | null
  tax_code: string | null
  social_insurance_no: string | null
}

/**
 * Hợp đồng lao động đang hiệu lực của người này.
 *
 * VÌ SAO NẰM TRONG BIỂU MẪU HỒ SƠ: tới 12/08/2026 không màn nào trong app
 * ghi được vào `labor_contracts` — hợp đồng chỉ vào bằng script. Mà engine
 * lương nối bảng hợp đồng, nên người không có hợp đồng thì KHÔNG có phiếu
 * lương, im lặng. Nhập lương lúc tạo hồ sơ là lúc tự nhiên nhất.
 */
export type GiaTriHopDong = {
  id: string | null
  contract_no: string
  type: string
  start_date: string | null
  end_date: string | null
  /** Mức phụ cấp riêng theo mã loại. Rỗng nghĩa là dùng mức của chức danh. */
  phu_cap: Record<string, number>
  /** Dòng phụ cấp cũ không khớp mã loại nào — giữ nguyên, không sửa ở đây. */
  phuCapLa: { name: string; amount: number }[]
}

export type LoaiPhuCap = {
  id: string
  code: string
  name: string
  is_taxable: boolean
  is_insurance: boolean
}


const O_NHAP =
  'w-full rounded-lg border border-slate-300 px-3 py-2.5 text-base outline-none focus:border-slate-900 dark:border-slate-700 dark:bg-slate-950'

function Truong({
  ten,
  nhan,
  children,
}: {
  ten: string
  nhan: string
  children: React.ReactNode
}) {
  return (
    <div>
      <label htmlFor={ten} className="mb-1 block text-sm font-medium">
        {nhan}
      </label>
      {children}
    </div>
  )
}

function NutLuu({ nhan }: { nhan: string }) {
  const { pending } = useFormStatus()
  return (
    <button
      type="submit"
      disabled={pending}
      className="rounded-lg bg-slate-900 px-5 py-3 text-base font-medium text-white transition hover:bg-slate-700 disabled:opacity-60"
    >
      {pending ? 'Đang lưu…' : nhan}
    </button>
  )
}

const TIEN_VN = new Intl.NumberFormat('vi-VN')

/**
 * Khối hợp đồng lao động và phụ cấp riêng.
 *
 * Phụ cấp ở đây là NGOẠI LỆ CỦA CÁ NHÂN. Chức danh đã có mức mặc định; tick
 * ở đây là thay thế mức đó cho riêng người này, KHÔNG cộng dồn. Nhãn phải
 * nói rõ điều đó ngay tại chỗ tick, vì đọc bảng lương xong mới phát hiện
 * cộng dồn thì đã trả thừa tiền rồi.
 */
function KhoiHopDong({
  banDau,
  loaiPhuCap,
  mucTheoChucDanh,
}: {
  banDau: GiaTriHopDong
  loaiPhuCap: LoaiPhuCap[]
  mucTheoChucDanh: Record<string, number>
}) {
  const [chon, setChon] = useState<Record<string, boolean>>(() =>
    Object.fromEntries(loaiPhuCap.map((l) => [l.code, l.code in banDau.phu_cap])),
  )

  return (
    <section className="rounded-xl border border-slate-200 bg-white p-5 dark:border-slate-800 dark:bg-slate-900">
      <h2 className="font-medium">Hợp đồng lao động</h2>
      <p className="mt-1 mb-4 text-sm text-slate-600 dark:text-slate-400">
        Không có hợp đồng thì <strong>không có phiếu lương</strong> — engine bỏ qua người
        chưa có hợp đồng đang hiệu lực. Để trống cả khối này nếu chưa ký.
      </p>

      {banDau.id && <input type="hidden" name="hd_id" value={banDau.id} />}

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <Truong ten="hd_contract_no" nhan="Số hợp đồng">
          <input
            id="hd_contract_no"
            name="hd_contract_no"
            defaultValue={banDau.contract_no}
            className={O_NHAP}
          />
        </Truong>

        <Truong ten="hd_type" nhan="Loại hợp đồng">
          <select id="hd_type" name="hd_type" defaultValue={banDau.type} className={O_NHAP}>
            {Object.entries(CONTRACT_TYPE_LABELS).map(([ma, nhan]) => (
              <option key={ma} value={ma}>
                {nhan}
              </option>
            ))}
          </select>
        </Truong>

        <Truong ten="hd_start_date" nhan="Ngày bắt đầu">
          <input
            id="hd_start_date"
            name="hd_start_date"
            type="date"
            defaultValue={banDau.start_date ?? ''}
            className={O_NHAP}
          />
        </Truong>

        <Truong ten="hd_end_date" nhan="Ngày kết thúc">
          <input
            id="hd_end_date"
            name="hd_end_date"
            type="date"
            defaultValue={banDau.end_date ?? ''}
            className={O_NHAP}
          />
          <p className="mt-1 text-xs text-slate-500">
            Để trống với hợp đồng không xác định thời hạn.
          </p>
        </Truong>

      </div>

      <p className="mt-3 text-sm text-slate-500">
        <strong>Lương không sửa ở đây.</strong> Mỗi mức lương có ngày áp dụng riêng và được
        giữ lại thành lịch sử — xem và thêm mức mới ở khối <em>Mức lương theo thời gian</em>
        trong trang chi tiết hồ sơ. Sửa đè lên một ô lương là làm mất căn cứ của những đồng
        tiền đã trả.
      </p>

      <div className="mt-5 rounded-lg border border-slate-200 p-4 dark:border-slate-800">
        <p className="font-medium">Phụ cấp riêng của người này</p>
        <p className="mt-1 text-sm text-slate-600 dark:text-slate-400">
          Chỉ tick khi người này hưởng mức <strong>khác</strong> mức mặc định của chức danh.
          Mức nhập ở đây <strong>thay thế</strong> mức của chức danh, không cộng thêm. Không
          tick thì tự động hưởng mức của chức danh.
        </p>

        {loaiPhuCap.length === 0 ? (
          <p className="mt-3 text-sm text-slate-500">
            Chưa khai loại phụ cấp nào. Admin khai ở Quản trị → Loại phụ cấp.
          </p>
        ) : (
          <ul className="mt-3 space-y-2">
            {loaiPhuCap.map((l) => {
              const macDinh = mucTheoChucDanh[l.code]
              return (
                <li key={l.id} className="grid grid-cols-[auto_1fr_auto] items-center gap-3">
                  <input
                    type="checkbox"
                    id={`pc-${l.code}`}
                    name={`pc_chon_${l.code}`}
                    checked={chon[l.code] ?? false}
                    onChange={(e) => setChon((t) => ({ ...t, [l.code]: e.target.checked }))}
                  />
                  <label htmlFor={`pc-${l.code}`} className="text-sm">
                    {l.name}
                    <span className="block text-xs text-slate-500">
                      {macDinh === undefined
                        ? 'Chức danh này không có mức mặc định'
                        : `Chức danh: ${TIEN_VN.format(macDinh)} ₫`}
                      {' · '}
                      {l.is_taxable ? 'chịu thuế' : 'miễn thuế'}
                      {' · '}
                      {l.is_insurance ? 'có đóng BH' : 'không đóng BH'}
                    </span>
                  </label>
                  <input
                    type="number"
                    min="0"
                    step="1000"
                    name={`pc_muc_${l.code}`}
                    defaultValue={banDau.phu_cap[l.code] ?? ''}
                    disabled={!chon[l.code]}
                    aria-label={`Mức ${l.name} riêng của người này`}
                    placeholder="0"
                    className="w-40 rounded-lg border border-slate-300 px-3 py-1.5 text-right text-sm outline-none focus:border-slate-900 disabled:bg-slate-100 disabled:text-slate-400 dark:border-slate-700 dark:bg-slate-950 dark:disabled:bg-slate-900"
                  />
                </li>
              )
            })}
          </ul>
        )}

        {banDau.phuCapLa.length > 0 && (
          <div className="mt-4 rounded-lg bg-slate-100 p-3 text-sm dark:bg-slate-800">
            <p className="font-medium">Dòng phụ cấp cũ, không khớp loại nào</p>
            <p className="mt-1 text-xs text-slate-600 dark:text-slate-400">
              Được giữ nguyên và vẫn cộng vào lương. Muốn bỏ thì khai chúng thành loại phụ
              cấp ở Quản trị rồi tick lại ở trên.
            </p>
            <ul className="mt-2 space-y-1">
              {banDau.phuCapLa.map((p, i) => (
                <li key={`${p.name}-${i}`}>
                  {p.name}: {TIEN_VN.format(p.amount)} ₫
                </li>
              ))}
            </ul>
          </div>
        )}
      </div>
    </section>
  )
}

export function BieuMauNhanSu({
  laTaoMoi = false,
  hanhDong,
  banDau,
  hopDong,
  loaiPhuCap,
  mucTheoChucDanh,
  phongBan,
  chucDanh,
  quanLy,
  congTy,
  laTao,
}: {
  /** Ô chức danh chỉ hiện khi TẠO MỚI — hồ sơ đã có thì đổi qua khối lịch sử. */
  laTaoMoi?: boolean
  hanhDong: (state: TrangThaiForm, form: FormData) => Promise<TrangThaiForm>
  banDau: GiaTriHoSo
  hopDong: GiaTriHopDong
  loaiPhuCap: LoaiPhuCap[]
  mucTheoChucDanh: Record<string, number>
  phongBan: { id: string; name: string }[]
  chucDanh: { id: string; name: string }[]
  quanLy: { id: string; full_name: string }[]
  congTy: { id: string; name: string }[]
  laTao: boolean
}) {
  const [trangThai, guiForm] = useActionState(hanhDong, { error: null } as TrangThaiForm)

  return (
    <form
      action={guiForm}
      className="space-y-6"
      // Chặn Enter tự gửi form. Biểu mẫu này có 16 ô: gõ xong bấm Enter để
      // sang ô kế là thói quen rất thường, và theo chuẩn HTML thì Enter trong
      // ô một dòng sẽ GỬI form — tức lưu đè dữ liệu đang sửa dở rồi chuyển
      // trang. Nút Lưu vẫn bấm được bằng bàn phím: Tab tới nó rồi Enter.
      onKeyDown={(e) => {
        const t = e.target as HTMLElement
        if (chanEnterTuGui(e.key, t.tagName, (t as HTMLInputElement).type)) {
          e.preventDefault()
        }
      }}
    >
      {banDau.id && <input type="hidden" name="id" value={banDau.id} />}

      <section className="rounded-xl border border-slate-200 bg-white p-5 dark:border-slate-800 dark:bg-slate-900">
        <h2 className="mb-4 font-medium">Thông tin chung</h2>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <Truong ten="employee_code" nhan="Mã nhân viên *">
            <input
              id="employee_code"
              name="employee_code"
              required={laTao}
              defaultValue={banDau.employee_code}
              readOnly={!laTao}
              className={`${O_NHAP} ${laTao ? '' : 'bg-slate-100 dark:bg-slate-800'}`}
            />
            {!laTao && (
              <p className="mt-1 text-xs text-slate-500">
                Không sửa được: mã này dùng để đối chiếu chấm công và bảng lương.
              </p>
            )}
          </Truong>

          <Truong ten="full_name" nhan="Họ và tên *">
            <input id="full_name" name="full_name" required defaultValue={banDau.full_name} className={O_NHAP} />
          </Truong>

          <Truong ten="dob" nhan="Ngày sinh">
            <input id="dob" name="dob" type="date" defaultValue={banDau.dob ?? ''} className={O_NHAP} />
          </Truong>

          <Truong ten="gender" nhan="Giới tính">
            <select id="gender" name="gender" defaultValue={banDau.gender ?? ''} className={O_NHAP}>
              <option value="">— Chưa chọn —</option>
              {Object.entries(GENDER_LABELS).map(([ma, nhan]) => (
                <option key={ma} value={ma}>
                  {nhan}
                </option>
              ))}
            </select>
          </Truong>

          <Truong ten="phone" nhan="Điện thoại">
            <input id="phone" name="phone" inputMode="tel" defaultValue={banDau.phone ?? ''} className={O_NHAP} />
          </Truong>

          <Truong ten="personal_email" nhan="Email cá nhân">
            <input
              id="personal_email"
              name="personal_email"
              type="email"
              defaultValue={banDau.personal_email ?? ''}
              className={O_NHAP}
            />
          </Truong>

          <div className="sm:col-span-2">
            <Truong ten="permanent_address" nhan="Địa chỉ thường trú">
              <input
                id="permanent_address"
                name="permanent_address"
                defaultValue={banDau.permanent_address ?? ''}
                className={O_NHAP}
              />
            </Truong>
          </div>
        </div>
      </section>

      <section className="rounded-xl border border-slate-200 bg-white p-5 dark:border-slate-800 dark:bg-slate-900">
        <h2 className="mb-4 font-medium">Công việc</h2>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <Truong ten="company_id" nhan="Công ty *">
            <select
              id="company_id"
              name="company_id"
              defaultValue={banDau.company_id ?? ''}
              className={O_NHAP}
            >
              <option value="">— Chưa gán —</option>
              {congTy.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </select>
            <p className="mt-1 text-xs text-slate-500">
              Pháp nhân trả lương cho người này. Chưa gán thì họ không nằm trong kỳ lương nào,
              và hệ thống sẽ từ chối tính lương cho tới khi gán xong.
            </p>
          </Truong>

          <Truong ten="department_id" nhan="Phòng ban">
            <select
              id="department_id"
              name="department_id"
              defaultValue={banDau.department_id ?? ''}
              className={O_NHAP}
            >
              <option value="">— Chưa gán —</option>
              {phongBan.map((d) => (
                <option key={d.id} value={d.id}>
                  {d.name}
                </option>
              ))}
            </select>
          </Truong>

          {laTaoMoi && (
          <Truong ten="position_id" nhan="Chức danh">
            <select
              id="position_id"
              name="position_id"
              defaultValue=""
              className={O_NHAP}
            >
              <option value="">— Chưa gán —</option>
              {chucDanh.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.name}
                </option>
              ))}
            </select>
          </Truong>
          )}

          <Truong ten="manager_id" nhan="Quản lý trực tiếp">
            <select
              id="manager_id"
              name="manager_id"
              defaultValue={banDau.manager_id ?? ''}
              className={O_NHAP}
            >
              <option value="">— Chưa gán —</option>
              {quanLy
                .filter((q) => q.id !== banDau.id)
                .map((q) => (
                  <option key={q.id} value={q.id}>
                    {q.full_name}
                  </option>
                ))}
            </select>
          </Truong>

          <Truong ten="hire_date" nhan="Ngày vào làm">
            <input
              id="hire_date"
              name="hire_date"
              type="date"
              defaultValue={banDau.hire_date ?? ''}
              className={O_NHAP}
            />
          </Truong>

          <Truong ten="status" nhan="Trạng thái">
            <select id="status" name="status" defaultValue={banDau.status} className={O_NHAP}>
              {Object.entries(EMPLOYEE_STATUS_LABELS).map(([ma, nhan]) => (
                <option key={ma} value={ma}>
                  {nhan}
                </option>
              ))}
            </select>
          </Truong>

          <Truong ten="region" nhan="Vùng lương tối thiểu">
            <select id="region" name="region" defaultValue={banDau.region?.toString() ?? ''} className={O_NHAP}>
              <option value="">— Chưa xác định —</option>
              {[1, 2, 3, 4].map((v) => (
                <option key={v} value={v}>
                  Vùng {v}
                </option>
              ))}
            </select>
            <p className="mt-1 text-xs text-slate-500">
              Dùng để tra lương tối thiểu vùng khi tính lương. Mức tiền đọc từ bảng tham số
              theo ngày hiệu lực, không nhập ở đây.
            </p>
          </Truong>

          <div className="sm:col-span-2">
            <label className="flex items-start gap-3">
              <input
                type="checkbox"
                name="theo_doi_cham_cong"
                defaultChecked={banDau.theo_doi_cham_cong}
                className="mt-1"
              />
              <span>
                <span className="font-medium">Áp dụng chấm công</span>
                <span className="mt-1 block text-xs text-slate-500">
                  Bỏ tick nếu công việc của người này không phù hợp để chấm công. Khi đó họ
                  không thấy nút chấm công, và bảng lương tính{' '}
                  <strong>đủ ngày công chuẩn</strong> của kỳ cho họ — không phải 0 đồng.
                </span>
              </span>
            </label>
          </div>
        </div>
      </section>

      <KhoiHopDong
        banDau={hopDong}
        loaiPhuCap={loaiPhuCap}
        mucTheoChucDanh={mucTheoChucDanh}
      />

      <section className="rounded-xl border border-amber-300 bg-amber-50 p-5 dark:border-amber-900 dark:bg-amber-950/30">
        <h2 className="font-medium">Thông tin nhạy cảm</h2>
        <p className="mt-1 mb-4 text-sm text-slate-600 dark:text-slate-400">
          Lưu ở bảng riêng, chỉ chính chủ, HR, kế toán và admin đọc được. Trưởng phòng không
          xem được phần này. Chỉ nhập những gì thực sự cần.
        </p>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <Truong ten="cccd" nhan="Số CCCD">
            <input id="cccd" name="cccd" inputMode="numeric" defaultValue={banDau.cccd ?? ''} className={O_NHAP} />
          </Truong>

          <Truong ten="cccd_issue_date" nhan="Ngày cấp CCCD">
            <input
              id="cccd_issue_date"
              name="cccd_issue_date"
              type="date"
              defaultValue={banDau.cccd_issue_date ?? ''}
              className={O_NHAP}
            />
          </Truong>

          <Truong ten="cccd_issue_place" nhan="Nơi cấp CCCD">
            <input
              id="cccd_issue_place"
              name="cccd_issue_place"
              defaultValue={banDau.cccd_issue_place ?? ''}
              className={O_NHAP}
            />
          </Truong>

          <Truong ten="tax_code" nhan="Mã số thuế cá nhân">
            <input id="tax_code" name="tax_code" defaultValue={banDau.tax_code ?? ''} className={O_NHAP} />
          </Truong>

          <Truong ten="bank_account_no" nhan="Số tài khoản">
            <input
              id="bank_account_no"
              name="bank_account_no"
              inputMode="numeric"
              defaultValue={banDau.bank_account_no ?? ''}
              className={O_NHAP}
            />
          </Truong>

          <Truong ten="bank_name" nhan="Ngân hàng">
            <input id="bank_name" name="bank_name" defaultValue={banDau.bank_name ?? ''} className={O_NHAP} />
          </Truong>

          <Truong ten="social_insurance_no" nhan="Số sổ BHXH">
            <input
              id="social_insurance_no"
              name="social_insurance_no"
              defaultValue={banDau.social_insurance_no ?? ''}
              className={O_NHAP}
            />
          </Truong>
        </div>
      </section>

      {trangThai.error !== null && (
        <p role="alert" className="text-sm text-red-600">
          {trangThai.error}
        </p>
      )}

      <NutLuu nhan={laTao ? 'Tạo hồ sơ' : 'Lưu thay đổi'} />
    </form>
  )
}
