import { version } from '../../../../package.json'

/**
 * Phiên bản đang chạy, hiện ở góc dưới mọi màn hình.
 *
 * VÌ SAO CẦN: ngày 11/08/2026 việc deploy đứng nhiều giờ mà không ai biết —
 * app vẫn chạy, chỉ là chạy bản cũ. Không có cách nào nhìn vào màn hình mà
 * biết đang dùng bản nào. Số này để làm việc đó: so với `CHANGELOG.md` là ra.
 *
 * Đọc thẳng từ `package.json` nên KHÔNG có bản sao thứ hai để lệch. Phát hành
 * bản mới chỉ cần `npm version <muc>` là số ở đây tự theo.
 */
export const PHIEN_BAN = version

/**
 * Mã commit, do Vercel tiêm vào lúc build.
 *
 * Số phiên bản chỉ đổi khi phát hành; mã commit đổi mỗi lần đẩy. Có cả hai
 * thì phân biệt được "bản 0.4.3 nào" khi đang sửa vặt giữa hai lần phát hành.
 *
 * Chạy máy cục bộ thì biến này không có — hiện "cục bộ" thay vì để trống,
 * để người xem biết đây không phải bản trên máy chủ.
 */
export const MA_COMMIT = (
  // Thử cả hai tên: Vercel đặt VERCEL_GIT_COMMIT_SHA cho phía máy chủ, và
  // với dự án Next thì thường có thêm bản NEXT_PUBLIC_. Chân trang render ở
  // máy chủ nên bản không tiền tố là đủ, nhưng giữ cả hai để nếu sau này ai
  // đưa nhãn này vào component phía trình duyệt thì vẫn chạy.
  process.env.NEXT_PUBLIC_VERCEL_GIT_COMMIT_SHA ??
  process.env.VERCEL_GIT_COMMIT_SHA ??
  ''
).slice(0, 7)

export function nhanPhienBan(): string {
  return MA_COMMIT ? `v${PHIEN_BAN} · ${MA_COMMIT}` : `v${PHIEN_BAN} · cục bộ`
}
