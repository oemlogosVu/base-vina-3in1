'use client'

import { useCallback, useEffect, useRef, useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@ns/lib/supabase/client'
import type { CheckType } from '@ns/types/database'

/**
 * Nút chấm công: bấm vào/ra, kèm ảnh nếu muốn.
 *
 * Từ 11/08/2026 KHÔNG còn lấy vị trí. Không dùng để đối chiếu thì thu thập
 * toạ độ là thu thập dữ liệu cá nhân không có mục đích.
 *
 * Ảnh là TUỲ CHỌN — bật camera thì có ảnh kèm, không bật vẫn chấm được. Vì
 * vậy màn này không tự xin quyền camera lúc vào: xin quyền cho một thứ không
 * bắt buộc là cách nhanh nhất khiến người dùng bấm "chặn" cho mọi lần sau.
 *
 * Lần chấm nào cũng chờ nhân sự xác nhận rồi mới được tính công. Nói rõ điều
 * đó ngay sau khi bấm, để không ai tưởng đã xong việc.
 */

type KetQua = {
  logged_at: string
  co_anh: boolean
  canh_bao: string | null
  thong_bao: string
}

export function NutChamCong() {
  const router = useRouter()
  const videoRef = useRef<HTMLVideoElement>(null)
  const streamRef = useRef<MediaStream | null>(null)

  const [dangGui, setDangGui] = useState(false)
  const [loi, setLoi] = useState<string | null>(null)
  const [ketQua, setKetQua] = useState<KetQua | null>(null)
  const [camera, setCamera] = useState<'tat' | 'dang-mo' | 'bat' | 'khong-duoc'>('tat')

  useEffect(() => {
    return () => {
      streamRef.current?.getTracks().forEach((t) => t.stop())
    }
  }, [])

  async function batCamera() {
    setCamera('dang-mo')
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: 'user', width: 640, height: 480 },
        audio: false,
      })
      streamRef.current = stream
      if (videoRef.current) videoRef.current.srcObject = stream
      setCamera('bat')
    } catch {
      setCamera('khong-duoc')
    }
  }

  function tatCamera() {
    streamRef.current?.getTracks().forEach((t) => t.stop())
    streamRef.current = null
    if (videoRef.current) videoRef.current.srcObject = null
    setCamera('tat')
  }

  const chup = useCallback((): string | null => {
    const video = videoRef.current
    if (!video || video.videoWidth === 0) return null
    const canvas = document.createElement('canvas')
    canvas.width = video.videoWidth
    canvas.height = video.videoHeight
    const ctx = canvas.getContext('2d')
    if (!ctx) return null
    ctx.drawImage(video, 0, 0)
    return canvas.toDataURL('image/jpeg', 0.7)
  }, [])

  async function gui(checkType: CheckType) {
    setLoi(null)
    setKetQua(null)
    setDangGui(true)

    try {
      const supabase = createClient()
      const { data, error } = await supabase.functions.invoke('cham-cong', {
        body: {
          check_type: checkType,
          // Chỉ gửi ảnh khi camera đang bật. Không có ảnh vẫn chấm được.
          selfie_base64: camera === 'bat' ? chup() : null,
          device_info: { userAgent: navigator.userAgent },
        },
      })

      if (error) {
        let thongBao = 'Không gửi được. Kiểm tra mạng rồi thử lại.'
        try {
          const than = await error.context.json()
          if (typeof than?.loi === 'string') thongBao = than.loi
        } catch {
          // Không đọc được thân lỗi thì giữ thông báo chung — không nuốt im lặng.
        }
        throw new Error(thongBao)
      }

      setKetQua(data as KetQua)
      router.refresh()
    } catch (e) {
      setLoi(e instanceof Error ? e.message : 'Có lỗi không xác định.')
    } finally {
      setDangGui(false)
    }
  }

  return (
    <div className="space-y-4">
      <div>
        <p className="mb-2 text-sm font-medium">Giờ hành chính</p>
        <div className="flex gap-3">
          <button
            type="button"
            onClick={() => gui('in')}
            disabled={dangGui}
            className="flex-1 rounded-lg bg-slate-900 px-4 py-4 text-lg font-medium text-white disabled:opacity-50 dark:bg-slate-100 dark:text-slate-900"
          >
            {dangGui ? 'Đang gửi…' : 'Chấm vào'}
          </button>
          <button
            type="button"
            onClick={() => gui('out')}
            disabled={dangGui}
            className="flex-1 rounded-lg border border-slate-300 px-4 py-4 text-lg font-medium disabled:opacity-50 dark:border-slate-700"
          >
            {dangGui ? 'Đang gửi…' : 'Chấm ra'}
          </button>
        </div>
      </div>

      {/*
        Làm thêm giờ để riêng, không gộp chung với hai nút trên: bấm nhầm
        "chấm ra" thành "thêm giờ ra" là sai cả bảng công lẫn bảng lương.
        Tách khối, đổi màu, và ghi rõ nhãn.
      */}
      <div className="rounded-xl border border-amber-300 p-4 dark:border-amber-900">
        <p className="text-sm font-medium">Làm thêm giờ</p>
        <p className="mb-3 text-sm text-slate-500">
          Chỉ bấm khi thật sự làm thêm ngoài giờ hành chính. Ở lại công ty mà không bấm ở đây
          thì <strong>không được tính là làm thêm</strong>.
        </p>
        <div className="flex gap-3">
          <button
            type="button"
            onClick={() => gui('ot_in')}
            disabled={dangGui}
            className="flex-1 rounded-lg border border-amber-500 px-4 py-3 font-medium text-amber-800 disabled:opacity-50 dark:text-amber-300"
          >
            {dangGui ? 'Đang gửi…' : 'Bắt đầu thêm giờ'}
          </button>
          <button
            type="button"
            onClick={() => gui('ot_out')}
            disabled={dangGui}
            className="flex-1 rounded-lg border border-amber-500 px-4 py-3 font-medium text-amber-800 disabled:opacity-50 dark:text-amber-300"
          >
            {dangGui ? 'Đang gửi…' : 'Kết thúc thêm giờ'}
          </button>
        </div>
      </div>

      <div className="rounded-xl border border-slate-200 p-4 dark:border-slate-800">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <p className="text-sm font-medium">Ảnh kèm theo</p>
            <p className="text-sm text-slate-500">
              Không bắt buộc. Bật camera nếu muốn gửi kèm ảnh làm bằng chứng.
            </p>
          </div>
          {camera === 'bat' ? (
            <button
              type="button"
              onClick={tatCamera}
              className="rounded-lg border border-slate-300 px-4 py-2 text-sm dark:border-slate-700"
            >
              Tắt camera
            </button>
          ) : (
            <button
              type="button"
              onClick={batCamera}
              disabled={camera === 'dang-mo'}
              className="rounded-lg border border-slate-300 px-4 py-2 text-sm disabled:opacity-60 dark:border-slate-700"
            >
              {camera === 'dang-mo' ? 'Đang mở…' : 'Bật camera'}
            </button>
          )}
        </div>

        {camera === 'bat' && (
          <div className="mt-3 overflow-hidden rounded-lg bg-slate-950">
            <video ref={videoRef} autoPlay playsInline muted className="h-56 w-full object-cover" />
          </div>
        )}

        {camera === 'khong-duoc' && (
          <p className="mt-3 rounded-lg bg-amber-50 p-3 text-sm text-amber-900 dark:bg-amber-950 dark:text-amber-200">
            Không dùng được camera. Cho phép truy cập camera trong cài đặt trình duyệt, và nhớ
            rằng camera chỉ hoạt động khi vào bằng địa chỉ https. Bạn vẫn chấm công được mà
            không cần ảnh.
          </p>
        )}
      </div>

      {loi && (
        <p className="rounded-lg bg-rose-50 p-3 text-sm text-rose-900 dark:bg-rose-950 dark:text-rose-200">
          {loi}
        </p>
      )}

      {ketQua && (
        <div className="rounded-lg bg-emerald-50 p-3 text-sm text-emerald-900 dark:bg-emerald-950 dark:text-emerald-200">
          <p className="font-medium">{ketQua.thong_bao}</p>
          {ketQua.co_anh && <p className="mt-1">Đã gửi kèm ảnh.</p>}
          {ketQua.canh_bao && <p className="mt-1">{ketQua.canh_bao}</p>}
        </div>
      )}
    </div>
  )
}
