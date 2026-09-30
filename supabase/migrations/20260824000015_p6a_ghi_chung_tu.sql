-- =========================================================
-- P6a (tiếp) — Đường ghi DUY NHẤT vào bảng chứng từ
--
-- Bảng `chung_tu` không có policy INSERT nào, nên chỉ `service_role` ghi được.
-- Nhưng "service_role ghi thẳng vào bảng" nghĩa là mọi ràng buộc nghiệp vụ nằm
-- trong mã Deno, và mã Deno thì bộ kiểm SQL không soi được.
--
-- Nên gom vào một hàm: Edge Function gọi hàm, hàm tự sinh số hiệu và tự kiểm
-- những thứ mà database kiểm được tốt hơn. Đúng ranh giới đã dùng cho
-- `anh-cham-cong-to`: chỗ nào database diễn đạt được thì để database làm.
--
-- CHỈ `service_role` GỌI ĐƯỢC. Cấp cho `authenticated` là mở đúng cái cửa mà
-- cả P6a dựng lên để đóng — ai cũng tự khai được một chứng từ với con số tuỳ ý.
-- =========================================================

create or replace function public.ghi_chung_tu(
  p_loai         public.loai_chung_tu,
  p_doi_tuong_id uuid,
  p_duong_dan    text,
  p_tieu_de      text,
  p_tong_tien    numeric,
  p_so_dong      integer,
  p_kich_thuoc   integer,
  p_sha256       text,
  p_nguoi_tao    uuid
)
returns public.chung_tu
language plpgsql
security definer
set search_path = ''
as $$
declare
  ket public.chung_tu%rowtype;
begin
  -- Đã có chứng từ cho đối tượng này thì TRẢ LẠI BẢN CŨ, không ném lỗi và
  -- tuyệt đối không ghi đè.
  --
  -- Gọi lại là chuyện bình thường: người dùng bấm hai lần, hoặc bấm "sinh lại"
  -- sau một lần mạng chập. Ghi đè thì chứng từ mất tính bất biến — mà bất biến
  -- là toàn bộ giá trị của nó. Ném lỗi thì giao diện phải phân biệt "lỗi thật"
  -- với "đã có rồi", và sẽ có ngày phân biệt sai.
  select * into ket
  from public.chung_tu
  where loai = p_loai and doi_tuong_id = p_doi_tuong_id;

  if found then
    return ket;
  end if;

  -- Đối tượng phải CÓ THẬT và ĐÃ CHỐT. Không kiểm thì một lời gọi sai sinh ra
  -- chứng từ cho một kỳ lương còn đang mở — tức là một tờ giấy nói con số đã
  -- xong trong khi nó còn tính lại được.
  if p_loai = 'ky_luong' then
    if not exists (
      select 1 from public.payroll_periods
      where id = p_doi_tuong_id and status <> 'mo'
    ) then
      raise exception 'Kỳ lương % chưa chốt hoặc không tồn tại — chưa sinh chứng từ được.',
        p_doi_tuong_id;
    end if;
  else
    if not exists (select 1 from public.bang_thanh_toan_to where id = p_doi_tuong_id) then
      raise exception 'Không tìm thấy bảng thanh toán %.', p_doi_tuong_id;
    end if;
  end if;

  insert into public.chung_tu (
    so_hieu, loai, doi_tuong_id, duong_dan, tieu_de,
    tong_tien, so_dong, kich_thuoc, sha256, nguoi_tao
  )
  values (
    'CT-' || to_char(now() at time zone 'Asia/Ho_Chi_Minh', 'YYYY') || '-'
          || lpad(nextval('public.chung_tu_so_hieu_seq')::text, 6, '0'),
    p_loai, p_doi_tuong_id, p_duong_dan, p_tieu_de,
    p_tong_tien, p_so_dong, p_kich_thuoc, p_sha256, p_nguoi_tao
  )
  returning * into ket;

  return ket;
end;
$$;

comment on function public.ghi_chung_tu(public.loai_chung_tu, uuid, text, text, numeric, integer, integer, text, uuid) is
  'Đường ghi duy nhất vào chung_tu. Chỉ service_role gọi được. Gọi lại lần hai trả về bản cũ, KHÔNG ghi đè — chứng từ bất biến.';

revoke execute on function public.ghi_chung_tu(public.loai_chung_tu, uuid, text, text, numeric, integer, integer, text, uuid)
  from public, anon, authenticated;
