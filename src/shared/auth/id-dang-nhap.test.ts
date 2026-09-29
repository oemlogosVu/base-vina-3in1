import { describe, expect, it } from "vitest";

import { emailTuId, idHopLe } from "./id-dang-nhap";

// Khóa hành vi đang chạy ở app Tài chính: tài khoản SĐT đã tạo theo đúng quy đổi này,
// đổi quy đổi là người dùng SĐT không đăng nhập được nữa.
describe("emailTuId — quy đổi ID đăng nhập", () => {
  it("email giữ nguyên, chữ thường", () => {
    expect(emailTuId("  KeToan@Base.Vina ")).toBe("ketoan@base.vina");
  });

  it("SĐT chỉ giữ chữ số rồi thêm miền nội bộ", () => {
    expect(emailTuId("0912 345 678")).toBe("0912345678@sodienthoai.local");
    expect(emailTuId("0912-345-678")).toBe("0912345678@sodienthoai.local");
  });

  it("KHÔNG đổi +84 thành 0 (giữ đúng quy ước Tài chính hiện tại)", () => {
    expect(emailTuId("+84 912 345 678")).toBe("84912345678@sodienthoai.local");
  });
});

describe("idHopLe", () => {
  it("nhận email có dấu chấm và SĐT từ 8 chữ số", () => {
    expect(idHopLe("a@b.vn")).toBe(true);
    expect(idHopLe("0912345678")).toBe(true);
  });

  it("loại chuỗi rỗng, email thiếu dấu chấm, SĐT quá ngắn", () => {
    expect(idHopLe("")).toBe(false);
    expect(idHopLe("a@b")).toBe(false);
    expect(idHopLe("1234567")).toBe(false);
  });
});
