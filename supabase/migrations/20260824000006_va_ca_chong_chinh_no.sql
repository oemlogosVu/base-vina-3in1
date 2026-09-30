-- =========================================================
-- Vá lỗi: khai khung giờ báo 'Ca "sang" chồng giờ với ca "sang"'
--
-- Triệu Vũ báo 24/08/2026, ngay khi khai khung giờ chuẩn cho công ty đầu tiên.
-- Câu báo lỗi tự mâu thuẫn — một ca chồng giờ với chính nó — nên nó là lỗi của
-- phép kiểm, không phải của dữ liệu người dùng nhập.
--
-- TÁI HIỆN
--
-- Lần bấm Lưu ĐẦU TIÊN chạy được. Lần thứ hai, khi sửa lại giờ của chính ca ấy,
-- thì ngã. Biểu mẫu ghi bằng `upsert` (`insert … on conflict (company_id, ma)
-- do update`), và đó là chỗ hỏng.
--
-- NGUYÊN NHÂN
--
-- Trigger `trg_ca_cong_nhat_chan_chong_nhau` là BEFORE INSERT. Postgres chạy
-- trigger BEFORE INSERT **trước khi** phát hiện xung đột khoá và chuyển sang
-- nhánh DO UPDATE. Tại thời điểm ấy `new.id` là một uuid VỪA SINH RA từ
-- `default gen_random_uuid()`, chưa phải id của dòng sẽ bị ghi đè.
--
-- Nên điều kiện `c.id is distinct from new.id` không loại được dòng 'sang' đang
-- có: với trigger, nó là "một ca khác" có giờ chồng lên — và tất nhiên là chồng,
-- vì nó chính là ca ấy.
--
-- CÁCH VÁ
--
-- Loại theo `ma`, không theo `id`. Ràng buộc `ca_mot_cong_ty_mot_ma` đã bảo đảm
-- mỗi công ty chỉ có một dòng cho mỗi mã ca, nên "cùng company_id và cùng ma"
-- LÀ cùng một ca, bất kể id nào đang cầm trên tay. Điều kiện ấy đúng ở cả ba
-- đường ghi — insert mới, upsert, và update thẳng — vì nó không phụ thuộc vào
-- việc `new.id` có thật hay không.
--
-- Giữ luôn vế `id` cho update thẳng: thừa nhưng không sai, và nó nói ra ý định.
--
-- BÀI HỌC: `new.id` trong trigger BEFORE INSERT của một lệnh upsert KHÔNG phải
-- id của dòng sẽ tồn tại. Đừng nhận dạng dòng bằng nó.
-- =========================================================

create or replace function public.chan_ca_cong_nhat_chong_nhau()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  ten_ca text;
begin
  select c.ma into ten_ca
  from public.ca_cong_nhat c
  where c.company_id = new.company_id
    -- Cùng công ty + cùng mã ca = CÙNG MỘT CA, theo ràng buộc
    -- `ca_mot_cong_ty_mot_ma`. Đây là vế thật sự loại được chính nó.
    and c.ma is distinct from new.ma
    and c.id is distinct from new.id
    and c.gio_bat_dau < new.gio_ket_thuc
    and c.gio_ket_thuc > new.gio_bat_dau
  limit 1;

  if ten_ca is not null then
    raise exception
      'Ca "%" chồng giờ với ca "%" của cùng công ty. Hai ca chồng nhau là đếm hai lần cùng một giờ làm.',
      new.ma, ten_ca
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

comment on function public.chan_ca_cong_nhat_chong_nhau() is
  'Hai ca KHÁC NHAU của cùng công ty không được chồng giờ. Loại chính nó bằng `ma` chứ không bằng `id`: trong trigger BEFORE INSERT của một lệnh upsert, new.id là uuid vừa sinh ra, không phải id của dòng sẽ bị ghi đè.';
