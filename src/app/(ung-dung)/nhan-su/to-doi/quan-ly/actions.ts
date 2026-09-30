'use server'

import { revalidatePath } from 'next/cache'
import { createClient } from '@ns/lib/supabase/server'
import { batBuocPhien, batBuocVaiTro } from '@ns/lib/phien'

export type TrangThaiForm = { error: string | null; xong?: string }

const LA_NGAY = /^\d{4}-\d{2}-\d{2}$/

/** Chuỗi đã cắt khoảng trắng; rỗng thành NULL để không lưu chuỗi rỗng vào DB. */
function chuoi(form: FormData, ten: string): string | null {
  const v = String(form.get(ten) ?? '').trim()
  return v === '' ? null : v
}

/**
 * Dịch lỗi thô của Postgres sang tiếng người.
 *
 * Ràng buộc ở database là lớp chặn thật, nhưng thông báo của nó viết cho lập
 * trình viên. Người dùng gặp "duplicate key value violates unique constraint
 * uniq_thanh_vien_mot_to_dang_mo" thì không biết phải làm gì.
 */
function dichLoi(loi: { code?: string; message: string }): string {
  if (loi.code === '23505' && loi.message.includes('uniq_thanh_vien_mot_to_dang_mo')) {
    return 'Người này đang thuộc một tổ khác. Kết thúc ở tổ cũ trước rồi mới thêm vào tổ này — một người ở hai tổ là ngày công bị đếm hai lần.'
  }
  if (loi.code === '23505' && loi.message.includes('to_doi_code_key')) {
    return 'Mã tổ này đã có rồi.'
  }
  if (loi.code === '23505' && loi.message.includes('nguoi_cham_khong_trung')) {
    return 'Người này đã được giao chấm công cho tổ đó rồi.'
  }
  if (loi.code === '23514' && loi.message.includes('tdtv_ky_hop_le')) {
    return 'Ngày rời tổ không được trước ngày vào tổ.'
  }
  // Trigger `kiem_nguoi_cham_chinh_thuc` đã viết sẵn câu tiếng Việt đầy đủ —
  // giữ nguyên thay vì gói lại, vì nó nói cả lý do chứ không chỉ nói "sai".
  return loi.message
}

/**
 * Câu báo khi RLS cho câu lệnh chạy nhưng không dòng nào khớp.
 *
 * PostgREST KHÔNG coi đó là lỗi: `update` bị policy loại hết dòng vẫn trả về
 * `error === null` với mảng rỗng. Nên mọi chỗ sửa dữ liệu của tổ đều phải hỏi
 * lại "có đổi được dòng nào không" rồi mới dám báo đã lưu.
 */
const KHONG_PHU_TRACH =
  'Không lưu được: bạn không phụ trách tổ này, hoặc tài khoản của bạn không còn đủ điều kiện làm người chấm công (phải là nhân viên chính thức, hợp đồng đang hiệu lực và đang đóng bảo hiểm). Đề nghị quản trị hệ thống kiểm tra lại.'

export async function taoToDoi(_prev: TrangThaiForm, form: FormData): Promise<TrangThaiForm> {
  await batBuocVaiTro('admin')

  const code = chuoi(form, 'code')
  const name = chuoi(form, 'name')
  const companyId = chuoi(form, 'company_id')

  if (!code) return { error: 'Thiếu mã tổ.' }
  if (!name) return { error: 'Thiếu tên tổ.' }
  // Bắt buộc ở database luôn, nhưng báo ở đây thì người dùng hiểu vì sao.
  if (!companyId) {
    return { error: 'Phải chọn công ty — bảng thanh toán của tổ tách theo pháp nhân.' }
  }

  const supabase = await createClient()
  const { error } = await supabase.from('to_doi').insert({
    code,
    name,
    company_id: companyId,
    department_id: chuoi(form, 'department_id'),
    ghi_chu: chuoi(form, 'ghi_chu'),
  })

  if (error) return { error: `Không tạo được tổ: ${dichLoi(error)}` }

  revalidatePath('/nhan-su/to-doi/quan-ly')
  return { error: null, xong: 'Đã tạo tổ.' }
}

/**
 * Sửa tên, phòng ban, ghi chú, trạng thái của một tổ.
 *
 * Guard chỉ là `batBuocPhien()`, KHÔNG phải `batBuocVaiTro('admin')`. Cho tới
 * 29/08/2026 nó đòi admin, trong khi biểu mẫu lại hiện ra cho cả người quản lý
 * tổ — họ bấm Lưu và bị đá thẳng về `/nhan-su/ho-so-cua-toi`, không một câu báo. Database đã
 * mở đúng việc này từ P5c: policy `to_doi_update_nguoi_cham` cho người chấm
 * sửa tổ mình, và quyền cấp cột chỉ mở đúng năm cột biểu mẫu này đang sửa —
 * `code` với `company_id` không cấp cho ai. Để RLS trả lời là hết lệch.
 */
export async function capNhatToDoi(_prev: TrangThaiForm, form: FormData): Promise<TrangThaiForm> {
  await batBuocPhien()

  const id = chuoi(form, 'id')
  const name = chuoi(form, 'name')
  if (!id) return { error: 'Thiếu mã tổ.' }
  if (!name) return { error: 'Thiếu tên tổ.' }

  const supabase = await createClient()
  // `.select()` sau `.update()` để BIẾT có dòng nào đổi thật không. Không có
  // nó thì RLS chặn cũng trả về `error === null`, và người dùng nhận "Đã lưu."
  // cho một việc chưa xảy ra — đúng kiểu hỏng lặng lẽ mà `suaNhanCong` đã
  // phải đi chữa ngày 24/08.
  const { data, error } = await supabase
    .from('to_doi')
    .update({
      name,
      department_id: chuoi(form, 'department_id'),
      ghi_chu: chuoi(form, 'ghi_chu'),
      is_active: form.get('is_active') !== null,
    })
    .eq('id', id)
    .select('id')

  if (error) return { error: `Không lưu được: ${dichLoi(error)}` }
  if ((data ?? []).length === 0) return { error: KHONG_PHU_TRACH }

  revalidatePath('/nhan-su/to-doi/quan-ly')
  revalidatePath('/nhan-su/to-doi')
  return { error: null, xong: 'Đã lưu.' }
}

/**
 * Xếp một hồ sơ nhân sự ĐÃ CÓ vào tổ.
 *
 * Khác `themNhanCong`: chỗ kia tạo hồ sơ mới cho người thuê công nhật, chỗ này
 * lấy người đã có trong danh sách nhân sự. Nên nó chỉ có nghĩa với người đọc
 * được danh sách ấy — `is_hr_or_admin()` ở policy `tdtv_insert_hr_admin`. Guard
 * là `batBuocPhien()` để quyền `quan_ly_nhan_su` đi qua đúng như RLS đã cho;
 * insert bị chặn thì PostgREST trả lỗi 42501, không im lặng như update.
 */
export async function themThanhVien(_prev: TrangThaiForm, form: FormData): Promise<TrangThaiForm> {
  await batBuocPhien()

  const toDoiId = chuoi(form, 'to_doi_id')
  const employeeId = chuoi(form, 'employee_id')
  const tuNgay = chuoi(form, 'tu_ngay')

  if (!toDoiId) return { error: 'Thiếu tổ.' }
  if (!employeeId) return { error: 'Chưa chọn người.' }
  if (!tuNgay || !LA_NGAY.test(tuNgay)) return { error: 'Ngày bắt đầu không hợp lệ.' }

  const supabase = await createClient()
  const { error } = await supabase
    .from('to_doi_thanh_vien')
    .insert({ to_doi_id: toDoiId, employee_id: employeeId, tu_ngay: tuNgay })

  if (error) return { error: `Không thêm được: ${dichLoi(error)}` }

  revalidatePath('/nhan-su/to-doi/quan-ly')
  revalidatePath('/nhan-su/to-doi')
  return { error: null, xong: 'Đã thêm vào tổ.' }
}

/**
 * Đặt khoảng thời gian một người ở trong tổ: ngày vào, và ngày rời (nếu đã rời).
 *
 * Thay `ketThucThanhVien` từ 29/08/2026. Bản cũ chỉ ĐẶT được ngày rời tổ, một
 * chiều: gõ nhầm ngày vào tổ thì không đường nào sửa, gõ nhầm ngày rời tổ thì
 * cũng vậy — mà cả hai đều là ngày quyết định người ấy được tính công những
 * hôm nào. Một ô chỉ ghi được mà không sửa được là một ô mời người ta gõ nhầm
 * rồi sống chung với nó.
 *
 * Bỏ trống ô ngày rời = CÒN TRONG TỔ. Nên biểu mẫu này cũng là đường đưa một
 * người quay lại tổ khi cho rời nhầm — database chặn nếu lúc ấy họ đang mở ở
 * một tổ khác (`uniq_thanh_vien_mot_to_dang_mo`), và câu báo đã dịch sẵn.
 *
 * Vẫn KHÔNG xoá dòng: bảng công của những ngày họ còn trong tổ phải giữ
 * nguyên, và ai xem lại sau này phải thấy được họ từng ở đó. Cùng nguyên tắc
 * không xoá cứng của cả dự án.
 *
 * Guard chỉ là `batBuocPhien()` vì cùng lý do với `capNhatToDoi`: policy
 * `tdtv_update_nguoi_cham` (P5c) đã cho người chấm sửa dòng thành viên của tổ
 * mình. Đòi admin ở đây là đóng cửa mà database đã mở, và đóng một cách không
 * nhìn thấy được.
 */
export async function datNgayThanhVien(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  await batBuocPhien()

  const id = chuoi(form, 'id')
  const tuNgay = chuoi(form, 'tu_ngay')
  const denNgay = chuoi(form, 'den_ngay')

  if (!id) return { error: 'Thiếu dòng thành viên.' }
  if (!tuNgay || !LA_NGAY.test(tuNgay)) return { error: 'Ngày vào tổ không hợp lệ.' }
  if (denNgay !== null && !LA_NGAY.test(denNgay)) return { error: 'Ngày rời tổ không hợp lệ.' }
  // Ràng buộc `tdtv_ky_hop_le` ở database mới là lớp chặn; báo sớm ở đây chỉ
  // để người dùng không phải chờ một vòng mạng mới biết mình gõ ngược.
  if (denNgay !== null && denNgay < tuNgay) {
    return { error: 'Ngày rời tổ không được trước ngày vào tổ.' }
  }

  const supabase = await createClient()
  const { data, error } = await supabase
    .from('to_doi_thanh_vien')
    .update({ tu_ngay: tuNgay, den_ngay: denNgay })
    .eq('id', id)
    .select('id')

  if (error) return { error: `Không lưu được: ${dichLoi(error)}` }
  if ((data ?? []).length === 0) return { error: KHONG_PHU_TRACH }

  revalidatePath('/nhan-su/to-doi/quan-ly')
  revalidatePath('/nhan-su/to-doi')
  return {
    error: null,
    xong: denNgay === null ? 'Đã lưu. Người này còn trong tổ.' : 'Đã lưu ngày rời tổ.',
  }
}

/**
 * Giao cho một người quản lý được chấm công cho một tổ.
 *
 * KHÔNG kiểm điều kiện "nhân viên chính thức" ở đây. Trigger
 * `kiem_nguoi_cham_chinh_thuc` ở database mới là lớp chặn, và nó chặn cả
 * đường gọi thẳng PostgREST. Viết lại phép kiểm ở tầng này là tạo ra hai
 * định nghĩa của cùng một quy tắc, rồi tới lúc chúng lệch nhau thì không ai
 * biết bên nào đúng.
 */
export async function giaoNguoiCham(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  await batBuocVaiTro('admin')

  const toDoiId = chuoi(form, 'to_doi_id')
  const appUserId = chuoi(form, 'app_user_id')

  if (!toDoiId) return { error: 'Thiếu tổ.' }
  if (!appUserId) return { error: 'Chưa chọn người quản lý.' }

  const supabase = await createClient()
  const { error } = await supabase
    .from('to_doi_nguoi_cham')
    .insert({ to_doi_id: toDoiId, app_user_id: appUserId })

  if (error) return { error: dichLoi(error) }

  revalidatePath('/nhan-su/to-doi/quan-ly')
  revalidatePath('/nhan-su/to-doi')
  return { error: null, xong: 'Đã giao quyền chấm công.' }
}

/**
 * Gỡ quyền chấm công của một người khỏi một tổ.
 *
 * Xoá hẳn dòng gán — đây là bảng thiết lập quyền, không phải chứng từ. Dữ
 * liệu chấm công đã ghi KHÔNG mất gì: mỗi phiên lưu `nguoi_cham_id` của
 * chính nó, nên vẫn truy ra được ai đã chấm ngày nào.
 */
export async function goNguoiCham(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  await batBuocVaiTro('admin')

  const id = chuoi(form, 'id')
  if (!id) return { error: 'Thiếu dòng cần gỡ.' }

  const supabase = await createClient()
  const { error } = await supabase.from('to_doi_nguoi_cham').delete().eq('id', id)
  if (error) return { error: `Không gỡ được: ${error.message}` }

  revalidatePath('/nhan-su/to-doi/quan-ly')
  revalidatePath('/nhan-su/to-doi')
  return { error: null, xong: 'Đã gỡ quyền chấm công.' }
}

/** Số tiền người dùng gõ: chấp nhận cả "300.000" lẫn "300000". Rỗng → null. */
function soTien(form: FormData, ten: string): number | null {
  const v = String(form.get(ten) ?? '').replace(/[.,\s]/g, '').trim()
  if (v === '') return null
  const n = Number(v)
  return Number.isFinite(n) ? n : Number.NaN
}


/**
 * Đơn giá riêng của một người trong một tổ.
 *
 * Để trống là XOÁ mức đang có — không phải là 0 đồng. Phân biệt hai thứ đó
 * quan trọng: 0 đồng là một mức trả công có thật mà ai đó có thể gõ nhầm, còn
 * "trống" là "chưa khai", và bảng thanh toán từ chối sinh khi chưa khai.
 */
export async function datDonGiaThanhVien(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  await batBuocVaiTro('admin')

  const id = chuoi(form, 'id')
  const donGia = soTien(form, 'don_gia_gio')

  if (!id) return { error: 'Thiếu dòng thành viên.' }
  if (donGia !== null && (Number.isNaN(donGia) || donGia < 0)) {
    return { error: 'Đơn giá giờ không hợp lệ.' }
  }

  const supabase = await createClient()
  // Khai đơn giá giờ là chuyển hẳn người này sang tính theo ca — đúng như hàm
  // `sua_nhan_cong_to()` ở database làm. Không có bước ấy thì người khoán ngày
  // cũ khai xong đơn giá vẫn nằm ở nhánh cũ và bảng thanh toán đọc nhầm cột.
  const { error } = await supabase
    .from('to_doi_thanh_vien')
    .update(donGia === null ? { don_gia_gio: null } : { don_gia_gio: donGia, kieu_tinh: 'gio' })
    .eq('id', id)

  if (error) return { error: `Không lưu được: ${error.message}` }

  // Đọc lại rồi mới báo — cùng lý do với `suaNhanCong`.
  const { data: sau } = await supabase
    .from('to_doi_thanh_vien')
    .select('don_gia_gio')
    .eq('id', id)
    .maybeSingle()

  if (donGia !== null && Number(sau?.don_gia_gio) !== donGia) {
    return {
      error:
        'Đã gọi lưu nhưng đơn giá giờ KHÔNG đổi trong database. Báo lại nguyên văn câu này.',
    }
  }

  revalidatePath('/nhan-su/to-doi/quan-ly')
  revalidatePath('/nhan-su/to-doi')
  return {
    error: null,
    xong:
      donGia === null
        ? 'Đã xoá đơn giá giờ. Bảng thanh toán sẽ từ chối sinh cho tới khi khai lại.'
        : `Đã lưu đơn giá ${Number(donGia).toLocaleString('vi-VN')}đ/giờ.`,
  }
}

/**
 * Người quản lý tự lập tổ cho công ty của mình.
 *
 * Đi qua hàm `tao_to_doi` ở database vì nó làm HAI việc không tách rời: tạo tổ,
 * và gán chính người tạo làm người chấm. Thiếu việc thứ hai thì họ lập xong tổ
 * rồi không chấm được cho chính tổ mình.
 *
 * KHÔNG có ô chọn công ty: công ty suy từ hồ sơ nhân sự của người tạo. Cho họ
 * chọn là mở đường lập tổ cho pháp nhân khác.
 */
export async function taoToDoiCuaToi(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  await batBuocPhien()

  const supabase = await createClient()
  const { error } = await supabase.rpc('tao_to_doi', {
    p_code: chuoi(form, 'code') ?? '',
    p_name: chuoi(form, 'name') ?? '',
    p_department_id: chuoi(form, 'department_id') ?? undefined,
    p_ghi_chu: chuoi(form, 'ghi_chu') ?? undefined,
  })

  // Hàm ở database viết sẵn câu tiếng Việt đầy đủ — giữ nguyên.
  if (error) return { error: error.message }

  revalidatePath('/nhan-su/to-doi/quan-ly')
  revalidatePath('/nhan-su/to-doi')
  return { error: null, xong: 'Đã lập tổ. Bạn là người chấm công của tổ này.' }
}

/** Số tiền: chấp nhận "300.000" lẫn "300000". Rỗng → null. */
function tienHoacNull(form: FormData, ten: string): number | null {
  const v = String(form.get(ten) ?? '').replace(/[.,\s]/g, '').trim()
  if (v === '') return null
  const n = Number(v)
  return Number.isFinite(n) ? n : Number.NaN
}

/**
 * Thêm một nhân công công nhật vào tổ.
 *
 * Hồ sơ rút gọn theo yêu cầu 19/08/2026: họ tên, CCCD, đơn giá, đơn giá ngoài
 * giờ. Ba lần ghi vào ba bảng được gói trong hàm `them_nhan_cong_to` — nới
 * policy cho cả ba là mở vĩnh viễn ba cánh cửa cho vai trò thấp nhất.
 */
export async function themNhanCong(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  await batBuocPhien()

  const toDoiId = chuoi(form, 'to_doi_id')
  const hoTen = chuoi(form, 'ho_ten')
  const donGia = tienHoacNull(form, 'don_gia_gio')
  const donGiaOt = tienHoacNull(form, 'don_gia_ot')

  if (!toDoiId) return { error: 'Thiếu tổ.' }
  if (!hoTen) return { error: 'Thiếu họ và tên.' }
  if (donGia !== null && Number.isNaN(donGia)) return { error: 'Đơn giá giờ không hợp lệ.' }
  if (donGiaOt !== null && Number.isNaN(donGiaOt)) {
    return { error: 'Đơn giá ngoài giờ không hợp lệ.' }
  }

  const supabase = await createClient()
  const { error } = await supabase.rpc('them_nhan_cong_to', {
    p_to_doi_id: toDoiId,
    p_ho_ten: hoTen,
    p_cccd: chuoi(form, 'cccd') ?? undefined,
    p_don_gia_gio: donGia ?? undefined,
    p_don_gia_ot: donGiaOt ?? undefined,
    p_tu_ngay: chuoi(form, 'tu_ngay') ?? undefined,
  })

  if (error) return { error: error.message }

  revalidatePath('/nhan-su/to-doi/quan-ly')
  revalidatePath('/nhan-su/to-doi')
  return { error: null, xong: `Đã thêm ${hoTen} vào tổ.` }
}

/** Sửa nhân công đã thêm. Ô bỏ trống nghĩa là GIỮ NGUYÊN, không phải xoá. */
export async function suaNhanCong(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  await batBuocPhien()

  const id = chuoi(form, 'thanh_vien_id')
  if (!id) return { error: 'Thiếu dòng thành viên.' }

  const donGia = tienHoacNull(form, 'don_gia_gio')
  const donGiaOt = tienHoacNull(form, 'don_gia_ot')
  if (donGia !== null && Number.isNaN(donGia)) return { error: 'Đơn giá giờ không hợp lệ.' }
  if (donGiaOt !== null && Number.isNaN(donGiaOt)) {
    return { error: 'Đơn giá ngoài giờ không hợp lệ.' }
  }

  const supabase = await createClient()
  // Tham số RPC dùng `undefined` cho "không truyền". Ô bỏ trống phải thành
  // undefined chứ không phải null — null là một giá trị, và hàm ở database
  // hiểu "có truyền null" khác hẳn "không truyền".
  const hoTen = chuoi(form, 'ho_ten')

  const { error } = await supabase.rpc('sua_nhan_cong_to', {
    p_thanh_vien_id: id,
    p_ho_ten: hoTen ?? undefined,
    p_cccd: chuoi(form, 'cccd') ?? undefined,
    p_don_gia_gio: donGia ?? undefined,
    p_don_gia_ot: donGiaOt ?? undefined,
  })

  if (error) return { error: error.message }

  // ĐỌC LẠI RỒI MỚI BÁO ĐÃ LƯU.
  //
  // Bản trước báo "Đã lưu." ngay khi RPC không trả lỗi. Nhưng hàm ở database
  // dùng `coalesce(tham_số, giá_trị_cũ)`, nên một tham số không tới nơi thì nó
  // lặng lẽ giữ nguyên giá trị cũ VÀ KHÔNG BÁO GÌ — người dùng nhận "Đã lưu."
  // rồi tải lại trang thấy y như cũ. Triệu Vũ báo đúng tình huống này ngày
  // 24/08/2026 với đơn giá ngoài giờ.
  //
  // Nay câu báo nói ra CON SỐ ĐANG NẰM TRONG DATABASE. Lưu hụt thì nhìn là
  // thấy, không phải tải lại trang mới biết.
  const { data: sau, error: loiDoc } = await supabase
    .from('to_doi_thanh_vien')
    .select('don_gia_gio, don_gia_ot, employees ( full_name )')
    .eq('id', id)
    .maybeSingle()

  if (loiDoc) return { error: `Đã gọi lưu nhưng không đọc lại được: ${loiDoc.message}` }
  if (!sau) return { error: 'Đã gọi lưu nhưng không tìm thấy dòng này nữa.' }

  revalidatePath('/nhan-su/to-doi/quan-ly')
  revalidatePath('/nhan-su/to-doi')

  const noiTien = (n: number | null) =>
    n === null ? 'chưa có' : `${Number(n).toLocaleString('vi-VN')}đ`

  // Gửi lên một con số mà đọc lại vẫn khác nó thì nói thẳng, đừng báo thành công.
  const hut: string[] = []
  if (donGiaOt !== null && Number(sau.don_gia_ot) !== donGiaOt) hut.push('đơn giá ngoài giờ')
  if (donGia !== null && Number(sau.don_gia_gio) !== donGia) hut.push('đơn giá giờ')
  // Ô họ tên mới có từ 29/08/2026, và nó ghi sang bảng `employees` chứ không
  // phải bảng thành viên — nên phải hỏi riêng, đừng tin là đã đổi.
  const tenSau = (sau.employees as { full_name: string } | null)?.full_name ?? null
  if (hoTen !== null && tenSau !== hoTen) hut.push('họ tên')

  if (hut.length > 0) {
    return {
      error:
        `Đã gọi lưu nhưng ${hut.join(' và ')} KHÔNG đổi trong database ` +
        `(đang là ${noiTien(sau.don_gia_gio)}/giờ · ngoài giờ ${noiTien(sau.don_gia_ot)}). ` +
        'Báo lại nguyên văn câu này.',
    }
  }

  return {
    error: null,
    xong: `Đã lưu: ${noiTien(sau.don_gia_gio)}/giờ · ngoài giờ ${noiTien(sau.don_gia_ot)}.`,
  }
}

/** Admin bật/tắt quyền quản lý tổ đội cho một tài khoản. */
export async function datQuyenQuanLyToDoi(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  await batBuocVaiTro('admin')

  const id = chuoi(form, 'app_user_id')
  if (!id) return { error: 'Thiếu tài khoản.' }

  const supabase = await createClient()
  const { error } = await supabase
    .from('app_users')
    .update({ quan_ly_to_doi: form.get('bat') !== null })
    .eq('id', id)

  if (error) return { error: `Không lưu được: ${error.message}` }

  revalidatePath('/nhan-su/to-doi/quan-ly')
  return { error: null, xong: 'Đã lưu quyền.' }
}

/**
 * Admin chọn chức danh dùng cho nhân công công nhật.
 *
 * Chỉ MỘT chức danh mang cờ này (chỉ mục duy nhất từng phần ở database), nên
 * phải gỡ cờ cũ trước rồi mới đặt cờ mới.
 */
export async function datChucDanhCongNhat(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  await batBuocVaiTro('admin')

  const id = chuoi(form, 'position_id')
  if (!id) return { error: 'Chưa chọn chức danh.' }

  const supabase = await createClient()

  const { error: loiGo } = await supabase
    .from('positions')
    .update({ la_cong_nhat: false })
    .eq('la_cong_nhat', true)
  if (loiGo) return { error: `Không gỡ được cờ cũ: ${loiGo.message}` }

  const { error } = await supabase.from('positions').update({ la_cong_nhat: true }).eq('id', id)
  if (error) return { error: `Không đặt được chức danh công nhật: ${error.message}` }

  revalidatePath('/nhan-su/to-doi/quan-ly')
  return { error: null, xong: 'Đã đặt chức danh dùng cho nhân công công nhật.' }
}

/**
 * Đặt một người trong tổ làm tổ trưởng.
 *
 * Đặt từ chính dòng của họ trong danh sách nhân công, không phải từ một ô
 * chọn riêng trên biểu mẫu tổ. Ô chọn cũ liệt kê TOÀN BỘ nhân sự công ty —
 * mà tổ trưởng công nhật là người trong nhóm thợ, nên danh sách đó vừa dài
 * vừa gợi ý sai người.
 *
 * Guard chỉ là `batBuocPhien()`: RLS trên `to_doi` đã nói đúng ai được sửa
 * tổ nào (HR/admin, hoặc người được giao chấm công cho chính tổ đó), và cột
 * `to_truong_id` nằm trong quyền cấp cột. Viết lại điều kiện ở đây là tạo
 * bản thứ hai của một quy tắc đã có, và bản thứ hai sẽ lệch.
 */
export async function datToTruong(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  await batBuocPhien()

  const toDoiId = chuoi(form, 'to_doi_id')
  const employeeId = chuoi(form, 'employee_id')
  if (!toDoiId) return { error: 'Thiếu tổ.' }

  const supabase = await createClient()
  const { data, error } = await supabase
    .from('to_doi')
    .update({ to_truong_id: employeeId })
    .eq('id', toDoiId)
    .select('id')

  // Trigger ở database viết sẵn câu tiếng Việt đầy đủ — giữ nguyên.
  if (error) return { error: error.message }
  if ((data ?? []).length === 0) return { error: KHONG_PHU_TRACH }

  revalidatePath('/nhan-su/to-doi/quan-ly')
  return { error: null, xong: employeeId ? 'Đã đặt tổ trưởng.' : 'Đã gỡ chức tổ trưởng.' }
}
