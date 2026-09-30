/**
 * Edge Function `anh-cham-cong-to` — đường DUY NHẤT ghi được ảnh xác minh
 * chấm công tổ đội, và cột `phien_cham_cong_to.anh_path`.
 *
 * VÌ SAO PHẢI ĐI QUA ĐÂY, trong khi số công thì người chấm ghi thẳng qua
 * PostgREST được: đường dẫn ảnh đoán được từ (mã tổ, ngày). Nếu người chấm
 * tự upload và tự đặt `anh_path`, họ làm được hai việc mà không ai thấy —
 * ghi đè ảnh của một ngày đã duyệt, và trỏ ảnh của tổ này sang ngày khác.
 * Cả hai đều là sửa bằng chứng. Nên bucket không có policy INSERT nào cho
 * `authenticated`, và cột `anh_path` không nằm trong quyền cấp cột.
 *
 * Ranh giới cố ý: hàm này CHỈ lo cái file và cột đường dẫn. Số công vẫn đi
 * qua RLS như mọi bảng khác — chỗ nào RLS diễn đạt được thì để RLS làm.
 *
 * Nói thẳng mức bảo vệ, không nói quá: ảnh chứng minh có người chụp một tấm
 * ảnh vào lúc nào, KHÔNG chứng minh từng người trong tổ có mặt thật. Trình
 * duyệt không ép được ảnh phải chụp tại chỗ. Nó nâng chi phí gian lận chứ
 * không chặn được, và giao diện sẽ không nói khác điều đó.
 */

import { createClient } from 'jsr:@supabase/supabase-js@2'

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

  const { data: taiKhoan } = await admin
    .from('app_users')
    .select('role, is_active')
    .eq('id', user.id)
    .maybeSingle()

  if (!taiKhoan?.is_active) return traLoi({ loi: 'Tài khoản chưa được kích hoạt.' }, 403)

  // ---- 2. Đọc yêu cầu ----
  let body: Record<string, unknown>
  try {
    body = await req.json()
  } catch {
    return traLoi({ loi: 'Thân yêu cầu không phải JSON.' }, 400)
  }

  const phienId = typeof body.phien_id === 'string' ? body.phien_id : null
  const anhBase64 =
    typeof body.anh_base64 === 'string' && body.anh_base64.length > 0 ? body.anh_base64 : null

  if (!phienId) return traLoi({ loi: 'Thiếu phien_id.' }, 400)
  if (!anhBase64) return traLoi({ loi: 'Thiếu ảnh.' }, 400)

  // ---- 3. Người này có được ghi ảnh cho phiên này không ----
  //
  // Hàm chạy bằng service_role nên nó BỎ QUA RLS — mọi điều kiện mà policy
  // vẫn lo hộ ở chỗ khác thì ở đây phải tự viết ra, không được cho rằng
  // database đã chặn giúp.
  //
  // ⚠️ ĐỌC `error`, đừng chỉ đọc `data`. Bản đầu của hàm này viết
  // `const { data: phien } = await ...` và bỏ qua `error`. Khi cột
  // `to_doi.nguoi_cham_cong_id` bị gỡ ngày 19/08, PostgREST bắt đầu trả lỗi
  // "cột không tồn tại", `data` thành null, và hàm báo "Không tìm thấy phiên
  // chấm công" cho MỌI lần gọi. Tính năng ảnh hỏng từ ngày ra đời tới
  // 22/08/2026 vì đúng một dòng nuốt lỗi.
  const { data: phien, error: loiDoc } = await admin
    .from('phien_cham_cong_to')
    .select('id, to_doi_id, work_date, da_duyet')
    .eq('id', phienId)
    .maybeSingle()

  if (loiDoc) {
    console.error('Lỗi đọc phiên chấm công:', loiDoc.message)
    return traLoi({ loi: `Không đọc được phiên chấm công: ${loiDoc.message}` }, 500)
  }
  if (!phien) return traLoi({ loi: 'Không tìm thấy phiên chấm công.' }, 404)

  // Đã duyệt là chốt. Cho ghi đè ảnh sau khi duyệt là cho sửa bằng chứng của
  // một ngày công đã được công nhận.
  if (phien.da_duyet) {
    return traLoi({ loi: 'Phiên đã duyệt, không thay được ảnh nữa.' }, 409)
  }

  // Luật "ai được ghi ảnh" nằm ở MỘT chỗ: hàm `duoc_ghi_anh_phien` trong
  // database. Bản trước chép luật ấy bằng TypeScript và chép thiếu — nó so
  // với một cột đã bị gỡ, và không biết gì về quyền `xac_nhan_cham_cong` mà
  // P1d thêm vào. Gọi thẳng vào SQL thì không có bản thứ hai để lệch.
  const { data: duocGhi, error: loiQuyen } = await admin.rpc('duoc_ghi_anh_phien', {
    p_phien_id: phienId,
    p_user_id: user.id,
  })

  if (loiQuyen) {
    console.error('Lỗi kiểm quyền ghi ảnh:', loiQuyen.message)
    return traLoi({ loi: `Không kiểm được quyền: ${loiQuyen.message}` }, 500)
  }
  if (duocGhi !== true) {
    return traLoi({ loi: 'Bạn không được giao chấm công cho tổ này.' }, 403)
  }

  // ---- 4. Lưu ảnh ----
  //
  // Đường dẫn suy ra từ (tổ, ngày) chứ không mang id ngẫu nhiên: một tổ một
  // ngày chỉ có một ảnh, nên tên file trùng đúng bằng khoá nghiệp vụ. `upsert`
  // bật để người chấm chụp lại được khi ảnh mờ — an toàn vì tới được đây
  // nghĩa là phiên chưa duyệt.
  const thang = String(phien.work_date).slice(0, 7)
  const duongDan = `${phien.to_doi_id}/${thang}/${phien.work_date}.jpg`

  try {
    const base64 = anhBase64.includes(',') ? anhBase64.split(',')[1]! : anhBase64
    const bytes = Uint8Array.from(atob(base64), (c) => c.charCodeAt(0))
    const { error: loiUpload } = await admin.storage
      .from('to-doi-cham-cong')
      .upload(duongDan, bytes, { contentType: 'image/jpeg', upsert: true })
    if (loiUpload) throw loiUpload
  } catch (e) {
    console.error('Lỗi lưu ảnh chấm công tổ:', e instanceof Error ? e.message : String(e))
    return traLoi({ loi: 'Không lưu được ảnh. Kiểm tra mạng rồi thử lại.' }, 500)
  }

  // ---- 5. Ghi đường dẫn vào phiên ----
  //
  // Làm SAU khi upload thành công. Ngược lại thì phiên trỏ tới một file không
  // tồn tại, và ràng buộc "duyệt phải có ảnh" hoá ra cho duyệt một phiên
  // không có ảnh thật.
  const { error: loiGhi } = await admin
    .from('phien_cham_cong_to')
    .update({ anh_path: duongDan })
    .eq('id', phienId)

  if (loiGhi) {
    console.error('Lỗi ghi anh_path:', loiGhi.message)
    return traLoi({ loi: 'Đã tải ảnh lên nhưng không ghi được vào phiên. Thử lại.' }, 500)
  }

  return traLoi({ anh_path: duongDan })
})
