import Link from 'next/link'
import { KhungTrang, Khoi } from '@ns/components/khung-trang'
import { batBuocTab } from '@ns/lib/phien'
import { createClient } from '@ns/lib/supabase/server'
import { ngay as dinhDangNgay, ngayGio, tien } from '@ns/lib/dinh-dang'
import { layNgayTheoCongTy, layNgayTheoTo } from '@ns/lib/sua-chua-cong'
import { FormMoLaiPhien, FormTruyLinh } from './bieu-mau'
import { BangChamBuCongTy } from './bang-cong-ty'
import type { CaChuan } from '@ns/lib/cong-ngay'

/** Hôm nay theo giờ Việt Nam. Máy chủ chạy UTC nên `new Date()` lệch 7 tiếng. */
function homNayVN(): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Ho_Chi_Minh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date())
}

const NHAN_LOAI: Record<string, string> = {
  cham_bu: 'Chấm bù',
  xoa_lan_cham: 'Xoá lần chấm',
  mo_lai_phien: 'Mở lại phiên tổ',
  truy_linh: 'Truy lĩnh',
}

const soGio = (phut: number) => (phut / 60).toFixed(1).replace('.', ',')

export default async function TrangSuaChuaCong({
  searchParams,
}: {
  searchParams: Promise<{ pv?: string; ngay?: string }>
}) {
  const phien = await batBuocTab('sua-chua-cong')
  const { pv: pvThamSo, ngay: ngayThamSo } = await searchParams

  // Tham số URL là dữ liệu người dùng gửi lên và nó đi thẳng vào mốc lọc truy
  // vấn — chỉ nhận đúng dạng, không nhận gì khác.
  const ngaySoi = /^\d{4}-\d{2}-\d{2}$/.test(ngayThamSo ?? '') ? ngayThamSo! : homNayVN()

  // Phạm vi mã hoá thành "to:<uuid>" hoặc "cty:<uuid>". Một tham số thay vì
  // hai: không thể rơi vào trạng thái chọn cả tổ lẫn công ty rồi phải đoán
  // xem cái nào thắng.
  const khop = /^(to|cty):([0-9a-f-]{36})$/i.exec(pvThamSo ?? '')
  const kieu = khop?.[1] as 'to' | 'cty' | undefined
  const pvId = khop?.[2]

  const supabase = await createClient()

  const [{ data: dsTo }, { data: dsCongTy }] = await Promise.all([
    supabase.from('to_doi').select('id, code, name').eq('is_active', true).order('code'),
    supabase.from('companies').select('id, name').eq('is_active', true).order('code'),
  ])

  const { data: soGhiVet } = await supabase
    .from('sua_chua_cong')
    .select('id, loai, work_date, ly_do, sua_luc, employee_id')
    .order('sua_luc', { ascending: false })
    .limit(15)

  // `employee_id` NULL với dòng nhắm vào cả phiên tổ đội, nên phải lọc trước
  // khi tra tên — `filter(Boolean)` một mình không thu hẹp kiểu.
  const idTrongSo = [
    ...new Set(
      (soGhiVet ?? [])
        .map((g) => g.employee_id)
        .filter((id): id is string => id !== null),
    ),
  ]
  const { data: tenSo } = idTrongSo.length
    ? await supabase.from('employees').select('id, full_name').in('id', idTrongSo)
    : { data: [] }
  const tenTheoId = new Map((tenSo ?? []).map((e) => [e.id, e.full_name]))

  // ---- Số liệu của phạm vi đang xem ----
  const dongCongTy = kieu === 'cty' && pvId ? await layNgayTheoCongTy(pvId, ngaySoi) : []
  const toDoi = kieu === 'to' && pvId ? await layNgayTheoTo(pvId, ngaySoi) : null

  // Kỳ lương của ngày đang xem. Hỏi qua một người bất kỳ trong danh sách: kỳ
  // gắn với CÔNG TY, nên ai trong cùng công ty cũng cho ra một câu trả lời.
  const nguoiDaiDien = dongCongTy[0]?.employeeId ?? toDoi?.dong[0]?.employeeId ?? null
  const { data: kyTho } = nguoiDaiDien
    ? await supabase.rpc('ky_luong_cua_ngay', {
        p_employee_id: nguoiDaiDien,
        p_ngay: ngaySoi,
      })
    : { data: null }
  const ky = Array.isArray(kyTho) ? kyTho[0] : kyTho
  const kyDaChot = Boolean(ky?.id) && ky.status !== 'mo'

  // Ca chuẩn để quy giờ ra công. Lấy đúng ca mà `tong_hop_cong_ngay()` dùng —
  // ca đang bật, sắp theo mã, lấy cái đầu — nếu không thì bản xem trước trên
  // màn hình tính theo một ca khác với ca database dùng để ghi.
  const { data: caTho } = await supabase
    .from('work_shifts')
    .select('start_time, end_time, break_start, break_end')
    .eq('is_active', true)
    .order('code')
    .limit(1)
    .maybeSingle()

  const ca: CaChuan = {
    tu: (caTho?.start_time ?? '08:00:00').slice(0, 5),
    den: (caTho?.end_time ?? '17:00:00').slice(0, 5),
    nghiTu: caTho?.break_start ? caTho.break_start.slice(0, 5) : null,
    nghiDen: caTho?.break_end ? caTho.break_end.slice(0, 5) : null,
  }

  // Chủ nhật là ngày nghỉ tuần: database trả 0 giờ thường. Dựng ngày ở UTC từ
  // ba con số, không dùng `new Date(chuoi)` — chuỗi "2026-08-09" được hiểu là
  // UTC còn máy chủ thì không, và lệch một ngày là cảnh báo sai ngày.
  const [nam = 1970, thang = 1, ngayTrongThang = 1] = ngaySoi.split('-').map(Number)
  const laChuNhat = new Date(Date.UTC(nam, thang - 1, ngayTrongThang)).getUTCDay() === 0

  return (
    <KhungTrang phien={phien} tieuDe="Sửa chữa công">
      <Khoi
        tieuDe="Chọn tổ đội hoặc công ty, và ngày"
        ghiChu="Mọi thao tác ở màn này đều đòi lý do và đều đi vào sổ ghi vết — không có đường sửa công nào im lặng."
      >
        <form method="get" className="flex flex-wrap items-end gap-3">
          <label className="text-sm">
            <span className="mb-1 block font-medium">Phạm vi</span>
            <select
              name="pv"
              defaultValue={pvThamSo ?? ''}
              className="rounded-lg border border-slate-300 px-3 py-2 text-base dark:border-slate-700 dark:bg-slate-950"
            >
              <option value="">— chọn —</option>
              <optgroup label="Tổ đội công nhật">
                {(dsTo ?? []).map((t) => (
                  <option key={t.id} value={`to:${t.id}`}>
                    {t.name} ({t.code})
                  </option>
                ))}
              </optgroup>
              <optgroup label="Công ty — nhân viên chính thức">
                {(dsCongTy ?? []).map((c) => (
                  <option key={c.id} value={`cty:${c.id}`}>
                    {c.name}
                  </option>
                ))}
              </optgroup>
            </select>
          </label>
          <label className="text-sm">
            <span className="mb-1 block font-medium">Ngày</span>
            <input
              type="date"
              name="ngay"
              defaultValue={ngaySoi}
              className="rounded-lg border border-slate-300 px-3 py-2 text-base dark:border-slate-700 dark:bg-slate-950"
            />
          </label>
          <button
            type="submit"
            className="rounded-lg bg-slate-900 px-4 py-2 text-sm font-medium text-white dark:bg-slate-100 dark:text-slate-900"
          >
            Xem
          </button>
        </form>
      </Khoi>

      {/* ================= CÔNG TY — nhân viên chính thức ================= */}
      {kieu === 'cty' && (
        <Khoi
          tieuDe={`${dsCongTy?.find((c) => c.id === pvId)?.name ?? 'Công ty'} · ${dinhDangNgay(ngaySoi)}`}
          ghiChu={
            ky?.id
              ? `Kỳ lương ${String(ky.month).padStart(2, '0')}/${ky.year} — ${kyDaChot ? 'ĐÃ CHỐT' : 'đang mở'}`
              : 'Tháng này chưa có kỳ lương nào.'
          }
        >
          {dongCongTy.length === 0 ? (
            <p className="nhan-phu">Công ty này chưa có nhân viên chính thức nào.</p>
          ) : kyDaChot ? (
            <>
              <div className="mb-4 rounded-lg bg-amber-50 p-4 text-sm text-amber-900 dark:bg-amber-950 dark:text-amber-200">
                Kỳ lương {String(ky.month).padStart(2, '0')}/{ky.year} <strong>đã chốt</strong> —
                không sửa công của ngày này được. Phiếu lương kỳ đó đã phát và có thể đã được ký.
                Bù tiền bằng khoản <strong>truy lĩnh</strong> ở từng dòng bên dưới.
              </div>
              <table className="bang">
                <thead>
                  <tr>
                    <th>Họ tên</th>
                    <th>Giờ làm</th>
                    <th>Bù tiền</th>
                  </tr>
                </thead>
                <tbody>
                  {dongCongTy.map((d) => (
                    <tr key={d.employeeId}>
                      <td>
                        {d.ten} <span className="nhan-phu">{d.ma}</span>
                      </td>
                      <td data-nhan="Giờ làm">
                        {d.phutLam > 0 ? `${soGio(d.phutLam)} giờ` : '—'}
                      </td>
                      <td data-nhan="Bù tiền">
                        {d.phutLam > 0 ? (
                          <span className="nhan-phu">đã có công</span>
                        ) : (
                          <FormTruyLinh
                            employeeId={d.employeeId}
                            ngayGoc={ngaySoi}
                            soTienGoiY={null}
                            canCu=""
                          />
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </>
          ) : (
            <BangChamBuCongTy
              ngay={ngaySoi}
              ca={ca}
              laChuNhat={laChuNhat}
              dong={dongCongTy}
            />
          )}

          <p className="mt-4 text-sm text-slate-500">
            Muốn <strong>sửa giờ</strong> thì xoá lần chấm sai rồi chấm bù lại giờ đúng. Cố ý không
            cho sửa tại chỗ: bản gốc phải còn lại làm bằng chứng, và nó vẫn nằm ở Thùng rác.
          </p>
        </Khoi>
      )}

      {/* ================= TỔ ĐỘI ================= */}
      {kieu === 'to' && toDoi && (
        <Khoi
          tieuDe={`${dsTo?.find((t) => t.id === pvId)?.name ?? 'Tổ'} · ${dinhDangNgay(ngaySoi)}`}
          ghiChu={
            toDoi.phien === null
              ? 'Ngày này chưa có phiên chấm công nào.'
              : toDoi.phien.daDuyet
                ? 'Phiên ĐÃ DUYỆT — khoá sửa. Mở lại phiên thì người chấm sửa được.'
                : 'Phiên chưa duyệt — đang sửa được ở màn Quản lý tổ đội.'
          }
        >
          {toDoi.dong.length === 0 ? (
            <p className="nhan-phu">Tổ này chưa có nhân công nào trong ngày đang xem.</p>
          ) : (
            <table className="bang">
              <thead>
                <tr>
                  <th>Họ tên</th>
                  <th className="phai">Số công / giờ</th>
                  <th className="phai">Ngoài giờ</th>
                  <th className="phai">Thưởng</th>
                </tr>
              </thead>
              <tbody>
                {toDoi.dong.map((d) => (
                  <tr key={d.employeeId}>
                    <td>
                      {d.ten} <span className="nhan-phu">{d.ma}</span>
                    </td>
                    <td data-nhan="Số công / giờ" className="phai">
                      {d.soCong !== null
                        ? `${d.soCong} công`
                        : d.soGio !== null
                          ? `${d.soGio} giờ`
                          : '—'}
                    </td>
                    <td data-nhan="Ngoài giờ" className="phai">
                      {d.soGioOt > 0 ? `${d.soGioOt} giờ` : '—'}
                    </td>
                    <td data-nhan="Thưởng" className="phai">
                      {d.thuong > 0 ? (
                        <>
                          {tien(d.thuong)}
                          {d.thuongLyDo && (
                            <span className="nhan-phu block">{d.thuongLyDo}</span>
                          )}
                        </>
                      ) : (
                        '—'
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}

          {/*
            Sửa số công của tổ KHÔNG làm ở đây, và đó là chủ ý.

            Lưới chấm công ở Quản lý tổ đội đã làm đúng việc ấy — ba ca theo
            giờ, ngoài giờ, thưởng, ảnh xác minh. Dựng lưới thứ hai ở màn này
            là hai chỗ cùng ghi một bảng, rồi một hôm chỉ một chỗ được sửa.

            Việc riêng của màn này là MỞ KHOÁ: phiên đã duyệt thì không ai sửa
            được, kể cả người chấm.
          */}
          {toDoi.phien?.daDuyet ? (
            <div className="mt-4 rounded-lg border border-slate-200 p-4 dark:border-slate-800">
              <p className="text-sm font-medium">Mở lại phiên để sửa</p>
              <p className="mt-1 text-sm text-slate-500">
                Mở xong thì vào <strong>Quản lý tổ đội → Chấm công</strong> sửa số công, thưởng,
                rồi <strong>duyệt lại</strong>. Nếu ngày này đã nằm trong một bảng thanh toán thì
                phải xoá bảng đó trước — nếu không sẽ có hai con số cho cùng một ngày công.
              </p>
              <FormMoLaiPhien phienId={toDoi.phien.id} />
            </div>
          ) : (
            <p className="mt-4 text-sm">
              Phiên đang sửa được. Vào{' '}
              <Link href="/nhan-su/to-doi/quan-ly" style={{ color: 'var(--mau-nhan)' }}>
                Quản lý tổ đội → Chấm công
              </Link>{' '}
              để chấm hoặc sửa — kể cả cho ngày đã qua.
            </p>
          )}
        </Khoi>
      )}

      <Khoi
        tieuDe={`Sổ ghi vết (${soGhiVet?.length ?? 0} lần gần nhất)`}
        ghiChu="Bất biến: không ai sửa hay xoá được một dòng ở đây, kể cả quản trị."
      >
        {(soGhiVet ?? []).length === 0 ? (
          <p className="nhan-phu">Chưa có lần can thiệp nào.</p>
        ) : (
          <ul className="divide-y divide-slate-100 dark:divide-slate-800">
            {(soGhiVet ?? []).map((g) => (
              <li key={g.id} className="py-3">
                <p className="text-sm">
                  <strong>{NHAN_LOAI[g.loai] ?? g.loai}</strong>
                  {' · '}
                  {g.employee_id ? (tenTheoId.get(g.employee_id) ?? 'người đã xoá hồ sơ') : 'cả tổ'}
                  {' · ngày '}
                  {dinhDangNgay(g.work_date)}
                </p>
                <p className="text-sm text-slate-600 dark:text-slate-400">{g.ly_do}</p>
                <p className="text-xs text-slate-500">{ngayGio(g.sua_luc)}</p>
              </li>
            ))}
          </ul>
        )}
      </Khoi>
    </KhungTrang>
  )
}
