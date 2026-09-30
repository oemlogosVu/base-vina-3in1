import { createClient } from '@ns/lib/supabase/server'

/**
 * Chứng từ PDF — phía ứng dụng.
 *
 * Toàn bộ việc dựng file, tính vân tay và ghi bản ghi nằm trong Edge Function
 * `chung-tu`. File này chỉ làm ba việc: gọi nó, đọc lại kết quả, và tạo đường
 * tải có hạn.
 *
 * KHÔNG dựng PDF ở tầng Next.js, dù kỹ thuật thì làm được. Bucket và bảng
 * `chung_tu` chỉ nhận ghi từ `service_role`, mà `service_role` thì tuyệt đối
 * không được có mặt trong ứng dụng web (quy ước từ P2, xem `src/lib/env.ts`).
 * Một đường ghi, một chỗ.
 */

export type LoaiChungTu = 'bang_thanh_toan_to' | 'ky_luong'

export type ChungTu = {
  id: string
  so_hieu: string
  loai: LoaiChungTu
  doi_tuong_id: string
  duong_dan: string
  tong_tien: number
  so_dong: number
  tao_luc: string
}

/**
 * Gọi Edge Function sinh chứng từ.
 *
 * Trả về `null` cho lỗi — chứ KHÔNG ném. Chỗ gọi là ngay sau khi chốt kỳ lương
 * hoặc sinh bảng thanh toán, và hai việc ấy ĐÃ XONG rồi. Ném lỗi ở đây sẽ làm
 * người dùng tưởng việc chính hỏng, rồi bấm lại.
 *
 * Thiếu chứng từ không mất đi đâu: `chung_tu_con_thieu` nhìn thấy được, và có
 * nút sinh lại.
 */
export async function sinhChungTu(
  loai: LoaiChungTu,
  doiTuongId: string,
): Promise<{ chungTu: ChungTu | null; loi: string | null }> {
  const supabase = await createClient()
  const { data, error } = await supabase.functions.invoke('chung-tu', {
    body: { loai, doi_tuong_id: doiTuongId },
  })

  if (error) {
    // `functions.invoke` gói mọi mã khác 2xx thành một câu chung chung; câu lý
    // do thật nằm trong thân phản hồi. Bài học đã ghi ở màn quản trị người dùng.
    const ctx = (error as { context?: unknown }).context
    if (ctx instanceof Response) {
      try {
        const than = await ctx.json()
        if (typeof than?.loi === 'string') return { chungTu: null, loi: than.loi }
      } catch {
        // Thân không phải JSON — rơi xuống câu mặc định.
      }
    }
    return { chungTu: null, loi: error instanceof Error ? error.message : 'Không gọi được máy chủ.' }
  }

  if (data?.loi) return { chungTu: null, loi: String(data.loi) }
  return { chungTu: (data?.chung_tu ?? null) as ChungTu | null, loi: null }
}

/** Chứng từ của một loạt đối tượng, tra theo id. RLS lọc hộ phần không được đọc. */
export async function layChungTuTheoDoiTuong(
  loai: LoaiChungTu,
  ids: string[],
): Promise<Map<string, ChungTu>> {
  if (ids.length === 0) return new Map()
  const supabase = await createClient()
  const { data } = await supabase
    .from('chung_tu')
    .select('id, so_hieu, loai, doi_tuong_id, duong_dan, tong_tien, so_dong, tao_luc')
    .eq('loai', loai)
    .in('doi_tuong_id', ids)
  return new Map(((data ?? []) as ChungTu[]).map((c) => [c.doi_tuong_id, c]))
}

/**
 * Đường tải file, có hạn 10 phút.
 *
 * Bucket là private nên không có đường công khai. Link ký sẵn KHÔNG kiểm quyền
 * lại lúc bấm — ai cầm link là tải được — nên hạn phải ngắn, và link chỉ được
 * dựng cho người vừa qua RLS ở câu truy vấn phía trên.
 */
export async function duongTaiChungTu(duongDan: string): Promise<string | null> {
  const supabase = await createClient()
  const { data } = await supabase.storage.from('chung-tu').createSignedUrl(duongDan, 600)
  return data?.signedUrl ?? null
}
