-- =========================================================
-- P5h — Người chấm tự duyệt công cho cả tổ, và khoá bảng thanh toán đã sinh
--
-- Triệu Vũ, 24/08/2026, hai quyết định:
--
--   "Người chấm công sẽ được xác nhận công áp dụng cho cả tổ đội."
--   "Phần tính lương của tổ đội đã tính xong không cho phép sửa nữa."
--
-- =========================================================
-- 1. NGƯỜI CHẤM TỰ DUYỆT — và đánh đổi phải nói thẳng
-- ---------------------------------------------------------
--
-- Việc này BỎ chốt hai người mà chính ngày hôm nay đã dựng lên hai lần:
--
--   • P1e sáng nay: "người chấm không tự duyệt phiên mình chấm — vừa khai vừa
--     duyệt thì con số không còn ai đối chiếu";
--   • bản vá cùng ngày: bỏ luôn ngoại lệ cho `hr` vì cùng lý do.
--
-- Triệu Vũ được hỏi lại đúng câu ấy, kèm nguyên văn đánh đổi, và chọn cho tổ
-- trưởng tự duyệt. Đây là quyết định của người phụ trách, không phải chỗ code
-- quên. Ghi lại để người sau đọc thấy nó có chủ, và biết đường hỏi ai nếu
-- muốn đổi.
--
-- ĐÁNH ĐỔI, nói rõ: từ bản này, MỘT NGƯỜI vừa khai số công vừa duyệt số công
-- ấy, và số công là tiền. Không còn chữ ký thứ hai trên con số đó. Lớp kiểm
-- còn lại chỉ là ảnh xác minh (phiên thiếu ảnh vẫn không duyệt được) và bảng
-- thanh toán do người khác sinh.
--
-- HAI VẾ KHÁC GIỮ NGUYÊN, và chúng vẫn có nghĩa:
--
--   (a) `duyet_boi` phải là chính người đang duyệt — dấu vết duyệt không mang
--       tên người khác được.
--   (b) NGƯỜI CÓ TÊN TRONG TỔ vẫn KHÔNG duyệt được công của tổ mình. Đây là
--       vế bảo vệ người HƯỞNG TIỀN tự duyệt công của chính mình — khác hẳn vế
--       vừa bỏ, vốn nói về người CHẤM. Quyết định 22/08 về tổ trưởng vẫn đứng.
-- ---------------------------------------------------------
create or replace function public.chan_tu_duyet_cong_to()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  nguoi uuid := (select auth.uid());
  ho_so uuid;
begin
  if new.da_duyet is not true or old.da_duyet is true then
    return new;
  end if;

  if nguoi is null then
    return new;
  end if;

  select u.employee_id into ho_so from public.app_users u where u.id = nguoi;

  if new.duyet_boi is distinct from nguoi then
    raise exception
      'Ô "duyệt bởi" phải mang tên chính người đang duyệt. Dấu vết duyệt ghi tên người khác thì nó không còn là bằng chứng.'
      using errcode = 'insufficient_privilege';
  end if;

  -- Người HƯỞNG TIỀN của tổ vẫn không tự duyệt công của tổ mình. Vế này khác
  -- vế vừa bỏ: bỏ là bỏ cho người CHẤM, giữ là giữ cho người ĂN CÔNG.
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

  return new;
end;
$$;

comment on function public.chan_tu_duyet_cong_to() is
  'Dấu vết duyệt phải mang tên người duyệt, và người CÓ TÊN TRONG TỔ không duyệt công của tổ mình. Người CHẤM tự duyệt được từ 24/08/2026 — quyết định của Triệu Vũ, đánh đổi ghi trong migration P5h.';

-- Policy cũ chặn người chấm ở đúng chỗ này: `not da_duyet` ở WITH CHECK nghĩa
-- là họ ghi được mọi thứ TRỪ việc bật cờ duyệt. Nay tách làm hai policy để đọc
-- ra là thấy hai quyền khác nhau, thay vì nới một điều kiện rồi quên mất nó
-- từng chặn cái gì.
drop policy "phien_update_nguoi_cham" on public.phien_cham_cong_to;

-- (i) Sửa số công, ghi chú: chỉ khi phiên CHƯA duyệt. Không đổi.
create policy "phien_update_nguoi_cham_chua_duyet"
  on public.phien_cham_cong_to for update
  to authenticated
  using ((select public.la_nguoi_cham_cong_to(to_doi_id)) and not da_duyet)
  with check ((select public.la_nguoi_cham_cong_to(to_doi_id)) and not da_duyet);

-- (ii) DUYỆT phiên của chính tổ mình. Mở từ 24/08/2026.
create policy "phien_duyet_boi_nguoi_cham"
  on public.phien_cham_cong_to for update
  to authenticated
  using ((select public.la_nguoi_cham_cong_to(to_doi_id)))
  with check ((select public.la_nguoi_cham_cong_to(to_doi_id)));

-- Ai duyệt được công tổ đội: thêm người chấm của chính tổ ấy.
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

-- =========================================================
-- 2. BẢNG THANH TOÁN ĐÃ SINH: KHOÁ SỬA
-- ---------------------------------------------------------
--
-- "Phần tính lương của tổ đội đã tính xong không cho phép sửa nữa."
--
-- Bảng thanh toán là KẾT QUẢ TÍNH RA từ số công đã duyệt và đơn giá đã khai.
-- Sửa tay một dòng trong đó là làm cho con số trả tiền không còn suy ra được
-- từ dữ liệu gốc — và không dấu vết nào nói ai đã sửa, sửa từ bao nhiêu.
--
-- Hai lớp cùng lúc, như mọi chỗ khác trong hệ thống này: bỏ quyền cấp cột, VÀ
-- bỏ policy. Thiếu một trong hai là còn một đường đi.
--
-- XOÁ thì GIỮ cho admin (quyết định của Triệu Vũ hôm nay): hàm sinh từ chối
-- trùng khoảng ngày, nên duyệt thêm phiên rồi muốn sinh lại thì phải bỏ bảng
-- cũ. Đánh đổi ấy đã ghi ở phép kiểm 3 của p1 từ 19/08 và không đổi.
-- ---------------------------------------------------------
revoke update on public.dong_thanh_toan_to from authenticated;

drop policy "dong_update_admin" on public.dong_thanh_toan_to;

comment on table public.dong_thanh_toan_to is
  'Dòng thanh toán của một người trong một bảng. KHÔNG SỬA ĐƯỢC sau khi sinh (24/08/2026): nó là kết quả tính ra từ số công đã duyệt và đơn giá đã khai. Sai thì xoá cả bảng rồi sinh lại — admin làm, và dấu vết là bảng cũ biến mất chứ không phải một con số lặng lẽ đổi.';
