import type { Metadata } from "next";

import { duongDanNoiBo } from "@/shared/an-toan-duong-dan";
import { PHIEN_BAN, TEN_APP } from "@/shared/phien-ban";

import { FormDangNhap } from "./form-dang-nhap";

export const metadata: Metadata = { title: `Đăng nhập — ${TEN_APP}` };

/**
 * ĐĂNG NHẬP CHUNG cho cả 3 phân hệ — chép bố cục từ app Tài chính (một cột,
 * ô cao 48, thẻ 420px đặt giữa trên máy tính).
 *
 * Tên hiển thị và logo CHƯA CHỐT: tạm chữ "Base Vina", ô logo navy chữ "BV".
 */
export default async function TrangDangNhap({
  searchParams,
}: {
  // Next.js 15+ : searchParams là Promise, phải await.
  searchParams: Promise<{ tiep_tuc?: string }>;
}) {
  const { tiep_tuc } = await searchParams;

  return (
    <main className="flex min-h-screen flex-col px-5">
      <div className="flex flex-1 flex-col justify-center py-8">
        <div className="mx-auto w-full max-w-[420px]">
          <div className="mb-6 flex flex-col items-center text-center lg:flex-row lg:gap-3.5 lg:text-left">
            <span className="logo-lon lg:h-[52px] lg:w-[52px] lg:rounded-xl lg:text-xl" aria-hidden="true">
              BV
            </span>
            <div className="mt-3.5 lg:mt-0">
              <h1 className="text-2xl font-bold text-navy-dam">{TEN_APP}</h1>
              <p className="mt-0.5 text-[15px] text-muc-nhat">Tài chính · Nhân sự · Kho</p>
            </div>
          </div>

          <div className="the p-4 lg:p-[22px]">
            <FormDangNhap tiepTuc={duongDanNoiBo(tiep_tuc)} />
          </div>

          <p className="mt-4 text-center text-sm text-muc-nhat">
            Quên mật khẩu? Liên hệ Quản trị.
          </p>
        </div>
      </div>

      {/* Dấu phiên bản — để hỏi nhanh "máy anh đang ở bản nào" khi WebView giữ bản cũ. */}
      <p className="phien-ban pb-[calc(22px+env(safe-area-inset-bottom))] text-center">
        {PHIEN_BAN}
      </p>
    </main>
  );
}
