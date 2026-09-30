/**
 * Sắc pill cho từng trạng thái — NGUỒN DUY NHẤT.
 *
 * Bốn sắc, và cố ý không nhiều hơn: thêm sắc thứ năm là bắt người dùng học
 * một bảng mã màu. Quy ước đọc từ trái sang phải theo mức độ "cần để ý":
 *
 *   xanh — đang chạy đúng, không cần làm gì
 *   vàng — còn dở dang, sẽ phải quay lại
 *   xám  — đã kết thúc, không còn tác động
 *   đỏ   — sai hoặc bị từ chối
 *
 * Ánh xạ để ở đây chứ không rải trong từng trang: cùng một trạng thái mà hai
 * màn tô hai màu là người dùng phải học hai lần.
 */
export type Sac = 'xanh' | 'vang' | 'xam' | 'do'

/** Trạng thái hồ sơ nhân sự. */
export function sacNhanSu(trangThai: string): Sac {
  switch (trangThai) {
    case 'chinh_thuc':
      return 'xanh'
    case 'thu_viec':
    case 'cong_tac_vien':
      return 'vang'
    case 'nghi_viec':
    case 'tam_hoan':
      return 'xam'
    default:
      return 'xam'
  }
}

/**
 * Trạng thái kỳ lương.
 *
 * "Đang mở" là VÀNG chứ không phải xanh: kỳ còn mở nghĩa là còn việc phải
 * làm, chưa phải trạng thái yên ổn.
 */
export function sacKyLuong(trangThai: string): Sac {
  switch (trangThai) {
    case 'mo':
      return 'vang'
    case 'da_chot':
      return 'xanh'
    case 'da_tra':
      return 'xam'
    default:
      return 'xam'
  }
}

/** Trạng thái xác nhận phiếu lương của người lao động. */
export function sacXacNhan(trangThai: string): Sac {
  switch (trangThai) {
    case 'da_xac_nhan':
      return 'xanh'
    case 'cho_xac_nhan':
      return 'vang'
    case 'thac_mac':
      return 'do'
    default:
      return 'xam'
  }
}

/** Trạng thái một ngày công. */
export function sacNgayCong(trangThai: string): Sac {
  switch (trangThai) {
    case 'du_cong':
      return 'xanh'
    case 'thieu_gio':
    case 'thieu_cham_ra':
      return 'vang'
    case 'nghi':
      return 'xam'
    case 'lam_ngay_nghi':
      return 'xanh'
    default:
      return 'xam'
  }
}
