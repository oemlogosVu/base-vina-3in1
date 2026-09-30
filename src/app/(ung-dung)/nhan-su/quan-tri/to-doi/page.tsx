import { redirect } from 'next/navigation'

/**
 * Tổ đội công nhật rời khỏi Quản trị ngày 24/08/2026.
 *
 * Nó nay là một tab riêng — Quản lý tổ đội — gom cả lập tổ, chấm công và duyệt
 * công vào một chỗ. Trang này ở lại chỉ để những đường dẫn cũ (dấu trang của
 * người dùng, link trong nhật ký) không dẫn vào 404.
 */
export default function ChuyenHuongToDoiCu() {
  redirect('/nhan-su/to-doi/quan-ly')
}
