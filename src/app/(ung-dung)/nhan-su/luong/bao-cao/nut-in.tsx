'use client'

/**
 * Nút in / lưu PDF.
 *
 * Gọi thẳng `window.print()`. Không dùng thư viện sinh PDF vì font PDF chuẩn
 * của jsPDF và pdfkit không có dấu tiếng Việt; muốn đúng phải nhúng font
 * Unicode vài trăm KB và chữ vẫn xấu hơn. Hộp thoại in của trình duyệt có sẵn
 * lựa chọn "Lưu thành PDF" trên cả Windows, macOS, Android và iOS.
 *
 * Nhãn nói cả hai việc, vì phần lớn người dùng không biết rằng đường ra PDF
 * nằm trong hộp thoại In.
 */
export function NutIn() {
  return (
    <button
      type="button"
      onClick={() => window.print()}
      className="khong-in rounded-lg bg-slate-900 px-4 py-2 text-sm font-medium text-white dark:bg-slate-100 dark:text-slate-900"
    >
      In / Lưu PDF
    </button>
  )
}
