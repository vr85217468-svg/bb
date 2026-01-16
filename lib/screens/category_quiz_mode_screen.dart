import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../widgets/badge_widget.dart';
import 'quiz_play_screen.dart';

/// شاشة وضع الاختبار المتسلسل - تصميم مرعب 💀
class CategoryQuizModeScreen extends StatefulWidget {
  final Map<String, dynamic> category;
  final String userId;

  const CategoryQuizModeScreen({
    super.key,
    required this.category,
    required this.userId,
  });

  @override
  State<CategoryQuizModeScreen> createState() => _CategoryQuizModeScreenState();
}

class _CategoryQuizModeScreenState extends State<CategoryQuizModeScreen> {
  List<Map<String, dynamic>> _quizzes = [];
  int _currentQuizIndex = 0;
  int _totalScore = 0;
  int _totalQuestions = 0;
  bool _isLoading = true;
  bool _allCompleted = false;

  @override
  void initState() {
    super.initState();
    _loadQuizzes();
  }

  Future<void> _loadQuizzes() async {
    final quizzes = await SupabaseService.getQuizzes(widget.category['id']);
    if (mounted) {
      setState(() {
        _quizzes = quizzes;
        _isLoading = false;
      });

      if (_quizzes.isNotEmpty) {
        // تحديد الاختبار الذي يجب البدء منه
        await _determineStartingQuiz();
        _startCurrentQuiz();
      }
    }
  }

  /// تحديد من أي اختبار نبدأ بناءً على التقدم المحفوظ
  Future<void> _determineStartingQuiz() async {
    for (int i = 0; i < _quizzes.length; i++) {
      final quizId = _quizzes[i]['id']?.toString() ?? '';
      if (quizId.isEmpty) continue;

      // جلب التقدم لهذا الاختبار
      final progress = await SupabaseService.getUserQuizProgress(
        userId: widget.userId,
        quizId: quizId,
      );

      if (progress == null) {
        // اختبار لم يبدأ بعد - نبدأ منه
        setState(() => _currentQuizIndex = i);
        debugPrint('🎯 البدء من اختبار $i (لم يبدأ بعد)');
        return;
      }

      final currentQuestion = progress['current_question'] as int? ?? 0;
      final questions = await SupabaseService.getQuizQuestions(quizId);
      final totalQuestions = questions.length;

      if (currentQuestion < totalQuestions) {
        // اختبار غير مكتمل - نستأنفه
        setState(() => _currentQuizIndex = i);
        debugPrint(
          '🎯 استئناف اختبار $i (السؤال $currentQuestion من $totalQuestions)',
        );
        return;
      }

      // هذا الاختبار مكتمل - نتابع للتالي
    }

    // كل الاختبارات مكتملة
    setState(() => _currentQuizIndex = _quizzes.length);
    debugPrint('✅ جميع الاختبارات مكتملة');
  }

  Future<void> _startCurrentQuiz() async {
    if (_currentQuizIndex >= _quizzes.length) {
      setState(() => _allCompleted = true);
      return;
    }

    final quiz = _quizzes[_currentQuizIndex];
    final questions = await SupabaseService.getQuizQuestions(quiz['id']);

    if (!mounted) return;

    if (questions.isEmpty) {
      // تخطي الاختبار الفارغ
      _currentQuizIndex++;
      _startCurrentQuiz();
      return;
    }

    // الانتقال لشاشة الاختبار
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => QuizPlayScreen(
          quiz: quiz,
          questions: questions,
          userId: widget.userId,
          isPartOfCategory: true,
        ),
      ),
    );

    if (!mounted) return;

    if (result != null) {
      setState(() {
        _totalScore += (result['score'] as num?)?.toInt() ?? 0;
        _totalQuestions += (result['total'] as num?)?.toInt() ?? 0;
        _currentQuizIndex++;
      });

      if (_currentQuizIndex >= _quizzes.length) {
        setState(() => _allCompleted = true);
      } else {
        _startCurrentQuiz();
      }
    } else {
      // المستخدم خرج من الاختبار - الخروج مباشرة بدون تأكيد إضافي
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  double get _percentage =>
      _totalQuestions > 0 ? (_totalScore / _totalQuestions) * 100 : 0;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0D0D0D), Color(0xFF1A0A0A)],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: Color(0xFF8B0000)),
          ),
        ),
      );
    }

    if (_quizzes.isEmpty) {
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
                Padding(
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
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
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
                          child: const Text(
                            '💀',
                            style: TextStyle(fontSize: 50),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          '🩸 لا توجد اختبارات',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'الأرواح لم تُعد الاختبارات بعد...',
                          style: TextStyle(
                            color: Colors.white.withAlpha(100),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_allCompleted) {
      return _buildResultScreen();
    }

    // شاشة التحميل بين الاختبارات
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D0D0D), Color(0xFF1A0A0A)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B0000).withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const CircularProgressIndicator(
                  color: Color(0xFFDC143C),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '🎭 جاري تحضير الاختبار...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'الاختبار ${_currentQuizIndex + 1} من ${_quizzes.length}',
                style: TextStyle(
                  color: Colors.white.withAlpha(100),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultScreen() {
    final isSuccess = _percentage >= 50;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D0D0D), Color(0xFF1A0A0A), Color(0xFF0A0505)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // عرض شارة الفئة إذا وجدت، وإلا عرض أيقونة النجاح/الفشل
                  FutureBuilder<String?>(
                    future: SupabaseService.getUserBadgeForCategory(
                      userId: widget.userId,
                      categoryId: widget.category['id'] ?? '',
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data != null) {
                        final rawBadges = snapshot.data!.split(',');
                        final List<BadgeType> badges = [];

                        for (var b in rawBadges) {
                          try {
                            final name = b.trim();
                            if (name.isNotEmpty) {
                              badges.add(
                                BadgeType.values.firstWhere(
                                  (e) => e.name == name,
                                ),
                              );
                            }
                          } catch (_) {}
                        }

                        if (badges.isNotEmpty) {
                          // ترتيب للحصول على الأعلى دائماً في النهاية
                          badges.sort((a, b) => a.index.compareTo(b.index));
                          final type = badges.last;

                          return Column(
                            children: [
                              BadgeWidget(type: type, size: 120),
                              const SizedBox(height: 12),
                              Text(
                                BadgeHelper.getBadgeName(type),
                                style: const TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          );
                        }
                      }

                      return Container(
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: isSuccess
                              ? const Color(0xFF00FF41).withAlpha(20)
                              : const Color(0xFF8B0000).withAlpha(20),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSuccess
                                ? const Color(0xFF00FF41).withAlpha(50)
                                : const Color(0xFF8B0000).withAlpha(50),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isSuccess
                                  ? const Color(0xFF00FF41).withAlpha(30)
                                  : const Color(0xFF8B0000).withAlpha(30),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: Text(
                          isSuccess ? '🏆' : '💀',
                          style: const TextStyle(fontSize: 60),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // العنوان
                  Text(
                    isSuccess ? 'نجوت من الظلام! 🎉' : 'الظلام ابتلعك... 💀',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // اسم القسم
                  Text(
                    widget.category['name'] ?? '',
                    style: TextStyle(
                      color: Colors.white.withAlpha(150),
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // النتيجة الكبيرة
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isSuccess
                            ? [
                                const Color(0xFF00FF41).withAlpha(30),
                                const Color(0xFF006400).withAlpha(20),
                              ]
                            : [
                                const Color(0xFF8B0000).withAlpha(30),
                                const Color(0xFFDC143C).withAlpha(20),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isSuccess
                            ? const Color(0xFF00FF41)
                            : const Color(0xFFDC143C),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${_percentage.toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: isSuccess
                                ? const Color(0xFF00FF41)
                                : const Color(0xFFDC143C),
                            fontSize: 64,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$_totalScore من $_totalQuestions',
                          style: TextStyle(
                            color: Colors.white.withAlpha(150),
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // عدد الاختبارات المكتملة
                  Text(
                    '🎭 أكملت ${_quizzes.length} اختبارات',
                    style: TextStyle(
                      color: Colors.white.withAlpha(100),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // أزرار
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4A0E4E), Color(0xFF2D1515)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF8B0000).withAlpha(50),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.arrow_back,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'هروب',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _currentQuizIndex = 0;
                              _totalScore = 0;
                              _totalQuestions = 0;
                              _allCompleted = false;
                            });
                            _startCurrentQuiz();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8B0000), Color(0xFFDC143C)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF8B0000).withAlpha(100),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.refresh,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'إعادة',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
