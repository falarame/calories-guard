import { useState, type FormEvent } from 'react'
import { useNavigate } from 'react-router-dom'
import { Eye, EyeOff, Loader2 } from 'lucide-react'
import { api } from '../api/client'
import { useAuth } from '../context/AuthContext'

export default function Login() {
  const { login } = useAuth()
  const navigate = useNavigate()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [showPw, setShowPw] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault()
    setError('')
    setLoading(true)
    try {
      const res = await api.login(email, password)
      if (res.role_id !== 1) {
        setError('บัญชีนี้ไม่มีสิทธิ์เข้าใช้งาน Admin Panel')
        return
      }
      if (!res.access_token) {
        setError('เซิร์ฟเวอร์ไม่ได้ส่ง access token — โปรดอัปเดต backend')
        return
      }
      login({
        user_id: res.user_id,
        username: res.username,
        email: res.email,
        role_id: res.role_id,
        access_token: res.access_token,
      })
      navigate('/', { replace: true })
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'เข้าสู่ระบบไม่สำเร็จ')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-[#2D4A1C] via-[#3e5828] to-[#628141] flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        {/* Logo card */}
        <div className="flex flex-col items-center mb-8">
          <div className="w-16 h-16 rounded-2xl bg-white flex items-center justify-center shadow-xl mb-4 overflow-hidden">
            <img src="/app-icon.png" alt="Calories Guard" className="w-14 h-14 object-contain" />
          </div>
          <h1 className="text-2xl font-bold text-white">Calories Guard</h1>
          <p className="text-white/60 text-sm mt-1">Admin Panel</p>
        </div>

        {/* Form card */}
        <div className="bg-white rounded-2xl shadow-2xl p-8">
          <h2 className="text-xl font-semibold text-gray-800 mb-6">เข้าสู่ระบบ</h2>

          {error && (
            <div className="mb-4 px-4 py-3 bg-red-50 border border-red-200 text-red-700 rounded-xl text-sm">
              {error}
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1.5">อีเมล</label>
              <input
                type="email"
                required
                value={email}
                onChange={e => setEmail(e.target.value)}
                placeholder="admin@example.com"
                className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:outline-none focus:ring-2 focus:ring-[#628141]/40 focus:border-[#628141] text-sm transition"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1.5">รหัสผ่าน</label>
              <div className="relative">
                <input
                  type={showPw ? 'text' : 'password'}
                  required
                  value={password}
                  onChange={e => setPassword(e.target.value)}
                  placeholder="••••••••"
                  className="w-full px-4 py-2.5 pr-10 rounded-xl border border-gray-200 focus:outline-none focus:ring-2 focus:ring-[#628141]/40 focus:border-[#628141] text-sm transition"
                />
                <button
                  type="button"
                  onClick={() => setShowPw(v => !v)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 transition"
                >
                  {showPw ? <EyeOff size={16} /> : <Eye size={16} />}
                </button>
              </div>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full py-2.5 rounded-xl bg-[#628141] hover:bg-[#507034] text-white font-semibold text-sm transition-all shadow-sm disabled:opacity-60 disabled:cursor-not-allowed flex items-center justify-center gap-2 mt-2"
            >
              {loading && <Loader2 size={16} className="animate-spin" />}
              {loading ? 'กำลังเข้าสู่ระบบ...' : 'เข้าสู่ระบบ'}
            </button>
          </form>
        </div>

        <p className="text-center text-white/40 text-xs mt-6">
          เฉพาะผู้ดูแลระบบเท่านั้น (role_id = 1)
        </p>
      </div>
    </div>
  )
}
