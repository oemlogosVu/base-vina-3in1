import { createClient } from '@ns/lib/supabase/server'
import type { AttendanceDay, AttendanceLog } from '@ns/types/database'

/**
 * Truy vấn chấm công phía server. Đi qua client thường nên RLS vẫn áp dụng.
 *
 * Từ 11/08/2026 không còn địa điểm và toạ độ. Lần chấm chỉ được tính công
 * khi nhân sự xác nhận — `da_xac_nhan` là cờ quyết định, và mặc định là
 * false lúc ghi.
 */

export type LogRut = Pick<
  AttendanceLog,
  | 'id'
  | 'employee_id'
  | 'check_type'
  | 'logged_at'
  | 'da_xac_nhan'
  | 'selfie_path'
  | 'xac_nhan_luc'
  | 'ghi_chu_xac_nhan'
>

const COT_LOG =
  'id, employee_id, check_type, logged_at, da_xac_nhan, selfie_path, xac_nhan_luc, ghi_chu_xac_nhan'

export async function layLogCuaToi(gioiHan = 30): Promise<LogRut[]> {
  const supabase = await createClient()
  const { data, error } = await supabase
    .from('attendance_logs')
    .select(COT_LOG)
    .order('logged_at', { ascending: false })
    .limit(gioiHan)

  if (error) throw new Error(`Không đọc được lịch sử chấm công: ${error.message}`)
  return data ?? []
}

export async function layBangCongCuaToi(gioiHan = 31): Promise<AttendanceDay[]> {
  const supabase = await createClient()
  const { data, error } = await supabase
    .from('attendance_days')
    .select('*')
    .order('work_date', { ascending: false })
    .limit(gioiHan)

  if (error) throw new Error(`Không đọc được bảng công: ${error.message}`)
  return data ?? []
}

export type LogChoXacNhan = LogRut & {
  employees: { employee_code: string; full_name: string } | null
}

/**
 * Hàng đợi xác nhận của nhân sự: MỌI lần chấm chưa ai xử lý.
 *
 * Khác trước 11/08: trước đây chỉ những lần chấm bị máy đánh dấu nghi ngờ
 * mới vào đây. Giờ máy không phán xét nữa nên mọi lần chấm đều phải qua đây.
 *
 * Điều kiện là `xac_nhan_luc is null`, không phải `da_xac_nhan = false`: lần
 * chấm mà nhân sự đã xem và quyết định không công nhận thì không được quay
 * lại hàng đợi, nếu không họ sẽ xem đi xem lại cùng một dòng mãi.
 */
export async function layHangDoiXacNhan(gioiHan = 200): Promise<LogChoXacNhan[]> {
  const supabase = await createClient()
  const { data, error } = await supabase
    .from('attendance_logs')
    .select(`${COT_LOG}, employees ( employee_code, full_name )`)
    .is('xac_nhan_luc', null)
    .order('logged_at', { ascending: false })
    .limit(gioiHan)

  if (error) throw new Error(`Không đọc được hàng đợi xác nhận: ${error.message}`)
  return data ?? []
}

/**
 * Những lần chấm ĐÃ xác nhận của một ngày.
 *
 * Cần cho việc xoá: hàng đợi ở trên chỉ có lần chấm chưa ai xem, mà lần chấm
 * chưa xác nhận thì vốn không được tính công — xoá nó chẳng đổi gì. Lần chấm
 * SAI mà đã trót xác nhận mới là thứ đang cộng nhầm giờ vào bảng lương, và
 * trước bản này không màn nào nhìn thấy nó.
 *
 * Lọc theo ngày giờ Việt Nam, không phải theo UTC: một lần bấm lúc 07:30 sáng
 * ngày 12 ở VN là 00:30 UTC cùng ngày, nhưng bấm lúc 23:30 tối ngày 12 lại là
 * 16:30 UTC — cắt theo UTC sẽ đẩy ca đêm sang ngày hôm sau.
 */
export async function layLogDaXacNhanTheoNgay(
  ngay: string,
  gioiHan = 200,
): Promise<LogChoXacNhan[]> {
  const supabase = await createClient()
  const dau = `${ngay}T00:00:00+07:00`
  const cuoi = `${ngay}T23:59:59.999+07:00`

  const { data, error } = await supabase
    .from('attendance_logs')
    .select(`${COT_LOG}, employees ( employee_code, full_name )`)
    .not('xac_nhan_luc', 'is', null)
    .gte('logged_at', dau)
    .lte('logged_at', cuoi)
    .order('logged_at', { ascending: true })
    .limit(gioiHan)

  if (error) throw new Error(`Không đọc được lần chấm đã xác nhận: ${error.message}`)
  return data ?? []
}

/**
 * Link xem ảnh chấm công cho NHIỀU đường dẫn cùng lúc, hết hạn sau 60 giây.
 *
 * Dùng `createSignedUrls` số nhiều: một lượt gọi Storage cho cả danh sách.
 * Bản đầu gọi `createSignedUrl` số ít cho từng ảnh — màn xác nhận có 200 lần
 * chấm là 200 lượt gọi, và đó là một trong những chỗ chậm thật của app chứ
 * không phải chậm cảm giác.
 *
 * Bucket là private nên không có URL cố định nào đọc được ảnh. Việc cấp link
 * vẫn phải đi qua policy: người không có quyền nhận null chứ không nhận link
 * hỏng. Hạn 60 giây vì link đã cấp là link ai cầm cũng mở được.
 *
 * Trả về Map để nơi gọi tra theo đường dẫn, khỏi phải giữ đúng thứ tự mảng.
 */
export async function layLinkAnhHangLoat(
  duongDans: readonly (string | null)[],
): Promise<Map<string, string>> {
  const canLay = [...new Set(duongDans.filter((d): d is string => d !== null))]
  if (canLay.length === 0) return new Map()

  const supabase = await createClient()
  const { data } = await supabase.storage
    .from('attendance-selfies')
    .createSignedUrls(canLay, 60)

  const ketQua = new Map<string, string>()
  for (const m of data ?? []) {
    if (m.path && m.signedUrl && !m.error) ketQua.set(m.path, m.signedUrl)
  }
  return ketQua
}

/** Nhân viên đang đăng nhập có phải chấm công không. */
export async function coPhaiChamCong(employeeId: string | null): Promise<boolean> {
  if (!employeeId) return false
  const supabase = await createClient()
  const { data } = await supabase
    .from('employees')
    .select('theo_doi_cham_cong')
    .eq('id', employeeId)
    .maybeSingle()
  // Không đọc được (RLS chặn hoặc chưa có hồ sơ) thì coi như phải chấm công —
  // hiện nút bấm rồi bị Edge Function từ chối vẫn tốt hơn là giấu nút của
  // người đáng lẽ phải chấm.
  return data?.theo_doi_cham_cong ?? true
}

/**
 * Công ty của người đang đăng nhập, để màn xác nhận nói rõ phạm vi.
 *
 * Hàm `xac_nhan_cham_cong_ngay` giới hạn theo công ty này. Trả về null khi
 * tài khoản chưa gắn hồ sơ nhân sự (tài khoản quản trị thuần) — người đó xác
 * nhận được toàn hệ thống, và màn hình phải nói ra điều đó chứ không để nó
 * lặng lẽ.
 */
export async function layCongTyCuaToi(
  employeeId: string | null,
): Promise<{ id: string; name: string } | null> {
  if (!employeeId) return null
  const supabase = await createClient()
  const { data } = await supabase
    .from('employees')
    .select('companies ( id, name )')
    .eq('id', employeeId)
    .maybeSingle()
  return (data?.companies as { id: string; name: string } | null) ?? null
}

/**
 * Bảng công của một ngày, chỉ những dòng CÓ phút làm thêm.
 *
 * Dùng cho khối đặt tỷ lệ % làm thêm: không có phút làm thêm thì tỷ lệ chẳng
 * nhân vào đâu, hiện ra chỉ làm rối.
 */
export type NgayCoLamThem = {
  id: string
  employee_id: string
  work_date: string
  ot_minutes: number
  worked_minutes: number
  status: string
  ty_le_lam_them_pct: number | null
  employees: { employee_code: string; full_name: string } | null
}

export async function layNgayCoLamThem(ngay: string): Promise<NgayCoLamThem[]> {
  const supabase = await createClient()
  const { data, error } = await supabase
    .from('attendance_days')
    .select(
      'id, employee_id, work_date, ot_minutes, worked_minutes, status, ty_le_lam_them_pct, employees ( employee_code, full_name )',
    )
    .eq('work_date', ngay)
    .gt('ot_minutes', 0)
    .order('employee_id')

  if (error) throw new Error(`Không đọc được bảng công có làm thêm: ${error.message}`)
  return (data ?? []) as NgayCoLamThem[]
}

/**
 * Hệ số làm thêm giờ mặc định tại một ngày.
 *
 * Qua RPC chứ không đọc thẳng `cfg_overtime_rates`: bảng đó chỉ kế toán và
 * admin đọc được, trong khi màn xác nhận chấm công là của HR. Hàm RPC mở
 * đúng ba con số hệ số, không mở cả bảng tham số lương.
 *
 * Không có tham số hiệu lực thì trả 0 — màn hình sẽ hiện ô trống thay vì một
 * con số bịa.
 */
export async function layHeSoLamThem(
  ngay: string,
): Promise<{ ngayThuong: number; ngayNghiTuan: number }> {
  const supabase = await createClient()
  const { data } = await supabase.rpc('he_so_lam_them_hieu_luc', { p_ngay: ngay })
  const d = data?.[0]
  return {
    ngayThuong: Number(d?.ngay_thuong_pct ?? 0),
    ngayNghiTuan: Number(d?.ngay_nghi_tuan_pct ?? 0),
  }
}
