-- =========================================================
-- P6a — Chứng từ PDF cho bảng thanh toán tổ và kỳ lương
--
-- Triệu Vũ, 24/08/2026: "phần tính lương của tổ đội đã tính xong không cho
-- phép sửa nữa, sau khi duyệt bảng lương tạo ngay file pdf lưu lại như chứng
-- từ."
--
-- Phần "không cho sửa nữa" đã xong ở P5h (thu hồi UPDATE trên
-- `dong_thanh_toan_to`). Bản này làm nốt phần chứng từ.
--
-- CHỨNG TỪ LÀ GÌ Ở ĐÂY, VÀ KHÔNG LÀ GÌ
--
-- Nó là **bản chụp bất biến** của một con số đã chốt: đọc được mà không cần
-- mở phần mềm, và giữ được cả khi bảng gốc bị xoá. Nó KHÔNG phải chữ ký số và
-- không mang giá trị pháp lý của hoá đơn — nói rõ ngay đây để về sau không ai
-- viện dẫn nó như thứ nó không phải.
--
-- Chống sửa bằng hai lớp:
--   1. Không ai GHI được vào bucket ngoài Edge Function (`service_role`) —
--      cùng quy ước với bucket ảnh chấm công.
--   2. Mỗi bản ghi mang `sha256` của file. File trong kho bị thay thì vân tay
--      lệch, và không ai sửa được vân tay vì bảng này cũng không cho UPDATE.
--
-- SINH SAU, KHÔNG SINH TRONG CÙNG GIAO DỊCH
--
-- Chốt kỳ lương là thao tác database; sinh PDF là gọi mạng. Buộc hai thứ vào
-- một giao dịch nghĩa là một lần Edge Function lỗi sẽ chặn luôn việc chốt kỳ —
-- đem một việc quan trọng ra phụ thuộc vào một việc phụ.
--
-- Nên: chốt trước, sinh chứng từ ngay sau. Sinh hỏng thì **thiếu chứng từ phải
-- NHÌN THẤY ĐƯỢC**, không được im lặng. Đó là việc của view
-- `chung_tu_con_thieu` ở cuối file — giao diện đọc nó và hiện nút sinh lại.
-- =========================================================

-- ---------------------------------------------------------
-- 1. Bảng chứng từ
-- ---------------------------------------------------------
create type public.loai_chung_tu as enum ('bang_thanh_toan_to', 'ky_luong');

comment on type public.loai_chung_tu is
  'Loại chứng từ. Thêm loại mới thì phải sửa cả co_the_doc_chung_tu() — "ai đọc được loại này" là câu hỏi bắt buộc trả lời.';

create sequence public.chung_tu_so_hieu_seq;

create table public.chung_tu (
  id           uuid primary key default gen_random_uuid(),

  -- Số hiệu để người ta gọi tên chứng từ trong đời thật ("CT-2026-000007"),
  -- không bắt ai đọc uuid.
  so_hieu      text not null unique,

  loai         public.loai_chung_tu not null,

  -- Không đặt khoá ngoại: cột này trỏ tới hai bảng khác nhau tuỳ `loai`.
  -- Đánh đổi đã cân: mất ràng buộc tham chiếu, đổi lấy việc chứng từ SỐNG SÓT
  -- khi bảng gốc bị xoá — mà đó chính là lý do tồn tại của chứng từ.
  doi_tuong_id uuid not null,

  duong_dan    text not null unique,
  tieu_de      text not null,

  -- Chụp lại con số tổng ngay lúc sinh, để tra cứu không phải mở từng file.
  tong_tien    numeric(15, 2) not null check (tong_tien >= 0),
  so_dong      integer        not null check (so_dong >= 0),

  -- Vân tay file. Đây là thứ biến "một file trong kho" thành "bằng chứng".
  kich_thuoc   integer not null check (kich_thuoc > 0),
  sha256       text    not null check (sha256 ~ '^[0-9a-f]{64}$'),

  nguoi_tao    uuid not null references public.app_users (id),
  tao_luc      timestamptz not null default now(),

  -- Một đối tượng đúng một chứng từ. Xoá bảng thanh toán rồi sinh lại thì
  -- bảng mới mang id mới, nên ràng buộc này không cản việc sinh lại hợp lệ.
  constraint chung_tu_mot_doi_tuong_mot_ban unique (loai, doi_tuong_id)
);

comment on table public.chung_tu is
  'Chứng từ PDF của một con số đã chốt. BẤT BIẾN: không có policy UPDATE hay DELETE nào, và sha256 lộ ngay nếu file trong kho bị thay.';

comment on column public.chung_tu.doi_tuong_id is
  'bang_thanh_toan_to.id hoặc payroll_periods.id tuỳ loai. Cố ý KHÔNG có khoá ngoại: chứng từ phải sống sót khi bảng gốc bị xoá.';

create index idx_chung_tu_doi_tuong on public.chung_tu (loai, doi_tuong_id);

-- ---------------------------------------------------------
-- 2. Ai đọc được một chứng từ
--
--    MỘT QUY TẮC, VIẾT MỘT LẦN. Cả policy của bảng lẫn policy của bucket đều
--    gọi hàm này. Bài học đã lặp bốn lần trong dự án: một quy tắc chép ra hai
--    chỗ thì sẽ có ngày chỉ một chỗ được sửa.
--
--    Chứng từ kỳ lương chứa lương của toàn bộ nhân sự → đúng vòng
--    `can_read_payroll()`: quản trị, và chức danh được tick "Tính lương".
--
--    Chứng từ bảng thanh toán tổ → thêm người chấm công của chính tổ đó, y
--    hệt quyền đọc bảng gốc. Họ là người cầm bảng đi trả tiền.
-- ---------------------------------------------------------
create or replace function public.co_the_doc_chung_tu(
  p_loai         public.loai_chung_tu,
  p_doi_tuong_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.can_read_payroll()
      or (p_loai = 'bang_thanh_toan_to'
          and public.co_the_doc_bang_thanh_toan(p_doi_tuong_id));
$$;

comment on function public.co_the_doc_chung_tu(public.loai_chung_tu, uuid) is
  'Quy tắc đọc chứng từ, viết đúng một lần. Policy của bảng chung_tu và policy của bucket chung-tu đều đi qua đây.';

revoke execute on function public.co_the_doc_chung_tu(public.loai_chung_tu, uuid) from public, anon;
grant  execute on function public.co_the_doc_chung_tu(public.loai_chung_tu, uuid) to authenticated;

create or replace function public.co_the_doc_chung_tu_theo_duong_dan(p_duong_dan text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.chung_tu c
    where c.duong_dan = p_duong_dan
      and public.co_the_doc_chung_tu(c.loai, c.doi_tuong_id)
  );
$$;

comment on function public.co_the_doc_chung_tu_theo_duong_dan(text) is
  'Bản dành cho policy của storage, tra ngược từ đường dẫn file. Uỷ quyền cho co_the_doc_chung_tu() chứ không chép lại điều kiện.';

revoke execute on function public.co_the_doc_chung_tu_theo_duong_dan(text) from public, anon;
grant  execute on function public.co_the_doc_chung_tu_theo_duong_dan(text) to authenticated;

-- ---------------------------------------------------------
-- 3. RLS
--
--    Chỉ có policy SELECT. Không INSERT / UPDATE / DELETE cho ai — kể cả
--    admin. Thiếu policy nghĩa là RLS từ chối, và `service_role` (Edge
--    Function) bỏ qua RLS nên vẫn ghi được.
--
--    Admin cũng không xoá được, và đó là chủ ý: chứng từ mà người quyền cao
--    nhất xoá được thì nó không chứng minh được gì trước một tranh chấp
--    lương. Cần xoá thật thì làm bằng migration — có vết trong git.
-- ---------------------------------------------------------
alter table public.chung_tu enable row level security;

create policy "chung_tu_select"
  on public.chung_tu for select
  to authenticated
  using ((select public.co_the_doc_chung_tu(loai, doi_tuong_id)));

grant select on public.chung_tu to authenticated;
revoke insert, update, delete on public.chung_tu from authenticated;
revoke all on public.chung_tu from anon;
revoke all on sequence public.chung_tu_so_hieu_seq from anon, authenticated;

-- ---------------------------------------------------------
-- 4. Chỗ nào còn THIẾU chứng từ
--
--    Sinh PDF nằm ngoài giao dịch chốt nên nó hỏng được. Hỏng mà im lặng là
--    kiểu hỏng tệ nhất — ba tháng sau mới phát hiện không có chứng từ nào.
--
--    View này là chỗ giao diện đọc để hiện cảnh báo và nút sinh lại. Nó dùng
--    `security_invoker` nên người đọc chỉ thấy phần họ vốn được thấy: kế toán
--    thấy cả hai loại, người chấm công chỉ thấy bảng của tổ mình.
-- ---------------------------------------------------------
create or replace view public.chung_tu_con_thieu
with (security_invoker = true)
as
  select 'bang_thanh_toan_to'::public.loai_chung_tu as loai,
         b.id      as doi_tuong_id,
         t.name || ' · ' || to_char(b.tu_ngay, 'DD/MM') || '-'
                || to_char(b.den_ngay, 'DD/MM/YYYY') as ten,
         b.tao_luc as chot_luc
  from public.bang_thanh_toan_to b
  join public.to_doi t on t.id = b.to_doi_id
  where not exists (
    select 1 from public.chung_tu c
    where c.loai = 'bang_thanh_toan_to' and c.doi_tuong_id = b.id
  )

  union all

  select 'ky_luong'::public.loai_chung_tu,
         k.id,
         'Kỳ lương ' || lpad(k.month::text, 2, '0') || '/' || k.year::text,
         k.closed_at
  from public.payroll_periods k
  where k.status <> 'mo'
    and not exists (
      select 1 from public.chung_tu c
      where c.loai = 'ky_luong' and c.doi_tuong_id = k.id
    );

comment on view public.chung_tu_con_thieu is
  'Bảng thanh toán và kỳ lương đã chốt mà CHƯA có chứng từ PDF. Giao diện đọc view này để hiện nút sinh lại — thiếu chứng từ phải nhìn thấy được, không được im lặng.';

grant select on public.chung_tu_con_thieu to authenticated;
revoke all on public.chung_tu_con_thieu from anon;
