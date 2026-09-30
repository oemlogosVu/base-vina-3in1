-- =========================================================
-- P0d — Quyền đi theo Ô TICK TAB, khai cho từng người
--
-- Triệu Vũ, 24/08/2026: "Cần điều chỉnh để admin quyết định ai được xem những
-- tab nào, bỏ luôn phân quyền, vì nếu không xem được tab sẽ không thao tác
-- được trên đó."
--
-- MỘT CÂU SAI, VÀ ĐÂY LÀ BẢN SỬA CHO NÓ THÀNH ĐÚNG
--
-- "Không xem được tab thì không thao tác được" — hôm nay KHÔNG đúng. Ẩn tab
-- chỉ giấu lối đi; lớp chặn thật là RLS, và RLS đọc `quyen`. Ai gọi thẳng
-- PostgREST vẫn làm được đúng những gì quyền cho phép, dù tab đã tắt.
--
-- Nên bản này KHÔNG bỏ phân quyền — bỏ thì sáu hàm gác cửa chỉ còn admin và
-- người đang làm việc thật mất sạch. Bản này làm cho câu ấy THÀNH ĐÚNG: ô tick
-- tab vừa mở màn hình, vừa CẤP quyền tương ứng ở database. Một ô tick, một
-- hệ quả, không còn hai thứ lệch nhau.
--
--   Tick "Nhân sự"            → quan_ly_nhan_su
--   Tick "Kỳ lương"           → tinh_luong
--   Tick "Báo cáo lương"      → xem_luong
--   Tick "Xác nhận chấm công" → xac_nhan_cham_cong
--   Tick "Duyệt công tổ đội"  → duyet_cong        (ô riêng, xem mục 1)
--
-- VÌ SAO `duyet_cong` PHẢI CÓ Ô RIÊNG
--
-- Tab "Quản lý tổ đội" mở cho MỌI vai trò — người chấm công thường là tổ
-- trưởng, tài khoản `nhan_vien`. Nếu tick tab ấy là cấp luôn quyền duyệt thì
-- mọi người chấm công thành người duyệt công. Duyệt là việc hẹp hơn hẳn việc
-- vào màn, nên nó giữ ô riêng.
--
-- TÁCH `tinh_luong` VÀ `xem_luong`
--
-- Trước bản này hai tab Kỳ lương và Báo cáo lương cùng đòi `tinh_luong`, nghĩa
-- là ai được xem báo cáo cũng CHỐT được kỳ lương — một hành động một chiều.
-- Muốn "một tab một quyền" thì phải tách, nếu không ô tick lại hứa một đằng
-- làm một nẻo.
-- =========================================================

-- ---------------------------------------------------------
-- 1. Ô "Duyệt công tổ đội" — cờ riêng trên tài khoản
--
--    Cùng hình dạng với `quan_ly_to_doi` đã có sẵn: một việc hẹp, khai thẳng
--    trên tài khoản, không mượn đường vòng qua chức danh.
-- ---------------------------------------------------------
alter table public.app_users
  add column duyet_cong boolean not null default false;

comment on column public.app_users.duyet_cong is
  'Người này được DUYỆT công tổ đội. Ô riêng vì tab "Quản lý tổ đội" mở cho mọi vai trò, còn duyệt thì không.';

-- Giữ nguyên quyền của người đang làm việc thật. Chạy TRƯỚC khi cột `quyen`
-- sinh ra và trước khi bỏ `positions.quyen` — đảo thứ tự là mất dữ liệu.
update public.app_users u
set duyet_cong = true
where exists (
  select 1
  from public.nhan_vien_chuc_danh nc
  join public.positions p on p.id = nc.position_id
  where nc.employee_id = u.employee_id
    and p.is_active
    and nc.tu_ngay <= current_date
    and (nc.den_ngay is null or nc.den_ngay >= current_date)
    and 'duyet_cong' = any (p.quyen)
);

-- ---------------------------------------------------------
-- 2. Bảng ánh xạ tab → quyền, viết ĐÚNG MỘT LẦN
--
--    `immutable` vì cột sinh ở mục 3 đòi thế, và nó immutable thật: đầu vào
--    nào ra kết quả ấy, không đọc bảng nào.
--
--    ⚠️ ĐỔI ÁNH XẠ NÀY THÌ PHẢI DROP RỒI TẠO LẠI CỘT `quyen`. Postgres không
--    tự tính lại cột sinh khi thân hàm đổi — giá trị cũ nằm nguyên đó và
--    không ai biết. Phép kiểm cấu trúc p0 số 30 canh đúng chuyện này: nó so
--    giá trị đang lưu với giá trị tính lại, từng dòng.
-- ---------------------------------------------------------
create or replace function public.quyen_tu_tab(p_tabs text[], p_duyet_cong boolean)
returns text[]
language sql
immutable
set search_path = ''
as $$
  select coalesce(
    (
      select array_agg(q order by q)
      from (
        select unnest(array[
          case when 'nhan-su'            = any (coalesce(p_tabs, '{}')) then 'quan_ly_nhan_su' end,
          case when 'luong-ky-luong'     = any (coalesce(p_tabs, '{}')) then 'tinh_luong' end,
          case when 'luong-bao-cao'      = any (coalesce(p_tabs, '{}')) then 'xem_luong' end,
          case when 'cham-cong-xac-nhan' = any (coalesce(p_tabs, '{}')) then 'xac_nhan_cham_cong' end,
          case when coalesce(p_duyet_cong, false)                       then 'duyet_cong' end
        ]) as q
      ) t
      where q is not null
    ),
    '{}'::text[]
  );
$$;

comment on function public.quyen_tu_tab(text[], boolean) is
  'Ánh xạ ô tick tab → quyền. NGUỒN DUY NHẤT. Đổi ở đây thì phải drop và tạo lại cột app_users.quyen — Postgres không tự tính lại cột sinh.';

-- ---------------------------------------------------------
-- 3. Cột `quyen` là CỘT SINH, không phải cột thường
--
--    Không ai ghi thẳng vào nó được, kể cả admin, kể cả service_role. Nó luôn
--    bằng đúng ánh xạ của `tabs` + `duyet_cong`.
--
--    Đây là điểm khác hẳn cách làm cũ: trước kia tab và quyền là hai thứ khai
--    riêng, và hai thứ khai riêng thì có ngày lệch nhau — đúng cái vừa xảy ra
--    sáng nay với tab Nhân sự của Trần Thu Hà. Cột sinh làm cho lệch nhau trở
--    thành chuyện không xảy ra được, chứ không phải chuyện phải nhớ tránh.
--
--    `tabs IS NULL` (chưa khai) ⇒ không quyền gì. Đúng: quyền phải là lời
--    khẳng định có chủ ý của admin, không phải thứ rơi vào ai đó theo mặc định.
-- ---------------------------------------------------------
alter table public.app_users
  add column quyen text[]
  generated always as (public.quyen_tu_tab(tabs, duyet_cong)) stored;

comment on column public.app_users.quyen is
  'CỘT SINH từ tabs + duyet_cong qua quyen_tu_tab(). Không ghi thẳng được. RLS đọc cột này — nó là quyền thật, còn tabs là lời khai ra nó.';

create index idx_app_users_quyen on public.app_users using gin (quyen);

-- ---------------------------------------------------------
-- 4. Hai hàm hỏi quyền, thay cho `co_quyen_chuc_danh*`
--
--    Tên cũ nay là một lời nói dối: quyền không còn đi theo chức danh.
-- ---------------------------------------------------------
create or replace function public.co_quyen_cua(p_user_id uuid, p_quyen text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.app_users u
    where u.id = p_user_id
      and u.is_active
      and p_quyen = any (coalesce(u.quyen, '{}'))
  );
$$;

revoke execute on function public.co_quyen_cua(uuid, text) from public, anon;
grant  execute on function public.co_quyen_cua(uuid, text) to authenticated;

create or replace function public.co_quyen(p_quyen text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.co_quyen_cua((select auth.uid()), p_quyen);
$$;

comment on function public.co_quyen(text) is
  'Người đang đăng nhập có quyền này không. Quyền sinh ra từ ô tick tab tại Quản trị → Người dùng (P0d, 24/08/2026).';

revoke execute on function public.co_quyen(text) from public, anon;
grant  execute on function public.co_quyen(text) to authenticated;

-- ---------------------------------------------------------
-- 5. Sáu cửa gác đổi nguồn đọc quyền
--
--    Thân hàm chép từ `pg_get_functiondef()` của bản ĐANG CHẠY rồi đổi đúng
--    lời gọi — bài học 24/08 với `them_nhan_cong_to`: tên file migration nói
--    hàm ấy RA ĐỜI ở đâu, không nói nó ĐANG là gì.
-- ---------------------------------------------------------
create or replace function public.is_hr_or_admin()
returns boolean language sql stable security definer set search_path = ''
as $$
  select public.current_app_role() = 'admin'
      or public.co_quyen('quan_ly_nhan_su');
$$;

-- Đọc DANH SÁCH nhân sự rộng hơn SỬA hồ sơ, và cố ý:
--   • Xác nhận chấm công phải biết đang xác nhận cho ai.
--   • Tính lương và xem báo cáo lương cũng vậy.
-- Ba quyền ấy cho ĐỌC, chỉ `quan_ly_nhan_su` mới cho SỬA (is_hr_or_admin).
create or replace function public.can_read_all_employees()
returns boolean language sql stable security definer set search_path = ''
as $$
  select public.current_app_role() = 'admin'
      or public.co_quyen('quan_ly_nhan_su')
      or public.co_quyen('tinh_luong')
      or public.co_quyen('xem_luong')
      or public.co_quyen('xac_nhan_cham_cong');
$$;

create or replace function public.can_read_payroll()
returns boolean language sql stable security definer set search_path = ''
as $$
  select public.current_app_role() = 'admin'
      or public.co_quyen('tinh_luong')
      or public.co_quyen('xem_luong');
$$;

-- CHỐT kỳ lương là một chiều, nên nó đòi `tinh_luong` chứ không nhận
-- `xem_luong`. Đây chính là lý do phải tách hai quyền.
create or replace function public.can_manage_payroll()
returns boolean language sql stable security definer set search_path = ''
as $$
  select public.current_app_role() = 'admin'
      or public.co_quyen('tinh_luong');
$$;

create or replace function public.can_manage_attendance()
returns boolean language sql stable security definer set search_path = ''
as $$
  select public.current_app_role() = 'admin'
      or public.co_quyen('xac_nhan_cham_cong');
$$;

create or replace function public.duoc_duyet_cong_to()
returns boolean language sql stable security definer set search_path = ''
as $$
  select public.current_app_role() in ('truong_phong', 'admin')
      or public.co_quyen('duyet_cong');
$$;

create or replace function public.duoc_ghi_anh_phien(p_phien_id uuid, p_user_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1
    from public.phien_cham_cong_to p
    join public.to_doi t on t.id = p.to_doi_id
    where p.id = p_phien_id
      and t.is_active
      and (
        exists (
          select 1 from public.app_users u
          where u.id = p_user_id and u.is_active and u.role = 'admin'
        )
        or public.co_quyen_cua(p_user_id, 'xac_nhan_cham_cong')
        or (
          exists (
            select 1 from public.to_doi_nguoi_cham g
            where g.to_doi_id = t.id and g.app_user_id = p_user_id
          )
          and public.la_nhan_vien_chinh_thuc(p_user_id)
        )
      )
  );
$$;

-- ---------------------------------------------------------
-- 6. Gỡ đường cũ
--
--    Xoá chứ không để lại. Một cơ chế không ai đọc là một cơ chế người sau sẽ
--    đọc nhầm — đúng lý do đã dùng sáng nay khi bỏ `positions.tabs`.
-- ---------------------------------------------------------
drop function if exists public.co_quyen_chuc_danh(text);
drop function if exists public.co_quyen_chuc_danh_cua(uuid, text);

alter table public.positions drop column quyen;

-- ---------------------------------------------------------
-- 7. Người dùng KHÔNG tự đổi ô tick của mình
--
--    Cột sinh không nằm trong quyền cấp cột được, nên `quyen` tự nó đã an
--    toàn. Nhưng `duyet_cong` là cột thường: không ghim thì mọi tài khoản tự
--    cấp cho mình quyền duyệt công. Ghim đúng cách `tabs` đã ghim ở P0c.
-- ---------------------------------------------------------
drop policy "app_users_update_self_name" on public.app_users;

create policy "app_users_update_self_name"
  on public.app_users for update
  to authenticated
  using (id = (select auth.uid()))
  with check (
    id = (select auth.uid())
    and role      = (select t.role      from public.tai_khoan_cua_toi() t)
    and is_active = (select t.is_active from public.tai_khoan_cua_toi() t)
    and employee_id is not distinct from
        (select t.employee_id from public.tai_khoan_cua_toi() t)
    and tabs is not distinct from
        (select t.tabs from public.tai_khoan_cua_toi() t)
    and duyet_cong = (select t.duyet_cong from public.tai_khoan_cua_toi() t)
  );

comment on policy "app_users_update_self_name" on public.app_users is
  'Người dùng tự sửa TÊN của mình. Vai trò, kích hoạt, hồ sơ nhân sự, danh sách tab và ô duyệt công phải giữ nguyên — so với giá trị cũ qua tai_khoan_cua_toi() để policy không đọc thẳng bảng nó đang bảo vệ.';

grant select (duyet_cong, quyen) on public.app_users to authenticated;
grant update (duyet_cong)        on public.app_users to authenticated;
