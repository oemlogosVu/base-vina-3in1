"use client";

import { useActionState, useState } from "react";
import { useFormStatus } from "react-dom";

import { ThongBao } from "@/shared/ui/hien-thi";
import { Nut } from "@/shared/ui/nut";

import { dangNhap, type KetQuaDangNhap } from "./actions";

function NutGui() {
  const { pending } = useFormStatus();
  return (
    <Nut type="submit" className="mt-5 w-full" dangXuLy={pending} nhanDangXuLy="Đang đăng nhập…">
      Đăng nhập
    </Nut>
  );
}

export function FormDangNhap({ tiepTuc }: { tiepTuc: string }) {
  const [ketQua, formAction] = useActionState<KetQuaDangNhap, FormData>(
    dangNhap,
    undefined,
  );
  // Nút "Hiện" mật khẩu: gõ trên điện thoại rất dễ sai một ký tự mà không biết.
  const [hienMatKhau, datHienMatKhau] = useState(false);

  return (
    <form action={formAction}>
      <input type="hidden" name="tiep_tuc" value={tiepTuc} />

      <label htmlFor="id" className="nhan-o">
        Email hoặc số điện thoại
      </label>
      <input
        id="id"
        name="id"
        type="text"
        inputMode="email"
        required
        autoComplete="username"
        autoCapitalize="none"
        className="o-nhap"
      />

      <label htmlFor="mat_khau" className="nhan-o mt-4">
        Mật khẩu
      </label>
      <div className="flex gap-2">
        <input
          id="mat_khau"
          name="mat_khau"
          type={hienMatKhau ? "text" : "password"}
          required
          autoComplete="current-password"
          className="o-nhap min-w-0 flex-1"
        />
        <button
          type="button"
          onClick={() => datHienMatKhau((v) => !v)}
          aria-pressed={hienMatKhau}
          aria-controls="mat_khau"
          className="nut-phu min-h-12 w-16 rounded-[10px] px-0"
        >
          {hienMatKhau ? "Ẩn" : "Hiện"}
        </button>
      </div>

      {ketQua?.loi && (
        <ThongBao loai="loi" className="mt-4">
          {ketQua.loi}
        </ThongBao>
      )}

      <NutGui />
    </form>
  );
}
