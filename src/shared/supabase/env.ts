/**
 * Đọc biến môi trường Supabase và báo lỗi RÕ RÀNG nếu thiếu.
 *
 * Vì sao cần file này: thiếu biến môi trường thì Supabase ném lỗi rất khó hiểu
 * ("Invalid URL"), mất hàng giờ để lần ra nguyên nhân. Chặn sớm ngay tại đây.
 */

function doc(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(
      `Thiếu biến môi trường ${name}. ` +
        `Kiểm tra file .env.local (local) hoặc Environment Variables trên Vercel (deploy). ` +
        `Xem file .env.example để biết danh sách biến cần có.`,
    );
  }
  return value;
}

export function layCauHinhSupabase(): { url: string; anonKey: string } {
  return {
    url: doc("NEXT_PUBLIC_SUPABASE_URL"),
    anonKey: doc("NEXT_PUBLIC_SUPABASE_ANON_KEY"),
  };
}
