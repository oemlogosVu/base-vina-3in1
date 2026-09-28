import { batBuocDangNhap, TEN_VAI_TRO } from "@/lib/auth/nguoi-dung";
import { boCucDieuHuong, menuChoNguoiDung } from "@/lib/auth/menu";
import { PHIEN_BAN } from "@/lib/phien-ban";
import { huyHieuTheoTab, napViecCanLam } from "@/lib/viec-can-lam";
import { dangXuat } from "@/app/dang-nhap/actions";
import { BieuTuong } from "@/components/ui/bieu-tuong";

import { DauTrangDienThoai, ThanhBen, ThanhTabDuoi } from "./dieu-huong";

/**
 * Khung chung cho mọi trang cần đăng nhập.
 *
 * Nhóm route "(ung-dung)" nằm trong ngoặc nên KHÔNG xuất hiện trong đường dẫn —
 * nó chỉ để gom các trang dùng chung khung này.
 *
 * Giao diện mới (PROMPT mục 4):
 *   - Điện thoại (< 1024px): đầu trang navy + thanh tab dưới đáy (4 tab + Thêm).
 *     Đổi mật khẩu / Đăng xuất dời vào trang /them.
 *   - Máy tính (≥ 1024px): thanh trên navy + thanh bên trái chia nhóm.
 */
export default async function KhungUngDung({
  children,
}: {
  children: React.ReactNode;
}) {
  const nguoiDung = await batBuocDangNhap();
  const [menu, viec] = await Promise.all([menuChoNguoiDung(nguoiDung), napViecCanLam()]);
  const dieuHuong = boCucDieuHuong(menu, huyHieuTheoTab(viec));
  const vaiTro = nguoiDung.vaiTro.map((v) => TEN_VAI_TRO[v]).join(" · ");

  return (
    <div className="flex min-h-screen flex-col">
      <DauTrangDienThoai
        hoTen={nguoiDung.hoTen}
        vaiTro={vaiTro}
        muc={dieuHuong.nhomThanhBen.flatMap((n) => n.muc)}
      />

      <header className="thanh-tren hidden lg:flex">
        <span className="logo-tc" aria-hidden="true">
          TC
        </span>
        <span className="text-base font-bold">Quản lý Thu Chi</span>
        <span className="flex-1" />
        <span className="min-w-0 truncate text-sm">
          {nguoiDung.hoTen} · {vaiTro}
        </span>
        <form action={dangXuat}>
          <button type="submit" className="nut-tren-nen-toi">
            <BieuTuong ten="out" co={18} />
            Đăng xuất
          </button>
        </form>
      </header>

      <div className="flex flex-1">
        <ThanhBen nhom={dieuHuong.nhomThanhBen} phienBan={PHIEN_BAN} />

        {/* pb điện thoại: chừa chỗ cho thanh tab dán đáy (6 + 56 + 14px + vùng an
            toàn), nếu không nội dung cuối trang bị nó che mất. */}
        <main className="noi-dung min-w-0 flex-1 px-4 pt-4 pb-[calc(92px+env(safe-area-inset-bottom))] lg:px-8 lg:pt-6 lg:pb-10">
          {children}
        </main>
      </div>

      <ThanhTabDuoi tab={dieuHuong.tabDuoi} them={dieuHuong.tabThem} />
    </div>
  );
}
