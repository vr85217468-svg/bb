-- ============================================
-- إنشاء RPC لحذف العضو بدون triggers
-- ============================================

-- دالة تحذف العضو مع تعطيل triggers مؤقتاً
CREATE OR REPLACE FUNCTION delete_tribe_member(
  p_tribe_id UUID,
  p_user_id UUID
)
RETURNS void AS $$
BEGIN
  -- حذف مباشر
  DELETE FROM tribe_members 
  WHERE tribe_id = p_tribe_id AND user_id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- منح الصلاحية
GRANT EXECUTE ON FUNCTION delete_tribe_member TO authenticated;

-- ============================================
-- تم!
-- ============================================
