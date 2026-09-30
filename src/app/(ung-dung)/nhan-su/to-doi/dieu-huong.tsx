import Link from 'next/link'

/**
 * Thanh điều hướng con của tab Quản lý tổ đội.
 *
 * VÌ SAO CÓ FILE NÀY: bản gộp tab đầu tiên (24/08/2026) đặt ba màn dưới cùng
 * một tab, nhưng đường sang hai màn kia chỉ là một dòng chữ gạch chân nằm lẫn
 * ở cuối khối chọn tổ. Triệu Vũ mở tab và kết luận là **chưa có phần lập tổ
 * đội mới** — trong khi nó vẫn ở đó, chỉ là không ai tìm ra.
 *
 * Đúng cái bẫy đã ghi ngày 22/08 với mục "chỉ định người quản lý tổ đội": một
 * tính năng không tìm thấy và một tính năng chưa làm trông giống hệt nhau.
 *
 * Ba mục luôn hiện đủ, kể cả mục người dùng không vào được — trừ mục Tổ đội &
 * nhân công, vì nó đòi quyền và hiện ra một đường dẫn chỉ để đá người ta về là
 * tệ hơn không hiện.
 *
 * Điều kiện của mục ấy phải khớp ĐÚNG cửa vào của `/nhan-su/to-doi/quan-ly`. Tới
 * 29/08/2026 nó lệch cả hai chiều: người mang quyền `quan_ly_nhan_su` thấy
 * đường dẫn nhưng bấm vào bị đá về, còn người chấm của một tổ thì vào được mà
 * không thấy đường nào để vào. Sửa một bên phải mở bên kia ra đọc.
 */
const MUC = [
  { khoa: 'cham-cong', nhan: 'Chấm công & duyệt công', duongDan: '/nhan-su/to-doi' },
  { khoa: 'quan-ly', nhan: 'Tổ đội & nhân công', duongDan: '/nhan-su/to-doi/quan-ly' },
  { khoa: 'thanh-toan', nhan: 'Bảng thanh toán', duongDan: '/nhan-su/to-doi/thanh-toan' },
] as const

export type KhoaManToDoi = (typeof MUC)[number]['khoa']

export function DieuHuongToDoi({
  dang,
  quanLyDuoc,
}: {
  dang: KhoaManToDoi
  /**
   * Vào được màn Tổ đội & nhân công: admin, người mang quyền `quan_ly_nhan_su`,
   * người được bật cờ quản lý tổ đội, hoặc người chấm của ít nhất một tổ.
   */
  quanLyDuoc: boolean
}) {
  return (
    <nav aria-label="Màn hình trong Quản lý tổ đội" className="mb-5 flex flex-wrap gap-2">
      {MUC.filter((m) => m.khoa !== 'quan-ly' || quanLyDuoc).map((m) => {
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
