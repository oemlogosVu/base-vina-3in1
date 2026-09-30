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
