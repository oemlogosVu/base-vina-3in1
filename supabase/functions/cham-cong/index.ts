/**
 * Edge Function `cham-cong` — đường DUY NHẤT ghi được vào attendance_logs.
 *
 * Vì sao vẫn phải đi qua đây dù không còn kiểm tra GPS: client tự insert thì
 * tự đặt được `logged_at` và `da_xac_nhan`, tức tự tạo công khống. Bảng đã
 * thu hồi quyền INSERT của `authenticated`; hàm này dùng `service_role`.
 *
 * Thay đổi 11/08/2026 theo yêu cầu của Triệu Vũ:
 *   - Bỏ toàn bộ phần địa điểm và GPS. Không còn thu thập toạ độ nữa —
 *     không dùng để đối chiếu thì thu thập là dữ liệu cá nhân không có mục
 *     đích, trái nguyên tắc tối thiểu của NĐ 13/2023.
 *   - Ảnh chấm công thành TUỲ CHỌN.
 *   - Lần chấm chỉ được tính công khi nhân sự XÁC NHẬN, nên `da_xac_nhan`
 *     luôn là false lúc ghi. Máy không phán xét gì nữa; người quyết định.
 *
 * Mức bảo vệ hiện tại, nói thẳng để không ai hiểu nhầm: **giờ máy chủ** và
 * **nhân sự xác nhận từng ngày**. Không có gì khác. Đây là lựa chọn có ý
 * thức — GPS trên nền tảng web giả mạo được bằng DevTools nên nó chưa bao
 * giờ là bảo vệ thật, chỉ là vẻ ngoài của bảo vệ.
 */

import { createClient } from 'jsr:@supabase/supabase-js@2'

/** Hai lần chấm cùng chiều sát nhau là bấm nhầm, không phải hai sự kiện. */
const KHOANG_CACH_BAM_TOI_THIEU_GIAY = 60

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const traLoi = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  })

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  if (req.method !== 'POST') return traLoi({ loi: 'Chỉ nhận POST.' }, 405)

  const url = Deno.env.get('SUPABASE_URL')
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')
  if (!url || !serviceKey || !anonKey) {
    return traLoi({ loi: 'Thiếu biến môi trường của Edge Function.' }, 500)
  }

  // ---- 1. Xác thực người gọi ----
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return traLoi({ loi: 'Chưa đăng nhập.' }, 401)

  const clientNguoiDung = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  })
  const { data: { user }, error: loiAuth } = await clientNguoiDung.auth.getUser()
  if (loiAuth || !user) return traLoi({ loi: 'Phiên đăng nhập không hợp lệ.' }, 401)

  const admin = createClient(url, serviceKey, { auth: { persistSession: false } })

  // ---- 2. Người này gắn với hồ sơ nào, và có phải chấm công không ----
  const { data: taiKhoan } = await admin
    .from('app_users')
    .select('employee_id, is_active')
    .eq('id', user.id)
    .maybeSingle()

  if (!taiKhoan?.is_active) return traLoi({ loi: 'Tài khoản chưa được kích hoạt.' }, 403)
  if (!taiKhoan.employee_id) {
    return traLoi({ loi: 'Tài khoản chưa gắn với hồ sơ nhân sự. Liên hệ nhân sự.' }, 403)
  }
  const employeeId: string = taiKhoan.employee_id

  const { data: nhanVien } = await admin
    .from('employees')
    .select('theo_doi_cham_cong, deleted_at')
    .eq('id', employeeId)
    .maybeSingle()

  // Hàm này dùng khoá service_role nên nó BỎ QUA RLS — policy ẩn hồ sơ đã xoá
  // không che được ở đây. Không lọc tường minh thì người đã bị xoá hồ sơ vẫn
  // chấm công được, và lần chấm đó nằm lại trong bảng không ai truy ra chủ.
  if (nhanVien?.deleted_at) {
    return traLoi({ loi: 'Hồ sơ nhân sự của bạn đã bị xoá. Liên hệ nhân sự.' }, 403)
  }

  // Chặn ở đây thay vì để họ bấm rồi log nằm im không ai xử lý: người được
  // miễn chấm công mà vẫn thấy nút bấm sẽ tưởng mình phải chấm.
  if (nhanVien && nhanVien.theo_doi_cham_cong === false) {
    return traLoi(
      { loi: 'Công việc của bạn không áp dụng chấm công. Lương tính theo ngày công chuẩn.' },
      403,
    )
  }

  // ---- 3. Đọc dữ liệu client gửi lên ----
  // Chỉ đọc hai trường. Mọi thứ khác client gửi kèm — logged_at,
  // da_xac_nhan — đều bị bỏ qua, không phải bị từ chối: từ chối sẽ mách cho
  // người thử biết trường nào đáng nhắm tới.
  let body: Record<string, unknown>
  try {
    body = await req.json()
  } catch {
    return traLoi({ loi: 'Thân yêu cầu không phải JSON.' }, 400)
  }

  // Bốn loại, KHÔNG phải hai.
  //
  // LỖI đã sửa 12/08/2026: bản trước chỉ nhận 'in' và 'out', trong khi màn
  // chấm công có hai nút "Bắt đầu thêm giờ" / "Kết thúc thêm giờ" gửi lên
  // 'ot_in' / 'ot_out'. Nghĩa là tính năng chấm thêm giờ KHÔNG dùng được từ
  // ngày phát hành, dù bộ kiểm tra P2 có 8 phép về làm thêm giờ đều xanh —
  // chúng chèn thẳng vào bảng bằng SQL thay vì gọi hàm này như điện thoại.
  //
  // Danh sách lấy từ enum của database, không gõ rời rạc ở đây.
  const LOAI_CHAM = ['in', 'out', 'ot_in', 'ot_out'] as const
  const checkType = body.check_type
  if (typeof checkType !== 'string' || !LOAI_CHAM.includes(checkType as typeof LOAI_CHAM[number])) {
    return traLoi({ loi: `check_type phải là một trong: ${LOAI_CHAM.join(', ')}.` }, 400)
  }

  // Ảnh là TUỲ CHỌN. Không có ảnh vẫn chấm công được.
  const selfie = typeof body.selfie_base64 === 'string' && body.selfie_base64.length > 0
    ? body.selfie_base64
    : null

  const deviceInfo =
    body.device_info !== null && typeof body.device_info === 'object' ? body.device_info : {}

  // ---- 4. Chống bấm nhầm hai lần ----
  const { data: lanTruoc } = await admin
    .from('attendance_logs')
    .select('logged_at, check_type')
    .eq('employee_id', employeeId)
    .order('logged_at', { ascending: false })
    .limit(1)
    .maybeSingle()

  const bayGio = new Date()

  if (lanTruoc && lanTruoc.check_type === checkType) {
    const giay = (bayGio.getTime() - new Date(lanTruoc.logged_at).getTime()) / 1000
    if (giay < KHOANG_CACH_BAM_TOI_THIEU_GIAY) {
      return traLoi({ loi: 'Vừa chấm xong. Đợi một chút rồi thử lại.' }, 429)
    }
  }

  // ---- 5. Lưu ảnh nếu có ----
  const logId = crypto.randomUUID()
  let anhDaLuu: string | null = null
  let canhBaoAnh: string | null = null

  if (selfie) {
    const duongDanAnh = `${employeeId}/${bayGio.getUTCFullYear()}/${logId}.jpg`
    try {
      const base64 = selfie.includes(',') ? selfie.split(',')[1]! : selfie
      const bytes = Uint8Array.from(atob(base64), (c) => c.charCodeAt(0))
      const { error: loiUpload } = await admin.storage
        .from('attendance-selfies')
        .upload(duongDanAnh, bytes, { contentType: 'image/jpeg', upsert: false })
      if (loiUpload) throw loiUpload
      anhDaLuu = duongDanAnh
    } catch (e) {
      // Không chặn việc chấm công vì lỗi lưu ảnh: ảnh là tuỳ chọn, còn lần
      // chấm thì đã xảy ra rồi.
      canhBaoAnh = 'Không lưu được ảnh, nhưng đã ghi nhận lần chấm công.'
      console.error('Lỗi lưu ảnh chấm công:', e instanceof Error ? e.message : String(e))
    }
  }

  // ---- 6. Ghi log ----
  const { data: log, error: loiGhi } = await admin
    .from('attendance_logs')
    .insert({
      id: logId,
      employee_id: employeeId,
      check_type: checkType,
      // logged_at để mặc định now() của database — một nguồn giờ duy nhất,
      // và KHÔNG bao giờ lấy từ client.
      selfie_path: anhDaLuu,
      device_info: deviceInfo,
      // Luôn false. Chỉ nhân sự xác nhận mới thành true.
      da_xac_nhan: false,
    })
    .select('id, logged_at, da_xac_nhan')
    .single()

  if (loiGhi) {
    console.error('Lỗi ghi attendance_logs:', loiGhi.message)
    return traLoi({ loi: 'Không ghi được lần chấm công. Thử lại sau.' }, 500)
  }

  return traLoi({
    id: log.id,
    logged_at: log.logged_at,
    da_xac_nhan: log.da_xac_nhan,
    co_anh: anhDaLuu !== null,
    canh_bao: canhBaoAnh,
    thong_bao: 'Đã ghi nhận. Chờ nhân sự xác nhận thì mới được tính công.',
  })
})
