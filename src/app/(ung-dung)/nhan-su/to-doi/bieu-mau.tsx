'use client'

import { useActionState, useState } from 'react'
import { useFormStatus } from 'react-dom'
import { useRouter } from 'next/navigation'
import { createClient } from '@ns/lib/supabase/client'
import {
  gioTuKhoang,
  kiemGioMotNguoi,
  type KhoangGio,
  type KhungGioCongTy,
} from '@ns/lib/gio-chuan'
import { tien as tienVN } from '@ns/lib/dinh-dang'
import {
  duyetPhienChamCongTo,
  luuChamCongTo,
  moLaiPhienChamCongTo,
  type TrangThaiForm,
} from './actions'

const BAN_DAU: TrangThaiForm = { error: null }

export type ThanhVien = {
  employeeId: string
  ma: string
  ten: string
}

/** Một ca của công ty, và giờ MẶC ĐỊNH của nó (P5f). */
export type CaCongTy = { ma: MaCa; nhan: string; bd: string; kt: string }

export type MaCa = 'sang' | 'chieu' | 'toi'

/** Giờ đã chấm của một người. `null` = không làm khoảng ấy. */
export type GioCa = {
  caSang: KhoangGio | null
  caChieu: KhoangGio | null
  caToi: KhoangGio | null
  /** Khoảng làm thêm ngoài ba ca — toàn bộ tính là ngoài giờ. */
  ngoaiGio: KhoangGio | null
  /**
   * Tiền thưởng ẤN ĐỊNH, đơn vị ĐỒNG (P5i, 25/08/2026).
   *
   * Tên là `tienThuong` chứ không phải `thuong`: trong file này "thường" đã
   * mang nghĩa GIỜ THƯỜNG (đối lập với ngoài giờ) — xem `gioCua()` và biến
   * `tong.thuong`. Hai thứ cùng tên trong một file là cách chắc chắn để một
   * hôm nào đó cộng nhầm tiền vào giờ.
   */
  tienThuong: number
  thuongLyDo: string
}

export type CongDaCo = Record<string, GioCa>

/**
 * Ba khoá ca, thu hẹp về đúng ba trường giờ.
 *
 * Không dùng `keyof GioCa`: từ P5i kiểu ấy còn có `tienThuong` (số) và
 * `thuongLyDo` (chữ), nên `tick[KHOA_CA[ma]]` sẽ nới ra `string | number |
 * KhoangGio` và mọi chỗ đọc `.bd` / `.kt` hỏng theo.
 */
const KHOA_CA: Record<MaCa, 'caSang' | 'caChieu' | 'caToi'> = {
  sang: 'caSang',
  chieu: 'caChieu',
  toi: 'caToi',
}

/**
 * Thu nhỏ ảnh trước khi gửi.
 *
 * Ảnh máy điện thoại đời mới thường 4–8MB, mà bucket chặn ở 2MB — không thu
 * nhỏ thì người dùng nhận lỗi "quá lớn" mà không hiểu vì sao, ngay giữa công
 * trường. Cạnh dài 1600px đủ để nhìn rõ mặt người trong ảnh tập thể.
 */
async function thuNhoAnh(file: File): Promise<string> {
  const anh = await createImageBitmap(file)
  const canhDai = Math.max(anh.width, anh.height)
  const tyLe = canhDai > 1600 ? 1600 / canhDai : 1

  const canvas = document.createElement('canvas')
  canvas.width = Math.round(anh.width * tyLe)
  canvas.height = Math.round(anh.height * tyLe)

  const ctx = canvas.getContext('2d')
  if (!ctx) throw new Error('Trình duyệt không xử lý được ảnh này.')
  ctx.drawImage(anh, 0, 0, canvas.width, canvas.height)

  return canvas.toDataURL('image/jpeg', 0.7)
}

/**
 * Lấy câu lỗi thật của Edge Function.
 *
 * `functions.invoke` gói mọi mã trạng thái khác 2xx thành một
 * `FunctionsHttpError` với câu chữ chung chung. Lý do thật nằm trong thân
 * phản hồi, phải đọc ra — không đọc thì người dùng nhận một thông báo không
 * nói gì và không biết phải làm gì.
 */
async function docLoiHam(error: unknown, data: unknown): Promise<string | null> {
  if (error) {
    const ctx = (error as { context?: unknown }).context
    if (ctx instanceof Response) {
      try {
        const than = await ctx.json()
        if (typeof than?.loi === 'string') return than.loi
      } catch {
        // Thân phản hồi không phải JSON — rơi xuống thông báo mặc định.
      }
    }
    return error instanceof Error ? error.message : 'không gọi được máy chủ.'
  }
  if (data && typeof (data as { loi?: unknown }).loi === 'string') {
    return (data as { loi: string }).loi
  }
  return null
}

/** 7.5 → "7,5". Người Việt đọc dấu phẩy, và số giờ hay là số lẻ. */
const soGio = (n: number) => String(Math.round(n * 100) / 100).replace('.', ',')

const O_GIO =
  'w-24 rounded-lg border border-slate-300 px-2 py-1.5 text-sm dark:border-slate-700 dark:bg-slate-950'

const KHONG_CA: GioCa = {
  caSang: null,
  caChieu: null,
  caToi: null,
  ngoaiGio: null,
  tienThuong: 0,
  thuongLyDo: '',
}

/** Giờ mặc định rót vào ô ngoài giờ: nối ngay sau giờ ra của công ty. */
const NGOAI_GIO_MAC_DINH = (khung: KhungGioCongTy | null): KhoangGio =>
  khung ? { bd: khung.gioRa, kt: '00:00' } : { bd: '18:00', kt: '22:00' }

export function LuoiChamCong({
  toDoiId,
  ngay,
  thanhVien,
  caCongTy,
  khung,
  congDaCo,
  daCoAnh,
}: {
  toDoiId: string
  ngay: string
  thanhVien: ThanhVien[]
  caCongTy: CaCongTy[]
  khung: KhungGioCongTy | null
  congDaCo: CongDaCo
  daCoAnh: boolean
}) {
  const router = useRouter()

  // Mặc định KHÔNG tick ca nào, không phải làm đủ. Cùng nguyên tắc với
  // `is_valid` mặc định false ở chấm công cá nhân: sai theo hướng bỏ sót an
  // toàn hơn sai theo hướng tạo công khống. Có nút "cả tổ" cho ai làm đủ.
  const [cong, setCong] = useState<CongDaCo>(() =>
    Object.fromEntries(
      thanhVien.map((t) => [t.employeeId, congDaCo[t.employeeId] ?? KHONG_CA]),
    ),
  )
  const [anh, setAnh] = useState<string | null>(null)
  const [tenAnh, setTenAnh] = useState<string | null>(null)
  const [dangLuu, setDangLuu] = useState(false)
  const [loi, setLoi] = useState<string | null>(null)
  const [xong, setXong] = useState<string | null>(null)

  /** Bật ca = rót giờ mặc định của công ty vào; tắt = xoá cặp giờ. */
  const bat = (id: string, ca: CaCongTy) =>
    setCong((c) => {
      const truoc = c[id] ?? KHONG_CA
      const khoa = KHOA_CA[ca.ma]
      return {
        ...c,
        [id]: { ...truoc, [khoa]: truoc[khoa] ? null : { bd: ca.bd, kt: ca.kt } },
      }
    })

  /** Sửa một đầu giờ của một ca. Chỉ chạm được khi ca ấy đang bật. */
  const datGio = (id: string, ma: MaCa, dau: 'bd' | 'kt', gt: string) =>
    setCong((c) => {
      const truoc = c[id] ?? KHONG_CA
      const khoa = KHOA_CA[ma]
      const hienTai = truoc[khoa]
      if (!hienTai) return c
      return { ...c, [id]: { ...truoc, [khoa]: { ...hienTai, [dau]: gt } } }
    })

  const gioCua = (g: GioCa | undefined) =>
    gioTuKhoang(
      khung,
      [g?.caSang ?? undefined, g?.caChieu ?? undefined, g?.caToi ?? undefined],
      g?.ngoaiGio ?? undefined,
    )

  /** Bật/tắt dòng ngoài giờ của một người. */
  const batNgoaiGio = (id: string) =>
    setCong((c) => {
      const truoc = c[id] ?? KHONG_CA
      return {
        ...c,
        [id]: {
          ...truoc,
          ngoaiGio: truoc.ngoaiGio ? null : NGOAI_GIO_MAC_DINH(khung),
        },
      }
    })

  const datNgoaiGio = (id: string, dau: 'bd' | 'kt', gt: string) =>
    setCong((c) => {
      const truoc = c[id] ?? KHONG_CA
      if (!truoc.ngoaiGio) return c
      return { ...c, [id]: { ...truoc, ngoaiGio: { ...truoc.ngoaiGio, [dau]: gt } } }
    })

  /**
   * Ô thưởng nhận chữ, không nhận số.
   *
   * Người chấm gõ "100.000" hay "100000" đều phải ra 100000 — họ đang đứng
   * ngoài công trường, không phải đang điền biểu mẫu kế toán. Bỏ mọi ký tự
   * không phải chữ số rồi mới đổi sang số.
   */
  const datThuong = (id: string, gt: string) =>
    setCong((c) => {
      const truoc = c[id] ?? KHONG_CA
      const so = Number(gt.replace(/[^\d]/g, '') || '0')
      return { ...c, [id]: { ...truoc, tienThuong: so } }
    })

  const datThuongLyDo = (id: string, gt: string) =>
    setCong((c) => {
      const truoc = c[id] ?? KHONG_CA
      return { ...c, [id]: { ...truoc, thuongLyDo: gt } }
    })

  const tongThuong = thanhVien.reduce(
    (t, x) => t + (cong[x.employeeId]?.tienThuong ?? 0),
    0,
  )

  const tong = thanhVien.reduce(
    (t, x) => {
      const g = gioCua(cong[x.employeeId])
      return { thuong: t.thuong + g.thuong, ot: t.ot + g.ot }
    },
    { thuong: 0, ot: 0 },
  )

  async function chonAnh(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    if (!file) return
    setLoi(null)
    try {
      setAnh(await thuNhoAnh(file))
      setTenAnh(file.name)
    } catch (err) {
      setLoi(err instanceof Error ? err.message : 'Không đọc được ảnh.')
    }
  }

  async function luu() {
    setLoi(null)
    setXong(null)
    setDangLuu(true)

    try {
      const dsCong = thanhVien.map((t) => ({
        employeeId: t.employeeId,
        ten: t.ten,
        ...(cong[t.employeeId] ?? KHONG_CA),
      }))

      // Cùng hàm kiểm mà server action gọi — nói lỗi ngay, không đợi lượt mạng.
      // Lớp chặn thật vẫn là ràng buộc ở database.
      for (const d of dsCong) {
        const loiGio = kiemGioMotNguoi(d.ten, [
          { nhan: 'ca sáng', gt: d.caSang },
          { nhan: 'ca chiều', gt: d.caChieu },
          { nhan: 'ca tối', gt: d.caToi },
          { nhan: 'ngoài giờ', gt: d.ngoaiGio },
        ])
        if (loiGio !== null) throw new Error(loiGio)
        if (d.tienThuong > 0 && d.thuongLyDo.trim() === '') {
          throw new Error(
            `Có thưởng cho ${d.ten} thì phải ghi lý do — một khoản tiền không có chữ nào ` +
              'đi kèm là một câu hỏi không ai trả lời được sau vài tháng.',
          )
        }
      }

      const kq = await luuChamCongTo(toDoiId, ngay, dsCong)
      if (kq.error !== null) throw new Error(kq.error)

      // Ảnh đi sau và có thể hỏng riêng. Số công KHÔNG bị cuốn theo: người
      // lao động không đáng mất công vì sóng yếu. Đổi lại, phiên thiếu ảnh
      // thì database không cho duyệt, nên không có đường lách.
      if (anh && kq.phienId) {
        const supabase = createClient()
        const { data, error } = await supabase.functions.invoke('anh-cham-cong-to', {
          body: { phien_id: kq.phienId, anh_base64: anh },
        })
        const loiAnh = await docLoiHam(error, data)
        if (loiAnh) {
          // Nói LÝ DO thật, không chỉ nói "chưa tải được".
          //
          // Bản trước nuốt lý do và luôn đổ cho sóng yếu. Ngày 22/08/2026 hàm
          // trả 404 cho MỌI lần gọi — nó truy vấn một cột đã bị gỡ từ 19/08 —
          // và màn hình vẫn khuyên người dùng "chụp lại khi có sóng". Người
          // dùng chụp lại mãi mà không đời nào chạy được.
          setXong(
            `Đã lưu số công, nhưng CHƯA tải được ảnh lên: ${loiAnh} ` +
              'Thiếu ảnh thì nhân sự không duyệt được.',
          )
          router.refresh()
          return
        }
        setAnh(null)
        setTenAnh(null)
      }

      setXong(
        anh || daCoAnh
          ? 'Đã lưu số công và ảnh. Chờ nhân sự duyệt.'
          : 'Đã lưu số công. Còn thiếu ẢNH XÁC MINH — nhân sự chưa duyệt được cho tới khi có ảnh.',
      )
      router.refresh()
    } catch (e) {
      setLoi(e instanceof Error ? e.message : 'Không lưu được. Thử lại.')
    } finally {
      setDangLuu(false)
    }
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center gap-2 text-sm">
        {/* Một nút cho mỗi ca: cả tổ cùng làm một ca là tình huống thường
            nhất ngoài công trường, và bấm 15 lần cho 15 người thì không ai
            dùng màn này lần thứ hai. */}
        {caCongTy.map((ca) => (
          <button
            key={ca.ma}
            type="button"
            onClick={() =>
              setCong((c) =>
                Object.fromEntries(
                  thanhVien.map((t) => [
                    t.employeeId,
                    {
                      ...(c[t.employeeId] ?? KHONG_CA),
                      [KHOA_CA[ca.ma]]: { bd: ca.bd, kt: ca.kt },
                    },
                  ]),
                ),
              )
            }
            className="rounded-lg border border-slate-300 px-3 py-1.5 dark:border-slate-700"
          >
            Cả tổ {ca.nhan.toLowerCase()} ({ca.bd}–{ca.kt})
          </button>
        ))}
        <button
          type="button"
          onClick={() =>
            setCong(Object.fromEntries(thanhVien.map((t) => [t.employeeId, KHONG_CA])))
          }
          className="rounded-lg border border-slate-300 px-3 py-1.5 dark:border-slate-700"
        >
          Xoá hết
        </button>
        <span className="text-slate-500">
          {thanhVien.length} người
          {tong.thuong > 0 && <> · tổng {soGio(tong.thuong)} giờ</>}
          {tong.ot > 0 && <> · ngoài giờ {soGio(tong.ot)} giờ</>}
          {tongThuong > 0 && <> · thưởng {tienVN(tongThuong)}đ</>}
        </span>
      </div>

      <p className="text-xs text-slate-500">
        <strong>Ngoài giờ</strong> là khoảng làm thêm ngoài ba ca — toàn bộ tính là ngoài giờ,
        không trừ giờ nghỉ. Giờ kết thúc <strong>00:00 nghĩa là nửa đêm</strong>. Làm sang ngày
        mai thì ghi đến 00:00 ở đây, phần còn lại ghi tiếp ở phiếu ngày mai.
      </p>

      <ul className="divide-y divide-slate-100 dark:divide-slate-800">
        {thanhVien.map((t) => {
          const tick = cong[t.employeeId] ?? KHONG_CA
          const g = gioCua(tick)
          return (
            <li key={t.employeeId} className="flex flex-wrap items-center gap-3 py-3">
              <div className="min-w-40 flex-1">
                <p className="text-sm font-medium">{t.ten}</p>
                <p className="font-mono text-xs text-slate-500">{t.ma}</p>
              </div>

              {/* Bấm tên ca = bật/tắt ca ấy. Bật thì hai ô giờ hiện ra, rót
                  sẵn giờ mặc định của công ty; sửa được cho đúng người này. */}
              <div className="flex flex-wrap gap-2">
                {caCongTy.map((ca) => {
                  const gio = tick[KHOA_CA[ca.ma]]
                  return (
                    <div key={ca.ma} className="flex items-center gap-1">
                      <button
                        type="button"
                        aria-pressed={gio !== null}
                        onClick={() => bat(t.employeeId, ca)}
                        title={`Mặc định ${ca.bd}–${ca.kt}`}
                        className={`rounded-lg px-3 py-2 text-sm ${
                          gio
                            ? 'bg-slate-900 text-white dark:bg-slate-100 dark:text-slate-900'
                            : 'border border-slate-300 dark:border-slate-700'
                        }`}
                      >
                        {ca.nhan}
                      </button>
                      {gio && (
                        <>
                          <input
                            type="time"
                            value={gio.bd}
                            onChange={(e) => datGio(t.employeeId, ca.ma, 'bd', e.target.value)}
                            aria-label={`${ca.nhan} của ${t.ten}: giờ vào`}
                            className={O_GIO}
                          />
                          <span className="text-slate-400">–</span>
                          <input
                            type="time"
                            value={gio.kt}
                            onChange={(e) => datGio(t.employeeId, ca.ma, 'kt', e.target.value)}
                            aria-label={`${ca.nhan} của ${t.ten}: giờ ra`}
                            className={O_GIO}
                          />
                        </>
                      )}
                    </div>
                  )
                })}

                {/* Ngoài giờ là khoảng RIÊNG, không thuộc ca nào: toàn bộ tính
                    là ngoài giờ, không xét khung giờ chuẩn. Kết thúc lúc 00:00
                    nghĩa là nửa đêm — làm qua đêm thì ghi tiếp vào phiếu ngày
                    mai. */}
                <div className="flex items-center gap-1">
                  <button
                    type="button"
                    aria-pressed={tick.ngoaiGio !== null}
                    onClick={() => batNgoaiGio(t.employeeId)}
                    title="Khoảng làm thêm ngoài ba ca. Kết thúc 00:00 = nửa đêm."
                    className={`rounded-lg px-3 py-2 text-sm ${
                      tick.ngoaiGio
                        ? 'bg-amber-600 text-white dark:bg-amber-500 dark:text-slate-900'
                        : 'border border-dashed border-amber-500 text-amber-700 dark:text-amber-400'
                    }`}
                  >
                    Ngoài giờ
                  </button>
                  {tick.ngoaiGio && (
                    <>
                      <input
                        type="time"
                        value={tick.ngoaiGio.bd}
                        onChange={(e) => datNgoaiGio(t.employeeId, 'bd', e.target.value)}
                        aria-label={`Ngoài giờ của ${t.ten}: giờ bắt đầu`}
                        className={O_GIO}
                      />
                      <span className="text-slate-400">–</span>
                      <input
                        type="time"
                        value={tick.ngoaiGio.kt}
                        onChange={(e) => datNgoaiGio(t.employeeId, 'kt', e.target.value)}
                        aria-label={`Ngoài giờ của ${t.ten}: giờ kết thúc`}
                        className={O_GIO}
                      />
                    </>
                  )}
                </div>
              </div>

              {/* Thưởng: SỐ TIỀN ẤN ĐỊNH, không nhân với gì cả (P5i).

                  Ô lý do chỉ hiện khi đã gõ một số tiền — người không được
                  thưởng thì không phải nhìn thêm một ô trống nào. */}
              <div className="flex items-center gap-1">
                <input
                  type="text"
                  inputMode="numeric"
                  value={tick.tienThuong ? tienVN(tick.tienThuong) : ''}
                  onChange={(e) => datThuong(t.employeeId, e.target.value)}
                  placeholder="Thưởng"
                  aria-label={`Tiền thưởng của ${t.ten}, đơn vị đồng`}
                  className={`${O_GIO} text-right`}
                />
                {tick.tienThuong > 0 && (
                  <input
                    type="text"
                    value={tick.thuongLyDo}
                    onChange={(e) => datThuongLyDo(t.employeeId, e.target.value)}
                    placeholder="Lý do thưởng"
                    aria-label={`Lý do thưởng của ${t.ten}`}
                    className="w-40 rounded-lg border border-slate-300 px-2 py-1.5 text-sm"
                  />
                )}
              </div>

              {/* Hiện ngay số giờ sẽ được tính, để người chấm thấy hệ quả của
                  ô mình vừa bấm thay vì chờ tới lúc duyệt mới biết. */}
              <span className="min-w-32 text-right text-sm tabular-nums">
                {g.thuong === 0 && g.ot === 0 ? (
                  <span className="text-slate-400">nghỉ</span>
                ) : (
                  <>
                    {soGio(g.thuong)} giờ
                    {g.ot > 0 && (
                      <span className="text-amber-700 dark:text-amber-400">
                        {' '}
                        + {soGio(g.ot)} ngoài giờ
                      </span>
                    )}
                  </>
                )}
              </span>
            </li>
          )
        })}
      </ul>

      <div className="rounded-lg bg-slate-50 p-4 dark:bg-slate-900">
        <label htmlFor="anh-to" className="block text-sm font-medium">
          Ảnh xác minh {daCoAnh && <span className="text-slate-500">(đã có ảnh — chọn ảnh mới để thay)</span>}
        </label>
        <input
          id="anh-to"
          type="file"
          accept="image/*"
          capture="environment"
          onChange={chonAnh}
          className="mt-2 block w-full text-sm"
        />
        <p className="mt-2 text-xs text-slate-500">
          Một ảnh cho cả tổ mỗi ngày. Ảnh chứng minh có người chụp tại thời điểm nào, không
          chứng minh từng người có mặt — nhân sự vẫn đối chiếu khi duyệt.
        </p>
        {tenAnh && <p className="mt-1 text-xs text-slate-500">Đã chọn: {tenAnh}</p>}
      </div>

      <button
        type="button"
        onClick={luu}
        disabled={dangLuu}
        className="rounded-lg bg-slate-900 px-4 py-2 text-sm font-medium text-white disabled:opacity-60 dark:bg-slate-100 dark:text-slate-900"
      >
        {dangLuu ? 'Đang lưu…' : 'Lưu chấm công'}
      </button>

      {loi !== null && (
        <p role="alert" className="text-sm text-red-600">
          {loi}
        </p>
      )}
      {xong !== null && <p className="text-sm text-emerald-700 dark:text-emerald-400">{xong}</p>}
    </div>
  )
}

function NutNho({ nhan, dangChay }: { nhan: string; dangChay: string }) {
  const { pending } = useFormStatus()
  return (
    <button
      type="submit"
      disabled={pending}
      className="rounded-lg border border-slate-300 px-3 py-1.5 text-sm disabled:opacity-60 dark:border-slate-700"
    >
      {pending ? dangChay : nhan}
    </button>
  )
}

export function FormDuyetPhien({ id }: { id: string }) {
  const [trangThai, gui] = useActionState(duyetPhienChamCongTo, BAN_DAU)
  return (
    <form action={gui} className="inline-flex flex-col gap-1">
      <input type="hidden" name="id" value={id} />
      <NutNho nhan="Duyệt" dangChay="Đang duyệt…" />
      {trangThai.error !== null && (
        <span role="alert" className="text-xs text-red-600">
          {trangThai.error}
        </span>
      )}
      {trangThai.xong && <span className="text-xs text-emerald-700">{trangThai.xong}</span>}
    </form>
  )
}

export function FormMoLaiPhien({ id }: { id: string }) {
  const [trangThai, gui] = useActionState(moLaiPhienChamCongTo, BAN_DAU)
  return (
    <form action={gui} className="inline-flex flex-col gap-1">
      <input type="hidden" name="id" value={id} />
      <NutNho nhan="Mở lại" dangChay="Đang mở…" />
      {trangThai.error !== null && (
        <span role="alert" className="text-xs text-red-600">
          {trangThai.error}
        </span>
      )}
      {trangThai.xong && <span className="text-xs text-emerald-700">{trangThai.xong}</span>}
    </form>
  )
}
