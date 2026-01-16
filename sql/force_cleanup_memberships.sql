-- 🏰 SQL Script: Force Cleanup of Stale Memberships
-- This script removes any invalid or "ghost" membership records
-- and ensures only one active membership per user (if that's a requirement)
-- or simply clears all to start fresh.

-- Option 1: Remove all records that are NOT active
-- DELETE FROM tribe_members WHERE status != 'active';

-- Option 2: Remove all memberships for a specific user to reset them
-- DELETE FROM tribe_members WHERE user_id = 'YOUR_USER_ID';

-- Option 3: Comprehensive Cleanup (USE WITH CAUTION)
-- 1. Remove memberships where tribe doesn't exist anymore
DELETE FROM tribe_members 
WHERE tribe_id NOT IN (SELECT id FROM tribes);

-- 2. Ensure leader_id in tribes table matches a member who is_leader=true
-- (This is just a diagnostic query)
SELECT t.id, t.name, t.leader_id, tm.user_id as actual_leader
FROM tribes t
LEFT JOIN tribe_members tm ON t.id = tm.tribe_id AND tm.is_leader = true
WHERE t.leader_id != tm.user_id OR tm.user_id IS NULL;

-- 3. Fix leaders (Optional - Run if diagnosis above shows issues)
-- UPDATE tribes t
-- SET leader_id = (SELECT user_id FROM tribe_members WHERE tribe_id = t.id AND is_leader = true LIMIT 1)
-- WHERE leader_id NOT IN (SELECT user_id FROM tribe_members WHERE tribe_id = t.id AND is_leader = true);

-- 4. Clear all memberships if requested by user for total reset
-- DELETE FROM tribe_members;
-- DELETE FROM tribes;

-- Useful view for debugging:
-- SELECT tm.id, tm.status, tm.is_leader, t.name as tribe_name, u.name as user_name
-- FROM tribe_members tm
-- JOIN tribes t ON tm.tribe_id = t.id
-- JOIN users u ON tm.user_id = u.id;
