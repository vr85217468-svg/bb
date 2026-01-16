-- ================================================
-- نظام حفظ التقدم المتقدم - جداول قاعدة البيانات
-- ================================================

-- الجدول 1: جلسات الاختبار
-- ================================================
CREATE TABLE IF NOT EXISTS quiz_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  quiz_id UUID NOT NULL REFERENCES quizzes(id) ON DELETE CASCADE,
  session_start TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  session_end TIMESTAMPTZ,
  total_duration_seconds INTEGER,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'paused', 'abandoned')),
  current_question_index INTEGER NOT NULL DEFAULT 0,
  total_questions INTEGER NOT NULL DEFAULT 0,
  correct_count INTEGER NOT NULL DEFAULT 0,
  wrong_count INTEGER NOT NULL DEFAULT 0,
  skipped_count INTEGER NOT NULL DEFAULT 0,
  earned_badges TEXT,
  final_score INTEGER,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes للأداء
CREATE INDEX IF NOT EXISTS idx_quiz_sessions_user_id ON quiz_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_quiz_sessions_quiz_id ON quiz_sessions(quiz_id);
CREATE INDEX IF NOT EXISTS idx_quiz_sessions_status ON quiz_sessions(status);
CREATE INDEX IF NOT EXISTS idx_quiz_sessions_created_at ON quiz_sessions(created_at DESC);

-- RLS Policy
ALTER TABLE quiz_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own sessions" ON quiz_sessions;
CREATE POLICY "Users can view their own sessions" ON quiz_sessions
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert their own sessions" ON quiz_sessions;
CREATE POLICY "Users can insert their own sessions" ON quiz_sessions
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Users can update their own sessions" ON quiz_sessions;
CREATE POLICY "Users can update their own sessions" ON quiz_sessions
  FOR UPDATE USING (true);

DROP POLICY IF EXISTS "Users can delete their own sessions" ON quiz_sessions;
CREATE POLICY "Users can delete their own sessions" ON quiz_sessions
  FOR DELETE USING (true);

-- ================================================
-- الجدول 2: محاولات الإجابة على الأسئلة
-- ================================================
CREATE TABLE IF NOT EXISTS question_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES quiz_sessions(id) ON DELETE CASCADE,
  question_id UUID NOT NULL REFERENCES quiz_questions(id) ON DELETE CASCADE,
  question_text TEXT NOT NULL,
  question_type TEXT NOT NULL,
  correct_answer TEXT NOT NULL,
  user_answer TEXT,
  is_correct BOOLEAN NOT NULL DEFAULT FALSE,
  time_spent_seconds INTEGER NOT NULL DEFAULT 0,
  attempt_number INTEGER NOT NULL DEFAULT 1,
  answered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes للأداء
CREATE INDEX IF NOT EXISTS idx_question_attempts_session_id ON question_attempts(session_id);
CREATE INDEX IF NOT EXISTS idx_question_attempts_question_id ON question_attempts(question_id);
CREATE INDEX IF NOT EXISTS idx_question_attempts_is_correct ON question_attempts(is_correct);
CREATE INDEX IF NOT EXISTS idx_question_attempts_answered_at ON question_attempts(answered_at DESC);

-- RLS Policy
ALTER TABLE question_attempts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own attempts" ON question_attempts;
CREATE POLICY "Users can view their own attempts" ON question_attempts
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert their own attempts" ON question_attempts;
CREATE POLICY "Users can insert their own attempts" ON question_attempts
  FOR INSERT WITH CHECK (true);

-- ================================================
-- الجدول 3: تحليلات أداء المستخدم
-- ================================================
CREATE TABLE IF NOT EXISTS user_quiz_analytics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  quiz_id UUID NOT NULL REFERENCES quizzes(id) ON DELETE CASCADE,
  category_id UUID NOT NULL REFERENCES quiz_categories(id) ON DELETE CASCADE,
  total_attempts INTEGER NOT NULL DEFAULT 0,
  total_questions_answered INTEGER NOT NULL DEFAULT 0,
  total_correct INTEGER NOT NULL DEFAULT 0,
  total_wrong INTEGER NOT NULL DEFAULT 0,
  average_time_per_question DECIMAL(10, 2) DEFAULT 0,
  best_score INTEGER DEFAULT 0,
  best_score_percentage DECIMAL(5, 2) DEFAULT 0,
  last_attempt_date TIMESTAMPTZ,
  total_time_spent_seconds BIGINT DEFAULT 0,
  improvement_rate DECIMAL(5, 2),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, quiz_id)
);

-- Indexes للأداء
CREATE INDEX IF NOT EXISTS idx_user_quiz_analytics_user_id ON user_quiz_analytics(user_id);
CREATE INDEX IF NOT EXISTS idx_user_quiz_analytics_quiz_id ON user_quiz_analytics(quiz_id);
CREATE INDEX IF NOT EXISTS idx_user_quiz_analytics_category_id ON user_quiz_analytics(category_id);
CREATE INDEX IF NOT EXISTS idx_user_quiz_analytics_best_score ON user_quiz_analytics(best_score DESC);

-- RLS Policy
ALTER TABLE user_quiz_analytics ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own analytics" ON user_quiz_analytics;
CREATE POLICY "Users can view their own analytics" ON user_quiz_analytics
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert their own analytics" ON user_quiz_analytics;
CREATE POLICY "Users can insert their own analytics" ON user_quiz_analytics
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Users can update their own analytics" ON user_quiz_analytics;
CREATE POLICY "Users can update their own analytics" ON user_quiz_analytics
  FOR UPDATE USING (true);

-- ================================================
-- الجدول 4: الأسئلة الصعبة للمستخدم
-- ================================================
CREATE TABLE IF NOT EXISTS weak_questions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  question_id UUID NOT NULL REFERENCES quiz_questions(id) ON DELETE CASCADE,
  wrong_count INTEGER NOT NULL DEFAULT 0,
  total_attempts INTEGER NOT NULL DEFAULT 0,
  last_attempt_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  mastered BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, question_id)
);

-- Indexes للأداء
CREATE INDEX IF NOT EXISTS idx_weak_questions_user_id ON weak_questions(user_id);
CREATE INDEX IF NOT EXISTS idx_weak_questions_question_id ON weak_questions(question_id);
CREATE INDEX IF NOT EXISTS idx_weak_questions_mastered ON weak_questions(mastered);
CREATE INDEX IF NOT EXISTS idx_weak_questions_wrong_count ON weak_questions(wrong_count DESC);

-- RLS Policy
ALTER TABLE weak_questions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own weak questions" ON weak_questions;
CREATE POLICY "Users can view their own weak questions" ON weak_questions
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert their own weak questions" ON weak_questions;
CREATE POLICY "Users can insert their own weak questions" ON weak_questions
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Users can update their own weak questions" ON weak_questions;
CREATE POLICY "Users can update their own weak questions" ON weak_questions
  FOR UPDATE USING (true);

-- ================================================
-- Triggers للتحديث التلقائي
-- ================================================

-- Trigger لتحديث updated_at في quiz_sessions
CREATE OR REPLACE FUNCTION update_quiz_sessions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_quiz_sessions_updated_at ON quiz_sessions;
CREATE TRIGGER trigger_update_quiz_sessions_updated_at
  BEFORE UPDATE ON quiz_sessions
  FOR EACH ROW
  EXECUTE FUNCTION update_quiz_sessions_updated_at();

-- Trigger لتحديث updated_at في user_quiz_analytics
CREATE OR REPLACE FUNCTION update_user_quiz_analytics_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_user_quiz_analytics_updated_at ON user_quiz_analytics;
CREATE TRIGGER trigger_update_user_quiz_analytics_updated_at
  BEFORE UPDATE ON user_quiz_analytics
  FOR EACH ROW
  EXECUTE FUNCTION update_user_quiz_analytics_updated_at();

-- Trigger لتحديث updated_at في weak_questions
CREATE OR REPLACE FUNCTION update_weak_questions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_weak_questions_updated_at ON weak_questions;
CREATE TRIGGER trigger_update_weak_questions_updated_at
  BEFORE UPDATE ON weak_questions
  FOR EACH ROW
  EXECUTE FUNCTION update_weak_questions_updated_at();

-- ================================================
-- Views للاستعلامات الشائعة
-- ================================================

-- View: جلسات نشطة للمستخدم
CREATE OR REPLACE VIEW active_user_sessions AS
SELECT 
  qs.*,
  q.title as quiz_title,
  qc.name as category_name
FROM quiz_sessions qs
JOIN quizzes q ON qs.quiz_id = q.id
JOIN quiz_categories qc ON q.category_id = qc.id
WHERE qs.status = 'active';

-- View: إحصائيات المستخدم الشاملة
CREATE OR REPLACE VIEW user_overall_stats AS
SELECT 
  uqa.user_id,
  COUNT(DISTINCT uqa.quiz_id) as total_quizzes_attempted,
  SUM(uqa.total_attempts) as total_attempts,
  SUM(uqa.total_questions_answered) as total_questions_answered,
  SUM(uqa.total_correct) as total_correct,
  SUM(uqa.total_wrong) as total_wrong,
  ROUND(AVG(uqa.best_score_percentage), 2) as average_best_score_percentage,
  SUM(uqa.total_time_spent_seconds) as total_time_spent_seconds
FROM user_quiz_analytics uqa
GROUP BY uqa.user_id;

-- ================================================
-- ملاحظات
-- ================================================
-- 1. تأكد من تشغيل هذا السكريبت في Supabase SQL Editor
-- 2. قد تحتاج لتشغيل الأجزاء بشكل منفصل إذا كانت هناك أخطاء
-- 3. تأكد من وجود جداول users, quizzes, quiz_categories, quiz_questions مسبقاً
-- 4. RLS Policies مفتوحة حالياً (true) - قد تحتاج لتخصيصها حسب متطلباتك
