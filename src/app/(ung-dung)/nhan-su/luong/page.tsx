import { KhungTrang, Khoi, O } from '@ns/components/khung-trang'
import { batBuocTab } from '@ns/lib/phien'
import { hanXacNhan, layChiTietPhieu, layPhieuCuaToi } from '@ns/lib/luong'
import { tien } from '@ns/lib/dinh-dang'
import { KhoiXacNhan } from './xac-nhan-phieu'

const NGAY_VN = new Intl.DateTimeFormat('vi-VN', {
  day: '2-digit',
  month: '2-digit',
  year: 'numeric',
})

const NHAN_LOAI: Record<string, string> = {
  phu_cap: 'Phụ cấp',
  thuong: 'Thưởng / làm thêm',
  khau_tru: 'Khấu trừ',
}

export default async function TrangLuongCuaToi() {
  // Hai truy vấn này không phụ thuộc nhau — RLS lo phần ai đọc được gì, nên
  // không cần biết phiên trước khi hỏi phiếu lương. Chạy song song bớt được
  // một vòng chờ mạng.
  const [phien, phieu] = await Promise.all([batBuocTab('luong'), layPhieuCuaToi()])

  // Chỉ mở chi tiết phiếu mới nhất: người xem quan tâm tháng vừa rồi, và mỗi
  // phiếu là một truy vấn riêng.
  const moiNhat = phieu[0]
  const chiTiet = moiNhat ? await layChiTietPhieu(moiNhat.id) : []

  return (
    <KhungTrang phien={phien} tieuDe="Phiếu lương của tôi">
      {phieu.length === 0 ? (
        <Khoi tieuDe="Chưa có phiếu lương">
          <p className="text-sm text-slate-500">
            Chưa có kỳ lương nào được tính cho bạn. Phiếu lương xuất hiện ở đây sau khi kế toán
            tính lương của kỳ đó.
          </p>
        </Khoi>
      ) : (
        <>
          {moiNhat && (
            <Khoi
              tieuDe={`Kỳ ${moiNhat.payroll_periods?.month}/${moiNhat.payroll_periods?.year}`}
              ghiChu={
                moiNhat.payroll_periods?.status === 'mo'
                  ? 'Kỳ này chưa chốt — con số còn có thể thay đổi, chưa cần xác nhận.'
                  : moiNhat.xac_nhan_trang_thai === 'da_xac_nhan'
                    ? moiNhat.xac_nhan_tu_dong
                      ? 'Hợp lệ — hệ thống tự đánh dấu do quá hạn xác nhận.'
                      : 'Hợp lệ — bạn đã xác nhận phiếu này.'
                    : moiNhat.xac_nhan_trang_thai === 'thac_mac'
                      ? 'Bạn đang có thắc mắc về phiếu này — nhân sự đã nhận được.'
                      : 'Kỳ đã chốt và gửi cho bạn. Phiếu chỉ hợp lệ khi bạn bấm xác nhận.'
              }
            >
              <dl className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                <O nhan="Ngày công">{moiNhat.worked_days}</O>
                <O nhan="Tổng thu nhập">{tien(moiNhat.gross_salary)}</O>
                <O nhan="BHXH bạn đóng">{tien(moiNhat.bhxh_employee)}</O>
                <O nhan="BHYT bạn đóng">{tien(moiNhat.bhyt_employee)}</O>
                <O nhan="BHTN bạn đóng">{tien(moiNhat.bhtn_employee)}</O>
                <O nhan="Thu nhập chịu thuế">{tien(moiNhat.taxable_income)}</O>
                <O nhan="Giảm trừ bản thân">{tien(moiNhat.personal_deduction)}</O>
                <O nhan="Giảm trừ người phụ thuộc">{tien(moiNhat.dependent_deduction)}</O>
                <O nhan="Thu nhập tính thuế">{tien(moiNhat.assessable_income)}</O>
                <O nhan="Thuế TNCN">{tien(moiNhat.pit)}</O>
                <div className="sm:col-span-2 lg:col-span-3">
                  <dt className="text-xs uppercase tracking-wide text-slate-500">
                    Thực nhận
                  </dt>
                  <dd className="mt-0.5 text-2xl font-semibold">{tien(moiNhat.net_salary)}</dd>
                </div>
              </dl>

              {chiTiet.length > 0 && (
                <ul className="mt-6 space-y-1 border-t border-slate-100 pt-4 text-sm dark:border-slate-800">
                  {chiTiet.map((m) => (
                    <li key={m.id} className="flex flex-wrap justify-between gap-2">
                      <span>
                        <span className="text-slate-500">{NHAN_LOAI[m.item_type] ?? m.item_type}</span>{' '}
                        {m.name}
                        {!m.is_taxable && (
                          <span className="ml-2 text-xs text-slate-500">không chịu thuế</span>
                        )}
                      </span>
                      <span>{tien(m.amount)}</span>
                    </li>
                  ))}
                </ul>
              )}

              <p className="mt-6 text-sm text-slate-500">
                Phần công ty đóng cho bạn: BHXH {tien(moiNhat.bhxh_employer)}, BHYT{' '}
                {tien(moiNhat.bhyt_employer)}, BHTN {tien(moiNhat.bhtn_employer)}. Khoản này
                công ty trả, không trừ vào lương của bạn.
              </p>

              {moiNhat.thac_mac_ly_do && (
                <p className="mt-4 rounded-lg bg-slate-100 p-3 text-sm dark:bg-slate-900">
                  <span className="text-slate-500">Thắc mắc bạn đã gửi:</span>{' '}
                  {moiNhat.thac_mac_ly_do}
                </p>
              )}

              {/* Chỉ hiện nút khi kỳ đã chốt (tức đã gửi) và bạn chưa ký.
                  Kỳ còn mở thì con số chưa chốt, ký vào là ký một bản nháp. */}
              {moiNhat.payroll_periods?.status !== 'mo' &&
                moiNhat.xac_nhan_trang_thai !== 'da_xac_nhan' && (
                  <KhoiXacNhan
                    payslipId={moiNhat.id}
                    hanXacNhan={(() => {
                      const han = hanXacNhan(moiNhat)
                      return han ? NGAY_VN.format(han) : null
                    })()}
                  />
                )}
            </Khoi>
          )}

          {phieu.length > 1 && (
            <Khoi tieuDe="Các kỳ trước">
              <div className="overflow-x-auto">
                <table className="bang">
                  <thead>
                    <tr>
                      <th>Kỳ</th>
                      <th className="phai">Ngày công</th>
                      <th className="phai">Tổng thu nhập</th>
                      <th className="phai">Thuế TNCN</th>
                      <th className="phai">Thực nhận</th>
                    </tr>
                  </thead>
                  <tbody>
                    {phieu.slice(1).map((p) => (
                      <tr key={p.id}>
                        <td className="whitespace-nowrap">
                          Kỳ {p.payroll_periods?.month}/{p.payroll_periods?.year}
                        </td>
                        <td data-nhan="Ngày công" className="phai">
                          {p.worked_days}
                        </td>
                        <td data-nhan="Tổng thu nhập" className="phai">
                          {tien(p.gross_salary)}
                        </td>
                        <td data-nhan="Thuế TNCN" className="phai">
                          {tien(p.pit)}
                        </td>
                        <td data-nhan="Thực nhận" className="phai font-semibold">
                          {tien(p.net_salary)}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </Khoi>
          )}
        </>
      )}
    </KhungTrang>
  )
}
