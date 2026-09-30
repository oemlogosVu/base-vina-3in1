import Link from 'next/link'
import { layPhien } from '@ns/lib/phien'
import { createClient } from '@ns/lib/supabase/server'
import { DUONG_DAN_QUAN_TRI, tabsChoPhep } from '@ns/lib/tabs'
import { KhungTrang, Khoi, Pill } from '@ns/components/khung-trang'
import { ROLE_LABELS } from '@ns/types/database'
import { dangXuat as signOut } from '@/app/dang-nhap/actions'

/** Hôm nay theo giờ Việt Nam. Máy chủ chạy UTC nên `new Date()` lệch 7 tiếng. */
function homNayVN(): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Ho_Chi_Minh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date())
}

function The({ nhan, so, phu }: { nhan: string; so: string; phu?: string }) {
  return (
    <div className="the" style={{ marginBottom: 0 }}>
      <p className="nhan-phu">{nhan}</p>
      <p className="so-lieu mt-1">{so}</p>
      {phu && (
        <p className="nhan-phu mt-1" style={{ fontSize: 12 }}>
          {phu}
        </p>
      )}
    </div>
  )
}

export default async function HomePage() {
  // layPhien() đã tự gọi getUser() bên trong. Trước đây trang này gọi
  // getUser() thêm một lần nữa ở đây — thừa hẳn một vòng mạng tới Supabase.
  //
  // layPhien() trả NULL cho ba trường hợp: chưa đăng nhập, chưa có dòng
  // app_users, hoặc tài khoản chưa được admin kích hoạt. Người chưa đăng nhập
  // đã bị proxy đẩy về /login trước khi tới đây, nên tới được đây mà NULL thì
  // gần như chắc chắn là chưa kích hoạt.
  const phien = await layPhien()

  if (!phien) {
    return (
      <main className="flex min-h-dvh items-center justify-center px-4">
        <div className="max-w-sm text-center">
          <h1 className="mb-2 text-xl font-semibold">Chưa truy cập được</h1>
          <p className="nhan-phu mb-6">
            Tài khoản của bạn chưa được kích hoạt. Liên hệ quản trị viên để được cấp quyền, hoặc
            đăng nhập bằng tài khoản khác.
          </p>
          <div className="flex items-center justify-center gap-4">
            <Link href="/dang-nhap" style={{ color: 'var(--mau-nhan)' }}>
              Đăng nhập
            </Link>
            <form action={signOut}>
              <button type="submit" style={{ color: 'var(--mau-nhan)' }}>
                Đăng xuất
              </button>
            </form>
          </div>
        </div>
      </main>
    )
  }

  const tabs = tabsChoPhep(phien.role, phien.tabsRieng)
  const laAdmin = phien.role === 'admin'
  const homNay = homNayVN()
  const supabase = await createClient()

  // Hỏi database xem người này có được đọc toàn bộ nhân sự không, thay vì suy
  // từ vai trò ở tầng giao diện. Nếu không được, con số "Nhân sự đang làm" sẽ
  // là 1 — chính họ — và một con số đúng-về-kỹ-thuật nhưng vô nghĩa còn tệ
  // hơn không hiện gì.
  const { data: xemDuocNhanSu } = await supabase.rpc('can_read_all_employees')

  const [dsNhanSu, chamHomNay, choXacNhan] = await Promise.all([
    xemDuocNhanSu
      ? supabase
          .from('employees')
          .select('id', { count: 'exact', head: true })
          .is('deleted_at', null)
          .in('status', ['chinh_thuc', 'thu_viec'])
      : Promise.resolve({ count: null }),
    supabase
      .from('attendance_logs')
      .select('employee_id')
      .is('deleted_at', null)
      .gte('logged_at', `${homNay}T00:00:00+07:00`)
      .lt('logged_at', `${homNay}T24:00:00+07:00`),
    supabase
      .from('attendance_logs')
      .select('id', { count: 'exact', head: true })
      .is('deleted_at', null)
      .eq('da_xac_nhan', false),
  ])

  const soNguoiChamHomNay = new Set((chamHomNay.data ?? []).map((l) => l.employee_id)).size

  // ---- Việc cần làm: chỉ những cảnh báo TRA ĐƯỢC, không bịa ----
  const viecCanLam: { muc: 'do' | 'vang'; chu: string; duongDan?: string }[] = []

  if (laAdmin) {
    const [thieuVung, thieuGioChuan, thieuChungTu, chuaNoiHoSo] = await Promise.all([
      supabase
        .from('employees')
        .select('id', { count: 'exact', head: true })
        .is('deleted_at', null)
        .is('region', null)
        .in('status', ['chinh_thuc', 'thu_viec']),
      supabase
        .from('companies')
        .select('id', { count: 'exact', head: true })
        .eq('is_active', true)
        .is('gio_vao', null),
      supabase.from('chung_tu_con_thieu').select('doi_tuong_id', { count: 'exact', head: true }),
      supabase
        .from('app_users')
        .select('id', { count: 'exact', head: true })
        .eq('is_active', true)
        .is('employee_id', null),
    ])

    // Đỏ vì nó ĐỔI TIỀN: để trống vùng thì engine coi là vùng 1, tức trần
    // BHTN cao hơn thực tế với người làm ở Thái Nguyên và Bắc Ninh.
    if ((thieuVung.count ?? 0) > 0) {
      viecCanLam.push({
        muc: 'do',
        chu: `${thieuVung.count} hồ sơ chưa điền vùng lương tối thiểu — ảnh hưởng mức đóng bảo hiểm`,
        duongDan: '/nhan-su/ho-so',
      })
    }
    if ((thieuGioChuan.count ?? 0) > 0) {
      viecCanLam.push({
        muc: 'vang',
        chu: `${thieuGioChuan.count} công ty chưa khai khung giờ chuẩn — chấm công tổ đội theo ca chưa tính ra giờ`,
        duongDan: '/nhan-su/quan-tri/cong-ty',
      })
    }
    if ((thieuChungTu.count ?? 0) > 0) {
      viecCanLam.push({
        muc: 'vang',
        chu: `${thieuChungTu.count} bảng thanh toán hoặc kỳ lương đã chốt mà chưa có chứng từ PDF`,
      })
    }
    if ((chuaNoiHoSo.count ?? 0) > 0) {
      viecCanLam.push({
        muc: 'vang',
        chu: `${chuaNoiHoSo.count} tài khoản đang bật nhưng chưa nối với hồ sơ nhân sự`,
        duongDan: '/nhan-su/quan-tri/nguoi-dung',
      })
    }
  }

  const soViecCanXuLy = (choXacNhan.count ?? 0) + viecCanLam.length

  // Truy cập nhanh: lấy đúng ba tab người này thật sự có, không vẽ thẻ dẫn
  // tới màn họ sẽ bị chặn.
  const nhanh = ['cham-cong', 'nhan-su', 'to-doi', 'luong']
    .map((k) => tabs.find((t) => t.khoa === k))
    .filter((t): t is NonNullable<typeof t> => Boolean(t))
    .slice(0, laAdmin ? 2 : 3)

  return (
    <KhungTrang phien={phien} tieuDe="Trang chủ">
      <div style={{ marginBottom: 18 }}>
        <p style={{ fontSize: 17, fontWeight: 600 }}>Xin chào, {phien.fullName}</p>
        <p className="mt-1">
          <Pill sac="xam">{ROLE_LABELS[phien.role]}</Pill>
        </p>
      </div>

      <div className="grid grid-cols-2 gap-3 lg:grid-cols-3" style={{ marginBottom: 18 }}>
        {xemDuocNhanSu && (
          <The
            nhan="Nhân sự đang làm"
            so={String(dsNhanSu.count ?? 0)}
            phu="chính thức và thử việc"
          />
        )}
        <The
          nhan="Đã chấm công hôm nay"
          so={String(soNguoiChamHomNay)}
          phu={xemDuocNhanSu ? 'người đã bấm ít nhất một lần' : 'trong phạm vi bạn xem được'}
        />
        <The
          nhan="Việc cần xử lý"
          so={String(soViecCanXuLy)}
          phu={`${choXacNhan.count ?? 0} lần chấm chờ xác nhận`}
        />
      </div>

      {laAdmin && (
        <Khoi
          tieuDe="Việc cần làm"
          ghiChu={
            viecCanLam.length === 0
              ? undefined
              : 'Tra từ dữ liệu thật, không phải nhắc chung chung. Mục đỏ là mục đổi tiền.'
          }
        >
          {viecCanLam.length === 0 ? (
            <p className="nhan-phu">Không có gì đang thiếu. Dữ liệu nền đã đủ để chạy lương.</p>
          ) : (
            <ul className="space-y-3">
              {viecCanLam.map((v) => (
                <li key={v.chu} className="flex gap-3">
                  <span className={`cham cham-${v.muc}`} aria-hidden />
                  <span>
                    {v.chu}
                    {v.duongDan && (
                      <>
                        {' · '}
                        <Link href={v.duongDan} style={{ color: 'var(--mau-nhan)' }}>
                          xử lý
                        </Link>
                      </>
                    )}
                  </span>
                </li>
              ))}
            </ul>
          )}
        </Khoi>
      )}

      <Khoi tieuDe="Truy cập nhanh">
        <div className="grid grid-cols-2 gap-3 xl:grid-cols-3">
          {nhanh.map((t) => (
            <Link
              key={t.khoa}
              href={t.duongDan}
              className="the"
              style={{ marginBottom: 0, display: 'block' }}
            >
              <p className="the-tieu-de">{t.nhan}</p>
              <p className="the-ghi-chu">{t.moTa}</p>
            </Link>
          ))}

          {laAdmin && (
            <Link
              href={DUONG_DAN_QUAN_TRI}
              className="the"
              style={{ marginBottom: 0, display: 'block' }}
            >
              <p className="the-tieu-de">Quản trị</p>
              <p className="the-ghi-chu">
                Công ty, phòng ban, chức danh, ca làm việc và tham số lương.
              </p>
            </Link>
          )}
        </div>
      </Khoi>
    </KhungTrang>
  )
}
