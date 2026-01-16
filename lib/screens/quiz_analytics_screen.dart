import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

/// شاشة التحليلات التفصيلية للاختبار 📊
class QuizAnalyticsScreen extends StatefulWidget {
  final String userId;
  final String quizId;
  final String quizTitle;

  const QuizAnalyticsScreen({
    super.key,
    required this.userId,
    required this.quizId,
    required this.quizTitle,
  });

  @override
  State<QuizAnalyticsScreen> createState() => _QuizAnalyticsScreenState();
}

class _QuizAnalyticsScreenState extends State<QuizAnalyticsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _analytics;
  List<Map<String, dynamic>> _weakQuestions = [];

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);

    try {
      final analytics = await SupabaseService.getDetailedUserStats(
        userId: widget.userId,
        quizId: widget.quizId,
      );

      final weakQuestions = await SupabaseService.getUserWeakQuestions(
        userId: widget.userId,
        limit: 10,
      );

      setState(() {
        _analytics = analytics;
        _weakQuestions = weakQuestions;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ خطأ في تحميل التحليلات: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D0D0D), Color(0xFF1A0A0A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _analytics == null
                    ? _buildEmptyState()
                    : _buildAnalyticsContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF8B0000).withAlpha(30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF8B0000).withAlpha(50),
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios,
                color: Color(0xFFDC143C),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📊 التحليلات التفصيلية',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.quizTitle,
                  style: TextStyle(
                    color: Colors.white.withAlpha(150),
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: Color(0xFFDC143C)),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF8B0000).withAlpha(30),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF8B0000).withAlpha(50),
                width: 2,
              ),
            ),
            child: const Text('📊', style: TextStyle(fontSize: 50)),
          ),
          const SizedBox(height: 20),
          const Text(
            'لا توجد بيانات',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ابدأ بحل الاختبار أولاً',
            style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOverviewCards(),
          const SizedBox(height: 24),
          _buildPerformanceSection(),
          const SizedBox(height: 24),
          _buildWeakQuestionsSection(),
        ],
      ),
    );
  }

  Widget _buildOverviewCards() {
    final totalAttempts = _analytics?['total_attempts'] ?? 0;
    final bestScore = _analytics?['best_score'] ?? 0;
    final bestPercentage = _analytics?['best_score_percentage'] ?? 0.0;
    final avgTime = _analytics?['average_time_per_question'] ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'نظرة عامة',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: '🎯',
                title: 'أفضل نتيجة',
                value: '${bestPercentage.toStringAsFixed(0)}%',
                subtitle: '$bestScore صحيح',
                color: const Color(0xFF00FF41),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: '🔄',
                title: 'المحاولات',
                value: '$totalAttempts',
                subtitle: 'محاولة',
                color: const Color(0xFF4A90E2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          icon: '⏱️',
          title: 'متوسط الوقت',
          value: '${avgTime.toStringAsFixed(1)}s',
          subtitle: 'لكل سؤال',
          color: const Color(0xFFFFA500),
          isFullWidth: true,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    bool isFullWidth = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withAlpha(30), color.withAlpha(10)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withAlpha(200),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceSection() {
    final totalCorrect = _analytics?['total_correct'] ?? 0;
    final totalWrong = _analytics?['total_wrong'] ?? 0;
    final totalAnswered = totalCorrect + totalWrong;
    final accuracy = totalAnswered > 0
        ? (totalCorrect / totalAnswered) * 100
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'الأداء',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF4A0E4E).withAlpha(50),
                const Color(0xFF2D1515).withAlpha(50),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF8B0000).withAlpha(50)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildPerformanceStat(
                    '✅',
                    'صحيح',
                    '$totalCorrect',
                    const Color(0xFF00FF41),
                  ),
                  _buildPerformanceStat(
                    '❌',
                    'خطأ',
                    '$totalWrong',
                    const Color(0xFFDC143C),
                  ),
                  _buildPerformanceStat(
                    '📈',
                    'الدقة',
                    '${accuracy.toStringAsFixed(0)}%',
                    const Color(0xFF4A90E2),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildProgressBar(accuracy / 100),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceStat(
    String icon,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildProgressBar(double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withAlpha(20),
            valueColor: AlwaysStoppedAnimation<Color>(
              progress >= 0.7
                  ? const Color(0xFF00FF41)
                  : progress >= 0.5
                  ? const Color(0xFFFFA500)
                  : const Color(0xFFDC143C),
            ),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildWeakQuestionsSection() {
    if (_weakQuestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🎯 الأسئلة التي تحتاج تحسين',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ..._weakQuestions.take(5).map((wq) => _buildWeakQuestionCard(wq)),
      ],
    );
  }

  Widget _buildWeakQuestionCard(Map<String, dynamic> weakQuestion) {
    final wrongCount = weakQuestion['wrong_count'] ?? 0;
    final totalAttempts = weakQuestion['total_attempts'] ?? 0;
    final question = weakQuestion['quiz_questions'];
    final questionText = question?['question'] ?? 'سؤال غير معروف';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFDC143C).withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDC143C).withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            questionText,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildBadge('$wrongCount أخطاء', const Color(0xFFDC143C)),
              const SizedBox(width: 8),
              _buildBadge('$totalAttempts محاولات', const Color(0xFF4A90E2)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
