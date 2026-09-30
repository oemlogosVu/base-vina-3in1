-- =========================================================
-- P3b — Mức lương có thời gian hiệu lực
--
-- Yêu cầu Triệu Vũ 19/08/2026: tăng hay giảm lương đều có NGÀY ÁP DỤNG;
-- những ngày trước đó vẫn tính theo mức cũ. Hợp đồng KHÔNG bị đóng lại —
-- nó là văn bản pháp lý, còn mức lương là thứ đổi trong lòng nó.
--
-- LỖ HỔNG ĐANG SỬA (dò ra 19/08/2026):
--   Sửa lương chạy `update` ngay trên dòng hợp đồng đang hiệu lực, nên mức cũ
--   bị GHI ĐÈ và mất hẳn. Phiếu lương đã phát hành thì không sai — chúng lưu
--   kết quả đã tính. Nhưng ba tháng sau, khi có người hỏi "sao phiếu tháng 8
--   chỉ 20 triệu mà hợp đồng ghi 30 triệu", hệ thống KHÔNG trả lời được: phiếu
--   đúng, hợp đồng đúng, và không gì nối hai con số đó lại. Với bảng lương thì
--   mất khả năng giải thích cũng nghiêm trọng gần bằng tính sai.
--
-- VÌ SAO GỠ HẲN HAI CỘT LƯƠNG KHỎI `labor_contracts` thay vì để lại cho tiện:
--   để lại là có HAI nguồn sự thật về cùng một con số lương, và sớm muộn chúng
--   lệch nhau. Đó đúng là loại lỗi migration này đi sửa; tự tạo lại nó ở dạng
--   khác thì vô nghĩa.
--
-- Migration KHÔNG mất dữ liệu: mức lương hiện tại của từng hợp đồng được
-- chuyển thành MỨC ĐẦU TIÊN, hiệu lực từ ngày bắt đầu hợp đồng.
--
-- Engine lương nằm ở migration kế tiếp. Tách ra vì nó dài và vì nếu phần engine
-- hỏng thì phần cấu trúc đã áp xong không bị kéo theo.
-- =========================================================

-- ---------------------------------------------------------
-- 1. Bảng mức lương
-- ---------------------------------------------------------
create table public.muc_luong_hop_dong (
  id              uuid primary key default gen_random_uuid(),
  contract_id     uuid not null references public.labor_contracts (id) on delete cascade,

  -- Ngày BẮT ĐẦU áp dụng. Không có ngày kết thúc: mức sau tự thay mức trước.
  -- Hai cột ngày là hai chỗ phải giữ cho khớp nhau, và khi lệch thì sinh ra
  -- khoảng trống không ai để ý — cùng lý do với nhóm cfg_* ở P3.
  tu_ngay         date not null,

  position_salary numeric(15, 2) not null check (position_salary >= 0),
  bhxh_salary     numeric(15, 2) not null check (bhxh_salary >= 0),

  -- "Tăng lương định kỳ", "Điều chỉnh theo lương tối thiểu vùng"… Bắt buộc có
  -- lý do thì người xem lại sau này hiểu được, mà người nhập cũng phải dừng
  -- lại một nhịp trước khi đổi tiền của người khác.
  ly_do           text,

  dat_boi         uuid references public.app_users (id),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  constraint muc_luong_mot_ngay_mot_muc unique (contract_id, tu_ngay)
);

comment on table public.muc_luong_hop_dong is
  'Mức lương theo thời gian của một hợp đồng. Mức sau thay mức trước kể từ tu_ngay; những ngày trước đó vẫn tính theo mức cũ.';

create index idx_muc_luong_hop_dong on public.muc_luong_hop_dong (contract_id, tu_ngay desc);

create trigger trg_muc_luong_touch
  before update on public.muc_luong_hop_dong
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------
-- 2. Chuyển mức hiện tại thành mức đầu tiên
--
--    Hiệu lực từ NGÀY BẮT ĐẦU HỢP ĐỒNG, không phải từ hôm nay: mức đang ghi
--    trên hợp đồng là mức đã dùng để tính mọi kỳ lương từ trước tới giờ.
-- ---------------------------------------------------------
insert into public.muc_luong_hop_dong (contract_id, tu_ngay, position_salary, bhxh_salary, ly_do)
select lc.id, lc.start_date, lc.position_salary, lc.bhxh_salary,
       'Mức khi ký hợp đồng (chuyển từ dữ liệu cũ 19/08/2026)'
from public.labor_contracts lc;

-- ---------------------------------------------------------
-- 3. Hàm tra mức lương tại một ngày
--
--    Trước mức đầu tiên thì dùng chính mức đầu tiên. Không phải để "chữa cháy":
--    ngày trước khi hợp đồng bắt đầu thì người ta chưa đi làm, nên chẳng có
--    ngày công nào rơi vào đó — trả về mức đầu tiên chỉ để hàm không bao giờ
--    trả NULL và làm phép nhân phía sau ra NULL âm thầm.
-- ---------------------------------------------------------
create or replace function public.luong_chuc_danh_tai_ngay(p_contract_id uuid, p_ngay date)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select m.position_salary from public.muc_luong_hop_dong m
     where m.contract_id = p_contract_id and m.tu_ngay <= p_ngay
     order by m.tu_ngay desc limit 1),
    (select m.position_salary from public.muc_luong_hop_dong m
     where m.contract_id = p_contract_id
     order by m.tu_ngay asc limit 1)
  );
$$;

create or replace function public.luong_bhxh_tai_ngay(p_contract_id uuid, p_ngay date)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select m.bhxh_salary from public.muc_luong_hop_dong m
     where m.contract_id = p_contract_id and m.tu_ngay <= p_ngay
     order by m.tu_ngay desc limit 1),
    (select m.bhxh_salary from public.muc_luong_hop_dong m
     where m.contract_id = p_contract_id
     order by m.tu_ngay asc limit 1)
  );
$$;

-- Lương chức danh BÌNH QUÂN theo ngày dương lịch của một khoảng.
--
-- Dành cho người được MIỄN chấm công: họ hưởng đủ ngày công chuẩn nên không có
-- bảng công để chia theo ngày làm. Chia theo ngày dương lịch là cách phân bổ
-- trung tính nhất — quyết định 19/08/2026, ghi ra đây để người sau biết đó là
-- lựa chọn chứ không phải mặc định tình cờ.
create or replace function public.luong_chuc_danh_binh_quan(
  p_contract_id uuid, p_tu date, p_den date
)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select round(avg(public.luong_chuc_danh_tai_ngay(p_contract_id, d::date)))
  from generate_series(p_tu, p_den, interval '1 day') d;
$$;

-- Các mức đã dùng trong một kỳ, để chụp vào phiếu lương.
create or replace function public.muc_luong_trong_ky(
  p_contract_id uuid, p_tu date, p_den date
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(x order by x_tu_ngay), '[]'::jsonb)
  from (
    -- Mức đang hiệu lực tại ngày đầu kỳ.
    select
      p_tu as x_tu_ngay,
      jsonb_build_object(
        'tu_ngay', p_tu,
        'position_salary', public.luong_chuc_danh_tai_ngay(p_contract_id, p_tu),
        'bhxh_salary',     public.luong_bhxh_tai_ngay(p_contract_id, p_tu),
        'ghi_chu', 'mức đang hiệu lực đầu kỳ'
      ) as x
    union all
    -- Các mức bắt đầu áp dụng TRONG kỳ.
    select m.tu_ngay,
      jsonb_build_object(
        'tu_ngay', m.tu_ngay,
        'position_salary', m.position_salary,
        'bhxh_salary',     m.bhxh_salary,
        'ghi_chu', coalesce(m.ly_do, 'đổi mức trong kỳ')
      )
    from public.muc_luong_hop_dong m
    where m.contract_id = p_contract_id
      and m.tu_ngay > p_tu and m.tu_ngay <= p_den
  ) t;
$$;

revoke execute on function public.luong_chuc_danh_tai_ngay(uuid, date)      from anon;
revoke execute on function public.luong_bhxh_tai_ngay(uuid, date)           from anon;
revoke execute on function public.luong_chuc_danh_binh_quan(uuid, date, date) from anon;
revoke execute on function public.muc_luong_trong_ky(uuid, date, date)      from anon;

-- ---------------------------------------------------------
-- 4. Định nghĩa lại hàm phụ thuộc TRƯỚC khi gỡ cột
--
--    `la_nhan_vien_chinh_thuc` là hàm SQL nên Postgres theo dõi phụ thuộc cột:
--    gỡ cột trước là lệnh DROP bị từ chối.
-- ---------------------------------------------------------
create or replace function public.la_nhan_vien_chinh_thuc(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.app_users u
    join public.employees e on e.id = u.employee_id
    join public.labor_contracts lc on lc.employee_id = e.id and lc.is_active
    where u.id = p_user_id
      and u.is_active
      and e.deleted_at is null
      and e.status = 'chinh_thuc'
      -- Mức đang hiệu lực HÔM NAY, không phải mức khi ký.
      and public.luong_bhxh_tai_ngay(lc.id, current_date) > 0
  );
$$;

-- ---------------------------------------------------------
-- 5. Gỡ hai cột lương khỏi hợp đồng
-- ---------------------------------------------------------
alter table public.labor_contracts
  drop column position_salary,
  drop column bhxh_salary;

comment on table public.labor_contracts is
  'Hợp đồng lao động. Mức lương KHÔNG nằm ở đây từ 19/08/2026 — xem muc_luong_hop_dong, nơi mỗi mức có ngày hiệu lực riêng.';

-- ---------------------------------------------------------
-- 6. Phiếu lương chụp lại CĂN CỨ, không chỉ kết quả
--
--    Trước bản này phiếu lưu gross/net nhưng không lưu mức lương đã sinh ra
--    chúng. Tháng đủ công thì gross tình cờ bằng lương chức danh nên còn đoán
--    ra; tháng thiếu công, có làm thêm, hoặc có phụ cấp thì gross KHÁC lương
--    chức danh và không dựng lại được. Nay một tháng còn có thể có hai mức,
--    nên thiếu chỗ này là phiếu lương không tự giải thích được nữa.
-- ---------------------------------------------------------
alter table public.payslips
  add column luong_dong_bhxh    numeric(15, 2),
  add column muc_luong_snapshot jsonb not null default '[]'::jsonb;

comment on column public.payslips.luong_dong_bhxh is
  'Mức lương đóng bảo hiểm ĐÃ DÙNG cho kỳ này — mức của ngày ĐẦU kỳ (quyết định 19/08/2026).';

comment on column public.payslips.muc_luong_snapshot is
  'Các mức lương chức danh đã áp dụng trong kỳ, kèm ngày hiệu lực. Nhiều hơn một phần tử nghĩa là kỳ đó có đổi mức.';

-- ---------------------------------------------------------
-- 7. RLS — cùng ma trận với labor_contracts
--
--    Mức lương nhạy cảm ngang hợp đồng: trưởng phòng KHÔNG đọc được lương của
--    cấp dưới, giữ nguyên quyết định từ P1.
--
--    KHÔNG có policy DELETE. Gõ nhầm một mức thì SỬA mức đó, không xoá —
--    lịch sử lương là thứ để giải thích những đồng tiền đã trả.
-- ---------------------------------------------------------
alter table public.muc_luong_hop_dong enable row level security;
alter table public.muc_luong_hop_dong force  row level security;

create policy "muc_luong_select_self"
  on public.muc_luong_hop_dong for select
  to authenticated
  using (
    exists (
      select 1 from public.labor_contracts lc
      where lc.id = contract_id and lc.employee_id = (select public.current_employee_id())
    )
  );

create policy "muc_luong_select_hr_ketoan_admin"
  on public.muc_luong_hop_dong for select
  to authenticated
  using ((select public.can_read_all_employees()));

create policy "muc_luong_insert_hr_admin"
  on public.muc_luong_hop_dong for insert
  to authenticated
  with check ((select public.is_hr_or_admin()));

create policy "muc_luong_update_hr_admin"
  on public.muc_luong_hop_dong for update
  to authenticated
  using ((select public.is_hr_or_admin()))
  with check ((select public.is_hr_or_admin()));

revoke all on public.muc_luong_hop_dong from anon, authenticated;
grant select, insert, update on public.muc_luong_hop_dong to authenticated;
