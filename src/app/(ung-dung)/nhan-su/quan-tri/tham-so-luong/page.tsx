import { KhungTrang, Khoi } from '@ns/components/khung-trang'
import { batBuocVaiTro } from '@ns/lib/phien'
import { layThamSoLuong } from '@ns/lib/luong'
import { ngay, tien } from '@ns/lib/dinh-dang'
import {
  FormBacThue,
  FormBaoHiem,
  FormGiamTru,
  FormLamThem,
  FormLuongCoSo,
  FormLuongToiThieu,
} from './bieu-mau'

export default async function TrangThamSoLuong() {
  const phien = await batBuocVaiTro('admin')
  const t = await layThamSoLuong()

  return (
    <KhungTrang phien={phien} tieuDe="Tham số tính lương">
      <div className="mb-6 rounded-xl bg-slate-100 p-4 text-sm dark:bg-slate-800">
        <p className="font-medium">Ba nguyên tắc của màn này</p>
        <ol className="mt-2 list-decimal space-y-1 pl-5">
          <li>
            <strong>Thêm dòng mới, không sửa dòng cũ.</strong> Engine chọn tham số theo ngày
            cuối kỳ lương, nên tính lại tháng 3 vào tháng 8 phải ra đúng con số của tháng 3.
            Sửa dòng cũ là làm sai lại các kỳ đã tính.
          </li>
          <li>
            <strong>Ghi căn cứ pháp lý.</strong> Người tiếp quản cần biết con số này lấy từ
            văn bản nào, không phải đoán.
          </li>
          <li>
            <strong>Thiếu tham số thì hệ thống từ chối tính lương</strong>, chứ không tính ra
            0 đồng. Con số 0 là thứ dễ lọt qua mắt người duyệt nhất.
          </li>
        </ol>
      </div>

      <Khoi
        tieuDe={`Biểu thuế TNCN (${t.bacThue.length} bậc đã nhập)`}
        ghiChu="Kế hoạch dự án ghi 7 bậc, hồ sơ người phụ trách ghi 5 bậc theo Luật 109/2025. Hệ thống KHÔNG chọn hộ — nhập đúng biểu thuế đang có hiệu lực kèm căn cứ."
      >
        {t.bacThue.length > 0 && (
          <table className="bang">
            <thead>
              <tr>
                <th>Hiệu lực</th>
                <th>Bậc</th>
                <th>Từ</th>
                <th>Đến</th>
                <th>Thuế suất</th>
              </tr>
            </thead>
            <tbody>
              {t.bacThue.map((b) => (
                <tr key={b.id} className="border-t border-slate-100 dark:border-slate-800">
                  <td>{ngay(b.effective_from)}</td>
                  <td data-nhan="Bậc">{b.level}</td>
                  <td data-nhan="Từ">{tien(b.from_amount)}</td>
                  <td data-nhan="Đến">
                    {b.to_amount === null ? 'trở lên' : tien(b.to_amount)}
                  </td>
                  <td data-nhan="Thuế suất">{b.rate}%</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
        <FormBacThue />
      </Khoi>

      <Khoi tieuDe={`Giảm trừ gia cảnh (${t.giamTru.length})`}>
        {t.giamTru.length > 0 && (
          <ul className="mb-4 space-y-1 text-sm">
            {t.giamTru.map((g) => (
              <li key={g.id}>
                Từ {ngay(g.effective_from)}: bản thân {tien(g.personal_amount)}, mỗi người phụ
                thuộc {tien(g.dependent_amount)}
              </li>
            ))}
          </ul>
        )}
        <FormGiamTru />
      </Khoi>

      <Khoi tieuDe={`Tỷ lệ và trần bảo hiểm (${t.baoHiem.length})`}>
        {t.baoHiem.length > 0 && (
          <ul className="mb-4 space-y-1 text-sm">
            {t.baoHiem.map((b) => (
              <li key={b.id}>
                Từ {ngay(b.effective_from)}: NV đóng BHXH {b.bhxh_employee_pct}% · BHYT{' '}
                {b.bhyt_employee_pct}% · BHTN {b.bhtn_employee_pct}%; công ty đóng{' '}
                {b.bhxh_employer_pct}% · {b.bhyt_employer_pct}% · {b.bhtn_employer_pct}%
                {b.ghi_chu ? ` — ${b.ghi_chu}` : ''}
              </li>
            ))}
          </ul>
        )}
        <FormBaoHiem />
      </Khoi>

      <Khoi tieuDe={`Lương cơ sở (${t.luongCoSo.length})`} ghiChu="Dùng để tính trần đóng BHXH và BHYT.">
        {t.luongCoSo.length > 0 && (
          <ul className="mb-4 space-y-1 text-sm">
            {t.luongCoSo.map((l) => (
              <li key={l.id}>
                Từ {ngay(l.effective_from)}: {tien(l.amount)}
              </li>
            ))}
          </ul>
        )}
        <FormLuongCoSo />
      </Khoi>

      <Khoi
        tieuDe={`Lương tối thiểu vùng (${t.luongToiThieu.length})`}
        ghiChu="Dùng để tính trần đóng BHTN. Nhập riêng cho từng vùng có nhân viên."
      >
        {t.luongToiThieu.length > 0 && (
          <ul className="mb-4 space-y-1 text-sm">
            {t.luongToiThieu.map((l) => (
              <li key={l.id}>
                Từ {ngay(l.effective_from)} · vùng {l.region}: {tien(l.amount)}
              </li>
            ))}
          </ul>
        )}
        <FormLuongToiThieu />
      </Khoi>

      <Khoi
        tieuDe={`Hệ số làm thêm giờ (${t.lamThem.length})`}
        ghiChu="Chưa nhập thì hệ thống TỪ CHỐI tính lương cho nhân viên có giờ làm thêm — im lặng ở đây là quỵt tiền của người đã làm thêm."
      >
        {t.lamThem.length > 0 && (
          <ul className="mb-4 space-y-1 text-sm">
            {t.lamThem.map((o) => (
              <li key={o.id}>
                Từ {ngay(o.effective_from)}: ngày thường {o.ngay_thuong_pct}% · ngày nghỉ tuần{' '}
                {o.ngay_nghi_tuan_pct}% · ngày lễ {o.ngay_le_pct}%
                {o.ghi_chu ? ` — ${o.ghi_chu}` : ''}
              </li>
            ))}
          </ul>
        )}
        <FormLamThem />
      </Khoi>

      <p className="text-sm text-slate-500">
        Hiện engine áp hệ số <strong>ngày thường</strong> cho toàn bộ giờ làm thêm. Phân biệt
        ngày nghỉ tuần và ngày lễ cần một bảng lịch nghỉ lễ — thuộc phase sau. Tới lúc đó, kế
        toán tự điều chỉnh phần chênh bằng dòng thưởng trên phiếu lương.
      </p>
    </KhungTrang>
  )
}
