import type { MetadataRoute } from "next";

import { TEN_APP } from "@/shared/phien-ban";

/**
 * PWA manifest — thứ làm app cài được lên màn hình chính điện thoại.
 *
 * Next.js tự phục vụ file này tại /manifest.webmanifest. Đường dẫn đó đã được
 * loại trừ khỏi proxy.ts, vì điện thoại phải đọc được manifest KHI CHƯA đăng
 * nhập — chặn nó thì nút "Thêm vào màn hình chính" không hiện ra.
 *
 * Biểu tượng: TẠM dùng của app Tài chính cũ cho đến khi chốt tên + logo.
 */
export default function manifest(): MetadataRoute.Manifest {
  return {
    name: TEN_APP,
    short_name: TEN_APP,
    description: "Phần mềm nội bộ: Tài chính · Nhân sự · Kho",
    start_url: "/",
    display: "standalone",
    orientation: "portrait",
    background_color: "#f3f5f7",
    theme_color: "#1f3a5c",
    lang: "vi",
    icons: [
      { src: "/icons/icon-192.png", sizes: "192x192", type: "image/png", purpose: "any" },
      { src: "/icons/icon-512.png", sizes: "512x512", type: "image/png", purpose: "any" },
      {
        // maskable: Android cắt icon theo hình của hãng (tròn, vuông bo góc...).
        // Không có bản này thì logo bị cắt cụt mất chữ.
        src: "/icons/icon-512-maskable.png",
        sizes: "512x512",
        type: "image/png",
        purpose: "maskable",
      },
    ],
  };
}
