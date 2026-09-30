import Image from 'next/image'
import { KhungTrang, Khoi } from '@ns/components/khung-trang'
import { batBuocTab } from '@ns/lib/phien'
import {
  layCongTyCuaToi,
  layHangDoiXacNhan,
  layHeSoLamThem,
  layLinkAnhHangLoat,
  layLogDaXacNhanTheoNgay,
  layNgayCoLamThem,
} from '@ns/lib/cham-cong'
import { gio, ngay, ngayGio, phutThanhGio } from '@ns/lib/dinh-dang'
import {
  ATTENDANCE_DAY_STATUS_LABELS,
  CHECK_TYPE_LABELS,
  type AttendanceDayStatus,
} from '@ns/types/database'
import {
  FormTongHopLai,
  FormTyLeLamThem,
  FormXacNhanCaNgay,
  FormXacNhanMotLan,
  FormXoaLanCham,
} from './bieu-mau'
import { DieuHuongChamCong } from './dieu-huong'

/** Ngày hôm nay theo giờ Việt Nam, dạng yyyy-mm-dd. */
function homNayVN(): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Ho_Chi_Minh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date())
}

/** Ngày làm việc theo giờ VN của một mốc thời gian. */
function ngayVN(t: string): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Ho_Chi_Minh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date(t))
}

export default async function TrangXacNhanChamCong({
  searchParams,
}: {
  searchParams: Promise<{ ngay?: string }>
}) {
  const phien = await batBuocTab('cham-cong-xac-nhan')
  const hangDoi = await layHangDoiXacNhan()

  // Ngày đang soi ở khối "đã xác nhận". Chỉ nhận đúng dạng yyyy-mm-dd: tham
  // số URL là dữ liệu người dùng gửi lên và nó đi thẳng vào mốc lọc truy vấn.
  const { ngay: ngayThamSo } = await searchParams
  const ngaySoi = /^\d{4}-\d{2}-\d{2}$/.test(ngayThamSo ?? '') ? ngayThamSo! : homNayVN()

  // Chỉ admin xoá được, nên chỉ admin cần danh sách này — không đi lấy dữ
  // liệu mà người xem không dùng tới.
  const daXacNhan = phien.role === 'admin' ? await layLogDaXacNhanTheoNgay(ngaySoi) : []

  const [congTyCuaToi, ngayLamThem, heSo] = await Promise.all([
    layCongTyCuaToi(phien.employeeId),
    layNgayCoLamThem(ngaySoi),
    layHeSoLamThem(ngaySoi),
  ])

  // Chủ nhật là ngày nghỉ tuần trong mô hình hiện tại; engine lương chia hệ
  // số theo đúng quy ước đó.
  const laNgayNghi = new Date(`${ngaySoi}T00:00:00+07:00`).getUTCDay() === 0
  const heSoMacDinh = laNgayNghi ? heSo.ngayNghiTuan : heSo.ngayThuong

  // Một lượt gọi Storage cho cả danh sách, không phải mỗi ảnh một lượt.
  const linkAnh = await layLinkAnhHangLoat(hangDoi.map((l) => l.selfie_path))

  // Gom theo ngày: nhân sự làm việc theo ngày, không theo từng lần bấm rời rạc.
  const theoNgay = new Map<string, { log: (typeof hangDoi)[number]; anh: string | null }[]>()
  for (const l of hangDoi) {
    const d = ngayVN(l.logged_at)
    const ds = theoNgay.get(d) ?? []
    ds.push({ log: l, anh: l.selfie_path ? (linkAnh.get(l.selfie_path) ?? null) : null })
    theoNgay.set(d, ds)
  }

  return (
    <KhungTrang phien={phien} tieuDe="Chấm công công ty">
      <DieuHuongChamCong dang="xac-nhan" />
      <div className="mb-6 rounded-xl bg-slate-100 p-4 text-sm dark:bg-slate-800">
        <p className="font-medium">Không xác nhận thì không tính công.</p>
        <p className="mt-1">
          Hệ thống chỉ ghi lại thời điểm nhân viên bấm. Nó <strong>không</strong> tự phán đoán
          lần chấm nào đúng hay sai — người quyết định là bạn. Bảng công và bảng lương chỉ
          đếm những lần đã được xác nhận ở đây.
        </p>
      </div>

      <Khoi
        tieuDe="Xác nhận cả ngày"
        ghiChu={
          congTyCuaToi
            ? `Xác nhận cho nhân viên của ${congTyCuaToi.name} — đúng công ty bạn đang ký hợp đồng. Nhân viên pháp nhân khác không bị đụng tới.`
            : 'Tài khoản của bạn chưa gắn hồ sơ nhân sự nên KHÔNG giới hạn theo công ty: nút này xác nhận cho nhân viên của mọi pháp nhân trong hệ thống.'
        }
      >
        <FormXacNhanCaNgay ngayMacDinh={homNayVN()} />
      </Khoi>

      <Khoi
        tieuDe={`Chờ xác nhận (${hangDoi.length})`}
        ghiChu="Xác nhận lẻ từng lần chỉ dùng cho trường hợp cá biệt — ví dụ một người quên bấm ra, hoặc bấm nhầm."
      >
        {hangDoi.length === 0 ? (
          <p className="text-sm text-slate-500">Không có lần chấm nào chờ xác nhận.</p>
        ) : (
          <div className="space-y-8">
            {[...theoNgay.entries()].map(([d, dsLog]) => (
              <section key={d}>
                <h3 className="mb-3 font-medium">
                  {ngay(d)}{' '}
                  <span className="font-normal text-slate-500">({dsLog.length} lần chấm)</span>
                </h3>

                <ul className="space-y-5">
                  {dsLog.map(({ log: l, anh }) => (
                    <li
                      key={l.id}
                      className="border-t border-slate-100 pt-5 first:border-0 first:pt-0 dark:border-slate-800"
                    >
                      <div className="flex flex-wrap gap-x-6 gap-y-3">
                        <div className="min-w-56 flex-1">
                          <p className="font-medium">
                            {l.employees?.full_name ?? 'Không rõ'}{' '}
                            <span className="font-normal text-slate-500">
                              {l.employees?.employee_code ?? ''}
                            </span>
                          </p>
                          <p className="mt-1 text-sm">
                            <span className="text-slate-500">Chấm </span>
                            {CHECK_TYPE_LABELS[l.check_type]} lúc <strong>{gio(l.logged_at)}</strong>{' '}
                            <span className="text-slate-500">({ngayGio(l.logged_at)})</span>
                          </p>
                          {!l.selfie_path && (
                            <p className="mt-1 text-sm text-slate-500">Không kèm ảnh.</p>
                          )}

                          <FormXacNhanMotLan id={l.id} />
                        </div>

                        {anh && (
                          <div className="w-32 shrink-0">
                            <Image
                              src={anh}
                              alt={`Ảnh chấm công của ${l.employees?.full_name ?? 'nhân viên'}`}
                              width={128}
                              height={128}
                              unoptimized
                              className="h-32 w-32 rounded-lg border border-slate-200 object-cover dark:border-slate-800"
                            />
                          </div>
                        )}
                      </div>
                    </li>
                  ))}
                </ul>
              </section>
            ))}
          </div>
        )}
      </Khoi>

      {phien.role === 'admin' && (
        <Khoi
          tieuDe={`Đã xác nhận ngày ${ngay(ngaySoi)} (${daXacNhan.length})`}
          ghiChu="Đây là những lần chấm ĐANG được tính vào bảng công. Xoá một dòng ở đây là bảng công và tiền lương của kỳ chưa chốt đổi theo ngay."
        >
          <form method="get" className="mb-5 flex flex-wrap items-end gap-3">
            <div>
              <label htmlFor="ngay-soi" className="mb-1 block text-sm font-medium">
                Xem ngày
              </label>
              <input
                id="ngay-soi"
                name="ngay"
                type="date"
                defaultValue={ngaySoi}
                className="rounded-lg border border-slate-300 px-3 py-2 text-base outline-none focus:border-slate-900 dark:border-slate-700 dark:bg-slate-950"
              />
            </div>
            <button
              type="submit"
              className="rounded-lg border border-slate-300 px-4 py-2 text-sm font-medium dark:border-slate-700"
            >
              Xem
            </button>
          </form>

          {daXacNhan.length === 0 ? (
            <p className="text-sm text-slate-500">
              Ngày này chưa có lần chấm nào được xem xét.
            </p>
          ) : (
            <ul className="space-y-4">
              {daXacNhan.map((l) => (
                <li
                  key={l.id}
                  className="border-t border-slate-100 pt-4 first:border-0 first:pt-0 dark:border-slate-800"
                >
                  <p className="font-medium">
                    {l.employees?.full_name ?? 'Không rõ'}{' '}
                    <span className="font-normal text-slate-500">
                      {l.employees?.employee_code ?? ''}
                    </span>
                  </p>
                  <p className="mt-1 text-sm">
                    {CHECK_TYPE_LABELS[l.check_type]} lúc <strong>{gio(l.logged_at)}</strong>
                    {!l.da_xac_nhan && (
                      <span className="text-slate-500"> — đã xem và KHÔNG công nhận</span>
                    )}
                  </p>
                  {/* Chỉ lần chấm được công nhận mới đáng xoá: lần không công
                      nhận vốn đã không tính vào bảng công. */}
                  {l.da_xac_nhan && (
                    <FormXoaLanCham
                      id={l.id}
                      moTa={`${CHECK_TYPE_LABELS[l.check_type]} lúc ${gio(l.logged_at)} của ${l.employees?.full_name ?? 'nhân viên này'}`}
                    />
                  )}
                </li>
              ))}
            </ul>
          )}
        </Khoi>
      )}

      <Khoi
        tieuDe={`Tỷ lệ làm thêm ngày ${ngay(ngaySoi)}${laNgayNghi ? ' — chủ nhật' : ''}`}
        ghiChu={
          heSoMacDinh > 0
            ? `Để trống thì áp hệ số mặc định ${heSoMacDinh}% của ${laNgayNghi ? 'ngày nghỉ tuần' : 'ngày thường'}. Nhập số khác để áp riêng cho đúng ngày này của đúng người này — không ảnh hưởng ngày khác, không đổi chính sách chung.`
            : 'Chưa có hệ số làm thêm hiệu lực tại ngày này trong bảng tham số lương, nên chưa có mức mặc định để gợi ý.'
        }
      >
        {ngayLamThem.length === 0 ? (
          <p className="text-sm text-slate-500">
            Ngày này không ai có phút làm thêm. Đổi ngày ở ô bên trên để xem ngày khác.
          </p>
        ) : (
          <ul className="space-y-4">
            {ngayLamThem.map((d) => (
              <li
                key={d.id}
                className="flex flex-wrap items-center justify-between gap-3 border-t border-slate-100 pt-4 first:border-0 first:pt-0 dark:border-slate-800"
              >
                <div>
                  <p className="font-medium">
                    {d.employees?.full_name ?? 'Không rõ'}{' '}
                    <span className="font-mono text-xs font-normal text-slate-500">
                      {d.employees?.employee_code ?? ''}
                    </span>
                  </p>
                  <p className="mt-1 text-sm text-slate-500">
                    Làm thêm {phutThanhGio(d.ot_minutes)} · giờ làm thường{' '}
                    {phutThanhGio(d.worked_minutes)} ·{' '}
                    {ATTENDANCE_DAY_STATUS_LABELS[d.status as AttendanceDayStatus] ?? d.status}
                    {d.ty_le_lam_them_pct === null
                      ? ' · đang theo mặc định'
                      : ` · đang áp riêng ${d.ty_le_lam_them_pct}%`}
                  </p>
                </div>
                <FormTyLeLamThem
                  id={d.id}
                  hienTai={d.ty_le_lam_them_pct}
                  macDinh={heSoMacDinh}
                />
              </li>
            ))}
          </ul>
        )}
      </Khoi>

      <Khoi
        tieuDe="Tổng hợp lại bảng công"
        ghiChu="Dùng khi đã xác nhận lẻ từng lần, hoặc khi sửa gì đó và muốn con số của ngày cập nhật lại."
      >
        <FormTongHopLai ngayMacDinh={homNayVN()} />
      </Khoi>
    </KhungTrang>
  )
}
