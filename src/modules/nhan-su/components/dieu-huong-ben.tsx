'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { useEffect, useState } from 'react'
import {
  DUONG_DAN_QUAN_TRI,
  MAN_QUAN_TRI,
  NHAN_NHOM,
  NHOM_MENU,
  NHOM_QUAN_TRI,
  type Tab,
} from '@ns/lib/tabs'

/**
 * Thanh điều hướng bên trái.
 *
 * ⚠️ ĐÂY KHÔNG PHẢI LỚP BẢO MẬT, y như thanh tab ngang nó thay thế. Danh sách
 * `tabs` đã được `tabsChoPhep()` lọc ở phía máy chủ; component này chỉ vẽ.
 * Người gõ thẳng URL vẫn bị `batBuocTab()` chặn ở trang, và RLS chặn ở
 * database.
 *
 * Là client component vì ba việc chỉ làm được ở trình duyệt: biết đường dẫn
 * hiện tại để tô mục đang mở, đóng/mở drawer, và đóng drawer lại sau khi
 * người dùng bấm một mục (nếu không, họ bấm xong vẫn thấy tấm che tối).
 */
export function DieuHuongBen({
  tabs,
  laAdmin,
  mo,
  dong,
}: {
  tabs: Tab[]
  laAdmin: boolean
  mo: boolean
  dong: () => void
}) {
  const duongDan = usePathname()

  // Đóng drawer mỗi khi sang trang khác. Không có bước này thì trên điện
  // thoại, bấm một mục xong màn hình mới hiện ra sau lớp phủ tối.
  useEffect(() => {
    dong()
    // Chỉ chạy khi ĐƯỜNG DẪN đổi. Đưa `dong` vào danh sách phụ thuộc sẽ chạy
    // lại mỗi lần component vẽ lại, và drawer đóng ngay khi vừa mở.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [duongDan])

  /**
   * Mục đang mở.
   *
   * So bằng tiền tố chứ không bằng dấu bằng: `/nhan-su/ho-so/abc/sua` vẫn thuộc về
   * mục *Nhân sự*. Nhưng phải chặn `/nhan-su/luong` nuốt `/nhan-su/luong/ky-luong` — nên
   * đường dẫn dài hơn được ưu tiên, và chỉ đúng MỘT mục được tô.
   */
  const mucDangMo = [...tabs]
    .sort((a, b) => b.duongDan.length - a.duongDan.length)
    .find((t) => duongDan === t.duongDan || duongDan.startsWith(`${t.duongDan}/`))?.khoa

  const trongQuanTri = duongDan.startsWith(DUONG_DAN_QUAN_TRI)

  return (
    <>
      {mo && <div className="lop-phu" onClick={dong} aria-hidden />}

      <nav className={`sidebar khong-in${mo ? ' mo' : ''}`} aria-label="Điều hướng chính">
        <Link href="/" className="sidebar-ten">
          HR Base Vina
        </Link>

        {NHOM_MENU.map((nhom) => {
          const cua = tabs.filter((t) => t.nhom === nhom)
          if (cua.length === 0) return null
          return (
            <div key={nhom}>
              <p className="nhom-tieu-de">{NHAN_NHOM[nhom]}</p>
              {cua.map((t) => (
                <Link
                  key={t.khoa}
                  href={t.duongDan}
                  className="muc-menu"
                  aria-current={mucDangMo === t.khoa ? 'page' : undefined}
                >
                  {t.nhan}
                </Link>
              ))}
            </div>
          )
        })}

        {/*
          Nhóm Quản trị CỐ Ý không nằm trong danh mục tab và không cấu hình
          được theo chức danh: tắt nhầm đường vào màn quản trị là tắt luôn
          đường sửa cấu hình đã tắt nó.

          Mặc định mở khi đang ở trong khu quản trị, đóng khi ở ngoài — vào
          màn khác mà thấy tám mục quản trị bung ra là thừa.
        */}
        {laAdmin && (
          <details className="nhom-gop" open={trongQuanTri}>
            <summary className="nhom-tieu-de">
              <span>Quản trị</span>
              <svg
                className="chevron"
                width="12"
                height="12"
                viewBox="0 0 12 12"
                fill="none"
                aria-hidden
              >
                <path
                  d="M4 2.5 7.5 6 4 9.5"
                  stroke="currentColor"
                  strokeWidth="1.6"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </svg>
            </summary>

            {NHOM_QUAN_TRI.map((nhom) => (
              <div key={nhom.nhan}>
                <p className="nhom-tieu-de" style={{ paddingLeft: 18 }}>
                  {nhom.nhan}
                </p>
                {nhom.muc.map((ten) => {
                  const man = MAN_QUAN_TRI.find((m) => m.nhan === ten)
                  if (!man) return null
                  return (
                    <Link
                      key={man.duongDan}
                      href={man.duongDan}
                      className="muc-menu"
                      style={{ paddingLeft: 18 }}
                      aria-current={duongDan === man.duongDan ? 'page' : undefined}
                    >
                      {man.nhan}
                    </Link>
                  )
                })}
              </div>
            ))}
          </details>
        )}
      </nav>
    </>
  )
}

/**
 * Nút hamburger + trạng thái mở/đóng của drawer.
 *
 * Trạng thái sống ở đây chứ không ở `KhungTrang`, để `KhungTrang` giữ nguyên
 * là server component — nó nhận `phien` và gọi hàm phía máy chủ, biến cả
 * khung thành client component là kéo theo mọi trang.
 */
export function KhoiDieuHuong({ tabs, laAdmin }: { tabs: Tab[]; laAdmin: boolean }) {
  const [mo, datMo] = useState(false)

  return (
    <>
      <button
        type="button"
        className="nut-hamburger khong-in"
        aria-label={mo ? 'Đóng menu' : 'Mở menu'}
        aria-expanded={mo}
        onClick={() => datMo((truoc) => !truoc)}
      >
        <svg width="18" height="18" viewBox="0 0 18 18" fill="none" aria-hidden>
          <path
            d="M2 4.5h14M2 9h14M2 13.5h14"
            stroke="currentColor"
            strokeWidth="1.7"
            strokeLinecap="round"
          />
        </svg>
      </button>

      <DieuHuongBen tabs={tabs} laAdmin={laAdmin} mo={mo} dong={() => datMo(false)} />
    </>
  )
}
