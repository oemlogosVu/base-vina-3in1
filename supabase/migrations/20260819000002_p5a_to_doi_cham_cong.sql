-- =========================================================
-- P5a — Chấm công theo tổ đội thuê công nhật
--
-- Kế hoạch Triệu Vũ duyệt 19/08/2026. Bốn quyết định định hình bản này:
--   1. Người công nhật DÙNG LẠI bảng employees (trạng thái cong_tac_vien),
--      không tách bảng riêng — người hôm nay làm công nhật, mai được nhận
--      chính thức, chỉ đổi trạng thái chứ không phải chuyển bảng.
--   2. Tiền trả qua BẢNG THANH TOÁN RIÊNG của tổ, không qua phiếu lương.
--      Nên bản này KHÔNG đụng engine lương, và cũng không có cột đơn giá:
--      đơn giá gắn theo người / theo tổ / theo chức danh là quyết định về
--      tiền, hỏi ở phase thanh toán chứ không đoán (AGENTS.md mục 5).
--   3. Đếm theo SỐ CÔNG 0 / 0,5 / 1, không phải giờ vào–giờ ra.
--   4. Người được chấm công là một Ô TRÊN TỔ, không phải vai trò thứ sáu.
--      "Được giao chấm công" là quan hệ với MỘT tổ, còn vai trò thì toàn hệ
--      thống — một người chấm cho hai tổ là chuyện bình thường, mà vai trò
--      không diễn đạt được điều đó.
--
-- VÌ SAO KHÔNG DÙNG attendance_logs / attendance_days: luồng kia là mỗi
-- người tự bấm trên máy mình, giờ lấy từ server. Ở đây tổ trưởng gõ hộ cho
-- cả tổ. Trộn hai thứ vào một bảng là biến "giờ bấm của chính người lao
-- động" thành "giờ người khác khai hộ" — khác hẳn nhau về giá trị chứng cứ
-- khi có tranh chấp công, mà lại không còn cách nào phân biệt.
--
-- Ảnh xác minh: bucket và policy nằm ở migration kế tiếp, tách ra theo đúng
-- tiền lệ của P2 — storage thuộc schema Supabase quản lý, hỏng ở đó không
-- được kéo đổ phần bảng đã áp xong.
-- =========================================================

-- ---------------------------------------------------------
-- 1. Tổ đội
-- ---------------------------------------------------------
create table public.to_doi (
  id                 uuid primary key default gen_random_uuid(),
  code               text not null unique,
  name               text not null,

  -- BẮT BUỘC. Bảng thanh toán tách theo pháp nhân, nên một tổ không thuộc
  -- công ty nào là một tổ không thanh toán được. Khác với departments —
  -- phòng ban để NULL được vì hai công ty dùng chung bộ máy.
  company_id         uuid not null references public.companies (id),

  -- Công trường nơi tổ làm việc. NULL được: tổ chạy nhiều công trường.
  department_id      uuid references public.departments (id),

  to_truong_id       uuid references public.employees (id),

  -- Tài khoản được giao chấm công cho tổ này. NULL = chưa giao, và khi đó
  -- KHÔNG AI chấm được cho tổ ngoài HR/admin — đó là trạng thái đúng, không
  -- phải lỗi: chưa giao cho ai thì không ai được chấm.
  nguoi_cham_cong_id uuid references public.app_users (id),

  ghi_chu            text,
  is_active          boolean not null default true,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

comment on table public.to_doi is
  'Tổ nhân công thuê công nhật. Không đóng bảo hiểm, không hợp đồng lao động — tiền trả qua bảng thanh toán riêng của tổ, không qua phiếu lương.';

comment on column public.to_doi.nguoi_cham_cong_id is
  'Tài khoản được giao chấm công cho tổ này. NULL = chưa giao, không ai chấm được ngoài HR/admin.';

create index idx_to_doi_cong_ty on public.to_doi (company_id);
create index idx_to_doi_nguoi_cham on public.to_doi (nguoi_cham_cong_id);

-- ---------------------------------------------------------
-- 2. Thành viên của tổ
--
--    CÓ KỲ, không phải danh sách cố định: công nhật vào ra theo mùa vụ, và
--    bảng công của tháng trước phải giữ đúng danh sách của tháng trước.
-- ---------------------------------------------------------
create table public.to_doi_thanh_vien (
  id          uuid primary key default gen_random_uuid(),
  to_doi_id   uuid not null references public.to_doi (id) on delete cascade,
  employee_id uuid not null references public.employees (id),
  tu_ngay     date not null,
  den_ngay    date,
  ghi_chu     text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),

  constraint tdtv_ky_hop_le check (den_ngay is null or den_ngay >= tu_ngay)
);

comment on table public.to_doi_thanh_vien is
  'Ai thuộc tổ nào, trong khoảng thời gian nào. den_ngay NULL = còn trong tổ.';

-- Một người chỉ được ở MỘT tổ đang mở. Không có ràng buộc này thì thêm nhầm
-- một người vào tổ thứ hai là ngày công của họ bị chấm hai lần ở hai bảng
-- công khác nhau, và không gì phát hiện ra.
create unique index uniq_thanh_vien_mot_to_dang_mo
  on public.to_doi_thanh_vien (employee_id)
  where den_ngay is null;

create index idx_tdtv_to_doi on public.to_doi_thanh_vien (to_doi_id);
create index idx_tdtv_nhan_su on public.to_doi_thanh_vien (employee_id);

-- ---------------------------------------------------------
-- 3. Phiên chấm công — một tổ, một ngày, một ảnh
--
--    Ảnh chụp CẢ TỔ mỗi ngày (quyết định 19/08/2026), nên ảnh thuộc về phiên
--    chứ không thuộc về từng dòng công.
-- ---------------------------------------------------------
create table public.phien_cham_cong_to (
  id            uuid primary key default gen_random_uuid(),
  to_doi_id     uuid not null references public.to_doi (id),
  work_date     date not null,

  -- Đường dẫn trong bucket private. CHỈ Edge Function ghi được cột này —
  -- quyền cấp cột ở mục 7 không cho `authenticated` chạm vào. Nếu người chấm
  -- tự đặt được đường dẫn, họ trỏ sang ảnh của tổ khác hoặc của ngày khác,
  -- tức tự làm giả bằng chứng.
  anh_path      text,

  nguoi_cham_id uuid not null references public.app_users (id),
  cham_luc      timestamptz not null default now(),
  ghi_chu       text,

  da_duyet      boolean not null default false,
  duyet_boi     uuid references public.app_users (id),
  duyet_luc     timestamptz,

  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  constraint phien_mot_to_mot_ngay unique (to_doi_id, work_date),

  -- Cần cho khoá ngoại ghép ở mục 4. id đã là khoá chính, nhưng khoá ngoại
  -- ghép đòi phía cha phải có ràng buộc duy nhất đúng bộ cột đó.
  constraint phien_id_kem_ngay unique (id, work_date),

  -- Thiếu ảnh thì DUYỆT KHÔNG ĐƯỢC (quyết định 19/08/2026). Số công vẫn lưu
  -- ngay để người lao động không mất công vì sóng yếu ngoài công trường,
  -- nhưng công chưa có ảnh thì chưa thành công đã duyệt.
  constraint phien_duyet_phai_co_anh check (not da_duyet or anh_path is not null),

  -- Đã duyệt thì phải biết ai duyệt và lúc nào; chưa duyệt thì hai ô đó phải
  -- rỗng. Nửa vời là bảng công không giải thích được cho ai.
  constraint phien_duyet_du_doi check (
    (da_duyet and duyet_boi is not null and duyet_luc is not null)
    or (not da_duyet and duyet_boi is null and duyet_luc is null)
  )
);

comment on table public.phien_cham_cong_to is
  'Một lần chấm công cho cả tổ trong một ngày, kèm ảnh xác minh. Đã duyệt thì người chấm không sửa được nữa.';

create index idx_phien_to_doi on public.phien_cham_cong_to (to_doi_id, work_date desc);
create index idx_phien_cho_duyet on public.phien_cham_cong_to (work_date) where not da_duyet;

-- ---------------------------------------------------------
-- 4. Số công từng người trong phiên
-- ---------------------------------------------------------
create table public.cham_cong_cong_nhat (
  id          uuid primary key default gen_random_uuid(),
  phien_id    uuid not null,

  -- Lặp lại ngày của phiên. Cố ý dư thừa: nó là cột duy nhất cho phép đặt
  -- ràng buộc "một người một ngày một dòng" xuyên qua mọi tổ. Khoá ngoại
  -- ghép bên dưới khoá chặt hai giá trị này với nhau nên không lệch được.
  work_date   date not null,

  employee_id uuid not null references public.employees (id),

  -- 0 / 0,5 / 1 — quyết định 19/08/2026. Không đếm giờ.
  so_cong     numeric(3, 2) not null,

  ghi_chu     text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),

  constraint cccn_so_cong_hop_le check (so_cong in (0, 0.5, 1)),
  constraint cccn_mot_nguoi_mot_phien unique (phien_id, employee_id),

  -- Chặn đếm hai lần: kể cả khi ai đó lọt vào hai tổ, ngày công vẫn chỉ ghi
  -- được một lần.
  constraint cccn_mot_nguoi_mot_ngay unique (employee_id, work_date),

  -- Khoá ngoại GHÉP: dòng công không thể mang ngày khác ngày của phiên nó
  -- thuộc về. Nếu chỉ trỏ phien_id, một lệnh update lén đổi work_date là
  -- ràng buộc "một người một ngày" ở trên mất tác dụng ngay.
  constraint cccn_thuoc_phien foreign key (phien_id, work_date)
    references public.phien_cham_cong_to (id, work_date) on delete cascade
);

comment on table public.cham_cong_cong_nhat is
  'Số công của từng người trong một phiên chấm của tổ. Không xoá cứng — sửa số công về 0 để bảng công còn dấu vết.';

create index idx_cccn_nhan_su on public.cham_cong_cong_nhat (employee_id, work_date desc);

-- ---------------------------------------------------------
-- 5. Trigger updated_at — tái dùng hàm của P0
-- ---------------------------------------------------------
create trigger trg_to_doi_touch
  before update on public.to_doi
  for each row execute function public.touch_updated_at();

create trigger trg_to_doi_thanh_vien_touch
  before update on public.to_doi_thanh_vien
  for each row execute function public.touch_updated_at();

create trigger trg_phien_cham_cong_to_touch
  before update on public.phien_cham_cong_to
  for each row execute function public.touch_updated_at();

create trigger trg_cham_cong_cong_nhat_touch
  before update on public.cham_cong_cong_nhat
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------
-- 6. Hàm nền cho policy
--
--    security definer + search_path rỗng, cùng chuẩn với các hàm P0/P1:
--    hàm đọc chính những bảng mà policy của chúng lại gọi hàm này.
-- ---------------------------------------------------------
create or replace function public.la_nguoi_cham_cong_to(p_to_doi_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.to_doi t
    join public.app_users u on u.id = t.nguoi_cham_cong_id
    where t.id = p_to_doi_id
      and t.is_active
      and u.is_active
      and u.id = (select auth.uid())
  );
$$;

comment on function public.la_nguoi_cham_cong_to(uuid) is
  'Người đang đăng nhập có được giao chấm công cho tổ này không. Tổ đã ngừng hoạt động hoặc tài khoản bị khoá đều trả false.';

create or replace function public.la_nguoi_cham_cong_phien(p_phien_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.phien_cham_cong_to p
    where p.id = p_phien_id
      and public.la_nguoi_cham_cong_to(p.to_doi_id)
  );
$$;

-- Còn sửa được = là người chấm của tổ VÀ phiên chưa duyệt. Tách khỏi hàm
-- trên vì đọc và ghi có điều kiện khác nhau: duyệt rồi vẫn xem được, chỉ là
-- không sửa được nữa.
create or replace function public.phien_con_sua_duoc(p_phien_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.phien_cham_cong_to p
    where p.id = p_phien_id
      and not p.da_duyet
      and public.la_nguoi_cham_cong_to(p.to_doi_id)
  );
$$;

-- Bản nhận TEXT, dành riêng cho policy trên storage.objects.
--
-- Ở đó thứ ta có trong tay là TÊN THƯ MỤC, tức chuỗi do người khác đặt. Ép
-- chuỗi ấy sang uuid ngay trong policy là mở một đường hỏng lạ: chỉ cần một
-- file có tên thư mục không phải uuid lọt vào bucket, câu ép kiểu ném lỗi và
-- policy vỡ cho MỌI người, không riêng file đó. So sánh id::text = p_id thì
-- chuỗi rác chỉ đơn giản là không khớp.
create or replace function public.la_nguoi_cham_cong_to_txt(p_id text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.to_doi t
    join public.app_users u on u.id = t.nguoi_cham_cong_id
    where t.id::text = p_id
      and t.is_active
      and u.is_active
      and u.id = (select auth.uid())
  );
$$;

revoke execute on function public.la_nguoi_cham_cong_to_txt(text) from anon;
revoke execute on function public.la_nguoi_cham_cong_to(uuid)    from anon;
revoke execute on function public.la_nguoi_cham_cong_phien(uuid) from anon;
revoke execute on function public.phien_con_sua_duoc(uuid)       from anon;

-- =========================================================
-- 7. RLS
--
--    | Bảng                | NV/TP | Người chấm của tổ      | HR/Admin | Kế toán
--    |---------------------|-------|------------------------|----------|--------
--    | to_doi              | —     | tổ của mình, đọc       | đọc+ghi  | đọc
--    | to_doi_thanh_vien   | —     | tổ của mình, đọc       | đọc+ghi  | đọc
--    | phien_cham_cong_to  | —     | tổ mình, ghi khi chưa duyệt | đọc+ghi+duyệt | đọc
--    | cham_cong_cong_nhat | —     | tổ mình, ghi khi chưa duyệt | đọc+ghi  | đọc
--
--    Người công nhật KHÔNG có tài khoản đăng nhập nên không có policy nào
--    cho họ. Nếu sau này có, họ sẽ cần policy "xem công của chính mình" —
--    cố ý để dành, không đoán trước.
--
--    Không bảng nào có policy DELETE.
-- =========================================================

alter table public.to_doi              enable row level security;
alter table public.to_doi              force  row level security;
alter table public.to_doi_thanh_vien   enable row level security;
alter table public.to_doi_thanh_vien   force  row level security;
alter table public.phien_cham_cong_to  enable row level security;
alter table public.phien_cham_cong_to  force  row level security;
alter table public.cham_cong_cong_nhat enable row level security;
alter table public.cham_cong_cong_nhat force  row level security;

-- ---- to_doi ----
create policy "to_doi_select_quan_ly"
  on public.to_doi for select
  to authenticated
  using ((select public.can_read_all_employees()));

create policy "to_doi_select_nguoi_cham"
  on public.to_doi for select
  to authenticated
  using ((select public.la_nguoi_cham_cong_to(id)));

create policy "to_doi_insert_hr_admin"
  on public.to_doi for insert
  to authenticated
  with check ((select public.is_hr_or_admin()));

create policy "to_doi_update_hr_admin"
  on public.to_doi for update
  to authenticated
  using ((select public.is_hr_or_admin()))
  with check ((select public.is_hr_or_admin()));

-- ---- to_doi_thanh_vien ----
create policy "tdtv_select_quan_ly"
  on public.to_doi_thanh_vien for select
  to authenticated
  using ((select public.can_read_all_employees()));

create policy "tdtv_select_nguoi_cham"
  on public.to_doi_thanh_vien for select
  to authenticated
  using ((select public.la_nguoi_cham_cong_to(to_doi_id)));

create policy "tdtv_insert_hr_admin"
  on public.to_doi_thanh_vien for insert
  to authenticated
  with check ((select public.is_hr_or_admin()));

create policy "tdtv_update_hr_admin"
  on public.to_doi_thanh_vien for update
  to authenticated
  using ((select public.is_hr_or_admin()))
  with check ((select public.is_hr_or_admin()));

-- ---- phien_cham_cong_to ----
create policy "phien_select_quan_ly"
  on public.phien_cham_cong_to for select
  to authenticated
  using ((select public.can_read_all_employees()));

create policy "phien_select_nguoi_cham"
  on public.phien_cham_cong_to for select
  to authenticated
  using ((select public.la_nguoi_cham_cong_to(to_doi_id)));

-- Người chấm mở phiên cho ĐÚNG tổ mình, và phải đứng tên chính mình. Không
-- ràng buộc nguoi_cham_id thì họ mở phiên rồi ghi tên người khác vào.
create policy "phien_insert_nguoi_cham"
  on public.phien_cham_cong_to for insert
  to authenticated
  with check (
    (select public.la_nguoi_cham_cong_to(to_doi_id))
    and nguoi_cham_id = (select auth.uid())
    and not da_duyet
  );

create policy "phien_insert_hr_admin"
  on public.phien_cham_cong_to for insert
  to authenticated
  with check ((select public.is_hr_or_admin()));

-- USING xét dòng CŨ, WITH CHECK xét dòng MỚI. Cặp này chặn đúng hai đường:
-- không sửa được phiên đã duyệt, và không tự duyệt phiên của mình.
create policy "phien_update_nguoi_cham"
  on public.phien_cham_cong_to for update
  to authenticated
  using ((select public.la_nguoi_cham_cong_to(to_doi_id)) and not da_duyet)
  with check ((select public.la_nguoi_cham_cong_to(to_doi_id)) and not da_duyet);

create policy "phien_update_hr_admin"
  on public.phien_cham_cong_to for update
  to authenticated
  using ((select public.is_hr_or_admin()))
  with check ((select public.is_hr_or_admin()));

-- ---- cham_cong_cong_nhat ----
create policy "cccn_select_quan_ly"
  on public.cham_cong_cong_nhat for select
  to authenticated
  using ((select public.can_read_all_employees()));

create policy "cccn_select_nguoi_cham"
  on public.cham_cong_cong_nhat for select
  to authenticated
  using ((select public.la_nguoi_cham_cong_phien(phien_id)));

create policy "cccn_insert_nguoi_cham"
  on public.cham_cong_cong_nhat for insert
  to authenticated
  with check ((select public.phien_con_sua_duoc(phien_id)));

create policy "cccn_insert_hr_admin"
  on public.cham_cong_cong_nhat for insert
  to authenticated
  with check ((select public.is_hr_or_admin()));

create policy "cccn_update_nguoi_cham"
  on public.cham_cong_cong_nhat for update
  to authenticated
  using ((select public.phien_con_sua_duoc(phien_id)))
  with check ((select public.phien_con_sua_duoc(phien_id)));

create policy "cccn_update_hr_admin"
  on public.cham_cong_cong_nhat for update
  to authenticated
  using ((select public.is_hr_or_admin()))
  with check ((select public.is_hr_or_admin()));

-- ---------------------------------------------------------
-- 8. Quyền bảng — và quyền CẤP CỘT
--
--    Policy nói được "hàng nào", không nói được "cột nào". Hai cột phải chặn
--    bằng quyền cấp cột vì policy không với tới:
--
--      phien.anh_path  — chỉ Edge Function (service_role) ghi. Người chấm tự
--                        đặt được đường dẫn là trỏ sang ảnh tổ khác được.
--      cccn.work_date  — chỉ đặt lúc thêm dòng. Cho sửa là mở đường lách
--                        ràng buộc "một người một ngày".
--
--    Cùng cách đã dùng cho attendance_logs ở P2b.
-- ---------------------------------------------------------
revoke all on public.to_doi              from anon, authenticated;
revoke all on public.to_doi_thanh_vien   from anon, authenticated;
revoke all on public.phien_cham_cong_to  from anon, authenticated;
revoke all on public.cham_cong_cong_nhat from anon, authenticated;

grant select, insert, update on public.to_doi            to authenticated;
grant select, insert, update on public.to_doi_thanh_vien to authenticated;

grant select on public.phien_cham_cong_to to authenticated;
grant insert (to_doi_id, work_date, nguoi_cham_id, ghi_chu)
  on public.phien_cham_cong_to to authenticated;
grant update (ghi_chu, da_duyet, duyet_boi, duyet_luc)
  on public.phien_cham_cong_to to authenticated;

grant select on public.cham_cong_cong_nhat to authenticated;
grant insert (phien_id, work_date, employee_id, so_cong, ghi_chu)
  on public.cham_cong_cong_nhat to authenticated;
grant update (so_cong, ghi_chu)
  on public.cham_cong_cong_nhat to authenticated;
