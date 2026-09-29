"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

import { phanHeTuDuongDan, type ThongTinPhanHe } from "@/shared/phan-he";
import { BieuTuong, type TenBieuTuong } from "@/shared/ui/bieu-tuong";

/**
 * KHUNG ĐIỀU HƯỚNG CHUNG — dựng theo dieu-huong.tsx của app Tài chính (main 992cdd7)
 * + bộ chọn phân hệ của bộ giao diện 3 trong 1 (design/he-thong-giao-dien, thẻ
 * KhungUngDung + BoChonPhanHe):
 *   - KhungPhanHe:       gắn data-phan-he theo đường dẫn → CSS tô màu nhấn
 *   - DauTrangDienThoai: đầu trang navy — ô chữ tắt + tên trang + "Tên người"
 *   - ThanhTabDuoi:      Việc chờ · các phân hệ · Thêm, dán đáy màn điện thoại
 *   - ThanhBen:          Việc chờ tôi · bộ chọn phân hệ · menu phân hệ, chỉ máy tính
 *
 * Là client component chỉ để biết trang đang mở (usePathname).
 * Không modal, không popup: bộ chọn phân hệ là <details> gốc mở tại chỗ; điện thoại
 * đổi phân hệ ở trang riêng /them.
 */

export type MucDieuHuong = { duongDan: string; nhan: string; bieuTuong: TenBieuTuong };

function khop(duongDan: string, muc: string): boolean {
  return muc === "/" ? duongDan === "/" : duongDan === muc || duongDan.startsWith(`${muc}/`);
}

/** Mục của trang đang mở = mục khớp DÀI NHẤT (/tai-chinh/duyet thắng /tai-chinh). */
function mucDangMo(duongDan: string, ds: { duongDan: string }[]): string | null {
  let tot: string | null = null;
  for (const m of ds) {
    if (khop(duongDan, m.duongDan) && (!tot || m.duongDan.length > tot.length)) tot = m.duongDan;
  }
  return tot;
}

/**
 * Menu bên trong từng phân hệ. GĐ1 mỗi phân hệ chỉ có trang giữ chỗ; menu thật chép
 * sang cùng phân hệ (GĐ2 Nhân sự, GĐ3 Tài chính, GĐ4 Kho, GĐ5 Hệ thống).
 */
function menuPhanHe(ph: ThongTinPhanHe): MucDieuHuong[] {
  return [{ duongDan: ph.duongDan, nhan: "Tổng quan", bieuTuong: "home" }];
}

const TIEU_DE_KHAC: { duongDan: string; nhan: string }[] = [
  { duongDan: "/", nhan: "Việc chờ tôi" },
  { duongDan: "/them", nhan: "Thêm" },
];

/** Bọc toàn khung: data-phan-he của trang đang mở (không có = trang chung, màu navy). */
export function KhungPhanHe({ children }: { children: React.ReactNode }) {
  const ph = phanHeTuDuongDan(usePathname());
  return (
    <div className="flex min-h-screen flex-col" data-phan-he={ph?.ma}>
      {children}
    </div>
  );
}

/** Ô chữ tắt phân hệ. Tự mang data-phan-he của chính nó (không ăn theo khung). */
export function OPhanHe({ ph, lop }: { ph: ThongTinPhanHe; lop?: string }) {
  return (
    <span className={`o-phan-he ${lop ?? ""}`} data-phan-he={ph.ma} aria-hidden="true">
      {ph.chuTat}
    </span>
  );
}

export function DauTrangDienThoai({ tenHienThi }: { tenHienThi: string }) {
  const duongDan = usePathname();
  const ph = phanHeTuDuongDan(duongDan);
  const khopNhat = mucDangMo(duongDan, TIEU_DE_KHAC);
  const tieuDe = ph ? ph.ten : (TIEU_DE_KHAC.find((m) => m.duongDan === khopNhat)?.nhan ?? "Base Vina");

  return (
    <header className="dau-trang lg:hidden">
      {ph ? (
        <OPhanHe ph={ph} lop="o-phan-he-tren-toi" />
      ) : (
        <span className="logo-tc" aria-hidden="true">
          BV
        </span>
      )}
      <div className="min-w-0">
        <p className="tieu-de truncate">{tieuDe}</p>
        <p className="phu truncate">{tenHienThi}</p>
      </div>
    </header>
  );
}

export function ThanhTabDuoi({ phanHe }: { phanHe: ThongTinPhanHe[] }) {
  const duongDan = usePathname();
  // Tối đa 3 phân hệ trên thanh (Hệ thống mở từ "Thêm") để mỗi tab đủ rộng ≥ 44px.
  const tab: MucDieuHuong[] = [
    { duongDan: "/", nhan: "Việc chờ", bieuTuong: "home" },
    ...phanHe
      .filter((p) => p.ma !== "ht")
      .slice(0, 3)
      .map((p) => ({ duongDan: p.duongDan, nhan: p.ten, bieuTuong: p.bieuTuong })),
  ];
  const them: MucDieuHuong = { duongDan: "/them", nhan: "Thêm", bieuTuong: "more" };
  const dangMo = mucDangMo(duongDan, tab);

  return (
    <nav aria-label="Điều hướng chính" className="thanh-tab lg:hidden">
      {[...tab, them].map((m) => {
        // Trang không có tab riêng (Hệ thống, Đổi mật khẩu…) được mở từ "Thêm" —
        // nên tô "Thêm" để người dùng biết mình đang ở nhánh nào.
        const chon = m.duongDan === them.duongDan ? dangMo === null : dangMo === m.duongDan;
        return (
          <Link
            key={m.duongDan}
            href={m.duongDan}
            aria-current={chon ? "page" : undefined}
            className="tab-duoi"
          >
            <span className="khung-bieu-tuong">
              <BieuTuong ten={m.bieuTuong} co={24} />
            </span>
            <span className="max-w-full truncate px-0.5">{m.nhan}</span>
          </Link>
        );
      })}
    </nav>
  );
}

export function ThanhBen({ phanHe, phienBan }: { phanHe: ThongTinPhanHe[]; phienBan: string }) {
  const duongDan = usePathname();
  const ph = phanHeTuDuongDan(duongDan);
  const menu = ph ? menuPhanHe(ph) : [];
  const dangMo = mucDangMo(duongDan, [{ duongDan: "/" }, ...menu, { duongDan: "/doi-mat-khau" }]);

  return (
    <nav aria-label="Điều hướng chính" className="thanh-ben hidden lg:flex">
      {/* "Việc chờ tôi" không thuộc phân hệ nào — đứng TRÊN bộ chọn, màu navy. */}
      <ul className="mb-3.5">
        <li>
          <Link href="/" aria-current={dangMo === "/" ? "page" : undefined} className="muc-ben">
            <BieuTuong ten="home" />
            <span className="min-w-0 flex-1 truncate">Việc chờ tôi</span>
          </Link>
        </li>
      </ul>

      {/* Chỉ 1 phân hệ thì không cần bộ chọn (design BoChonPhanHe). */}
      {phanHe.length > 1 && (
        // key đổi theo phân hệ → vào phân hệ khác thì bộ chọn tự đóng lại.
        <details key={ph?.ma ?? "chung"} className="chon-phan-he">
          <summary>
            {ph ? (
              <OPhanHe ph={ph} />
            ) : (
              <span className="o-phan-he" aria-hidden="true">
                <BieuTuong ten="more" co={16} />
              </span>
            )}
            <span className="min-w-0">
              <span className="ten block">{ph ? ph.ten : "Chọn phân hệ"}</span>
              <span className="phu block">{ph ? "Đổi phân hệ" : `${phanHe.length} phân hệ`}</span>
            </span>
            <BieuTuong ten="down" co={18} className="mui-ten" />
          </summary>
          <div className="ds">
            {phanHe.map((p) => (
              <Link
                key={p.ma}
                href={p.duongDan}
                data-phan-he={p.ma}
                aria-current={ph?.ma === p.ma ? "page" : undefined}
                className="muc-phan-he"
              >
                <OPhanHe ph={p} />
                <span>{p.ten}</span>
              </Link>
            ))}
          </div>
        </details>
      )}

      {ph && (
        <div className="nhom-ben">
          <p className="nhan-nhom-ben">{ph.ten}</p>
          <ul>
            {menu.map((m) => (
              <li key={m.duongDan}>
                <Link
                  href={m.duongDan}
                  aria-current={dangMo === m.duongDan ? "page" : undefined}
                  className="muc-ben"
                >
                  <BieuTuong ten={m.bieuTuong} />
                  <span className="min-w-0 flex-1 truncate">{m.nhan}</span>
                </Link>
              </li>
            ))}
          </ul>
        </div>
      )}

      <div className="nhom-ben">
        <p className="nhan-nhom-ben">Tài khoản</p>
        <Link
          href="/doi-mat-khau"
          aria-current={dangMo === "/doi-mat-khau" ? "page" : undefined}
          className="muc-ben"
        >
          <BieuTuong ten="key" />
          Đổi mật khẩu
        </Link>
      </div>

      <p className="phien-ban mt-auto pt-6 pl-2.5">{phienBan}</p>
    </nav>
  );
}

/** Dải 4px màu nhấn dưới thanh trên (máy tính) — chỉ khi đang ở trong một phân hệ. */
export function DaiNhan() {
  const ph = phanHeTuDuongDan(usePathname());
  return ph ? <div className="dai-nhan hidden lg:block" aria-hidden="true" /> : null;
}
