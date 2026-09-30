/**
 * Edge Function `quan-tri-tai-khoan` — tạo tài khoản đăng nhập và đặt lại
 * mật khẩu.
 *
 * VÌ SAO PHẢI ĐI QUA ĐÂY, trong khi vai trò và việc nối hồ sơ thì sửa thẳng
 * qua PostgREST được: hai việc này đụng tới `auth.users`, mà bảng đó chỉ
 * `service_role` mới ghi được. Và `service_role` thì tuyệt đối không được
 * xuống trình duyệt (AGENTS.md mục 10) — nó bỏ qua toàn bộ RLS, ai cầm được
 * nó là đọc được lương và CCCD của cả công ty.
 *
 * Ranh giới cố ý: hàm này CHỈ lo phần `auth.users` cộng đúng một câu cập nhật
 * vai trò ngay sau khi tạo. Mọi việc còn lại của màn quản trị người dùng —
 * đổi vai trò, nối hồ sơ, khoá/mở — đi qua RLS như mọi bảng khác. Chỗ nào
 * RLS diễn đạt được thì để RLS làm.
 *
 * Chạy bằng `service_role` nghĩa là KHÔNG có policy nào chặn hộ. Mọi điều
 * kiện phân quyền ở đây phải tự viết ra.
 *
 * Không log email, không log mật khẩu, không log id — nhật ký Edge Function
 * lưu ngoài phạm vi kiểm soát của dự án.
 */

import { createClient } from 'jsr:@supabase/supabase-js@2'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const VAI_TRO_HOP_LE = ['nhan_vien', 'truong_phong', 'hr', 'ke_toan', 'admin']

const traLoi = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  })

/**
 * Mật khẩu ngẫu nhiên đủ mạnh, hiện MỘT lần cho admin chép đi trao tay.
 *
 * Project chưa cấu hình SMTP nên không có email mời và không có "quên mật
 * khẩu". Bắt admin tự nghĩ mật khẩu cho từng người là con đường ngắn nhất
 * dẫn tới cả công ty dùng chung một chuỗi dễ đoán.
 *
 * 16 ký tự, và ghép cứng mỗi nhóm một ký tự để luôn vượt chính sách của
 * project (chữ thường + hoa + số) — không phụ thuộc vào may rủi của bốc ngẫu
 * nhiên. Dùng `crypto.getRandomValues`, không dùng `Math.random()`: đây là
 * mật khẩu, không phải một con số cho vui.
 *
 * Bỏ các ký tự nhìn giống nhau (0/O, 1/l/I) vì mật khẩu này được đọc và gõ
 * lại bằng tay.
 */
function matKhauNgauNhien(): string {
  const THUONG = 'abcdefghijkmnpqrstuvwxyz'
  const HOA = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
  const SO = '23456789'
  const TAT_CA = THUONG + HOA + SO

  const boc = (bang: string) => {
    const r = new Uint32Array(1)
    crypto.getRandomValues(r)
    return bang[r[0]! % bang.length]!
  }

  const kyTu = [boc(THUONG), boc(HOA), boc(SO)]
  while (kyTu.length < 16) kyTu.push(boc(TAT_CA))

  // Xáo Fisher–Yates để ba ký tự bắt buộc không luôn nằm ở đầu.
  for (let i = kyTu.length - 1; i > 0; i--) {
    const r = new Uint32Array(1)
    crypto.getRandomValues(r)
    const j = r[0]! % (i + 1)
    ;[kyTu[i], kyTu[j]] = [kyTu[j]!, kyTu[i]!]
  }
  return kyTu.join('')
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  if (req.method !== 'POST') return traLoi({ loi: 'Chỉ nhận POST.' }, 405)

  const url = Deno.env.get('SUPABASE_URL')
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')
  if (!url || !serviceKey || !anonKey) {
    return traLoi({ loi: 'Thiếu biến môi trường của Edge Function.' }, 500)
  }

  // ---- 1. Người gọi là ai ----
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return traLoi({ loi: 'Chưa đăng nhập.' }, 401)

  const clientNguoiDung = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  })
  const {
    data: { user },
    error: loiAuth,
  } = await clientNguoiDung.auth.getUser()
  if (loiAuth || !user) return traLoi({ loi: 'Phiên đăng nhập không hợp lệ.' }, 401)

  const admin = createClient(url, serviceKey, { auth: { persistSession: false } })

  // ---- 2. Chỉ admin đang hoạt động ----
  //
  // Kiểm cả `is_active`: một tài khoản admin đã bị khoá vẫn còn `role='admin'`
  // trong bảng. Chỉ so vai trò là để lọt người đã bị thu hồi quyền.
  const { data: nguoiGoi } = await admin
    .from('app_users')
    .select('role, is_active')
    .eq('id', user.id)
    .maybeSingle()

  if (!nguoiGoi?.is_active || nguoiGoi.role !== 'admin') {
    return traLoi({ loi: 'Chỉ quản trị hệ thống mới cấp được tài khoản.' }, 403)
  }

  // ---- 3. Đọc yêu cầu ----
  let body: Record<string, unknown>
  try {
    body = await req.json()
  } catch {
    return traLoi({ loi: 'Thân yêu cầu không phải JSON.' }, 400)
  }

  const hanhDong = typeof body.hanh_dong === 'string' ? body.hanh_dong : null
  const chuoi = (ten: string): string | null => {
    const v = body[ten]
    return typeof v === 'string' && v.trim() !== '' ? v.trim() : null
  }

  // ---- 4a. Tạo tài khoản ----
  if (hanhDong === 'tao') {
    const email = chuoi('email')?.toLowerCase() ?? null
    const hoTen = chuoi('ho_ten')
    const vaiTro = chuoi('vai_tro')
    // Bỏ trống là để hàm tự sinh — đường đi được khuyến khích.
    const matKhauChon = chuoi('mat_khau')

    if (!email) return traLoi({ loi: 'Thiếu email đăng nhập.' }, 400)
    if (!hoTen) return traLoi({ loi: 'Thiếu họ tên.' }, 400)
    if (!vaiTro || !VAI_TRO_HOP_LE.includes(vaiTro)) {
      return traLoi({ loi: 'Vai trò không hợp lệ.' }, 400)
    }

    const matKhau = matKhauChon ?? matKhauNgauNhien()

    const { data: taoRa, error: loiTao } = await admin.auth.admin.createUser({
      email,
      password: matKhau,
      // Hệ thống nội bộ, chưa cấu hình SMTP nên không gửi được thư xác minh.
      // Để `false` là tạo ra một tài khoản không bao giờ đăng nhập được.
      email_confirm: true,
      user_metadata: { full_name: hoTen },
    })

    if (loiTao || !taoRa?.user) {
      // Thông điệp của Supabase Auth nói đúng lý do (email trùng, mật khẩu
      // yếu hơn chính sách project). Chép lại một bản kiểm tra ở đây là tạo
      // ra bản thứ hai của chính sách, và bản thứ hai sẽ lệch.
      return traLoi({ loi: loiTao?.message ?? 'Không tạo được tài khoản.' }, 400)
    }

    // Trigger `on_auth_user_created` vừa tạo dòng app_users với vai trò thấp
    // nhất và `is_active=false`. Nâng lên đúng vai trò admin đã chọn.
    const { error: loiVaiTro } = await admin
      .from('app_users')
      .update({ role: vaiTro, is_active: true, full_name: hoTen })
      .eq('id', taoRa.user.id)

    if (loiVaiTro) {
      // Tài khoản đã tồn tại nhưng đang bị khoá — vô hại, và admin sửa được
      // ngay trên màn hình. Nói thẳng tình trạng đó thay vì báo "xong".
      return traLoi(
        {
          loi: `Đã tạo tài khoản nhưng chưa đặt được vai trò: ${loiVaiTro.message}. Tài khoản đang bị khoá, hãy đặt vai trò và kích hoạt trong danh sách bên dưới.`,
        },
        500,
      )
    }

    // Chỉ trả mật khẩu khi hàm tự sinh. Admin đã tự gõ thì họ có sẵn rồi,
    // gửi ngược lại chỉ thêm một chỗ nữa để nó rò ra.
    return traLoi({ id: taoRa.user.id, mat_khau: matKhauChon ? null : matKhau })
  }

  // ---- 4b. Đặt lại mật khẩu ----
  if (hanhDong === 'dat-lai-mat-khau') {
    const userId = chuoi('user_id')
    if (!userId) return traLoi({ loi: 'Thiếu tài khoản cần đặt lại.' }, 400)

    // Chỉ đặt lại cho tài khoản CÓ TRONG app_users. Không có bước này thì
    // tham số `user_id` là một ô nhập tự do trỏ vào toàn bộ `auth.users`.
    const { data: dich } = await admin
      .from('app_users')
      .select('id')
      .eq('id', userId)
      .maybeSingle()

    if (!dich) return traLoi({ loi: 'Không tìm thấy tài khoản.' }, 404)

    const matKhau = chuoi('mat_khau') ?? matKhauNgauNhien()
    const tuSinh = chuoi('mat_khau') === null

    const { error: loiDat } = await admin.auth.admin.updateUserById(userId, {
      password: matKhau,
    })
    if (loiDat) return traLoi({ loi: loiDat.message }, 400)

    return traLoi({ mat_khau: tuSinh ? matKhau : null })
  }

  return traLoi({ loi: 'Hành động không hợp lệ.' }, 400)
})
