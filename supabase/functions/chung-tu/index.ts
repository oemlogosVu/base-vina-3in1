/**
 * Edge Function `chung-tu` — đường DUY NHẤT sinh ra một chứng từ PDF.
 *
 * Triệu Vũ, 24/08/2026: "sau khi duyệt bảng lương tạo ngay file pdf lưu lại
 * như chứng từ."
 *
 * VÌ SAO PHẢI ĐI QUA ĐÂY
 *
 * Bucket `chung-tu` không có policy INSERT nào, và bảng `chung_tu` cũng vậy.
 * Cho người dùng tự upload là cho họ tự chế ra "chứng từ" mang con số bất kỳ —
 * đúng thứ mà cả P6a dựng lên để chống. Nên file và bản ghi cùng do
 * `service_role` ghi, ở đúng một chỗ, và chỗ đó là file này.
 *
 * KHÔNG GHI ĐÈ. Gọi lần hai cho cùng một đối tượng thì `ghi_chung_tu()` trả về
 * bản cũ và hàm này KHÔNG upload lại. Bất biến là toàn bộ giá trị của chứng
 * từ; một đường ghi đè, dù chỉ mở cho admin, là một đường sửa số tiền đã chốt.
 *
 * TỰ KIỂM QUYỀN. Hàm chạy bằng `service_role` nên nó BỎ QUA RLS — mọi điều
 * kiện mà policy vẫn lo hộ ở chỗ khác thì ở đây phải tự viết ra. Bài học
 * 22/08: hàm chạy quyền cao mà không tự kiểm là cửa hậu.
 */

import { createClient } from 'jsr:@supabase/supabase-js@2'
import { PDFDocument, rgb } from 'npm:pdf-lib@1.17.1'
import fontkit from 'npm:@pdf-lib/fontkit@1.1.1'
import { dinhDangTien, docSoTienBangChu } from '../_shared/so-tien-bang-chu.ts'

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

// ---------------------------------------------------------------------------
// Khổ giấy và lề — A4 ngang cho bảng nhiều cột, dọc cho kỳ lương.
// ---------------------------------------------------------------------------
const A4_NGANG: [number, number] = [841.89, 595.28]
const LE = 32

const DEN = rgb(0.08, 0.09, 0.11)
const XAM = rgb(0.42, 0.45, 0.5)
const VIEN = rgb(0.78, 0.8, 0.83)

/**
 * Đọc file font nằm cạnh file này.
 *
 * Font Roboto (OFL) được nhúng vì font chuẩn của PDF chỉ có bảng mã WinAnsi —
 * không có một chữ tiếng Việt có dấu nào. Chứng từ in "Nguy?n Th? Hà" thì
 * không dùng được, mà tệ hơn là nó HỎNG ÂM THẦM: file vẫn sinh ra, vẫn tải
 * về được, chỉ sai tên người nhận tiền.
 */
async function docFont(ten: string): Promise<Uint8Array> {
  return await Deno.readFile(new URL(`./${ten}`, import.meta.url))
}

function vanTay(bytes: Uint8Array): Promise<string> {
  return crypto.subtle.digest('SHA-256', bytes).then((h) =>
    Array.from(new Uint8Array(h)).map((b) => b.toString(16).padStart(2, '0')).join('')
  )
}

const ngayVN = (iso: string | null) => {
  if (!iso) return '—'
  const d = new Date(iso)
  const p = (n: number) => String(n).padStart(2, '0')
  return `${p(d.getUTCDate())}/${p(d.getUTCMonth() + 1)}/${d.getUTCFullYear()}`
}

type Cot = { nhan: string; rong: number; phai?: boolean }
type O = string | number

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
    .select('is_active')
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

  const loai = body.loai === 'ky_luong' || body.loai === 'bang_thanh_toan_to' ? body.loai : null
  const doiTuongId = typeof body.doi_tuong_id === 'string' ? body.doi_tuong_id : null
  if (!loai) return traLoi({ loi: 'Thiếu hoặc sai loai chứng từ.' }, 400)
  if (!doiTuongId) return traLoi({ loi: 'Thiếu doi_tuong_id.' }, 400)

  // ---- 3. Người này có được sinh chứng từ này không ----
  //
  // Hỏi bằng CHÍNH phiên của người gọi, không hỏi bằng service_role: hàm phân
  // quyền đọc `auth.uid()`, và service_role không có uid nào.
  //
  // Kỳ lương đòi quyền TÍNH LƯƠNG (chặt hơn quyền đọc): người sinh chứng từ là
  // người chịu trách nhiệm con số, không phải người được xem nó.
  const rpc = loai === 'ky_luong'
    ? await clientNguoiDung.rpc('can_manage_payroll')
    : await clientNguoiDung.rpc('co_the_doc_chung_tu', {
      p_loai: loai,
      p_doi_tuong_id: doiTuongId,
    })

  if (rpc.error) {
    console.error('Không hỏi được quyền:', rpc.error.message)
    return traLoi({ loi: `Không kiểm được quyền: ${rpc.error.message}` }, 500)
  }
  if (rpc.data !== true) {
    return traLoi({ loi: 'Bạn không có quyền sinh chứng từ cho mục này.' }, 403)
  }

  // ---- 4. Đã có chứng từ thì trả lại ngay, không dựng lại file ----
  const { data: daCo, error: loiTra } = await admin
    .from('chung_tu')
    .select('*')
    .eq('loai', loai)
    .eq('doi_tuong_id', doiTuongId)
    .maybeSingle()
  if (loiTra) return traLoi({ loi: `Không tra được chứng từ: ${loiTra.message}` }, 500)
  if (daCo) return traLoi({ chung_tu: daCo, da_co_tu_truoc: true })

  // ---- 5. Gom số liệu ----
  let tieuDe: string
  let phuDe: string[]
  let cot: Cot[]
  let dong: O[][]
  let tongTien = 0

  if (loai === 'bang_thanh_toan_to') {
    const { data: bang, error: loiBang } = await admin
      .from('bang_thanh_toan_to')
      .select('id, tu_ngay, den_ngay, tao_luc, ghi_chu, dong_cho_duyet, to_doi_id')
      .eq('id', doiTuongId)
      .maybeSingle()
    if (loiBang) return traLoi({ loi: `Không đọc được bảng: ${loiBang.message}` }, 500)
    if (!bang) return traLoi({ loi: 'Không tìm thấy bảng thanh toán.' }, 404)

    const { data: to } = await admin
      .from('to_doi')
      .select('code, name, company_id')
      .eq('id', bang.to_doi_id)
      .maybeSingle()
    const { data: cty } = to?.company_id
      ? await admin.from('companies').select('name, tax_code, address').eq('id', to.company_id)
        .maybeSingle()
      : { data: null }

    const { data: cacDong, error: loiDong } = await admin
      .from('dong_thanh_toan_to')
      .select('employee_id, so_luong, don_gia, kieu_tinh, so_gio_ot, don_gia_ot, thuong, thanh_tien')
      .eq('bang_id', doiTuongId)
    if (loiDong) return traLoi({ loi: `Không đọc được dòng: ${loiDong.message}` }, 500)

    const ids = (cacDong ?? []).map((d) => d.employee_id)
    const { data: nhanSu } = ids.length
      ? await admin.from('employees').select('id, employee_code, full_name').in('id', ids)
      : { data: [] }
    const ten = new Map((nhanSu ?? []).map((e) => [e.id, e]))

    tieuDe = 'BẢNG THANH TOÁN NHÂN CÔNG'
    phuDe = [
      `Tổ: ${to?.name ?? '—'}${to?.code ? ` (${to.code})` : ''}`,
      `Kỳ thanh toán: ${ngayVN(bang.tu_ngay)} — ${ngayVN(bang.den_ngay)}`,
      `Lập lúc: ${ngayVN(bang.tao_luc)}`,
    ]
    if (cty?.name) phuDe.unshift(`Đơn vị: ${cty.name}${cty.tax_code ? ` · MST ${cty.tax_code}` : ''}`)
    if (Number(bang.dong_cho_duyet) > 0) {
      // Nói thẳng trên chứng từ, không giấu xuống chân trang: bảng thiếu tiền
      // vì còn phiên chưa duyệt là chuyện người cầm bảng phải biết ngay.
      phuDe.push(`⚠ Còn ${bang.dong_cho_duyet} dòng công thuộc phiên CHƯA DUYỆT, không tính vào bảng này.`)
    }

    // Cột THƯỞNG phải có mặt, không được gộp lặng vào thành tiền (P5i).
    //
    // `thanh_tien` đã cộng thưởng vào rồi. Nếu tờ giấy chỉ in số lượng, đơn
    // giá và thành tiền thì người cầm nó nhân tay ra một con số KHÁC — và một
    // chứng từ mà phép cộng trên đó không ra tổng thì không chứng minh được gì.
    //
    // Bề rộng đã trừ lại ở ba cột khác để tổng vẫn lọt khổ A4 ngang
    // (841.89 − 2×32 = 777.89 điểm).
    cot = [
      { nhan: 'TT', rong: 30 },
      { nhan: 'Mã NV', rong: 70 },
      { nhan: 'Họ và tên', rong: 170 },
      { nhan: 'Kiểu', rong: 52 },
      { nhan: 'Số lượng', rong: 58, phai: true },
      { nhan: 'Đơn giá', rong: 72, phai: true },
      { nhan: 'Giờ NG', rong: 50, phai: true },
      { nhan: 'Đơn giá NG', rong: 72, phai: true },
      { nhan: 'Thưởng', rong: 76, phai: true },
      { nhan: 'Thành tiền', rong: 92, phai: true },
    ]

    dong = (cacDong ?? [])
      .map((d) => ({ d, e: ten.get(d.employee_id) }))
      .sort((a, b) => String(a.e?.full_name ?? '').localeCompare(String(b.e?.full_name ?? ''), 'vi'))
      .map(({ d, e }, i) => {
        tongTien += Number(d.thanh_tien ?? 0)
        return [
          i + 1,
          e?.employee_code ?? '—',
          e?.full_name ?? '(không rõ)',
          d.kieu_tinh === 'gio' ? 'Giờ' : 'Công',
          String(Number(d.so_luong ?? 0)),
          dinhDangTien(Number(d.don_gia ?? 0)),
          Number(d.so_gio_ot ?? 0) ? String(Number(d.so_gio_ot)) : '—',
          Number(d.don_gia_ot ?? 0) ? dinhDangTien(Number(d.don_gia_ot)) : '—',
          Number(d.thuong ?? 0) ? dinhDangTien(Number(d.thuong)) : '—',
          dinhDangTien(Number(d.thanh_tien ?? 0)),
        ]
      })
  } else {
    const { data: ky, error: loiKy } = await admin
      .from('payroll_periods')
      .select('id, month, year, status, closed_at, standard_days, company_id')
      .eq('id', doiTuongId)
      .maybeSingle()
    if (loiKy) return traLoi({ loi: `Không đọc được kỳ lương: ${loiKy.message}` }, 500)
    if (!ky) return traLoi({ loi: 'Không tìm thấy kỳ lương.' }, 404)
    if (ky.status === 'mo') {
      return traLoi({ loi: 'Kỳ lương chưa chốt — chứng từ chỉ sinh cho con số đã chốt.' }, 409)
    }

    const { data: cty } = ky.company_id
      ? await admin.from('companies').select('name, tax_code').eq('id', ky.company_id).maybeSingle()
      : { data: null }

    const { data: phieu, error: loiPhieu } = await admin
      .from('payslips')
      .select('employee_id, worked_days, gross_salary, bhxh_employee, bhyt_employee, bhtn_employee, pit, net_salary')
      .eq('period_id', doiTuongId)
    if (loiPhieu) return traLoi({ loi: `Không đọc được phiếu lương: ${loiPhieu.message}` }, 500)

    const ids = (phieu ?? []).map((p) => p.employee_id)
    const { data: nhanSu } = ids.length
      ? await admin.from('employees').select('id, employee_code, full_name').in('id', ids)
      : { data: [] }
    const ten = new Map((nhanSu ?? []).map((e) => [e.id, e]))

    tieuDe = 'BẢNG THANH TOÁN TIỀN LƯƠNG'
    phuDe = [
      `Kỳ lương: tháng ${String(ky.month).padStart(2, '0')}/${ky.year}`,
      `Ngày công chuẩn: ${ky.standard_days}`,
      `Chốt lúc: ${ngayVN(ky.closed_at)}`,
    ]
    if (cty?.name) phuDe.unshift(`Đơn vị: ${cty.name}${cty.tax_code ? ` · MST ${cty.tax_code}` : ''}`)

    cot = [
      { nhan: 'TT', rong: 30 },
      { nhan: 'Mã NV', rong: 66 },
      { nhan: 'Họ và tên', rong: 170 },
      { nhan: 'Công', rong: 46, phai: true },
      { nhan: 'Tổng thu nhập', rong: 96, phai: true },
      { nhan: 'BH người LĐ', rong: 90, phai: true },
      { nhan: 'Thuế TNCN', rong: 84, phai: true },
      { nhan: 'Thực nhận', rong: 96, phai: true },
    ]

    dong = (phieu ?? [])
      .map((p) => ({ p, e: ten.get(p.employee_id) }))
      .sort((a, b) => String(a.e?.full_name ?? '').localeCompare(String(b.e?.full_name ?? ''), 'vi'))
      .map(({ p, e }, i) => {
        const bh = Number(p.bhxh_employee ?? 0) + Number(p.bhyt_employee ?? 0) +
          Number(p.bhtn_employee ?? 0)
        tongTien += Number(p.net_salary ?? 0)
        return [
          i + 1,
          e?.employee_code ?? '—',
          e?.full_name ?? '(không rõ)',
          String(Number(p.worked_days ?? 0)),
          dinhDangTien(Number(p.gross_salary ?? 0)),
          dinhDangTien(bh),
          dinhDangTien(Number(p.pit ?? 0)),
          dinhDangTien(Number(p.net_salary ?? 0)),
        ]
      })
  }

  if (dong.length === 0) {
    return traLoi({ loi: 'Không có dòng nào — chứng từ rỗng thì không sinh.' }, 409)
  }

  // ---- 6. Vẽ PDF ----
  let pdfBytes: Uint8Array
  try {
    pdfBytes = await veChungTu({ tieuDe, phuDe, cot, dong, tongTien })
  } catch (e) {
    console.error('Vẽ PDF hỏng:', e)
    return traLoi({ loi: `Không dựng được file PDF: ${(e as Error).message}` }, 500)
  }

  const sha = await vanTay(pdfBytes)
  const duongDan = `${loai}/${doiTuongId}.pdf`

  // `upsert: false` — bucket đã cấm ghi qua RLS, nhưng service_role bỏ qua RLS
  // nên lớp chặn cuối cùng phải nằm ở đây. Trùng đường dẫn nghĩa là có file mà
  // không có bản ghi: một tình huống bất thường, phải báo chứ không đè lên.
  const { error: loiUp } = await admin.storage
    .from('chung-tu')
    .upload(duongDan, pdfBytes, { contentType: 'application/pdf', upsert: false })

  if (loiUp) {
    console.error('Upload chứng từ hỏng:', loiUp.message)
    return traLoi({ loi: `Không lưu được file chứng từ: ${loiUp.message}` }, 500)
  }

  const { data: banGhi, error: loiGhi } = await admin.rpc('ghi_chung_tu', {
    p_loai: loai,
    p_doi_tuong_id: doiTuongId,
    p_duong_dan: duongDan,
    p_tieu_de: tieuDe,
    p_tong_tien: tongTien,
    p_so_dong: dong.length,
    p_kich_thuoc: pdfBytes.byteLength,
    p_sha256: sha,
    p_nguoi_tao: user.id,
  })

  if (loiGhi) {
    // File đã lên kho mà bản ghi hỏng: dọn file đi. Để lại là để lại một file
    // không ai đọc được (policy tra ngược từ bảng) và một đường dẫn bị chiếm —
    // lần sinh lại sau sẽ chết vì `upsert: false`.
    await admin.storage.from('chung-tu').remove([duongDan])
    console.error('Ghi bản ghi chứng từ hỏng:', loiGhi.message)
    return traLoi({ loi: `Không ghi được chứng từ: ${loiGhi.message}` }, 500)
  }

  return traLoi({ chung_tu: banGhi, da_co_tu_truoc: false })
})

// ---------------------------------------------------------------------------
// Phần vẽ
// ---------------------------------------------------------------------------
async function veChungTu(opts: {
  tieuDe: string
  phuDe: string[]
  cot: Cot[]
  dong: O[][]
  tongTien: number
}): Promise<Uint8Array> {
  const { tieuDe, phuDe, cot, dong, tongTien } = opts

  const pdf = await PDFDocument.create()
  pdf.registerFontkit(fontkit)
  const thuong = await pdf.embedFont(await docFont('Roboto-Regular.ttf'), { subset: true })
  const dam = await pdf.embedFont(await docFont('Roboto-Bold.ttf'), { subset: true })

  pdf.setTitle(tieuDe)
  pdf.setProducer('HR Base Vina')
  pdf.setCreator('HR Base Vina')

  const rongBang = cot.reduce((s, c) => s + c.rong, 0)
  const CAO_DONG = 17
  const CO_CHU = 8.5

  let trang = pdf.addPage(A4_NGANG)
  let y = 0
  let soTrang = 0

  /** Cắt chữ cho vừa ô — thà mất đuôi tên còn hơn chữ đè lên cột bên cạnh. */
  const catVua = (chu: string, rong: number, font: typeof thuong, co: number) => {
    if (font.widthOfTextAtSize(chu, co) <= rong) return chu
    let t = chu
    while (t.length > 1 && font.widthOfTextAtSize(`${t}…`, co) > rong) t = t.slice(0, -1)
    return `${t}…`
  }

  const veHangCot = () => {
    let x = LE
    trang.drawRectangle({
      x: LE,
      y: y - 4,
      width: rongBang,
      height: CAO_DONG,
      color: rgb(0.94, 0.95, 0.97),
    })
    for (const c of cot) {
      const chu = catVua(c.nhan, c.rong - 8, dam, CO_CHU)
      const w = dam.widthOfTextAtSize(chu, CO_CHU)
      trang.drawText(chu, {
        x: c.phai ? x + c.rong - 4 - w : x + 4,
        y: y + 1,
        size: CO_CHU,
        font: dam,
        color: DEN,
      })
      x += c.rong
    }
    y -= CAO_DONG
  }

  const trangMoi = () => {
    soTrang += 1
    trang = soTrang === 1 ? trang : pdf.addPage(A4_NGANG)
    y = A4_NGANG[1] - LE

    if (soTrang === 1) {
      trang.drawText(tieuDe, { x: LE, y: y - 16, size: 15, font: dam, color: DEN })
      y -= 34
      for (const d of phuDe) {
        trang.drawText(d, { x: LE, y, size: 9, font: thuong, color: XAM })
        y -= 13
      }
      y -= 8
    } else {
      trang.drawText(`${tieuDe} (tiếp)`, { x: LE, y: y - 12, size: 10, font: dam, color: XAM })
      y -= 26
    }
    veHangCot()
  }

  trangMoi()

  for (const hang of dong) {
    if (y < LE + 90) trangMoi()

    let x = LE
    for (let i = 0; i < cot.length; i += 1) {
      const c = cot[i]
      const chu = catVua(String(hang[i] ?? ''), c.rong - 8, thuong, CO_CHU)
      const w = thuong.widthOfTextAtSize(chu, CO_CHU)
      trang.drawText(chu, {
        x: c.phai ? x + c.rong - 4 - w : x + 4,
        y: y + 1,
        size: CO_CHU,
        font: thuong,
        color: DEN,
      })
      x += c.rong
    }
    trang.drawLine({
      start: { x: LE, y: y - 4 },
      end: { x: LE + rongBang, y: y - 4 },
      thickness: 0.4,
      color: VIEN,
    })
    y -= CAO_DONG
  }

  // ---- Dòng tổng ----
  y -= 4
  const nhanTong = `TỔNG CỘNG (${dong.length} người)`
  trang.drawText(nhanTong, { x: LE + 4, y: y + 1, size: 9.5, font: dam, color: DEN })
  const tong = dinhDangTien(tongTien)
  const wTong = dam.widthOfTextAtSize(tong, 9.5)
  trang.drawText(tong, { x: LE + rongBang - 4 - wTong, y: y + 1, size: 9.5, font: dam, color: DEN })
  trang.drawLine({
    start: { x: LE, y: y - 5 },
    end: { x: LE + rongBang, y: y - 5 },
    thickness: 1,
    color: DEN,
  })
  y -= 22

  // Bằng chữ: lớp chống sửa số tiền rẻ nhất mà kế toán Việt Nam vẫn dùng.
  // Làm tròn về đồng trước khi đọc — số lẻ xu không đọc được thành chữ, và
  // tiền lương ở đây luôn tròn đồng.
  trang.drawText(`Bằng chữ: ${docSoTienBangChu(Math.round(tongTien))}`, {
    x: LE,
    y,
    size: 9.5,
    font: dam,
    color: DEN,
  })
  y -= 24

  // ---- Chỗ ký ----
  const oKy = ['Người lập biểu', 'Kế toán trưởng', 'Người nhận tiền', 'Thủ trưởng đơn vị']
  const rongO = rongBang / oKy.length
  for (let i = 0; i < oKy.length; i += 1) {
    const w = dam.widthOfTextAtSize(oKy[i], 9)
    trang.drawText(oKy[i], {
      x: LE + i * rongO + (rongO - w) / 2,
      y,
      size: 9,
      font: dam,
      color: DEN,
    })
    const ghiChu = '(ký, ghi rõ họ tên)'
    const w2 = thuong.widthOfTextAtSize(ghiChu, 7.5)
    trang.drawText(ghiChu, {
      x: LE + i * rongO + (rongO - w2) / 2,
      y: y - 11,
      size: 7.5,
      font: thuong,
      color: XAM,
    })
  }

  // ---- Chân trang trên MỌI trang ----
  //
  // Nói thẳng chứng từ này là gì và không là gì. Một tờ giấy do máy in ra mà
  // không nói rõ giới hạn của nó là một tờ giấy sẽ bị viện dẫn quá xa.
  const cacTrang = pdf.getPages()
  for (let i = 0; i < cacTrang.length; i += 1) {
    cacTrang[i].drawText(
      `HR Base Vina · chứng từ sinh tự động, không phải chữ ký số · trang ${i + 1}/${cacTrang.length}`,
      { x: LE, y: 18, size: 7.5, font: thuong, color: XAM },
    )
  }

  return await pdf.save()
}
