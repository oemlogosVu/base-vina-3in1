import { describe, expect, it } from "vitest";

import { duongDanNoiBo } from "./an-toan-duong-dan";

// Chép từ test của app Nhân sự (src/lib/safe-path.test.ts), đổi tên hàm.
describe("duongDanNoiBo — chặn open-redirect", () => {
  it("giữ nguyên đường dẫn nội bộ hợp lệ", () => {
    expect(duongDanNoiBo("/")).toBe("/");
    expect(duongDanNoiBo("/nhan-su/ho-so")).toBe("/nhan-su/ho-so");
    expect(duongDanNoiBo("/tai-chinh/duyet?tab=cho")).toBe("/tai-chinh/duyet?tab=cho");
  });

  it("loại URL tuyệt đối sang tên miền khác", () => {
    expect(duongDanNoiBo("https://site-gia-mao.example")).toBe("/");
    expect(duongDanNoiBo("http://site-gia-mao.example")).toBe("/");
  });

  it("loại dạng protocol-relative //host", () => {
    expect(duongDanNoiBo("//site-gia-mao.example")).toBe("/");
    expect(duongDanNoiBo("//site-gia-mao.example/dang-nhap")).toBe("/");
  });

  it("loại dạng backslash mà một số trình duyệt chuẩn hoá thành //host", () => {
    expect(duongDanNoiBo("/\\site-gia-mao.example")).toBe("/");
  });

  it("loại giá trị không phải chuỗi", () => {
    expect(duongDanNoiBo(null)).toBe("/");
    expect(duongDanNoiBo(undefined)).toBe("/");
    expect(duongDanNoiBo(42)).toBe("/");
    expect(duongDanNoiBo(["/nhan-su"])).toBe("/");
  });

  it("dùng được fallback tuỳ biến", () => {
    expect(duongDanNoiBo("https://xau.example", "/dang-nhap")).toBe("/dang-nhap");
  });
});
