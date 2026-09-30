import { Khoi, O } from '@ns/components/khung-trang'
import { hoacGach, ngay, tien } from '@ns/lib/dinh-dang'
import type { ChiTietHoSo as DuLieuHoSo } from '@ns/lib/ho-so'
import {
  CONTRACT_TYPE_LABELS,
  EMPLOYEE_STATUS_LABELS,
  GENDER_LABELS,
  type UserRole,
} from '@ns/types/database'

/** Giải thích vì sao một khối rỗng — theo vai trò của người đang xem. */
function LyDoTrong({ vaiTro, moTa }: { vaiTro: UserRole; moTa: string }) {
  if (vaiTro === 'truong_phong') {
    return (
      <p className="text-sm text-slate-500">
        Vai trò trưởng phòng không được xem {moTa}. Đây là thiết kế, không phải lỗi — dữ liệu
        bị chặn ngay ở tầng database.
      </p>
    )
  }
  return <p className="text-sm text-slate-500">Chưa có dữ liệu.</p>
}

export function ChiTietHoSo({
  duLieu,
  vaiTroNguoiXem,
}: {
  duLieu: DuLieuHoSo
  vaiTroNguoiXem: UserRole
}) {
  const { employee: nv, nhayCam, hopDong, mucLuong, chucDanh, nguoiPhuThuoc } = duLieu

  return (
    <>
      <Khoi tieuDe="Thông tin chung">
        <dl className="grid grid-cols-1 gap-4 text-sm sm:grid-cols-3">
          <O nhan="Mã nhân viên">
            <span className="font-mono">{nv.employee_code}</span>
          </O>
          <O nhan="Họ và tên">{nv.full_name}</O>
          <O nhan="Trạng thái">{EMPLOYEE_STATUS_LABELS[nv.status]}</O>
          <O nhan="Ngày sinh">{ngay(nv.dob)}</O>
          <O nhan="Giới tính">{nv.gender ? GENDER_LABELS[nv.gender] : '—'}</O>
          <O nhan="Ngày vào làm">{ngay(nv.hire_date)}</O>
          <O nhan="Phòng ban">{hoacGach(duLieu.tenPhongBan)}</O>
          <O nhan="Chức danh">{hoacGach(duLieu.tenChucDanh)}</O>
          <O nhan="Quản lý trực tiếp">{hoacGach(duLieu.tenQuanLy)}</O>
          <O nhan="Điện thoại">{hoacGach(nv.phone)}</O>
          <O nhan="Email cá nhân">{hoacGach(nv.personal_email)}</O>
          <O nhan="Vùng lương tối thiểu">{nv.region === null ? '—' : `Vùng ${nv.region}`}</O>
          <div className="sm:col-span-3">
            <O nhan="Địa chỉ thường trú">{hoacGach(nv.permanent_address)}</O>
          </div>
        </dl>
      </Khoi>

      <Khoi
        tieuDe="Thông tin nhạy cảm"
        ghiChu="CCCD, tài khoản ngân hàng, mã số thuế, số sổ BHXH — chỉ chính chủ, HR, kế toán và admin xem được."
      >
        {nhayCam ? (
          <dl className="grid grid-cols-1 gap-4 text-sm sm:grid-cols-3">
            <O nhan="Số CCCD">{hoacGach(nhayCam.cccd)}</O>
            <O nhan="Ngày cấp">{ngay(nhayCam.cccd_issue_date)}</O>
            <O nhan="Nơi cấp">{hoacGach(nhayCam.cccd_issue_place)}</O>
            <O nhan="Số tài khoản">{hoacGach(nhayCam.bank_account_no)}</O>
            <O nhan="Ngân hàng">{hoacGach(nhayCam.bank_name)}</O>
            <O nhan="Mã số thuế">{hoacGach(nhayCam.tax_code)}</O>
            <O nhan="Số sổ BHXH">{hoacGach(nhayCam.social_insurance_no)}</O>
          </dl>
        ) : (
          <LyDoTrong vaiTro={vaiTroNguoiXem} moTa="CCCD, tài khoản ngân hàng và mã số thuế" />
        )}
      </Khoi>

      <Khoi tieuDe="Hợp đồng lao động">
        {hopDong.length === 0 ? (
          <LyDoTrong vaiTro={vaiTroNguoiXem} moTa="lương và hợp đồng lao động" />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-sm">
              <thead className="text-xs uppercase tracking-wide text-slate-500">
                <tr>
                  <th className="py-2 pr-4">Số hợp đồng</th>
                  <th className="py-2 pr-4">Loại</th>
                  <th className="py-2 pr-4">Từ ngày</th>
                  <th className="py-2 pr-4">Đến ngày</th>
                  <th className="py-2">Hiệu lực</th>
                </tr>
              </thead>
              <tbody>
                {hopDong.map((hd) => (
                  <tr key={hd.id} className="border-t border-slate-100 dark:border-slate-800">
                    <td className="py-2 pr-4 font-mono text-xs">{hd.contract_no}</td>
                    <td className="py-2 pr-4">{CONTRACT_TYPE_LABELS[hd.type]}</td>
                    <td className="py-2 pr-4">{ngay(hd.start_date)}</td>
                    <td className="py-2 pr-4">{ngay(hd.end_date)}</td>
                    <td className="py-2">{hd.is_active ? 'Đang hiệu lực' : 'Đã kết thúc'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Khoi>

      <Khoi
        tieuDe="Chức danh theo thời gian"
        ghiChu="Cả chức danh chính lẫn chức danh kiêm đều có kỳ hiệu lực. Phụ cấp của mọi chức danh đang hiệu lực được cộng vào lương — cùng một loại thì chỉ hưởng mức cao nhất."
      >
        {chucDanh.length === 0 ? (
          <p className="text-sm text-slate-500">Chưa gán chức danh nào.</p>
        ) : (
          <ul className="space-y-2 text-sm">
            {chucDanh.map((k) => {
              const conHieuLuc = k.den_ngay === null
              return (
                <li key={k.id} className="flex flex-wrap items-center gap-3">
                  <span className={conHieuLuc ? 'font-medium' : 'text-slate-500'}>
                    {k.positions?.name}
                  </span>
                  <span className="text-xs text-slate-500">
                    {k.la_chinh ? 'chức danh chính' : 'kiêm nhiệm'}
                  </span>
                  <span className="text-xs text-slate-500">
                    từ {ngay(k.tu_ngay)}
                    {k.den_ngay !== null && ` đến ${ngay(k.den_ngay)}`}
                    {k.ly_do && ` · ${k.ly_do}`}
                  </span>
                  {!conHieuLuc && (
                    <span className="text-xs text-slate-500">(đã kết thúc)</span>
                  )}
                </li>
              )
            })}
          </ul>
        )}
      </Khoi>

      <Khoi
        tieuDe="Mức lương theo thời gian"
        ghiChu="Tăng hay giảm lương đều có ngày áp dụng; những ngày trước đó vẫn tính theo mức cũ."
      >
        {mucLuong.length === 0 ? (
          <LyDoTrong vaiTro={vaiTroNguoiXem} moTa="mức lương" />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-left text-slate-500">
                  <th className="py-2 pr-4">Áp dụng từ</th>
                  <th className="py-2 pr-4">Lương chức danh</th>
                  <th className="py-2 pr-4">Lương đóng BHXH</th>
                  <th className="py-2">Lý do</th>
                </tr>
              </thead>
              <tbody>
                {mucLuong.map((m, i) => (
                  <tr key={m.id} className="border-t border-slate-100 dark:border-slate-800">
                    <td className="py-2 pr-4">
                      {ngay(m.tu_ngay)}
                      {i === 0 && (
                        <span className="ml-2 text-xs text-emerald-700 dark:text-emerald-400">
                          mới nhất
                        </span>
                      )}
                    </td>
                    <td className="py-2 pr-4">{tien(m.position_salary)}</td>
                    <td className="py-2 pr-4">{tien(m.bhxh_salary)}</td>
                    <td className="py-2 text-slate-500">{hoacGach(m.ly_do)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Khoi>

      <Khoi
        tieuDe="Người phụ thuộc"
        ghiChu="Dùng để tính giảm trừ gia cảnh thuế TNCN. Mức giảm trừ đọc từ bảng tham số theo ngày hiệu lực, không nhập tay ở đây."
      >
        {nguoiPhuThuoc.length === 0 ? (
          <LyDoTrong vaiTro={vaiTroNguoiXem} moTa="danh sách người phụ thuộc" />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-sm">
              <thead className="text-xs uppercase tracking-wide text-slate-500">
                <tr>
                  <th className="py-2 pr-4">Họ tên</th>
                  <th className="py-2 pr-4">Quan hệ</th>
                  <th className="py-2 pr-4">Mã số thuế</th>
                  <th className="py-2 pr-4">Từ</th>
                  <th className="py-2">Đến</th>
                </tr>
              </thead>
              <tbody>
                {nguoiPhuThuoc.map((n) => (
                  <tr key={n.id} className="border-t border-slate-100 dark:border-slate-800">
                    <td className="py-2 pr-4">{n.full_name}</td>
                    <td className="py-2 pr-4">{hoacGach(n.relationship)}</td>
                    <td className="py-2 pr-4">{hoacGach(n.tax_code)}</td>
                    <td className="py-2 pr-4">{ngay(n.reg_from)}</td>
                    <td className="py-2">{n.reg_to ? ngay(n.reg_to) : 'Còn hiệu lực'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Khoi>
    </>
  )
}
