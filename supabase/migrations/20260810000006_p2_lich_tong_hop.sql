-- =========================================================
-- P2 — Lịch chạy tổng hợp công hằng ngày
--
-- Tách khỏi migration hàm (20260810000005) có chủ ý: pg_cron là extension,
-- việc bật nó có thể hỏng vì lý do hạ tầng (gói dịch vụ, quyền). Nếu hỏng
-- thì hàm tổng hợp đã áp dụng xong vẫn dùng được — HR bấm nút tổng hợp tay,
-- hệ thống không chết, chỉ mất phần tự động.
-- =========================================================

create extension if not exists pg_cron;

-- ---------------------------------------------------------
-- Tổng hợp công của NGÀY HÔM TRƯỚC, chạy lúc 00:15 giờ Việt Nam.
--
-- pg_cron dùng giờ UTC. 00:15 giờ VN = 17:15 UTC hôm trước.
--
-- Vì sao 00:15 chứ không phải 00:00: ai chấm ra lúc 23:59 thì log cần vài
-- giây để ghi xong. Tổng hợp đúng lúc giao ngày là chạy đua với chính dữ
-- liệu mình đang chờ.
--
-- Vì sao lấy ngày hôm trước theo giờ VN chứ không phải current_date: lúc
-- 17:15 UTC thì current_date của server (UTC) vẫn là ngày hôm đó, trong khi
-- ở Việt Nam đã sang ngày mới. Phải quy đổi tường minh.
-- ---------------------------------------------------------
select cron.schedule(
  'tong-hop-cong-hang-ngay',
  '15 17 * * *',
  $job$
    select public.tong_hop_cong_ngay(
      ((now() at time zone 'Asia/Ho_Chi_Minh')::date - 1)
    );
  $job$
);
