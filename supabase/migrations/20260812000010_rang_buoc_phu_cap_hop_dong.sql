-- =========================================================
-- Ràng buộc cho phụ cấp riêng trong hợp đồng
--
-- HAI LỖI dò ra 12/08/2026 (scripts/do-loi-toan-dien.mjs):
--
--   A4. Phụ cấp ÂM được nhận. Đặt -5.000.000 thì gross tụt từ 10 triệu
--       xuống 5 triệu. Nó thành khoản khấu trừ không ai duyệt và không hiện
--       ra như một khoản khấu trừ trên phiếu lương.
--
--   A5. `amount` không phải số thì engine đổ lỗi thô của Postgres
--       (22P02 invalid input syntax for type numeric) và KHÔNG nói nhân
--       viên nào sai. Người nhập không có đường lần ra chỗ hỏng.
--
-- Chặn ở đây chứ không chỉ ở biểu mẫu: biểu mẫu là tiện lợi, ràng buộc mới
-- là lớp chặn thật. Dữ liệu còn vào được bằng script và bằng SQL tay.
-- =========================================================

create or replace function public.phu_cap_hop_dong_hop_le(p jsonb)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select
    -- NULL và mảng rỗng đều hợp lệ; phải là MẢNG, không phải object.
    p is null
    or (
      jsonb_typeof(p) = 'array'
      and not exists (
        select 1
        from jsonb_array_elements(p) as x
        where
          -- Mỗi phần tử phải là object có tên và mức tiền.
          jsonb_typeof(x) <> 'object'
          or coalesce(btrim(x->>'name'), '') = ''
          -- `amount` phải là SỐ trong JSON. Kiểm bằng jsonb_typeof chứ không
          -- ép kiểu: ép kiểu chuỗi bậy sẽ ném lỗi ngay trong ràng buộc và
          -- người nhập nhận đúng cái lỗi thô mà ràng buộc này sinh ra để
          -- tránh.
          or jsonb_typeof(x->'amount') <> 'number'
          or (x->>'amount')::numeric < 0
      )
    );
$$;

comment on function public.phu_cap_hop_dong_hop_le(jsonb) is
  'Phụ cấp riêng trong hợp đồng: phải là mảng object có name và amount là số không âm.';

-- Dữ liệu đang có đều là mảng rỗng (đã kiểm: 7 hợp đồng, 0 dòng có phụ cấp)
-- nên thêm ràng buộc không làm hỏng dòng nào.
alter table public.labor_contracts
  add constraint phu_cap_hop_dong_hop_le
  check (public.phu_cap_hop_dong_hop_le(allowances));

-- Cùng lý do, cho phụ cấp theo chức danh: bảng này đã có check (amount >= 0)
-- từ migration 20260812000004, không cần thêm.
