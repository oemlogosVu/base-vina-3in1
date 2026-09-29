import { TrangThaiTrong } from "@/shared/ui/hien-thi";

/** Trang giữ chỗ phân hệ Tài chính — GĐ1 chưa chép nghiệp vụ. Ghép ở Giai đoạn 3 (docs/KE_HOACH_GOP_3_TRONG_1.md mục 4). */
export default function TrangTaiChinh() {
  return (
    <div className="flex flex-col gap-6">
      <h1 className="hidden text-[22px] font-bold text-muc lg:block">Tài chính</h1>
      <TrangThaiTrong
        bieuTuong="wallet"
        chinh="Phân hệ Tài chính chưa được ghép vào"
        phu="Sẽ ghép ở Giai đoạn 3. Trong lúc chờ, vẫn dùng app Quản lý Thu Chi hiện tại."
      />
    </div>
  );
}
