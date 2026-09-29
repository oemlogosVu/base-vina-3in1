import type { TenBieuTuong } from "@/shared/ui/bieu-tuong";

/**
 * DANH SÁCH PHÂN HỆ của app 3 trong 1 và cách nhận ra phân hệ đang mở từ đường dẫn.
 *
 * Thứ tự cố định: Tài chính · Nhân sự · Kho · Hệ thống (design BoChonPhanHe).
 * Mã (tc/ns/kho/ht) là giá trị của thuộc tính data-phan-he trên khung — CSS đọc
 * nó để tô màu nhấn (globals.css, khối "MỞ RỘNG 3 TRONG 1").
 */
export type PhanHe = "tc" | "ns" | "kho" | "ht";

export type ThongTinPhanHe = {
  ma: PhanHe;
  ten: string;
  /** Chữ tắt trong ô màu nhấn. */
  chuTat: string;
  duongDan: string;
  /** Một dòng mô tả ở trang «Chọn phân hệ» (điện thoại). */
  moTa: string;
  bieuTuong: TenBieuTuong;
};

export const DS_PHAN_HE: readonly ThongTinPhanHe[] = [
  { ma: "tc", ten: "Tài chính", chuTat: "TC", duongDan: "/tai-chinh", moTa: "Thu chi · tạm ứng · duyệt chi", bieuTuong: "wallet" },
  { ma: "ns", ten: "Nhân sự", chuTat: "NS", duongDan: "/nhan-su", moTa: "Hồ sơ · chấm công · lương", bieuTuong: "users" },
  { ma: "kho", ten: "Kho", chuTat: "KHO", duongDan: "/kho", moTa: "Nhập · xuất · tồn vật tư", bieuTuong: "folder" },
  { ma: "ht", ten: "Hệ thống", chuTat: "HT", duongDan: "/he-thong", moTa: "Tài khoản · quyền vào phân hệ", bieuTuong: "cog" },
];

/** Phân hệ chứa đường dẫn, hoặc null (trang chủ, đổi mật khẩu, trang Thêm…). */
export function phanHeTuDuongDan(duongDan: string): ThongTinPhanHe | null {
  return (
    DS_PHAN_HE.find((p) => duongDan === p.duongDan || duongDan.startsWith(`${p.duongDan}/`)) ?? null
  );
}

/**
 * Phân hệ người dùng được vào.
 *
 * GIAI ĐOẠN 1: CHƯA phân quyền — trả đủ cả 4 (kế hoạch GĐ1: "hàm để trống, trả cả 3").
 * Quy tắc thật làm ở GĐ5 (kế hoạch mục 3.4): Tài chính nếu có dòng nhan_vien đang dùng,
 * Nhân sự nếu app_users.is_active, Kho nếu email có trong dm_nguoi_dung HOAT_DONG,
 * Hệ thống chỉ quản trị.
 *
 * ĐÂY KHÔNG PHẢI PHÂN QUYỀN: ẩn phân hệ chỉ để gọn giao diện. Quyền thật nằm ở RLS/RPC
 * của từng phân hệ và ở kiểm tra phiên trong API Kho.
 */
export async function layPhanHeDuocPhep(): Promise<ThongTinPhanHe[]> {
  return [...DS_PHAN_HE];
}
