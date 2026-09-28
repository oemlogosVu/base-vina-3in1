Bộ chọn phân hệ ở đầu thanh bên: ô chữ tắt màu nhấn + tên phân hệ đang mở, bấm mở danh sách TẠI CHỖ bằng `<details>` gốc (không popup, không dropdown tự vẽ).

Chưa có trong code. Dựng từ khung Tài chính (`.thanh-ben`, `.muc-ben`, `.huy-hieu`, `.logo-tc`) + class mới trong `bundle.css` phần 3: `.chon-phan-he`, `.muc-phan-he`, `.o-phan-he`, `.o-phan-he-tren-toi`, `[data-phan-he]`.

- Gắn `data-phan-he="tc|ns|kho|ht"` lên khung của layout phân hệ; class mới đọc `--nhan` / `--nhan-nen` từ đó (`nhan-tc`… `nhan-ht-nen`).
- Thứ tự cố định: Tài chính · Nhân sự · Kho · Hệ thống. Chỉ hiện phân hệ người dùng được phép (hàm `layPhanHeDuocPhep`); Hệ thống chỉ cho quản trị. Chỉ có 1 phân hệ → ẩn bộ chọn.
- Mỗi dòng: ô chữ tắt (TC / NS / KHO / HT, chữ trắng trên `nhan-*`) · tên · huy hiệu số việc chờ (`vang-chu`, gấp `do`). Dòng đang mở: nền `nhan-*-nen`, chữ 700.
- Trên thanh bên, «Việc chờ tôi» (trang chủ tổng, `/`) đứng TRÊN bộ chọn — không thuộc phân hệ nào, màu navy.
- Mục thanh bên đang chọn trong một phân hệ: nền `nhan-*` chữ trắng (Tài chính vẫn navy). Thanh trên giữ navy cho mọi phân hệ + dải 4px `nhan-*` bên dưới (`.dai-nhan`).
- Điện thoại: đầu trang thay `.logo-tc` bằng ô chữ tắt trắng chữ màu nhấn (`.o-phan-he-tren-toi`) + viền đáy 4px màu nhấn; bấm ô đó (hoặc mục «Phân hệ» ở trang Thêm) mở trang riêng «Chọn phân hệ» như bản bên phải.
- Tên hiển thị app và logo CHƯA CHỐT: tạm chữ «Base Vina».
- Khi code thật: thay `var(--nhan…)` bằng hex trong `tokens.json` (quy tắc màu hex cố định cho Android cũ).

Người dùng cung cấp: phân hệ đang mở, danh sách phân hệ được phép, số việc chờ mỗi phân hệ.
