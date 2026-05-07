import { useEffect, useState, type FormEvent } from 'react'
import { CheckCircle, XCircle, Loader2, X, RefreshCw, AlertTriangle, Upload, ImageOff } from 'lucide-react'
import { api, normalizeImageUrl } from '../api/client'
import { useAuth } from '../context/AuthContext'
import type { TempFood } from '../types'

const FOOD_TYPE_CONFIG: Record<string, { categories: string[]; units: { value: string; label: string }[]; defaultUnit: string }> = {
  dish: {
    categories: ['อาหารไทย', 'อาหารตะวันตก', 'เส้น/ก๋วยเตี๋ยว', 'ข้าวและโจ๊ก', 'ซุป/แกง', 'อาหารนานาชาติ'],
    units: [
      { value: 'serving', label: 'serving' },
      { value: 'plate', label: 'จาน (plate)' },
      { value: 'bowl', label: 'ชาม/ถ้วย (bowl)' },
      { value: 'set', label: 'ชุด (set)' },
      { value: 'box', label: 'กล่อง (box)' },
    ],
    defaultUnit: 'serving',
  },
  raw_ingredient: {
    categories: ['เนื้อสัตว์', 'ผัก', 'เครื่องปรุง', 'ธัญพืช/แป้ง', 'อาหารทะเล', 'ไข่และนม'],
    units: [
      { value: 'g', label: 'กรัม (g)' },
      { value: 'kg', label: 'กิโลกรัม (kg)' },
      { value: 'piece', label: 'ชิ้น (piece)' },
    ],
    defaultUnit: 'g',
  },
  snack: {
    categories: ['ผลไม้', 'ขนมหวาน', 'ขนมขบเคี้ยว', 'ของว่าง'],
    units: [
      { value: 'piece', label: 'ชิ้น/อัน (piece)' },
      { value: 'g', label: 'กรัม (g)' },
      { value: 'bag', label: 'ถุง (bag)' },
      { value: 'box', label: 'กล่อง (box)' },
    ],
    defaultUnit: 'piece',
  },
  beverage: {
    categories: ['เครื่องดื่มร้อน', 'เครื่องดื่มเย็น', 'น้ำผลไม้', 'เครื่องดื่มแอลกอฮอล์', 'น้ำเปล่า/โซดา', 'นมและโยเกิร์ต'],
    units: [
      { value: 'ml', label: 'มิลลิลิตร (ml)' },
      { value: 'glass', label: 'แก้ว (glass)' },
      { value: 'can', label: 'กระป๋อง (can)' },
      { value: 'bottle', label: 'ขวด (bottle)' },
      { value: 'cup', label: 'ถ้วย (cup)' },
    ],
    defaultUnit: 'ml',
  },
}

function NutritionInput({ label, val, set }: { label: string; val: string; set: (v: string) => void }) {
  return (
    <div>
      <label className="block text-xs font-medium text-gray-600 mb-1">{label}</label>
      <input
        type="text"
        inputMode="decimal"
        value={val}
        onChange={e => set(e.target.value)}
        onFocus={e => e.target.select()}
        placeholder="0"
        className="w-full px-3 py-2 rounded-lg border border-gray-200 focus:outline-none focus:ring-2 focus:ring-[#628141]/30 focus:border-[#628141] text-sm"
      />
    </div>
  )
}

function ApproveModal({
  item, onClose, onApprove,
}: {
  item: TempFood
  onClose: () => void
  onApprove: (data: {
    food_name?: string
    calories?: number; protein?: number; carbs?: number; fat?: number
    imageFile?: File
    food_type?: string; food_category?: string
    sodium?: number; sugar?: number; cholesterol?: number; fiber_g?: number
    serving_quantity?: number; serving_unit?: string
  }) => Promise<void>
}) {
  const [foodName, setFoodName]   = useState(item.food_name)
  const [calories, setCalories] = useState(String(item.calories ?? ''))
  const [protein, setProtein]   = useState(String(item.protein  ?? ''))
  const [carbs, setCarbs]       = useState(String(item.carbs    ?? ''))
  const [fat, setFat]           = useState(String(item.fat      ?? ''))
  const [loading, setLoading]   = useState(false)
  const [similars, setSimilars] = useState<any[]>([])
  const [checked, setChecked]   = useState(false)
  const [imageFile, setImageFile] = useState<File | null>(null)
  const [preview, setPreview]     = useState('')
  const [foodType, setFoodType]         = useState('dish')
  const [foodCategory, setFoodCategory] = useState('')
  const [sodium, setSodium]             = useState('')
  const [sugar, setSugar]               = useState('')
  const [cholesterol, setCholesterol]   = useState('')
  const [fiberG, setFiberG]             = useState('0')
  const [servingQty, setServingQty]     = useState('1')
  const [servingUnit, setServingUnit]   = useState('serving')

  const typeConfig = FOOD_TYPE_CONFIG[foodType] ?? FOOD_TYPE_CONFIG.dish

  useEffect(() => {
    setFoodCategory('')
    setServingUnit(FOOD_TYPE_CONFIG[foodType]?.defaultUnit ?? 'serving')
  }, [foodType])

  useEffect(() => {
    api.getSimilarFoods(item.food_name)
      .then(r => { setSimilars(r); setChecked(true) })
      .catch(() => setChecked(true))
  }, [item.food_name])

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    setImageFile(file)
    setPreview(URL.createObjectURL(file))
  }

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault()
    setLoading(true)
    try {
      await onApprove({
        food_name: foodName.trim() || undefined,
        calories: parseFloat(calories) || undefined,
        protein:  parseFloat(protein)  || undefined,
        carbs:    parseFloat(carbs)    || undefined,
        fat:      parseFloat(fat)      || undefined,
        imageFile: imageFile ?? undefined,
        food_type: foodType || undefined,
        food_category: foodCategory || undefined,
        sodium: parseFloat(sodium) || undefined,
        sugar: parseFloat(sugar) || undefined,
        cholesterol: parseFloat(cholesterol) || undefined,
        fiber_g: parseFloat(fiberG) || undefined,
        serving_quantity: parseFloat(servingQty) || undefined,
        serving_unit: servingUnit || undefined,
      })
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100">
          <div>
            <h3 className="font-semibold text-gray-800">อนุมัติเมนู</h3>
          </div>
          <button onClick={onClose} className="p-1.5 rounded-lg hover:bg-gray-100 transition">
            <X size={18} className="text-gray-500" />
          </button>
        </div>

        {/* Duplicate warning */}
        {checked && similars.length > 0 && (
          <div className="mx-6 mt-4 p-3 bg-yellow-50 border border-yellow-200 rounded-xl">
            <div className="flex items-center gap-2 text-yellow-800 font-medium text-sm mb-2">
              <AlertTriangle size={15} />
              พบเมนูที่คล้ายกันในฐานข้อมูลแล้ว ({similars.length} รายการ)
            </div>
            <div className="space-y-1.5">
              {similars.map((s: any) => (
                <div key={s.food_id} className="flex items-center gap-2 text-xs text-yellow-700 bg-yellow-100 px-3 py-1.5 rounded-lg">
                  {s.image_url && (
                    <img src={normalizeImageUrl(s.image_url) ?? ''} className="w-6 h-6 rounded object-cover" />
                  )}
                  <span className="font-medium">{s.food_name}</span>
                  <span className="text-yellow-500 ml-auto">{s.calories} kcal</span>
                </div>
              ))}
            </div>
            <p className="text-xs text-yellow-600 mt-2">ตรวจสอบก่อนว่าไม่ใช่เมนูซ้ำ หรืออาจเป็นชื่อภาษาถิ่นของเมนูเดิม</p>
          </div>
        )}

        <form onSubmit={handleSubmit} className="px-6 py-5 space-y-4">

          {/* ชื่อเมนู */}
          <div>
            <label className="block text-xs font-medium text-gray-600 mb-1">ชื่อเมนู (แก้ไขได้)</label>
            <input
              type="text"
              value={foodName}
              onChange={e => setFoodName(e.target.value)}
              className="w-full px-3 py-2 rounded-lg border border-[#628141] focus:outline-none focus:ring-2 focus:ring-[#628141]/30 text-sm font-medium"
            />
          </div>

          {/* ประเภทและหน่วยบริโภค */}
          <div>
            <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-2">ประเภทและหน่วย</p>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-xs font-medium text-gray-600 mb-1">ประเภทอาหาร</label>
                <select value={foodType} onChange={e => setFoodType(e.target.value)}
                  className="w-full px-3 py-2 rounded-lg border border-gray-200 text-sm focus:outline-none focus:ring-2 focus:ring-[#628141]/30">
                  <option value="dish">อาหารจาน (dish)</option>
                  <option value="raw_ingredient">วัตถุดิบ (raw_ingredient)</option>
                  <option value="snack">ขนม/อาหารว่าง (snack)</option>
                  <option value="beverage">เครื่องดื่ม (beverage)</option>
                </select>
              </div>
              <div>
                <label className="block text-xs font-medium text-gray-600 mb-1">หมวดหมู่</label>
                <select value={foodCategory} onChange={e => setFoodCategory(e.target.value)}
                  className="w-full px-3 py-2 rounded-lg border border-gray-200 text-sm focus:outline-none focus:ring-2 focus:ring-[#628141]/30">
                  <option value="">— ไม่ระบุ —</option>
                  {typeConfig.categories.map(c => <option key={c} value={c}>{c}</option>)}
                </select>
              </div>
              <div>
                <label className="block text-xs font-medium text-gray-600 mb-1">ปริมาณ/ครั้ง</label>
                <input type="number" value={servingQty} onChange={e => setServingQty(e.target.value)}
                  className="w-full px-3 py-2 rounded-lg border border-gray-200 text-sm focus:outline-none focus:ring-2 focus:ring-[#628141]/30" />
              </div>
              <div>
                <label className="block text-xs font-medium text-gray-600 mb-1">หน่วย</label>
                <select value={servingUnit} onChange={e => setServingUnit(e.target.value)}
                  className="w-full px-3 py-2 rounded-lg border border-gray-200 text-sm focus:outline-none focus:ring-2 focus:ring-[#628141]/30">
                  {typeConfig.units.map(u => <option key={u.value} value={u.value}>{u.label}</option>)}
                </select>
              </div>
            </div>
          </div>

          {/* โภชนาการหลัก */}
          <div>
            <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-2">โภชนาการหลัก (จาก User)</p>
            <div className="grid grid-cols-2 gap-3">
              <NutritionInput label="แคลอรี่ (kcal)" val={calories} set={setCalories} />
              <NutritionInput label="โปรตีน (g)"     val={protein}  set={setProtein} />
              <NutritionInput label="คาร์บ (g)"      val={carbs}    set={setCarbs} />
              <NutritionInput label="ไขมัน (g)"      val={fat}      set={setFat} />
            </div>
          </div>

          {/* โภชนาการเพิ่มเติม */}
          <div>
            <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-2">โภชนาการเพิ่มเติม (กรอกเพิ่มถ้ารู้)</p>
            <div className="grid grid-cols-2 gap-3">
              <NutritionInput label="โซเดียม (mg)"   val={sodium}      set={setSodium} />
              <NutritionInput label="น้ำตาล (g)"       val={sugar}       set={setSugar} />
              <NutritionInput label="โคเลสเตอรอล (mg)" val={cholesterol} set={setCholesterol} />
              <NutritionInput label="ไฟเบอร์ (g)"      val={fiberG}      set={setFiberG} />
            </div>
          </div>

          {/* Image upload */}
          <div>
            <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-2">รูปภาพ</p>
            <label className="flex items-center gap-2 px-3 py-2.5 rounded-lg border border-dashed border-gray-300 hover:border-[#628141] hover:bg-[#f5f9f0] cursor-pointer transition text-sm text-gray-500">
              <Upload size={15} />
              {imageFile ? imageFile.name : 'คลิกเลือกรูป...'}
              <input type="file" accept="image/*" className="hidden" onChange={handleFileChange} />
            </label>
            {preview
              ? <img src={preview} className="mt-2 h-20 w-20 object-cover rounded-lg border border-gray-200" />
              : <div className="mt-2 h-10 flex items-center gap-2 text-xs text-gray-400">
                  <ImageOff size={14} />ยังไม่มีรูป — จะตั้งชื่อเป็น food_id_ชื่อไฟล์อัตโนมัติ
                </div>
            }
          </div>
          <div className="flex gap-3 pt-1">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 py-2.5 rounded-xl border border-gray-200 text-sm font-medium text-gray-600 hover:bg-gray-50 transition"
            >
              ยกเลิก
            </button>
            <button
              type="submit"
              disabled={loading}
              className="flex-1 py-2.5 rounded-xl bg-[#628141] text-white text-sm font-semibold hover:bg-[#507034] transition disabled:opacity-60 flex items-center justify-center gap-2"
            >
              {loading && <Loader2 size={14} className="animate-spin" />}
              ✅ ยืนยันอนุมัติ
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

export default function FoodRequests() {
  const { auth } = useAuth()
  const adminId = auth?.user_id ?? 0

  const [tempFoods, setTempFoods] = useState<TempFood[]>([])
  const [loading, setLoading] = useState(true)
  const [toast, setToast] = useState('')
  const [approveModal, setApproveModal] = useState<{ open: boolean; item: TempFood | null }>({
    open: false, item: null,
  })

  const showToast = (msg: string) => {
    setToast(msg)
    setTimeout(() => setToast(''), 3000)
  }

  const load = () => {
    setLoading(true)
    api.getTempFoods('pending')
      .then(t => setTempFoods(t as TempFood[]))
      .catch(console.error)
      .finally(() => setLoading(false))
  }

  useEffect(() => { load() }, [])

  const handleRejectTemp = async (tfId: number) => {
    if (!confirm('ต้องการปฏิเสธเมนูนี้?')) return
    try {
      await api.rejectTempFood(tfId)
      showToast('❌ ปฏิเสธเมนูแล้ว')
      load()
    } catch (e: unknown) {
      alert(e instanceof Error ? e.message : 'เกิดข้อผิดพลาด')
    }
  }

  const handleApproveTemp = async (data: {
    food_name?: string
    calories?: number; protein?: number; carbs?: number; fat?: number
    imageFile?: File
    food_type?: string; food_category?: string
    sodium?: number; sugar?: number; cholesterol?: number; fiber_g?: number
    serving_quantity?: number; serving_unit?: string
  }) => {
    const item = approveModal.item as TempFood
    const { imageFile, ...nutrition } = data

    // 1) approve (โภชนาการ + ข้อมูลเพิ่มเติม) → ได้ food_id กลับมา
    const result = await api.approveTempFood(item.tf_id, adminId, nutrition)

    // 2) ถ้ามีรูป → upload พร้อม food_id → ชื่อไฟล์จะเป็น {food_id}_{ชื่อไฟล์}
    if (imageFile && result?.food_id) {
      const formData = new FormData()
      formData.append('file', imageFile)
      formData.append('food_id', String(result.food_id))
      const BASE = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000'
      const res = await fetch(`${BASE}/upload-image/`, { method: 'POST', body: formData })
      if (res.ok) {
        const { url } = await res.json()
        await api.patchFood(result.food_id, { image_url: url })
      }
    }

    showToast('✅ อนุมัติเมนูแล้ว')
    setApproveModal({ open: false, item: null })
    load()
  }

  return (
    <div className="space-y-5">
      {/* Toast */}
      {toast && (
        <div className="fixed top-5 right-5 z-50 px-5 py-3 bg-gray-800 text-white rounded-xl shadow-xl text-sm font-medium animate-pulse">
          {toast}
        </div>
      )}

      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-gray-800">คำขอเพิ่มเมนู</h2>
          <p className="text-sm text-gray-500 mt-0.5">Temp Foods รอการอนุมัติจาก User ({tempFoods.length} รายการ)</p>
        </div>
        <button onClick={load} className="p-2 rounded-xl hover:bg-white border border-gray-200 transition" title="รีเฟรช">
          <RefreshCw size={16} className="text-gray-500" />
        </button>
      </div>

      {/* Table */}
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
        {loading ? (
          <div className="flex items-center justify-center py-16">
            <div className="w-8 h-8 border-4 border-[#628141] border-t-transparent rounded-full animate-spin" />
          </div>
        ) : tempFoods.length === 0 ? (
            <div className="py-16 text-center text-gray-400 text-sm">ไม่มี Temp Foods รอดำเนินการ 🎉</div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="bg-gray-50 border-b border-gray-100">
                  <tr>
                    <th className="py-3 px-4 text-left text-xs font-semibold text-gray-500 uppercase">ชื่อเมนู</th>
                    <th className="py-3 px-4 text-left text-xs font-semibold text-gray-500 uppercase">ผู้ขอ</th>
                    <th className="py-3 px-4 text-right text-xs font-semibold text-gray-500 uppercase">แคล</th>
                    <th className="py-3 px-4 text-left text-xs font-semibold text-gray-500 uppercase">วันที่</th>
                    <th className="py-3 px-4 text-center text-xs font-semibold text-gray-500 uppercase">จัดการ</th>
                  </tr>
                </thead>
                <tbody>
                  {tempFoods.map(t => (
                    <tr key={t.tf_id} className="border-b border-gray-50 hover:bg-gray-50 transition">
                      <td className="py-3 px-4 font-medium text-gray-800">{t.food_name}</td>
                      <td className="py-3 px-4 text-gray-500">{t.requester_name}</td>
                      <td className="py-3 px-4 text-right text-gray-600">{t.calories ?? '—'}</td>
                      <td className="py-3 px-4 text-gray-400 text-xs">
                        {t.submitted_at ? new Date(t.submitted_at).toLocaleDateString('th-TH') : '—'}
                      </td>
                      <td className="py-3 px-4">
                        <div className="flex items-center justify-center gap-2">
                          <button
                            onClick={() => setApproveModal({ open: true, item: t })}
                            className="flex items-center gap-1 px-3 py-1.5 rounded-lg bg-green-50 text-green-700 hover:bg-green-100 text-xs font-medium transition"
                          >
                            <CheckCircle size={13} /> อนุมัติ
                          </button>
                          <button
                            onClick={() => handleRejectTemp(t.tf_id)}
                            className="flex items-center gap-1 px-3 py-1.5 rounded-lg bg-red-50 text-red-600 hover:bg-red-100 text-xs font-medium transition"
                          >
                            <XCircle size={13} /> ปฏิเสธ
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
      </div>

      {approveModal.open && approveModal.item && (
        <ApproveModal
          item={approveModal.item}
          onClose={() => setApproveModal({ open: false, item: null })}
          onApprove={handleApproveTemp}
        />
      )}
    </div>
  )
}
