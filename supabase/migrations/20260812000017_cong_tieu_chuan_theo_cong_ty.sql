-- =========================================================
-- Công tiêu chuẩn CỐ ĐỊNH theo từng công ty
--
-- Nguyên tắc trả lương của doanh nghiệp: lương ngày = lương tháng chia cho
-- một số công tiêu chuẩn CỐ ĐỊNH của pháp nhân (26, 24, 22… tuỳ công ty),
-- rồi nhân với số ngày công thực tế đi làm. Con số ấy là chính sách, không
-- phải số ngày làm việc có thật của riêng tháng đó.
--
-- Trước bản này `payroll_periods.standard_days` được GÕ TAY cho từng kỳ, ô
-- nhập mặc định 22. Hai đường sai mở sẵn:
--
--   1. Gõ nhầm một kỳ thì cả kỳ đó trả sai, và không có gì để đối chiếu —
--      không đâu trong hệ thống ghi con số ĐÚNG là bao nhiêu.
--   2. Hai công ty dùng hai mức chuẩn khác nhau, nhưng ô nhập chung một số
--      mặc định 22 cho cả hai.
--
-- Nay công ty khai một lần, kỳ lương thừa hưởng. Kế toán vẫn sửa được cho
-- một kỳ đặc biệt (kỳ đầu tiên lệch ngày, tháng có lịch nghỉ riêng), và kỳ
-- đã lưu GIỮ số của chính nó — đổi chính sách sang năm không làm dựng lại
-- sai những phiếu lương đã phát hành.
--
-- KHÔNG đụng tới quy tắc trần 100%: đi nhiều hơn công chuẩn vẫn chỉ hưởng
-- đủ lương tháng, phần dôi ra phải bấm nút làm thêm giờ mới được trả. Đây
-- là quyết định của Triệu Vũ ngày 12/08/2026.
-- =========================================================

alter table public.companies
  add column standard_days numeric(5, 2)
    check (standard_days > 0 and standard_days <= 31);

comment on column public.companies.standard_days is
  'Công tiêu chuẩn cố định của pháp nhân — mẫu số để quy lương tháng thành lương ngày. NULL nghĩa là chưa khai, và kỳ lương của công ty đó sẽ không tạo được.';

-- Migration KHÔNG điền con số nào: 26 hay 24 là chính sách trả lương của
-- doanh nghiệp, không phải thứ suy ra được. Cùng lý do với việc không seed
-- tên công ty và biểu thuế. Admin nhập tại /quan-tri/cong-ty.

-- ---------------------------------------------------------
-- Kỳ lương thừa hưởng công chuẩn của công ty
--
-- Đặt ở tầng database chứ không ở màn hình: kỳ lương còn vào được bằng
-- script và bằng PostgREST gọi thẳng. Một mặc định chỉ sống trong biểu mẫu
-- React là mặc định mà mọi đường khác đi vòng qua được.
--
-- Trigger BEFORE INSERT chạy TRƯỚC khi Postgres kiểm ràng buộc NOT NULL,
-- nên cột vẫn giữ nguyên NOT NULL mà người gọi được phép bỏ trống.
-- ---------------------------------------------------------

create or replace function public.dat_cong_chuan_cho_ky()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  chuan   numeric;
  ten_cty text;
begin
  -- Kế toán gõ số riêng cho kỳ này thì tôn trọng, không đè.
  if new.standard_days is not null then
    return new;
  end if;

  select c.standard_days, c.name into chuan, ten_cty
  from public.companies c
  where c.id = new.company_id;

  if ten_cty is null then
    raise exception 'Không tìm thấy công ty của kỳ lương này.';
  end if;

  if chuan is null then
    raise exception
      'Công ty % chưa khai công tiêu chuẩn. Vào Quản trị → Công ty nhập số ngày công tiêu chuẩn trước khi tạo kỳ lương — không có mẫu số thì không quy được lương tháng thành lương ngày.',
      ten_cty;
  end if;

  new.standard_days := chuan;
  return new;
end;
$$;

comment on function public.dat_cong_chuan_cho_ky() is
  'Điền công tiêu chuẩn của công ty vào kỳ lương khi người tạo bỏ trống. Từ chối tạo kỳ nếu công ty chưa khai.';

create trigger trg_ky_luong_cong_chuan
  before insert on public.payroll_periods
  for each row execute function public.dat_cong_chuan_cho_ky();
