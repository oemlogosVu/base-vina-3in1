import { dangXuat } from "@/app/dang-nhap/actions";
import { batBuocPhien } from "@/shared/auth/phien";
import { layPhanHeDuocPhep } from "@/shared/phan-he-duoc-phep";
import { PHIEN_BAN, TEN_APP } from "@/shared/phien-ban";
import { BieuTuong } from "@/shared/ui/bieu-tuong";

import { layMenuPhanHe } from "./menu-phan-he";
import { DaiNhan, DauTrangDienThoai, KhungPhanHe, ThanhBen, ThanhTabDuoi } from "./dieu-huong";

/**
 * KHUNG CHUNG cho mọi trang cần đăng nhập — dựng theo layout (ung-dung) của app
 * Tài chính (main 992cdd7) + bộ chọn phân hệ (design/he-thong-giao-dien).
 *
 * Nhóm route "(ung-dung)" nằm trong ngoặc nên KHÔNG xuất hiện trong đường dẫn.
 *
 *   - Điện thoại (< 1024px): đầu trang navy + thanh tab dưới đáy (Việc chờ · phân hệ · Thêm).
 *     Đổi phân hệ / Đổi mật khẩu / Đăng xuất nằm ở trang /them.
 *   - Máy tính (≥ 1024px): thanh trên navy + dải màu nhấn + thanh bên có bộ chọn phân hệ.
 */
export default async function KhungUngDung({ children }: { children: React.ReactNode }) {
  const [phien, phanHe] = await Promise.all([batBuocPhien(), layPhanHeDuocPhep()]);
  const menuTheoPhanHe = await layMenuPhanHe(phanHe.map((p) => p.ma));

  return (
    <KhungPhanHe>
      <DauTrangDienThoai tenHienThi={phien.tenHienThi} />

      <header className="thanh-tren hidden lg:flex">
        <span className="logo-tc" aria-hidden="true">
          BV
        </span>
        <span className="text-base font-bold">{TEN_APP}</span>
        <span className="flex-1" />
        <span className="min-w-0 truncate text-sm">{phien.tenHienThi}</span>
        <form action={dangXuat}>
          <button type="submit" className="nut-tren-nen-toi">
            <BieuTuong ten="out" co={18} />
            Đăng xuất
          </button>
        </form>
      </header>
      <DaiNhan />

      <div className="flex flex-1">
        <ThanhBen phanHe={phanHe} phienBan={PHIEN_BAN} menuTheoPhanHe={menuTheoPhanHe} />

        {/* pb điện thoại: chừa chỗ cho thanh tab dán đáy (6 + 56 + 14px + vùng an
            toàn), nếu không nội dung cuối trang bị nó che mất. */}
        <main className="noi-dung min-w-0 flex-1 px-4 pt-4 pb-[calc(92px+env(safe-area-inset-bottom))] lg:px-8 lg:pt-6 lg:pb-10">
          {children}
        </main>
      </div>

      <ThanhTabDuoi phanHe={phanHe} />
    </KhungPhanHe>
  );
}
