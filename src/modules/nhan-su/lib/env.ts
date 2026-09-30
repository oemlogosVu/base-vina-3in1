/**
 * Đọc biến môi trường công khai một lần, fail sớm và rõ ràng.
 *
 * Chỉ chấp nhận biến NEXT_PUBLIC_*. service_role key không bao giờ được
 * đọc ở đây — nó chỉ tồn tại trong Edge Function, do Supabase tự tiêm
 * (AGENTS.md mục 2.3).
 */

function required(name: string, value: string | undefined): string {
  if (!value || value.trim() === '') {
    throw new Error(
      `Thiếu biến môi trường ${name}. Chép .env.example thành .env.local và điền giá trị từ Supabase Dashboard → Settings → API.`,
    )
  }
  return value
}

// Next.js thay thế process.env.NEXT_PUBLIC_* lúc build nên phải viết đầy đủ,
// không được truy cập động qua biến.
export const supabaseUrl = (): string =>
  required('NEXT_PUBLIC_SUPABASE_URL', process.env.NEXT_PUBLIC_SUPABASE_URL)

export const supabaseAnonKey = (): string =>
  required('NEXT_PUBLIC_SUPABASE_ANON_KEY', process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY)
