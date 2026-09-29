import { describe, expect, it } from "vitest";

import { DS_PHAN_HE, phanHeTuDuongDan } from "./phan-he";

describe("phanHeTuDuongDan", () => {
  it("nhận đúng phân hệ theo tiền tố đường dẫn", () => {
    expect(phanHeTuDuongDan("/tai-chinh")?.ma).toBe("tc");
    expect(phanHeTuDuongDan("/tai-chinh/de-nghi/12")?.ma).toBe("tc");
    expect(phanHeTuDuongDan("/nhan-su/ho-so/5")?.ma).toBe("ns");
    expect(phanHeTuDuongDan("/kho/phieu/PN-01")?.ma).toBe("kho");
    expect(phanHeTuDuongDan("/he-thong/tai-khoan")?.ma).toBe("ht");
  });

  it("trang chung không thuộc phân hệ nào", () => {
    expect(phanHeTuDuongDan("/")).toBeNull();
    expect(phanHeTuDuongDan("/doi-mat-khau")).toBeNull();
    expect(phanHeTuDuongDan("/them")).toBeNull();
  });

  it("không nhận nhầm đường dẫn chỉ trùng phần đầu chữ", () => {
    expect(phanHeTuDuongDan("/khoan-vay")).toBeNull();
    expect(phanHeTuDuongDan("/tai-chinh-cu")).toBeNull();
  });

  it("thứ tự cố định Tài chính · Nhân sự · Kho · Hệ thống", () => {
    expect(DS_PHAN_HE.map((p) => p.ma)).toEqual(["tc", "ns", "kho", "ht"]);
  });
});
