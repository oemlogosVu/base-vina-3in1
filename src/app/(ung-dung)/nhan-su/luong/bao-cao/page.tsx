import Link from 'next/link'
import { createClient } from '@ns/lib/supabase/server'
import { batBuocTab } from '@ns/lib/phien'
import { KhungTrang } from '@ns/components/khung-trang'
import { NutIn } from './nut-in'
import { PERIOD_STATUS_LABELS } from '@ns/types/database'

/**
 * Số tiền trong bảng báo cáo: KHÔNG kèm ký hiệu ₫.
 *
 * Bảng có mười cột số; nhắc lại "₫" ở từng ô làm cột rộng gấp rưỡi và mắt
 * khó dóng hàng. Đơn vị ghi một lần ở đầu báo cáo, đúng cách bảng biểu kế
 * toán vẫn làm.
 */
const SO = new Intl.NumberFormat('vi-VN', { maximumFractionDigits: 0 })
const so = (v: unknown) => SO.format(Number(v ?? 0))

/** Ngày công có phần lẻ (5,5 ngày) nên giữ tối đa 2 chữ số thập phân. */
const NGAY_CONG = new Intl.NumberFormat('vi-VN', { maximumFractionDigits: 2 })

const THANG_NAM = (nam: number, thang: number) => `${String(thang).padStart(2, '0')}/${nam}`

/** yyyy-mm của thẻ input[type=month] → số nguyên yyyymm. Sai dạng thì trả null. */
function thangSang(v: string | undefined): number | null {
  if (!v || !/^\d{4}-\d{2}$/.test(v)) return null
  const [nam, thang] = v.split('-').map(Number)
  if (!nam || !thang || thang < 1 || thang > 12) return null
  return nam * 100 + thang
}

const soSangThang = (n: number) =>
  `${Math.floor(n / 100)}-${String(n % 100).padStart(2, '0')}`

export default async function BaoCaoLuongPage({
  searchParams,
}: {
  searchParams: Promise<{ cty?: string; tu?: string; den?: string }>
}) {
  const phien = await batBuocTab('luong-bao-cao')
  const supabase = await createClient()
  const { cty, tu, den } = await searchParams

  const { data: congTy, error: loiCongTy } = await supabase
    .from('companies')
    .select('id, code, name, tax_code, address')
    .order('code')
  if (loiCongTy) throw new Error(`Không đọc được danh sách công ty: ${loiCongTy.message}`)

  const dsCongTy = congTy ?? []
  const ctyChon = dsCongTy.find((c) => c.id === cty) ?? dsCongTy[0]

  // Mặc định 6 kỳ gần nhất tính tới tháng hiện tại theo giờ Việt Nam. Máy chủ
  // chạy UTC nên phải ép múi giờ, nếu không thì đêm 30 rạng 01 hàng tháng báo
  // cáo mặc định lệch một kỳ.
  const homNay = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Ho_Chi_Minh',
    year: 'numeric',
    month: '2-digit',
  }).format(new Date())
  const [namNay, thangNay] = homNay.split('-').map(Number)
  const denMacDinh = namNay! * 100 + thangNay!

  // Lùi 5 tháng qua số thứ tự tháng tuyệt đối, KHÔNG trừ thẳng trên yyyymm:
  // 202601 − 5 ra 202596, một "tháng 96" không tồn tại và khoảng lọc thành
  // rỗng suốt nửa đầu mỗi năm.
  const soThang = namNay! * 12 + (thangNay! - 1) - 5
  const tuMacDinh = Math.floor(soThang / 12) * 100 + (soThang % 12) + 1

  const tuSo = thangSang(tu) ?? tuMacDinh
  const denSo = thangSang(den) ?? denMacDinh
  // Người dùng chọn ngược thì đảo lại thay vì trả bảng rỗng không giải thích.
  const [tuCuoi, denCuoi] = tuSo <= denSo ? [tuSo, denSo] : [denSo, tuSo]

  if (!ctyChon) {
    return (
      <KhungTrang phien={phien} tieuDe="Báo cáo tổng hợp lương">
        <p className="text-sm text-slate-500">
          Chưa khai báo công ty nào. Vào{' '}
          <Link href="/nhan-su/quan-tri/cong-ty" className="underline">
            Quản trị → Công ty
          </Link>{' '}
          để thêm.
        </p>
      </KhungTrang>
    )
  }

  const [{ data: theoKy, error: loiKy }, { data: theoNguoi, error: loiNguoi }] = await Promise.all([
    supabase.rpc('bao_cao_luong_theo_ky', {
      p_company_id: ctyChon.id,
      p_tu: tuCuoi,
      p_den: denCuoi,
    }),
    supabase.rpc('bao_cao_luong_theo_nhan_vien', {
      p_company_id: ctyChon.id,
      p_tu: tuCuoi,
      p_den: denCuoi,
    }),
  ])
  if (loiKy) throw new Error(`Không đọc được tổng hợp theo kỳ: ${loiKy.message}`)
  if (loiNguoi) throw new Error(`Không đọc được tổng hợp theo nhân viên: ${loiNguoi.message}`)

  const ky = theoKy ?? []
  const nguoi = theoNguoi ?? []

  // Cộng tổng ở đây CHỈ để hiển thị dòng cuối bảng. Từng dòng đã được Postgres
  // cộng bằng numeric; phép cộng lại này chạy trên số đã làm tròn về đồng nên
  // không sinh sai số phân xu.
  const cong = (ds: readonly Record<string, unknown>[], truong: string) =>
    ds.reduce((s, d) => s + Number(d[truong] ?? 0), 0)

  const chuaChot = ky.filter((k) => k.trang_thai === 'mo')
  const inLuc = new Intl.DateTimeFormat('vi-VN', {
    timeZone: 'Asia/Ho_Chi_Minh',
    dateStyle: 'short',
    timeStyle: 'short',
  }).format(new Date())

  const O =
    'rounded-lg border border-slate-300 px-3 py-2 text-base outline-none focus:border-slate-900 dark:border-slate-700 dark:bg-slate-950'

  return (
    <KhungTrang phien={phien} tieuDe="Báo cáo tổng hợp lương">
      <form method="get" className="khong-in mb-6 flex flex-wrap items-end gap-3">
        <div>
          <label htmlFor="cty" className="mb-1 block text-sm font-medium">
            Công ty
          </label>
          <select id="cty" name="cty" defaultValue={ctyChon.id} className={O}>
            {dsCongTy.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </select>
        </div>
        <div>
          <label htmlFor="tu" className="mb-1 block text-sm font-medium">
            Từ kỳ
          </label>
          <input id="tu" name="tu" type="month" defaultValue={soSangThang(tuCuoi)} className={O} />
        </div>
        <div>
          <label htmlFor="den" className="mb-1 block text-sm font-medium">
            Đến kỳ
          </label>
          <input id="den" name="den" type="month" defaultValue={soSangThang(denCuoi)} className={O} />
        </div>
        <button type="submit" className="rounded-lg border border-slate-300 px-4 py-2 text-sm font-medium dark:border-slate-700">
          Xem báo cáo
        </button>
        <NutIn />
      </form>

      {/* Đầu báo cáo — phần này IN RA GIẤY, nên phải tự nói đủ: ai, kỳ nào,
          in lúc nào. Một tờ giấy rời khỏi màn hình thì không còn ngữ cảnh. */}
      <header className="khong-tach-trang mb-5 border-b border-slate-300 pb-4 dark:border-slate-700">
        <p className="text-lg font-semibold">{ctyChon.name}</p>
        {ctyChon.tax_code && <p className="text-sm">Mã số thuế: {ctyChon.tax_code}</p>}
        {ctyChon.address && <p className="text-sm text-slate-600 dark:text-slate-400">{ctyChon.address}</p>}
        <h2 className="mt-3 text-xl font-bold">BẢNG TỔNG HỢP LƯƠNG</h2>
        <p className="text-sm">
          Từ kỳ {THANG_NAM(Math.floor(tuCuoi / 100), tuCuoi % 100)} đến kỳ{' '}
          {THANG_NAM(Math.floor(denCuoi / 100), denCuoi % 100)}
        </p>
        <p className="mt-1 text-xs text-slate-600 dark:text-slate-400">
          Đơn vị tính: đồng · In lúc {inLuc} · Người in: {phien.fullName}
        </p>
      </header>

      {chuaChot.length > 0 && (
        <p className="khong-tach-trang mb-5 border border-amber-400 bg-amber-50 p-3 text-sm dark:bg-amber-950/30">
          <strong>Có {chuaChot.length} kỳ chưa chốt</strong> (
          {chuaChot.map((k) => THANG_NAM(k.nam, k.thang)).join(', ')}). Số liệu của các kỳ này
          còn thay đổi được — tính lại là đổi. Chỉ dùng bản in này làm chứng từ sau khi đã chốt kỳ.
        </p>
      )}

      {ky.length === 0 ? (
        <p className="text-sm text-slate-500">
          Không có kỳ lương nào của công ty này trong khoảng đã chọn.
        </p>
      ) : (
        <>
          <section className="khong-tach-trang mb-8">
            <h3 className="mb-2 font-medium">1. Tổng hợp theo kỳ</h3>
            <div className="overflow-x-auto">
              <table className="bang">
                <thead>
                  <tr>
                    <th>Kỳ</th>
                    <th>Trạng thái</th>
                    <th className="phai">Số người</th>
                    <th className="phai">Ngày công</th>
                    <th className="phai">Tổng thu nhập</th>
                    <th className="phai">BH người LĐ đóng</th>
                    <th className="phai">Thuế TNCN</th>
                    <th className="phai">Thực nhận</th>
                    <th className="phai">BH công ty đóng</th>
                    <th className="phai">Chi phí lao động</th>
                  </tr>
                </thead>
                <tbody>
                  {ky.map((k) => (
                    <tr key={`${k.nam}-${k.thang}`}>
                      <td className="font-semibold">{THANG_NAM(k.nam, k.thang)}</td>
                      <td data-nhan="Trạng thái">{PERIOD_STATUS_LABELS[k.trang_thai]}</td>
                      <td data-nhan="Số người" className="phai">{k.so_phieu}</td>
                      <td data-nhan="Ngày công" className="phai">{NGAY_CONG.format(Number(k.tong_ngay_cong))}</td>
                      <td data-nhan="Tổng thu nhập" className="phai">{so(k.tong_gross)}</td>
                      <td data-nhan="BH người LĐ đóng" className="phai">{so(k.bh_nguoi_lao_dong)}</td>
                      <td data-nhan="Thuế TNCN" className="phai">{so(k.tong_thue)}</td>
                      <td data-nhan="Thực nhận" className="phai font-semibold">{so(k.tong_net)}</td>
                      <td data-nhan="BH công ty đóng" className="phai">{so(k.bh_cong_ty)}</td>
                      <td data-nhan="Chi phí lao động" className="phai">{so(k.tong_chi_phi)}</td>
                    </tr>
                  ))}
                </tbody>
                <tfoot>
                  <tr >
                    <td colSpan={2}>
                      TỔNG CỘNG {ky.length} kỳ
                    </td>
                    <td data-nhan="Trạng thái" className="phai">{cong(ky, 'so_phieu')}</td>
                    <td data-nhan="Số người" className="phai">{NGAY_CONG.format(cong(ky, 'tong_ngay_cong'))}</td>
                    <td data-nhan="Ngày công" className="phai">{so(cong(ky, 'tong_gross'))}</td>
                    <td data-nhan="Tổng thu nhập" className="phai">{so(cong(ky, 'bh_nguoi_lao_dong'))}</td>
                    <td data-nhan="BH người LĐ đóng" className="phai">{so(cong(ky, 'tong_thue'))}</td>
                    <td data-nhan="Thuế TNCN" className="phai">{so(cong(ky, 'tong_net'))}</td>
                    <td data-nhan="Thực nhận" className="phai">{so(cong(ky, 'bh_cong_ty'))}</td>
                    <td data-nhan="BH công ty đóng" className="phai">{so(cong(ky, 'tong_chi_phi'))}</td>
                  </tr>
                </tfoot>
              </table>
            </div>
          </section>

          <section>
            <h3 className="mb-2 font-medium">
              2. Tổng hợp theo nhân viên ({nguoi.length} người)
            </h3>
            <div className="overflow-x-auto">
              <table className="bang">
                <thead>
                  <tr>
                    <th>STT</th>
                    <th>Mã NV</th>
                    <th>Họ và tên</th>
                    <th className="phai">Số kỳ</th>
                    <th className="phai">Ngày công</th>
                    <th className="phai">Tổng thu nhập</th>
                    <th className="phai">BH người LĐ đóng</th>
                    <th className="phai">Thuế TNCN</th>
                    <th className="phai">Thực nhận</th>
                    <th className="phai">BH công ty đóng</th>
                  </tr>
                </thead>
                <tbody>
                  {nguoi.map((n, i) => (
                    <tr key={n.employee_code + i}>
                      <td>{i + 1}</td>
                      <td data-nhan="Mã NV" className="font-mono">{n.employee_code}</td>
                      <td data-nhan="Họ và tên">{n.full_name}</td>
                      <td data-nhan="Số kỳ" className="phai">{n.so_ky}</td>
                      <td data-nhan="Ngày công" className="phai">{NGAY_CONG.format(Number(n.tong_ngay_cong))}</td>
                      <td data-nhan="Tổng thu nhập" className="phai">{so(n.tong_gross)}</td>
                      <td data-nhan="BH người LĐ đóng" className="phai">{so(n.bh_nguoi_lao_dong)}</td>
                      <td data-nhan="Thuế TNCN" className="phai">{so(n.tong_thue)}</td>
                      <td data-nhan="Thực nhận" className="phai font-semibold">{so(n.tong_net)}</td>
                      <td data-nhan="BH công ty đóng" className="phai">{so(n.bh_cong_ty)}</td>
                    </tr>
                  ))}
                </tbody>
                <tfoot>
                  <tr >
                    <td colSpan={3}>
                      TỔNG CỘNG
                    </td>
                    <td data-nhan="Mã NV" className="phai">{cong(nguoi, 'so_ky')}</td>
                    <td data-nhan="Họ và tên" className="phai">{NGAY_CONG.format(cong(nguoi, 'tong_ngay_cong'))}</td>
                    <td data-nhan="Số kỳ" className="phai">{so(cong(nguoi, 'tong_gross'))}</td>
                    <td data-nhan="Ngày công" className="phai">{so(cong(nguoi, 'bh_nguoi_lao_dong'))}</td>
                    <td data-nhan="Tổng thu nhập" className="phai">{so(cong(nguoi, 'tong_thue'))}</td>
                    <td data-nhan="BH người LĐ đóng" className="phai">{so(cong(nguoi, 'tong_net'))}</td>
                    <td data-nhan="Thuế TNCN" className="phai">{so(cong(nguoi, 'bh_cong_ty'))}</td>
                  </tr>
                </tfoot>
              </table>
            </div>
          </section>

          {/* Hai bảng cộng từ cùng một tập phiếu lương nên tổng phải bằng nhau.
              Lệch nghĩa là có dòng bị RLS ẩn khỏi người đang xem — nói ra chứ
              không để người đọc tự phát hiện bằng máy tính bỏ túi. */}
          {cong(ky, 'tong_net') !== cong(nguoi, 'tong_net') && (
            <p className="khong-tach-trang mt-5 border border-red-400 bg-red-50 p-3 text-sm dark:bg-red-950/30">
              <strong>Hai bảng không khớp nhau.</strong> Tổng thực nhận theo kỳ là{' '}
              {so(cong(ky, 'tong_net'))} nhưng theo nhân viên là {so(cong(nguoi, 'tong_net'))}. Có
              phiếu lương nằm ngoài quyền xem của bạn — bản in này chưa đầy đủ.
            </p>
          )}

          <div className="khong-tach-trang mt-10 grid grid-cols-3 gap-4 text-center text-sm">
            <div>
              <p className="font-medium">Người lập biểu</p>
              <p className="text-xs text-slate-500">(Ký, ghi rõ họ tên)</p>
            </div>
            <div>
              <p className="font-medium">Kế toán trưởng</p>
              <p className="text-xs text-slate-500">(Ký, ghi rõ họ tên)</p>
            </div>
            <div>
              <p className="font-medium">Giám đốc</p>
              <p className="text-xs text-slate-500">(Ký, đóng dấu)</p>
            </div>
          </div>
        </>
      )}
    </KhungTrang>
  )
}
