import { createBrowserClient } from "@supabase/ssr";

import { layCauHinhSupabase } from "./env";

/**
 * Supabase client dùng phía TRÌNH DUYỆT (client component).
 *
 * Chỉ dùng anon key. Mọi quyền truy cập dữ liệu do RLS trên Postgres quyết định,
 * không phụ thuộc vào việc client ẩn hay hiện nút bấm.
 */
export function taoSupabaseClient() {
  const { url, anonKey } = layCauHinhSupabase();
  return createBrowserClient(url, anonKey);
}
