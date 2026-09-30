import { cookies } from 'next/headers'
import { createServerClient } from '@supabase/ssr'
import { supabaseAnonKey, supabaseUrl } from '@ns/lib/env'
import type { Database } from '@ns/types/database'

/**
 * Supabase client cho Server Component / Server Action / Route Handler.
 *
 * Vẫn dùng anon key + phiên của người dùng, KHÔNG dùng service_role.
 * Nhờ vậy mọi truy vấn phía server vẫn đi qua RLS — đúng nguyên tắc
 * "frontend phải đi qua RLS" (AGENTS.md mục 7).
 */
export async function createClient() {
  const cookieStore = await cookies()

  return createServerClient<Database>(supabaseUrl(), supabaseAnonKey(), {
    cookies: {
      getAll() {
        return cookieStore.getAll()
      },
      setAll(cookiesToSet) {
        try {
          for (const { name, value, options } of cookiesToSet) {
            cookieStore.set(name, value, options)
          }
        } catch {
          // Server Component không được phép ghi cookie. Bỏ qua an toàn:
          // middleware đã làm mới phiên trước khi request tới đây.
          // Không nuốt lỗi khác — khối này chỉ bao đúng thao tác ghi cookie.
        }
      },
    },
  })
}
