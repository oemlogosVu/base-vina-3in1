import type { NextRequest } from "next/server";

import { lamMoiPhienDangNhap } from "@/shared/supabase/proxy";

/**
 * Chạy trước mọi request: làm mới phiên đăng nhập, đá người chưa đăng nhập về
 * trang đăng nhập.
 *
 * LƯU Ý CHO NGƯỜI ĐỌC SAU: file này tên `proxy.ts`, KHÔNG phải `middleware.ts`.
 * Next.js 16 đã đổi tên (xem node_modules/next/dist/docs/01-app/02-guides/
 * upgrading/version-16.md, mục "middleware to proxy"). Hàm cũng phải tên `proxy`.
 * Đặt lại tên cũ thì Next.js vẫn chạy nhưng đó là đường đã bị khai tử.
 */
export async function proxy(request: NextRequest) {
  return await lamMoiPhienDangNhap(request);
}

export const config = {
  matcher: [
    /*
     * Chạy trên mọi đường dẫn TRỪ:
     *   _next/static, _next/image  — file tĩnh, không cần biết ai đăng nhập
     *   favicon, manifest, icon    — PWA cần đọc được khi CHƯA đăng nhập,
     *                                nếu chặn thì điện thoại không cài app được
     *   file ảnh
     * Vì sao loại trừ: mỗi lần chạy là một lần gọi sang máy chủ Supabase để xác
     * thực token. Chạy cho cả file ảnh là phí, và làm trang tải chậm hẳn.
     */
    "/((?!_next/static|_next/image|favicon.ico|manifest.webmanifest|icons/|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico)$).*)",
  ],
};
