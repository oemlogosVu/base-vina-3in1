/** Định dạng hiển thị. Không chứa phép tính nghiệp vụ nào. */

const DINH_DANG_TIEN = new Intl.NumberFormat('vi-VN', {
  style: 'currency',
  currency: 'VND',
  maximumFractionDigits: 0,
})

/**
 * Hiển thị số tiền VND.
 *
 * CHỈ để hiển thị. Mọi phép tính tiền lương chạy phía server bằng `numeric`
 * của Postgres, không bao giờ tính bằng số thực trong trình duyệt
 * (AGENTS.md mục 2.2 và mục 10).
 */
export function tien(giaTri: number | null | undefined): string {
  if (giaTri === null || giaTri === undefined) return '—'
  return DINH_DANG_TIEN.format(giaTri)
}

/** Ngày dạng dd/mm/yyyy. Nhận chuỗi `date` của Postgres (yyyy-mm-dd). */
export function ngay(giaTri: string | null | undefined): string {
  if (!giaTri) return '—'
  const [nam, thang, ngayTrongThang] = giaTri.split('-')
  if (!nam || !thang || !ngayTrongThang) return giaTri
  return `${ngayTrongThang}/${thang}/${nam}`
}

/** Giá trị rỗng hiển thị bằng gạch ngang thay vì khoảng trắng khó nhìn. */
export function hoacGach(giaTri: string | null | undefined): string {
  const s = (giaTri ?? '').trim()
  return s === '' ? '—' : s
}

/**
 * Giờ phút theo múi giờ Việt Nam, từ một `timestamptz` của Postgres.
 *
 * Luôn ép múi giờ tường minh thay vì để trình duyệt tự chọn: máy chủ Vercel
 * chạy UTC, còn điện thoại nhân viên có thể đặt múi giờ bất kỳ. Không ép thì
 * cùng một lần chấm công hiện ra hai giờ khác nhau ở hai nơi, và người xem
 * không có cách nào biết bên nào đúng.
 */
const DINH_DANG_GIO = new Intl.DateTimeFormat('vi-VN', {
  timeZone: 'Asia/Ho_Chi_Minh',
  hour: '2-digit',
  minute: '2-digit',
  hour12: false,
})

const DINH_DANG_NGAY_GIO = new Intl.DateTimeFormat('vi-VN', {
  timeZone: 'Asia/Ho_Chi_Minh',
  day: '2-digit',
  month: '2-digit',
  year: 'numeric',
  hour: '2-digit',
  minute: '2-digit',
  hour12: false,
})

export function gio(giaTri: string | null | undefined): string {
  if (!giaTri) return '—'
  return DINH_DANG_GIO.format(new Date(giaTri))
}

export function ngayGio(giaTri: string | null | undefined): string {
  if (!giaTri) return '—'
  return DINH_DANG_NGAY_GIO.format(new Date(giaTri))
}

/** 485 phút → "8h05". Đọc nhanh hơn số phút thô khi xem bảng công. */
export function phutThanhGio(phut: number | null | undefined): string {
  if (phut === null || phut === undefined) return '—'
  if (phut === 0) return '0'
  const g = Math.floor(phut / 60)
  const p = phut % 60
  if (g === 0) return `${p} phút`
  return p === 0 ? `${g}h` : `${g}h${String(p).padStart(2, '0')}`
}

/**
 * Hôm nay theo GIỜ VIỆT NAM, dạng yyyy-mm-dd.
 *
 * Không dùng toISOString().slice(0,10): nó cho ra ngày theo UTC, nên từ 00:00
 * tới 07:00 giờ Việt Nam nó trả về NGÀY HÔM QUA. Chấm công buổi sáng sớm ở
 * công trường rơi đúng vào khoảng đó.
 */
export function ngayHomNayVN(): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Ho_Chi_Minh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date())
}
