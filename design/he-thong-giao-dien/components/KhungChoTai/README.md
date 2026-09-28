Khung chờ tải: các thanh `xam-nen` TĨNH (`.xuong`, bo `bo-4`) mô phỏng thẻ — không nhấp nháy vì máy cũ giật.

Nguồn: `KhungChoTai` trong `design/tham-chieu-tai-chinh/components-ui/hien-thi.tsx` + `.xuong`.

- Kèm `<span class="sr-only" role="status">Đang tải…</span>` cho trình đọc màn hình.
- Dùng trong `loading.tsx` của route; số thẻ ≈ số thẻ thật sắp hiện.

Người dùng cung cấp: `soThe?` (mặc định 4).
