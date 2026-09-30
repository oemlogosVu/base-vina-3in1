'use client'

import { useActionState, useState } from 'react'
import { useFormStatus } from 'react-dom'
import { gio } from '@ns/lib/dinh-dang'
import {
  congTuPhut,
  docCong,
  phutChuanMotNgay,
  phutLamMotNgay,
  type CaChuan,
} from '@ns/lib/cong-ngay'
import { Pill } from '@ns/components/khung-trang'
import { chamBuHangLoat, type TrangThaiForm } from './actions'
import { FormXoaLanCham } from './bieu-mau'

const BAN_DAU: TrangThaiForm = { error: null }

const O_GIO =
  'w-28 rounded-lg border border-slate-300 px-2 py-1.5 text-sm dark:border-slate-700 dark:bg-slate-950'

export type DongBang = {
  employeeId: string
  ma: string
  ten: string
  lanCham: { id: string; loai: string; luc: string; laChamBu: boolean }[]
  phutLam: number
}

function NutGui({ so }: { so: number }) {
  const { pending } = useFormStatus()
  return (
    <button
      type="submit"
      disabled={pending || so === 0}
      className="rounded-lg bg-slate-900 px-4 py-2 text-sm font-medium text-white disabled:opacity-60 dark:bg-slate-100 dark:text-slate-900"
    >
      {pending ? 'Đang ghi…' : `Chấm bù cho ${so} người đã tick`}
    </button>
  )
}

/**
 * Bảng chấm bù của một công ty trong một ngày.
 *
 * BA ĐIỀU QUYẾT ĐỊNH HÌNH DẠNG FILE NÀY
 *
 * 1. **Công là số lẻ, tính từ giờ.** Nửa ngày là 08:00–12:00 chứ không phải
 *    một ô ghi "0,5". Nên mỗi dòng có cặp giờ riêng, và ngay cạnh nó hiện số
 *    công sẽ ra — người chấm thấy hệ quả TRƯỚC khi bấm lưu, không phải mở
 *    bảng lương tháng sau mới biết mình ghi nhầm cả ngày cho người làm nửa
 *    buổi.
 *
 * 2. **Giờ chung là MẶC ĐỊNH, không phải ràng buộc.** Cả tổ nghỉ vì máy hỏng
 *    thì gõ một lần; ai làm khác giờ thì sửa đúng dòng của họ.
 *
 * 3. **Form KHÔNG bọc quanh bảng.** Nút xoá từng lần chấm cũng là một form —
 *    lồng form trong form là HTML không hợp lệ, trình duyệt bỏ form bên trong
 *    và nút xoá sẽ gửi nhầm sang hành động chấm bù. Bản P7b sáng nay dính
 *    đúng lỗi này. Nay bảng đứng riêng, còn form chấm bù chỉ chứa ô ẩn dựng
 *    từ trạng thái.
 */
export function BangChamBuCongTy({
  ngay,
  ca,
  laChuNhat,
  dong,
}: {
  ngay: string
  ca: CaChuan
  laChuNhat: boolean
  dong: DongBang[]
}) {
  const [vaoChung, setVaoChung] = useState('08:00')
  const [raChung, setRaChung] = useState('17:00')
  const [lyDo, setLyDo] = useState('')
  const [tick, setTick] = useState<Record<string, boolean>>({})
  const [rieng, setRieng] = useState<Record<string, { vao: string; ra: string }>>({})
  const [trangThai, chay] = useActionState(chamBuHangLoat, BAN_DAU)

  const phutChuan = phutChuanMotNgay(ca)
  const chuaCham = dong.filter((d) => d.lanCham.length === 0)
  const daTick = chuaCham.filter((d) => tick[d.employeeId])

  const gioCua = (id: string) => rieng[id] ?? { vao: vaoChung, ra: raChung }
  const congCua = (id: string) => {
    const g = gioCua(id)
    return congTuPhut(phutLamMotNgay(g.vao, g.ra, ca, laChuNhat), phutChuan)
  }

  const datRieng = (id: string, dau: 'vao' | 'ra', gt: string) =>
    setRieng((r) => ({ ...r, [id]: { ...(r[id] ?? { vao: vaoChung, ra: raChung }), [dau]: gt } }))

  return (
    <>
      {laChuNhat && (
        <div className="mb-4 rounded-lg bg-red-50 p-4 text-sm text-red-900 dark:bg-red-950 dark:text-red-200">
          Ngày này là <strong>chủ nhật</strong> — ngày nghỉ tuần không có giờ hành chính, nên chấm
          bù vào đây sẽ ra <strong>0 giờ thường</strong>. Giờ làm chủ nhật là làm thêm và đi đường
          khác.
        </div>
      )}

      <div className="mb-3 flex flex-wrap items-end gap-3">
        <label className="text-sm">
          <span className="mb-1 block font-medium">Giờ vào (chung)</span>
          <input
            type="time"
            value={vaoChung}
            onChange={(e) => setVaoChung(e.target.value)}
            className={O_GIO}
          />
        </label>
        <label className="text-sm">
          <span className="mb-1 block font-medium">Giờ ra (chung)</span>
          <input
            type="time"
            value={raChung}
            onChange={(e) => setRaChung(e.target.value)}
            className={O_GIO}
          />
        </label>
        <label className="min-w-64 flex-1 text-sm">
          <span className="mb-1 block font-medium">
            Lý do chung <span className="text-red-600">*</span>
          </span>
          <input
            type="text"
            value={lyDo}
            onChange={(e) => setLyDo(e.target.value)}
            minLength={10}
            placeholder="Ví dụ: máy chấm công hỏng cả ngày 20/08, tổ trưởng xác nhận"
            className="w-full rounded-lg border border-slate-300 px-3 py-2 text-base dark:border-slate-700 dark:bg-slate-950"
          />
        </label>
      </div>

      <p className="mb-3 text-sm">
        {chuaCham.length === 0
          ? 'Cả công ty đều đã có công trong ngày này.'
          : `${chuaCham.length}/${dong.length} người chưa có lần chấm nào — tick để chấm bù. ` +
            'Ai làm khác giờ thì sửa ngay trên dòng của họ.'}
      </p>

      <table className="bang">
        <thead>
          <tr>
            <th>Bù</th>
            <th>Họ tên</th>
            <th>Đã chấm</th>
            <th>Giờ vào – ra</th>
            <th className="phai">Thành công</th>
          </tr>
        </thead>
        <tbody>
          {dong.map((d) => {
            const daCham = d.lanCham.length > 0
            const g = gioCua(d.employeeId)
            const cong = congCua(d.employeeId)
            return (
              <tr key={d.employeeId}>
                <td data-nhan="Chấm bù">
                  {daCham ? (
                    <span className="nhan-phu">—</span>
                  ) : (
                    <input
                      type="checkbox"
                      checked={Boolean(tick[d.employeeId])}
                      onChange={(e) =>
                        setTick((t) => ({ ...t, [d.employeeId]: e.target.checked }))
                      }
                      aria-label={`Chấm bù cho ${d.ten}`}
                    />
                  )}
                </td>

                <td>
                  {d.ten} <span className="nhan-phu">{d.ma}</span>
                </td>

                <td data-nhan="Đã chấm">
                  {!daCham ? (
                    <Pill sac="vang">chưa chấm</Pill>
                  ) : (
                    d.lanCham.map((l) => (
                      <div key={l.id} className="mb-2">
                        <span>
                          {l.loai === 'in' ? 'Vào' : 'Ra'} {gio(l.luc)}
                        </span>
                        {l.laChamBu && (
                          <span className="ml-1">
                            <Pill sac="vang">khai hộ</Pill>
                          </span>
                        )}
                        <FormXoaLanCham
                          logId={l.id}
                          nhan={`lần ${l.loai === 'in' ? 'vào' : 'ra'} ${gio(l.luc)}`}
                        />
                      </div>
                    ))
                  )}
                </td>

                <td data-nhan="Giờ vào – ra">
                  {daCham ? (
                    <span className="nhan-phu">
                      {d.phutLam > 0 ? `${docCong(congTuPhut(d.phutLam, phutChuan))} công` : '—'}
                    </span>
                  ) : (
                    <span className="flex items-center gap-1">
                      <input
                        type="time"
                        value={g.vao}
                        onChange={(e) => datRieng(d.employeeId, 'vao', e.target.value)}
                        aria-label={`Giờ vào của ${d.ten}`}
                        className={O_GIO}
                      />
                      <span className="text-slate-400">–</span>
                      <input
                        type="time"
                        value={g.ra}
                        onChange={(e) => datRieng(d.employeeId, 'ra', e.target.value)}
                        aria-label={`Giờ ra của ${d.ten}`}
                        className={O_GIO}
                      />
                    </span>
                  )}
                </td>

                <td data-nhan="Thành công" className="phai">
                  {daCham ? (
                    <span className="nhan-phu">đã có công</span>
                  ) : cong === 0 ? (
                    <span className="text-red-600 dark:text-red-400">0 công</span>
                  ) : (
                    <strong>{docCong(cong)} công</strong>
                  )}
                </td>
              </tr>
            )
          })}
        </tbody>
      </table>

      {/*
        Form chỉ chứa ô ẩn, đặt NGOÀI bảng. Xem chú thích đầu file: nút xoá
        từng lần chấm cũng là form, mà form lồng form thì trình duyệt bỏ cái
        bên trong.
      */}
      <form action={chay} className="mt-3">
        <input type="hidden" name="work_date" value={ngay} />
        <input type="hidden" name="ly_do" value={lyDo} />
        <input type="hidden" name="gio_vao" value={vaoChung} />
        <input type="hidden" name="gio_ra" value={raChung} />
        {daTick.map((d) => (
          <span key={d.employeeId}>
            <input type="hidden" name="nguoi" value={d.employeeId} />
            <input
              type="hidden"
              name={`gio_vao_${d.employeeId}`}
              value={gioCua(d.employeeId).vao}
            />
            <input
              type="hidden"
              name={`gio_ra_${d.employeeId}`}
              value={gioCua(d.employeeId).ra}
            />
          </span>
        ))}

        <div className="flex flex-wrap items-center gap-3">
          <NutGui so={daTick.length} />
          {trangThai.error && (
            <p role="alert" className="text-sm text-red-600 dark:text-red-400">
              {trangThai.error}
            </p>
          )}
          {trangThai.xong && (
            <p className="text-sm text-green-700 dark:text-green-400">{trangThai.xong}</p>
          )}
        </div>
      </form>
    </>
  )
}
