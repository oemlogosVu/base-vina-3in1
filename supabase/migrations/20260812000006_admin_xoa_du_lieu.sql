-- =========================================================
-- Admin được xoá dữ liệu
--
-- Yêu cầu 12/08/2026 của Triệu Vũ, đã chốt phạm vi:
--   - Xoá được: danh mục tổ chức, hồ sơ nhân sự, lần chấm công
--   - KHÔNG xoá được: bảng lương, kỳ lương, tham số lương, tài khoản
--   - Dữ liệu nghiệp vụ xoá MỀM (khôi phục được); danh mục xoá CỨNG
--
-- HAI KIỂU XOÁ, VÀ VÌ SAO KHÔNG DÙNG MỘT KIỂU CHO TẤT CẢ:
--
--   Danh mục (phòng ban, chức danh, ca, công ty, loại phụ cấp) → XOÁ CỨNG.
--   Không có gì để mất: nếu còn ai tham chiếu thì khoá ngoại chặn, nếu không
--   còn ai thì dòng đó là rác. Xoá mềm danh mục chỉ tạo ra một danh sách dài
--   dần những thứ không ai dùng.
--
--   Hồ sơ nhân sự và lần chấm công → XOÁ MỀM. Chúng là căn cứ của những con
--   số đã tính. Xoá cứng một hồ sơ là mất luôn lời giải thích cho bảng lương
--   của người đó, và không có đường lùi khi bấm nhầm.
--
-- BẢNG LƯƠNG KHÔNG XOÁ ĐƯỢC, kể cả admin. Luật Kế toán 88/2015 buộc lưu
-- chứng từ dùng để ghi sổ tối thiểu 10 năm. Đây không phải lựa chọn kỹ thuật.
-- =========================================================

-- ---------------------------------------------------------
-- 1. Cột dấu vết xoá mềm
--
--    Ba cột chứ không phải một cờ boolean: "đã xoá" mà không biết AI xoá và
--    LÚC NÀO thì đến lúc cãi nhau không có gì để tra.
-- ---------------------------------------------------------
alter table public.employees
  add column deleted_at timestamptz,
  add column deleted_by uuid references public.app_users (id),
  add column ly_do_xoa  text;

alter table public.attendance_logs
  add column deleted_at timestamptz,
  add column deleted_by uuid references public.app_users (id),
  add column ly_do_xoa  text;

comment on column public.employees.deleted_at is
  'Xoá mềm. Dòng vẫn còn để bảng lương cũ giải thích được; RLS ẩn khỏi mọi truy vấn thường.';

-- Chỉ đánh index phần đã xoá — phần chưa xoá là đại đa số và đã có index khác.
create index idx_employees_da_xoa        on public.employees (deleted_at)        where deleted_at is not null;
create index idx_attendance_logs_da_xoa  on public.attendance_logs (deleted_at)  where deleted_at is not null;

-- LƯU Ý về employee_code: ràng buộc duy nhất vẫn tính cả dòng đã xoá, nên mã
-- của người đã xoá KHÔNG dùng lại được. Cố ý: mã nhân viên xuất hiện trên
-- bảng lương và hợp đồng đã in: dùng lại cho người khác là tạo ra hai người
-- cùng mã trong hồ sơ giấy.

-- ---------------------------------------------------------
-- 2. Ẩn dòng đã xoá — bằng policy RESTRICTIVE
--
--    Policy thường (permissive) được OR với nhau, nên thêm một cái nữa không
--    bao giờ SIẾT được quyền. Policy RESTRICTIVE thì AND vào tất cả. Nhờ vậy
--    ba policy select của employees đã viết và đã kiểm kỹ ở P1 giữ nguyên
--    không sửa một chữ, mà vẫn không ai đọc được dòng đã xoá.
--
--    Ẩn với TẤT CẢ, kể cả admin. Admin xem thùng rác qua RPC riêng bên dưới.
--    Nếu để admin thấy dòng đã xoá lẫn trong danh sách thường thì màn nhân sự
--    hiện cả người đã nghỉ việc đã xoá — đúng thứ vừa bấm xoá để khỏi thấy.
-- ---------------------------------------------------------
create policy "employees_an_dong_da_xoa"
  on public.employees as restrictive
  for all to authenticated
  using (deleted_at is null);

create policy "attendance_logs_an_dong_da_xoa"
  on public.attendance_logs as restrictive
  for all to authenticated
  using (deleted_at is null);

-- ---------------------------------------------------------
-- 3. Xoá CỨNG danh mục — chỉ admin
--
--    Không cần tự đi đếm xem còn ai tham chiếu: mọi khoá ngoại trỏ vào các
--    bảng này đều là NO ACTION (đã kiểm 12/08), nên Postgres tự chặn và trả
--    lỗi 23503. Tự đếm bằng tay là tạo ra một bản sao của luật khoá ngoại,
--    và bản sao sẽ lệch.
--
--    Ngoại lệ đã biết: xoá một chức danh sẽ CASCADE xoá luôn các dòng phụ cấp
--    theo chức danh đó. Đúng ý — chúng là cấu hình của riêng chức danh ấy.
-- ---------------------------------------------------------
create policy "departments_delete_admin"     on public.departments     for delete to authenticated using ((select public.current_app_role()) = 'admin');
create policy "positions_delete_admin"       on public.positions       for delete to authenticated using ((select public.current_app_role()) = 'admin');
create policy "work_shifts_delete_admin"     on public.work_shifts     for delete to authenticated using ((select public.current_app_role()) = 'admin');
create policy "companies_delete_admin"       on public.companies       for delete to authenticated using ((select public.current_app_role()) = 'admin');
create policy "allowance_types_delete_admin" on public.allowance_types for delete to authenticated using ((select public.current_app_role()) = 'admin');

grant delete on public.departments     to authenticated;
grant delete on public.positions       to authenticated;
grant delete on public.work_shifts     to authenticated;
grant delete on public.companies       to authenticated;
grant delete on public.allowance_types to authenticated;

-- ---------------------------------------------------------
-- 4. Xoá MỀM hồ sơ nhân sự
--
--    Qua RPC chứ không qua UPDATE thường, vì một lần xoá phải làm ba việc
--    cùng lúc và không được làm nửa vời:
--      a. đánh dấu đã xoá + ghi ai xoá + lý do
--      b. VÔ HIỆU tài khoản đăng nhập gắn với hồ sơ đó
--      c. từ chối nếu người đó đã có phiếu lương
--
--    (b) là chỗ dễ quên nhất: hồ sơ biến mất khỏi màn nhân sự nhưng tài khoản
--    vẫn đăng nhập và vẫn chấm công được thì việc "xoá" chỉ là ảo giác.
-- ---------------------------------------------------------
create or replace function public.xoa_nhan_su(p_employee_id uuid, p_ly_do text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  nv       public.employees%rowtype;
  so_phieu integer;
begin
  if (select public.current_app_role()) <> 'admin' then
    raise exception 'Chỉ admin được xoá hồ sơ nhân sự.';
  end if;

  if coalesce(btrim(p_ly_do), '') = '' then
    raise exception 'Phải ghi lý do xoá.';
  end if;

  select * into nv from public.employees where id = p_employee_id;
  if not found then
    raise exception 'Không tìm thấy hồ sơ nhân sự này.';
  end if;
  if nv.deleted_at is not null then
    raise exception 'Hồ sơ % (%) đã bị xoá trước đó rồi.', nv.full_name, nv.employee_code;
  end if;

  -- Có phiếu lương thì KHÔNG cho xoá, kể cả xoá mềm.
  --
  -- Không phải vì sợ mất dữ liệu — xoá mềm có mất gì đâu — mà vì bảng lương
  -- là chứng từ phải lưu 10 năm, và một chứng từ trỏ tới người "đã xoá" là
  -- chứng từ không tra ngược được. Muốn cho người này nghỉ thì đổi
  -- employees.status, đó mới là việc đúng.
  select count(*) into so_phieu from public.payslips where employee_id = p_employee_id;
  if so_phieu > 0 then
    raise exception
      'Không xoá được % (%): đã có % phiếu lương. Bảng lương là chứng từ kế toán phải lưu 10 năm. Muốn cho nghỉ việc thì đổi trạng thái hồ sơ.',
      nv.full_name, nv.employee_code, so_phieu;
  end if;

  update public.employees
     set deleted_at = now(),
         deleted_by = (select auth.uid()),
         ly_do_xoa  = btrim(p_ly_do)
   where id = p_employee_id;

  -- Gỡ khỏi vị trí trưởng phòng, nếu đang giữ. Để nguyên là phòng ban trỏ
  -- tới một hồ sơ không ai đọc được nữa.
  update public.departments set manager_id = null where manager_id = p_employee_id;
  update public.employees    set manager_id = null where manager_id = p_employee_id;

  -- Khoá đường đăng nhập.
  update public.app_users set is_active = false where employee_id = p_employee_id;
end;
$$;

comment on function public.xoa_nhan_su(uuid, text) is
  'Xoá mềm hồ sơ nhân sự: đánh dấu, gỡ khỏi vị trí quản lý, vô hiệu tài khoản. Từ chối nếu đã có phiếu lương.';

create or replace function public.khoi_phuc_nhan_su(p_employee_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select public.current_app_role()) <> 'admin' then
    raise exception 'Chỉ admin được khôi phục hồ sơ nhân sự.';
  end if;

  update public.employees
     set deleted_at = null, deleted_by = null, ly_do_xoa = null
   where id = p_employee_id and deleted_at is not null;

  if not found then
    raise exception 'Hồ sơ này không nằm trong thùng rác.';
  end if;

  -- CỐ Ý không tự bật lại tài khoản đăng nhập. Tài khoản có thể đã bị khoá vì
  -- lý do khác hẳn việc xoá hồ sơ; bật lại hộ là mở cửa mà không ai yêu cầu.
  -- Màn thùng rác nói rõ điều này cho người bấm.
end;
$$;

-- ---------------------------------------------------------
-- 5. Xoá MỀM một lần chấm công — và TỔNG HỢP LẠI ngày đó
--
--    Đây là chỗ nếu làm ẩu thì sai tiền: attendance_days là dữ liệu DẪN XUẤT,
--    tính từ attendance_logs. Đánh dấu xoá một lần bấm mà không tổng hợp lại
--    thì bảng công ngày đó vẫn giữ nguyên số phút cũ, và bảng lương vẫn trả
--    theo số cũ. Người dùng thấy lần chấm biến mất và tin là đã xong.
-- ---------------------------------------------------------
create or replace function public.xoa_cham_cong(p_log_id uuid, p_ly_do text)
returns date
language plpgsql
security definer
set search_path = ''
as $$
declare
  ngay date;
begin
  if (select public.current_app_role()) <> 'admin' then
    raise exception 'Chỉ admin được xoá lần chấm công.';
  end if;

  update public.attendance_logs
     set deleted_at = now(),
         deleted_by = (select auth.uid()),
         ly_do_xoa  = nullif(btrim(coalesce(p_ly_do, '')), '')
   where id = p_log_id and deleted_at is null
  returning (logged_at at time zone 'Asia/Ho_Chi_Minh')::date into ngay;

  if ngay is null then
    raise exception 'Không tìm thấy lần chấm công này, hoặc nó đã bị xoá rồi.';
  end if;

  perform public.tong_hop_cong_ngay(ngay);
  return ngay;
end;
$$;

create or replace function public.khoi_phuc_cham_cong(p_log_id uuid)
returns date
language plpgsql
security definer
set search_path = ''
as $$
declare
  ngay date;
begin
  if (select public.current_app_role()) <> 'admin' then
    raise exception 'Chỉ admin được khôi phục lần chấm công.';
  end if;

  update public.attendance_logs
     set deleted_at = null, deleted_by = null, ly_do_xoa = null
   where id = p_log_id and deleted_at is not null
  returning (logged_at at time zone 'Asia/Ho_Chi_Minh')::date into ngay;

  if ngay is null then
    raise exception 'Lần chấm công này không nằm trong thùng rác.';
  end if;

  perform public.tong_hop_cong_ngay(ngay);
  return ngay;
end;
$$;

-- ---------------------------------------------------------
-- 6. Tổng hợp công: bỏ qua lần chấm đã xoá, VÀ dọn ngày công thừa
--
--    Bản cũ chỉ có INSERT ... ON CONFLICT UPDATE. Nó không bao giờ xoá dòng
--    nào, nên khi mọi lần chấm của một người trong ngày đều bị xoá, dòng
--    attendance_days cũ vẫn nằm đó với số phút của lần chấm đã biến mất.
--    Thêm bước dọn ở đầu là thứ làm cho việc xoá có tác dụng thật lên lương.
-- ---------------------------------------------------------
create or replace function public.tong_hop_cong_ngay(p_ngay date)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  so_dong integer;
  ca      public.work_shifts%rowtype;
begin
  select * into ca from public.work_shifts where is_active order by code limit 1;
  if not found then
    raise exception 'Chưa khai báo ca làm việc nào — không tổng hợp công được.';
  end if;

  -- Dọn trước: ai không còn lần chấm hợp lệ nào trong ngày thì không có ngày
  -- công. attendance_days là dữ liệu dẫn xuất nên xoá ở đây không mất gì —
  -- chạy lại hàm này là dựng lại được từ attendance_logs.
  delete from public.attendance_days d
  where d.work_date = p_ngay
    and not exists (
      select 1 from public.attendance_logs l
      where l.employee_id = d.employee_id
        and l.da_xac_nhan
        and l.deleted_at is null
        and (l.logged_at at time zone 'Asia/Ho_Chi_Minh')::date = p_ngay
    );

  with gom as (
    select
      l.employee_id,
      min(l.logged_at) filter (where l.check_type = 'in')     as first_in,
      max(l.logged_at) filter (where l.check_type = 'out')    as last_out,
      min(l.logged_at) filter (where l.check_type = 'ot_in')  as ot_in,
      max(l.logged_at) filter (where l.check_type = 'ot_out') as ot_out
    from public.attendance_logs l
    where l.da_xac_nhan
      and l.deleted_at is null
      and (l.logged_at at time zone 'Asia/Ho_Chi_Minh')::date = p_ngay
    group by l.employee_id
  )
  insert into public.attendance_days as d (
    employee_id, work_date, shift_id, first_in, last_out,
    ot_first_in, ot_last_out,
    worked_minutes, ot_minutes, late_minutes, early_leave_minutes,
    status, tong_hop_luc
  )
  select
    g.employee_id, p_ngay, ca.id, g.first_in, g.last_out,
    g.ot_in, g.ot_out,
    c.worked_minutes, c.ot_minutes, c.late_minutes, c.early_leave_minutes,
    c.status, now()
  from gom g
  cross join lateral public.tinh_cong_mot_ngay(
    p_ngay, g.first_in, g.last_out, g.ot_in, g.ot_out,
    ca.start_time, ca.end_time, ca.break_start, ca.break_end
  ) c
  on conflict (employee_id, work_date) do update set
    shift_id            = excluded.shift_id,
    first_in            = excluded.first_in,
    last_out            = excluded.last_out,
    ot_first_in         = excluded.ot_first_in,
    ot_last_out         = excluded.ot_last_out,
    worked_minutes      = excluded.worked_minutes,
    ot_minutes          = excluded.ot_minutes,
    late_minutes        = excluded.late_minutes,
    early_leave_minutes = excluded.early_leave_minutes,
    status              = excluded.status,
    tong_hop_luc        = excluded.tong_hop_luc;

  get diagnostics so_dong = row_count;
  return so_dong;
end;
$$;

-- ---------------------------------------------------------
-- 7. Thùng rác — chỉ admin đọc được
--
--    Qua RPC vì policy RESTRICTIVE ở mục 2 ẩn dòng đã xoá với mọi truy vấn
--    thường, kể cả của admin. Đó là chủ ý: chỉ có đúng một đường vào xem dữ
--    liệu đã xoá, và đường đó tự kiểm quyền.
-- ---------------------------------------------------------
create or replace function public.thung_rac_nhan_su()
returns table (
  id uuid, employee_code text, full_name text,
  deleted_at timestamptz, ly_do_xoa text, nguoi_xoa text
)
language sql
security definer
set search_path = ''
as $$
  select e.id, e.employee_code, e.full_name, e.deleted_at, e.ly_do_xoa, u.full_name
  from public.employees e
  left join public.app_users u on u.id = e.deleted_by
  where e.deleted_at is not null
    and (select public.current_app_role()) = 'admin'
  order by e.deleted_at desc;
$$;

create or replace function public.thung_rac_cham_cong()
returns table (
  id uuid, employee_code text, full_name text, check_type public.check_type,
  logged_at timestamptz, deleted_at timestamptz, ly_do_xoa text, nguoi_xoa text
)
language sql
security definer
set search_path = ''
as $$
  select l.id, e.employee_code, e.full_name, l.check_type, l.logged_at,
         l.deleted_at, l.ly_do_xoa, u.full_name
  from public.attendance_logs l
  join public.employees e on e.id = l.employee_id
  left join public.app_users u on u.id = l.deleted_by
  where l.deleted_at is not null
    and (select public.current_app_role()) = 'admin'
  order by l.deleted_at desc;
$$;

-- Hàm SECURITY DEFINER phải khoá lại rồi mở đúng cho authenticated. Để
-- `public` là mở cho cả vai trò anon chưa đăng nhập.
revoke execute on function public.xoa_nhan_su(uuid, text)      from public, anon;
revoke execute on function public.khoi_phuc_nhan_su(uuid)      from public, anon;
revoke execute on function public.xoa_cham_cong(uuid, text)    from public, anon;
revoke execute on function public.khoi_phuc_cham_cong(uuid)    from public, anon;
revoke execute on function public.thung_rac_nhan_su()          from public, anon;
revoke execute on function public.thung_rac_cham_cong()        from public, anon;

grant execute on function public.xoa_nhan_su(uuid, text)   to authenticated;
grant execute on function public.khoi_phuc_nhan_su(uuid)   to authenticated;
grant execute on function public.xoa_cham_cong(uuid, text) to authenticated;
grant execute on function public.khoi_phuc_cham_cong(uuid) to authenticated;
grant execute on function public.thung_rac_nhan_su()       to authenticated;
grant execute on function public.thung_rac_cham_cong()     to authenticated;

-- tong_hop_cong_ngay vẫn KHÔNG mở cho ai gọi trực tiếp — chỉ pg_cron và các
-- hàm ở trên gọi nó.
revoke execute on function public.tong_hop_cong_ngay(date) from public, anon, authenticated;
