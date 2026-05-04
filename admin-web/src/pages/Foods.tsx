import { useEffect, useState, type FormEvent } from 'react'
import { Plus, Pencil, Search, X, Loader2, ImageOff, Upload, Trash2 } from 'lucide-react'
import { api, normalizeImageUrl } from '../api/client'
import type { Food, FoodFormData } from '../types'

const EMPTY_FORM: FoodFormData = {
  food_name: '', calories: '', protein: '', carbs: '', fat: '',
  sodium: '', sugar: '', cholesterol: '', fiber_g: '', image_url: '',
}

function FoodField({ label, k, type = 'text', placeholder = '', value, onChange }: {
  label: string; k: keyof FoodFormData; type?: string; placeholder?: string
  value: string; onChange: (k: keyof FoodFormData, v: string) => void
}) {
  const isNum = type === 'number'
  return (
    <div>
      <label className="block text-sm font-medium text-gray-700 mb-1">{label}</label>
      <input
        type={isNum ? 'text' : type}
        inputMode={isNum ? 'decimal' : undefined}
        value={value}
        onChange={e => onChange(k, e.target.value)}
        onFocus={isNum ? e => e.target.select() : undefined}
        placeholder={placeholder}
        className="w-full px-3 py-2 rounded-lg border border-gray-200 focus:outline-none focus:ring-2 focus:ring-[#628141]/30 focus:border-[#628141] text-sm transition"
      />
    </div>
  )
}

function FoodModal({
  food, onClose, onSaved,
}: {
  food: Food | null
  onClose: () => void
  onSaved: () => void
}) {
  const [form, setForm] = useState<FoodFormData>(
    food
      ? {
          food_name: food.food_name,
          calories: String(food.calories),
          protein: String(food.protein),
          carbs: String(food.carbs),
          fat: String(food.fat),
          sodium: food.sodium != null ? String(food.sodium) : '',
          sugar: food.sugar != null ? String(food.sugar) : '',
          cholesterol: food.cholesterol != null ? String(food.cholesterol) : '',
          fiber_g: food.fiber_g != null ? String(food.fiber_g) : '',
          image_url: food.image_url ?? '',
        }
      : EMPTY_FORM
  )
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [uploading, setUploading] = useState(false)

  const set = (k: keyof FoodFormData, v: string) => setForm(f => ({ ...f, [k]: v }))
  const fieldProps = (k: keyof FoodFormData) => ({ k, value: form[k], onChange: set })

  const handleUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    setUploading(true)
    try {
      const formData = new FormData()
      formData.append('file', file)
      if (food?.food_id) formData.append('food_id', String(food.food_id))
      const res = await fetch(`${import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000'}/upload-image/`, {
        method: 'POST', body: formData,
      })
      if (!res.ok) throw new Error('Upload failed')
      const data = await res.json()
      set('image_url', data.url)
    } catch {
      setError('อัปโหลดรูปไม่สำเร็จ')
    } finally {
      setUploading(false)
    }
  }

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault()
    setError('')
    setLoading(true)
    try {
      const payload = {
        food_name: form.food_name.trim(),
        calories: parseFloat(form.calories) || 0,
        protein: parseFloat(form.protein) || 0,
        carbs: parseFloat(form.carbs) || 0,
        fat: parseFloat(form.fat) || 0,
        sodium: form.sodium !== '' ? parseFloat(form.sodium) : null,
        sugar: form.sugar !== '' ? parseFloat(form.sugar) : null,
        cholesterol: form.cholesterol !== '' ? parseFloat(form.cholesterol) : null,
        fiber_g: form.fiber_g !== '' ? parseFloat(form.fiber_g) : null,
        image_url: form.image_url.trim() || null,
      }
      if (food) {
        await api.updateFood(food.food_id, payload)
      } else {
        await api.createFood(payload)
      }
      onSaved()
      onClose()
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'เกิดข้อผิดพลาด')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100">
          <h3 className="font-semibold text-gray-800">{food ? 'แก้ไขเมนูอาหาร' : 'เพิ่มเมนูอาหารใหม่'}</h3>
          <button onClick={onClose} className="p-1.5 rounded-lg hover:bg-gray-100 transition">
            <X size={18} className="text-gray-500" />
          </button>
        </div>
        <form onSubmit={handleSubmit} className="px-6 py-5 space-y-4">
          {error && (
            <div className="px-4 py-3 bg-red-50 text-red-700 border border-red-200 rounded-xl text-sm">{error}</div>
          )}
          <FoodField label="ชื่ออาหาร *" placeholder="เช่น ข้าวผัดกะเพรา" {...fieldProps('food_name')} />
          <div className="grid grid-cols-2 gap-3">
            <FoodField label="แคลอรี่ (kcal) *" type="number" placeholder="350" {...fieldProps('calories')} />
            <FoodField label="โปรตีน (g)" type="number" placeholder="22" {...fieldProps('protein')} />
            <FoodField label="คาร์โบไฮเดรต (g)" type="number" placeholder="38" {...fieldProps('carbs')} />
            <FoodField label="ไขมัน (g)" type="number" placeholder="12" {...fieldProps('fat')} />
          </div>
          <div>
            <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-2">โภชนาการเพิ่มเติม</p>
            <div className="grid grid-cols-2 gap-3">
              <FoodField label="โซเดียม (mg)" type="number" placeholder="—" {...fieldProps('sodium')} />
              <FoodField label="น้ำตาล (g)" type="number" placeholder="—" {...fieldProps('sugar')} />
              <FoodField label="โคเลสเตอรอล (mg)" type="number" placeholder="—" {...fieldProps('cholesterol')} />
              <FoodField label="ไฟเบอร์ (g)" type="number" placeholder="—" {...fieldProps('fiber_g')} />
            </div>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">รูปภาพ</label>
            <div className="flex gap-2">
              <input
                type="text"
                value={form.image_url}
                onChange={e => set('image_url', e.target.value)}
                placeholder="https://... หรืออัปโหลดไฟล์"
                className="flex-1 px-3 py-2 rounded-lg border border-gray-200 focus:outline-none focus:ring-2 focus:ring-[#628141]/30 focus:border-[#628141] text-sm transition"
              />
              <label className="flex items-center gap-1.5 px-3 py-2 rounded-lg border border-gray-200 hover:bg-gray-50 cursor-pointer text-sm text-gray-600 transition whitespace-nowrap">
                {uploading ? <Loader2 size={14} className="animate-spin" /> : <Upload size={14} />}
                {uploading ? 'กำลังอัปโหลด...' : 'อัปโหลด'}
                <input type="file" accept="image/*" className="hidden" onChange={handleUpload} disabled={uploading} />
              </label>
            </div>
            {form.image_url && (
              <img src={form.image_url} alt="preview" className="mt-2 h-20 w-20 object-cover rounded-lg border border-gray-200" />
            )}
          </div>

          <div className="flex gap-3 pt-2">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 py-2.5 rounded-xl border border-gray-200 text-sm font-medium text-gray-600 hover:bg-gray-50 transition"
            >
              ยกเลิก
            </button>
            <button
              type="submit"
              disabled={loading || !form.food_name || !form.calories}
              className="flex-1 py-2.5 rounded-xl bg-[#628141] text-white text-sm font-semibold hover:bg-[#507034] transition disabled:opacity-60 disabled:cursor-not-allowed flex items-center justify-center gap-2"
            >
              {loading && <Loader2 size={14} className="animate-spin" />}
              {food ? 'บันทึกการแก้ไข' : 'เพิ่มเมนู'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

export default function Foods() {
  const [foods, setFoods] = useState<Food[]>([])
  const [filtered, setFiltered] = useState<Food[]>([])
  const [search, setSearch] = useState('')
  const [loading, setLoading] = useState(true)
  const [modal, setModal] = useState<{ open: boolean; food: Food | null }>({ open: false, food: null })
  const [deleting, setDeleting] = useState<number | null>(null)

  const handleDelete = async (food: Food) => {
    if (!confirm(`ต้องการลบ "${food.food_name}" ออกจากระบบ?`)) return
    setDeleting(food.food_id)
    try {
      await api.deleteFood(food.food_id)
      setFoods(prev => prev.filter(f => f.food_id !== food.food_id))
    } catch (e: unknown) {
      alert(e instanceof Error ? e.message : 'ลบไม่สำเร็จ')
    } finally {
      setDeleting(null)
    }
  }

  const load = () => {
    setLoading(true)
    api.getFoods()
      .then(data => { setFoods(data as Food[]); setFiltered(data as Food[]) })
      .catch(console.error)
      .finally(() => setLoading(false))
  }

  useEffect(() => { load() }, [])

  useEffect(() => {
    const q = search.toLowerCase()
    setFiltered(q ? foods.filter(f => f.food_name.toLowerCase().includes(q)) : foods)
  }, [search, foods])

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between gap-4">
        <div>
          <h2 className="text-2xl font-bold text-gray-800">จัดการอาหาร</h2>
          <p className="text-sm text-gray-500 mt-0.5">{foods.length} รายการ</p>
        </div>
        <button
          onClick={() => setModal({ open: true, food: null })}
          className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-[#628141] text-white text-sm font-semibold hover:bg-[#507034] transition shadow-sm"
        >
          <Plus size={16} />
          เพิ่มเมนูใหม่
        </button>
      </div>

      {/* Search */}
      <div className="relative">
        <Search size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" />
        <input
          type="text"
          placeholder="ค้นหาชื่ออาหาร..."
          value={search}
          onChange={e => setSearch(e.target.value)}
          className="w-full pl-10 pr-4 py-2.5 rounded-xl border border-gray-200 focus:outline-none focus:ring-2 focus:ring-[#628141]/30 focus:border-[#628141] text-sm bg-white"
        />
      </div>

      {/* Table */}
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
        {loading ? (
          <div className="flex items-center justify-center py-16">
            <div className="w-8 h-8 border-4 border-[#628141] border-t-transparent rounded-full animate-spin" />
          </div>
        ) : filtered.length === 0 ? (
          <div className="py-16 text-center text-gray-400 text-sm">ไม่พบรายการ</div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-gray-50 border-b border-gray-100">
                <tr>
                  <th className="py-3 px-4 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide w-20">รูป</th>
                  <th className="py-3 px-4 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide">ชื่ออาหาร</th>
                  <th className="py-3 px-4 text-right text-xs font-semibold text-gray-500 uppercase tracking-wide">แคล</th>
                  <th className="py-3 px-4 text-right text-xs font-semibold text-gray-500 uppercase tracking-wide">โปรตีน</th>
                  <th className="py-3 px-4 text-right text-xs font-semibold text-gray-500 uppercase tracking-wide">คาร์บ</th>
                  <th className="py-3 px-4 text-right text-xs font-semibold text-gray-500 uppercase tracking-wide">ไขมัน</th>
                  <th className="py-3 px-4 text-center text-xs font-semibold text-gray-500 uppercase tracking-wide">จัดการ</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map(food => (
                  <tr key={food.food_id} className="border-b border-gray-50 hover:bg-gray-50 transition">
                    <td className="py-2.5 px-4">
                      {food.image_url ? (
                        <img src={normalizeImageUrl(food.image_url) ?? ''} alt={food.food_name}
                          className="w-14 h-14 min-w-[56px] rounded-xl object-cover bg-gray-100 shrink-0" />
                      ) : (
                        <div className="w-14 h-14 min-w-[56px] rounded-xl bg-[#E8EFCF] flex items-center justify-center shrink-0">
                          <ImageOff size={14} className="text-[#628141]" />
                        </div>
                      )}
                    </td>
                    <td className="py-2.5 px-4 font-medium text-gray-800">{food.food_name}</td>
                    <td className="py-2.5 px-4 text-right text-gray-600">{food.calories}</td>
                    <td className="py-2.5 px-4 text-right text-blue-600">{food.protein}g</td>
                    <td className="py-2.5 px-4 text-right text-yellow-600">{food.carbs}g</td>
                    <td className="py-2.5 px-4 text-right text-red-500">{food.fat}g</td>
                    <td className="py-2.5 px-4 text-center">
                      <div className="flex items-center justify-center gap-1">
                        <button
                          onClick={() => setModal({ open: true, food })}
                          className="p-2 rounded-lg hover:bg-[#E8EFCF] text-[#628141] transition"
                          title="แก้ไข"
                        >
                          <Pencil size={15} />
                        </button>
                        <button
                          onClick={() => handleDelete(food)}
                          disabled={deleting === food.food_id}
                          className="p-2 rounded-lg hover:bg-red-50 text-red-400 hover:text-red-600 transition disabled:opacity-40"
                          title="ลบ"
                        >
                          {deleting === food.food_id
                            ? <Loader2 size={15} className="animate-spin" />
                            : <Trash2 size={15} />}
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

      {modal.open && (
        <FoodModal food={modal.food} onClose={() => setModal({ open: false, food: null })} onSaved={load} />
      )}
    </div>
  )
}
