"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

import { BieuTuong } from "@/components/ui/bieu-tuong";
import type { HuyHieu, MucDieuHuong, NhomDieuHuong } from "@/lib/auth/menu";

/**
 * KHUNG ĐIỀU HƯỚNG (PROMPT giao diện mới mục 4). Ba phần, cùng một nguồn là
 * boCucDieuHuong() trong lib/auth/menu.ts:
 *   - DauTrangDienThoai: đầu trang navy — tên trang + "Tên người · Vai trò"
 *   - ThanhTabDuoi:      tối đa 4 tab + "Thêm", dán đáy màn điện thoại
 *   - ThanhBen:          thanh bên trái chia nhóm, chỉ trên máy tính
 *
 * Là client component chỉ để biết trang đang mở (usePathname) mà tô tab.
 */

function khop(duongDan: string, muc: string): boolean {
  return muc === "/" ? duongDan === "/" : duongDan === muc || duongDan.startsWith(`${muc}/`);
}

/** Mục của trang đang mở = mục khớp DÀI NHẤT (/bao-cao/so-quy thắng /bao-cao). */
function mucDangMo(duongDan: string, ds: { duongDan: string }[]): string | null {
  let tot: string | null = null;
  for (const m of ds) {
    if (khop(duongDan, m.duongDan) && (!tot || m.duongDan.length > tot.length)) tot = m.duongDan;
  }
  return tot;
}

function SoHuyHieu({ hh }: { hh?: HuyHieu }) {
  if (!hh || hh.so <= 0) return null;
  return (
    <span className={`huy-hieu ${hh.gap ? "huy-hieu-gap" : ""}`}>
      {hh.so > 99 ? "99+" : hh.so}
      <span className="sr-only"> việc đang chờ</span>
    </span>
  );
}

/** Tên trang cho những đường dẫn không phải một tab. */
const TIEU_DE_KHAC: { duongDan: string; nhan: string }[] = [
  { duongDan: "/de-nghi/moi", nhan: "Lập đề nghị" },
  { duongDan: "/doi-mat-khau", nhan: "Đổi mật khẩu" },
  { duongDan: "/them", nhan: "Thêm" },
  { duongDan: "/design-system", nhan: "Hệ thống thiết kế" },
];

export function DauTrangDienThoai({
  hoTen,
  vaiTro,
  muc,
}: {
  hoTen: string;
  vaiTro: string;
  muc: MucDieuHuong[];
}) {
  const duongDan = usePathname();
  const ds = [...muc, ...TIEU_DE_KHAC];
  const khopNhat = mucDangMo(duongDan, ds);
  const tieuDe = ds.find((m) => m.duongDan === khopNhat)?.nhan ?? "Quản lý Thu Chi";

  return (
    <header className="dau-trang lg:hidden">
      <span className="logo-tc" aria-hidden="true">
        TC
      </span>
      <div className="min-w-0">
        <p className="tieu-de truncate">{tieuDe}</p>
        <p className="phu truncate">
          {hoTen} · {vaiTro}
        </p>
      </div>
    </header>
  );
}

export function ThanhTabDuoi({ tab, them }: { tab: MucDieuHuong[]; them: MucDieuHuong }) {
  const duongDan = usePathname();
  const dangMo = mucDangMo(duongDan, tab);

  return (
    <nav aria-label="Điều hướng chính" className="thanh-tab lg:hidden">
      {[...tab, them].map((m) => {
        // Trang không có tab riêng trên thanh (Thu tiền, Báo cáo...) được mở từ
        // "Thêm" — nên tô "Thêm" để người dùng biết mình đang ở nhánh nào.
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
              <SoHuyHieu hh={m.huyHieu} />
            </span>
            <span className="max-w-full truncate px-0.5">{m.nhan}</span>
          </Link>
        );
      })}
    </nav>
  );
}

export function ThanhBen({ nhom, phienBan }: { nhom: NhomDieuHuong[]; phienBan: string }) {
  const duongDan = usePathname();
  const dangMo = mucDangMo(duongDan, [
    ...nhom.flatMap((n) => n.muc),
    { duongDan: "/doi-mat-khau" },
  ]);

  return (
    <nav aria-label="Điều hướng chính" className="thanh-ben hidden lg:flex">
      {nhom.map((n) => (
        <div key={n.ten} className="nhom-ben">
          <p className="nhan-nhom-ben">{n.ten}</p>
          <ul>
            {n.muc.map((m) => (
              <li key={m.duongDan}>
                <Link
                  href={m.duongDan}
                  aria-current={dangMo === m.duongDan ? "page" : undefined}
                  className="muc-ben"
                >
                  <BieuTuong ten={m.bieuTuong} />
                  <span className="min-w-0 flex-1 truncate">{m.nhan}</span>
                  <SoHuyHieu hh={m.huyHieu} />
                </Link>
              </li>
            ))}
          </ul>
        </div>
      ))}

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
