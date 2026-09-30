import { describe, expect, it } from 'vitest'
import { safeInternalPath } from '@ns/lib/safe-path'

describe('safeInternalPath — chặn open-redirect', () => {
  it('giữ nguyên đường dẫn nội bộ hợp lệ', () => {
    expect(safeInternalPath('/')).toBe('/')
    expect(safeInternalPath('/nhan-su/ho-so-cua-toi')).toBe('/nhan-su/ho-so-cua-toi')
    expect(safeInternalPath('/nhan-su/luong/2026-08?tab=chi-tiet')).toBe('/nhan-su/luong/2026-08?tab=chi-tiet')
  })

  it('loại URL tuyệt đối sang tên miền khác', () => {
    expect(safeInternalPath('https://site-gia-mao.example')).toBe('/')
    expect(safeInternalPath('http://site-gia-mao.example')).toBe('/')
  })

  it('loại dạng protocol-relative //host', () => {
    expect(safeInternalPath('//site-gia-mao.example')).toBe('/')
    expect(safeInternalPath('//site-gia-mao.example/login')).toBe('/')
  })

  it('loại dạng backslash mà một số trình duyệt chuẩn hoá thành //host', () => {
    expect(safeInternalPath('/\\site-gia-mao.example')).toBe('/')
  })

  it('loại giá trị không phải chuỗi', () => {
    expect(safeInternalPath(null)).toBe('/')
    expect(safeInternalPath(undefined)).toBe('/')
    expect(safeInternalPath(42)).toBe('/')
    expect(safeInternalPath(['/nhan-su/ho-so-cua-toi'])).toBe('/')
  })

  it('dùng được fallback tuỳ biến', () => {
    expect(safeInternalPath('https://xau.example', '/dang-nhap')).toBe('/dang-nhap')
  })
})
