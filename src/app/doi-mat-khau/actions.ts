"use server";

import { batBuocPhien } from "@/shared/auth/phien";
import { taoSupabaseServerClient } from "@/shared/supabase/server";

export type TrangThaiForm = { loi: string | null; xong?: string };

/**
 * Đổi mật khẩu của chính người đang đăng nhập.
 *
 * Chép từ app Nhân sự (src/app/doi-mat-khau/actions.ts, main 9a0b9a8), đổi tên trường.
 *
 * Bắt nhập LẠI mật khẩu hiện tại trước khi đổi, dù Supabase không đòi. Lý do:
 * không có bước này thì ai ngồi vào máy đang mở sẵn phiên đều đổi được mật
 * khẩu và chiếm luôn tài khoản. Với tài khoản đọc được toàn bộ bảng lương thì
 * một màn hình bỏ quên là đủ.
 *
 * Không tự kiểm độ mạnh ở đây: Supabase Auth đã kiểm theo chính sách thật của
 * project và trả về lỗi. Chép lại quy tắc vào code là tạo bản sao thứ hai của
 * một thứ có thể đổi.
 */
export async function doiMatKhau(_truocDo: TrangThaiForm, form: FormData): Promise<TrangThaiForm> {
  const phien = await batBuocPhien();

  const hienTai = String(form.get("mat_khau_hien_tai") ?? "");
  const moi = String(form.get("mat_khau_moi") ?? "");
  const nhacLai = String(form.get("nhac_lai") ?? "");

  if (hienTai === "" || moi === "") return { loi: "Nhập đủ mật khẩu hiện tại và mật khẩu mới." };
  if (moi !== nhacLai) return { loi: "Hai lần nhập mật khẩu mới không giống nhau." };
  if (moi === hienTai) return { loi: "Mật khẩu mới trùng mật khẩu cũ." };

  const supabase = await taoSupabaseServerClient();

  // Lấy email từ phiên chứ không cho người dùng gửi lên: nhận email từ form
  // là mở đường đổi mật khẩu của người khác.
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user?.email) return { loi: "Phiên đăng nhập không hợp lệ. Đăng nhập lại rồi thử." };

  const { error: loiXacThuc } = await supabase.auth.signInWithPassword({
    email: user.email,
    password: hienTai,
  });
  if (loiXacThuc) return { loi: "Mật khẩu hiện tại không đúng." };

  const { error } = await supabase.auth.updateUser({ password: moi });
  if (error) {
    // Supabase trả nguyên văn lý do không đạt chính sách. Hiện đúng câu đó
    // thay vì một câu chung chung — người dùng cần biết thiếu gì.
    return { loi: `Không đổi được mật khẩu: ${error.message}` };
  }

  return {
    loi: null,
    xong: `Đã đổi mật khẩu cho ${phien.tenHienThi}. Lần đăng nhập sau dùng mật khẩu mới.`,
  };
}
