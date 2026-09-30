'use server'

import { revalidatePath } from 'next/cache'
import { createClient } from '@ns/lib/supabase/server'
import { batBuocCong, batBuocPhien, CONG_DUYET_CONG_TO } from '@ns/lib/phien'
import { gioGon, kiemGioMotNguoi, type KhoangGio } from '@ns/lib/gio-chuan'

export type KetQuaLuu = { error: string | null; phienId?: string }
export type TrangThaiForm = { error: string | null; xong?: string }

/**
 * Một dòng chấm công của một người: BA CẶP GIỜ VÀO–GIỜ RA.
 *
 * Từ P5f (24/08/2026) tổ trưởng ghi giờ THẬT của từng người từng ca; giờ ca
 * của công ty chỉ là giá trị mặc định rót vào ô. Số giờ thường và số giờ ngoài
 * giờ vẫn do trigger `trg_cccn_tinh_gio_tu_ca` ở database tính — client gửi số
 * giờ nào cũng bị ghi đè, và quyền cấp cột cũng không cho gửi. Ngoài giờ là
 * tiền; để người chấm tự gõ con số ấy là để họ tự quyết định tiền.
 */
export type DongCham = {
  employeeId: string
  /** Tên để câu lỗi gọi đúng người. Không đi vào database. */
  ten?: string
  /** `null` = không làm ca ấy. Cả hai đầu phải cùng có hoặc cùng không. */
  caSang: KhoangGio | null
  caChieu: KhoangGio | null
  caToi: KhoangGio | null
  /** Khoảng làm thêm ngoài ba ca. Toàn bộ tính là ngoài giờ. */
  ngoaiGio: KhoangGio | null
  /**
   * Tiền thưởng ẤN ĐỊNH cho người này trong ngày này (P5i, 25/08/2026).
   *
   * Đơn vị ĐỒNG, không phải hệ số và không nhân với gì cả. Tên trường là
   * `tienThuong` chứ không phải `thuong`: trong màn chấm công, "thường" đã
   * mang nghĩa GIỜ THƯỜNG (đối lập với ngoài giờ), và hai thứ cùng tên trong
   * một file là cách chắc chắn để một hôm nào đó cộng nhầm.
   */
  tienThuong: number
  /** Bắt buộc khi tienThuong > 0 — database cũng đòi, không chỉ giao diện. */
  thuongLyDo: string
}

const LA_NGAY = /^\d{4}-\d{2}-\d{2}$/

/** Sáu cột giờ cộng hai cột thưởng của một dòng, đúng tên cột ở database. */
function coCa(d: DongCham) {
  return {
    ca_sang_tu: d.caSang?.bd ?? null,
    ca_sang_den: d.caSang?.kt ?? null,
    ca_chieu_tu: d.caChieu?.bd ?? null,
    ca_chieu_den: d.caChieu?.kt ?? null,
    ca_toi_tu: d.caToi?.bd ?? null,
    ca_toi_den: d.caToi?.kt ?? null,
    ngoai_gio_tu: d.ngoaiGio?.bd ?? null,
    ngoai_gio_den: d.ngoaiGio?.kt ?? null,
    thuong: d.tienThuong,
    // Chuỗi rỗng phải thành NULL: ràng buộc `cccn_thuong_phai_co_ly_do` coi
    // chuỗi trắng là không có lý do, và một chuỗi rỗng lưu được sẽ làm ràng
    // buộc ấy trông như đang chạy trong khi nó không chặn gì.
    thuong_ly_do: d.thuongLyDo.trim() === '' ? null : d.thuongLyDo.trim(),
  }
}

/** Database trả "07:00:00", client gửi "07:00" — so bằng thì phải cắt giây. */
const gonHoacNull = (g: string | null) => (g === null ? null : gioGon(g))

/**
 * Lưu số công của cả tổ trong một ngày.
 *
 * KHÔNG kiểm vai trò ở đây, và đó là cố ý: người được giao chấm công thường
 * mang vai trò `nhan_vien`. Thứ quyết định họ ghi được cho tổ nào là RLS —
 * policy `phien_insert_nguoi_cham` và `cccn_insert_nguoi_cham` gọi hàm
 * `la_nguoi_cham_cong_to()`. Thêm một phép kiểm vai trò ở tầng này chỉ tạo
 * ảo giác an toàn và chặn nhầm đúng người cần dùng.
 *
 * Trả về phienId để phía client tải ảnh lên ngay sau đó: ảnh phải gắn vào một
 * phiên đã tồn tại, nên số công lưu trước, ảnh theo sau. Thứ tự này cũng là
 * lý do một phiên có thể tạm thời chưa có ảnh — và ràng buộc ở database
 * không cho duyệt phiên như vậy.
 */
export async function luuChamCongTo(
  toDoiId: string,
  ngay: string,
  dsCong: DongCham[],
): Promise<KetQuaLuu> {
  await batBuocPhien()

  if (!toDoiId) return { error: 'Chưa chọn tổ.' }
  if (!LA_NGAY.test(ngay)) return { error: 'Ngày không hợp lệ.' }
  if (dsCong.length === 0) return { error: 'Tổ chưa có thành viên nào để chấm công.' }

  // Kiểm HẾT rồi mới ghi, và nói bằng tiếng người. Không có bước này thì bốn
  // ràng buộc `cccn_*` ở database chặn đúng nhưng trả về nguyên văn
  // 'violates check constraint "cccn_ngoai_gio_xuoi"' — không nói được ai,
  // khoảng nào, sai gì, phải làm sao.
  for (const d of dsCong) {
    const loi = kiemGioMotNguoi(d.ten ?? 'Một người trong tổ', [
      { nhan: 'ca sáng', gt: d.caSang },
      { nhan: 'ca chiều', gt: d.caChieu },
      { nhan: 'ca tối', gt: d.caToi },
      { nhan: 'ngoài giờ', gt: d.ngoaiGio },
    ])
    if (loi !== null) return { error: loi }

    // Kiểm cả ở đây lẫn ở database. Không thừa: người gọi thẳng PostgREST bỏ
    // qua tầng này, còn người dùng bình thường cần một câu tiếng Việt ngay tại
    // ô nhập thay vì nguyên văn 'violates check constraint'.
    if (!Number.isFinite(d.tienThuong) || d.tienThuong < 0) {
      return { error: `Tiền thưởng của ${d.ten ?? 'một người trong tổ'} không hợp lệ.` }
    }
    if (d.tienThuong > 0 && d.thuongLyDo.trim() === '') {
      return {
        error:
          `Có thưởng cho ${d.ten ?? 'một người trong tổ'} thì phải ghi lý do. ` +
          'Một khoản tiền không có chữ nào đi kèm là một câu hỏi không ai trả lời được sau vài tháng.',
      }
    }
  }

  // Không cho chấm cho ngày mai. Chấm trước là ghi công cho việc chưa xảy ra.
  // Chấm bù cho ngày đã qua thì vẫn được — sóng yếu ngoài công trường là
  // chuyện thường, và phiên nào cũng ghi lại thời điểm chấm thật.
  const homNay = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Ho_Chi_Minh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date())
  if (ngay > homNay) return { error: 'Không chấm công cho ngày chưa tới.' }

  const supabase = await createClient()

  // ---- 1. Phiên của tổ trong ngày đó ----
  const { data: phienCu, error: loiDoc } = await supabase
    .from('phien_cham_cong_to')
    .select('id, da_duyet')
    .eq('to_doi_id', toDoiId)
    .eq('work_date', ngay)
    .maybeSingle()

  if (loiDoc) return { error: `Không đọc được phiên chấm công: ${loiDoc.message}` }
  if (phienCu?.da_duyet) {
    return { error: 'Phiên này đã được duyệt, không sửa được nữa. Liên hệ nhân sự nếu cần mở lại.' }
  }

  let phienId = phienCu?.id ?? null

  if (!phienId) {
    const phien = await batBuocPhien()
    const { data, error } = await supabase
      .from('phien_cham_cong_to')
      .insert({ to_doi_id: toDoiId, work_date: ngay, nguoi_cham_id: phien.userId })
      .select('id')
      .single()

    if (error) {
      // 23505 = trùng khoá: hai lần bấm sát nhau cùng tạo phiên. Đọc lại dòng
      // người kia vừa tạo thay vì báo lỗi — kết quả người dùng mong đợi là
      // công đã được lưu, không phải một thông báo về khoá trùng.
      if (error.code === '23505') {
        const { data: lai } = await supabase
          .from('phien_cham_cong_to')
          .select('id')
          .eq('to_doi_id', toDoiId)
          .eq('work_date', ngay)
          .maybeSingle()
        phienId = lai?.id ?? null
      }
      if (!phienId) {
        return {
          error:
            error.code === '42501' || error.message.includes('policy')
              ? 'Bạn không được giao chấm công cho tổ này.'
              : `Không tạo được phiên chấm công: ${error.message}`,
        }
      }
    } else {
      phienId = data.id
    }
  }

  // ---- 2. Số công từng người ----
  //
  // Tách THÊM và SỬA thay vì dùng upsert: upsert của PostgREST ghi lại mọi
  // cột trong payload, kể cả phien_id / work_date / employee_id, mà quyền cấp
  // cột cố ý KHÔNG cho sửa ba cột đó. Upsert sẽ bị từ chối, và bị từ chối vì
  // đúng lý do — nên đi đường khác chứ không nới quyền.
  const { data: dangCo, error: loiDongCu } = await supabase
    .from('cham_cong_cong_nhat')
    .select(
      'id, employee_id, ca_sang_tu, ca_sang_den, ca_chieu_tu, ca_chieu_den, ca_toi_tu, ca_toi_den, ngoai_gio_tu, ngoai_gio_den, thuong, thuong_ly_do',
    )
    .eq('phien_id', phienId)

  if (loiDongCu) return { error: `Không đọc được số công đã ghi: ${loiDongCu.message}` }

  const cu = new Map((dangCo ?? []).map((r) => [r.employee_id, r]))

  const themMoi = dsCong
    .filter((d) => !cu.has(d.employeeId))
    .map((d) => ({
      phien_id: phienId,
      work_date: ngay,
      employee_id: d.employeeId,
      ...coCa(d),
    }))

  if (themMoi.length > 0) {
    const { error } = await supabase.from('cham_cong_cong_nhat').insert(themMoi)
    if (error) {
      return {
        error:
          error.code === '23505'
            ? 'Có người trong tổ đã được chấm công ở một tổ khác trong ngày này.'
            : `Không lưu được số công: ${error.message}`,
      }
    }
  }

  // Chỉ ghi lại dòng THỰC SỰ đổi. Tổ 15 người mà lần nào cũng ghi đủ 15 dòng
  // là 15 lượt mạng cho một thao tác thường chỉ sửa một hai ô.
  for (const d of dsCong) {
    const truoc = cu.get(d.employeeId)
    if (!truoc) continue
    const moi = coCa(d)
    // So từng cột để chỉ ghi dòng THỰC SỰ đổi. Hai cột thưởng không phải giờ
    // nên không đi qua `gonHoacNull`: `thuong` là số (database trả "100000.00"
    // dạng chuỗi), `thuong_ly_do` là chữ.
    const khongDoi =
      Number(truoc.thuong ?? 0) === moi.thuong &&
      (truoc.thuong_ly_do ?? null) === moi.thuong_ly_do &&
      (['ca_sang_tu', 'ca_sang_den', 'ca_chieu_tu', 'ca_chieu_den', 'ca_toi_tu',
        'ca_toi_den', 'ngoai_gio_tu', 'ngoai_gio_den'] as const).every(
        (k) => gonHoacNull(truoc[k]) === moi[k],
      )
    if (khongDoi) continue

    const { error } = await supabase
      .from('cham_cong_cong_nhat')
      .update(moi)
      .eq('id', truoc.id)
    if (error) return { error: `Không sửa được giờ: ${error.message}` }
  }

  revalidatePath('/nhan-su/to-doi')
  return { error: null, phienId: phienId ?? undefined }
}

/**
 * Duyệt một phiên chấm công tổ.
 *
 * Ràng buộc `phien_duyet_phai_co_anh` ở database chặn phiên chưa có ảnh. Kiểm
 * lại ở đây chỉ để báo bằng tiếng người thay vì ném lỗi ràng buộc thô lên màn
 * hình — lớp chặn thật vẫn nằm dưới database.
 *
 * AI DUYỆT ĐƯỢC (P5h, 24/08/2026): HR/admin, chức danh mang quyền `duyet_cong`,
 * và NGƯỜI CHẤM của chính tổ ấy. Vế cuối là quyết định của Triệu Vũ hôm nay —
 * đánh đổi ghi trong migration P5h.
 *
 * Không kiểm quyền bằng vai trò ở đây nữa: ba đường ấy đã là ba policy ở
 * database, chép lại bằng TypeScript là tạo bản thứ hai sẽ lệch. Thay vào đó
 * ĐỌC LẠI sau khi ghi — policy từ chối thì UPDATE chạm 0 dòng mà PostgREST
 * không báo lỗi, và "Đã duyệt" khi chưa duyệt là kiểu hỏng tệ nhất ở đây.
 */
export async function duyetPhienChamCongTo(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  const phien = await batBuocPhien()

  const id = String(form.get('id') ?? '').trim()
  if (!id) return { error: 'Thiếu mã phiên.' }

  const supabase = await createClient()

  const { data: truoc, error: loiDoc } = await supabase
    .from('phien_cham_cong_to')
    .select('anh_path, da_duyet')
    .eq('id', id)
    .maybeSingle()

  if (loiDoc) return { error: `Không đọc được phiên: ${loiDoc.message}` }
  if (!truoc) return { error: 'Không tìm thấy phiên chấm công.' }
  if (truoc.da_duyet) return { error: 'Phiên này đã được duyệt rồi.' }
  if (!truoc.anh_path) {
    return { error: 'Phiên chưa có ảnh xác minh — người chấm phải tải ảnh lên trước khi duyệt.' }
  }
  const { error } = await supabase
    .from('phien_cham_cong_to')
    .update({ da_duyet: true, duyet_boi: phien.userId, duyet_luc: new Date().toISOString() })
    .eq('id', id)

  if (error) return { error: `Không duyệt được: ${error.message}` }

  revalidatePath('/nhan-su/to-doi')
  return { error: null, xong: 'Đã duyệt. Người chấm không sửa được phiên này nữa.' }
}

/**
 * Mở lại một phiên đã duyệt.
 *
 * Có chủ đích là hành động RIÊNG chứ không phải "sửa lại cho nhanh": duyệt là
 * lời khẳng định của nhân sự về công của người khác, nên rút lại nó phải để
 * lại dấu vết và phải do người có quyền làm.
 */
export async function moLaiPhienChamCongTo(
  _prev: TrangThaiForm,
  form: FormData,
): Promise<TrangThaiForm> {
  await batBuocCong(CONG_DUYET_CONG_TO)

  const id = String(form.get('id') ?? '').trim()
  if (!id) return { error: 'Thiếu mã phiên.' }

  const supabase = await createClient()
  const { error } = await supabase
    .from('phien_cham_cong_to')
    .update({ da_duyet: false, duyet_boi: null, duyet_luc: null })
    .eq('id', id)

  if (error) return { error: `Không mở lại được: ${error.message}` }

  revalidatePath('/nhan-su/to-doi')
  return { error: null, xong: 'Đã mở lại. Người chấm sửa được số công và ảnh của phiên này.' }
}
