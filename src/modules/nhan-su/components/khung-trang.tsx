import { type Phien } from '@ns/lib/phien'

/**
 * KHUNG TRANG Nhân sự trong app 3 trong 1 (sửa khi chép từ HRM main, Giai đoạn 2).
 *
 * Bản HRM vẽ cả thanh bên, đầu trang, tên người dùng, "Đổi mật khẩu", "Đăng xuất" và dấu phiên bản.
 * Ở app 3 trong 1 những thứ đó do khung chung vẽ (src/app/(ung-dung)/layout.tsx) — menu Nhân sự
 * (tabsChoPhep) nằm trong thanh bên chung. Ở đây chỉ còn tiêu đề trang + nội dung.
 * Chữ ký hàm giữ nguyên để 26 trang HRM không phải sửa.
 */
export function KhungTrang({
  phien: _phien,
  tieuDe,
  children,
}: {
  phien: Phien
  tieuDe: string
  children: React.ReactNode
}) {
  return (
    <div className="khung-trang-ns">
      <h1 className="header-tieu-de khong-in">{tieuDe}</h1>
      <div className="than-trang-ns">{children}</div>
    </div>
  )
}

export function O({ nhan, children }: { nhan: string; children: React.ReactNode }) {
  return (
    <div>
      <dt className="nhan-phu" style={{ textTransform: 'uppercase', letterSpacing: '0.04em' }}>
        {nhan}
      </dt>
      <dd className="mt-0.5 break-words">{children}</dd>
    </div>
  )
}

/** Khối nội dung có tiêu đề. */
export function Khoi({
  tieuDe,
  ghiChu,
  children,
}: {
  tieuDe: string
  ghiChu?: string
  children: React.ReactNode
}) {
  return (
    <section className="the">
      <h2 className="the-tieu-de">{tieuDe}</h2>
      {ghiChu && <p className="the-ghi-chu">{ghiChu}</p>}
      <div className="mt-4">{children}</div>
    </section>
  )
}

/**
 * Trạng thái dạng pill.
 *
 * Chữ màu trần trên nền trắng đọc như một lỗi hiển thị; pill đọc như một
 * trạng thái. Bốn sắc là đủ, và cố ý không nhiều hơn: thêm sắc thứ năm là
 * bắt người dùng học một bảng mã màu.
 */
export function Pill({
  sac,
  children,
}: {
  sac: 'xanh' | 'vang' | 'xam' | 'do'
  children: React.ReactNode
}) {
  return <span className={`pill pill-${sac}`}>{children}</span>
}
