-- v30: User notification preferences (JSONB) + last_active_at already added in v29.
-- This migration adds a notification_prefs column for full per-device sync.

ALTER TABLE cleangoal.users
  ADD COLUMN IF NOT EXISTS notification_prefs JSONB DEFAULT '{}'::jsonb;

COMMENT ON COLUMN cleangoal.users.notification_prefs IS
  'Per-user notification preferences synced from the device. Schema:
   {
     "enabled": bool,
     "categories": {"meal": bool, "water": bool, ...},
     "quietHours": {"enabled": bool, "startMin": int, "endMin": int},
     "mealTimes": {"breakfastHm": int, "lunchHm": int, "dinnerHm": int},
     "waterTimesHH": [int, ...],
     "weighInDay": int
   }';
