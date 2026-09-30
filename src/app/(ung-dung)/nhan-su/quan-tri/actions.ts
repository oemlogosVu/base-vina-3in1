'use server'

import { revalidatePath } from 'next/cache'
import { createClient } from '@ns/lib/supabase/server'
import { batBuocVaiTro } from '@ns/lib/phien'
import {
  docCapGio,
  gioGon,
  kiemKhungGioVaCa,
  MA_CA,
  type CaKhai,
} from '@ns/lib/gio-chuan'

export type TrangThaiForm = { error: string | null; xong?: string }

function chuoi(form: FormData, ten: string): string | null {
  const v = String(form.get(ten) ?? '').trim()
  return v === '' ? null : v
}

function so(form: FormData, ten: string): number | null {
  const v = String(form.get(ten) ?? '').trim()
  if (v === '') return null
  const n = Number(v)
  return Number.isFinite(n) ? n : null
}

/**
 * Công tiêu chuẩn của công ty — mẫu số để quy lương tháng thành lương ngày.
 *
 * Bỏ trống được (công ty mới lập chưa chốt chính sách), nhưng gõ vào thì
 * phải là số hợp lệ. Ràng buộc thật nằm ở cột `companies.standard_days`;
 * đây chỉ để báo lỗi bằng tiếng người thay vì ném mã 23514 lên màn hình.
 */
function congChuan(form: FormData): { loi: string } | { gt: number | null } {
  const raw = String(form.get('standard_days') ?? '').trim()
  if (raw === '') return { gt: null }
  const n = so(form, 'standard_days')
  if (n === null || n <= 0 || n > 31) {
    return { loi: 'Công tiêu chuẩn phải lớn hơn 0 và không quá 31 ngày.' }
  }
  return { gt: n }
}

/**
 * Hạn để người lao động xác nhận phiếu lương, tính từ lúc chốt kỳ.
 *
 * Bỏ trống là **không bao giờ tự động xác nhận** — đó là mặc định an toàn:
 * hệ thống không tự ý đồng ý thay người lao động khi chưa ai cho phép nó.
 */
function hanXacNhan(form: FormData): { loi: string } | { gt: number | null } {
  const raw = String(form.get('han_xac_nhan_phieu_ngay') ?? '').trim()
  if (raw === '') return { gt: null }
  const n = so(form, 'han_xac_nhan_phieu_ngay')
  if (n === null || !Number.isInteger(n) || n <= 0 || n > 90) {
    return { loi: 'Hạn xác nhận phải là số ngày nguyên, lớn hơn 0 và không quá 90.' }
  }
  return { gt: n }
}

/**
 * Khung giờ chuẩn của công ty, và ba ca công nhật (P5e, 24/08/2026).
 *
 * Một hành động cho cả bốn ô khung giờ lẫn sáu ô giờ ca, vì chúng chỉ có
 * nghĩa cùng nhau: khai ca mà chưa khai khung thì không biết giờ nào là ngoài
 * giờ, và khai khung mà chưa khai ca thì không có gì để tick.
 *
 * Không kiểm chồng giờ, không kiểm nghỉ-trong-khung ở đây: cả hai đã là ràng
 * buộc và trigger ở database. Việc của hàm này là dịch mã lỗi thành câu tiếng
 * Việt, không phải viết lại luật lần thứ hai.
 */
function gio(form: FormData, ten: string): string | null {
  const v = String(form.get(ten) ?? '').trim()
  return v === '' ? null : v
}

/**
 * Khung giờ chuẩn của công ty, và ba ca công nhật (P5e, 24/08/2026).
 *
 * Một hành động cho cả bốn ô khung giờ lẫn sáu ô giờ ca, vì chúng chỉ có
 * nghĩa cùng nhau: khai ca mà chưa khai khung thì không biết giờ nào là ngoài
 * giờ, và khai khung mà chưa khai ca thì không có gì để tick.
 *
 * KIỂM HẾT RỒI MỚI GHI — xem `kiemKhungGioVaCa()` trong `@/lib/gio-chuan`.
 * Bản đầu ghi khung giờ trước rồi ghi từng ca sau, nên một lỗi ở giữa để lại
 * trạng thái nửa vời: công ty BaseVN có 2 ca mà không có khung giờ, đúng vì lý
 * do này.
 *
 * Ràng buộc thật vẫn ở database. Việc của hàm này là nói ra **ô nào sai và sai
 * thế nào** — bản đầu gộp bốn luật vào một câu, nên Triệu Vũ nhận
 * "giờ ra phải sau giờ vào, và giờ nghỉ phải nằm trong khung" mà không biết
 * mình phạm vế nào.
 */
export async function datGioChuanVaCa(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  await batBuocVaiTro('admin')

  const id = chuoi(form, 'id')
  if (!id) return { error: 'Thiếu mã công ty.' }

  const khung = docCapGio(gio(form, 'gio_vao'), gio(form, 'gio_ra'), 'Khung giờ chuẩn')
  if ('loi' in khung) return { error: khung.loi }

  const nghi = docCapGio(gio(form, 'nghi_tu'), gio(form, 'nghi_den'), 'Giờ nghỉ')
  if ('loi' in nghi) return { error: nghi.loi }

  const ca: CaKhai[] = []
  for (const c of MA_CA) {
    const kq = docCapGio(
      gio(form, `ca_${c.ma}_bat_dau`),
      gio(form, `ca_${c.ma}_ket_thuc`),
      c.nhan,
    )
    if ('loi' in kq) return { error: kq.loi }
    ca.push({ ma: c.ma, nhan: c.nhan, gt: kq.gt })
  }

  const loi = kiemKhungGioVaCa(khung.gt, nghi.gt, ca)
  if (loi !== null) return { error: loi }

  // ---- Tới đây mới ghi ----
  const supabase = await createClient()

  const { error: loiCty } = await supabase
    .from('companies')
    .update({
      gio_vao: khung.gt?.bd ?? null,
      gio_ra: khung.gt?.kt ?? null,
      nghi_tu: nghi.gt?.bd ?? null,
      nghi_den: nghi.gt?.kt ?? null,
    })
    .eq('id', id)

  if (loiCty) return { error: `Không lưu được khung giờ: ${loiCty.message}` }

  for (const c of ca) {
    if (c.gt === undefined) {
      const { error } = await supabase
        .from('ca_cong_nhat')
        .delete()
        .eq('company_id', id)
        .eq('ma', c.ma)
      if (error) return { error: `Không xoá được ${c.nhan.toLowerCase()}: ${error.message}` }
      continue
    }

    const { error } = await supabase.from('ca_cong_nhat').upsert(
      {
        company_id: id,
        ma: c.ma,
        gio_bat_dau: c.gt.bd,
        gio_ket_thuc: c.gt.kt,
        is_active: true,
      },
      { onConflict: 'company_id,ma' },
    )

    if (error) return { error: `Không lưu được ${c.nhan.toLowerCase()}: ${error.message}` }
  }

  revalidatePath('/nhan-su/quan-tri/cong-ty')
  revalidatePath('/nhan-su/to-doi')

  const soCa = ca.filter((c) => c.gt !== undefined).length
  if (!khung.gt) {
    return {
      error: null,
      xong:
        'Đã XOÁ khung giờ chuẩn của công ty này. Tổ đội của nó sẽ không chấm công được cho tới khi khai lại.',
    }
  }

  return {
    error: null,
    xong:
      `Đã lưu: khung giờ ${gioGon(khung.gt.bd)}–${gioGon(khung.gt.kt)}` +
      (nghi.gt ? `, nghỉ ${gioGon(nghi.gt.bd)}–${gioGon(nghi.gt.kt)}` : ', không nghỉ giữa ca') +
      `, ${soCa} ca.` +
      (soCa === 0 ? ' Chưa khai ca nào thì tổ đội vẫn chưa chấm công được.' : ''),
  }
}

/**
 * Danh mục nào được xoá cứng, và gọi nó là gì khi báo lỗi.
 *
 * Danh sách trắng chứ không nhận thẳng tên bảng từ form: form là dữ liệu
 * người dùng gửi lên, sửa được. Không có danh sách này thì một người có
 * quyền admin gõ tay tên bảng nào cũng xoá được — RLS vẫn chặn phần lớn,
 * nhưng dựa vào đó là dựa vào lớp cuối cùng thay vì lớp đầu tiên.
 */
const DANH_MUC_XOA_DUOC = {
  departments: 'phòng ban',
  positions: 'chức danh',
  work_shifts: 'ca làm việc',
  companies: 'công ty',
  allowance_types: 'loại phụ cấp',
} as const

type BangDanhMuc = keyof typeof DANH_MUC_XOA_DUOC

/** Bảng nào đang giữ tham chiếu → câu giải thích cho người dùng. */
const TEN_BANG_THAM_CHIEU: Record<string, string> = {
  employees: 'hồ sơ nhân sự',
  departments: 'phòng ban',
  attendance_days: 'bảng công đã tổng hợp',
  payroll_periods: 'kỳ lương',
  position_allowances: 'phụ cấp theo chức danh',
}

/**
 * Xoá một dòng danh mục.
 *
 * KHÔNG tự đếm xem còn ai tham chiếu trước khi xoá. Mọi khoá ngoại trỏ vào
 * năm bảng này đều là NO ACTION, nên Postgres tự chặn và trả mã 23503. Tự
 * đếm bằng tay là viết lại luật khoá ngoại lần thứ hai, và bản viết lại sẽ
 * lệch ngay khi ai đó thêm một khoá ngoại mới.
 *
 * Việc ở đây chỉ là dịch mã 23503 thành câu người đọc hiểu được.
 */
export async function xoaDanhMuc(_prev: TrangThaiForm, form: FormData): Promise<TrangThaiForm> {
  await batBuocVaiTro('admin')

  const bang = String(form.get('bang') ?? '') as BangDanhMuc
  const id = chuoi(form, 'id')
  const ten = chuoi(form, 'ten') ?? 'dòng này'

  if (!(bang in DANH_MUC_XOA_DUOC)) return { error: 'Không xoá được loại dữ liệu này.' }
  if (!id) return { error: 'Thiếu mã dòng cần xoá.' }

  const supabase = await createClient()
  const { error } = await supabase.from(bang).delete().eq('id', id)

  if (error) {
    if (error.code === '23503') {
      // details có dạng: Key (id)=(...) is still referenced from table "employees".
      const khop = /table "([a-z_]+)"/.exec(error.details ?? '')?.[1]
      const nguon = khop ? (TEN_BANG_THAM_CHIEU[khop] ?? khop) : 'dữ liệu khác'
      return {
        error: `Không xoá được “${ten}”: còn ${nguon} đang dùng nó. Chuyển chúng sang mục khác trước, hoặc bỏ tick “Đang dùng” để ngừng sử dụng mà vẫn giữ dữ liệu cũ.`,
      }
    }
    return { error: `Không xoá được “${ten}”: ${error.message}` }
  }

  revalidatePath(`/nhan-su/quan-tri`, 'layout')
  // Menu và danh sách nhân sự dựng từ các danh mục này.
  revalidatePath('/', 'layout')
  return { error: null, xong: `Đã xoá ${DANH_MUC_XOA_DUOC[bang]} “${ten}”.` }
}

/**
 * Danh mục tổ chức do admin quản lý.
 *
 * Kiểm quyền ở đây chỉ để báo lỗi sớm. Lớp chặn thật là RLS: policy insert và
 * update trên các bảng này chỉ mở cho vai trò admin.
 */

/**
 * Công ty — hai pháp nhân, không phải hai phòng ban.
 *
 * Mỗi công ty có kỳ lương và bảng lương riêng vì khai thuế TNCN và BHXH tách
 * bạch. Xoá cứng được (từ 12/08/2026) nhưng chỉ khi chưa có kỳ lương, phòng
 * ban hay nhân viên nào trỏ tới — khoá ngoại tự chặn, xem `xoaDanhMuc`. Nhờ
 * vậy bảng lương đã phát hành luôn còn trỏ về được pháp nhân đã trả nó.
 */
export async function taoCongTy(_prev: TrangThaiForm, form: FormData): Promise<TrangThaiForm> {
  await batBuocVaiTro('admin')

  const code = chuoi(form, 'code')
  const name = chuoi(form, 'name')
  if (!code || !name) return { error: 'Mã và tên công ty là bắt buộc.' }

  const chuan = congChuan(form)
  if ('loi' in chuan) return { error: chuan.loi }
  const han = hanXacNhan(form)
  if ('loi' in han) return { error: han.loi }

  const supabase = await createClient()
  const { error } = await supabase.from('companies').insert({
    code,
    name,
    tax_code: chuoi(form, 'tax_code'),
    address: chuoi(form, 'address'),
    standard_days: chuan.gt,
    han_xac_nhan_phieu_ngay: han.gt,
  })

  if (error) {
    if (error.code === '23505') return { error: `Mã công ty “${code}” đã tồn tại.` }
    return { error: `Không tạo được công ty: ${error.message}` }
  }

  revalidatePath('/nhan-su/quan-tri/cong-ty')
  revalidatePath('/nhan-su/ho-so')
  return { error: null }
}

export async function capNhatCongTy(_prev: TrangThaiForm, form: FormData): Promise<TrangThaiForm> {
  await batBuocVaiTro('admin')

  const id = chuoi(form, 'id')
  const name = chuoi(form, 'name')
  if (!id || !name) return { error: 'Thiếu mã công ty hoặc tên.' }

  const chuan = congChuan(form)
  if ('loi' in chuan) return { error: chuan.loi }
  const han = hanXacNhan(form)
  if ('loi' in han) return { error: han.loi }

  const supabase = await createClient()
  const { error } = await supabase
    .from('companies')
    .update({
      name,
      tax_code: chuoi(form, 'tax_code'),
      address: chuoi(form, 'address'),
      han_xac_nhan_phieu_ngay: han.gt,
      // Đổi con số này KHÔNG động tới kỳ lương đã tạo: mỗi kỳ giữ công chuẩn
      // của chính nó, nên phiếu lương cũ dựng lại vẫn ra đúng số cũ.
      standard_days: chuan.gt,
      is_active: form.get('is_active') === 'on',
    })
    .eq('id', id)

  if (error) return { error: `Không lưu được công ty: ${error.message}` }

  revalidatePath('/nhan-su/quan-tri/cong-ty')
  return { error: null }
}

export async function taoPhongBan(_prev: TrangThaiForm, form: FormData): Promise<TrangThaiForm> {
  await batBuocVaiTro('admin')

  const code = chuoi(form, 'code')
  const name = chuoi(form, 'name')
  if (!code || !name) return { error: 'Mã và tên phòng ban là bắt buộc.' }

  const supabase = await createClient()
  const { error } = await supabase.from('departments').insert({
    code,
    name,
    parent_id: chuoi(form, 'parent_id'),
  })

  if (error) {
    if (error.code === '23505') return { error: `Mã phòng ban “${code}” đã tồn tại.` }
    return { error: `Không tạo được phòng ban: ${error.message}` }
  }

  revalidatePath('/nhan-su/quan-tri/phong-ban')
  return { error: null }
}

export async function capNhatPhongBan(_prev: TrangThaiForm, form: FormData): Promise<TrangThaiForm> {
  await batBuocVaiTro('admin')

  const id = chuoi(form, 'id')
  const name = chuoi(form, 'name')
  if (!id || !name) return { error: 'Thiếu mã phòng ban hoặc tên.' }

  const parent_id = chuoi(form, 'parent_id')
  if (parent_id === id) return { error: 'Phòng ban không thể là cấp cha của chính nó.' }

  const supabase = await createClient()
  const { error } = await supabase
    .from('departments')
    .update({
      name,
      parent_id,
      manager_id: chuoi(form, 'manager_id'),
      // Còn nhân viên thì không xoá được — lúc đó bỏ tick cờ này để ngừng
      // dùng mà vẫn giữ tham chiếu của hồ sơ cũ.
      is_active: form.get('is_active') === 'on',
    })
    .eq('id', id)

  if (error) return { error: `Không lưu được phòng ban: ${error.message}` }

  revalidatePath('/nhan-su/quan-tri/phong-ban')
  return { error: null }
}

export async function taoChucDanh(_prev: TrangThaiForm, form: FormData): Promise<TrangThaiForm> {
  await batBuocVaiTro('admin')

  const code = chuoi(form, 'code')
  const name = chuoi(form, 'name')
  if (!code || !name) return { error: 'Mã và tên chức danh là bắt buộc.' }

  const supabase = await createClient()
  const { error } = await supabase.from('positions').insert({ code, name })

  if (error) {
    if (error.code === '23505') return { error: `Mã chức danh “${code}” đã tồn tại.` }
    return { error: `Không tạo được chức danh: ${error.message}` }
  }

  revalidatePath('/nhan-su/quan-tri/chuc-danh')
  return { error: null }
}

export async function capNhatChucDanh(_prev: TrangThaiForm, form: FormData): Promise<TrangThaiForm> {
  await batBuocVaiTro('admin')

  const id = chuoi(form, 'id')
  const name = chuoi(form, 'name')
  if (!id || !name) return { error: 'Thiếu mã chức danh hoặc tên.' }

  // TAB rời khỏi đây ở P0c, QUYỀN rời khỏi đây ở P0d — cả hai nay khai cho
  // từng người tại Quản trị → Người dùng, và quyền sinh thẳng từ ô tick tab.
  // Màn này chỉ còn tên, trạng thái, và phụ cấp.
  const supabase = await createClient()
  const { error } = await supabase
    .from('positions')
    .update({ name, is_active: form.get('is_active') === 'on' })
    .eq('id', id)

  if (error) return { error: `Không lưu được chức danh: ${error.message}` }

  revalidatePath('/nhan-su/quan-tri/chuc-danh')
  // Menu của người đang giữ chức danh này dựng từ cấu hình vừa đổi, nên phải
  // dọn cache của toàn bộ app chứ không riêng màn quản trị.
  revalidatePath('/', 'layout')
  return { error: null }
}

/**
 * Danh mục LOẠI phụ cấp.
 *
 * `is_taxable` và `is_insurance` khai ở đây, một lần cho cả hệ thống. Chúng
 * quyết định tiền thuế và tiền bảo hiểm, nên để mỗi chức danh tự khai lại là
 * mời gọi hai chức danh khai khác nhau cho cùng một khoản.
 */
export async function taoLoaiPhuCap(_prev: TrangThaiForm, form: FormData): Promise<TrangThaiForm> {
  await batBuocVaiTro('admin')

  const code = chuoi(form, 'code')
  const name = chuoi(form, 'name')
  if (!code || !name) return { error: 'Mã và tên loại phụ cấp là bắt buộc.' }

  const supabase = await createClient()
  const { error } = await supabase.from('allowance_types').insert({
    code,
    name,
    is_taxable: form.get('is_taxable') === 'on',
    is_insurance: form.get('is_insurance') === 'on',
    ghi_chu: chuoi(form, 'ghi_chu'),
  })

  if (error) {
    if (error.code === '23505') return { error: `Mã loại phụ cấp “${code}” đã tồn tại.` }
    return { error: `Không tạo được loại phụ cấp: ${error.message}` }
  }

  revalidatePath('/nhan-su/quan-tri/loai-phu-cap')
  revalidatePath('/nhan-su/quan-tri/chuc-danh')
  return { error: null }
}

export async function capNhatLoaiPhuCap(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  await batBuocVaiTro('admin')

  const id = chuoi(form, 'id')
  const name = chuoi(form, 'name')
  if (!id || !name) return { error: 'Thiếu mã loại phụ cấp hoặc tên.' }

  const supabase = await createClient()
  const { error } = await supabase
    .from('allowance_types')
    .update({
      name,
      is_taxable: form.get('is_taxable') === 'on',
      is_insurance: form.get('is_insurance') === 'on',
      ghi_chu: chuoi(form, 'ghi_chu'),
      // Còn chức danh nào đang gán loại này thì khoá ngoại chặn xoá; lúc đó
      // bỏ tick cờ này để ngừng dùng. Phiếu lương cũ không phụ thuộc vào
      // danh mục vì đã chụp tên và mức vào cfg_snapshot.
      is_active: form.get('is_active') === 'on',
    })
    .eq('id', id)

  if (error) return { error: `Không lưu được loại phụ cấp: ${error.message}` }

  revalidatePath('/nhan-su/quan-tri/loai-phu-cap')
  revalidatePath('/nhan-su/quan-tri/chuc-danh')
  return { error: null }
}

/**
 * Chức danh nào hưởng loại phụ cấp nào, mức bao nhiêu.
 *
 * Form gửi lên TOÀN BỘ danh mục loại phụ cấp, mỗi loại một cặp `chon_<id>` +
 * `muc_<id>`. Ở đây so với những dòng đang có rồi mới quyết định thêm / sửa /
 * gỡ — nên bỏ tick một loại là gỡ thật, không phải để mức 0 rồi vẫn in ra
 * phiếu lương một dòng 0 đồng.
 */
export async function luuPhuCapChucDanh(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  await batBuocVaiTro('admin')

  const position_id = chuoi(form, 'position_id')
  if (!position_id) return { error: 'Thiếu chức danh.' }

  const supabase = await createClient()

  // Lấy danh mục từ DB chứ không tin danh sách id do form gửi lên: form là
  // dữ liệu người dùng, sửa được.
  const { data: loai, error: loiLoai } = await supabase
    .from('allowance_types')
    .select('id')
    .eq('is_active', true)

  if (loiLoai) return { error: `Không đọc được danh mục phụ cấp: ${loiLoai.message}` }

  const muon: { position_id: string; allowance_type_id: string; amount: number }[] = []

  for (const l of loai ?? []) {
    if (form.get(`chon_${l.id}`) !== 'on') continue

    const v = String(form.get(`muc_${l.id}`) ?? '').trim()
    if (v === '') return { error: 'Có loại phụ cấp được tick nhưng chưa nhập mức.' }

    const n = Number(v)
    if (!Number.isFinite(n) || n < 0) return { error: `Mức phụ cấp “${v}” không hợp lệ.` }

    muon.push({ position_id, allowance_type_id: l.id, amount: n })
  }

  const giu = muon.map((m) => m.allowance_type_id)

  // Gỡ trước, thêm sau. Ngược lại thì lệnh gỡ sẽ xoá luôn dòng vừa thêm khi
  // danh sách giữ lại rỗng.
  let xoa = supabase.from('position_allowances').delete().eq('position_id', position_id)
  if (giu.length > 0) xoa = xoa.not('allowance_type_id', 'in', `(${giu.join(',')})`)

  const { error: loiXoa } = await xoa
  if (loiXoa) return { error: `Không gỡ được phụ cấp cũ: ${loiXoa.message}` }

  if (muon.length > 0) {
    const { error } = await supabase
      .from('position_allowances')
      .upsert(muon, { onConflict: 'position_id,allowance_type_id' })
    if (error) return { error: `Không lưu được phụ cấp: ${error.message}` }
  }

  revalidatePath('/nhan-su/quan-tri/chuc-danh')
  return { error: null }
}

/**
 * Ca làm việc.
 *
 * Phần địa điểm chấm công đã bị bỏ ngày 11/08/2026 cùng với tính năng kiểm
 * tra GPS — không còn `taoDiaDiem` / `capNhatDiaDiem` ở file này nữa.
 */
export async function capNhatCaLamViec(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  await batBuocVaiTro('admin')

  const id = chuoi(form, 'id')
  const name = chuoi(form, 'name')
  const start = chuoi(form, 'start_time')
  const end = chuoi(form, 'end_time')
  const breakStart = chuoi(form, 'break_start')
  const breakEnd = chuoi(form, 'break_end')

  if (!id || !name || !start || !end) return { error: 'Tên ca, giờ vào và giờ ra là bắt buộc.' }
  if (end <= start) return { error: 'Giờ ra phải sau giờ vào.' }
  if ((breakStart === null) !== (breakEnd === null)) {
    return { error: 'Giờ nghỉ phải có đủ cả giờ bắt đầu và giờ kết thúc.' }
  }
  if (breakStart !== null && breakEnd !== null) {
    if (breakEnd <= breakStart) return { error: 'Giờ kết thúc nghỉ phải sau giờ bắt đầu nghỉ.' }
    if (breakStart < start || breakEnd > end) return { error: 'Giờ nghỉ phải nằm trong ca.' }
  }

  const supabase = await createClient()
  const { error } = await supabase
    .from('work_shifts')
    .update({
      name,
      start_time: start,
      end_time: end,
      break_start: breakStart,
      break_end: breakEnd,
      is_active: form.get('is_active') === 'on',
    })
    .eq('id', id)

  if (error) return { error: `Không lưu được ca làm việc: ${error.message}` }

  revalidatePath('/nhan-su/quan-tri/ca-lam-viec')
  return { error: null }
}

/**
 * Xoá mềm hồ sơ nhân sự.
 *
 * Ba việc — đánh dấu, gỡ khỏi vị trí quản lý, khoá tài khoản đăng nhập — nằm
 * trong hàm `xoa_nhan_su` của database chứ không rải ở đây, để chúng cùng
 * thành công hoặc cùng thất bại. Làm ở tầng này thì mất kết nối giữa chừng
 * là hồ sơ biến mất nhưng tài khoản vẫn đăng nhập được.
 */
export async function xoaNhanSu(_prev: TrangThaiForm, form: FormData): Promise<TrangThaiForm> {
  await batBuocVaiTro('admin')

  const id = chuoi(form, 'employee_id')
  const lyDo = chuoi(form, 'ly_do')
  if (!id) return { error: 'Thiếu hồ sơ cần xoá.' }
  if (!lyDo) return { error: 'Phải ghi lý do xoá — người đọc thùng rác sau này cần biết vì sao.' }

  const supabase = await createClient()
  const { error } = await supabase.rpc('xoa_nhan_su', { p_employee_id: id, p_ly_do: lyDo })

  if (error) return { error: error.message }

  revalidatePath('/nhan-su/ho-so')
  revalidatePath('/nhan-su/quan-tri/thung-rac')
  return { error: null, xong: 'Đã chuyển hồ sơ vào thùng rác.' }
}

export async function khoiPhucNhanSu(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  await batBuocVaiTro('admin')

  const id = chuoi(form, 'employee_id')
  if (!id) return { error: 'Thiếu hồ sơ cần khôi phục.' }

  const supabase = await createClient()
  const { error } = await supabase.rpc('khoi_phuc_nhan_su', { p_employee_id: id })
  if (error) return { error: error.message }

  revalidatePath('/nhan-su/ho-so')
  revalidatePath('/nhan-su/quan-tri/thung-rac')
  return {
    error: null,
    xong: 'Đã khôi phục hồ sơ. Tài khoản đăng nhập của người này VẪN đang bị khoá — bật lại ở màn tài khoản nếu cần.',
  }
}

/**
 * Xoá mềm một lần chấm công.
 *
 * Hàm database tự tổng hợp lại bảng công của đúng ngày đó sau khi xoá. Nếu
 * không, lần chấm biến mất khỏi màn hình nhưng số phút cũ vẫn nằm trong
 * attendance_days và bảng lương vẫn trả theo số cũ.
 */
export async function xoaChamCong(_prev: TrangThaiForm, form: FormData): Promise<TrangThaiForm> {
  await batBuocVaiTro('admin')

  const id = chuoi(form, 'log_id')
  if (!id) return { error: 'Thiếu lần chấm công cần xoá.' }

  const supabase = await createClient()
  const { data, error } = await supabase.rpc('xoa_cham_cong', {
    p_log_id: id,
    // Lý do không bắt buộc với lần chấm công (khác với xoá hồ sơ): hàm SQL
    // tự đổi chuỗi rỗng thành null.
    p_ly_do: chuoi(form, 'ly_do') ?? '',
  })
  if (error) return { error: error.message }

  revalidatePath('/nhan-su/cham-cong/xac-nhan')
  revalidatePath('/nhan-su/quan-tri/thung-rac')
  return { error: null, xong: `Đã xoá và tổng hợp lại bảng công ngày ${data}.` }
}

export async function khoiPhucChamCong(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  await batBuocVaiTro('admin')

  const id = chuoi(form, 'log_id')
  if (!id) return { error: 'Thiếu lần chấm công cần khôi phục.' }

  const supabase = await createClient()
  const { data, error } = await supabase.rpc('khoi_phuc_cham_cong', { p_log_id: id })
  if (error) return { error: error.message }

  revalidatePath('/nhan-su/cham-cong/xac-nhan')
  revalidatePath('/nhan-su/quan-tri/thung-rac')
  return { error: null, xong: `Đã khôi phục và tổng hợp lại bảng công ngày ${data}.` }
}
