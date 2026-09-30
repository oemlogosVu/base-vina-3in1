import Image from 'next/image'
import Link from 'next/link'
import { KhungTrang, Khoi } from '@ns/components/khung-trang'
import { batBuocTab, CONG_DUYET_CONG_TO, CONG_SUA_NHAN_SU, quaCong } from '@ns/lib/phien'
import { ngay as dinhDangNgay, ngayGio, ngayHomNayVN } from '@ns/lib/dinh-dang'
import {
  duocVaoQuanLyToDoi,
  layCaCuaCongTy,
  layLinkAnhToDoi,
  layMoiToDoi,
  layPhienChoDuyet,
  layPhienTheoNgay,
  layThanhVienTaiNgay,
  layToDoiToiCham,
} from '@ns/lib/to-doi'
import { FormDuyetPhien, FormMoLaiPhien, LuoiChamCong } from './bieu-mau'
import { DieuHuongToDoi } from './dieu-huong'

const LA_NGAY = /^\d{4}-\d{2}-\d{2}$/

/** 7.5 → "7,5". Người Việt đọc dấu phẩy, và số giờ hay là số lẻ. */
const soLe = (n: number) => String(Math.round(n * 100) / 100).replace('.', ',')

export default async function TrangChamCongToDoi({
  searchParams,
}: {
  searchParams: Promise<{ to?: string; ngay?: string }>
}) {
  const phien = await batBuocTab('to-doi')

  // Ba tư cách khác nhau trên cùng một màn, đừng gộp:
  //   laQuanLy  — HR/admin: chấm hộ được cho mọi tổ (tổ trưởng ốm, mất điện
  //               thoại…) và duyệt được.
  //   duyetDuoc — HR/admin, HOẶC chức danh mang quyền `duyet_cong` (P1e):
  //               duyệt được, nhưng KHÔNG ghi số công thay ai.
  //   toToiCham — tổ được giao chấm công cho chính người này.
  // Chấm hộ được cho mọi tổ = đúng cổng `is_hr_or_admin()` ở database.
  const laQuanLy = quaCong(phien, CONG_SUA_NHAN_SU)
  const duyetDuoc = quaCong(phien, CONG_DUYET_CONG_TO)

  // Người chỉ có quyền duyệt vẫn có thể kiêm chấm công cho một tổ nào đó, nên
  // vẫn phải hỏi câu này để biết ở tổ nào họ được GHI. HR/admin ghi được mọi
  // tổ nên bỏ hẳn một vòng mạng cho họ.
  const toToiCham = laQuanLy ? [] : await layToDoiToiCham(phien.userId)
  const danhSachTo = duyetDuoc ? await layMoiToDoi() : toToiCham

  // Có hiện đường sang màn Tổ đội & nhân công không. Hỏi bằng hàm chung để ba
  // màn của tab không lệch nhau — xem `duocVaoQuanLyToDoi`.
  const quanLyDuoc = await duocVaoQuanLyToDoi(phien)

  const { to: toThamSo, ngay: ngayThamSo } = await searchParams
  const ngaySoi = LA_NGAY.test(ngayThamSo ?? '') ? ngayThamSo! : ngayHomNayVN()
  const toDangChon =
    danhSachTo.find((t) => t.id === toThamSo) ?? danhSachTo[0] ?? null

  if (danhSachTo.length === 0) {
    return (
      <KhungTrang phien={phien} tieuDe="Quản lý tổ đội">
        <DieuHuongToDoi dang="cham-cong" quanLyDuoc={quanLyDuoc} />
        <Khoi tieuDe={duyetDuoc ? 'Chưa có tổ nào' : 'Bạn chưa được giao tổ nào'}>
          {duyetDuoc ? (
            <p className="text-sm">
              Bạn có quyền duyệt công tổ đội, nhưng hệ thống chưa có tổ nhân công thuê công
              nhật nào đang hoạt động — nên chưa có gì để duyệt.
            </p>
          ) : (
            <>
              <p className="text-sm">
                Màn này dành cho người được giao chấm công cho một tổ nhân công thuê công nhật.
                Tài khoản của bạn chưa được gán vào tổ nào.
              </p>
              <p className="mt-2 text-sm text-slate-500">
                Nếu bạn phụ trách một tổ, đề nghị quản trị hệ thống gán bạn làm người chấm công
                của tổ đó tại <strong>Quản trị → Tổ đội công nhật</strong>.
              </p>
            </>
          )}
          {phien.quanLyToDoi && (
            <p className="mt-3 text-sm">
              <Link href="/nhan-su/to-doi/quan-ly" className="underline">
                Bạn có quyền lập tổ — lập tổ đầu tiên tại đây →
              </Link>
            </p>
          )}
        </Khoi>
      </KhungTrang>
    )
  }

  const thanhVien = toDangChon ? await layThanhVienTaiNgay(toDangChon.id, ngaySoi) : []
  const phienNgay = toDangChon ? await layPhienTheoNgay(toDangChon.id, ngaySoi) : null
  const cauHinhCa = toDangChon
    ? await layCaCuaCongTy(toDangChon.company_id)
    : { khung: null, ca: [] }

  const linkAnh = await layLinkAnhToDoi([phienNgay?.phien.anh_path ?? null])
  const anhHienTai = phienNgay?.phien.anh_path
    ? (linkAnh.get(phienNgay.phien.anh_path) ?? null)
    : null

  // Duyệt và CHẤM là hai việc khác nhau: quyền `duyet_cong` không cho ghi số
  // công (RLS đòi là người chấm của tổ hoặc HR/admin). Hiện lưới nhập cho
  // người không ghi được là mời họ gõ vào một ô sẽ báo lỗi khi bấm Lưu.
  const ghiDuoc = laQuanLy || toToiCham.some((t) => t.id === toDangChon?.id)

  // P5h (24/08/2026): người chấm của chính tổ ấy duyệt được phiên của mình.
  // Quyết định của Triệu Vũ — đánh đổi ghi trong migration P5h. Lớp chặn thật
  // là ba policy UPDATE trên `phien_cham_cong_to`, không phải dòng này.
  const duyetDuocPhienNay =
    duyetDuoc || toToiCham.some((t) => t.id === toDangChon?.id)

  // "07:00:00" từ database → "07:00" cho ô <input type="time">.
  const cap = (tu: string | null, den: string | null) =>
    tu === null || den === null ? null : { bd: tu.slice(0, 5), kt: den.slice(0, 5) }

  const congDaCo = Object.fromEntries(
    (phienNgay?.dong ?? []).map((d) => [
      d.employee_id,
      {
        caSang: cap(d.ca_sang_tu, d.ca_sang_den),
        caChieu: cap(d.ca_chieu_tu, d.ca_chieu_den),
        caToi: cap(d.ca_toi_tu, d.ca_toi_den),
        ngoaiGio: cap(d.ngoai_gio_tu, d.ngoai_gio_den),
        tienThuong: Number(d.thuong ?? 0),
        thuongLyDo: d.thuong_ly_do ?? '',
      },
    ]),
  )

  const choDuyet = duyetDuoc ? await layPhienChoDuyet() : []

  return (
    <KhungTrang phien={phien} tieuDe="Quản lý tổ đội">
      <DieuHuongToDoi dang="cham-cong" quanLyDuoc={quanLyDuoc} />
      <Khoi
        tieuDe="Chọn tổ và ngày"
        ghiChu="Công nhật đếm theo số công 0 / 0,5 / 1, không đếm giờ vào–giờ ra."
      >
        <div className="flex flex-wrap gap-2">
          {danhSachTo.map((t) => (
            <Link
              key={t.id}
              href={`/nhan-su/to-doi?to=${t.id}&ngay=${ngaySoi}`}
              className={`rounded-lg px-3 py-2 text-sm ${
                t.id === toDangChon?.id
                  ? 'bg-slate-900 text-white dark:bg-slate-100 dark:text-slate-900'
                  : 'border border-slate-300 dark:border-slate-700'
              }`}
            >
              {t.name}
              <span className="ml-2 font-mono text-xs opacity-70">{t.code}</span>
            </Link>
          ))}
        </div>

        <form method="get" className="mt-4 flex flex-wrap items-end gap-3">
          <input type="hidden" name="to" value={toDangChon?.id ?? ''} />
          <div>
            <label htmlFor="ngay" className="mb-1 block text-sm font-medium">
              Ngày chấm công
            </label>
            <input
              id="ngay"
              name="ngay"
              type="date"
              defaultValue={ngaySoi}
              max={ngayHomNayVN()}
              className="rounded-lg border border-slate-300 px-3 py-2 text-base outline-none focus:border-slate-900 dark:border-slate-700 dark:bg-slate-950"
            />
          </div>
          <button
            type="submit"
            className="rounded-lg border border-slate-300 px-4 py-2 text-sm dark:border-slate-700"
          >
            Xem ngày này
          </button>
        </form>

        {toDangChon && (
          <p className="mt-3 text-sm text-slate-500">
            {toDangChon.companies?.name ?? 'Chưa gán công ty'}
            {toDangChon.departments?.name ? ` · ${toDangChon.departments.name}` : ''}
          </p>
        )}
      </Khoi>

      {toDangChon && (
        <Khoi
          tieuDe={`${toDangChon.name} — ${dinhDangNgay(ngaySoi)}`}
          ghiChu={
            phienNgay?.phien.da_duyet
              ? 'Phiên đã được duyệt. Muốn sửa thì người duyệt phải mở lại.'
              : ghiDuoc
                ? 'Số công lưu được ngay cả khi chưa tải được ảnh — nhưng thiếu ảnh thì không duyệt được.'
                : 'Bạn xem để duyệt. Ghi số công là việc của người được giao chấm công cho tổ này.'
          }
        >
          {cauHinhCa.khung === null || cauHinhCa.ca.length === 0 ? (
            // Chưa khai khung giờ chuẩn hoặc chưa khai ca nào thì lưới chấm
            // công hiện ra vẫn bấm được mà lưu không được. Nói ra thứ còn
            // thiếu, và nói ai khai được nó.
            <div className="rounded-lg bg-amber-50 p-4 text-sm text-amber-900 dark:bg-amber-950 dark:text-amber-200">
              <p className="font-medium">
                Công ty của tổ này chưa khai khung giờ chuẩn và ba ca — chưa chấm công được.
              </p>
              <p className="mt-1">
                Số giờ thường và giờ ngoài giờ suy ra từ hai thứ đó, nên thiếu chúng thì hệ
                thống không biết giờ nào là ngoài giờ. Đề nghị quản trị hệ thống khai tại{' '}
                <strong>Quản trị → Công ty</strong>: giờ vào, giờ ra, nghỉ trưa, và giờ của ca
                sáng / chiều / tối.
              </p>
            </div>
          ) : thanhVien.length === 0 ? (
            <p className="text-sm text-slate-500">
              Tổ này chưa có thành viên nào còn hiệu lực trong ngày {dinhDangNgay(ngaySoi)}. Thêm
              thành viên tại <strong>Quản trị → Tổ đội công nhật</strong>.
            </p>
          ) : phienNgay?.phien.da_duyet || !ghiDuoc ? (
            <div className="space-y-3">
              <ul className="divide-y divide-slate-100 text-sm dark:divide-slate-800">
                {thanhVien.map((t) => {
                  const d = (phienNgay?.dong ?? []).find((x) => x.employee_id === t.employee_id)
                  return (
                    <li key={t.employee_id} className="flex justify-between py-2">
                      <span>{t.employees?.full_name}</span>
                      <span className="font-medium">
                        {/* Dòng chấm khoán ngày trước 24/08/2026 vẫn còn trong
                            bảng, và vẫn phải đọc ra đúng đơn vị của chính nó. */}
                        {d?.so_cong !== null && d?.so_cong !== undefined
                          ? `${soLe(Number(d.so_cong))} công`
                          : `${soLe(Number(d?.so_gio ?? 0))} giờ`}
                        {Number(d?.so_gio_ot ?? 0) > 0 &&
                          ` · ngoài giờ ${soLe(Number(d!.so_gio_ot))}h`}
                      </span>
                    </li>
                  )
                })}
              </ul>
              {phienNgay?.phien.da_duyet ? (
                <p className="text-sm text-slate-500">
                  Duyệt lúc {ngayGio(phienNgay.phien.duyet_luc)}.
                </p>
              ) : (
                <p className="text-sm text-slate-500">
                  {phienNgay
                    ? 'Chưa duyệt. Bấm duyệt ở mục “Phiên chờ duyệt” bên dưới.'
                    : 'Tổ này chưa chấm công ngày đang xem.'}
                </p>
              )}
            </div>
          ) : (
            <LuoiChamCong
              toDoiId={toDangChon.id}
              ngay={ngaySoi}
              daCoAnh={Boolean(phienNgay?.phien.anh_path)}
              caCongTy={cauHinhCa.ca}
              khung={cauHinhCa.khung}
              congDaCo={congDaCo}
              thanhVien={thanhVien.map((t) => ({
                employeeId: t.employee_id,
                ma: t.employees?.employee_code ?? '—',
                ten: t.employees?.full_name ?? '(không đọc được tên)',
              }))}
            />
          )}

          {/* Duyệt ngay tại khối ngày: tổ trưởng chấm xong bấm luôn ở đây,
              không phải đi tìm mục "Phiên chờ duyệt" bên dưới (mà họ cũng
              không thấy nếu chỉ có quyền của người chấm). */}
          {duyetDuocPhienNay && phienNgay && (
            <div className="mt-5 rounded-lg border border-slate-200 p-3 dark:border-slate-800">
              {phienNgay.phien.da_duyet ? (
                <>
                  <p className="mb-2 text-sm">
                    Phiên này đã duyệt lúc {ngayGio(phienNgay.phien.duyet_luc)}. Mở lại nếu cần
                    sửa số công.
                  </p>
                  <FormMoLaiPhien id={phienNgay.phien.id} />
                </>
              ) : (
                <>
                  <p className="mb-2 text-sm">
                    Chấm xong thì bấm duyệt cho cả tổ — duyệt rồi số công khoá lại, không sửa
                    được nữa.
                    {!phienNgay.phien.anh_path && (
                      <strong> Phiên chưa có ảnh xác minh nên chưa duyệt được.</strong>
                    )}
                  </p>
                  <FormDuyetPhien id={phienNgay.phien.id} />
                </>
              )}
            </div>
          )}

          {anhHienTai && (
            <div className="mt-5">
              <p className="mb-2 text-sm font-medium">Ảnh xác minh đã tải lên</p>
              <Image
                src={anhHienTai}
                alt={`Ảnh chấm công tổ ${toDangChon.name} ngày ${ngaySoi}`}
                width={480}
                height={360}
                unoptimized
                className="h-auto w-full max-w-lg rounded-lg"
              />
            </div>
          )}
        </Khoi>
      )}

      {duyetDuoc && (
        <Khoi
          tieuDe={`Phiên chờ duyệt (${choDuyet.length})`}
          ghiChu="Phiên chưa có ảnh xác minh thì không duyệt được — đó là ràng buộc ở database, không phải quy ước của màn hình."
        >
          {choDuyet.length === 0 ? (
            <p className="text-sm text-slate-500">Không còn phiên nào chờ duyệt.</p>
          ) : (
            <ul className="divide-y divide-slate-100 dark:divide-slate-800">
              {choDuyet.map((p) => (
                <li key={p.id} className="flex flex-wrap items-center gap-3 py-3">
                  <div className="min-w-48 flex-1">
                    <p className="text-sm font-medium">
                      {p.to_doi?.name}{' '}
                      <span className="font-mono text-xs text-slate-500">{p.to_doi?.code}</span>
                    </p>
                    <p className="text-xs text-slate-500">
                      {dinhDangNgay(p.work_date)} · {p.so_dong} dòng / {p.so_nguoi} người có
                      công · chấm lúc {ngayGio(p.cham_luc)}
                    </p>
                  </div>
                  {p.anh_path ? (
                    <Link
                      href={`/nhan-su/to-doi?to=${p.to_doi_id}&ngay=${p.work_date}`}
                      className="text-sm underline"
                    >
                      Xem ảnh
                    </Link>
                  ) : (
                    <span className="text-sm text-amber-700 dark:text-amber-400">Thiếu ảnh</span>
                  )}
                  <FormDuyetPhien id={p.id} />
                </li>
              ))}
            </ul>
          )}

          {phienNgay?.phien.da_duyet && (
            <div className="mt-4 border-t border-slate-100 pt-4 dark:border-slate-800">
              <p className="mb-2 text-sm">
                Phiên đang xem đã duyệt. Mở lại nếu người chấm cần sửa.
              </p>
              <FormMoLaiPhien id={phienNgay.phien.id} />
            </div>
          )}
        </Khoi>
      )}
    </KhungTrang>
  )
}
