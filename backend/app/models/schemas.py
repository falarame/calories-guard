from datetime import date
from typing import List, Optional
from enum import Enum
from pydantic import BaseModel


class GoalType(str, Enum):
    lose_weight = 'lose_weight'
    maintain_weight = 'maintain_weight'
    gain_muscle = 'gain_muscle'


class ActivityLevel(str, Enum):
    sedentary = 'sedentary'
    lightly_active = 'lightly_active'
    moderately_active = 'moderately_active'
    very_active = 'very_active'


class ThaiRegion(str, Enum):
    central = 'central'
    northern = 'northern'
    northeastern = 'northeastern'
    southern = 'southern'


class UserRegister(BaseModel):
    email: str
    password: str
    username: str


class UserVerifyEmail(BaseModel):
    email: str
    code: str


class UserLogin(BaseModel):
    email: str
    password: str


class UserUpdate(BaseModel):
    username: str | None = None
    gender: str | None = None
    birth_date: date | None = None
    height_cm: float | None = None
    current_weight_kg: float | None = None
    goal_type: GoalType | None = None
    target_weight_kg: float | None = None
    target_calories: int | None = None
    target_protein: int | None = None
    target_carbs: int | None = None
    target_fat: int | None = None
    activity_level: ActivityLevel | None = None
    goal_target_date: date | None = None
    unit_weight: str | None = None
    unit_height: str | None = None
    unit_energy: str | None = None
    unit_water: str | None = None
    avatar_url: str | None = None


class PasswordResetRequest(BaseModel):
    email: str


class PasswordResetVerify(BaseModel):
    email: str
    code: str
    birth_date: date


class PasswordResetConfirm(BaseModel):
    email: str
    code: str
    birth_date: date
    new_password: str


class FoodCreate(BaseModel):
    food_name: str
    calories: float
    protein: float
    carbs: float
    fat: float
    image_url: str | None = None


class FoodAutoAdd(BaseModel):
    user_id: int
    food_name: str
    calories: float | None = 0
    protein: float | None = 0
    carbs: float | None = 0
    fat: float | None = 0


class AdminFoodReview(BaseModel):
    admin_id: int
    status: str  # 'approved' or 'rejected'
    calories: float | None = None
    protein: float | None = None
    carbs: float | None = None
    fat: float | None = None
    image_url: str | None = None


class TempFoodApprove(BaseModel):
    admin_id: int
    food_name: str | None = None
    calories: float | None = None
    protein: float | None = None
    carbs: float | None = None
    fat: float | None = None
    image_url: str | None = None
    food_type: str | None = None
    food_category: str | None = None
    sodium: float | None = None
    sugar: float | None = None
    cholesterol: float | None = None
    fiber_g: float | None = None
    serving_quantity: float | None = None
    serving_unit: str | None = None


class MealItem(BaseModel):
    food_id: Optional[int] = None
    amount: float = 1.0
    food_name: str
    cal_per_unit: float
    protein_per_unit: float
    carbs_per_unit: float
    fat_per_unit: float
    unit_id: Optional[int] = None


class DailyLogUpdate(BaseModel):
    date: date
    meal_type: str
    items: List[MealItem]


class RecipeReview(BaseModel):
    user_id: int
    rating: int  # 1-5
    comment: str | None = None


class WaterLogUpdate(BaseModel):
    amount_ml: int


class AllergyUpdate(BaseModel):
    flag_ids: List[int]


class SocialLoginRequest(BaseModel):
    email: str
    name: str
    uid: str
    provider: str


class WeightLogEntry(BaseModel):
    weight_kg: float


class ChatMessage(BaseModel):
    user_id: int
    message: str
    lat: float | None = None
    lng: float | None = None


class UserRegionUpdate(BaseModel):
    region: ThaiRegion | None  # None = clear preference (back to canonical Central)


class RegionalNameSubmission(BaseModel):
    user_id: int
    region: ThaiRegion
    name_th: str
    popularity: int | None = None  # 1-5; admin may override at approval time


class RegionalNameApprove(BaseModel):
    admin_id: int
    is_primary: bool = False
    popularity: int | None = None


class MealEstimateRequest(BaseModel):
    """
    User types free text like "มื้อเช้ากินข้าวผัดกะเพรา 1 จาน ต้มยำกุ้ง ครึ่งถ้วย"
    and we return per-item + total calorie/macro estimates without committing
    to DB yet — the app can then confirm + POST /meals/{user_id} to persist.
    """
    user_id: int
    message: str
    meal_type: str | None = None  # breakfast/lunch/dinner/snack (optional hint)
