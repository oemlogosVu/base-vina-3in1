Thanh tiến độ ngân sách: đã dùng / tổng, cao 10px, bo `bo-tron`; vượt thì đỏ + pill «Vượt ngân sách».

Nguồn: `ThanhTienDo` trong `design/tham-chieu-tai-chinh/components-ui/hien-thi.tsx` + `.thanh-tien-do`.

- Rãnh `xam-nen`, phần đã dùng `xanh`; vượt: `.thanh-tien-do-vuot` (phần dùng `do`), số tô `tien-ra`, thêm pill đỏ — không chỉ dựa vào màu.
- Độ rộng là chỗ DUY NHẤT được dùng style nội tuyến. `role="progressbar"` + `aria-valuenow`.

Người dùng cung cấp: `nhan`, `daDung`, `tong` (số).
