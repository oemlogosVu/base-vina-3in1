Chấm công nhật cho tổ đội. Chỉ huy hoặc tổ trưởng chấm thay cho công nhân, vì phần lớn công nhân không có tài khoản (89 hồ sơ, 4 tài khoản). Điện thoại chấm theo ngày, máy tính xem và xác nhận theo lưới người × ngày.

Thiết kế mới. Nghiệp vụ: «chấm công tổ đội công nhật», bucket `to-doi-cham-cong` (kế hoạch gộp, mục 1). Class mới: `.chon-cong`, `.luoi-cong`, `.o-cong`, `.cong-nua`, `.cong-vang`, `.cong-chua` (bundle.css phần 4).

- Điện thoại: một ngày một màn. Chọn ngày bằng `<input type="date">` gốc cùng hai nút trước/sau (không cho sang ngày tương lai). Mỗi người một dòng, bên phải là ô chọn công 1 · ½ · 0 bằng **radio gốc** (`.chon-cong`, mỗi ô ≥ 46×44px), mục đang chọn nền `nhan-ns`.
- Mặc định mọi người = 1 để chỉ huy chỉ sửa người vắng hoặc nửa công, bấm ít nhất trên điện thoại cũ.
- Ảnh tổ đội tại công trường dùng `<input type="file" capture="environment">` gốc.
- Thanh tổng dính đáy (`.thanh-day`): số người, số vắng, tổng công (to nhất), và nút chính «Gửi chỉ huy xác nhận».
- Máy tính: `Bang` gọn (`.bang-gon` + `<colgroup>`), cột ngày 44px, Chủ nhật tô `xam-nen`, ½ màu `vang-chu`, 0 màu `do`, «—» màu `muc-mo`. Tổng công căn phải, có dòng cộng. Không bao giờ để bảng phải trượt ngang để thấy cột tổng.
- Bảng công đã xác nhận thì khóa. Muốn sửa phải có lý do và ghi nhật ký, đúng nguyên tắc «sổ chỉ ghi thêm».
- Bảng công đã chốt là đầu vào cho bảng thanh toán tổ đội, từ đó tạo đề nghị chi bên Tài chính.

Người dùng cung cấp: tổ đội, ngày hoặc kỳ, danh sách người và công từng ngày, trạng thái xác nhận.
