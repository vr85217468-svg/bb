-- ═══════════════════════════════════════════════════════════════════
-- 🛡️ CRITICAL SECURITY FIX: Row Level Security for Tribe Messages
-- ═══════════════════════════════════════════════════════════════════
-- This file adds RLS policies to prevent unauthorized access to tribe messages
-- Run this in your Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════════

-- 1️⃣ Enable RLS on tribe_messages table
ALTER TABLE tribe_messages ENABLE ROW LEVEL SECURITY;

-- 2️⃣ Drop existing policies if any (cleanup)
DROP POLICY IF EXISTS "Users can only read their tribe messages" ON tribe_messages;
DROP POLICY IF EXISTS "Users can only send messages to their tribes" ON tribe_messages;
DROP POLICY IF EXISTS "Users can only delete their own messages" ON tribe_messages;

-- 3️⃣ READ POLICY: Only members can read tribe messages
CREATE POLICY "Users can only read their tribe messages"
  ON tribe_messages
  FOR SELECT
  USING (
    -- التحقق من العضوية النشطة
    EXISTS (
      SELECT 1
      FROM tribe_members
      WHERE tribe_members.tribe_id = tribe_messages.tribe_id
        AND tribe_members.user_id = auth.uid()
        AND tribe_members.status = 'active'
    )
  );

-- 4️⃣ INSERT POLICY: Only active members can send messages
CREATE POLICY "Users can only send messages to their tribes"
  ON tribe_messages
  FOR INSERT
  WITH CHECK (
    -- التحقق من العضوية النشطة
    EXISTS (
      SELECT 1
      FROM tribe_members
      WHERE tribe_members.tribe_id = tribe_messages.tribe_id
        AND tribe_members.user_id = auth.uid()
        AND tribe_members.status = 'active'
    )
    AND
    -- التأكد من أن معرف المستخدم في الرسالة هو نفس المستخدم المسجل
    user_id = auth.uid()
  );

-- 5️⃣ DELETE POLICY: Users can only delete their own messages
CREATE POLICY "Users can only delete their own messages"
  ON tribe_messages
  FOR DELETE
  USING (
    user_id = auth.uid()
  );

-- 6️⃣ Verification Query - Test that policies work
-- Run this to verify (replace with actual user ID and tribe ID)
-- SELECT * FROM tribe_messages WHERE tribe_id = 'test-tribe-id';
-- Should only return messages if the current user is an active member

COMMENT ON POLICY "Users can only read their tribe messages" ON tribe_messages IS 
  'Ensures users can only read messages from tribes they are active members of';

COMMENT ON POLICY "Users can only send messages to their tribes" ON tribe_messages IS 
  'Ensures users can only send messages to tribes they are active members of';

COMMENT ON POLICY "Users can only delete their own messages" ON tribe_messages IS 
  'Ensures users can only delete messages they sent themselves';

-- ═══════════════════════════════════════════════════════════════════
-- ✅ DONE! Your tribe messages are now protected at the database level
-- ═══════════════════════════════════════════════════════════════════
