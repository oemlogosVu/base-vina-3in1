-- =========================================================
-- P1e — Quyền thứ tư gán được theo chức danh: DUYỆT CÔNG TỔ ĐỘI
--
-- Triệu Vũ, 24/08/2026: "thêm quyền duyệt công để phân thêm quyền cho các
-- chức danh".
--
-- P1d (22/08) mở ba quyền gán theo chức danh: `quan_ly_nhan_su`,
-- `tinh_luong`, `xac_nhan_cham_cong`. Cả ba đi vào năm hàm phân quyền chung.
-- Nhưng DUYỆT PHIÊN CHẤM CÔNG TỔ ĐỘI không đi qua hàm nào trong số đó — nó
-- nằm ở policy `phien_update_hr_admin`, tức đòi `is_hr_or_admin()`.
--
-- Hệ quả trước bản này: muốn một chỉ huy trưởng công trường duyệt được công
-- của tổ công nhật, phải cấp cho họ quyền `quan_ly_nhan_su` — tức MỞ TOÀN BỘ
-- hồ sơ nhân sự, hợp đồng và người phụ thuộc của cả công ty cho một việc chỉ
-- cần nhìn số công và tấm ảnh. Ngược hẳn tinh thần truy cập tối thiểu của
-- NĐ 13/2023, và ngược cả cách P1d đã cố ý tách `xac_nhan_cham_cong` ra khỏi
-- `can_read_payroll`.
--
-- Nên: quyền thứ tư, `duyet_cong`.
--
--   duyet_cong — duyệt và mở lại phiên chấm công tổ đội thuê công nhật.
--
-- KHÔNG kèm quyền ghi số công: duyệt là xác nhận số của NGƯỜI KHÁC. Người
-- chấm vẫn phải là người được giao tổ (`to_doi_nguoi_cham`), như cũ.
--
-- KHÔNG kèm quyền ghi ẢNH xác minh: `duoc_ghi_anh_phien()` cố ý không nhận
-- `duyet_cong`. Ai nộp bằng chứng thì không phải là người duyệt bằng chứng đó.
--
-- KHÔNG kèm quyền đọc lương, cùng lý do đã viết cho `xac_nhan_cham_cong`.
-- =========================================================

-- ---------------------------------------------------------
-- 1. Giá trị thứ tư cho cột quyền
--
-- Đúng như P1d đã tính trước: mảng text nên thêm quyền chỉ là đổi ràng buộc,
-- không phải đổi hình dạng bảng.
-- ---------------------------------------------------------
alter table public.positions
  drop constraint positions_quyen_hop_le;

alter table public.positions
  add constraint positions_quyen_hop_le
  check (quyen <@ array['quan_ly_nhan_su', 'tinh_luong',
                        'xac_nhan_cham_cong', 'duyet_cong']::text[]);

-- ---------------------------------------------------------
-- 2. Ai duyệt được công tổ đội — MỘT câu trả lời duy nhất
--
-- Gộp cả HR/admin vào đây thay vì để hai khái niệm song song: màn hình hỏi
-- đúng một câu, policy hỏi đúng một câu, và không có đường nào để hai bên
-- lệch nhau về sau.
--
-- `security definer` + `search_path = ''` bắt buộc, cùng lý do với mọi hàm
-- phân quyền từ P0: nó được gọi từ trong policy của bảng mà chính nó đọc.
-- ---------------------------------------------------------
create or replace function public.duoc_duyet_cong_to()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.current_app_role() in ('hr', 'admin')
      or public.co_quyen_chuc_danh('duyet_cong');
$$;

comment on function public.duoc_duyet_cong_to() is
  'Người đang đăng nhập có duyệt được phiên chấm công tổ đội không. Nguồn DUY NHẤT của luật đó — policy và giao diện đều hỏi vào đây.';

revoke all    on function public.duoc_duyet_cong_to() from public;
revoke all    on function public.duoc_duyet_cong_to() from anon;
grant execute on function public.duoc_duyet_cong_to() to authenticated;

-- ---------------------------------------------------------
-- 3. Thấy được thì mới duyệt được — nhưng CHỈ thấy đúng phần phải duyệt
--
-- Đường ngắn là cộng `duyet_cong` vào `can_read_all_employees()` như P1d đã
-- làm với ba quyền kia. ĐỪNG. Hàm ấy mở nhiều hơn tên nó nói: ngoài
-- `employees`, nó còn là điều kiện đọc của `employee_sensitive` (CCCD),
-- `labor_contracts` và `muc_luong_hop_dong` (mức lương từng người). Cấp nó cho
-- người duyệt công là đưa CCCD và bảng lương cả công ty cho một việc chỉ cần
-- nhìn số công và tấm ảnh — đúng thứ bản này ra đời để tránh.
--
-- Nên `duyet_cong` đi bằng policy RIÊNG trên đúng bốn bảng tổ đội, cộng tên và
-- mã của người TRONG tổ. Cùng cách P5c đã mở cho người chấm công (mục 9 của
-- migration ấy), chỉ khác phạm vi: người chấm thấy tổ mình, người duyệt thấy
-- mọi tổ.
--
-- Không đụng `can_read_all_employees()`, không đụng `can_read_payroll()`.
-- ---------------------------------------------------------
create or replace function public.la_nhan_cong_to_doi(p_employee_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.to_doi_thanh_vien tv
    where tv.employee_id = p_employee_id
  );
$$;

comment on function public.la_nhan_cong_to_doi(uuid) is
  'Hồ sơ này có tên trong một tổ đội công nhật nào không, kể cả tổ đã kết thúc. Dùng để mở ĐỌC tên và mã cho người duyệt công — không mở hồ sơ của người ngoài tổ đội.';

revoke all    on function public.la_nhan_cong_to_doi(uuid) from public;
revoke all    on function public.la_nhan_cong_to_doi(uuid) from anon;
grant execute on function public.la_nhan_cong_to_doi(uuid) to authenticated;

create policy "to_doi_select_duyet_cong"
  on public.to_doi for select
  to authenticated
  using ((select public.duoc_duyet_cong_to()));

create policy "tdtv_select_duyet_cong"
  on public.to_doi_thanh_vien for select
  to authenticated
  using ((select public.duoc_duyet_cong_to()));

create policy "phien_select_duyet_cong"
  on public.phien_cham_cong_to for select
  to authenticated
  using ((select public.duoc_duyet_cong_to()));

create policy "cccn_select_duyet_cong"
  on public.cham_cong_cong_nhat for select
  to authenticated
  using ((select public.duoc_duyet_cong_to()));

-- Không có policy này thì lưới duyệt hiện ra toàn dòng trống không tên — đúng
-- bài học P5c đã ghi cho người chấm công.
create policy "employees_select_duyet_cong"
  on public.employees for select
  to authenticated
  using (
    (select public.duoc_duyet_cong_to())
    and (select public.la_nhan_cong_to_doi(id))
  );

-- ---------------------------------------------------------
-- 4. Policy duyệt
--
-- Policy RIÊNG chứ không sửa `phien_update_hr_admin`: hai policy UPDATE trên
-- cùng bảng là phép HOẶC, nên đường cũ của HR/admin giữ nguyên từng chữ và
-- đường mới đứng cạnh nó, đọc ra là thấy ngay ai vào bằng cửa nào.
--
-- Người chỉ có `duyet_cong` KHÔNG sửa được gì ngoài việc duyệt: quyền cấp cột
-- của P5a mục 8 đã giới hạn UPDATE của `authenticated` xuống đúng
-- (ghi_chu, da_duyet, duyet_boi, duyet_luc) — `anh_path` nằm ngoài tầm với.
-- ---------------------------------------------------------
create policy "phien_update_duyet_cong"
  on public.phien_cham_cong_to for update
  to authenticated
  using ((select public.duoc_duyet_cong_to()))
  with check ((select public.duoc_duyet_cong_to()));

-- ---------------------------------------------------------
-- 5. Không ai duyệt công của chính mình
--
-- Đây là phần quan trọng nhất của bản này, và nó KHÔNG hiện ra khi chỉ nhìn
-- màn hình.
--
-- Quyết định 22/08 (P5d) viết rõ: "tổ trưởng là chức danh ghi nhận trong tổ,
-- KHÔNG kèm quyền chấm công — trộn chúng lại là để người hưởng tiền tự khai
-- số công của chính mình." Quyền `duyet_cong` mở đúng cái cửa ấy theo lối
-- khác: gán nó cho chức danh mà tổ trưởng đang giữ là để người hưởng tiền tự
-- DUYỆT số công của chính mình. Nên luật phải nằm ở database, không nằm ở lời
-- dặn.
--
-- Trigger chứ không policy: policy trả false thì UPDATE lặng lẽ chạm 0 dòng,
-- PostgREST không báo lỗi, và màn hình sẽ nói "Đã duyệt" trong khi không có
-- gì được duyệt. Kiểu hỏng tệ nhất trong một hệ thống ra tiền. Trigger nói
-- thẳng bằng tiếng người.
--
-- Ba vế, và hai vế đầu áp cho MỌI người kể cả HR/admin:
--
--   (a) `duyet_boi` phải là chính người đang duyệt. Không có vế này thì dấu
--       vết duyệt ghi được tên người khác — bằng chứng tự khai.
--   (b) Người có tên trong tổ ngày ấy thì không duyệt công của tổ ấy.
--   (c) Không tự duyệt phiên do chính mình chấm.
--
-- Vế (c) CỐ Ý chừa HR/admin: họ chấm hộ khi tổ trưởng ốm hay mất điện thoại
-- (đường đã có từ P5a), và chặn họ ở đây là để công ty một-người-nhân-sự
-- không duyệt nổi phiên nào. Lỗ tự-duyệt của HR vẫn còn và là lỗ CŨ, không do
-- bản này mở; vá nó là quyết định về quy trình, phải hỏi người phụ trách.
--
-- `auth.uid()` NULL (service_role, SQL Editor) đi thẳng: lối thoát bằng tay
-- phải luôn còn, giống hai trigger của P0b và trigger của P1d.
-- ---------------------------------------------------------
create or replace function public.chan_tu_duyet_cong_to()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  nguoi   uuid := (select auth.uid());
  vai_tro text;
  ho_so   uuid;
begin
  -- Chỉ xét đúng hành vi DUYỆT. Mở lại (true → false) không cấp quyền cho ai,
  -- và chặn nó ở đây là khoá luôn đường sửa sai.
  if new.da_duyet is not true or old.da_duyet is true then
    return new;
  end if;

  if nguoi is null then
    return new;
  end if;

  select u.role, u.employee_id into vai_tro, ho_so
  from public.app_users u where u.id = nguoi;

  if new.duyet_boi is distinct from nguoi then
    raise exception
      'Ô "duyệt bởi" phải mang tên chính người đang duyệt. Dấu vết duyệt ghi tên người khác thì nó không còn là bằng chứng.'
      using errcode = 'insufficient_privilege';
  end if;

  if ho_so is not null and exists (
    select 1 from public.to_doi_thanh_vien tv
    where tv.to_doi_id = new.to_doi_id
      and tv.employee_id = ho_so
      and tv.tu_ngay <= new.work_date
      and (tv.den_ngay is null or tv.den_ngay >= new.work_date)
  ) then
    raise exception
      'Bạn có tên trong tổ này ngày %. Người trong tổ không duyệt công của tổ mình — đó là công của chính bạn.',
      new.work_date
      using errcode = 'insufficient_privilege';
  end if;

  if new.nguoi_cham_id = nguoi and coalesce(vai_tro, '') not in ('hr', 'admin') then
    raise exception
      'Bạn là người chấm phiên này. Duyệt phải do người khác làm — vừa khai vừa duyệt thì con số không còn ai đối chiếu.'
      using errcode = 'insufficient_privilege';
  end if;

  return new;
end;
$$;

comment on function public.chan_tu_duyet_cong_to() is
  'Không ai duyệt công của chính mình: dấu vết duyệt phải mang tên người duyệt, người trong tổ không duyệt tổ mình, và người chấm không tự duyệt phiên mình chấm (HR/admin chừa vế cuối vì họ chấm hộ).';

create trigger trg_phien_chan_tu_duyet
  before update of da_duyet on public.phien_cham_cong_to
  for each row execute function public.chan_tu_duyet_cong_to();

-- ---------------------------------------------------------
-- 6. Người duyệt phải NHÌN được ảnh xác minh
--
-- Không có mục này thì quyền `duyet_cong` là quyền bấm nút mà không xem được
-- bằng chứng — tức biến ảnh xác minh thành hình thức, đúng thứ ma trận
-- 19/08/2026 đã cân nhắc từng dòng để tránh.
--
-- Ma trận ấy giữ nguyên; bản này chỉ thêm một cửa: kế toán vẫn KHÔNG xem ảnh
-- (cần số công để thanh toán, không cần ảnh mặt), trưởng phòng vẫn KHÔNG.
--
-- GHI thì vẫn không ai ngoài Edge Function, và `duoc_ghi_anh_phien()` cố ý
-- không nhận `duyet_cong`: người duyệt tự tải ảnh rồi tự duyệt là vòng kiểm
-- soát đóng lại thành một người.
-- ---------------------------------------------------------
drop policy if exists "anh_to_doi_select" on storage.objects;

create policy "anh_to_doi_select"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'to-doi-cham-cong'
    and (
      (select public.can_manage_attendance())
      or (select public.duoc_duyet_cong_to())
      or (select public.la_nguoi_cham_cong_to_txt((storage.foldername(name))[1]))
    )
  );
