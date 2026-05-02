-- Supabase Setup for Push Notifications
-- Run this SQL in your Supabase SQL editor

-- 1. Create table to store FCM tokens
CREATE TABLE IF NOT EXISTS user_fcm_tokens (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL,
  device_type TEXT, -- 'android' or 'ios'
  created_at TIMESTAMP DEFAULT NOW(),
  last_updated TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, fcm_token)
);

-- 2. Create index for faster lookups
CREATE INDEX idx_user_fcm_tokens_user_id ON user_fcm_tokens(user_id);

-- 3. Enable RLS on user_fcm_tokens table
ALTER TABLE user_fcm_tokens ENABLE ROW LEVEL SECURITY;

-- 4. Create RLS policy for users to manage their own tokens
CREATE POLICY "Users can manage their own FCM tokens"
ON user_fcm_tokens
FOR ALL
USING (auth.uid() = user_id);

-- 5. Create notification log table (optional, for tracking sent notifications)
CREATE TABLE IF NOT EXISTS notification_log (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  notification_type TEXT, -- 'mission_assigned', 'status_update', 'critical', etc
  related_mission_id BIGINT REFERENCES missions(id) ON DELETE SET NULL,
  sent_at TIMESTAMP DEFAULT NOW(),
  status TEXT DEFAULT 'sent', -- 'sent', 'failed', 'delivered'
  metadata JSONB
);

-- 6. Create index for notification log
CREATE INDEX idx_notification_log_user_id ON notification_log(user_id);
CREATE INDEX idx_notification_log_sent_at ON notification_log(sent_at);

-- 7. Enable RLS on notification_log
ALTER TABLE notification_log ENABLE ROW LEVEL SECURITY;

-- 8. Create RLS policy for users to view their own notifications
CREATE POLICY "Users can view their own notification logs"
ON notification_log
FOR SELECT
USING (auth.uid() = user_id);

-- 9. Create a trigger to update mission's notification status
CREATE OR REPLACE FUNCTION log_notification()
RETURNS TRIGGER AS $$
BEGIN
  -- This will be called when a notification is sent
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 10. Create a function to handle mission status updates and send notifications
-- This would be called from your backend when mission status changes
CREATE OR REPLACE FUNCTION notify_mission_status_change(
  p_mission_id BIGINT,
  p_new_status TEXT
)
RETURNS void AS $$
DECLARE
  v_user_id UUID;
  v_fcm_tokens TEXT[];
  v_mission_number TEXT;
BEGIN
  -- Get the mission details
  SELECT mission_number INTO v_mission_number
  FROM missions WHERE id = p_mission_id;

  -- Get manager's user ID (you may need to adjust based on your schema)
  SELECT auth.uid() INTO v_user_id;

  -- Get all FCM tokens for the user
  SELECT ARRAY_AGG(fcm_token) INTO v_fcm_tokens
  FROM user_fcm_tokens WHERE user_id = v_user_id;

  -- Log the notification
  INSERT INTO notification_log (
    user_id,
    title,
    body,
    notification_type,
    related_mission_id,
    metadata
  ) VALUES (
    v_user_id,
    'Mission Status Update',
    'Mission ' || v_mission_number || ' status changed to ' || p_new_status,
    'mission_status_update',
    p_mission_id,
    jsonb_build_object(
      'mission_id', p_mission_id,
      'mission_number', v_mission_number,
      'new_status', p_new_status,
      'fcm_tokens', v_fcm_tokens
    )
  );
END;
$$ LANGUAGE plpgsql;

-- 11. Grant execute permission on the function
GRANT EXECUTE ON FUNCTION notify_mission_status_change(BIGINT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION notify_mission_status_change(BIGINT, TEXT) TO anon;
