import { redirect } from "next/navigation";

import { taoSupabaseServerClient } from "@/shared/supabase/server";

export type Phien = {
  id: string;
  /** Email đăng nhập (tài khoản SĐT là "<số>@sodienthoai.local"). */
  email: string;
  /** Tên hiển thị trên khung: tên trong hồ sơ Auth, không có thì chính ID đăng nhập. */
  tenHienThi: string;
};

const MIEN_SDT = "@sodienthoai.local";

/** ID đăng nhập để hiển thị: tài khoản SĐT hiện lại số điện thoại, không hiện miền nội bộ. */
export function idHienThi(email: string): string {
  return email.endsWith(MIEN_SDT) ? email.slice(0, -MIEN_SDT.length) : email;
}

/**
 * Người đang đăng nhập, hoặc null.
 *
 * PHẢI dùng getUser() (hỏi thẳng máy chủ Supabase), KHÔNG dùng getSession() —
 * getSession() chỉ đọc cookie, mà cookie người dùng sửa được (AGENTS.md mục 4).
 *
 * GĐ1 chỉ đọc thông tin của Auth, chưa đọc bảng của phân hệ nào (nhan_vien của
 * Tài chính, app_users của Nhân sự): phân quyền nội bộ từng phân hệ giữ nguyên,
 * chép sang cùng phân hệ đó.
 */
export async function layPhien(): Promise<Phien | null> {
  const supabase = await taoSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const email = user.email ?? "";
  const ten = user.user_metadata?.full_name ?? user.user_metadata?.ho_ten;
  return {
    id: user.id,
    email,
    tenHienThi: typeof ten === "string" && ten.trim() ? ten.trim() : idHienThi(email),
  };
}

/** Như layPhien() nhưng chưa đăng nhập thì đưa về /dang-nhap. */
export async function batBuocPhien(): Promise<Phien> {
  const phien = await layPhien();
  if (!phien) redirect("/dang-nhap");
  return phien;
}
