'use server'

import { revalidatePath } from 'next/cache'
import { createClient } from '@ns/lib/supabase/server'
import { batBuocCong, CONG_SUA_CHUA_CONG } from '@ns/lib/phien'

export type TrangThaiForm = { error: string | null; xong?: string }

const LA_NGAY = /^\d{4}-\d{2}-\d{2}$/
const LA_GIO = /^\d{2}:\d{2}$/

function chuoi(form: FormData, ten: string): string {
  return String(form.get(ten) ?? '').trim()
}

/**
 * Lý do là phần quan trọng nhất của mọi hành động ở màn này.
 *
 * Kiểm cả ở đây lẫn ở database, và đó KHÔNG phải trùng lặp thừa: người gọi
 * thẳng PostgREST bỏ qua tầng này, còn người dùng bình thường cần câu báo lỗi
 * ngay tại ô nhập thay vì một mã lỗi Postgres.
 */
function kiemLyDo(lyDo: string): string | null {
  if (lyDo.length < 10) {
    return 'Lý do phải ít nhất 10 ký tự. Đây là dòng duy nhất giải thích vì sao công bị sửa.'
  }
  return null
}

/**
 * Chấm bù một ngày công chưa từng được bấm.
 *
 * Toàn bộ phần khó nằm ở `cham_bu_cong()` trong database, cố ý: nó phải ghi
 * vào `attendance_logs` — bảng không cho `authenticated` ghi từ P2 — phải từ
 * chối khi kỳ lương đã chốt, và phải tổng hợp lại ngày đó. Viết lại các quy
 * tắc ấy ở tầng này là tạo bản sao thứ hai của cùng một logic tiền.
 */
export async function chamBuCong(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  await batBuocCong(CONG_SUA_CHUA_CONG)

  const employeeId = chuoi(form, 'employee_id')
  const ngay = chuoi(form, 'work_date')
  const gioVao = chuoi(form, 'gio_vao')
  const gioRa = chuoi(form, 'gio_ra')
  const lyDo = chuoi(form, 'ly_do')

  if (!employeeId) return { error: 'Chưa chọn người.' }
  if (!LA_NGAY.test(ngay)) return { error: 'Ngày không hợp lệ.' }
  if (!LA_GIO.test(gioVao) || !LA_GIO.test(gioRa)) return { error: 'Giờ vào/ra không hợp lệ.' }
  if (gioRa <= gioVao) return { error: 'Giờ ra phải sau giờ vào.' }

  const loiLyDo = kiemLyDo(lyDo)
  if (loiLyDo) return { error: loiLyDo }

  const supabase = await createClient()
  const { data, error } = await supabase.rpc('cham_bu_cong', {
    p_employee_id: employeeId,
    p_work_date: ngay,
    p_gio_vao: gioVao,
    p_gio_ra: gioRa,
    p_ly_do: lyDo,
  })

  // Database đã viết sẵn câu tiếng Việt đầy đủ, và với kỳ đã chốt nó còn chỉ
  // luôn đường đi tiếp. Giữ nguyên thay vì gói lại thành câu chung chung.
  if (error) return { error: error.message }

  revalidatePath('/nhan-su/sua-chua-cong')
  revalidatePath('/nhan-su/cham-cong/xac-nhan')
  return { error: null, xong: `Đã chấm bù ngày ${ngay} — ${data ?? 0} phút làm việc.` }
}

/**
 * Chấm bù cho NHIỀU người cùng lúc, cùng giờ, cùng một lý do.
 *
 * Vì sao có bản hàng loạt trong khi đã có bản một người: tình huống thật gần
 * như luôn là cả nhóm — máy chấm công hỏng cả buổi, tổ đi công trường xa
 * không có sóng. Bắt gõ lại cùng một lý do năm lần là ép người dùng viết cho
 * xong, và lý do viết cho xong thì vô dụng đúng lúc cần đọc nó.
 *
 * MỘT LÝ DO CHUNG LÀ TRUNG THỰC ở đây: năm người bị sót vì cùng một nguyên
 * nhân thì lý do của họ giống nhau thật.
 *
 * Không dừng ở người đầu tiên lỗi. Mỗi người là một lời gọi `cham_bu_cong()`
 * riêng, ai được thì được — rồi báo lại đúng ai không được và vì sao. Dừng
 * giữa chừng để lại một nửa đã ghi mà người dùng không biết là nửa nào.
 */
export async function chamBuHangLoat(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  await batBuocCong(CONG_SUA_CHUA_CONG)

  const ngay = chuoi(form, 'work_date')
  const gioVao = chuoi(form, 'gio_vao')
  const gioRa = chuoi(form, 'gio_ra')
  const lyDo = chuoi(form, 'ly_do')
  const ids = form.getAll('nguoi').map(String).filter(Boolean)

  if (!LA_NGAY.test(ngay)) return { error: 'Ngày không hợp lệ.' }
  if (ids.length === 0) return { error: 'Chưa tick ai để chấm bù.' }
  if (!LA_GIO.test(gioVao) || !LA_GIO.test(gioRa)) return { error: 'Giờ vào/ra không hợp lệ.' }

  const loiLyDo = kiemLyDo(lyDo)
  if (loiLyDo) return { error: loiLyDo }

  const supabase = await createClient()
  const hong: string[] = []
  let xong = 0

  for (const id of ids) {
    // GIỜ RIÊNG TỪNG NGƯỜI, giờ chung chỉ là mặc định.
    //
    // Công của nhân viên chính thức tính RA TỪ GIỜ, không phải một con số gõ
    // vào: nửa ngày là 08:00–12:00. Bắt cả nhóm dùng chung một cặp giờ nghĩa
    // là ai làm nửa buổi cũng bị ghi đủ ngày công — sai theo hướng trả thừa,
    // và không ai phát hiện cho tới lúc đối chiếu quỹ.
    const vao = chuoi(form, `gio_vao_${id}`) || gioVao
    const ra = chuoi(form, `gio_ra_${id}`) || gioRa

    if (!LA_GIO.test(vao) || !LA_GIO.test(ra) || ra <= vao) {
      hong.push(`giờ của một người không hợp lệ (${vao}–${ra})`)
      continue
    }

    const { error } = await supabase.rpc('cham_bu_cong', {
      p_employee_id: id,
      p_work_date: ngay,
      p_gio_vao: vao,
      p_gio_ra: ra,
      p_ly_do: lyDo,
    })
    if (error) hong.push(error.message)
    else xong += 1
  }

  revalidatePath('/nhan-su/sua-chua-cong')
  revalidatePath('/nhan-su/cham-cong/xac-nhan')

  if (hong.length > 0) {
    // Câu lỗi của database đã nêu đích danh người và lý do. Gộp lại thay vì
    // rút gọn thành "một số người không chấm bù được" — người dùng cần biết
    // AI trượt để đi xử lý tiếp.
    return {
      error:
        `Đã chấm bù ${xong}/${ids.length} người. Không làm được cho ${hong.length} người: ` +
        [...new Set(hong)].join(' · '),
    }
  }

  return { error: null, xong: `Đã chấm bù ngày ${ngay} cho ${xong} người.` }
}

/** Xoá một lần chấm sai. Bản gốc chỉ xoá MỀM, vẫn tra lại được ở Thùng rác. */
export async function xoaLanChamSai(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  await batBuocCong(CONG_SUA_CHUA_CONG)

  const id = chuoi(form, 'log_id')
  const lyDo = chuoi(form, 'ly_do')
  if (!id) return { error: 'Thiếu lần chấm cần xoá.' }

  const loiLyDo = kiemLyDo(lyDo)
  if (loiLyDo) return { error: loiLyDo }

  const supabase = await createClient()
  const { error } = await supabase.rpc('xoa_lan_cham_de_sua', {
    p_log_id: id,
    p_ly_do: lyDo,
  })
  if (error) return { error: error.message }

  revalidatePath('/nhan-su/sua-chua-cong')
  revalidatePath('/nhan-su/cham-cong/xac-nhan')
  return {
    error: null,
    xong: 'Đã xoá lần chấm. Bản gốc vẫn nằm trong Thùng rác — chấm bù lại giờ đúng nếu cần.',
  }
}

/** Mở lại một phiên chấm công tổ đội đã duyệt. */
export async function moLaiPhien(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  await batBuocCong(CONG_SUA_CHUA_CONG)

  const id = chuoi(form, 'phien_id')
  const lyDo = chuoi(form, 'ly_do')
  if (!id) return { error: 'Thiếu phiên cần mở lại.' }

  const loiLyDo = kiemLyDo(lyDo)
  if (loiLyDo) return { error: loiLyDo }

  const supabase = await createClient()
  const { error } = await supabase.rpc('mo_lai_phien_to', {
    p_phien_id: id,
    p_ly_do: lyDo,
  })
  if (error) return { error: error.message }

  revalidatePath('/nhan-su/sua-chua-cong')
  revalidatePath('/nhan-su/to-doi/quan-ly')
  return {
    error: null,
    xong: 'Đã mở lại phiên. Người chấm sửa được số công, và phải duyệt lại sau khi sửa.',
  }
}

/**
 * Tạo khoản truy lĩnh cho ngày công sót của một kỳ ĐÃ CHỐT.
 *
 * Số tiền do người tạo chốt và được LƯU LẠI, không tính lại lúc chạy lương —
 * bài học 19/08: mọi khoản ra tiền phải chụp lại căn cứ, sửa mức lương về sau
 * không được làm đổi một khoản đã duyệt.
 */
export async function taoTruyLinh(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  await batBuocCong(CONG_SUA_CHUA_CONG)

  const employeeId = chuoi(form, 'employee_id')
  const ngayGoc = chuoi(form, 'ngay_goc')
  const lyDo = chuoi(form, 'ly_do')
  const soTien = Number(chuoi(form, 'so_tien').replace(/[.,\s]/g, ''))
  const canCuTho = chuoi(form, 'can_cu')

  if (!employeeId) return { error: 'Chưa chọn người.' }
  if (!LA_NGAY.test(ngayGoc)) return { error: 'Ngày gốc không hợp lệ.' }
  if (!Number.isFinite(soTien) || soTien <= 0) return { error: 'Số tiền phải lớn hơn 0.' }

  const loiLyDo = kiemLyDo(lyDo)
  if (loiLyDo) return { error: loiLyDo }

  const supabase = await createClient()
  const { data, error } = await supabase.rpc('tao_truy_linh', {
    p_employee_id: employeeId,
    p_ngay_goc: ngayGoc,
    p_so_tien: soTien,
    p_ly_do: lyDo,
    p_can_cu: canCuTho ? { cach_tinh: canCuTho } : {},
  })
  if (error) return { error: error.message }

  const ky = (data as { can_cu?: { ky_tra?: string } } | null)?.can_cu?.ky_tra
  revalidatePath('/nhan-su/sua-chua-cong')
  revalidatePath('/nhan-su/luong/ky-luong')
  return {
    error: null,
    xong: `Đã tạo khoản truy lĩnh, sẽ trả vào kỳ ${ky ?? 'đang mở'}. Tính lại lương kỳ đó để nó vào phiếu.`,
  }
}
