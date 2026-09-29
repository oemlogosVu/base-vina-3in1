"use client";

import { useActionState } from "react";
import { useFormStatus } from "react-dom";

import { ThongBao } from "@/shared/ui/hien-thi";
import { Nut } from "@/shared/ui/nut";
import { OTruong } from "@/shared/ui/o-truong";

import { doiMatKhau, type TrangThaiForm } from "./actions";

const BAN_DAU: TrangThaiForm = { loi: null };

function NutGui() {
  const { pending } = useFormStatus();
  return (
    <Nut type="submit" className="mt-5 w-full" dangXuLy={pending} nhanDangXuLy="Đang đổi…">
      Đổi mật khẩu
    </Nut>
  );
}

/** Giao diện theo bộ thành phần của Tài chính; xử lý theo app Nhân sự. */
export function FormDoiMatKhau({ toiThieu }: { toiThieu: number }) {
  const [trangThai, gui] = useActionState(doiMatKhau, BAN_DAU);

  return (
    <form action={gui} className="flex flex-col gap-4">
      <OTruong
        nhan="Mật khẩu hiện tại"
        htmlFor="mat_khau_hien_tai"
        goiY="Nhập lại để chắc chắn là bạn, không phải người ngồi vào máy đang mở sẵn."
      >
        <input
          id="mat_khau_hien_tai"
          name="mat_khau_hien_tai"
          type="password"
          required
          autoComplete="current-password"
          className="o-nhap"
        />
      </OTruong>

      <OTruong
        nhan="Mật khẩu mới"
        htmlFor="mat_khau_moi"
        goiY={`Tối thiểu ${toiThieu} ký tự, có chữ thường, chữ HOA và số.`}
      >
        <input
          id="mat_khau_moi"
          name="mat_khau_moi"
          type="password"
          required
          minLength={toiThieu}
          autoComplete="new-password"
          className="o-nhap"
        />
      </OTruong>

      <OTruong nhan="Nhập lại mật khẩu mới" htmlFor="nhac_lai">
        <input id="nhac_lai" name="nhac_lai" type="password" required autoComplete="new-password" className="o-nhap" />
      </OTruong>

      {trangThai.loi !== null && <ThongBao loai="loi">{trangThai.loi}</ThongBao>}
      {trangThai.xong && <ThongBao loai="thanh-cong">{trangThai.xong}</ThongBao>}

      <NutGui />
    </form>
  );
}
