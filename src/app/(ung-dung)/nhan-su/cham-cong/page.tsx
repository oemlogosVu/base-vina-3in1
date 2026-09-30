import { KhungTrang, Khoi, Pill } from '@ns/components/khung-trang'
import { sacNgayCong } from '@ns/lib/sac-trang-thai'
import { batBuocTab } from '@ns/lib/phien'
import { coPhaiChamCong, layBangCongCuaToi, layLogCuaToi } from '@ns/lib/cham-cong'
import { gio, ngay, ngayGio, phutThanhGio } from '@ns/lib/dinh-dang'
import { ATTENDANCE_DAY_STATUS_LABELS, CHECK_TYPE_LABELS } from '@ns/types/database'
import { NutChamCong } from './nut-cham-cong'

export default async function TrangChamCong() {
  const phien = await batBuocTab('cham-cong')

  if (!phien.employeeId) {
    return (
      <KhungTrang phien={phien} tieuDe="Chấm công">
        <Khoi tieuDe="Chưa gắn hồ sơ nhân sự">
          <p className="text-sm">
            Tài khoản của bạn chưa được nối với hồ sơ nhân sự nên chưa chấm công được.
            Liên hệ bộ phận nhân sự để được gắn hồ sơ.
          </p>
        </Khoi>
      </KhungTrang>
    )
  }

  const [phaiChamCong, logs, bangCong] = await Promise.all([
    coPhaiChamCong(phien.employeeId),
    layLogCuaToi(10),
    layBangCongCuaToi(7),
  ])

  // Người được miễn chấm công vẫn vào được màn này qua menu, nên nói rõ thay
  // vì hiện nút bấm rồi để họ nhận lỗi khó hiểu.
  if (!phaiChamCong) {
    return (
      <KhungTrang phien={phien} tieuDe="Chấm công">
        <Khoi tieuDe="Công việc của bạn không áp dụng chấm công">
          <p className="text-sm">
            Do đặc thù công việc, bạn không phải chấm công. Bảng lương tính theo{' '}
            <strong>đủ ngày công chuẩn</strong> của kỳ, không phụ thuộc số lần bấm.
          </p>
          <p className="mt-2 text-sm text-slate-500">
            Nếu bạn cho rằng đây là nhầm lẫn, liên hệ bộ phận nhân sự.
          </p>
        </Khoi>
      </KhungTrang>
    )
  }

  return (
    <KhungTrang phien={phien} tieuDe="Chấm công">
      <Khoi
        tieuDe="Chấm công hôm nay"
        ghiChu="Giờ chấm công lấy từ máy chủ, không lấy giờ điện thoại. Lần chấm chỉ được tính công sau khi nhân sự xác nhận."
      >
        <NutChamCong />
      </Khoi>

      <Khoi tieuDe="Bảng công 7 ngày gần nhất" ghiChu="Chỉ tính những lần chấm đã được xác nhận.">
        {bangCong.length === 0 ? (
          <p className="text-sm text-slate-500">Chưa có ngày công nào được tổng hợp.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="bang">
              <thead>
                <tr>
                  <th>Ngày</th>
                  <th>Vào</th>
                  <th>Ra</th>
                  <th>Giờ làm</th>
                  <th>Muộn</th>
                  <th>Ngoài giờ</th>
                  <th>Trạng thái</th>
                </tr>
              </thead>
              <tbody>
                {bangCong.map((d) => (
                  <tr key={d.id}>
                    <td className="whitespace-nowrap">{ngay(d.work_date)}</td>
                    <td data-nhan="Vào">{gio(d.first_in)}</td>
                    <td data-nhan="Ra">{gio(d.last_out)}</td>
                    <td data-nhan="Giờ làm">{phutThanhGio(d.worked_minutes)}</td>
                    <td data-nhan="Muộn">
                      {d.late_minutes > 0 ? phutThanhGio(d.late_minutes) : '—'}
                    </td>
                    <td data-nhan="Ngoài giờ">
                      {d.ot_minutes > 0 ? (
                        <>
                          {phutThanhGio(d.ot_minutes)}
                          <span className="nhan-phu block">
                            {gio(d.ot_first_in)}–{gio(d.ot_last_out)}
                          </span>
                        </>
                      ) : (
                        '—'
                      )}
                    </td>
                    <td data-nhan="Trạng thái">
                      <Pill sac={sacNgayCong(d.status)}>
                        {ATTENDANCE_DAY_STATUS_LABELS[d.status]}
                      </Pill>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Khoi>

      <Khoi tieuDe="10 lần chấm gần nhất">
        {logs.length === 0 ? (
          <p className="text-sm text-slate-500">Chưa có lần chấm công nào.</p>
        ) : (
          <ul className="space-y-2 text-sm">
            {logs.map((l) => (
              <li
                key={l.id}
                className="flex flex-wrap items-baseline gap-x-3 gap-y-1 border-t border-slate-100 pt-2 first:border-0 first:pt-0 dark:border-slate-800"
              >
                <span className="font-medium">{CHECK_TYPE_LABELS[l.check_type]}</span>
                <span>{ngayGio(l.logged_at)}</span>
                {l.selfie_path && <span className="text-slate-500">có ảnh</span>}
                {l.da_xac_nhan ? (
                  <span className="text-emerald-700 dark:text-emerald-400">Đã xác nhận</span>
                ) : l.xac_nhan_luc ? (
                  <span className="text-rose-700 dark:text-rose-400">Không được công nhận</span>
                ) : (
                  <span className="text-amber-700 dark:text-amber-400">Chờ nhân sự xác nhận</span>
                )}
                {l.ghi_chu_xac_nhan && (
                  <span className="w-full text-slate-500">{l.ghi_chu_xac_nhan}</span>
                )}
              </li>
            ))}
          </ul>
        )}
      </Khoi>
    </KhungTrang>
  )
}
