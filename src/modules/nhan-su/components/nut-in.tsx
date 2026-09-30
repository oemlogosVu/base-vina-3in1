'use client'

/**
 * Nút xuất PDF.
 *
 * VÌ SAO DÙNG HỘP THOẠI IN CỦA TRÌNH DUYỆT, KHÔNG SINH FILE Ở MÁY CHỦ
 *
 * Dự án có sẵn một đường sinh PDF phía máy chủ (Edge Function `chung-tu`,
 * P6a). Nhưng đường ấy dựng lên để làm CHỨNG TỪ: file bất biến, có vân tay
 * sha256, lưu vào kho, không ai xoá được. Bảng công tháng là một BÁO CÁO —
 * xem xong là thôi, tháng sau lại khác. Đẩy nó qua đường chứng từ là mỗi lần
 * bấm xem lại sinh thêm một bằng chứng vĩnh viễn không ai xoá được.
 *
 * Trình duyệt in ra PDF thật: chữ chọn được, dấu tiếng Việt đúng, ngắt trang
 * do chính engine dàn trang lo. `@media print` trong `globals.css` đã đặt A4
 * ngang, bỏ menu, bỏ ghim cột và co chữ cho 31 cột lọt một tờ.
 *
 * Đánh đổi đã cân: người dùng phải chọn "Lưu thành PDF" trong hộp thoại in,
 * thay vì có ngay một file tải về. Đổi lại không thêm một hệ sinh PDF thứ hai
 * vào dự án, và bản in luôn khớp với thứ đang hiện trên màn hình.
 */
export function NutIn({ nhan = 'Xuất PDF / In' }: { nhan?: string }) {
  return (
    <button
      type="button"
      onClick={() => window.print()}
      className="khong-in rounded-lg border border-slate-300 px-3 py-2 text-sm dark:border-slate-700"
    >
      {nhan}
    </button>
  )
}
