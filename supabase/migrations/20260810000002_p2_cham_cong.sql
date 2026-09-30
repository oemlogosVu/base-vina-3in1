-- =========================================================
-- P2 — Chấm công mobile: danh mục, log thô, bảng công ngày
--
-- Kế hoạch đã duyệt: docs/P2-KE-HOACH.md (Triệu Vũ duyệt 10/08/2026).
--
-- Bốn bảng: office_locations, work_shifts, attendance_logs, attendance_days.
-- Storage bucket cho ảnh selfie nằm ở migration kế tiếp, tách riêng để nếu
-- phần storage hỏng thì phần bảng đã áp dụng xong không bị kéo theo.
-- =========================================================

-- ---------------------------------------------------------
-- 1. Kiểu dữ liệu
-- ---------------------------------------------------------
create type public.check_type as enum ('in', 'out');

comment on type public.check_type is
  'Chiều của một lần bấm chấm công. Chốt 10/08/2026: chấm 2 lần/ngày (vào buổi sáng, ra buổi chiều).';

-- Trạng thái một ngày công sau khi tổng hợp.
--   du_cong       — có đủ vào/ra, giờ làm đạt mức của ca
--   thieu_gio     — có đủ vào/ra nhưng chưa đủ giờ
--   thieu_cham_ra — có chấm vào, KHÔNG có chấm ra
--   nghi          — không có lần chấm hợp lệ nào
create type public.attendance_day_status as enum (
  'du_cong',
  'thieu_gio',
  'thieu_cham_ra',
  'nghi'
);

-- ---------------------------------------------------------
-- 2. Danh mục — địa điểm được phép chấm công
--
--    Toạ độ do Triệu Vũ tự lấy tại chỗ qua màn /quan-tri/dia-diem (quyết định
--    10/08/2026), nên migration này KHÔNG seed toạ độ nào. Bảng rỗng nghĩa là
--    chưa ai chấm công hợp lệ được — đó là trạng thái đúng, không phải lỗi.
-- ---------------------------------------------------------
create table public.office_locations (
  id            uuid primary key default gen_random_uuid(),
  code          text not null unique,
  name          text not null,
  latitude      double precision not null,
  longitude     double precision not null,
  radius_meters integer not null default 150,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  -- Toạ độ phải nằm trong dải hợp lệ của Trái Đất. Một cú gõ nhầm dấu thập
  -- phân (10.7 -> 107) mà lọt vào đây là mọi phép tính khoảng cách sai hết.
  constraint office_lat_hop_le check (latitude  between  -90 and  90),
  constraint office_lng_hop_le check (longitude between -180 and 180),
  -- 20m là nhỏ hơn sai số GPS thường gặp -> không ai chấm được.
  -- 5km là rộng hơn cả một khu công nghiệp -> mất ý nghĩa kiểm soát.
  constraint office_ban_kinh_hop_le check (radius_meters between 20 and 5000)
);

comment on table public.office_locations is
  'Địa điểm được phép chấm công. Toạ độ nhập qua màn admin bằng nút "lấy vị trí hiện tại".';

-- ---------------------------------------------------------
-- 3. Danh mục — ca làm việc
--
--    Chốt 10/08/2026: ca 1 08:00–12:00, ca 2 13:00–17:00, chấm 2 lần/ngày.
--    Vì chỉ chấm 2 lần nên hệ thống theo dõi MỘT khoảng có mặt duy nhất
--    08:00–17:00 với 60 phút nghỉ trưa, không phải hai dòng ca. Schema vẫn
--    cho thêm dòng nếu sau này công ty đổi sang chấm 4 lần.
--
--    break_start / break_end là giờ nghỉ trưa THỰC, không phải "số phút nghỉ".
--    Lý do ở mục 4 dưới đây: phải trừ đúng phần giao, không trừ hằng số.
-- ---------------------------------------------------------
create table public.work_shifts (
  id            uuid primary key default gen_random_uuid(),
  code          text not null unique,
  name          text not null,
  start_time    time not null,
  end_time      time not null,
  break_start   time,
  break_end     time,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  constraint shift_ky_hop_le check (end_time > start_time),
  -- Nghỉ trưa: có thì phải có đủ cả hai đầu, và phải nằm trong ca.
  constraint shift_nghi_du_doi check (
    (break_start is null and break_end is null)
    or (break_start is not null and break_end is not null and break_end > break_start)
  ),
  constraint shift_nghi_trong_ca check (
    break_start is null
    or (break_start >= start_time and break_end <= end_time)
  )
);

comment on table public.work_shifts is
  'Ca làm việc. break_start/break_end là giờ nghỉ THỰC — cần để trừ đúng phần giao, không trừ hằng số 60 phút.';

insert into public.work_shifts (code, name, start_time, end_time, break_start, break_end)
values ('HC', 'Hanh chinh', time '08:00', time '17:00', time '12:00', time '13:00');

-- ---------------------------------------------------------
-- 4. Hàm tính giờ làm — trừ đúng PHẦN GIAO với giờ nghỉ
--
--    Cái bẫy phải tránh: lấy (ra - vào) rồi trừ thẳng 60 phút. Nó đúng với
--    ngày đủ và SAI với nửa ngày — người làm 08:00–12:00 sẽ bị tính 3 tiếng
--    trong khi họ làm đủ 4 tiếng. Mỗi buổi nghỉ nửa ngày mất oan 1 tiếng
--    công của người thật, và tới P3 là thành tiền sai.
--
--    Đặt ở database chứ không ở UI hay ở JS: engine lương P3 và job tổng hợp
--    đều phải ra cùng một con số, không được mỗi nơi tính một kiểu.
-- ---------------------------------------------------------
create or replace function public.phut_giao_nhau(
  a_bat_dau timestamptz, a_ket_thuc timestamptz,
  b_bat_dau timestamptz, b_ket_thuc timestamptz
)
returns integer
language sql
immutable
set search_path = ''
as $$
  select greatest(
    0,
    ceil(extract(epoch from (
      least(a_ket_thuc, b_ket_thuc) - greatest(a_bat_dau, b_bat_dau)
    )) / 60)
  )::integer;
$$;

comment on function public.phut_giao_nhau is
  'Số phút giao nhau của hai khoảng thời gian, 0 nếu không giao. Dùng để trừ giờ nghỉ trưa đúng phần thực sự chồng lấn.';

-- ---------------------------------------------------------
-- 5. Log thô — mỗi lần nhân viên bấm nút
--
--    Nhân viên KHÔNG insert thẳng vào bảng này. Insert chỉ đi qua Edge
--    Function, vì client tự insert thì tự đặt được logged_at và is_valid —
--    vi phạm AGENTS.md mục 2.2 (không tin dữ liệu client). Kỹ thuật: không
--    cấp quyền insert cho authenticated, Edge Function dùng service_role.
-- ---------------------------------------------------------
create table public.attendance_logs (
  id          uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.employees (id) on delete cascade,
  check_type  public.check_type not null,

  -- GIỜ SERVER. Không bao giờ nhận giá trị này từ client (AGENTS.md 2.2).
  logged_at   timestamptz not null default now(),

  latitude    double precision,
  longitude   double precision,
  -- Sai số do trình duyệt báo. Toạ độ sai số ±2000m mà nằm trong bán kính
  -- 150m là vô nghĩa — phải giữ lại để đánh giá và để giải thích về sau.
  accuracy_m  double precision,
  -- Server tự tính bằng Haversine, KHÔNG nhận từ client.
  distance_m  double precision,
  office_id   uuid references public.office_locations (id),
  selfie_path text,
  device_info jsonb not null default '{}'::jsonb,

  -- Mặc định FALSE có chủ đích: nếu Edge Function quên đặt, log không được
  -- tính công. Sai theo hướng bỏ sót an toàn hơn sai theo hướng tạo công khống.
  is_valid            boolean not null default false,
  ly_do_khong_hop_le  text,

  -- Duyệt tay. AGENTS.md mục 6: log nghi ngờ vẫn lưu, HR duyệt, không tự
  -- động loại cũng không tự động nhận. Muốn duyệt tay thì phải truy vết được
  -- ai duyệt và lúc nào, nếu không thì tranh chấp công không có căn cứ.
  duyet_boi      uuid references public.app_users (id),
  duyet_luc      timestamptz,
  ghi_chu_duyet  text,

  created_at  timestamptz not null default now(),

  constraint att_log_lat_hop_le check (latitude  is null or latitude  between  -90 and  90),
  constraint att_log_lng_hop_le check (longitude is null or longitude between -180 and 180),
  constraint att_log_accuracy_khong_am check (accuracy_m is null or accuracy_m >= 0),
  constraint att_log_distance_khong_am check (distance_m is null or distance_m >= 0),
  -- Duyệt thì phải có đủ ai + lúc nào, không được có cái này thiếu cái kia.
  constraint att_log_duyet_du_doi check (
    (duyet_boi is null and duyet_luc is null)
    or (duyet_boi is not null and duyet_luc is not null)
  )
);

comment on table public.attendance_logs is
  'Log thô mỗi lần bấm chấm công. logged_at và distance_m do SERVER đặt, không nhận từ client. Chỉ Edge Function được insert.';

create index idx_att_logs_nhan_vien_thoi_gian
  on public.attendance_logs (employee_id, logged_at desc);

-- Hàng đợi duyệt của HR. Partial index vì phần lớn log là hợp lệ.
create index idx_att_logs_cho_duyet
  on public.attendance_logs (logged_at desc)
  where is_valid = false and duyet_luc is null;

-- ---------------------------------------------------------
-- 6. Bảng công ngày — do job tổng hợp, không nhập tay
-- ---------------------------------------------------------
create table public.attendance_days (
  id                  uuid primary key default gen_random_uuid(),
  employee_id         uuid not null references public.employees (id) on delete cascade,

  -- Ngày làm việc theo GIỜ VIỆT NAM, không phải UTC. Ca đêm chấm ra 00:30
  -- giờ VN là UTC 17:30 hôm trước — tổng hợp theo UTC là đẩy công sang nhầm
  -- ngày. Mọi phép quy đổi phải viết tường minh at time zone 'Asia/Ho_Chi_Minh'.
  work_date           date not null,
  shift_id            uuid references public.work_shifts (id),

  first_in            timestamptz,
  last_out            timestamptz,

  worked_minutes      integer not null default 0,
  ot_minutes          integer not null default 0,
  late_minutes        integer not null default 0,
  early_leave_minutes integer not null default 0,

  status              public.attendance_day_status not null default 'nghi',
  tong_hop_luc        timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),

  constraint att_day_mot_nguoi_mot_ngay unique (employee_id, work_date),
  constraint att_day_worked_khong_am     check (worked_minutes      >= 0),
  constraint att_day_ot_khong_am         check (ot_minutes          >= 0),
  constraint att_day_late_khong_am       check (late_minutes        >= 0),
  constraint att_day_early_khong_am      check (early_leave_minutes >= 0),
  -- Có giờ ra thì phải sau giờ vào.
  constraint att_day_thu_tu_hop_le check (
    first_in is null or last_out is null or last_out >= first_in
  )
);

comment on table public.attendance_days is
  'Bảng công ngày do job tổng hợp từ attendance_logs. work_date theo giờ Việt Nam. Đầu vào của engine lương P3.';

create index idx_att_days_nhan_vien_ngay
  on public.attendance_days (employee_id, work_date desc);

-- ---------------------------------------------------------
-- 7. Trigger updated_at — tái dùng hàm của P0
--
--    attendance_logs cố ý KHÔNG có updated_at: nó là bằng chứng, không phải
--    dữ liệu sống. Thay đổi duy nhất được phép là duyệt tay, và việc đó đã
--    có duyet_luc ghi vết.
-- ---------------------------------------------------------
create trigger trg_office_locations_touch
  before update on public.office_locations
  for each row execute function public.touch_updated_at();

create trigger trg_work_shifts_touch
  before update on public.work_shifts
  for each row execute function public.touch_updated_at();

create trigger trg_attendance_days_touch
  before update on public.attendance_days
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------
-- 8. Hàm nền — ai được đọc chấm công của ai
--
--    Một hàm dùng chung cho cả attendance_logs lẫn attendance_days, thay vì
--    lặp lại điều kiện vai trò ở từng bảng — cùng nguyên tắc với ba hàm nền
--    của P0.
--
--    security definer BẮT BUỘC: hàm đọc public.employees, mà employees có
--    RLS. Không có security definer thì policy trên attendance_logs sẽ lọc
--    qua RLS của employees và cho kết quả sai một cách khó lần ra.
-- ---------------------------------------------------------
create or replace function public.can_read_attendance_of(p_employee_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    -- của chính mình
    p_employee_id = public.current_employee_id()
    -- HR, kế toán, admin đọc tất cả. Kế toán cần bảng công để đối chiếu khi
    -- tính lương P3.
    or public.current_app_role() in ('hr', 'ke_toan', 'admin')
    -- Trưởng phòng: CHỈ phòng trực tiếp, không đệ quy — cùng phạm vi đã duyệt
    -- ở P1, không tự mở rộng ở P2.
    or (
      public.current_app_role() = 'truong_phong'
      and exists (
        select 1 from public.employees e
        where e.id = p_employee_id
          and e.department_id = public.current_department_id()
      )
    );
$$;

comment on function public.can_read_attendance_of(uuid) is
  'Người đang đăng nhập có được đọc chấm công của nhân viên này không. Dùng chung cho attendance_logs và attendance_days.';

revoke execute on function public.can_read_attendance_of(uuid) from anon;

-- Chỉ HR và admin được duyệt log nghi ngờ (quyết định 10/08/2026: một đầu
-- mối chịu trách nhiệm về công; trưởng phòng xem được nhưng không duyệt).
create or replace function public.can_manage_attendance()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.current_app_role() in ('hr', 'admin');
$$;

revoke execute on function public.can_manage_attendance() from anon;

-- =========================================================
-- 9. RLS
--
--    | Bảng             | NV            | TP        | HR       | KT      | Admin
--    |------------------|---------------|-----------|----------|---------|--------
--    | office_locations | đọc           | đọc       | đọc      | đọc     | đọc+ghi
--    | work_shifts      | đọc           | đọc       | đọc      | đọc     | đọc+ghi
--    | attendance_logs  | của mình, đọc | phòng, đọc| đọc+duyệt| đọc     | đọc+ghi
--    | attendance_days  | của mình, đọc | phòng, đọc| đọc+ghi  | đọc     | đọc+ghi
--
--    Không bảng nào có policy DELETE — log chấm công là bằng chứng công.
--    Nhân viên không có policy INSERT trên attendance_logs — chỉ Edge
--    Function được ghi.
-- =========================================================

alter table public.office_locations enable row level security;
alter table public.office_locations force  row level security;
alter table public.work_shifts      enable row level security;
alter table public.work_shifts      force  row level security;
alter table public.attendance_logs  enable row level security;
alter table public.attendance_logs  force  row level security;
alter table public.attendance_days  enable row level security;
alter table public.attendance_days  force  row level security;

-- ---- office_locations: ai đăng nhập cũng đọc, chỉ admin sửa ----
-- Nhân viên cần đọc để app biết vẽ vòng tròn "bạn đang ở đâu so với công ty".
create policy "office_locations_select_authenticated"
  on public.office_locations for select
  to authenticated
  using ((select public.current_app_role()) is not null);

create policy "office_locations_insert_admin"
  on public.office_locations for insert
  to authenticated
  with check ((select public.current_app_role()) = 'admin');

create policy "office_locations_update_admin"
  on public.office_locations for update
  to authenticated
  using ((select public.current_app_role()) = 'admin')
  with check ((select public.current_app_role()) = 'admin');

-- ---- work_shifts ----
create policy "work_shifts_select_authenticated"
  on public.work_shifts for select
  to authenticated
  using ((select public.current_app_role()) is not null);

create policy "work_shifts_insert_admin"
  on public.work_shifts for insert
  to authenticated
  with check ((select public.current_app_role()) = 'admin');

create policy "work_shifts_update_admin"
  on public.work_shifts for update
  to authenticated
  using ((select public.current_app_role()) = 'admin')
  with check ((select public.current_app_role()) = 'admin');

-- ---- attendance_logs ----
create policy "attendance_logs_select"
  on public.attendance_logs for select
  to authenticated
  using ((select public.can_read_attendance_of(employee_id)));

-- KHÔNG có policy INSERT cho authenticated. Đây là chủ ý, không phải bỏ sót:
-- client tự insert thì tự đặt được logged_at và is_valid.

-- Chỉ HR/admin được duyệt. Cột nào được sửa thì do GRANT cấp cột quyết định
-- ở mục 10 — RLS chỉ quyết được AI, không quyết được CỘT NÀO.
create policy "attendance_logs_update_duyet_hr_admin"
  on public.attendance_logs for update
  to authenticated
  using ((select public.can_manage_attendance()))
  with check ((select public.can_manage_attendance()));

-- ---- attendance_days ----
create policy "attendance_days_select"
  on public.attendance_days for select
  to authenticated
  using ((select public.can_read_attendance_of(employee_id)));

create policy "attendance_days_insert_hr_admin"
  on public.attendance_days for insert
  to authenticated
  with check ((select public.can_manage_attendance()));

create policy "attendance_days_update_hr_admin"
  on public.attendance_days for update
  to authenticated
  using ((select public.can_manage_attendance()))
  with check ((select public.can_manage_attendance()));

-- =========================================================
-- 10. Quyền bảng
--
--    Bài học P1 (NHAT-KY.md 10/08): `grant` KHÔNG thu hồi quyền đã có.
--    Migration 20260810000001 đã sửa default privileges nên bảng mới không
--    còn tự động nhận DELETE/TRUNCATE, nhưng vẫn revoke tường minh ở đây —
--    để người đọc file này thấy được ý định, và để đúng kể cả khi ai đó chạy
--    migration lệch thứ tự.
-- =========================================================
revoke all on public.office_locations from anon;
revoke all on public.work_shifts      from anon;
revoke all on public.attendance_logs  from anon;
revoke all on public.attendance_days  from anon;

grant select, insert, update on public.office_locations to authenticated;
grant select, insert, update on public.work_shifts      to authenticated;
grant select, insert, update on public.attendance_days  to authenticated;

-- attendance_logs: KHÔNG cấp insert. Chỉ Edge Function (service_role) ghi được.
grant select on public.attendance_logs to authenticated;

-- GRANT CẤP CỘT — chỗ duy nhất trong dự án dùng kỹ thuật này, và cần nói rõ
-- vì sao nó hợp lệ ở đây trong khi P1 đã kết luận là không dùng được.
--
-- P1 muốn "trưởng phòng không xem được CCCD" — đó là luật theo VAI TRÒ, mà
-- mọi vai trò nghiệp vụ đều đăng nhập chung role `authenticated` nên grant
-- cấp cột không phân biệt được. Phải tách bảng employee_sensitive.
--
-- Ở đây luật là "KHÔNG AI được sửa toạ độ và giờ đã chấm, kể cả HR" — không
-- phụ thuộc vai trò, nên grant cấp cột diễn đạt được chính xác. RLS quyết
-- AI được update (chỉ HR/admin), grant cấp cột quyết CỘT NÀO (chỉ 4 cột
-- duyệt). Hai lớp bổ sung nhau.
--
-- Sửa được toạ độ hay giờ thì log không còn là bằng chứng nữa.
grant update (is_valid, ly_do_khong_hop_le, duyet_boi, duyet_luc, ghi_chu_duyet)
  on public.attendance_logs to authenticated;

revoke delete, truncate on public.office_locations from authenticated;
revoke delete, truncate on public.work_shifts      from authenticated;
revoke delete, truncate on public.attendance_logs  from authenticated;
revoke delete, truncate on public.attendance_days  from authenticated;
