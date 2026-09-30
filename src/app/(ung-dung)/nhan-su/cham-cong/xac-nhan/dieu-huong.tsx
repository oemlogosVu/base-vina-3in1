import Link from 'next/link'

/**
 * Thanh điều hướng con của tab Chấm công công ty.
 *
 * Hai màn cùng một quyền `xac_nhan_cham_cong`, nên chúng ở chung một tab thay
 * vì mỗi màn một tab.
 *
 * Đây là hệ quả trực tiếp của mô hình P0d — MỘT TAB = MỘT Ô TICK = MỘT QUYỀN.
 * Tách bảng công tháng thành tab riêng thì tick tab ấy sẽ cấp luôn quyền
 * DUYỆT chấm công, hoặc tab hiện ra rồi báo lỗi với người không có quyền. Cả
 * hai đều tệ hơn một thanh chuyển màn.
 */
const MUC = [
  { khoa: 'xac-nhan', nhan: 'Xác nhận hằng ngày', duongDan: '/nhan-su/cham-cong/xac-nhan' },
  { khoa: 'bang-thang', nhan: 'Bảng công tháng', duongDan: '/nhan-su/cham-cong/xac-nhan/bang-thang' },
] as const

export type KhoaManChamCong = (typeof MUC)[number]['khoa']

export function DieuHuongChamCong({ dang }: { dang: KhoaManChamCong }) {
  return (
    <nav aria-label="Màn hình trong Chấm công công ty" className="khong-in mb-5 flex flex-wrap gap-2">
      {MUC.map((m) => {
        const dangXem = m.khoa === dang
        return (
          <Link
            key={m.khoa}
            href={m.duongDan}
            aria-current={dangXem ? 'page' : undefined}
            className={`rounded-lg px-3 py-2 text-sm ${
              dangXem
                ? 'bg-slate-900 font-medium text-white dark:bg-slate-100 dark:text-slate-900'
                : 'border border-slate-300 dark:border-slate-700'
            }`}
          >
            {m.nhan}
          </Link>
        )
      })}
    </nav>
  )
}
