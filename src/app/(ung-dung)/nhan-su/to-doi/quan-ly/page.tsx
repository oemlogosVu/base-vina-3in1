import Link from 'next/link'
import { redirect } from 'next/navigation'
import { KhungTrang, Khoi } from '@ns/components/khung-trang'
import { batBuocTab, CONG_SUA_NHAN_SU, quaCong } from '@ns/lib/phien'
import { createClient } from '@ns/lib/supabase/server'
import { ngay as dinhDangNgay, ngayHomNayVN, tien } from '@ns/lib/dinh-dang'
import { ROLE_LABELS } from '@ns/types/database'
import {
  layChucDanhCongNhat,
  duocVaoQuanLyToDoi,
  layMoiNguoiCham,
  layUngVienQuanLyTo,
  layTaiKhoanQuanLyToDoi,
} from '@ns/lib/to-doi'
import {
  FormChucDanhCongNhat,
  FormDatToTruong,
  FormGiaoNguoiCham,
  FormGoNguoiCham,
  FormNgayThanhVien,
  FormQuyenQuanLyToDoi,
  FormSuaNhanCong,
  FormSuaToDoi,
  FormTaoToDoi,
  FormTaoToDoiCuaToi,
  FormThemNhanCong,
  FormThemThanhVien,
  type ChonRut,
  type ToDoiDayDu,
} from './bieu-mau'
import { DieuHuongToDoi } from '../dieu-huong'

/**
 * Quản trị tổ đội công nhật.
 *
 * Từ 29/08/2026 màn này mở cho BỐN loại người, và cửa vào được viết cho khớp
 * đúng những gì RLS đã cho họ làm:
 *   - admin: thấy mọi tổ, đặt quyền, khai đơn giá theo chức danh;
 *   - người mang quyền `quan_ly_nhan_su` (↔ `is_hr_or_admin()`): cũng thấy và
 *     sửa được mọi tổ, chỉ không thấy hai khối thiết lập của admin. Trước bản
 *     này họ THẤY đường dẫn ở thanh điều hướng nhưng bấm vào là bị đá về —
 *     database mở, giao diện đóng, đúng cái bẫy `phien.ts` tự cảnh báo;
 *   - người quản lý tổ đội (cờ `quan_ly_to_doi`): thấy tổ mình phụ trách và tự
 *     lập tổ mới;
 *   - NGƯỜI CHẤM của ít nhất một tổ: thấy và sửa tổ mình, kể cả khi chưa được
 *     bật cờ lập tổ. Họ vẫn chấm công cho tổ ấy hằng ngày, nên không có lý gì
 *     bắt họ đi nhờ quản trị để sửa một cái đơn giá — và policy
 *     `to_doi_update_nguoi_cham` với `tdtv_update_nguoi_cham` đã cho phép.
 *
 * Đây vẫn là màn ĐIỀU HƯỚNG. Thứ quyết định họ đọc/ghi được gì là RLS và các
 * hàm `security definer` ở database — kể cả khi ai đó gõ thẳng URL. Cửa vào ở
 * đây chỉ để người không có việc gì làm ở màn này không phải nhìn một trang
 * trống.
 */
export default async function TrangQuanTriToDoi() {
  // Từ 24/08/2026 màn này nằm TRONG tab Quản lý tổ đội, không còn dưới Quản
  // trị. Chặn theo tab trước, rồi mới hỏi cửa riêng của màn — đẩy người không
  // có việc gì ở đây về đúng màn chấm công của tab họ đang đứng, thay vì hất
  // họ ra tận /ho-so.
  const phien = await batBuocTab('to-doi')
  const laAdmin = phien.role === 'admin'
  // Khớp với `is_hr_or_admin()` — cổng mà RLS dùng cho mọi lệnh ghi trên tổ.
  const laNhanSu = quaCong(phien, CONG_SUA_NHAN_SU)
  // Chỉ người này mới lập được tổ mới: hàm `tao_to_doi()` đòi
  // `la_quan_ly_to_doi()`, và nó còn kiểm thêm điều kiện nhân viên chính thức.
  const lapToDuoc = laAdmin || phien.quanLyToDoi
  // Đọc được DANH SÁCH nhân sự toàn công ty, nên xếp được một hồ sơ đã có vào
  // tổ. Người chấm chỉ đọc được hồ sơ của người trong tổ mình, nên với họ ô
  // chọn ấy luôn rỗng — hiện ra chỉ làm rối.
  const thayMoiTo = laAdmin || laNhanSu

  if (!(await duocVaoQuanLyToDoi(phien))) redirect('/nhan-su/to-doi')

  const supabase = await createClient()
  const homNay = ngayHomNayVN()

  const [toDoi, congTy, phongBan, taiKhoan, nhanSu, thanhVien, nguoiCham, chucDanh] =
    await Promise.all([
      supabase.from('to_doi').select('*').order('code'),
      supabase.from('companies').select('id, code, name').eq('is_active', true).order('code'),
      supabase.from('departments').select('id, code, name').eq('is_active', true).order('code'),
      layUngVienQuanLyTo(),
      supabase
        .from('employees')
        .select('id, employee_code, full_name')
        .is('deleted_at', null)
        .order('employee_code'),
      supabase
        .from('to_doi_thanh_vien')
        .select(
          'id, to_doi_id, employee_id, tu_ngay, den_ngay, don_gia_cong, don_gia_gio, don_gia_ot, kieu_tinh, employees ( employee_code, full_name )',
        )
        .order('tu_ngay'),
      layMoiNguoiCham(),
      supabase.from('positions').select('id, code, name').eq('is_active', true).order('code'),
    ])

  if (toDoi.error) throw new Error(`Không đọc được tổ đội: ${toDoi.error.message}`)

  // RLS đã lọc: người quản lý chỉ đọc được tổ mình phụ trách. Câu này không
  // phải lớp chặn, chỉ để trang không hiện khối rỗng cho họ.
  const ds = (toDoi.data ?? []) as ToDoiDayDu[]
  const dsThanhVien = thanhVien.data ?? []

  const [chucDanhCongNhat, dangQuanLy] = await Promise.all([
    layChucDanhCongNhat(),
    laAdmin ? layTaiKhoanQuanLyToDoi() : Promise.resolve(new Set<string>()),
  ])

  const chonCongTy: ChonRut[] = (congTy.data ?? []).map((c) => ({
    id: c.id,
    nhan: `${c.name} (${c.code})`,
  }))
  const chonPhongBan: ChonRut[] = (phongBan.data ?? []).map((d) => ({
    id: d.id,
    nhan: `${d.name} (${d.code})`,
  }))
  const duDieuKien = taiKhoan.filter((u) => u.duDieuKien)
  const chuaDu = taiKhoan.filter((u) => !u.duDieuKien)

  const chonTaiKhoan: ChonRut[] = duDieuKien.map((u) => ({
    id: u.id,
    nhan: `${u.full_name} — ${ROLE_LABELS[u.role as keyof typeof ROLE_LABELS]}`,
  }))
  const chonNhanSu: ChonRut[] = (nhanSu.data ?? []).map((e) => ({
    id: e.id,
    nhan: `${e.full_name} (${e.employee_code})`,
  }))
  const chonChucDanh: ChonRut[] = (chucDanh.data ?? []).map((c) => ({
    id: c.id,
    nhan: `${c.name} (${c.code})`,
  }))

  const dangCoTo = new Set(dsThanhVien.filter((t) => t.den_ngay === null).map((t) => t.employee_id))
  const chonNhanSuRanh = chonNhanSu.filter((n) => !dangCoTo.has(n.id))

  const coNguoiCham = new Set(nguoiCham.map((g) => g.to_doi_id))
  const chuaGiaoNguoiCham = ds.filter((t) => t.is_active && !coNguoiCham.has(t.id))

  return (
    <KhungTrang phien={phien} tieuDe="Quản lý tổ đội">
      <DieuHuongToDoi dang="quan-ly" quanLyDuoc />
      <Khoi
        tieuDe="Tổ đội thuê công nhật là gì trong hệ thống này"
        ghiChu="Đọc trước khi lập tổ — nó khác hẳn phòng ban."
      >
        <div className="space-y-3 text-sm">
          <p>
            Tổ gom những người làm <strong>công nhật</strong>: không hợp đồng lao động, không
            đóng bảo hiểm. Họ <strong>không nằm trong bảng lương</strong> — tiền trả qua bảng
            thanh toán riêng của tổ.
          </p>
          <p>
            Người công nhật không có tài khoản đăng nhập và không tự chấm công.{' '}
            <strong>Người quản lý tổ</strong> chấm hộ cả tổ mỗi ngày kèm một ảnh xác minh, rồi
            nhân sự duyệt.
          </p>
          <p>
            Mỗi người trong tổ tính lương <strong>theo ngày công</strong> hoặc{' '}
            <strong>theo giờ</strong>, và ai cũng có thể có <strong>giờ ngoài giờ</strong>.
          </p>
          <p>
            Một người chỉ ở được <strong>một tổ đang mở</strong> — ở hai tổ là ngày công bị đếm
            hai lần, và database chặn việc đó.
          </p>
        </div>
      </Khoi>

      {laAdmin && chuaGiaoNguoiCham.length > 0 && (
        <div className="mb-6 rounded-xl bg-amber-50 p-4 text-sm text-amber-900 dark:bg-amber-950 dark:text-amber-200">
          <p className="font-medium">{chuaGiaoNguoiCham.length} tổ chưa giao người chấm công</p>
          <p className="mt-1">
            {chuaGiaoNguoiCham.map((t) => t.name).join(', ')} — chưa giao thì không ai chấm được
            cho tổ đó ngoài nhân sự và quản trị. Người được giao phải là nhân viên chính thức,
            có hợp đồng đang hiệu lực và đóng bảo hiểm.
          </p>
        </div>
      )}

      {laAdmin && (
        <Khoi
          tieuDe="Chức danh dùng cho nhân công công nhật"
          ghiChu="Biểu mẫu thêm nhân công gán sẵn chức danh này. Chưa chọn thì chưa thêm được ai."
        >
          <FormChucDanhCongNhat
            chucDanh={chonChucDanh}
            dangChon={chucDanhCongNhat?.id ?? null}
          />
        </Khoi>
      )}

      {laAdmin && (
        <Khoi
          tieuDe="Người quản lý tổ đội"
          ghiChu="Bật một lần; từ đó người ấy tự lập tổ ngoài công trường và tự thêm nhân công, không phải hỏi quản trị từng lần. Khác với “người quản lý chấm công” giao riêng cho từng tổ ở danh sách bên dưới."
        >
          {duDieuKien.length === 0 ? (
            <p className="mb-4 text-sm text-slate-500">
              Chưa tài khoản nào đủ điều kiện.
            </p>
          ) : (
            <div className="divide-y divide-slate-100 dark:divide-slate-800">
              {duDieuKien.map((u) => (
                <FormQuyenQuanLyToDoi
                  key={u.id}
                  appUserId={u.id}
                  ten={`${u.full_name} — ${ROLE_LABELS[u.role as keyof typeof ROLE_LABELS]}`}
                  dangBat={dangQuanLy.has(u.id)}
                />
              ))}
            </div>
          )}

          {/*
            Người CHƯA đủ điều kiện vẫn hiện ra, kèm câu thiếu gì.

            Bản trước chỉ lọc lấy người đủ điều kiện, nên khi chưa ai đủ thì
            khối này rỗng và trông y hệt một tính năng chưa làm — đúng cách nó
            bị hiểu nhầm ngày 22/08. Một danh sách rỗng phải nói được vì sao
            nó rỗng, và nói ở ngay chỗ người dùng đang đứng.
          */}
          {chuaDu.length > 0 && (
            <div className="mt-5 rounded-lg bg-slate-50 p-4 dark:bg-slate-900">
              <p className="mb-1 text-sm font-medium">
                {chuaDu.length} tài khoản chưa đủ điều kiện
              </p>
              <p className="mb-3 text-xs text-slate-500">
                Điều kiện: nhân viên <strong>chính thức</strong>, có hợp đồng lao động đang
                hiệu lực và <strong>đóng bảo hiểm</strong>, và tài khoản phải được nối với hồ
                sơ nhân sự. Đây là ràng buộc ở database, không phải quy ước màn hình — người
                chấm công phải là người công ty chịu trách nhiệm được.
              </p>
              <ul className="space-y-1 text-sm">
                {chuaDu.map((u) => (
                  <li key={u.id} className="text-slate-500">
                    {u.full_name} — <em>{u.thieu}</em>
                  </li>
                ))}
              </ul>
              <p className="mt-3 text-xs text-slate-500">
                Nối tài khoản với hồ sơ nhân sự tại{' '}
                <Link href="/nhan-su/quan-tri/nguoi-dung" className="underline">
                  Quản trị → Người dùng
                </Link>
                . Hợp đồng và mức đóng bảo hiểm khai trong hồ sơ của từng người.
              </p>
            </div>
          )}
        </Khoi>
      )}

      {/*
        Chỉ hiện cho người thật sự lập được tổ. Người chấm chưa được bật cờ
        `quan_ly_to_doi` mà nhìn thấy biểu mẫu này thì điền xong sẽ ăn nguyên
        câu từ chối của `tao_to_doi()` — hiện một việc rồi từ chối làm nó là
        cách tệ hơn không hiện.
      */}
      {lapToDuoc && (
        <Khoi tieuDe={laAdmin ? 'Tạo tổ mới' : 'Lập tổ mới'}>
          {laAdmin ? (
            <FormTaoToDoi congTy={chonCongTy} phongBan={chonPhongBan} />
          ) : (
            <FormTaoToDoiCuaToi phongBan={chonPhongBan} />
          )}
        </Khoi>
      )}

      <Khoi tieuDe={`${thayMoiTo ? 'Danh sách tổ' : 'Tổ bạn phụ trách'} (${ds.length})`}>
        {ds.length === 0 ? (
          <p className="text-sm text-slate-500">
            {thayMoiTo
              ? 'Chưa có tổ nào.'
              : lapToDuoc
                ? 'Bạn chưa phụ trách tổ nào. Lập tổ ở khối phía trên.'
                : 'Bạn chưa phụ trách tổ nào. Đề nghị quản trị hệ thống giao bạn làm người chấm công của một tổ tại màn này.'}
          </p>
        ) : (
          <ul className="space-y-8">
            {ds.map((t) => {
              const cua = dsThanhVien.filter((tv) => tv.to_doi_id === t.id)
              const dangLam = cua.filter((tv) => tv.den_ngay === null)
              const daRoi = cua.filter((tv) => tv.den_ngay !== null)
              const cuaTo = nguoiCham.filter((g) => g.to_doi_id === t.id)

              return (
                <li
                  key={t.id}
                  className="border-t border-slate-100 pt-8 first:border-0 first:pt-0 dark:border-slate-800"
                >
                  <p className="mb-3 font-mono text-xs text-slate-500">{t.code}</p>

                  <FormSuaToDoi to={t} phongBan={chonPhongBan} />

                  {laAdmin && (
                    <div className="mt-5 rounded-lg bg-slate-50 p-4 dark:bg-slate-900">
                      <p className="mb-3 text-sm font-medium">
                        Người quản lý chấm công ({cuaTo.length})
                      </p>

                      {cuaTo.length === 0 ? (
                        <p className="mb-3 text-sm text-slate-500">
                          Chưa giao cho ai. Chưa giao thì không ai chấm được cho tổ này ngoài
                          nhân sự và quản trị.
                        </p>
                      ) : (
                        <ul className="mb-4 divide-y divide-slate-200 dark:divide-slate-800">
                          {cuaTo.map((g) => (
                            <li
                              key={g.id}
                              className="flex flex-wrap items-center justify-between gap-3 py-2"
                            >
                              <span className="text-sm">{g.app_users?.full_name}</span>
                              <FormGoNguoiCham id={g.id} />
                            </li>
                          ))}
                        </ul>
                      )}

                      <FormGiaoNguoiCham toDoiId={t.id} taiKhoan={chonTaiKhoan} />

                      {chonTaiKhoan.length === 0 && chuaDu.length > 0 && (
                        <ul className="mt-2 space-y-1 text-xs text-slate-500">
                          {chuaDu.map((u) => (
                            <li key={u.id}>
                              {u.full_name} — <em>{u.thieu}</em>
                            </li>
                          ))}
                        </ul>
                      )}
                    </div>
                  )}

                  <div className="mt-5 rounded-lg bg-slate-50 p-4 dark:bg-slate-900">
                    <p className="mb-3 text-sm font-medium">
                      Nhân công trong tổ ({dangLam.length})
                    </p>

                    {dangLam.length > 0 && t.to_truong_id === null && (
                      <p className="mb-3 text-xs text-slate-500">
                        Tổ chưa có tổ trưởng. Chọn một người trong danh sách dưới đây —
                        tổ trưởng là người trong tổ, không cần là nhân viên công ty.
                      </p>
                    )}

                    {dangLam.length === 0 ? (
                      <p className="mb-3 text-sm text-slate-500">
                        Chưa có ai. Tổ rỗng thì màn chấm công không hiện người nào.
                      </p>
                    ) : (
                      <ul className="mb-4 space-y-3">
                        {dangLam.map((tv) => (
                          <li
                            key={tv.id}
                            className="border-b border-slate-200 pb-3 last:border-0 dark:border-slate-800"
                          >
                            <div className="mb-2 flex flex-wrap items-center justify-between gap-3">
                              <span className="text-sm">
                                {tv.employees?.full_name}{' '}
                                <span className="font-mono text-xs text-slate-500">
                                  {tv.employees?.employee_code}
                                </span>
                                <span className="ml-2 text-xs text-slate-500">
                                  {tv.don_gia_gio !== null
                                    ? ` · ${tien(tv.don_gia_gio)}/giờ`
                                    : ' · CHƯA CÓ đơn giá giờ'}
                                  {tv.don_gia_ot !== null
                                    ? ` · ngoài giờ ${tien(tv.don_gia_ot)}/giờ`
                                    : ' · chưa thoả thuận giá ngoài giờ'}
                                  {/* Dòng khoán ngày cũ: nói ra mức cũ để người
                                      khai đơn giá giờ có cái mà đối chiếu. */}
                                  {tv.kieu_tinh === 'ngay' &&
                                    tv.don_gia_cong !== null &&
                                    ` · (cũ: khoán ngày ${tien(tv.don_gia_cong)}/công)`}
                                </span>
                                {t.to_truong_id === tv.employee_id && (
                                  <span className="ml-2 rounded bg-amber-100 px-2 py-0.5 text-xs text-amber-900 dark:bg-amber-950 dark:text-amber-200">
                                    Tổ trưởng
                                  </span>
                                )}
                              </span>
                              <div className="flex flex-wrap items-center gap-2">
                                <FormDatToTruong
                                  toDoiId={t.id}
                                  employeeId={tv.employee_id}
                                  dangLa={t.to_truong_id === tv.employee_id}
                                />
                                <FormNgayThanhVien
                                  id={tv.id}
                                  tuNgay={tv.tu_ngay}
                                  denNgay={tv.den_ngay}
                                />
                              </div>
                            </div>
                            <FormSuaNhanCong
                              thanhVienId={tv.id}
                              hoTen={tv.employees?.full_name ?? ''}
                              donGia={tv.don_gia_gio === null ? null : Number(tv.don_gia_gio)}
                              donGiaOt={tv.don_gia_ot === null ? null : Number(tv.don_gia_ot)}
                            />
                          </li>
                        ))}
                      </ul>
                    )}

                    <div className="border-t border-slate-200 pt-4 dark:border-slate-800">
                      <p className="mb-3 text-sm font-medium">Thêm nhân công mới</p>
                      <FormThemNhanCong
                        toDoiId={t.id}
                        homNay={homNay}
                        coChucDanh={chucDanhCongNhat !== null}
                      />
                    </div>

                    {thayMoiTo && (
                      <div className="mt-4 border-t border-slate-200 pt-4 dark:border-slate-800">
                        <p className="mb-2 text-sm text-slate-500">
                          Hoặc xếp một hồ sơ nhân sự đã có vào tổ:
                        </p>
                        <FormThemThanhVien
                          toDoiId={t.id}
                          nhanSu={chonNhanSuRanh}
                          homNay={homNay}
                        />
                      </div>
                    )}

                    {daRoi.length > 0 && (
                      <details className="mt-4">
                        <summary className="cursor-pointer text-sm text-slate-500">
                          Đã rời tổ ({daRoi.length})
                        </summary>
                        {/*
                          Sửa được cả hai ngày ngay tại đây. Cho rời nhầm ngày —
                          hoặc nhầm người — mà không có đường sửa thì công của
                          những hôm ở giữa biến mất, và không ai thấy nó biến đi
                          lúc nào. Bỏ trống ô ngày rời là đưa họ lại vào tổ.
                        */}
                        <ul className="mt-2 space-y-3 text-sm text-slate-500">
                          {daRoi.map((tv) => (
                            <li key={tv.id}>
                              <span className="mb-1 block">
                                {tv.employees?.full_name} — {dinhDangNgay(tv.tu_ngay)} đến{' '}
                                {dinhDangNgay(tv.den_ngay)}
                              </span>
                              <FormNgayThanhVien
                                id={tv.id}
                                tuNgay={tv.tu_ngay}
                                denNgay={tv.den_ngay}
                              />
                            </li>
                          ))}
                        </ul>
                      </details>
                    )}
                  </div>
                </li>
              )
            })}
          </ul>
        )}
      </Khoi>
    </KhungTrang>
  )
}
