import { cookies } from "next/headers";
import { createServerClient } from "@supabase/ssr";

import { layCauHinhSupabase } from "./env";

/**
 * Supabase client dùng phía MÁY CHỦ (server component, server action, route handler).
 *
 * Phiên đăng nhập nằm trong cookie; client này đọc cookie để mọi truy vấn chạy
 * đúng danh tính người đang đăng nhập — đây là căn cứ để RLS và các hàm RPC
 * xác định auth.uid(). Vì vậy KHÔNG được dùng chung một client giữa nhiều
 * request: mỗi lần render phải tạo mới.
 */
export async function taoSupabaseServerClient() {
  const { url, anonKey } = layCauHinhSupabase();
  const cookieStore = await cookies();

  return createServerClient(url, anonKey, {
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(cookiesToSet) {
        try {
          for (const { name, value, options } of cookiesToSet) {
            cookieStore.set(name, value, options);
          }
        } catch {
          // Server Component không được phép ghi cookie. Bỏ qua an toàn:
          // việc làm mới token đã do middleware đảm nhiệm (thiết lập ở Phase 2).
        }
      },
    },
  });
}
