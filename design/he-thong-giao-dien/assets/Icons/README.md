Bộ 31 biểu tượng nét đơn kiểu Lucide, chép từ `components-ui/bieu-tuong.tsx` (khối `HINH`) của app Tài chính.

- Tệp SVG rời ở đây có nét **#1b2430** (`muc`), vì `<img>` không kế thừa màu chữ. Trong app, dùng sprite `<symbol>` với `stroke="currentColor"` (thẻ `BieuTuong`) để màu ăn theo chữ.
- Nét 1.8; mũi tên (`right`, `down`, `back`, `plus`) 1.9; `check`, `x` 2. `viewBox 0 0 24 24`, đầu nét và góc nối bo tròn.
- Cỡ 20 trong nút, 24 trên thanh điều hướng, 26 ở trạng thái trống.
