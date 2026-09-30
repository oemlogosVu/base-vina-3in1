-- =========================================================
-- P5c — Người quản lý tổ tự lập tổ và thêm nhân công
--
-- Yêu cầu Triệu Vũ 19/08/2026, sau khi thử trên app và bị kẹt: tổ "TN-01 Đội
-- Hùng" tạo xong nhưng không giao được người chấm, vì chưa tài khoản nào nối
-- với hồ sơ nhân sự. Người ở công trường phải chờ admin cho từng thao tác.
--
-- Bốn quyết định:
--   1. Cờ `quan_ly_to_doi` trên tài khoản — admin bật MỘT LẦN, người đó tự lập
--      tổ và thêm nhân công. Giải luôn bài toán con gà quả trứng: "người chấm
--      công" là quan hệ với MỘT tổ, nên chưa có tổ thì chưa ai là người chấm.
--   2. Mỗi người một kiểu tính: theo NGÀY (0/0,5/1 công) hoặc theo GIỜ.
--   3. Ô giờ ngoài giờ cho MỌI người trong tổ, kể cả người khoán ngày.
--   4. Người quản lý tổ nhập được CCCD, nhưng CHỈ của người trong tổ mình.
--
-- VÌ SAO GHI QUA HÀM CHỨ KHÔNG NỚI POLICY: thêm một nhân công là ba lần ghi
-- vào ba bảng (hồ sơ, dữ liệu nhạy cảm, thành viên tổ). Nới policy cho cả ba
-- là mở vĩnh viễn ba cánh cửa cho vai trò thấp nhất, và mở xong thì mỗi cánh
-- tự sống đời của nó. Gói vào một hàm `security definer` có kiểm quyền ngay
-- dòng đầu thì cửa chỉ mở đúng một lối, và lối ấy đọc được từ trên xuống.
-- =========================================================

-- ---------------------------------------------------------
-- 1. Cờ quản lý tổ đội
-- ---------------------------------------------------------
alter table public.app_users
  add column quan_ly_to_doi boolean not null default false;

comment on column public.app_users.quan_ly_to_doi is
  'Được tự lập tổ đội công nhật và thêm nhân công. Admin bật; vẫn phải là nhân viên chính thức đang đóng bảo hiểm mới có tác dụng.';

-- ---------------------------------------------------------
-- 2. Chức danh công nhật
--
--    Đánh dấu bằng CỜ chứ không dò theo tên: dò theo tên thì đổi tên chức danh
--    một cái là biểu mẫu thêm nhân công hỏng mà không ai hiểu vì sao.
--
--    Chỉ được MỘT chức danh mang cờ này — hai cái thì "mặc định" hết nghĩa.
-- ---------------------------------------------------------
alter table public.positions
  add column la_cong_nhat boolean not null default false;

create unique index uniq_chuc_danh_cong_nhat
  on public.positions (la_cong_nhat) where la_cong_nhat;

comment on column public.positions.la_cong_nhat is
  'Chức danh mặc định khi thêm nhân công công nhật. Tối đa một chức danh mang cờ này.';

-- Đánh dấu chức danh đã có sẵn tên "Công nhật" (Triệu Vũ tạo 19/08 khi thử
-- app). Không khớp thì không sao — admin tự tích, và biểu mẫu nói rõ phải tích.
update public.positions set la_cong_nhat = true
where name = 'Công nhật'
  and not exists (select 1 from public.positions where la_cong_nhat);

-- ---------------------------------------------------------
-- 3. Kiểu tính lương của từng người trong tổ
--
--    `don_gia` đã có từ P5b, nay mang nghĩa theo `kieu_tinh`: đồng/công hoặc
--    đồng/giờ. Một cột hai nghĩa nghe như mùi lỗi, nhưng tách thành hai cột
--    thì luôn có một cột NULL và mọi phép tính phải coalesce — đổi một chỗ
--    khó đọc lấy một chỗ dễ quên.
-- ---------------------------------------------------------
alter table public.to_doi_thanh_vien
  add column kieu_tinh  text not null default 'ngay'
    check (kieu_tinh in ('ngay', 'gio')),
  add column don_gia_ot numeric(15, 2) check (don_gia_ot >= 0);

comment on column public.to_doi_thanh_vien.kieu_tinh is
  'ngay = trả theo số công (0/0,5/1). gio = trả theo số giờ làm thực tế.';

comment on column public.to_doi_thanh_vien.don_gia is
  'Đơn giá theo kieu_tinh: đồng/công nếu tính theo ngày, đồng/giờ nếu tính theo giờ. NULL = dùng mức của chức danh.';

comment on column public.to_doi_thanh_vien.don_gia_ot is
  'Đơn giá một giờ ngoài giờ. NULL = không trả ngoài giờ; có giờ OT mà thiếu giá thì bảng thanh toán TỪ CHỐI sinh.';

-- ---------------------------------------------------------
-- 4. Chấm công: giờ làm và giờ ngoài giờ
--
--    `so_cong` thành cho phép NULL: người tính theo giờ không có khái niệm
--    số công, và nhét 0 vào đó là nói dối — 0 nghĩa là VẮNG.
-- ---------------------------------------------------------
alter table public.cham_cong_cong_nhat
  alter column so_cong drop not null;

alter table public.cham_cong_cong_nhat
  add column so_gio    numeric(6, 2) check (so_gio >= 0 and so_gio <= 24),
  add column so_gio_ot numeric(6, 2) not null default 0
    check (so_gio_ot >= 0 and so_gio_ot <= 24);

-- Đúng MỘT đơn vị cho một dòng. Không có ràng buộc này thì một dòng vừa mang
-- số công vừa mang số giờ, và bảng thanh toán cộng cả hai — trả gấp đôi.
alter table public.cham_cong_cong_nhat
  add constraint cccn_don_vi_duy_nhat check (
    (so_cong is not null and so_gio is null)
    or (so_cong is null and so_gio is not null)
  );

comment on column public.cham_cong_cong_nhat.so_gio_ot is
  'Giờ ngoài giờ, nhập được cho MỌI người trong tổ kể cả người khoán ngày — thợ khoán ngày ở lại tăng ca là chuyện thường ngoài công trường.';

grant insert (phien_id, work_date, employee_id, so_cong, so_gio, so_gio_ot, ghi_chu)
  on public.cham_cong_cong_nhat to authenticated;
grant update (so_cong, so_gio, so_gio_ot, ghi_chu)
  on public.cham_cong_cong_nhat to authenticated;

-- ---------------------------------------------------------
-- 5. Hàm nền
-- ---------------------------------------------------------
create or replace function public.cong_ty_cua_toi()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select e.company_id
  from public.employees e
  where e.id = public.current_employee_id();
$$;

comment on function public.cong_ty_cua_toi() is
  'Pháp nhân của người đang đăng nhập, suy từ hồ sơ nhân sự. NULL nếu chưa gắn hồ sơ.';

-- Được lập tổ đội. Vẫn đòi là nhân viên chính thức đang đóng bảo hiểm: người
-- lập tổ rồi cũng là người chấm công cho tổ đó, nên điều kiện phải như nhau.
create or replace function public.la_quan_ly_to_doi()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.app_users u
    where u.id = (select auth.uid())
      and u.is_active
      and u.quan_ly_to_doi
      and public.la_nhan_vien_chinh_thuc(u.id)
  );
$$;

-- Người đang đăng nhập có phụ trách tổ mà nhân sự này đang thuộc về không.
-- Dùng cho quyền đọc dữ liệu nhạy cảm của người trong tổ mình.
create or replace function public.la_nguoi_cham_cua_nhan_su(p_employee_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.to_doi_thanh_vien tv
    where tv.employee_id = p_employee_id
      and tv.den_ngay is null
      and public.la_nguoi_cham_cong_to(tv.to_doi_id)
  );
$$;

revoke execute on function public.cong_ty_cua_toi()                    from anon;
revoke execute on function public.la_quan_ly_to_doi()                  from anon;
revoke execute on function public.la_nguoi_cham_cua_nhan_su(uuid)      from anon;

-- ---------------------------------------------------------
-- 6. Lập tổ đội
--
--    Gói thành hàm vì phải làm HAI việc không tách rời: tạo tổ, và gán chính
--    người tạo làm người chấm. Thiếu việc thứ hai thì họ lập xong tổ rồi không
--    chấm được cho chính tổ mình — đúng cái bẫy đang đi gỡ.
-- ---------------------------------------------------------
create or replace function public.tao_to_doi(
  p_code          text,
  p_name          text,
  p_department_id uuid default null,
  p_ghi_chu       text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  cty uuid;
  ra  uuid;
begin
  if not (public.la_quan_ly_to_doi() or public.current_app_role() = 'admin') then
    raise exception 'Bạn chưa được cấp quyền quản lý tổ đội. Đề nghị quản trị hệ thống bật quyền này cho tài khoản của bạn.';
  end if;

  if coalesce(btrim(p_code), '') = '' then raise exception 'Thiếu mã tổ.'; end if;
  if coalesce(btrim(p_name), '') = '' then raise exception 'Thiếu tên tổ.'; end if;

  cty := public.cong_ty_cua_toi();
  if cty is null then
    raise exception 'Tài khoản của bạn chưa gắn với hồ sơ nhân sự có công ty, nên chưa biết lập tổ cho pháp nhân nào.';
  end if;

  insert into public.to_doi (code, name, company_id, department_id, ghi_chu)
  values (btrim(p_code), btrim(p_name), cty, p_department_id, p_ghi_chu)
  returning id into ra;

  -- Người lập tổ thành người chấm của tổ đó. Admin lập hộ thì cũng vậy — họ
  -- gỡ mình ra và giao người khác được ở màn quản trị.
  insert into public.to_doi_nguoi_cham (to_doi_id, app_user_id)
  values (ra, (select auth.uid()));

  return ra;
end;
$$;

revoke execute on function public.tao_to_doi(text, text, uuid, text) from anon, public;
grant  execute on function public.tao_to_doi(text, text, uuid, text) to authenticated;

-- ---------------------------------------------------------
-- 7. Thêm nhân công công nhật
--
--    Hồ sơ rút gọn theo yêu cầu: họ tên, CCCD, đơn giá, đơn giá ngoài giờ.
--    Không phòng ban, không ngày sinh, không email — người thuê theo ngày
--    không cần hồ sơ đầy đủ, và bắt nhập thứ không dùng tới chỉ tạo ra dữ
--    liệu bịa.
-- ---------------------------------------------------------
create or replace function public.them_nhan_cong_to(
  p_to_doi_id  uuid,
  p_ho_ten     text,
  p_cccd       text    default null,
  p_kieu_tinh  text    default 'ngay',
  p_don_gia    numeric default null,
  p_don_gia_ot numeric default null,
  p_tu_ngay    date    default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  chuc_danh uuid;
  cty       uuid;
  ma        text;
  nv        uuid;
begin
  if not (public.la_nguoi_cham_cong_to(p_to_doi_id) or public.is_hr_or_admin()) then
    raise exception 'Bạn không phụ trách tổ này.';
  end if;

  if coalesce(btrim(p_ho_ten), '') = '' then
    raise exception 'Thiếu họ và tên.';
  end if;
  if p_kieu_tinh not in ('ngay', 'gio') then
    raise exception 'Kiểu tính lương phải là theo ngày hoặc theo giờ.';
  end if;
  if p_don_gia is not null and p_don_gia < 0 then
    raise exception 'Đơn giá không được âm.';
  end if;
  if p_don_gia_ot is not null and p_don_gia_ot < 0 then
    raise exception 'Đơn giá ngoài giờ không được âm.';
  end if;

  select id into chuc_danh from public.positions where la_cong_nhat limit 1;
  if chuc_danh is null then
    raise exception 'Chưa đánh dấu chức danh nào là "công nhật". Vào Quản trị → Tổ đội công nhật để tích chức danh dùng cho nhân công thuê ngoài.';
  end if;

  select company_id into cty from public.to_doi where id = p_to_doi_id;

  -- Mã tự sinh CN0001, CN0002… Người thuê theo ngày không có mã do phòng nhân
  -- sự cấp, mà bảng công lại cần một mã để đối chiếu.
  select 'CN' || lpad(
           (coalesce(max(substring(e.employee_code from '^CN(\d+)$')::integer), 0) + 1)::text,
           4, '0')
    into ma
  from public.employees e
  where e.employee_code ~ '^CN\d+$';

  insert into public.employees
    (employee_code, full_name, status, company_id, position_id, theo_doi_cham_cong)
  values
    (ma, btrim(p_ho_ten), 'cong_tac_vien', cty, chuc_danh, false)
  returning id into nv;

  if coalesce(btrim(p_cccd), '') <> '' then
    insert into public.employee_sensitive (employee_id, cccd)
    values (nv, btrim(p_cccd));
  end if;

  insert into public.to_doi_thanh_vien
    (to_doi_id, employee_id, tu_ngay, kieu_tinh, don_gia, don_gia_ot)
  values
    (p_to_doi_id, nv, coalesce(p_tu_ngay, current_date), p_kieu_tinh, p_don_gia, p_don_gia_ot);

  return nv;
end;
$$;

revoke execute on function
  public.them_nhan_cong_to(uuid, text, text, text, numeric, numeric, date)
  from anon, public;
grant execute on function
  public.them_nhan_cong_to(uuid, text, text, text, numeric, numeric, date)
  to authenticated;

-- ---------------------------------------------------------
-- 8. Sửa nhân công đã thêm
--
--    Có mặt vì gõ nhầm CCCD hay đơn giá là chuyện xảy ra thật, và người ở
--    công trường phải sửa được ngay thay vì chờ HR.
-- ---------------------------------------------------------
create or replace function public.sua_nhan_cong_to(
  p_thanh_vien_id uuid,
  p_ho_ten        text    default null,
  p_cccd          text    default null,
  p_kieu_tinh     text    default null,
  p_don_gia       numeric default null,
  p_don_gia_ot    numeric default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  tv record;
begin
  select * into tv from public.to_doi_thanh_vien where id = p_thanh_vien_id;
  if not found then raise exception 'Không tìm thấy dòng thành viên.'; end if;

  if not (public.la_nguoi_cham_cong_to(tv.to_doi_id) or public.is_hr_or_admin()) then
    raise exception 'Bạn không phụ trách tổ này.';
  end if;

  if p_kieu_tinh is not null and p_kieu_tinh not in ('ngay', 'gio') then
    raise exception 'Kiểu tính lương phải là theo ngày hoặc theo giờ.';
  end if;

  if coalesce(btrim(p_ho_ten), '') <> '' then
    update public.employees set full_name = btrim(p_ho_ten) where id = tv.employee_id;
  end if;

  -- Để trống ô CCCD nghĩa là GIỮ NGUYÊN, không phải xoá. Xoá một số giấy tờ
  -- phải là hành động có chủ đích, không phải hệ quả của việc bỏ trống ô.
  if coalesce(btrim(p_cccd), '') <> '' then
    insert into public.employee_sensitive (employee_id, cccd)
    values (tv.employee_id, btrim(p_cccd))
    on conflict (employee_id) do update set cccd = excluded.cccd;
  end if;

  update public.to_doi_thanh_vien
  set kieu_tinh  = coalesce(p_kieu_tinh, kieu_tinh),
      don_gia    = coalesce(p_don_gia, don_gia),
      don_gia_ot = coalesce(p_don_gia_ot, don_gia_ot)
  where id = p_thanh_vien_id;
end;
$$;

revoke execute on function
  public.sua_nhan_cong_to(uuid, text, text, text, numeric, numeric) from anon, public;
grant execute on function
  public.sua_nhan_cong_to(uuid, text, text, text, numeric, numeric) to authenticated;

-- ---------------------------------------------------------
-- 9. RLS bổ sung
--
--    CỐ Ý KHÔNG mở policy INSERT trên `employees` và `employee_sensitive` cho
--    người quản lý tổ. Mọi lối ghi đi qua hai hàm ở mục 7 và 8 — một lối, có
--    kiểm quyền, đọc được từ trên xuống.
--
--    Mở ĐỌC dữ liệu nhạy cảm của người trong tổ mình: nhập xong mà không xem
--    lại được thì gõ nhầm CCCD cũng không tự phát hiện, và ảnh xác minh đã
--    dạy bài học đó ở P5a.
-- ---------------------------------------------------------
create policy "employee_sensitive_select_nguoi_cham_to"
  on public.employee_sensitive for select
  to authenticated
  using ((select public.la_nguoi_cham_cua_nhan_su(employee_id)));

-- Người quản lý xem được hồ sơ (tên, mã) của nhân công trong tổ mình. Không có
-- policy này thì lưới chấm công hiện ra toàn dòng trống không tên.
create policy "employees_select_nguoi_cham_to"
  on public.employees for select
  to authenticated
  using ((select public.la_nguoi_cham_cua_nhan_su(id)));

-- Thêm/bớt thành viên và sửa đơn giá trong tổ mình.
create policy "tdtv_insert_nguoi_cham"
  on public.to_doi_thanh_vien for insert
  to authenticated
  with check ((select public.la_nguoi_cham_cong_to(to_doi_id)));

create policy "tdtv_update_nguoi_cham"
  on public.to_doi_thanh_vien for update
  to authenticated
  using ((select public.la_nguoi_cham_cong_to(to_doi_id)))
  with check ((select public.la_nguoi_cham_cong_to(to_doi_id)));

-- Đổi tên tổ mình phụ trách. KHÔNG mở company_id — đổi pháp nhân của một tổ là
-- chuyển sổ sách sang doanh nghiệp khác.
create policy "to_doi_update_nguoi_cham"
  on public.to_doi for update
  to authenticated
  using ((select public.la_nguoi_cham_cong_to(id)))
  with check ((select public.la_nguoi_cham_cong_to(id)));

-- Quyền cấp cột áp lên CẢ vai trò `authenticated`, không phân biệt được admin
-- với người quản lý tổ. Nên `code` và `company_id` không cấp cho ai qua
-- PostgREST: đổi pháp nhân của một tổ là chuyển sổ sách sang doanh nghiệp
-- khác, và đổi mã là làm hỏng mọi thứ đang đối chiếu theo mã. Hai việc đó nếu
-- thật sự cần thì làm bằng script, có chủ đích và để lại vết.
--
-- Biểu mẫu quản trị hiện chỉ sửa năm cột dưới đây, nên không mất chức năng nào.
revoke update on public.to_doi from authenticated;
grant  update (name, department_id, to_truong_id, ghi_chu, is_active)
  on public.to_doi to authenticated;
