import Link from 'next/link'
import { KhungTrang, Khoi } from '@ns/components/khung-trang'
import { batBuocTab, CONG_DOC_LUONG, quaCong } from '@ns/lib/phien'
import { ngay as dinhDangNgay, ngayGio, ngayHomNayVN, tien } from '@ns/lib/dinh-dang'
import {
  duocVaoQuanLyToDoi,
  layBangDaSuaTay,
  layBangThanhToan,
  layChiTietBang,
  layLichSuSuaTay,
  layMoiToDoi,
  layToDoiToiCham,
} from '@ns/lib/to-doi'
import { OChungTu } from '@ns/components/o-chung-tu'
import { duongTaiChungTu, layChungTuTheoDoiTuong } from '@ns/lib/chung-tu'
import { FormSinhBang, FormSuaDong, FormXoaBang, type DongSua, type ToChon } from './bieu-mau'
import { DieuHuongToDoi } from '../dieu-huong'

/** 0.5 → "0,5". */
const so = (n: number) => Number(n).toString().replace('.', ',')

/** Đơn vị của một dòng — đọc số lượng mà không biết đơn vị là đọc sai. */
const donVi = (kieu: string) => (kieu === 'gio' ? 'giờ' : 'công')

/**
 * Các con số của một dòng sổ sửa tay, theo thứ tự cột của bảng. Chỉ in những
 * số ĐÃ ĐỔI — in đủ sáu thì người đọc phải tự dò xem lần sửa ấy đổi cái gì.
 */
const TRUONG_SUA = [
  { khoa: 'so_luong', nhan: 'Số lượng', laTien: false },
  { khoa: 'don_gia', nhan: 'Đơn giá', laTien: true },
  { khoa: 'so_gio_ot', nhan: 'Giờ NG', laTien: false },
  { khoa: 'don_gia_ot', nhan: 'Đơn giá NG', laTien: true },
  { khoa: 'thuong', nhan: 'Thưởng', laTien: true },
  { khoa: 'thanh_tien', nhan: 'Thành tiền', laTien: true },
] as const

function cacThayDoi(truoc: Record<string, number>, sau: Record<string, number>): string[] {
  return TRUONG_SUA.filter((t) => Number(truoc[t.khoa]) !== Number(sau[t.khoa])).map((t) => {
    const viet = (n: number) => (t.laTien ? tien(n) : so(n))
    return `${t.nhan} ${viet(Number(truoc[t.khoa]))} → ${viet(Number(sau[t.khoa]))}`
  })
}

const HOP_XANH =
  'mb-4 rounded-lg bg-emerald-50 p-4 text-sm text-emerald-900 dark:bg-emerald-950 dark:text-emerald-200'
const HOP_VANG =
  'mb-4 rounded-lg bg-amber-50 p-4 text-sm text-amber-900 dark:bg-amber-950 dark:text-amber-200'

/** Ngày đầu tháng này theo giờ Việt Nam — mặc định hợp lý cho ô "từ ngày". */
function dauThangVN(): string {
  return `${ngayHomNayVN().slice(0, 7)}-01`
}

export default async function TrangThanhToanToDoi({
  searchParams,
}: {
  searchParams: Promise<{
    bang?: string
    sua?: string
    da_sua?: string
    da_xoa?: string
    thieu_chung_tu?: string
  }>
}) {
  const phien = await batBuocTab('to-doi')
  // Khớp với `can_read_payroll()` ở database — chức danh mang quyền quản lý
  // nhân sự hoặc tính lương cũng đọc được bảng thanh toán của mọi tổ.
  const laQuanLy = quaCong(phien, CONG_DOC_LUONG)
  const laAdmin = phien.role === 'admin'

  const toToiCham = await layToDoiToiCham(phien.userId)
  const danhSachTo = laQuanLy ? await layMoiToDoi() : toToiCham
  // Xem `duocVaoQuanLyToDoi`: điều kiện hiện đường dẫn phải là ĐÚNG điều kiện
  // vào được màn kia, không phải một điều kiện gần giống.
  const quanLyDuoc = await duocVaoQuanLyToDoi(phien)
  const {
    bang: bangThamSo,
    sua: suaThamSo,
    da_sua: daSua,
    da_xoa: daXoa,
    thieu_chung_tu: thieuChungTu,
  } = await searchParams

  if (danhSachTo.length === 0) {
    return (
      <KhungTrang phien={phien} tieuDe="Quản lý tổ đội">
      <DieuHuongToDoi dang="thanh-toan" quanLyDuoc={quanLyDuoc} />
        <Khoi tieuDe="Bạn chưa được giao tổ nào">
          <p className="text-sm">
            Màn này dành cho người được giao chấm công cho một tổ công nhật, và cho kế toán.
          </p>
        </Khoi>
      </KhungTrang>
    )
  }

  const danhSachBang = await layBangThanhToan()
  const chiTiet = bangThamSo ? await layChiTietBang(bangThamSo) : null

  // Khớp với policy `bang_delete_admin_hoac_nguoi_cham` và hàm
  // `sua_tay_dong_thanh_toan_to` (P5j, 15/09/2026): admin, hoặc người chấm
  // của CHÍNH tổ ấy. Kế toán đọc được mọi bảng nhưng không sửa, không xoá.
  // Điều kiện này chỉ quyết định hiện nút — database mới là bên trả lời.
  const maToToiCham = new Set(toToiCham.map((t) => t.id))
  const duocSuaBang =
    chiTiet !== null && (laAdmin || maToToiCham.has(chiTiet.bang.to_doi_id))

  const lichSu = chiTiet ? await layLichSuSuaTay(chiTiet.bang.id) : []
  const nguoiDaSua = new Set(lichSu.map((s) => s.employee_id))
  const daSuaTay = await layBangDaSuaTay(danhSachBang.map((b) => b.id))

  const dongDangSua =
    chiTiet && duocSuaBang && suaThamSo
      ? (chiTiet.dong.find((d) => d.id === suaThamSo) ?? null)
      : null
  // Tiền rót vào ô KHÔNG có dấu chấm hàng nghìn: người sửa gõ thêm một số 0
  // vào "40.000" thì dễ ra "40.0000" — một con số không ai đọc ra được.
  const dongSua: DongSua | null = dongDangSua
    ? {
        id: dongDangSua.id,
        donVi: donVi(dongDangSua.kieu_tinh),
        soLuong: so(dongDangSua.so_luong),
        donGia: String(Number(dongDangSua.don_gia)),
        soGioOt: so(dongDangSua.so_gio_ot),
        donGiaOt: String(Number(dongDangSua.don_gia_ot)),
        thuong: String(Number(dongDangSua.thuong ?? 0)),
      }
    : null

  const chonTo: ToChon[] = danhSachTo.map((t) => ({
    id: t.id,
    nhan: `${t.name} (${t.code})`,
  }))

  // Chứng từ của các bảng đang hiện. Đường tải ký sẵn hạn 10 phút nên dựng
  // ngay lúc vẽ trang, không dựng sẵn để dành.
  const chungTuTheoBang = await layChungTuTheoDoiTuong(
    'bang_thanh_toan_to',
    danhSachBang.map((b) => b.id),
  )
  const duongTai = new Map<string, string | null>()
  for (const ct of chungTuTheoBang.values()) {
    duongTai.set(ct.doi_tuong_id, await duongTaiChungTu(ct.duong_dan))
  }

  const tongTien = (chiTiet?.dong ?? []).reduce((t, d) => t + Number(d.thanh_tien), 0)
  const tongGioOt = (chiTiet?.dong ?? []).reduce((t, d) => t + Number(d.so_gio_ot), 0)
  const tongThuong = (chiTiet?.dong ?? []).reduce((t, d) => t + Number(d.thuong ?? 0), 0)

  return (
    <KhungTrang phien={phien} tieuDe="Quản lý tổ đội">
      <DieuHuongToDoi dang="thanh-toan" quanLyDuoc={quanLyDuoc} />

      {daXoa && (
        <div className={HOP_XANH}>Đã xoá bảng. Sinh lại được sau khi duyệt thêm phiên.</div>
      )}

      <Khoi
        tieuDe="Sinh bảng cho một khoảng ngày"
        ghiChu="Chỉ cộng ngày công của những phiên ĐÃ ĐƯỢC NHÂN SỰ DUYỆT — công chưa duyệt là công chưa ai xác nhận."
      >
        <FormSinhBang danhSachTo={chonTo} tuNgay={dauThangVN()} denNgay={ngayHomNayVN()} />

        <p className="mt-4 text-sm text-slate-500">
          Bảng <strong>chụp lại</strong> số công và đơn giá tại thời điểm sinh. Sửa đơn giá về
          sau không làm đổi bảng đã sinh — bảng in ra trả tiền tháng trước phải giữ nguyên con
          số của tháng trước.
        </p>
      </Khoi>

      {chiTiet && (
        <Khoi
          tieuDe={`${chiTiet.bang.to_doi?.name} · ${dinhDangNgay(chiTiet.bang.tu_ngay)} – ${dinhDangNgay(chiTiet.bang.den_ngay)}`}
          ghiChu={
            lichSu.length > 0
              ? `Bản đã sửa tay ${lichSu.length} lần, lần gần nhất lúc ${ngayGio(chiTiet.bang.tao_luc)}. Lịch sử sửa nằm dưới bảng.`
              : `Sinh lúc ${ngayGio(chiTiet.bang.tao_luc)}. Số liệu đã chụp lại, không tính lại khi mở.`
          }
        >
          {daSua && (
            <div className={HOP_XANH}>
              Đã sửa tay. Bảng cũ được <strong>thay</strong> bằng bảng này; chứng từ PDF của bảng
              cũ vẫn giữ nguyên làm vết.
            </div>
          )}
          {daSua && thieuChungTu && (
            <div className={HOP_VANG}>
              Chưa sinh được chứng từ PDF cho bảng này — bấm <strong>Sinh chứng từ</strong> ở danh
              sách bảng bên dưới.
            </div>
          )}

          {Number(chiTiet.bang.dong_cho_duyet) > 0 && (
            <div className={HOP_VANG}>
              Còn <strong>{chiTiet.bang.dong_cho_duyet} dòng chấm công</strong> trong khoảng này
              thuộc phiên <strong>chưa được duyệt</strong> nên không có trong bảng. Nhân sự duyệt
              xong thì xoá bảng này và sinh lại.
            </div>
          )}

          <div className="overflow-x-auto">
            <table className="bang">
              <thead>
                <tr>
                  <th>Họ và tên</th>
                  <th>Mã</th>
                  <th className="phai">Số công / giờ</th>
                  <th className="phai">Đơn giá</th>
                  <th className="phai">Giờ NG</th>
                  <th className="phai">Đơn giá NG</th>
                  <th className="phai">Thưởng</th>
                  <th className="phai">Thành tiền</th>
                  {duocSuaBang && <th className="print:hidden" />}
                </tr>
              </thead>
              <tbody>
                {chiTiet.dong.map((d) => (
                  <tr key={d.id}>
                    <td>
                      {d.employees?.full_name}
                      {nguoiDaSua.has(d.employee_id) && (
                        <span className="nhan-phu ml-2">đã sửa tay</span>
                      )}
                    </td>
                    <td data-nhan="Mã" className="font-mono nhan-phu">
                      {d.employees?.employee_code}
                    </td>
                    <td data-nhan="Số công / giờ" className="phai">
                      {so(d.so_luong)} <span className="nhan-phu">{donVi(d.kieu_tinh)}</span>
                    </td>
                    <td data-nhan="Đơn giá" className="phai">
                      {tien(d.don_gia)}
                    </td>
                    <td data-nhan="Giờ NG" className="phai">
                      {Number(d.so_gio_ot) > 0 ? so(d.so_gio_ot) : '—'}
                    </td>
                    <td data-nhan="Đơn giá NG" className="phai">
                      {Number(d.so_gio_ot) > 0 ? tien(d.don_gia_ot) : '—'}
                    </td>
                    <td data-nhan="Thưởng" className="phai">
                      {Number(d.thuong) > 0 ? tien(d.thuong) : '—'}
                    </td>
                    <td data-nhan="Thành tiền" className="phai font-semibold">
                      {tien(d.thanh_tien)}
                    </td>
                    {duocSuaBang && (
                      <td className="phai print:hidden">
                        <Link
                          href={`/nhan-su/to-doi/thanh-toan?bang=${chiTiet.bang.id}&sua=${d.id}#sua-tay`}
                          className="text-sm underline"
                        >
                          Sửa
                        </Link>
                      </td>
                    )}
                  </tr>
                ))}
              </tbody>
              <tfoot>
                <tr>
                  <td colSpan={2}>Tổng {chiTiet.dong.length} người</td>
                  <td />
                  <td />
                  <td data-nhan="Tổng giờ NG" className="phai">
                    {tongGioOt > 0 ? so(tongGioOt) : '—'}
                  </td>
                  <td />
                  <td data-nhan="Tổng thưởng" className="phai">
                    {tongThuong > 0 ? tien(tongThuong) : '—'}
                  </td>
                  <td data-nhan="Tổng tiền" className="phai">
                    {tien(tongTien)}
                  </td>
                  {duocSuaBang && <td className="print:hidden" />}
                </tr>
              </tfoot>
            </table>
          </div>

          <p className="mt-4 text-sm text-slate-500">
            Số tiền trên là <strong>số gộp</strong>: số công × đơn giá, không khấu trừ khoản
            nào. Nghĩa vụ thuế cho khoản chi này xử lý ngoài phần mềm (quyết định 19/08/2026).
          </p>

          {/*
            Nút Sửa và Xoá: admin, hoặc người chấm của chính tổ này (P5j,
            15/09/2026). Từ P5h (24/08) tới hôm ấy màn này không có nút Sửa
            nào — database đã khoá, và một nút luôn báo lỗi thì tệ hơn không
            có nút. Nút Sửa hôm nay gọi vào hàm riêng `sua_tay_dong_thanh_toan_to`,
            lối UPDATE cũ vẫn đóng.
          */}
          {duocSuaBang && (
            <div className="mt-4">
              <FormXoaBang id={chiTiet.bang.id} />
            </div>
          )}
        </Khoi>
      )}

      {chiTiet && dongDangSua && dongSua && (
        <div id="sua-tay">
          <Khoi
            tieuDe={`Sửa tay: ${dongDangSua.employees?.full_name ?? 'một dòng'}`}
            ghiChu="Lưu xong, bảng này được THAY bằng một bảng mới cùng khoảng ngày, có chứng từ PDF mới; chứng từ cũ giữ nguyên làm vết. Mỗi lần sửa ghi vào sổ: ai sửa, từ bao nhiêu thành bao nhiêu, vì sao."
          >
            <FormSuaDong dong={dongSua} huyHref={`/nhan-su/to-doi/thanh-toan?bang=${chiTiet.bang.id}`} />
          </Khoi>
        </div>
      )}

      {lichSu.length > 0 && (
        <Khoi
          tieuDe={`Lịch sử sửa tay (${lichSu.length})`}
          ghiChu="Sổ này không ai sửa hay xoá được — kể cả khi bảng bị xoá."
        >
          <ul className="divide-y divide-slate-100 dark:divide-slate-800">
            {lichSu.map((s) => (
              <li key={s.id} className="space-y-1 py-3 text-sm">
                <p className="font-medium">{s.ten_nhan_cong}</p>
                <p>{cacThayDoi(s.truoc, s.sau).join(' · ')}</p>
                <p className="text-slate-500">Lý do: {s.ly_do}</p>
                <p className="text-xs text-slate-500">
                  {s.nguoi_sua_ten} · {ngayGio(s.sua_luc)}
                </p>
              </li>
            ))}
          </ul>
        </Khoi>
      )}

      <Khoi tieuDe={`Bảng đã sinh (${danhSachBang.length})`}>
        {danhSachBang.length === 0 ? (
          <p className="text-sm text-slate-500">Chưa sinh bảng nào.</p>
        ) : (
          <ul className="divide-y divide-slate-100 dark:divide-slate-800">
            {danhSachBang.map((b) => (
              <li key={b.id} className="flex flex-wrap items-center gap-3 py-3">
                <div className="min-w-48 flex-1">
                  <p className="text-sm font-medium">
                    {b.to_doi?.name}{' '}
                    <span className="font-mono text-xs text-slate-500">{b.to_doi?.code}</span>
                  </p>
                  <p className="text-xs text-slate-500">
                    {dinhDangNgay(b.tu_ngay)} – {dinhDangNgay(b.den_ngay)} · sinh lúc{' '}
                    {ngayGio(b.tao_luc)}
                    {daSuaTay.has(b.id) && ' · đã sửa tay'}
                    {Number(b.dong_cho_duyet) > 0 &&
                      ` · còn ${b.dong_cho_duyet} dòng chưa duyệt`}
                  </p>
                </div>
                <OChungTu
                  loai="bang_thanh_toan_to"
                  doiTuongId={b.id}
                  soHieu={chungTuTheoBang.get(b.id)?.so_hieu}
                  duongTai={duongTai.get(b.id)}
                />
                <Link
                  href={`/nhan-su/to-doi/thanh-toan?bang=${b.id}`}
                  className="text-sm underline"
                >
                  Xem bảng
                </Link>
              </li>
            ))}
          </ul>
        )}
      </Khoi>
    </KhungTrang>
  )
}
