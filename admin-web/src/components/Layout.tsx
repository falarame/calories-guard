import { Outlet, NavLink, useNavigate } from 'react-router-dom'
import {
  LayoutDashboard,
  UtensilsCrossed,
  ClipboardList,
  Languages,
  Users,
  LogOut,
  Menu,
  X,
} from 'lucide-react'
import { useState, useEffect } from 'react'
import { useAuth } from '../context/AuthContext'
import { api } from '../api/client'

const nav = [
  { to: '/',              label: 'Dashboard',       icon: LayoutDashboard, end: true },
  { to: '/foods',         label: 'จัดการอาหาร',     icon: UtensilsCrossed, end: false },
  { to: '/food-requests', label: 'คำขอเพิ่มเมนู',   icon: ClipboardList,   end: false },
  { to: '/regional-names', label: 'ชื่อท้องถิ่น',    icon: Languages,       end: false },
  { to: '/users',         label: 'ผู้ใช้งาน',        icon: Users,           end: false },
]

export default function Layout() {
  const { auth, logout } = useAuth()
  const navigate = useNavigate()
  const [open, setOpen] = useState(false)
  const [pendingCount, setPendingCount] = useState({ tempFoods: 0, regionalNames: 0 })

  useEffect(() => {
    const fetch = () => {
      Promise.all([
        api.getPendingCount(),
        api.getRegionalNameSubmissions('pending'),
      ])
        .then(([temp, regional]) => {
          setPendingCount({
            tempFoods: temp.count,
            regionalNames: regional.length,
          })
        })
        .catch(() => {})
    }
    fetch()
    const id = setInterval(fetch, 30_000)
    return () => clearInterval(id)
  }, [])

  const handleLogout = () => {
    logout()
    navigate('/login', { replace: true })
  }

  const Sidebar = ({ mobile = false }: { mobile?: boolean }) => (
    <aside
      className={`flex flex-col h-full bg-[#2D4A1C] text-white ${
        mobile ? 'w-64' : 'w-64 hidden lg:flex'
      }`}
    >
      {/* Logo */}
      <div className="flex items-center gap-3 px-6 py-5 border-b border-white/10">
        <div className="w-9 h-9 rounded-xl bg-white flex items-center justify-center flex-shrink-0 overflow-hidden">
          <img src="/app-icon.png" alt="Calories Guard" className="w-8 h-8 object-contain" />
        </div>
        <div>
          <p className="font-bold text-sm leading-tight">Calories Guard</p>
          <p className="text-[11px] text-white/50">Admin Panel</p>
        </div>
      </div>

      {/* Nav */}
      <nav className="flex-1 px-3 py-4 space-y-1 overflow-y-auto">
        {nav.map(({ to, label, icon: Icon, end }) => (
          <NavLink
            key={to}
            to={to}
            end={end}
            onClick={() => setOpen(false)}
            className={({ isActive }) =>
              `flex items-center gap-3 px-4 py-2.5 rounded-xl text-sm font-medium transition-all ${
                isActive
                  ? 'bg-[#628141] text-white shadow-sm'
                  : 'text-white/70 hover:bg-white/10 hover:text-white'
              }`
            }
          >
            <Icon size={18} />
            <span className="flex-1">{label}</span>
            {to === '/food-requests' && pendingCount.tempFoods > 0 && (
              <span className="ml-auto min-w-[20px] h-5 px-1.5 rounded-full bg-red-500 text-white text-[11px] font-bold flex items-center justify-center">
                {pendingCount.tempFoods > 99 ? '99+' : pendingCount.tempFoods}
              </span>
            )}
            {to === '/regional-names' && pendingCount.regionalNames > 0 && (
              <span className="ml-auto min-w-[20px] h-5 px-1.5 rounded-full bg-red-500 text-white text-[11px] font-bold flex items-center justify-center">
                {pendingCount.regionalNames > 99 ? '99+' : pendingCount.regionalNames}
              </span>
            )}
          </NavLink>
        ))}
      </nav>

      {/* Footer */}
      <div className="px-4 py-4 border-t border-white/10">
        <div className="flex items-center gap-3 px-3 py-2 mb-2">
          <div className="w-8 h-8 rounded-full bg-[#AFD198] flex items-center justify-center text-[#2D4A1C] font-bold text-sm flex-shrink-0">
            {auth?.username?.[0]?.toUpperCase() ?? 'A'}
          </div>
          <div className="min-w-0">
            <p className="text-sm font-medium truncate">{auth?.username}</p>
            <p className="text-[11px] text-white/50 truncate">{auth?.email}</p>
          </div>
        </div>
        <button
          onClick={handleLogout}
          className="flex items-center gap-2 w-full px-4 py-2.5 rounded-xl text-sm text-white/70 hover:bg-red-500/20 hover:text-red-300 transition-all"
        >
          <LogOut size={16} />
          ออกจากระบบ
        </button>
      </div>
    </aside>
  )

  return (
    <div className="flex h-screen overflow-hidden bg-[#f5f7f2]">
      {/* Desktop sidebar */}
      <Sidebar />

      {/* Mobile overlay */}
      {open && (
        <div className="fixed inset-0 z-40 lg:hidden">
          <div className="absolute inset-0 bg-black/50" onClick={() => setOpen(false)} />
          <div className="absolute left-0 top-0 h-full z-50">
            <Sidebar mobile />
          </div>
        </div>
      )}

      {/* Main */}
      <div className="flex-1 flex flex-col min-w-0 overflow-hidden">
        {/* Topbar */}
        <header className="bg-white border-b border-gray-200 px-6 py-4 flex items-center gap-4 flex-shrink-0">
          <button
            className="lg:hidden p-2 rounded-lg hover:bg-gray-100 transition"
            onClick={() => setOpen(!open)}
          >
            {open ? <X size={20} /> : <Menu size={20} />}
          </button>
          <h1 className="text-gray-800 font-semibold text-base flex-1">
            Calories Guard — Admin
          </h1>
          <span className="hidden sm:inline-flex items-center gap-1 text-xs bg-brand-100 text-brand-700 px-3 py-1 rounded-full font-medium">
            <span className="w-1.5 h-1.5 rounded-full bg-green-500 inline-block" />
            Online
          </span>
        </header>

        {/* Page content */}
        <main className="flex-1 overflow-y-auto p-6">
          <Outlet />
        </main>
      </div>
    </div>
  )
}
