import { useEffect, useState } from 'react'
import { UtensilsCrossed, ClipboardList, Languages, ShieldCheck } from 'lucide-react'
import { api } from '../api/client'
import type { Food, RegionalNameSubmission, TempFood } from '../types'

interface StatCardProps {
  icon: React.ReactNode
  label: string
  value: number | string
  color: string
  bg: string
}

function StatCard({ icon, label, value, color, bg }: StatCardProps) {
  return (
    <div className="bg-white rounded-2xl p-6 shadow-sm border border-gray-100">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm text-gray-500 mb-1">{label}</p>
          <p className="text-3xl font-bold text-gray-800">{value}</p>
        </div>
        <div className={`w-12 h-12 rounded-xl ${bg} flex items-center justify-center`}>
          <span className={color}>{icon}</span>
        </div>
      </div>
    </div>
  )
}

function RecentRow({ item }: { item: TempFood }) {
  const name = item.food_name
  const requester = item.requester_name ?? '—'
  const date = new Date(item.submitted_at ?? '').toLocaleDateString('th-TH', {
    day: '2-digit',
    month: 'short',
    year: '2-digit',
  })

  return (
    <tr className="border-b border-gray-50 hover:bg-gray-50 transition">
      <td className="py-3 px-4 text-sm font-medium text-gray-800">{name}</td>
      <td className="py-3 px-4 text-sm text-gray-500">{requester}</td>
      <td className="py-3 px-4 text-sm text-gray-400">{date}</td>
      <td className="py-3 px-4">
        <span className="text-xs font-medium px-2.5 py-1 rounded-full bg-yellow-50 text-yellow-700 border border-yellow-200">
          คำขอเมนูใหม่
        </span>
      </td>
    </tr>
  )
}

export default function Dashboard() {
  const [foods, setFoods] = useState<Food[]>([])
  const [tempFoods, setTempFoods] = useState<TempFood[]>([])
  const [regionalNames, setRegionalNames] = useState<RegionalNameSubmission[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    Promise.all([
      api.getFoods(),
      api.getTempFoods('pending'),
      api.getRegionalNameSubmissions('pending'),
    ])
      .then(([f, t, regional]) => {
        setFoods(f as Food[])
        setTempFoods(t as TempFood[])
        setRegionalNames(regional as RegionalNameSubmission[])
      })
      .catch(console.error)
      .finally(() => setLoading(false))
  }, [])

  const pendingTotal = tempFoods.length + regionalNames.length
  const recentItems = tempFoods.slice(0, 5)

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="w-8 h-8 border-4 border-[#628141] border-t-transparent rounded-full animate-spin" />
      </div>
    )
  }

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-gray-800">Dashboard</h2>
        <p className="text-sm text-gray-500 mt-1">ภาพรวมระบบ Calories Guard</p>
      </div>

      {/* Stat cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4">
        <StatCard
          icon={<UtensilsCrossed size={22} />}
          label="เมนูอาหารทั้งหมด"
          value={foods.length}
          color="text-[#628141]"
          bg="bg-[#E8EFCF]"
        />
        <StatCard
          icon={<ShieldCheck size={22} />}
          label="รอดำเนินการทั้งหมด"
          value={pendingTotal}
          color="text-orange-600"
          bg="bg-orange-50"
        />
        <StatCard
          icon={<ClipboardList size={22} />}
          label="คำขอเมนูใหม่รอตรวจ"
          value={tempFoods.length}
          color="text-yellow-600"
          bg="bg-yellow-50"
        />
        <StatCard
          icon={<Languages size={22} />}
          label="ชื่อท้องถิ่นรอตรวจ"
          value={regionalNames.length}
          color="text-blue-600"
          bg="bg-blue-50"
        />
      </div>

      {/* Recent requests table */}
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
        <div className="px-6 py-4 border-b border-gray-100">
          <h3 className="font-semibold text-gray-800">คำขอเพิ่มเมนูล่าสุด</h3>
        </div>
        {recentItems.length === 0 ? (
          <div className="py-12 text-center text-gray-400 text-sm">ไม่มีคำขอรอดำเนินการ 🎉</div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-gray-50">
                <tr>
                  <th className="py-3 px-4 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide">ชื่อเมนู</th>
                  <th className="py-3 px-4 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide">ผู้ขอ</th>
                  <th className="py-3 px-4 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide">วันที่</th>
                  <th className="py-3 px-4 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide">ประเภท</th>
                </tr>
              </thead>
              <tbody>
                {recentItems.map((item, i) => (
                  <RecentRow key={i} item={item} />
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  )
}
