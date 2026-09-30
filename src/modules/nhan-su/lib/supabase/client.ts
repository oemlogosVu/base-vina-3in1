import { createBrowserClient } from '@supabase/ssr'
import { supabaseAnonKey, supabaseUrl } from '@ns/lib/env'
import type { Database } from '@ns/types/database'

/**
 * Supabase client cho Client Component.
 * Chỉ dùng anon key — mọi quyền đọc/ghi do RLS quyết định, không do code này.
 */
export function createClient() {
  return createBrowserClient<Database>(supabaseUrl(), supabaseAnonKey())
}
