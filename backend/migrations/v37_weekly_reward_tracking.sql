-- v37: Track weekly reward claims to prevent double-awarding
ALTER TABLE cleangoal.user_gamification
  ADD COLUMN IF NOT EXISTS last_weekly_reward_week TEXT;
