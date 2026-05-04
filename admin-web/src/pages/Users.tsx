import { useEffect, useState } from 'react'
import { Search, User, Loader2, Flame, RefreshCw, X, Pencil, Trash2, Star, Award, Shield } from 'lucide-react'
import { api } from '../api/client'
import type { UserDetail } from '../types'

interface UserRow {
  user_id: number
  username: string
  email: string
  role_id: number
  created_at: string
  last_login_date?: string
  current_streak?: number
  total_login_days?: number
  deleted_at?: string | null
}

const TIER_LABELS = [
  { name: 'ติ๊ด', emoji: '🌰', minPts: 0 },
  { name: 'ต้อย', emoji: '🌱', minPts: 100 },
  { name: 'แต้ว', emoji: '🪴', minPts: 300 },
  { name: 'โต้ง', emoji: '🌿', minPts: 600 },
  { name: 'พราว', emoji: '🌾', minPts: 1000 },
  { name: 'วิ้งค์', emoji: '✨', minPts: 2000 },
]

function UserModal({
  userId, onClose, onUpdated,
}: {
  userId: number
  onClose: () => void
  onUpdated: () => void
}) {
  const [detail, setDetail] = useState<UserDetail | null>(null)
  const [loading, setLoading] = useState(true)
  const [tab, setTab] = useState<'info' | 'edit' | 'tama'>('info')

  // edit fields
  const [username, setUsername] = useState('')
  const [email, setEmail] = useState('')
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [toast, setToast] = useState('')

  // tama fields
  const [tamaPoints, setTamaPoints] = useState(0)
  const [tierLevel, setTierLevel] = useState(0)

  const showToast = (msg: string) => {
    setToast(msg)
    setTimeout(() => setToast(''), 2500)
  }

  useEffect(() => {
    api.getAdminUser(userId)
      .then((d: UserDetail) => {
        setDetail(d)
        setUsername(d.username)
        setEmail(d.email)
        setTamaPoints(d.tama_points)
        setTierLevel(d.tier_level)
      })
      .catch(console.error)
      .finally(() => setLoading(false))
  }, [userId])

  const handleSaveInfo = async () => {
    setError('')
    setSaving(true)
    try {
      await api.updateAdminUser(userId, { username, email })
      showToast('✅ บันทึกข้อมูลสำเร็จ')
      onUpdated()
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'เกิดข้อผิดพลาด')
    } finally {
      setSaving(false)
    }
  }

  const handleSaveTama = async () => {
    setError('')
    setSaving(true)
    try {
      await api.updateAdminUserTama(userId, { tama_points: tamaPoints, tier_level: tierLevel })
      showToast('✅ อัปเดต tama สำเร็จ')
      onUpdated()
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'เกิดข้อผิดพลาด')
    } finally {
      setSaving(false)
    }
  }

  const handleDelete = async () => {
    if (!confirm(`⚠️ ลบบัญชี "${detail?.username}" ถาวร?\n\nข้อมูลทั้งหมดของ user นี้จะหายไปจาก Database ไม่สามารถกู้คืนได้`)) return
    try {
      await api.deleteAdminUser(userId)
      showToast('🗑️ ลบบัญชีและข้อมูลทั้งหมดสำเร็จ')
      onUpdated()
      setTimeout(onClose, 1500)
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'เกิดข้อผิดพลาด')
    }
  }

  const inputCls = 'w-full px-3 py-2 rounded-lg border border-gray-200 focus:outline-none focus:ring-2 focus:ring-[#628141]/30 focus:border-[#628141] text-sm'

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md max-h-[92vh] overflow-y-auto">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100">
          <h3 className="font-semibold text-gray-800">จัดการผู้ใช้ #{userId}</h3>
          <button onClick={onClose} className="p-1.5 rounded-lg hover:bg-gray-100 transition">
            <X size={18} className="text-gray-500" />
          </button>
        </div>

        {toast && (
          <div className="mx-6 mt-4 px-4 py-2.5 bg-gray-800 text-white text-sm rounded-xl">{toast}</div>
        )}
        {error && (
          <div className="mx-6 mt-4 px-4 py-2.5 bg-red-50 text-red-700 border border-red-200 text-sm rounded-xl">{error}</div>
        )}

        {loading ? (
          <div className="flex items-center justify-center py-16"><Loader2 size={28} className="animate-spin text-[#628141]" /></div>
        ) : detail ? (
          <>
            {/* User avatar + name */}
            <div className="px-6 pt-5 pb-3 flex items-center gap-3">
              <div className="w-12 h-12 rounded-full bg-[#E8EFCF] flex items-center justify-center">
                <User size={22} className="text-[#628141]" />
              </div>
              <div>
                <p className="font-bold text-gray-800">{detail.username}</p>
                <p className="text-xs text-gray-500">{detail.email}</p>
                {detail.deleted_at && (
                  <span className="text-xs text-red-500 font-medium">🚫 ถูกลบแล้ว</span>
                )}
              </div>
            </div>

            {/* Tab bar */}
            <div className="flex border-b border-gray-100 px-6">
              {([['info', 'ข้อมูล', Shield], ['edit', 'แก้ไข', Pencil], ['tama', 'Tama', Star]] as const).map(([t, label, Icon]) => (
                <button
                  key={t}
                  onClick={() => setTab(t)}
                  className={`flex items-center gap-1.5 px-4 py-2.5 text-sm font-medium border-b-2 transition ${
                    tab === t ? 'border-[#628141] text-[#628141]' : 'border-transparent text-gray-500 hover:text-gray-700'
                  }`}
                >
                  <Icon size={13} /> {label}
                </button>
              ))}
            </div>

            <div className="px-6 py-5 space-y-3">
              {/* ── Info tab ── */}
              {tab === 'info' && (
                <>
                  {[
                    ['Role', detail.role_id === 1 ? '👑 Admin' : '👤 User'],
                    ['Streak', `🔥 ${detail.current_streak ?? 0} วัน`],
                    ['วันใช้งานทั้งหมด', `${detail.total_login_days ?? 0} วัน`],
                    ['Login ล่าสุด', detail.last_login_date ? new Date(detail.last_login_date).toLocaleDateString('th-TH') : '—'],
                    ['สมัครเมื่อ', new Date(detail.created_at).toLocaleDateString('th-TH')],
                  ].map(([label, value]) => (
                    <div key={label} className="flex justify-between text-sm">
                      <span className="text-gray-500">{label}</span>
                      <span className="font-medium text-gray-800">{value}</span>
                    </div>
                  ))}
                  {/* Tama summary */}
                  <div className="mt-4 p-3 bg-[#f5f9f0] rounded-xl border border-[#E8EFCF] space-y-2">
                    <p className="text-xs font-semibold text-[#628141] uppercase tracking-wide">Tama Summary</p>
                    <div className="flex justify-between text-sm">
                      <span className="text-gray-500">แต้ม Tama</span>
                      <span className="font-bold text-[#628141]">⭐ {detail.tama_points.toLocaleString()}</span>
                    </div>
                    <div className="flex justify-between text-sm">
                      <span className="text-gray-500">ระดับ</span>
                      <span className="font-medium text-gray-800">{TIER_LABELS[detail.tier_level]?.emoji ?? ''} {TIER_LABELS[detail.tier_level]?.name ?? `Lv.${detail.tier_level}`}</span>
                    </div>
                    <div className="flex justify-between text-sm">
                      <span className="text-gray-500">Badge ที่ได้รับ</span>
                      <span className="font-medium text-gray-800 flex items-center gap-1">
                        <Award size={13} className="text-yellow-500" />
                        {detail.claimed_badges?.length ?? 0} badge
                      </span>
                    </div>
                    {detail.claimed_badges?.length > 0 && (
                      <div className="flex flex-wrap gap-1 pt-1">
                        {detail.claimed_badges.map(b => (
                          <span key={b} className="text-xs bg-yellow-100 text-yellow-700 px-2 py-0.5 rounded-full">{b}</span>
                        ))}
                      </div>
                    )}
                  </div>
                  {/* Action buttons */}
                  <div className="flex gap-2 pt-2">
                    <button
                      onClick={handleDelete}
                      className="flex-1 flex items-center justify-center gap-2 py-2 rounded-xl bg-red-50 text-red-600 text-sm font-medium hover:bg-red-100 transition"
                    >
                      <Trash2 size={14} /> ลบบัญชีถาวร
                    </button>
                  </div>
                </>
              )}

              {/* ── Edit tab ── */}
              {tab === 'edit' && (
                <div className="space-y-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">ชื่อผู้ใช้</label>
                    <input value={username} onChange={e => setUsername(e.target.value)} className={inputCls} />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">อีเมล</label>
                    <input type="email" value={email} onChange={e => setEmail(e.target.value)} className={inputCls} />
                  </div>
                  <button
                    onClick={handleSaveInfo}
                    disabled={saving}
                    className="w-full py-2.5 rounded-xl bg-[#628141] text-white text-sm font-semibold hover:bg-[#507034] transition disabled:opacity-60 flex items-center justify-center gap-2"
                  >
                    {saving && <Loader2 size={14} className="animate-spin" />}
                    บันทึกการแก้ไข
                  </button>
                </div>
              )}

              {/* ── Tama tab ── */}
              {tab === 'tama' && (
                <div className="space-y-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">แต้ม Tama</label>
                    <input type="number" min={0} value={tamaPoints} onChange={e => setTamaPoints(Number(e.target.value))} className={inputCls} />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      ระดับ Tama — ปัจจุบัน: {TIER_LABELS[tierLevel]?.emoji} {TIER_LABELS[tierLevel]?.name ?? `Lv.${tierLevel}`}
                    </label>
                    <select value={tierLevel} onChange={e => setTierLevel(Number(e.target.value))} className={inputCls}>
                      {TIER_LABELS.map((t, i) => (
                        <option key={i} value={i}>{t.emoji} {t.name} ({t.minPts}+ แต้ม)</option>
                      ))}
                    </select>
                  </div>
                  <div className="p-3 bg-[#f5f9f0] rounded-xl border border-[#E8EFCF]">
                    <p className="text-xs text-gray-500 mb-2 font-medium">Badge ที่ได้รับ ({detail.claimed_badges?.length ?? 0})</p>
                    {detail.claimed_badges?.length > 0 ? (
                      <div className="flex flex-wrap gap-1">
                        {detail.claimed_badges.map(b => (
                          <span key={b} className="text-xs bg-yellow-100 text-yellow-700 px-2 py-0.5 rounded-full">{b}</span>
                        ))}
                      </div>
                    ) : (
                      <p className="text-xs text-gray-400">ยังไม่มี badge</p>
                    )}
                  </div>
                  <button
                    onClick={handleSaveTama}
                    disabled={saving}
                    className="w-full py-2.5 rounded-xl bg-[#628141] text-white text-sm font-semibold hover:bg-[#507034] transition disabled:opacity-60 flex items-center justify-center gap-2"
                  >
                    {saving && <Loader2 size={14} className="animate-spin" />}
                    บันทึก Tama
                  </button>
                </div>
              )}
            </div>
          </>
        ) : (
          <div className="py-16 text-center text-gray-400 text-sm">ไม่พบข้อมูล</div>
        )}
      </div>
    </div>
  )
}

export default function Users() {
  const [users, setUsers] = useState<UserRow[]>([])
  const [search, setSearch] = useState('')
  const [loading, setLoading] = useState(true)
  const [selectedId, setSelectedId] = useState<number | null>(null)

  const load = (q = '') => {
    setLoading(true)
    api.getAdminUsers(q)
      .then(data => setUsers(data as UserRow[]))
      .catch(console.error)
      .finally(() => setLoading(false))
  }

  useEffect(() => { load() }, [])

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault()
    load(search)
  }

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-gray-800">ผู้ใช้งาน</h2>
          <p className="text-sm text-gray-500 mt-0.5">ทั้งหมด {users.length} บัญชี</p>
        </div>
        <button onClick={() => load(search)} className="p-2 rounded-xl hover:bg-white border border-gray-200 transition" title="รีเฟรช">
          <RefreshCw size={16} className="text-gray-500" />
        </button>
      </div>

      {/* Search */}
      <form onSubmit={handleSearch} className="flex gap-3">
        <div className="relative flex-1 max-w-sm">
          <Search size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" />
          <input
            type="text"
            placeholder="ค้นหาด้วยชื่อหรืออีเมล..."
            value={search}
            onChange={e => setSearch(e.target.value)}
            className="w-full pl-10 pr-4 py-2.5 rounded-xl border border-gray-200 focus:outline-none focus:ring-2 focus:ring-[#628141]/30 focus:border-[#628141] text-sm bg-white"
          />
        </div>
        <button
          type="submit"
          className="px-5 py-2.5 rounded-xl bg-[#628141] text-white text-sm font-semibold hover:bg-[#507034] transition flex items-center gap-2"
        >
          <Search size={15} /> ค้นหา
        </button>
      </form>

      {/* Table */}
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
        {loading ? (
          <div className="flex items-center justify-center py-16">
            <Loader2 size={28} className="animate-spin text-[#628141]" />
          </div>
        ) : users.length === 0 ? (
          <div className="py-16 text-center text-gray-400 text-sm">ไม่พบผู้ใช้งาน</div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-gray-50 border-b border-gray-100">
                <tr>
                  <th className="py-3 px-4 text-left text-xs font-semibold text-gray-500 uppercase">ID</th>
                  <th className="py-3 px-4 text-left text-xs font-semibold text-gray-500 uppercase">ชื่อผู้ใช้</th>
                  <th className="py-3 px-4 text-left text-xs font-semibold text-gray-500 uppercase">อีเมล</th>
                  <th className="py-3 px-4 text-center text-xs font-semibold text-gray-500 uppercase">Role</th>
                  <th className="py-3 px-4 text-center text-xs font-semibold text-gray-500 uppercase">Streak</th>
                  <th className="py-3 px-4 text-center text-xs font-semibold text-gray-500 uppercase">วันใช้งาน</th>
                  <th className="py-3 px-4 text-left text-xs font-semibold text-gray-500 uppercase">สมัครเมื่อ</th>
                  <th className="py-3 px-4 text-center text-xs font-semibold text-gray-500 uppercase">จัดการ</th>
                </tr>
              </thead>
              <tbody>
                {users.map(u => (
                  <tr key={u.user_id} className={`border-b border-gray-50 hover:bg-gray-50 transition ${u.deleted_at ? 'opacity-50' : ''}`}>
                    <td className="py-3 px-4 text-gray-400 text-xs">#{u.user_id}</td>
                    <td className="py-3 px-4">
                      <div className="flex items-center gap-2">
                        <div className="w-7 h-7 rounded-full bg-[#E8EFCF] flex items-center justify-center">
                          <User size={13} className="text-[#628141]" />
                        </div>
                        <div>
                          <span className="font-medium text-gray-800">{u.username}</span>
                          {u.deleted_at && <span className="ml-1 text-xs text-red-400">🚫</span>}
                        </div>
                      </div>
                    </td>
                    <td className="py-3 px-4 text-gray-500">{u.email}</td>
                    <td className="py-3 px-4 text-center">
                      <span className={`text-xs font-semibold px-2.5 py-1 rounded-full ${
                        u.role_id === 1 ? 'bg-purple-100 text-purple-700' : 'bg-[#E8EFCF] text-[#628141]'
                      }`}>
                        {u.role_id === 1 ? '👑 Admin' : '👤 User'}
                      </span>
                    </td>
                    <td className="py-3 px-4 text-center">
                      <span className="flex items-center justify-center gap-1 text-orange-500 font-semibold text-xs">
                        <Flame size={12} /> {u.current_streak ?? 0}
                      </span>
                    </td>
                    <td className="py-3 px-4 text-center text-gray-600 text-xs">{u.total_login_days ?? 0} วัน</td>
                    <td className="py-3 px-4 text-gray-400 text-xs">
                      {u.created_at ? new Date(u.created_at).toLocaleDateString('th-TH') : '—'}
                    </td>
                    <td className="py-3 px-4 text-center">
                      <button
                        onClick={() => setSelectedId(u.user_id)}
                        className="p-2 rounded-lg hover:bg-[#E8EFCF] text-[#628141] transition"
                        title="จัดการ"
                      >
                        <Pencil size={14} />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {selectedId !== null && (
        <UserModal
          userId={selectedId}
          onClose={() => setSelectedId(null)}
          onUpdated={() => load(search)}
        />
      )}
    </div>
  )
}
