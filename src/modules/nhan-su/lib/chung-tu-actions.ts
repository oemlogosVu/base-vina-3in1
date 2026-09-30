'use server'

import { revalidatePath } from 'next/cache'
import { sinhChungTu, type LoaiChungTu } from '@ns/lib/chung-tu'
import { batBuocPhien } from '@ns/lib/phien'

export type TrangThaiChungTu = { error: string | null; xong?: string }

/**
 * Sinh lại chứng từ cho một mục đang thiếu.
 *
 * Chứng từ sinh tự động ngay sau khi chốt, nhưng việc ấy là một lời gọi mạng
 * và nó hỏng được. Không có nút này thì một lần mạng chập nghĩa là vĩnh viễn
 * không có chứng từ cho kỳ đó — và không ai biết.
 *
 * KHÔNG kiểm quyền ở đây. Edge Function tự kiểm: kỳ lương đòi quyền tính
 * lương, bảng thanh toán đòi quyền đọc bảng ấy. Viết lại điều kiện ở tầng này
 * là tạo bản sao thứ hai của cùng một quy tắc.
 */
export async function sinhChungTuLai(
  _prev: TrangThaiChungTu,
  form: FormData,
): Promise<TrangThaiChungTu> {
  await batBuocPhien()

  const loai = String(form.get('loai') ?? '') as LoaiChungTu
  const id = String(form.get('doi_tuong_id') ?? '').trim()

  if (loai !== 'bang_thanh_toan_to' && loai !== 'ky_luong') {
    return { error: 'Loại chứng từ không hợp lệ.' }
  }
  if (!id) return { error: 'Thiếu mục cần sinh chứng từ.' }

  const { chungTu, loi } = await sinhChungTu(loai, id)
  if (loi) return { error: loi }

  revalidatePath('/nhan-su/to-doi/thanh-toan')
  revalidatePath('/nhan-su/luong/ky-luong')
  return { error: null, xong: `Đã sinh chứng từ ${chungTu?.so_hieu ?? ''}.` }
}
