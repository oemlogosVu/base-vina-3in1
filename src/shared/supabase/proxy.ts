import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

import { layCauHinhSupabase } from "./env";

/**
 * Làm mới phiên đăng nhập trên mỗi request và chặn người chưa đăng nhập.
 *
 * VÌ SAO CẦN: token đăng nhập của Supabase hết hạn sau ~1 giờ. Không có chỗ nào
 * làm mới nó thì người dùng đang thao tác giữa chừng bị văng ra đăng nhập lại —
 * tệ nhất là lúc đang gửi duyệt một đề nghị vừa nhập xong.
 *
 * ĐÂY KHÔNG PHẢI PHÂN QUYỀN. Tài liệu Next.js gọi đây là "optimistic check":
 * nó chỉ chuyển hướng cho nhanh, không quyết định ai được làm gì. Phân quyền
 * thật nằm ở RLS và ở kiểm tra vai trò bên trong từng RPC — đã chứng minh bằng
 * bộ test nghiệm thu Phase 1 (nhân viên gọi thẳng hàm duyệt vẫn bị từ chối, dù
 * có lách qua được lớp này).
 */

// Trang không cần đăng nhập. (App 3 trong 1 không có trang "quên mật khẩu":
// tài khoản SĐT dùng tên miền nội bộ, không nhận thư — quản trị đặt lại.)
const DUONG_DAN_CONG_KHAI = ["/dang-nhap"];

export async function lamMoiPhienDangNhap(request: NextRequest) {
  let response = NextResponse.next({ request });

  const { url, anonKey } = layCauHinhSupabase();

  const supabase = createServerClient(url, anonKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet) {
        // Ghi cookie mới vào CẢ request lẫn response. Thiếu một trong hai thì
        // token vừa làm mới không tới được trang đang render, và người dùng bị
        // đăng xuất ngẫu nhiên — lỗi rất khó lần ra.
        for (const { name, value } of cookiesToSet) {
          request.cookies.set(name, value);
        }
        response = NextResponse.next({ request });
        for (const { name, value, options } of cookiesToSet) {
          response.cookies.set(name, value, options);
        }
      },
    },
  });

  // PHẢI dùng getUser(), KHÔNG dùng getSession().
  // getSession() chỉ đọc cookie và tin vào nội dung trong đó — cookie thì người
  // dùng sửa được. getUser() hỏi thẳng máy chủ Supabase để xác thực token.
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const duongDan = request.nextUrl.pathname;
  const laTrangCongKhai = DUONG_DAN_CONG_KHAI.some((p) => duongDan.startsWith(p));

  if (!user && !laTrangCongKhai) {
    const dich = request.nextUrl.clone();
    dich.pathname = "/dang-nhap";
    // Nhớ chỗ người dùng định vào, đăng nhập xong đưa họ về đúng đó.
    dich.searchParams.set("tiep_tuc", duongDan);
    return NextResponse.redirect(dich);
  }

  if (user && duongDan.startsWith("/dang-nhap")) {
    const dich = request.nextUrl.clone();
    dich.pathname = "/";
    dich.searchParams.delete("tiep_tuc");
    return NextResponse.redirect(dich);
  }

  return response;
}
