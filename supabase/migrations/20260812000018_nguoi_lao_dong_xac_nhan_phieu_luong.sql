-- =========================================================
-- Người lao động xác nhận phiếu lương
--
-- Quy trình Triệu Vũ chốt 12/08/2026: cuối kỳ, nhân sự chốt công và lương rồi
-- GỬI cho người lao động kiểm tra. Phiếu lương chỉ được coi là **hợp lệ** khi
-- chính người lao động bấm xác nhận.
--
-- Vòng đời kỳ lương: mo → da_chot (đã gửi, đang chờ NLĐ) → da_tra.
-- Vòng đời từng phiếu: cho_xac_nhan → da_xac_nhan, hoặc → thac_mac.
--
-- BA QUYẾT ĐỊNH ĐI KÈM, ghi lại vì mỗi cái đều có hướng ngược:
--
-- 1. **Có nút Thắc mắc kèm lý do.** Nếu chỉ có nút Xác nhận thì người không
--    đồng ý chỉ còn cách KHÔNG bấm gì — mà "không bấm" không phân biệt được
--    với "chưa xem". Hai thứ đó cần hai xử lý khác hẳn nhau.
-- 2. **Quá hạn thì tự coi như đã xác nhận**, và ghi rõ là tự động chứ không
--    phải người bấm (`xac_nhan_tu_dong`). Số ngày do từng công ty khai; chưa
--    khai thì KHÔNG bao giờ tự động — hệ thống không tự ý đồng ý thay người
--    lao động khi chưa ai cho phép nó làm thế.
-- 3. **Còn người chưa xác nhận thì kỳ không chuyển sang "Đã trả"** — và lời
--    từ chối nêu đích danh tên họ, cùng kiểu với việc engine từ chối tính
--    lương khi còn nhân viên chưa gán công ty.
--
-- THẮC MẮC KHÔNG BAO GIỜ BỊ TỰ ĐỘNG XÁC NHẬN. Người đã nói "số này sai" mà
-- hệ thống lặng lẽ đánh dấu họ đồng ý thì tính năng này phản tác dụng hoàn
-- toàn — nó biến một tiếng nói phản đối thành một chữ ký.
-- =========================================================

create type public.payslip_ack as enum ('cho_xac_nhan', 'da_xac_nhan', 'thac_mac');

comment on type public.payslip_ack is
  'Trạng thái xác nhận của người lao động trên một phiếu lương. Chỉ da_xac_nhan mới là hợp lệ.';

alter table public.payslips
  add column xac_nhan_trang_thai public.payslip_ack not null default 'cho_xac_nhan',
  add column xac_nhan_luc        timestamptz,
  add column xac_nhan_tu_dong    boolean not null default false,
  add column thac_mac_luc        timestamptz,
  add column thac_mac_ly_do      text;

comment on column public.payslips.xac_nhan_tu_dong is
  'true = quá hạn nên hệ thống tự đánh dấu, KHÔNG phải người lao động bấm. Phải phân biệt được khi tra lại.';
comment on column public.payslips.thac_mac_ly_do is
  'Lý do người lao động nêu khi bấm Thắc mắc. Giữ lại cả sau khi họ đã xác nhận, để còn tra được đã từng có tranh chấp gì.';

-- Trạng thái và dữ liệu đi kèm phải khớp nhau ở TẦNG DATABASE. Biểu mẫu có
-- chặn, nhưng biểu mẫu là tiện lợi; dữ liệu còn vào được bằng script.
alter table public.payslips add constraint payslip_xac_nhan_du_doi check (
  case xac_nhan_trang_thai
    when 'da_xac_nhan' then xac_nhan_luc is not null
    when 'thac_mac'    then thac_mac_luc is not null
                            and coalesce(btrim(thac_mac_ly_do), '') <> ''
                            and xac_nhan_luc is null
    else xac_nhan_luc is null and xac_nhan_tu_dong = false
  end
);

-- ---------------------------------------------------------
-- Hạn xác nhận, khai theo từng công ty
-- ---------------------------------------------------------

alter table public.companies
  add column han_xac_nhan_phieu_ngay integer
    check (han_xac_nhan_phieu_ngay > 0 and han_xac_nhan_phieu_ngay <= 90);

comment on column public.companies.han_xac_nhan_phieu_ngay is
  'Số ngày kể từ lúc chốt kỳ, quá hạn thì phiếu chưa ai bấm được tự đánh dấu đã xác nhận. NULL = không bao giờ tự động.';

-- ---------------------------------------------------------
-- Người lao động xác nhận phiếu của CHÍNH MÌNH
-- ---------------------------------------------------------

create or replace function public.xac_nhan_phieu_luong(p_payslip_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  toi   uuid := public.current_employee_id();
  phieu public.payslips%rowtype;
  ky    public.payroll_periods%rowtype;
begin
  if toi is null then
    raise exception 'Tài khoản của bạn chưa gắn hồ sơ nhân sự nên không có phiếu lương để xác nhận.';
  end if;

  select * into phieu from public.payslips where id = p_payslip_id;
  if not found then
    raise exception 'Không tìm thấy phiếu lương này.';
  end if;

  -- Xác nhận là chữ ký. Chỉ chính chủ ký được, không ai ký hộ — kể cả admin.
  if phieu.employee_id <> toi then
    raise exception 'Chỉ người lao động mới xác nhận được phiếu lương của chính mình.';
  end if;

  select * into ky from public.payroll_periods where id = phieu.period_id;
  if ky.status = 'mo' then
    raise exception 'Kỳ lương %/% chưa chốt nên chưa gửi cho bạn — con số còn có thể thay đổi.', ky.month, ky.year;
  end if;

  if phieu.xac_nhan_trang_thai = 'da_xac_nhan' then
    raise exception 'Bạn đã xác nhận phiếu lương kỳ %/% rồi.', ky.month, ky.year;
  end if;

  -- Đang thắc mắc mà bấm xác nhận thì được: nhân sự giải thích xong, người
  -- lao động đồng ý. Lý do thắc mắc GIỮ NGUYÊN để còn tra lại.
  update public.payslips
  set xac_nhan_trang_thai = 'da_xac_nhan',
      xac_nhan_luc        = now(),
      xac_nhan_tu_dong    = false
  where id = p_payslip_id;
end;
$$;

comment on function public.xac_nhan_phieu_luong(uuid) is
  'Người lao động xác nhận phiếu lương của chính mình. Không ai xác nhận hộ được, kể cả admin.';

revoke execute on function public.xac_nhan_phieu_luong(uuid) from public, anon;
grant  execute on function public.xac_nhan_phieu_luong(uuid) to authenticated;

-- ---------------------------------------------------------
-- Người lao động nêu thắc mắc
-- ---------------------------------------------------------

create or replace function public.thac_mac_phieu_luong(p_payslip_id uuid, p_ly_do text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  toi   uuid := public.current_employee_id();
  phieu public.payslips%rowtype;
  ky    public.payroll_periods%rowtype;
begin
  if toi is null then
    raise exception 'Tài khoản của bạn chưa gắn hồ sơ nhân sự nên không có phiếu lương để thắc mắc.';
  end if;

  if coalesce(btrim(p_ly_do), '') = '' then
    raise exception 'Nêu rõ chỗ nào chưa đúng — thắc mắc không có nội dung thì nhân sự không biết kiểm cái gì.';
  end if;

  select * into phieu from public.payslips where id = p_payslip_id;
  if not found then
    raise exception 'Không tìm thấy phiếu lương này.';
  end if;
  if phieu.employee_id <> toi then
    raise exception 'Chỉ người lao động mới thắc mắc được về phiếu lương của chính mình.';
  end if;

  select * into ky from public.payroll_periods where id = phieu.period_id;
  if ky.status = 'mo' then
    raise exception 'Kỳ lương %/% chưa chốt nên chưa gửi cho bạn.', ky.month, ky.year;
  end if;

  -- Đã xác nhận rồi thì không quay lại thắc mắc: chữ ký đã ký. Muốn sửa thì
  -- nhân sự mở kỳ điều chỉnh, đúng như mọi sửa đổi khác sau khi chốt.
  if phieu.xac_nhan_trang_thai = 'da_xac_nhan' then
    raise exception 'Bạn đã xác nhận phiếu này rồi. Cần điều chỉnh thì báo nhân sự mở kỳ điều chỉnh.';
  end if;

  update public.payslips
  set xac_nhan_trang_thai = 'thac_mac',
      thac_mac_luc        = now(),
      thac_mac_ly_do      = btrim(p_ly_do)
  where id = p_payslip_id;
end;
$$;

comment on function public.thac_mac_phieu_luong(uuid, text) is
  'Người lao động nêu thắc mắc về phiếu lương của chính mình. Bắt buộc có lý do.';

revoke execute on function public.thac_mac_phieu_luong(uuid, text) from public, anon;
grant  execute on function public.thac_mac_phieu_luong(uuid, text) to authenticated;

-- ---------------------------------------------------------
-- Quá hạn thì tự đánh dấu đã xác nhận
-- ---------------------------------------------------------

create or replace function public.tu_dong_xac_nhan_phieu_qua_han(p_period_id uuid default null)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  so_dong integer;
begin
  with qua_han as (
    select p.id
    from public.payslips p
    join public.payroll_periods k on k.id = p.period_id
    join public.companies c on c.id = k.company_id
    where k.status = 'da_chot'
      and (p_period_id is null or k.id = p_period_id)
      -- Chưa khai hạn thì KHÔNG bao giờ tự động.
      and c.han_xac_nhan_phieu_ngay is not null
      and k.closed_at is not null
      and now() >= k.closed_at + make_interval(days => c.han_xac_nhan_phieu_ngay)
      -- CHỈ những phiếu chưa ai đụng tới. Phiếu đang THẮC MẮC không bao giờ
      -- bị quét: biến một tiếng nói phản đối thành chữ ký là hỏng hẳn.
      and p.xac_nhan_trang_thai = 'cho_xac_nhan'
  )
  update public.payslips p
  set xac_nhan_trang_thai = 'da_xac_nhan',
      xac_nhan_luc        = now(),
      xac_nhan_tu_dong    = true
  from qua_han q
  where p.id = q.id;

  get diagnostics so_dong = row_count;
  return so_dong;
end;
$$;

comment on function public.tu_dong_xac_nhan_phieu_qua_han(uuid) is
  'Quét phiếu quá hạn xác nhận và tự đánh dấu, ghi rõ xac_nhan_tu_dong = true. Không đụng phiếu đang thắc mắc.';

revoke execute on function public.tu_dong_xac_nhan_phieu_qua_han(uuid) from public, anon;
grant  execute on function public.tu_dong_xac_nhan_phieu_qua_han(uuid) to authenticated;

-- ---------------------------------------------------------
-- Đánh dấu kỳ ĐÃ TRẢ — chặn khi còn người chưa xác nhận
-- ---------------------------------------------------------

create or replace function public.danh_dau_da_tra(p_period_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  ky      public.payroll_periods%rowtype;
  con_lai text;
  so_con  integer;
begin
  if not public.can_manage_payroll() then
    raise exception 'Chỉ kế toán hoặc admin được đánh dấu kỳ lương đã trả.';
  end if;

  select * into ky from public.payroll_periods where id = p_period_id;
  if not found then
    raise exception 'Không tìm thấy kỳ lương %.', p_period_id;
  end if;
  if ky.status = 'mo' then
    raise exception 'Kỳ lương %/% chưa chốt. Chốt kỳ để gửi phiếu cho người lao động trước.', ky.month, ky.year;
  end if;
  if ky.status = 'da_tra' then
    raise exception 'Kỳ lương %/% đã đánh dấu trả rồi.', ky.month, ky.year;
  end if;

  -- Quét quá hạn ngay tại đây, để quy tắc "quá hạn coi như đã xác nhận" đúng
  -- kể cả khi chưa ai lên lịch chạy quét định kỳ.
  perform public.tu_dong_xac_nhan_phieu_qua_han(p_period_id);

  select count(*),
         string_agg(e.full_name || ' (' || e.employee_code || ')' ||
                    case when p.xac_nhan_trang_thai = 'thac_mac' then ' — đang thắc mắc' else '' end,
                    ', ' order by e.employee_code)
    into so_con, con_lai
  from public.payslips p
  join public.employees e on e.id = p.employee_id
  where p.period_id = p_period_id
    and p.xac_nhan_trang_thai <> 'da_xac_nhan';

  if so_con > 0 then
    raise exception
      'Còn % người chưa xác nhận phiếu lương kỳ %/%: %. Phiếu chỉ hợp lệ khi chính người lao động bấm xác nhận.',
      so_con, ky.month, ky.year, con_lai;
  end if;

  update public.payroll_periods set status = 'da_tra' where id = p_period_id;
end;
$$;

comment on function public.danh_dau_da_tra(uuid) is
  'Chuyển kỳ lương sang Đã trả. Từ chối khi còn phiếu chưa được người lao động xác nhận, và nêu đích danh ai.';

revoke execute on function public.danh_dau_da_tra(uuid) from public, anon;
grant  execute on function public.danh_dau_da_tra(uuid) to authenticated;

-- ---------------------------------------------------------
-- Tiến độ xác nhận của một kỳ — cho màn nhân sự
-- ---------------------------------------------------------

create or replace function public.tien_do_xac_nhan_ky(p_period_id uuid)
returns table (
  employee_code text,
  full_name     text,
  trang_thai    public.payslip_ack,
  tu_dong       boolean,
  xac_nhan_luc  timestamptz,
  ly_do         text
)
language sql
stable
security invoker
as $$
  select e.employee_code, e.full_name, p.xac_nhan_trang_thai, p.xac_nhan_tu_dong,
         p.xac_nhan_luc, p.thac_mac_ly_do
  from public.payslips p
  join public.employees e on e.id = p.employee_id
  where p.period_id = p_period_id
  order by
    case p.xac_nhan_trang_thai
      when 'thac_mac' then 1 when 'cho_xac_nhan' then 2 else 3
    end,
    e.employee_code;
$$;

comment on function public.tien_do_xac_nhan_ky(uuid) is
  'Ai đã xác nhận, ai chưa, ai đang thắc mắc. SECURITY INVOKER nên RLS của payslips vẫn áp: nhân viên thường chỉ thấy dòng của mình.';
