import Link from 'next/link'
import { KhungTrang, Khoi, Pill } from '@ns/components/khung-trang'
import { batBuocTab } from '@ns/lib/phien'
import { createClient } from '@ns/lib/supabase/server'
import {
  layBangLuongCuaKy,
  layKyLuong,
  layThamSoLuong,
  layTienDoXacNhan,
} from '@ns/lib/luong'
import { tien } from '@ns/lib/dinh-dang'
import { PERIOD_STATUS_LABELS } from '@ns/types/database'
import { OChungTu } from '@ns/components/o-chung-tu'
import { sacKyLuong, sacXacNhan } from '@ns/lib/sac-trang-thai'
import { duongTaiChungTu, layChungTuTheoDoiTuong } from '@ns/lib/chung-tu'
import { FormChotKy, FormDaTra, FormTaoKy, FormTinhLuong } from './bieu-mau'

const NHAN_XAC_NHAN: Record<string, string> = {
  cho_xac_nhan: 'Chưa xác nhận',
  da_xac_nhan: 'Đã xác nhận',
  thac_mac: 'Đang thắc mắc',
}

// Nhãn dùng chung với màn Báo cáo lương — giữ ở @/types/database cạnh các
// bảng nhãn khác. Bản sao thứ hai sẽ lệch ngay lần đầu ai đó đổi chữ.
const NHAN_TRANG_THAI = PERIOD_STATUS_LABELS

export default async function TrangKyLuong({
  searchParams,
}: {
  searchParams: Promise<{ ky?: string }>
}) {
  const phien = await batBuocTab('luong-ky-luong')
  const { ky: kyDangXem } = await searchParams

  const supabase = await createClient()
  const [dsKy, thamSo, { data: congTy }] = await Promise.all([
    layKyLuong(),
    layThamSoLuong(),
    supabase
      .from('companies')
      .select('id, name, standard_days')
      .eq('is_active', true)
      .order('code'),
  ])
  const tenCongTy = new Map((congTy ?? []).map((c) => [c.id, c.name]))
  const bangLuong = kyDangXem ? await layBangLuongCuaKy(kyDangXem) : []

  // Chứng từ chỉ có nghĩa với kỳ ĐÃ CHỐT — kỳ đang mở còn tính lại được, và
  // một tờ giấy nói con số đã xong trong khi nó chưa xong là tệ hơn không có.
  const kyDaChot = dsKy.filter((k) => k.status !== 'mo')
  const chungTuTheoKy = await layChungTuTheoDoiTuong('ky_luong', kyDaChot.map((k) => k.id))
  const duongTaiKy = new Map<string, string | null>()
  for (const ct of chungTuTheoKy.values()) {
    duongTaiKy.set(ct.doi_tuong_id, await duongTaiChungTu(ct.duong_dan))
  }
  const kyHienTai = dsKy.find((k) => k.id === kyDangXem)

  // Tiến độ xác nhận chỉ có nghĩa sau khi đã chốt — trước đó chưa gửi cho ai.
  const tienDo =
    kyHienTai && kyHienTai.status !== 'mo' ? await layTienDoXacNhan(kyHienTai.id) : []
  const daXacNhan = tienDo.filter((d) => d.trang_thai === 'da_xac_nhan').length
  const thacMac = tienDo.filter((d) => d.trang_thai === 'thac_mac')
  const conThieu = tienDo.length - daXacNhan

  const thieu: string[] = []
  if (thamSo.bacThue.length === 0) thieu.push('biểu thuế TNCN')
  if (thamSo.giamTru.length === 0) thieu.push('mức giảm trừ gia cảnh')
  if (thamSo.baoHiem.length === 0) thieu.push('tỷ lệ bảo hiểm')
  if (thamSo.luongCoSo.length === 0) thieu.push('lương cơ sở')
  if (thamSo.luongToiThieu.length === 0) thieu.push('lương tối thiểu vùng')
  if ((congTy ?? []).length === 0) thieu.push('công ty')

  const homNay = new Date()

  return (
    <KhungTrang phien={phien} tieuDe="Kỳ lương">
      {thieu.length > 0 && (
        <div className="mb-6 rounded-xl bg-amber-50 p-4 text-sm text-amber-900 dark:bg-amber-950 dark:text-amber-200">
          <p className="font-medium">Chưa nhập đủ tham số tính lương.</p>
          <p className="mt-1">
            Còn thiếu: {thieu.join(', ')}. Hệ thống sẽ <strong>từ chối tính lương</strong> chứ
            không tính ra số 0 — vì con số 0 là thứ dễ lọt qua mắt người duyệt nhất.
          </p>
          {phien.role === 'admin' ? (
            <p className="mt-2">
              <Link href="/nhan-su/quan-tri/tham-so-luong" className="underline">
                Nhập tham số tại đây
              </Link>
            </p>
          ) : (
            <p className="mt-2">Nhờ quản trị viên nhập ở màn Tham số lương.</p>
          )}
        </div>
      )}

      <Khoi
        tieuDe="Tạo kỳ lương"
        ghiChu="Công tiêu chuẩn là mẫu số cố định của công ty: lương ngày = lương tháng ÷ công tiêu chuẩn, rồi nhân số ngày thực tế đi làm. Ô này tự điền theo công ty được chọn; sửa ở đây chỉ đổi riêng kỳ này."
      >
        <FormTaoKy
          thangMacDinh={homNay.getMonth() + 1}
          namMacDinh={homNay.getFullYear()}
          congTy={congTy ?? []}
        />
      </Khoi>

      <Khoi tieuDe={`Các kỳ lương (${dsKy.length})`}>
        {dsKy.length === 0 ? (
          <p className="text-sm text-slate-500">Chưa có kỳ lương nào.</p>
        ) : (
          <ul className="space-y-4">
            {dsKy.map((k) => (
              <li
                key={k.id}
                className="flex flex-wrap items-start gap-x-6 gap-y-3 border-t border-slate-100 pt-4 first:border-0 first:pt-0 dark:border-slate-800"
              >
                <div className="min-w-40">
                  <p className="font-medium">
                    Kỳ {k.month}/{k.year}
                  </p>
                  <p className="text-sm">{tenCongTy.get(k.company_id) ?? '— công ty đã ngừng —'}</p>
                  <p className="mt-1">
                    <Pill sac={sacKyLuong(k.status)}>{NHAN_TRANG_THAI[k.status]}</Pill>{' '}
                    <span className="nhan-phu">công tiêu chuẩn {k.standard_days}</span>
                  </p>
                  <Link
                    href={`/nhan-su/luong/ky-luong?ky=${k.id}`}
                    className="text-sm underline"
                  >
                    Xem bảng lương
                  </Link>
                  {k.status !== 'mo' && (
                    <div className="mt-1">
                      <OChungTu
                        loai="ky_luong"
                        doiTuongId={k.id}
                        soHieu={chungTuTheoKy.get(k.id)?.so_hieu}
                        duongTai={duongTaiKy.get(k.id)}
                      />
                    </div>
                  )}
                </div>

                {k.status === 'mo' ? (
                  <>
                    <div className="min-w-48">
                      <FormTinhLuong periodId={k.id} />
                    </div>
                    <div className="min-w-48">
                      <FormChotKy periodId={k.id} />
                    </div>
                  </>
                ) : k.status === 'da_chot' ? (
                  <div className="min-w-48">
                    <FormDaTra
                      periodId={k.id}
                      conThieu={k.id === kyDangXem ? conThieu : 0}
                    />
                  </div>
                ) : (
                  <p className="text-sm text-slate-500">
                    Đã trả — mọi người lao động đã xác nhận phiếu của mình.
                  </p>
                )}
              </li>
            ))}
          </ul>
        )}
      </Khoi>

      {kyHienTai && tienDo.length > 0 && (
        <Khoi
          tieuDe={`Xác nhận của người lao động — ${daXacNhan}/${tienDo.length} người`}
          ghiChu="Phiếu lương chỉ hợp lệ khi chính người lao động bấm xác nhận. Kỳ này chưa đánh dấu trả được khi còn người chưa bấm."
        >
          {thacMac.length > 0 && (
            <div className="mb-4 rounded-xl bg-amber-50 p-4 text-sm dark:bg-amber-950">
              <p className="font-medium">
                {thacMac.length} người đang thắc mắc — xử lý trước khi đánh dấu đã trả
              </p>
              <ul className="mt-2 space-y-2">
                {thacMac.map((d) => (
                  <li key={d.employee_code}>
                    <span className="font-medium">{d.full_name}</span>{' '}
                    <span className="text-slate-500">{d.employee_code}</span>
                    <p className="whitespace-pre-wrap">{d.ly_do}</p>
                  </li>
                ))}
              </ul>
              <p className="mt-3 text-slate-600 dark:text-slate-400">
                Thắc mắc <strong>không bao giờ</strong> bị tự động xác nhận khi quá hạn. Giải
                thích xong thì chính người đó bấm xác nhận, hoặc mở kỳ điều chỉnh nếu số sai
                thật.
              </p>
            </div>
          )}

          <div className="overflow-x-auto">
            <table className="bang">
              <thead>
                <tr>
                  <th>Nhân viên</th>
                  <th>Trạng thái</th>
                  <th>Ghi nhận lúc</th>
                </tr>
              </thead>
              <tbody>
                {tienDo.map((d) => (
                  <tr key={d.employee_code}>
                    <td>
                      {d.full_name}{' '}
                      <span className="nhan-phu">{d.employee_code}</span>
                    </td>
                    <td data-nhan="Trạng thái">
                      <Pill sac={sacXacNhan(d.trang_thai)}>
                        {NHAN_XAC_NHAN[d.trang_thai] ?? d.trang_thai}
                      </Pill>
                      {d.tu_dong && (
                        <span className="nhan-phu ml-2">
                          tự động do quá hạn, không phải người bấm
                        </span>
                      )}
                    </td>
                    <td data-nhan="Ghi nhận lúc" className="nhan-phu">
                      {d.xac_nhan_luc ? new Date(d.xac_nhan_luc).toLocaleString('vi-VN') : '—'}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Khoi>
      )}

      {kyHienTai && (
        <Khoi
          tieuDe={`Bảng lương ${tenCongTy.get(kyHienTai.company_id) ?? ''} — kỳ ${kyHienTai.month}/${kyHienTai.year} (${bangLuong.length} người)`}
        >
          {bangLuong.length === 0 ? (
            <p className="text-sm text-slate-500">
              Kỳ này chưa được tính. Bấm “Tính lương kỳ này” ở trên.
            </p>
          ) : (
            <div className="overflow-x-auto">
              <table className="bang">
                <thead>
                  <tr>
                    <th>Nhân viên</th>
                    <th className="phai">Công</th>
                    <th className="phai">Tổng thu nhập</th>
                    <th className="phai">BH nhân viên</th>
                    <th className="phai">Thuế TNCN</th>
                    <th className="phai">Thực nhận</th>
                    <th className="phai">BH công ty đóng</th>
                  </tr>
                </thead>
                <tbody>
                  {bangLuong.map((p) => (
                    <tr key={p.id}>
                      <td>
                        {p.employees?.full_name}{' '}
                        <span className="nhan-phu">{p.employees?.employee_code}</span>
                      </td>
                      <td data-nhan="Công" className="phai">
                        {p.worked_days}
                      </td>
                      <td data-nhan="Tổng thu nhập" className="phai">
                        {tien(p.gross_salary)}
                      </td>
                      <td data-nhan="BH nhân viên" className="phai">
                        {tien(p.bhxh_employee + p.bhyt_employee + p.bhtn_employee)}
                      </td>
                      <td data-nhan="Thuế TNCN" className="phai">
                        {tien(p.pit)}
                      </td>
                      <td data-nhan="Thực nhận" className="phai font-semibold">
                        {tien(p.net_salary)}
                      </td>
                      <td data-nhan="BH công ty đóng" className="phai nhan-phu">
                        {tien(p.bhxh_employer + p.bhyt_employer + p.bhtn_employer)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </Khoi>
      )}
    </KhungTrang>
  )
}
