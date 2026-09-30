import "@ns/nhan-su.css";

/**
 * Vỏ phân hệ Nhân sự: mọi CSS chép từ HRM chỉ có hiệu lực bên trong .ns-scope
 * (HRM trùng tên class với phần dùng chung: .the, .bang, .pill, .noi-dung).
 * `rong`: bỏ giới hạn cột 768px của khung chung — bảng công/lương cần bề ngang (HRM tối đa 1040px).
 */
export default function KhungNhanSu({ children }: { children: React.ReactNode }) {
  return <div className="ns-scope rong">{children}</div>;
}
