import 'dart:async';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../widgets/badge_widget.dart'; // تأكد من استيراد الودجت
import 'quiz_analytics_screen.dart';

/// شاشة لعب الاختبار - تصميم مرعب 💀🩸
class QuizPlayScreen extends StatefulWidget {
  final Map<String, dynamic> quiz;
  final List<Map<String, dynamic>> questions;
  final String userId;
  final bool isPartOfCategory;

  const QuizPlayScreen({
    super.key,
    required this.quiz,
    required this.questions,
    required this.userId,
    this.isPartOfCategory = false,
  });

  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen> {
  int _currentQuestionIndex = 0;
  int _score = 0;
  int _wrongAnswers = 0; // تتبع الإجابات الخاطئة
  String? _selectedAnswer;
  bool _answered = false;

  Timer? _timer;
  int _remainingSeconds = 0;

  // ===== نظام الجلسات المتقدم =====
  String? _sessionId; // معرف الجلسة الحالية
  DateTime? _questionStartTime; // وقت بدء السؤال الحالي
  int _questionTimeSpent = 0; // الوقت المستغرق في السؤال الحالي
  Timer? _questionTimer; // مؤقت لحساب الوقت المستغرق

  Map<String, int>? _badgeSettings; // إعدادات الشارات لهذا القسم

  Map<String, dynamic> get _currentQuestion =>
      widget.questions[_currentQuestionIndex];
  bool get _isLastQuestion =>
      _currentQuestionIndex == widget.questions.length - 1;

  int? get _questionTimerSeconds {
    final hasTimer = _currentQuestion['has_timer'] == true;
    final timerSeconds = _currentQuestion['timer_seconds'];
    return (hasTimer && timerSeconds != null) ? timerSeconds as int : null;
  }

  @override
  void initState() {
    super.initState();
    _initializeSession();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _questionTimer?.cancel();
    super.dispose();
  }

  /// تهيئة الجلسة - البحث عن جلسة نشطة أو إنشاء جديدة
  Future<void> _initializeSession() async {
    try {
      final quizId = widget.quiz['id']?.toString() ?? '';

      // جلب إعدادات الشارات مسبقاً
      final categoryId = widget.quiz['category_id']?.toString() ?? '';
      final settings = await SupabaseService.getCategoryBadgeSettings(
        categoryId,
      );

      // البحث عن جلسة نشطة
      final activeSession = await SupabaseService.getActiveSession(
        userId: widget.userId,
        quizId: quizId,
      );

      if (activeSession != null) {
        // استئناف جلسة موجودة
        setState(() {
          _sessionId = activeSession['id'] as String;
          _currentQuestionIndex =
              activeSession['current_question_index'] as int? ?? 0;
          _score = activeSession['correct_count'] as int? ?? 0;
          _wrongAnswers =
              activeSession['wrong_count'] as int? ?? 0; // تحميل عدد الأخطاء
          _badgeSettings = settings;
        });
        debugPrint('✅ استئناف جلسة موجودة: $_sessionId');
      } else {
        // إنشاء جلسة جديدة
        final sessionId = await SupabaseService.createQuizSession(
          userId: widget.userId,
          quizId: quizId,
          totalQuestions: widget.questions.length,
        );

        setState(() {
          _sessionId = sessionId;
          _badgeSettings = settings;
        });
        debugPrint('✅ جلسة جديدة: $_sessionId');
      }

      // بدء تتبع الوقت للسؤال الحالي
      _startQuestionTimer();
      _startTimerIfNeeded();
    } catch (e) {
      debugPrint('❌ خطأ في تهيئة الجلسة: $e');
      _startTimerIfNeeded();
    }
  }

  /// بدء مؤقت لحساب الوقت المستغرق في السؤال
  void _startQuestionTimer() {
    _questionStartTime = DateTime.now();
    _questionTimeSpent = 0;

    _questionTimer?.cancel();
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!_answered) {
        setState(() {
          _questionTimeSpent++;
        });
      }
    });
  }

  /// إيقاف مؤقت السؤال وإرجاع الوقت المستغرق
  int _stopQuestionTimer() {
    _questionTimer?.cancel();
    if (_questionStartTime != null) {
      return DateTime.now().difference(_questionStartTime!).inSeconds;
    }
    return _questionTimeSpent;
  }

  void _startTimerIfNeeded() {
    _timer?.cancel();
    if (_questionTimerSeconds != null && _questionTimerSeconds! > 0) {
      _remainingSeconds = _questionTimerSeconds!;
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        // تنبية صوتي بسيط أو اهتزاز يمكن إضافته هنا مستقبلاً
        if (_remainingSeconds <= 5 && _remainingSeconds > 0) {
          // يمكن إضافة منطق هنا
        }

        setState(() {
          _remainingSeconds--;
        });

        if (_remainingSeconds <= 0) {
          timer.cancel();
          _timeExpired();
        }
      });
    }
  }

  void _timeExpired() {
    if (_answered) return;
    setState(() {
      _answered = true;
      _selectedAnswer = null;
      _wrongAnswers++; // زيادة عداد الأخطاء
    });

    // عرض رسالة انتهاء الوقت
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '⏰ انتهى الوقت!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFDC143C),
          duration: const Duration(milliseconds: 1200),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }

    // تسجيل المحاولة (تجاوز الوقت = إجابة خاطئة)
    _recordAttempt(isCorrect: false, userAnswer: null);

    // الانتقال التلقائي بعد 1.5 ثانية
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) _nextQuestion();
    });
  }

  void _selectAnswer(String answer) {
    if (_answered) return;
    _timer?.cancel();

    final correctAnswer = _currentQuestion['correct_answer'];
    final isCorrect = answer == correctAnswer;

    setState(() {
      _selectedAnswer = answer;
      _answered = true;
      if (isCorrect) {
        _score++;
      } else {
        _wrongAnswers++; // زيادة عداد الأخطاء
      }
    });

    // تسجيل المحاولة في النظام المتقدم
    _recordAttempt(isCorrect: isCorrect, userAnswer: answer);

    // حفظ التقدم بعد كل إجابة (النظام القديم للتوافق)
    _saveProgress();

    // الانتقال التلقائي بعد 1.5 ثانية
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) _nextQuestion();
    });
  }

  /// تسجيل محاولة الإجابة في النظام المتقدم
  Future<void> _recordAttempt({
    required bool isCorrect,
    String? userAnswer,
  }) async {
    if (_sessionId == null) return;

    final timeSpent = _stopQuestionTimer();
    final questionId = _currentQuestion['id']?.toString() ?? '';
    if (questionId.isEmpty) return;

    try {
      await SupabaseService.recordQuestionAttempt(
        sessionId: _sessionId!,
        questionId: questionId,
        questionText: _currentQuestion['question'] ?? '',
        questionType: _currentQuestion['question_type'] ?? 'multiple_choice',
        correctAnswer: _currentQuestion['correct_answer'] ?? '',
        userAnswer: userAnswer,
        isCorrect: isCorrect,
        timeSpentSeconds: timeSpent,
      );

      // تحديث الجلسة
      await SupabaseService.updateQuizSession(
        sessionId: _sessionId!,
        currentQuestionIndex: _currentQuestionIndex + 1,
        correctCount: _score,
        wrongCount: (_currentQuestionIndex + 1) - _score,
      );

      debugPrint(
        '✅ تم تسجيل المحاولة: ${isCorrect ? "صحيح" : "خطأ"}, الوقت: ${timeSpent}s',
      );
    } catch (e) {
      debugPrint('❌ خطأ في تسجيل المحاولة: $e');
    }
  }

  /// حفظ تقدم المستخدم في Supabase مع جميع الشارات المكتسبة
  Future<void> _saveProgress() async {
    final quizId = widget.quiz['id']?.toString() ?? '';
    final userId = widget.userId;

    debugPrint('💾 Saving progress: userId=$userId, quizId=$quizId');

    if (quizId.isEmpty || userId.isEmpty) {
      debugPrint('❌ Cannot save: quizId or userId is empty!');
      return;
    }

    try {
      List<String> earnedBadges = [];

      // استخدام الحدود من الحالة أو القيم الافتراضية
      final thresholds =
          _badgeSettings ??
          {
            'bronze': 10,
            'platinum': 11,
            'gold': 12,
            'purple': 14,
            'hero': 16,
            'royal': 17,
          };

      // إضافة جميع الشارات التي وصل إليها المستخدم
      if (_score >= (thresholds['bronze'] ?? 10)) {
        earnedBadges.add('bronze');
      }
      if (_score >= (thresholds['platinum'] ?? 11)) {
        earnedBadges.add('platinum');
      }
      if (_score >= (thresholds['gold'] ?? 12)) {
        earnedBadges.add('gold');
      }
      if (_score >= (thresholds['purple'] ?? 14)) {
        earnedBadges.add('purple');
      }
      if (_score >= (thresholds['hero'] ?? 16)) {
        earnedBadges.add('hero');
      }
      if (_score >= (thresholds['royal'] ?? 17)) {
        earnedBadges.add('royal');
      }

      // تحويل القائمة إلى نص مفصول بفواصل
      final earnedBadge = earnedBadges.isNotEmpty
          ? earnedBadges.join(',')
          : null;

      final success = await SupabaseService.saveUserQuizProgress(
        userId: userId,
        quizId: quizId,
        currentQuestion: _currentQuestionIndex + 1,
        correctAnswers: _score,
        wrongAnswers: _wrongAnswers, // استخدام العداد الصحيح
        earnedBadge: earnedBadge,
      );

      debugPrint(
        '💾 Progress saved: success=$success, question=${_currentQuestionIndex + 1}, score=$_score, wrong=$_wrongAnswers, badges=$earnedBadge',
      );
    } catch (e) {
      debugPrint('❌ Error saving progress: $e');
    }
  }

  void _nextQuestion() {
    _timer?.cancel();
    if (_isLastQuestion) {
      _showResults();
    } else {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswer = null;
        _answered = false;
      });
      _startQuestionTimer(); // بدء مؤقت السؤال التالي
      _saveProgress(); // حفظ التقدم عند الوصول للسؤال الجديد
      _startTimerIfNeeded();
    }
  }

  void _showResults() async {
    String? earnedBadge;
    BadgeType? highestBadge;

    try {
      final categoryId = widget.quiz['category_id']?.toString() ?? '';
      final settings = await SupabaseService.getCategoryBadgeSettings(
        categoryId,
      );

      // استخدام BadgeHelper للحصول على أعلى شارة مع الإعدادات الديناميكية
      highestBadge = BadgeHelper.getBadgeForScore(
        _score,
        bronzeThreshold: settings['bronze']!,
        platinumThreshold: settings['platinum']!,
        goldThreshold: settings['gold']!,
        purpleThreshold: settings['purple']!,
        heroThreshold: settings['hero']!,
        royalThreshold: settings['royal']!,
      );

      if (highestBadge != null) {
        earnedBadge = highestBadge.name; // تخزين اسم الشارة (e.g. 'royal')
      }
      debugPrint(
        '🏅 Highest Badge: score=$_score, categoryId=$categoryId, earnedBadge=$earnedBadge, thresholds=$settings',
      );
    } catch (e) {
      debugPrint('Error getting badge settings: $e');
    }

    try {
      // إنهاء الجلسة في النظام المتقدم
      if (_sessionId != null) {
        await SupabaseService.completeQuizSession(
          sessionId: _sessionId!,
          finalScore: _score,
          earnedBadges: earnedBadge,
        );

        // حساب التحليلات
        final categoryId = widget.quiz['category_id']?.toString() ?? '';
        if (categoryId.isNotEmpty) {
          await SupabaseService.calculateUserAnalytics(
            userId: widget.userId,
            quizId: widget.quiz['id']?.toString() ?? '',
            categoryId: categoryId,
          );
        }
      }

      // حفظ النتيجة مع الشارة (النظام القديم)
      await SupabaseService.saveQuizResult(
        userId: widget.userId,
        quizId: widget.quiz['id']?.toString() ?? '',
        score: _score,
        totalQuestions: widget.questions.length,
      );

      // حفظ التقدم مع جميع الشارات
      await SupabaseService.saveUserQuizProgress(
        userId: widget.userId,
        quizId: widget.quiz['id']?.toString() ?? '',
        currentQuestion: widget.questions.length,
        correctAnswers: _score,
        wrongAnswers: widget.questions.length - _score,
        earnedBadge: earnedBadge,
      );
    } catch (e) {
      debugPrint('Error saving quiz result: $e');
    }

    if (!mounted) return;

    if (widget.isPartOfCategory) {
      Navigator.pop(context, {
        'score': _score,
        'total': widget.questions.length,
        'badge': earnedBadge,
      });
      return;
    }

    final isSuccess = _score >= widget.questions.length / 2;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        backgroundColor: const Color(0xFF1A0A0A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isSuccess
                ? const Color(0xFF00FF41).withAlpha(50)
                : const Color(0xFF8B0000).withAlpha(50),
            width: 2,
          ),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
            maxWidth: 350,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // عرض الشارة إذا وجدت، وإلا عرض أيقونة النجاح/الفشل
                  if (isSuccess && highestBadge != null) ...[
                    BadgeWidget(type: highestBadge, size: 100),
                    const SizedBox(height: 12),
                    Text(
                      BadgeHelper.getBadgeName(highestBadge),
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      BadgeHelper.getBadgeDescription(highestBadge),
                      style: TextStyle(
                        color: Colors.white.withAlpha(150),
                        fontSize: 12,
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
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
                            blurRadius: 15,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: Text(
                        isSuccess ? '🏆' : '💀',
                        style: const TextStyle(fontSize: 40),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // العنوان
                  Text(
                    isSuccess ? '🎉 مبروك! أكملت القسم' : 'حاول مرة أخرى 💪',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // النتيجة
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
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
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSuccess
                            ? const Color(0xFF00FF41)
                            : const Color(0xFFDC143C),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$_score',
                          style: TextStyle(
                            color: isSuccess
                                ? const Color(0xFF00FF41)
                                : const Color(0xFFDC143C),
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          ' / ${widget.questions.length}',
                          style: TextStyle(
                            color: Colors.white.withAlpha(150),
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

                  // النسبة المئوية
                  Text(
                    '🩸 نسبة النجاة: ${((_score / widget.questions.length) * 100).round()}%',
                    style: TextStyle(
                      color: Colors.white.withAlpha(150),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // زر التحليلات
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuizAnalyticsScreen(
                              userId: widget.userId,
                              quizId: widget.quiz['id']?.toString() ?? '',
                              quizTitle: widget.quiz['title'] ?? 'اختبار',
                            ),
                          ),
                        );
                      },
                      icon: const Text('📊', style: TextStyle(fontSize: 18)),
                      label: const Text(
                        'التحليلات',
                        style: TextStyle(
                          color: Color(0xFF4A90E2),
                          fontSize: 14,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // أزرار الإعادة والخروج
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            setState(() {
                              _currentQuestionIndex = 0;
                              _score = 0;
                              _wrongAnswers = 0;
                              _selectedAnswer = null;
                              _answered = false;
                              _sessionId = null;
                            });
                            await _initializeSession();
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            '🔄 إعادة',
                            style: TextStyle(
                              color: Color(0xFF00FF41),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B0000),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'هروب 🚪',
                            style: TextStyle(color: Colors.white, fontSize: 14),
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

  @override
  Widget build(BuildContext context) {
    final questionType = _currentQuestion['question_type'];
    final isTrueFalse = questionType == 'true_false';

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        color: Colors.black,
        child: SafeArea(
          child: ShaderMask(
            shaderCallback: (Rect rect) {
              return const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black,
                  Colors.black,
                  Colors.transparent,
                ],
                stops: [0.0, 0.05, 0.95, 1.0],
              ).createShader(rect);
            },
            blendMode: BlendMode.dstIn,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 40),
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  children: [
                    // Header مرعب
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => _showExitConfirmation(),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B0000).withAlpha(30),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF8B0000).withAlpha(50),
                                ),
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Color(0xFFDC143C),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      '🎭 ',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                    Text(
                                      widget.quiz['title'] ?? 'اختبار',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'السؤال ${_currentQuestionIndex + 1} من ${widget.questions.length}',
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(100),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF006400), Color(0xFF00FF41)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00FF41).withAlpha(50),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Text(
                                  '💀 ',
                                  style: TextStyle(fontSize: 14),
                                ),
                                Text(
                                  '$_score',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // المؤقت المرعب
                    if (_questionTimerSeconds != null &&
                        _questionTimerSeconds! > 0) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _remainingSeconds <= 5
                                  ? [
                                      const Color(0xFF8B0000).withAlpha(40),
                                      const Color(0xFFDC143C).withAlpha(20),
                                    ]
                                  : [
                                      const Color(0xFF4A0E4E).withAlpha(40),
                                      const Color(0xFF2D1515).withAlpha(20),
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _remainingSeconds <= 5
                                  ? const Color(0xFFDC143C)
                                  : const Color(0xFFDC143C).withAlpha(50),
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _remainingSeconds <= 5 ? '💀' : '⏱️',
                                style: const TextStyle(fontSize: 24),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '$_remainingSeconds',
                                style: TextStyle(
                                  color: _remainingSeconds <= 5
                                      ? const Color(0xFFDC143C)
                                      : Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'ثانية',
                                style: TextStyle(
                                  color: _remainingSeconds <= 5
                                      ? const Color(0xFFDC143C).withAlpha(180)
                                      : Colors.white.withAlpha(150),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // Progress bar مرعب
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: const Color(0xFF8B0000).withAlpha(30),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value:
                                (_currentQuestionIndex + 1) /
                                widget.questions.length,
                            backgroundColor: Colors.transparent,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFDC143C),
                            ),
                            minHeight: 10,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // السؤال
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFF1A0A0A),
                                  const Color(0xFF2D1515).withAlpha(150),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF8B0000).withAlpha(50),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF8B0000).withAlpha(20),
                                  blurRadius: 15,
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                const Text('❓', style: TextStyle(fontSize: 30)),
                                const SizedBox(height: 16),
                                Text(
                                  _currentQuestion['question'] ?? '',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // الإجابات
                          if (isTrueFalse) ...[
                            _buildTrueFalseOption(
                              'true',
                              '✓ صح',
                              const Color(0xFF00FF41),
                            ),
                            const SizedBox(height: 16),
                            _buildTrueFalseOption(
                              'false',
                              '✗ خطأ',
                              const Color(0xFFDC143C),
                            ),
                          ] else ...[
                            ..._buildMultipleChoiceOptions(),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrueFalseOption(String value, String label, Color color) {
    final isSelected = _selectedAnswer == value;
    final correctAnswer = _currentQuestion['correct_answer'];
    final isCorrectAnswer = correctAnswer == value;

    Color backgroundColor = const Color(0xFF1A0A0A);
    Color borderColor = const Color(0xFF8B0000).withAlpha(40);

    if (_answered) {
      if (isCorrectAnswer) {
        backgroundColor = const Color(0xFF00FF41).withAlpha(30);
        borderColor = const Color(0xFF00FF41);
      } else if (isSelected && !isCorrectAnswer) {
        backgroundColor = const Color(0xFF8B0000).withAlpha(30);
        borderColor = const Color(0xFFDC143C);
      }
    } else if (isSelected) {
      backgroundColor = color.withAlpha(20);
      borderColor = color;
    }

    return GestureDetector(
      onTap: () => _selectAnswer(value),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: [
            BoxShadow(color: borderColor.withAlpha(30), blurRadius: 10),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_answered && isCorrectAnswer)
              const Text(
                '✓ ',
                style: TextStyle(fontSize: 24, color: Color(0xFF00FF41)),
              )
            else if (_answered && isSelected && !isCorrectAnswer)
              const Text(
                '✗ ',
                style: TextStyle(fontSize: 24, color: Color(0xFFDC143C)),
              ),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMultipleChoiceOptions() {
    final options = _currentQuestion['options'];
    if (options is! List || options.isEmpty) return [];

    final correctAnswer = _currentQuestion['correct_answer'];

    return List.generate(options.length, (index) {
      final option = options[index];
      final answerValue = '$index';
      final isSelected = _selectedAnswer == answerValue;
      final isCorrectAnswer = correctAnswer == answerValue;

      Color backgroundColor = const Color(0xFF1A0A0A);
      Color borderColor = const Color(0xFF8B0000).withAlpha(40);

      if (_answered) {
        if (isCorrectAnswer) {
          backgroundColor = const Color(0xFF00FF41).withAlpha(30);
          borderColor = const Color(0xFF00FF41);
        } else if (isSelected && !isCorrectAnswer) {
          backgroundColor = const Color(0xFF8B0000).withAlpha(30);
          borderColor = const Color(0xFFDC143C);
        }
      } else if (isSelected) {
        backgroundColor = const Color(0xFF8B0000).withAlpha(30);
        borderColor = const Color(0xFFDC143C);
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GestureDetector(
          onTap: () => _selectAnswer(answerValue),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 2),
              boxShadow: [
                BoxShadow(color: borderColor.withAlpha(20), blurRadius: 8),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: _answered && isCorrectAnswer
                        ? const LinearGradient(
                            colors: [Color(0xFF006400), Color(0xFF00FF41)],
                          )
                        : _answered && isSelected
                        ? const LinearGradient(
                            colors: [Color(0xFF8B0000), Color(0xFFDC143C)],
                          )
                        : isSelected
                        ? const LinearGradient(
                            colors: [Color(0xFF8B0000), Color(0xFFDC143C)],
                          )
                        : null,
                    color: !isSelected && !_answered
                        ? const Color(0xFF8B0000).withAlpha(30)
                        : null,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      String.fromCharCode(65 + index),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    option.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                if (_answered && isCorrectAnswer)
                  const Text(
                    '✓',
                    style: TextStyle(fontSize: 22, color: Color(0xFF00FF41)),
                  )
                else if (_answered && isSelected && !isCorrectAnswer)
                  const Text(
                    '✗',
                    style: TextStyle(fontSize: 22, color: Color(0xFFDC143C)),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A0A0A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: const Color(0xFF8B0000).withAlpha(100),
            width: 2,
          ),
        ),
        title: const Row(
          children: [
            Text('💀', style: TextStyle(fontSize: 24)),
            SizedBox(width: 10),
            Text('الهروب من الظلام؟', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'تقدمك محفوظ تلقائياً ✓ يمكنك المتابعة لاحقاً',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'متابعة',
              style: TextStyle(color: Color(0xFF00FF41)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B0000),
            ),
            child: const Text('هروب', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
