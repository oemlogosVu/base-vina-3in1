import { KhungTrang, Khoi } from '@ns/components/khung-trang'
import { NutIn } from '@ns/components/nut-in'
import { batBuocTab } from '@ns/lib/phien'
import { createClient } from '@ns/lib/supabase/server'
import { docCong, type CaChuan } from '@ns/lib/cong-ngay'
import {
  bangCongCongTy,
  bangCongToDoi,
  laChuNhat,
  type BangCongThang,
  type ONgay,
} from '@ns/lib/bang-cong-thang'
import { DieuHuongChamCong } from '../dieu-huong'

const THU = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7']

function thuCuaNgay(ngay: string): string {
  const [n = 1970, t = 1, d = 1] = ngay.split('-').map(Number)
  return THU[new Date(Date.UTC(n, t - 1, d)).getUTCDay()] ?? ''
}

/** Tháng này theo giờ Việt Nam, dạng yyyy-mm. */
function thangNayVN(): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Ho_Chi_Minh',
    year: 'numeric',
    month: '2-digit',
  })
    .format(new Date())
    .slice(0, 7)
}

const LOP_O: Record<ONgay['loai'], string> = {
  du_cong: 'o-du',
  nua_cong: 'o-thieu',
  nghi: 'o-nghi',
  trong: '',
  chu_nhat: 'o-cn',
  tuong_lai: 'o-tuong-lai',
}

/**
 * Chữ trong ô.
 *
 * Ô trống của ngày ĐÃ QUA và ô của ngày CHƯA TỚI đều không có công, nhưng đọc
 * khác hẳn nhau: một cái là "người này nghỉ", cái kia là "chưa đến ngày".
 * Dùng chung một dấu là buộc tội sai.
 */
function chuTrongO(o: ONgay): string {
  switch (o.loai) {
    case 'chu_nhat':
      return 'CN'
    case 'tuong_lai':
      return '·'
    case 'trong':
      return '–'
    case 'nghi':
      return 'N'
    default:
      return docCong(o.cong)
  }
}

function BangMaTran({ bang, donViCot }: { bang: BangCongThang; donViCot: string }) {
  return (
    <div className="khung-cuon">
      <table className="ma-tran">
        <thead>
          <tr>
            <th className="cot-ten">Họ và tên</th>
            {bang.ngay.map((n) => (
              <th key={n} className="o-ngay" title={n}>
                <span className="block">{Number(n.slice(8))}</span>
                <span className="block" style={{ fontWeight: 400, opacity: 0.7 }}>
                  {thuCuaNgay(n)}
                </span>
              </th>
            ))}
            <th className="cot-tong">{donViCot}</th>
            <th className="cot-tong">Giờ NG</th>
          </tr>
        </thead>

        <tbody>
          {bang.dong.map((d) => (
            <tr key={d.employeeId}>
              <th scope="row" className="cot-ten" title={`${d.ten} · ${d.ma}`}>
                {d.ten}
              </th>
              {d.o.map((o) => (
                <td
                  key={o.ngay}
                  className={`o-ngay ${LOP_O[o.loai]}${o.khaiHo ? ' o-khai-ho' : ''}`}
                  title={
                    `${o.ngay} · ${d.ten}` +
                    (o.khaiHo ? ' · công KHAI HỘ, không có ảnh' : '') +
                    (o.chuaDuyet ? ' · phiên CHƯA DUYỆT' : '') +
                    (o.gioOt > 0 ? ` · ${o.gioOt} giờ ngoài giờ` : '')
                  }
                >
                  {o.chuaDuyet ? <em>{chuTrongO(o)}</em> : chuTrongO(o)}
                </td>
              ))}
              <td className="cot-tong">{docCong(d.tongCong)}</td>
              <td className="cot-tong">{d.tongGioOt > 0 ? docCong(d.tongGioOt) : '—'}</td>
            </tr>
          ))}
        </tbody>

        <tfoot>
          <tr>
            <th scope="row" className="cot-ten">
              Có mặt
            </th>
            {bang.coMat.map((so, i) => (
              <td key={bang.ngay[i]} className={`o-ngay${laChuNhat(bang.ngay[i]!) ? ' o-cn' : ''}`}>
                {so > 0 ? so : '—'}
              </td>
            ))}
            <td className="cot-tong">
              {docCong(bang.dong.reduce((t, d) => t + d.tongCong, 0))}
            </td>
            <td className="cot-tong">
              {docCong(bang.dong.reduce((t, d) => t + d.tongGioOt, 0))}
            </td>
          </tr>
        </tfoot>
      </table>
    </div>
  )
}

export default async function TrangBangCongThang({
  searchParams,
}: {
  searchParams: Promise<{ pv?: string; thang?: string }>
}) {
  const phien = await batBuocTab('cham-cong-xac-nhan')
  const { pv: pvThamSo, thang: thangThamSo } = await searchParams

  const thangSoi = /^\d{4}-\d{2}$/.test(thangThamSo ?? '') ? thangThamSo! : thangNayVN()
  const [nam = 1970, thang = 1] = thangSoi.split('-').map(Number)

  // Cùng cách mã hoá phạm vi với màn Sửa chữa công: một tham số, không hai.
  const khop = /^(to|cty):([0-9a-f-]{36})$/i.exec(pvThamSo ?? '')
  const kieu = khop?.[1] as 'to' | 'cty' | undefined
  const pvId = khop?.[2]

  const supabase = await createClient()

  const [{ data: dsTo }, { data: dsCongTy }, { data: caTho }] = await Promise.all([
    supabase.from('to_doi').select('id, code, name').eq('is_active', true).order('code'),
    supabase.from('companies').select('id, name').eq('is_active', true).order('code'),
    supabase
      .from('work_shifts')
      .select('start_time, end_time, break_start, break_end')
      .eq('is_active', true)
      .order('code')
      .limit(1)
      .maybeSingle(),
  ])

  // Cùng ca mà `tong_hop_cong_ngay()` dùng. Lấy ca khác là bảng này quy công
  // theo một mẫu số khác với mẫu số engine lương dùng.
  const ca: CaChuan = {
    tu: (caTho?.start_time ?? '08:00:00').slice(0, 5),
    den: (caTho?.end_time ?? '17:00:00').slice(0, 5),
    nghiTu: caTho?.break_start ? caTho.break_start.slice(0, 5) : null,
    nghiDen: caTho?.break_end ? caTho.break_end.slice(0, 5) : null,
  }

  const bang =
    kieu === 'cty' && pvId
      ? await bangCongCongTy(pvId, nam, thang, ca)
      : kieu === 'to' && pvId
        ? await bangCongToDoi(pvId, nam, thang)
        : null

  const tenPhamVi =
    kieu === 'cty'
      ? (dsCongTy?.find((c) => c.id === pvId)?.name ?? 'Công ty')
      : (dsTo?.find((t) => t.id === pvId)?.name ?? 'Tổ đội')

  return (
    <KhungTrang phien={phien} tieuDe="Chấm công công ty">
      <DieuHuongChamCong dang="bang-thang" />

      <Khoi
        tieuDe="Chọn phạm vi và tháng"
        ghiChu="Bảng chỉ ĐỌC. Sửa công thì sang tab Sửa chữa công; xác nhận từng ngày thì sang màn Xác nhận hằng ngày."
      >
        <form method="get" className="flex flex-wrap items-end gap-3">
          <label className="text-sm">
            <span className="mb-1 block font-medium">Phạm vi</span>
            <select
              name="pv"
              defaultValue={pvThamSo ?? ''}
              className="rounded-lg border border-slate-300 px-3 py-2 text-base dark:border-slate-700 dark:bg-slate-950"
            >
              <option value="">— chọn —</option>
              <optgroup label="Công ty — nhân viên chính thức">
                {(dsCongTy ?? []).map((c) => (
                  <option key={c.id} value={`cty:${c.id}`}>
                    {c.name}
                  </option>
                ))}
              </optgroup>
              <optgroup label="Tổ đội công nhật">
                {(dsTo ?? []).map((t) => (
                  <option key={t.id} value={`to:${t.id}`}>
                    {t.name} ({t.code})
                  </option>
                ))}
              </optgroup>
            </select>
          </label>
          <label className="text-sm">
            <span className="mb-1 block font-medium">Tháng</span>
            <input
              type="month"
              name="thang"
              defaultValue={thangSoi}
              className="rounded-lg border border-slate-300 px-3 py-2 text-base dark:border-slate-700 dark:bg-slate-950"
            />
          </label>
          <button
            type="submit"
            className="rounded-lg bg-slate-900 px-4 py-2 text-sm font-medium text-white dark:bg-slate-100 dark:text-slate-900"
          >
            Xem
          </button>
          {bang && <NutIn />}
        </form>
      </Khoi>

      {bang && (
        <Khoi
          tieuDe={`${tenPhamVi} · tháng ${String(thang).padStart(2, '0')}/${nam}`}
          ghiChu={
            bang.dong.length === 0
              ? undefined
              : `${bang.dong.length} người · đơn vị ô: ${bang.donVi === 'cong' ? 'ngày công' : 'ngày công quy từ giờ'}`
          }
        >
          {bang.dong.length === 0 ? (
            <p className="nhan-phu">Phạm vi này chưa có ai trong tháng đang xem.</p>
          ) : (
            <>
              <BangMaTran bang={bang} donViCot={bang.donVi === 'cong' ? 'Công' : 'Công'} />

              <p className="nhan-phu mt-3">
                <strong>Đọc bảng:</strong> số là ngày công · <strong>N</strong> nghỉ ·{' '}
                <strong>–</strong> chưa chấm · <strong>CN</strong> chủ nhật ·{' '}
                <strong>·</strong> chưa tới ngày · chấm cam góc ô = công{' '}
                <strong>khai hộ</strong> · chữ nghiêng = phiên <strong>chưa duyệt</strong>.
              </p>
              <p className="nhan-phu mt-1">
                Nền xanh đủ công, vàng thiếu, đỏ nhạt nghỉ. Ngày chưa tới cố ý{' '}
                <strong>không tô màu</strong> — tô nó giống ngày nghỉ là buộc tội một người nghỉ
                vào ngày chưa xảy ra.
              </p>
            </>
          )}
        </Khoi>
      )}

      {!bang && (
        <Khoi tieuDe="Chưa chọn phạm vi">
          <p className="nhan-phu">
            Chọn một công ty để xem công của nhân viên chính thức, hoặc một tổ đội để xem công
            nhật. Hai bên khác đơn vị nên cố ý không gộp chung một bảng.
          </p>
        </Khoi>
      )}
    </KhungTrang>
  )
}
