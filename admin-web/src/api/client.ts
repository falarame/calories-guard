const BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000'

export function normalizeImageUrl(url: string | null | undefined): string | null {
  if (!url) return null
  return url.replace(/https?:\/\/10\.0\.2\.2(:\d+)?/, BASE_URL)
}

// ── Token + 401 plumbing ────────────────────────────────────────
// AuthContext wires getToken + onUnauthorized at startup so api requests
// can attach the Bearer token and auto-logout on 401.

type TokenGetter = () => string | null
type UnauthorizedHandler = () => void

let _getToken: TokenGetter = () => null
let _onUnauthorized: UnauthorizedHandler = () => {}

export function configureApiAuth(getter: TokenGetter, onUnauthorized: UnauthorizedHandler) {
  _getToken = getter
  _onUnauthorized = onUnauthorized
}

async function req<T>(path: string, options: RequestInit = {}): Promise<T> {
  const token = _getToken()
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    ...(options.headers as Record<string, string> | undefined),
  }
  if (token) headers['Authorization'] = `Bearer ${token}`

  const res = await fetch(`${BASE_URL}${path}`, { ...options, headers })
  if (res.status === 401) {
    _onUnauthorized()
  }
  if (!res.ok) {
    const err = await res.json().catch(() => ({ detail: `HTTP ${res.status}` }))
    throw new Error(err.detail || `HTTP ${res.status}`)
  }
  return res.json() as Promise<T>
}

export const api = {
  // ── Auth ──────────────────────────────────────────
  login: (email: string, password: string) =>
    req<any>('/login', { method: 'POST', body: JSON.stringify({ email, password }) }),

  // ── Foods ─────────────────────────────────────────
  getFoods: () => req<any[]>('/foods'),
  createFood: (data: object) =>
    req<any>('/foods', { method: 'POST', body: JSON.stringify(data) }),
  updateFood: (id: number, data: object) =>
    req<any>(`/foods/${id}`, { method: 'PUT', body: JSON.stringify(data) }),
  patchFood: (id: number, data: object) =>
    req<any>(`/foods/${id}`, { method: 'PATCH', body: JSON.stringify(data) }),
  deleteFood: (id: number) =>
    req<any>(`/foods/${id}`, { method: 'DELETE' }),

  // ── Temp Foods (v13 flow) ──────────────────────────
  getTempFoods: (status = 'pending') =>
    req<any[]>(`/admin/temp-foods?status=${status}`),
  getPendingCount: () =>
    req<{ count: number }>('/admin/temp-foods/pending-count'),
  getSimilarFoods: (name: string) =>
    req<any[]>(`/admin/foods/similar?name=${encodeURIComponent(name)}`),
  approveTempFood: (tfId: number, adminId: number, data: object) =>
    req<any>(`/admin/temp-foods/${tfId}/approve`, {
      method: 'POST',
      body: JSON.stringify({ admin_id: adminId, ...data }),
    }),
  rejectTempFood: (tfId: number) =>
    req<any>(`/admin/temp-foods/${tfId}`, { method: 'DELETE' }),

  // ── Regional name submissions ─────────────────────
  getRegionalNameSubmissions: (status = 'pending') =>
    req<any[]>(`/admin/regional-name-submissions?status=${status}`),
  approveRegionalNameSubmission: (
    submissionId: number,
    adminId: number,
    data: { is_primary?: boolean; popularity?: number | null },
  ) =>
    req<any>(`/admin/regional-name-submissions/${submissionId}/approve`, {
      method: 'POST',
      body: JSON.stringify({ admin_id: adminId, ...data }),
    }),
  rejectRegionalNameSubmission: (submissionId: number, adminId: number) =>
    req<any>(`/admin/regional-name-submissions/${submissionId}/reject`, {
      method: 'POST',
      body: JSON.stringify({ admin_id: adminId }),
    }),

  // ── Users ─────────────────────────────────────────
  getAdminUsers: (search = '') => req<any[]>(`/admin/users${search ? `?search=${encodeURIComponent(search)}` : ''}`),
  getAdminUser: (id: number) => req<any>(`/admin/users/${id}`),
  getUser: (id: number) => req<any>(`/users/${id}`),
  updateAdminUser: (id: number, data: object) =>
    req<any>(`/admin/users/${id}`, { method: 'PATCH', body: JSON.stringify(data) }),
  updateAdminUserTama: (id: number, data: object) =>
    req<any>(`/admin/users/${id}/tama`, { method: 'PATCH', body: JSON.stringify(data) }),
  deleteAdminUser: (id: number) =>
    req<any>(`/admin/users/${id}`, { method: 'DELETE' }),
}
