Bộ biểu tượng SVG nét đơn kiểu Lucide thay toàn bộ emoji: 31 hình, render MỘT sprite `<symbol>` trong layout gốc, mỗi chỗ dùng `<svg><use href="#i-ten"/></svg>`.

Nguồn: `design/tham-chieu-tai-chinh/components-ui/bieu-tuong.tsx` (`SpriteBieuTuong`, `BieuTuong`, `TenBieuTuong`). Tệp SVG rời trong nhóm tài sản **Icons**.

- Nét 1.8 (mũi tên 1.9; `check`, `x` 2), `stroke="currentColor"` — màu ăn theo chữ quanh nó.
- Cỡ: 20 trong nút, 24 trên thanh điều hướng/tab, 26 ở trạng thái trống, 15–19 trong dòng lỗi/thông báo.
- Luôn `aria-hidden`: biểu tượng đi kèm chữ, chữ mới là nhãn.
- Tên: `home`, `file`, `wallet`, `check-sq`, `card`, `more`, `search`, `plus`, `trash`, `right`, `down`, `back`, `clip`, `cog`, `users`, `chart`, `swap`, `down-tray`, `warn`, `clock`, `check`, `x`, `folder`, `bank`, `out`, `key`, `cal`, `pencil`, `filter`, `book`, `table`.
- Cần hình mới (vd cho Nhân sự, Kho): vẽ cùng nét 1.8, `viewBox 0 0 24 24`, round cap/join — như nguồn đã làm với `book`, `table`.

Người dùng cung cấp: `ten`, `co?` (mặc định 20), `className?`.
