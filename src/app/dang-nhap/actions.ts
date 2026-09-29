"use server";

import { redirect } from "next/navigation";

import { taoSupabaseServerClient } from "@/shared/supabase/server";
import { emailTuId } from "@/shared/auth/id-dang-nhap";
import { duongDanNoiBo } from "@/shared/an-toan-duong-dan";

export type KetQuaDangNhap = { loi: string } | undefined;

/**
 * Đăng nhập bằng ID (email HOẶC số điện thoại) + mật khẩu.
 *
 * Chạy trên máy chủ ("use server"): mật khẩu đi thẳng từ trình duyệt tới máy chủ
 * rồi sang Supabase, không có đoạn mã nào trên máy người dùng chạm vào nó.
 *
 * ID là SĐT thì quy đổi sang email tổng hợp (xem `emailTuId`) rồi mới đăng nhập.
 */
export async function dangNhap(
  _truocDo: KetQuaDangNhap,
  formData: FormData,
): Promise<KetQuaDangNhap> {
  const id = String(formData.get("id") ?? "").trim();
  const matKhau = String(formData.get("mat_khau") ?? "");
  const tiepTuc = String(formData.get("tiep_tuc") ?? "/");

  if (!id || !matKhau) {
    return { loi: "Vui lòng nhập đầy đủ email/số điện thoại và mật khẩu." };
  }

  const supabase = await taoSupabaseServerClient();
  const { error } = await supabase.auth.signInWithPassword({
    email: emailTuId(id),
    password: matKhau,
  });

  if (error) {
    // KHÔNG nói rõ "email này không tồn tại" hay "mật khẩu sai".
    // Nói rõ là giúp người ngoài dò ra danh sách email có thật trong hệ thống,
    // rồi tập trung đoán mật khẩu đúng những email đó.
    return { loi: "Email/số điện thoại hoặc mật khẩu không đúng. Vui lòng thử lại." };
  }

  // Chỉ nhận đường dẫn nội bộ. Không kiểm thì người ta gửi link
  // /dang-nhap?tiep_tuc=https://trang-lua-dao.com — đăng nhập xong bị ném thẳng
  // sang trang giả mạo, mà người dùng tưởng vẫn đang trong app của công ty.
  redirect(duongDanNoiBo(tiepTuc));
}

export async function dangXuat() {
  const supabase = await taoSupabaseServerClient();
  await supabase.auth.signOut();
  redirect("/dang-nhap");
}
