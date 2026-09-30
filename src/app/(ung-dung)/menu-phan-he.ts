import { layPhien as layPhienNhanSu } from "@ns/lib/phien";
import { DUONG_DAN_QUAN_TRI, NHAN_NHOM, NHOM_MENU, tabsChoPhep, type KhoaTab } from "@ns/lib/tabs";
import type { PhanHe } from "@/shared/phan-he";
import type { TenBieuTuong } from "@/shared/ui/bieu-tuong";

/**
 * MENU TRONG TỪNG PHÂN HỆ cho thanh bên chung — lấy từ chính nguồn menu của phân hệ đó.
 *
 * Nhân sự: tabsChoPhep() của HRM (theo vai trò + tab tick riêng từng người — một nguồn duy nhất,
 * dùng chung với việc chặn khi gõ thẳng URL). ĐÂY KHÔNG PHẢI PHÂN QUYỀN: quyền thật ở RLS.
 * Phân hệ chưa ghép (Tài chính, Kho, Hệ thống) chưa có menu → thanh bên hiện mục "Tổng quan".
 */
export type MucMenu = { duongDan: string; nhan: string; bieuTuong: TenBieuTuong };
export type NhomMenu = { ten: string; muc: MucMenu[] };

const BIEU_TUONG_NS: Record<KhoaTab, TenBieuTuong> = {
  "ho-so": "file",
  "cham-cong": "clock",
  "to-doi": "users",
  "cham-cong-xac-nhan": "check-sq",
  "sua-chua-cong": "pencil",
  "nhan-su": "users",
  luong: "wallet",
  "luong-ky-luong": "cal",
  "luong-bao-cao": "chart",
};

async function menuNhanSu(): Promise<NhomMenu[]> {
  // Người không có tài khoản Nhân sự đang dùng → không có menu (layPhien trả null, không chuyển trang).
  const phien = await layPhienNhanSu();
  if (!phien) return [];
  const tabs = tabsChoPhep(phien.role, phien.tabsRieng);
  const nhom: NhomMenu[] = NHOM_MENU.map((n) => ({
    ten: NHAN_NHOM[n],
    muc: tabs.filter((t) => t.nhom === n).map((t) => ({ duongDan: t.duongDan, nhan: t.nhan, bieuTuong: BIEU_TUONG_NS[t.khoa] })),
  })).filter((n) => n.muc.length > 0);
  if (phien.role === "admin") {
    nhom.push({ ten: "Quản trị", muc: [{ duongDan: DUONG_DAN_QUAN_TRI, nhan: "Quản trị Nhân sự", bieuTuong: "cog" }] });
  }
  return nhom;
}

export async function layMenuPhanHe(duocPhep: PhanHe[]): Promise<Partial<Record<PhanHe, NhomMenu[]>>> {
  return {
    ns: duocPhep.includes("ns") ? await menuNhanSu() : [],
  };
}
