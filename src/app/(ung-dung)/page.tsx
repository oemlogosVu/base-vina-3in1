import { batBuocPhien } from "@/shared/auth/phien";
import { TrangThaiTrong } from "@/shared/ui/hien-thi";

/**
 * TRANG CHỦ TỔNG «Việc chờ tôi».
 *
 * GĐ1: khung rỗng. GĐ5 mới gom việc chờ từ cả 3 phân hệ (mỗi phân hệ cung cấp một
 * hàm đếm việc chờ của người đang đăng nhập). Trang chủ chỉ ĐỌC số đếm, không tự tính.
 */
export default async function TrangChu() {
  const phien = await batBuocPhien();
  const homNay = new Intl.DateTimeFormat("vi-VN", {
    weekday: "long",
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    timeZone: "Asia/Ho_Chi_Minh",
  }).format(new Date());

  return (
    <div className="flex flex-col gap-6">
      <div className="hidden lg:block">
        <h1 className="text-[28px] font-bold text-muc">Chào {phien.tenHienThi}</h1>
        <p className="mt-1 text-[15px] text-muc-nhat">{homNay}</p>
      </div>

      <TrangThaiTrong
        bieuTuong="check-sq"
        chinh="Chưa có việc nào chờ bạn"
        phu="Việc chờ duyệt của Tài chính, Nhân sự và Kho sẽ hiện ở đây khi các phân hệ được ghép vào."
      />
    </div>
  );
}
