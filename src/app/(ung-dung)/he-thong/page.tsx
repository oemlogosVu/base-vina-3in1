import { TrangThaiTrong } from "@/shared/ui/hien-thi";

/** Trang giữ chỗ phân hệ Hệ thống — GĐ1 chưa chép nghiệp vụ. Ghép ở Giai đoạn 5 (docs/KE_HOACH_GOP_3_TRONG_1.md mục 4). */
export default function TrangHeThong() {
  return (
    <div className="flex flex-col gap-6">
      <h1 className="hidden text-[22px] font-bold text-muc lg:block">Hệ thống</h1>
      <TrangThaiTrong
        bieuTuong="cog"
        chinh="Phân hệ Hệ thống chưa được ghép vào"
        phu="Màn quản lý tài khoản và quyền vào phân hệ làm ở Giai đoạn 5."
      />
    </div>
  );
}
