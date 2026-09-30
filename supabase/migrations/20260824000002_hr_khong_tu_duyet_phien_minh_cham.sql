-- =========================================================
-- Nhân sự không tự duyệt phiên chấm công do chính mình chấm
--
-- Triệu Vũ đồng ý 24/08/2026, sau khi P1e nêu lỗ này ra.
--
-- P1e đặt luật "không tự duyệt phiên mình chấm" nhưng CHỪA hr/admin, vì HR
-- chấm hộ khi tổ trưởng ốm hay mất điện thoại (đường đã có từ P5a). Chừa như
-- vậy để nguyên một lỗ CŨ: HR mở phiên, tự ghi số công, rồi tự duyệt số công
-- ấy — một người đi trọn vòng, không còn ai đối chiếu.
--
-- Bản này bỏ ngoại lệ cho `hr`. Vẫn giữ cho `admin`, và đó là lựa chọn có
-- đánh đổi rõ ràng:
--
--   • Giữ admin  → công ty một-người-nhân-sự vẫn duyệt được: HR chấm hộ, admin
--                  duyệt. Đổi lại, admin đi trọn vòng được — nhưng admin vốn
--                  đã sửa được mọi thứ trong hệ thống này, kể cả bảng cấp
--                  quyền, nên chặn họ ở đây không thêm được gì thật.
--   • Bỏ cả admin → không ai đi trọn vòng, nhưng công ty chỉ có một admin mà
--                  admin lỡ chấm hộ thì phiên ấy TẮC, không đường nào duyệt
--                  ngoài SQL Editor. Một ngõ cụt trên giao diện tệ hơn một lỗ
--                  mà người ta biết.
--
-- Cách gỡ khi HR đã trót chấm hộ: admin duyệt, hoặc một người khác giữ chức
-- danh mang quyền `duyet_cong` duyệt. Thông báo lỗi nói thẳng cả hai đường.
--
-- KHÔNG đổi gì khác: hai vế còn lại của trigger (`duyet_boi` phải là chính
-- mình; người trong tổ không duyệt tổ mình) giữ nguyên từng chữ.
-- =========================================================

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

  -- service_role / SQL Editor: lối thoát bằng tay phải luôn còn.
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

  -- Đổi so với P1e: chỉ còn `admin` được chừa, không còn `hr`.
  if new.nguoi_cham_id = nguoi and coalesce(vai_tro, '') <> 'admin' then
    raise exception
      'Bạn là người chấm phiên này. Duyệt phải do người khác làm — vừa khai vừa duyệt thì con số không còn ai đối chiếu. Nhờ quản trị hệ thống, hoặc người giữ chức danh có quyền duyệt công, duyệt hộ.'
      using errcode = 'insufficient_privilege';
  end if;

  return new;
end;
$$;

comment on function public.chan_tu_duyet_cong_to() is
  'Không ai duyệt công của chính mình: dấu vết duyệt phải mang tên người duyệt, người trong tổ không duyệt tổ mình, và người chấm không tự duyệt phiên mình chấm. Chỉ admin được chừa vế cuối, và chỉ để không tạo ngõ cụt cho công ty một người.';
