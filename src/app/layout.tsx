import type { Metadata, Viewport } from "next";
import { Be_Vietnam_Pro } from "next/font/google";
import "./globals.css";

import { TEN_APP } from "@/shared/phien-ban";
import { SpriteBieuTuong } from "@/shared/ui/bieu-tuong";

// Font có sẵn bộ dấu tiếng Việt đầy đủ — tránh chữ bị vỡ dấu trên điện thoại.
const beVietnamPro = Be_Vietnam_Pro({
  variable: "--font-be-vietnam",
  subsets: ["latin", "vietnamese"],
  weight: ["400", "500", "600", "700"],
});

export const metadata: Metadata = {
  title: TEN_APP,
  description: "Phần mềm nội bộ: Tài chính · Nhân sự · Kho",
};

// Khóa giao diện sáng ngay từ <head>: trình duyệt biết TRƯỚC khi vẽ nên không tự
// ép tối (nguyên nhân nút navy đổi màu làm chìm chữ). Đi kèm color-scheme trong CSS.
export const viewport: Viewport = {
  colorScheme: "light",
  themeColor: "#1f3a5c",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="vi" className={`${beVietnamPro.variable} h-full antialiased`}>
      <body className="min-h-full flex flex-col font-sans">
        {/* Mọi <symbol> biểu tượng, render một lần — các trang chỉ <use href="#i-..."/>. */}
        <SpriteBieuTuong />
        {children}
      </body>
    </html>
  );
}
