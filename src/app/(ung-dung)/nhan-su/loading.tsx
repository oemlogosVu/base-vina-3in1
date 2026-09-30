/**
 * Màn chờ dùng chung cho mọi trang.
 *
 * Mọi trang trong app đều là server component đọc dữ liệu, nên chuyển tab
 * phải chờ server trả về mới thấy gì. Trước khi có file này, người dùng bấm
 * xong thì màn hình đứng im — không biết đã bấm trúng chưa, nên hay bấm lại.
 *
 * Có `loading.tsx` thì Next hiện khung này NGAY khi bấm, rồi thay bằng nội
 * dung thật khi server trả về. Nó không làm server nhanh hơn, nhưng làm cảm
 * giác chậm biến mất — và đó là phần lớn cái "chậm" mà người dùng cảm thấy.
 *
 * Nó còn một tác dụng thật: Next chỉ tải trước (prefetch) route động tới ranh
 * giới loading. Không có file này thì không có gì để tải trước.
 */

function Vach({ rong }: { rong: string }) {
  return <div className={`h-4 ${rong} animate-pulse rounded bg-slate-200 dark:bg-slate-800`} />
}

export default function DangTai() {
  return (
    <div className="min-h-dvh">
      <header className="border-b border-slate-200 bg-white dark:border-slate-800 dark:bg-slate-900">
        <div className="mx-auto flex w-full max-w-5xl items-center gap-5 px-4 py-3">
          <span className="font-semibold">HR Base Vina</span>
          <Vach rong="w-64" />
        </div>
      </header>

      <main className="mx-auto w-full max-w-5xl px-4 py-8" aria-busy="true" aria-live="polite">
        <span className="sr-only">Đang tải…</span>
        <div className="mb-6 h-8 w-56 animate-pulse rounded bg-slate-200 dark:bg-slate-800" />

        {[0, 1].map((i) => (
          <section
            key={i}
            className="mb-6 space-y-3 rounded-xl border border-slate-200 bg-white p-5 dark:border-slate-800 dark:bg-slate-900"
          >
            <Vach rong="w-40" />
            <Vach rong="w-full" />
            <Vach rong="w-5/6" />
            <Vach rong="w-2/3" />
          </section>
        ))}
      </main>
    </div>
  )
}
