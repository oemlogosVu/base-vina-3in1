import { TrangThaiTrong } from "@/shared/ui/hien-thi";

/** Trang giữ chỗ phân hệ Nhân sự — GĐ1 chưa chép nghiệp vụ. Ghép ở Giai đoạn 2 (docs/KE_HOACH_GOP_3_TRONG_1.md mục 4). */
export default function TrangNhanSu() {
  return (
    <div className="flex flex-col gap-6">
      <h1 className="hidden text-[22px] font-bold text-muc lg:block">Nhân sự</h1>
      <TrangThaiTrong
        bieuTuong="users"
        chinh="Phân hệ Nhân sự chưa được ghép vào"
        phu="Sẽ ghép ở Giai đoạn 2. Trong lúc chờ, vẫn dùng app Nhân sự hiện tại."
      />
    </div>
  );
}
