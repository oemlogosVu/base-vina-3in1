import type { Metadata } from "next";
import Link from "next/link";

import { batBuocPhien } from "@/shared/auth/phien";
import { TEN_APP } from "@/shared/phien-ban";
import { BieuTuong } from "@/shared/ui/bieu-tuong";

import { FormDoiMatKhau } from "./bieu-mau";

export const metadata: Metadata = { title: `Đổi mật khẩu — ${TEN_APP}` };

/**
 * Đổi mật khẩu của chính mình — dùng chung cho cả 3 phân hệ (một tài khoản).
 *
 * Ai đăng nhập được cũng vào được: khoá đường tự đổi mật khẩu là buộc người ta
 * nhờ quản trị cho một việc lẽ ra tự làm được. Tài khoản SĐT dùng tên miền nội bộ
 * không nhận được thư nên không có đường "quên mật khẩu" qua email.
 */
export default async function TrangDoiMatKhau() {
  const phien = await batBuocPhien();

  // CHỈ để hiển thị và để trình duyệt cảnh báo sớm — bản chép chính sách mật khẩu
  // của project Supabase chung (project Nhân sự: 12 ký tự). Kiểm thật do Supabase
  // Auth làm khi lưu, lỗi trả về được hiện nguyên văn.
  const TOI_THIEU_HIEN_THI = 12;

  return (
    <main className="flex min-h-screen flex-col px-5">
      <div className="mx-auto w-full max-w-[420px] py-8">
        <Link href="/" className="nut-chu -ml-3 mb-2">
          <BieuTuong ten="back" />
          Về trang chủ
        </Link>
        <h1 className="text-2xl font-bold text-navy-dam">Đổi mật khẩu</h1>
        <p className="mt-0.5 mb-5 text-[15px] text-muc-nhat">Tài khoản {phien.tenHienThi}</p>

        <div className="the p-4 lg:p-[22px]">
          <FormDoiMatKhau toiThieu={TOI_THIEU_HIEN_THI} />
        </div>

        <p className="mt-4 text-sm text-muc-nhat">
          Quên mật khẩu thì nhờ Quản trị đặt lại — tài khoản số điện thoại không nhận được thư.
        </p>
      </div>
    </main>
  );
}
