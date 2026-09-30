import { taoSupabaseServerClient } from "@/shared/supabase/server";

import { DS_PHAN_HE, type PhanHe, type ThongTinPhanHe } from "./phan-he";

// CHỈ dùng ở máy chủ (đọc database). Tách khỏi phan-he.ts vì thanh điều hướng (chạy trên trình duyệt) import phan-he.ts.

/**
 * Phân hệ người dùng được vào — đọc bảng public.quyen_phan_he (dòng của chính mình; RLS chỉ cho đọc
 * dòng của mình).
 *
 * GIAI ĐOẠN 2: chỉ Nhân sự lọc theo bảng (Nhân sự đã ghép). Tài chính, Kho, Hệ thống vẫn hiện trang
 * giữ chỗ cho mọi người đến khi ghép (GĐ3–5) — lúc đó lọc nốt.
 *
 * ĐÂY KHÔNG PHẢI PHÂN QUYỀN: ẩn phân hệ chỉ để gọn giao diện. Quyền thật nằm ở RLS/RPC
 * của từng phân hệ và ở kiểm tra phiên trong API Kho.
 */
export async function layPhanHeDuocPhep(): Promise<ThongTinPhanHe[]> {
  const supabase = await taoSupabaseServerClient();
  const { data } = await supabase.from("quyen_phan_he").select("phan_he").eq("dang_dung", true);
  const coQuyen = new Set((data ?? []).map((d: { phan_he: string }) => d.phan_he));
  const DA_GHEP: PhanHe[] = ["ns"];
  return DS_PHAN_HE.filter((p) => !DA_GHEP.includes(p.ma) || coQuyen.has(p.ma));
}
