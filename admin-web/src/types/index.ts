export interface AuthState {
  user_id: number
  username: string
  email: string
  role_id: number
  access_token: string
}

export interface Food {
  food_id: number
  food_name: string
  calories: number
  protein: number
  carbs: number
  fat: number
  sodium?: number | null
  sugar?: number | null
  cholesterol?: number | null
  fiber_g?: number | null
  image_url?: string | null
  allergy_flag_ids?: number[]
}

export interface FoodFormData {
  food_name: string
  calories: string
  protein: string
  carbs: string
  fat: string
  sodium: string
  sugar: string
  cholesterol: string
  fiber_g: string
  image_url: string
  food_type: string
  food_category: string
  serving_quantity: string
  serving_unit: string
}

export interface TempFood {
  tf_id: number
  food_name: string
  calories: number | null
  protein: number | null
  carbs: number | null
  fat: number | null
  user_id: number
  requester_name: string
  submitted_at: string
  is_verify: boolean
  verified_by: number | null
  verified_at: string | null
}

export interface UserDetail {
  user_id: number
  username: string
  email: string
  role_id: number
  created_at: string
  last_login_date?: string
  current_streak?: number
  total_login_days?: number
  deleted_at?: string | null
  tama_points: number
  tier_level: number
  claimed_badges: string[]
}

export type ThaiRegion = 'central' | 'northern' | 'northeastern' | 'southern'
export type SubmissionStatus = 'pending' | 'approved' | 'rejected'

export interface RegionalNameSubmission {
  submission_id: number
  food_id: number
  created_at: string
  food_name: string
  region: ThaiRegion
  name_th: string
  popularity: number | null
  user_id: number
  requester_name: string
  status: SubmissionStatus
  reviewed_by: number | null
  reviewed_at: string | null
}
