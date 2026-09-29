import Link from "next/link";

import { dangXuat } from "@/app/dang-nhap/actions";
import { layPhanHeDuocPhep } from "@/shared/phan-he";
import { PHIEN_BAN } from "@/shared/phien-ban";
import { BieuTuong } from "@/shared/ui/bieu-tuong";

import { OPhanHe } from "../dieu-huong";

/**
 * Trang «Thêm» (điện thoại): chọn phân hệ, đổi mật khẩu, đăng xuất.
 * Là TRANG RIÊNG, không phải lớp phủ/popup (design BoChonPhanHe + KhungUngDung).
 */
export default async function TrangThem() {
  const phanHe = await layPhanHeDuocPhep();

  return (
    <div className="flex flex-col gap-6">
      <section>
        <p className="nhan-nhom mb-2">Chọn phân hệ</p>
        <div className="the p-1">
          {phanHe.map((p) => (
            <Link key={p.ma} href={p.duongDan} data-phan-he={p.ma} className="muc-phan-he">
              <OPhanHe ph={p} lop="o-phan-he-lon" />
              <span className="min-w-0">
                <span className="block">{p.ten}</span>
                <span className="block text-[13px] font-normal text-muc-nhat">{p.moTa}</span>
              </span>
            </Link>
          ))}
        </div>
      </section>

      <section>
        <p className="nhan-nhom mb-2">Tài khoản</p>
        <div className="the p-1">
          <Link href="/doi-mat-khau" className="muc-phan-he">
            <BieuTuong ten="key" />
            <span>Đổi mật khẩu</span>
          </Link>
          <form action={dangXuat}>
            <button type="submit" className="muc-phan-he w-full text-left">
              <BieuTuong ten="out" />
              <span>Đăng xuất</span>
            </button>
          </form>
        </div>
      </section>

      <p className="phien-ban text-center">{PHIEN_BAN}</p>
    </div>
  );
}
