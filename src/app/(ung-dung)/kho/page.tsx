import { TrangThaiTrong } from "@/shared/ui/hien-thi";

/** Trang giữ chỗ phân hệ Kho — GĐ1 chưa chép nghiệp vụ. Ghép ở Giai đoạn 4 (docs/KE_HOACH_GOP_3_TRONG_1.md mục 4). */
export default function TrangKho() {
  return (
    <div className="flex flex-col gap-6">
      <h1 className="hidden text-[22px] font-bold text-muc lg:block">Kho</h1>
      <TrangThaiTrong
        bieuTuong="folder"
        chinh="Phân hệ Kho chưa được ghép vào"
        phu="Sẽ ghép ở Giai đoạn 4. Trong lúc chờ, vẫn dùng app Kho hiện tại."
      />
    </div>
  );
}
