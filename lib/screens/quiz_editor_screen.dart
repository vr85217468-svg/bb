import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class QuizEditorScreen extends StatefulWidget {
  final Map<String, dynamic> category;

  const QuizEditorScreen({super.key, required this.category});

  @override
  State<QuizEditorScreen> createState() => _QuizEditorScreenState();
}

class _QuizEditorScreenState extends State<QuizEditorScreen> {
  List<Map<String, dynamic>> _quizzes = [];
  bool _isLoading = true;

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
    }
  }

  Future<void> _addQuiz() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'إضافة اختبار جديد',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'عنوان الاختبار',
                hintStyle: TextStyle(color: Colors.white.withAlpha(100)),
                filled: true,
                fillColor: Colors.white.withAlpha(15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'وصف الاختبار (اختياري)',
                hintStyle: TextStyle(color: Colors.white.withAlpha(100)),
                filled: true,
                fillColor: Colors.white.withAlpha(15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text(
              'إلغاء',
              style: TextStyle(color: Colors.white.withAlpha(150)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.trim().isNotEmpty) {
                Navigator.pop(context, {
                  'title': titleController.text.trim(),
                  'description': descController.text.trim(),
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
            ),
            child: const Text('إضافة', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != null) {
      final quiz = await SupabaseService.addQuiz(
        categoryId: widget.category['id'],
        title: result['title']!,
        description: result['description']!.isNotEmpty
            ? result['description']
            : null,
      );
      if (quiz != null) {
        await _loadQuizzes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إضافة الاختبار'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteQuiz(Map<String, dynamic> quiz) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'حذف الاختبار',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'هل أنت متأكد من حذف "${quiz['title']}"؟',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'إلغاء',
              style: TextStyle(color: Colors.white.withAlpha(150)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await SupabaseService.deleteQuiz(quiz['id']);
      if (success) {
        await _loadQuizzes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف الاختبار'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  Future<void> _editQuiz(Map<String, dynamic> quiz) async {
    final titleController = TextEditingController(text: quiz['title'] ?? '');
    final descController = TextEditingController(
      text: quiz['description'] ?? '',
    );

    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.edit, color: Colors.amber),
            SizedBox(width: 12),
            Text('تعديل الاختبار', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'عنوان الاختبار',
                hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
                filled: true,
                fillColor: Colors.white.withAlpha(15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'الوصف (اختياري)',
                hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
                filled: true,
                fillColor: Colors.white.withAlpha(15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: TextStyle(color: Colors.white.withAlpha(150)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.trim().isNotEmpty) {
                Navigator.pop(context, {
                  'title': titleController.text.trim(),
                  'description': descController.text.trim(),
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != null) {
      final success = await SupabaseService.updateQuiz(
        quiz['id'],
        title: result['title'],
        description: result['description'],
      );
      if (success) {
        await _loadQuizzes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تحديث الاختبار ✓'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    Expanded(
                      child: Text(
                        widget.category['name'] ?? 'اختبارات',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _addQuiz,
                      icon: const Icon(
                        Icons.add_circle,
                        color: Color(0xFF6366F1),
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF6366F1),
                        ),
                      )
                    : _quizzes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.assignment,
                              size: 80,
                              color: Colors.white.withAlpha(50),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'لا توجد اختبارات',
                              style: TextStyle(
                                color: Colors.white.withAlpha(150),
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _addQuiz,
                              icon: const Icon(
                                Icons.add,
                                color: Color(0xFF6366F1),
                              ),
                              label: const Text(
                                'إضافة اختبار',
                                style: TextStyle(color: Color(0xFF6366F1)),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _quizzes.length,
                        itemBuilder: (context, index) =>
                            _buildQuizCard(_quizzes[index]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuizCard(Map<String, dynamic> quiz) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white.withAlpha(20), Colors.white.withAlpha(10)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(30)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFF22C55E).withAlpha(50),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.assignment,
            color: Color(0xFF22C55E),
            size: 28,
          ),
        ),
        title: Text(
          quiz['title'] ?? '',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle:
            quiz['description'] != null &&
                quiz['description'].toString().isNotEmpty
            ? Text(
                quiz['description'],
                style: TextStyle(
                  color: Colors.white.withAlpha(150),
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _editQuiz(quiz),
              icon: const Icon(Icons.edit_note, color: Colors.amber, size: 22),
              tooltip: 'تعديل العنوان',
            ),
            IconButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuestionEditorScreen(quiz: quiz),
                  ),
                );
              },
              icon: const Icon(
                Icons.list_alt,
                color: Color(0xFF6366F1),
                size: 22,
              ),
              tooltip: 'الأسئلة',
            ),
            IconButton(
              onPressed: () => _deleteQuiz(quiz),
              icon: const Icon(Icons.delete, color: Colors.red, size: 22),
              tooltip: 'حذف',
            ),
          ],
        ),

        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => QuestionEditorScreen(quiz: quiz)),
          );
        },
      ),
    );
  }
}

// شاشة تحرير الأسئلة
class QuestionEditorScreen extends StatefulWidget {
  final Map<String, dynamic> quiz;

  const QuestionEditorScreen({super.key, required this.quiz});

  @override
  State<QuestionEditorScreen> createState() => _QuestionEditorScreenState();
}

class _QuestionEditorScreenState extends State<QuestionEditorScreen> {
  List<Map<String, dynamic>> _questions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final questions = await SupabaseService.getQuizQuestions(widget.quiz['id']);
    if (mounted) {
      setState(() {
        _questions = questions;
        _isLoading = false;
      });
    }
  }

  Future<void> _addQuestion() async {
    final result = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(builder: (_) => const AddQuestionScreen()),
    );

    if (result != null) {
      final question = await SupabaseService.addQuizQuestion(
        quizId: widget.quiz['id'],
        question: result['question'],
        questionType: result['type'],
        correctAnswer: result['correctAnswer'],
        options: result['options'],
        hasTimer: result['hasTimer'] ?? false,
        timerSeconds: result['timerSeconds'],
      );
      if (question != null) {
        await _loadQuestions();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إضافة السؤال'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteQuestion(Map<String, dynamic> question) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف السؤال', style: TextStyle(color: Colors.white)),
        content: const Text(
          'هل أنت متأكد من حذف هذا السؤال؟',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'إلغاء',
              style: TextStyle(color: Colors.white.withAlpha(150)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await SupabaseService.deleteQuizQuestion(question['id']);
      if (success) {
        await _loadQuestions();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف السؤال'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            widget.quiz['title'] ?? 'أسئلة',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_questions.length} سؤال',
                            style: TextStyle(
                              color: Colors.white.withAlpha(150),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _addQuestion,
                      icon: const Icon(
                        Icons.add_circle,
                        color: Color(0xFF6366F1),
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF6366F1),
                        ),
                      )
                    : _questions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.help_outline,
                              size: 80,
                              color: Colors.white.withAlpha(50),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'لا توجد أسئلة',
                              style: TextStyle(
                                color: Colors.white.withAlpha(150),
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _addQuestion,
                              icon: const Icon(
                                Icons.add,
                                color: Color(0xFF6366F1),
                              ),
                              label: const Text(
                                'إضافة سؤال',
                                style: TextStyle(color: Color(0xFF6366F1)),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _questions.length,
                        itemBuilder: (context, index) =>
                            _buildQuestionCard(_questions[index], index + 1),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> question, int number) {
    final isTrueFalse = question['question_type'] == 'true_false';
    final correctAnswer = question['correct_answer'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withAlpha(25), Colors.white.withAlpha(10)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // رقم السؤال والحذف
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withAlpha(100),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '$number',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // نوع السؤال
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isTrueFalse
                        ? Colors.amber.withAlpha(50)
                        : Colors.purple.withAlpha(50),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isTrueFalse ? Colors.amber : Colors.purple,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isTrueFalse ? Icons.check_circle : Icons.list,
                        color: isTrueFalse ? Colors.amber : Colors.purple,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isTrueFalse ? 'صح/خطأ' : 'اختيارات',
                        style: TextStyle(
                          color: isTrueFalse ? Colors.amber : Colors.purple,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // عرض الوقت المحدد إذا كان موجوداً
                if (question['has_timer'] == true &&
                    question['timer_seconds'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF22C55E).withAlpha(80),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${question['timer_seconds']} ث',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                IconButton(
                  onPressed: () => _deleteQuestion(question),
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.delete,
                      color: Colors.red,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // نص السؤال
            Text(
              question['question'] ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),

            // الإجابة الصحيحة
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withAlpha(100)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'الإجابة الصحيحة: ',
                    style: TextStyle(
                      color: Colors.white.withAlpha(180),
                      fontSize: 13,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      isTrueFalse
                          ? (correctAnswer == 'true' ? 'صح ✓' : 'خطأ ✗')
                          : _getOptionText(question, correctAnswer),
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getOptionText(Map<String, dynamic> question, String correctAnswer) {
    final options = question['options'];
    if (options is List && options.isNotEmpty) {
      final index = int.tryParse(correctAnswer) ?? 0;
      if (index < options.length) {
        return options[index];
      }
    }
    return correctAnswer;
  }
}

// شاشة إضافة سؤال جديدة بتصميم رهيب
class AddQuestionScreen extends StatefulWidget {
  const AddQuestionScreen({super.key});

  @override
  State<AddQuestionScreen> createState() => _AddQuestionScreenState();
}

class _AddQuestionScreenState extends State<AddQuestionScreen> {
  final _questionController = TextEditingController();
  final _option1Controller = TextEditingController();
  final _option2Controller = TextEditingController();
  final _option3Controller = TextEditingController();
  final _option4Controller = TextEditingController();

  String _questionType = 'multiple_choice'; // 'multiple_choice' أو 'true_false'
  int _correctOptionIndex = 0;
  bool _trueFalseAnswer = true;

  // متغيرات الوقت المحدد
  bool _hasTimer = false;
  double _timerSeconds = 30.0; // القيمة الافتراضية 30 ثانية

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f0f23)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                    const Expanded(
                      child: Text(
                        'إضافة سؤال جديد',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // اختيار نوع السؤال
                      const Text(
                        '📋 نوع السؤال',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTypeCard(
                              'multiple_choice',
                              'اختيارات',
                              Icons.list,
                              Colors.purple,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTypeCard(
                              'true_false',
                              'صح / خطأ',
                              Icons.check_circle,
                              Colors.amber,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // كتابة السؤال
                      const Text(
                        '❓ السؤال',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withAlpha(20),
                              Colors.white.withAlpha(10),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withAlpha(30)),
                        ),
                        child: TextField(
                          controller: _questionController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'اكتب السؤال هنا...',
                            hintStyle: TextStyle(
                              color: Colors.white.withAlpha(100),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(20),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // قسم الوقت المحدد
                      const Text(
                        '⏱️ الوقت المحدد',
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
                              Colors.white.withAlpha(20),
                              Colors.white.withAlpha(10),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withAlpha(30)),
                        ),
                        child: Column(
                          children: [
                            // مفتاح التفعيل
                            Row(
                              children: [
                                Icon(
                                  Icons.timer,
                                  color: _hasTimer
                                      ? const Color(0xFF22C55E)
                                      : Colors.white.withAlpha(150),
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'تفعيل الوقت المحدد للسؤال',
                                    style: TextStyle(
                                      color: Colors.white.withAlpha(200),
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: _hasTimer,
                                  onChanged: (value) {
                                    setState(() => _hasTimer = value);
                                  },
                                  thumbColor: const WidgetStatePropertyAll(
                                    Color(0xFF22C55E),
                                  ),
                                  trackColor: WidgetStatePropertyAll(
                                    const Color(0xFF22C55E).withAlpha(100),
                                  ),
                                ),
                              ],
                            ),

                            // شريط تحديد الوقت (يظهر فقط إذا تم التفعيل)
                            if (_hasTimer) ...[
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF22C55E).withAlpha(30),
                                      const Color(0xFF22C55E).withAlpha(15),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF22C55E,
                                    ).withAlpha(100),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'المدة:',
                                          style: TextStyle(
                                            color: Color(0xFF22C55E),
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF22C55E),
                                                Color(0xFF16A34A),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(
                                                  0xFF22C55E,
                                                ).withAlpha(100),
                                                blurRadius: 8,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            '${_timerSeconds.toInt()} ثانية',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    SliderTheme(
                                      data: SliderThemeData(
                                        activeTrackColor: const Color(
                                          0xFF22C55E,
                                        ),
                                        inactiveTrackColor: Colors.white
                                            .withAlpha(30),
                                        thumbColor: const Color(0xFF22C55E),
                                        overlayColor: const Color(
                                          0xFF22C55E,
                                        ).withAlpha(50),
                                        trackHeight: 6,
                                        thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 12,
                                        ),
                                      ),
                                      child: Slider(
                                        value: _timerSeconds,
                                        min: 5,
                                        max: 60,
                                        divisions:
                                            55, // من 5 إلى 60 = 55 خطوة (كل ثانية)
                                        onChanged: (value) {
                                          setState(() => _timerSeconds = value);
                                        },
                                      ),
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '5 ث',
                                          style: TextStyle(
                                            color: Colors.white.withAlpha(150),
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          '60 ث',
                                          style: TextStyle(
                                            color: Colors.white.withAlpha(150),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // الإجابات
                      if (_questionType == 'multiple_choice') ...[
                        const Text(
                          '✅ الخيارات (اضغط لتحديد الصحيح)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildOptionCard(
                          0,
                          _option1Controller,
                          'A',
                          const Color(0xFFEF4444),
                        ),
                        _buildOptionCard(
                          1,
                          _option2Controller,
                          'B',
                          const Color(0xFF3B82F6),
                        ),
                        _buildOptionCard(
                          2,
                          _option3Controller,
                          'C',
                          const Color(0xFF22C55E),
                        ),
                        _buildOptionCard(
                          3,
                          _option4Controller,
                          'D',
                          const Color(0xFFF59E0B),
                        ),
                      ] else ...[
                        const Text(
                          '✅ الإجابة الصحيحة',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildTrueFalseCard(true)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildTrueFalseCard(false)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // زر الإضافة
              Container(
                padding: const EdgeInsets.all(20),
                child: GestureDetector(
                  onTap: _submit,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withAlpha(100),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle, color: Colors.white, size: 24),
                        SizedBox(width: 12),
                        Text(
                          'إضافة السؤال',
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
        ),
      ),
    );
  }

  Widget _buildTypeCard(String type, String label, IconData icon, Color color) {
    final isSelected = _questionType == type;
    return GestureDetector(
      onTap: () => setState(() => _questionType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [color.withAlpha(100), color.withAlpha(50)],
                )
              : null,
          color: isSelected ? null : Colors.white.withAlpha(15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.white.withAlpha(30),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withAlpha(50),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.white.withAlpha(150),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.white.withAlpha(150),
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard(
    int index,
    TextEditingController controller,
    String letter,
    Color color,
  ) {
    final isSelected = _correctOptionIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _correctOptionIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    Colors.green.withAlpha(50),
                    Colors.green.withAlpha(20),
                  ],
                )
              : null,
          color: isSelected ? null : Colors.white.withAlpha(15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.green : Colors.white.withAlpha(30),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // حرف الخيار
            Container(
              width: 56,
              height: 56,
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isSelected
                      ? [Colors.green, Colors.green.shade700]
                      : [color.withAlpha(200), color],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: (isSelected ? Colors.green : color).withAlpha(80),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 28)
                    : Text(
                        letter,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            // حقل النص
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'الخيار $letter',
                  hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.only(right: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrueFalseCard(bool isTrue) {
    final isSelected = _trueFalseAnswer == isTrue;
    final color = isTrue ? Colors.green : Colors.red;
    final icon = isTrue ? Icons.check_circle : Icons.cancel;
    final text = isTrue ? 'صح ✓' : 'خطأ ✗';

    return GestureDetector(
      onTap: () => setState(() => _trueFalseAnswer = isTrue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [color.withAlpha(100), color.withAlpha(50)],
                )
              : null,
          color: isSelected ? null : Colors.white.withAlpha(15),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? color : Colors.white.withAlpha(30),
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withAlpha(80),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.white.withAlpha(150),
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              text,
              style: TextStyle(
                color: isSelected ? color : Colors.white.withAlpha(150),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (_questionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 12),
              Text('اكتب السؤال أولاً'),
            ],
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    if (_questionType == 'multiple_choice') {
      if (_option1Controller.text.trim().isEmpty ||
          _option2Controller.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.warning, color: Colors.white),
                SizedBox(width: 12),
                Text('أضف خيارين على الأقل'),
              ],
            ),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        return;
      }

      final options = [
        _option1Controller.text.trim(),
        _option2Controller.text.trim(),
        if (_option3Controller.text.trim().isNotEmpty)
          _option3Controller.text.trim(),
        if (_option4Controller.text.trim().isNotEmpty)
          _option4Controller.text.trim(),
      ];

      final actualCorrectIndex = _correctOptionIndex < options.length
          ? _correctOptionIndex
          : 0;

      Navigator.pop(context, {
        'question': _questionController.text.trim(),
        'type': 'multiple_choice',
        'correctAnswer': '$actualCorrectIndex',
        'options': options,
        'hasTimer': _hasTimer,
        'timerSeconds': _hasTimer ? _timerSeconds.toInt() : null,
      });
    } else {
      Navigator.pop(context, {
        'question': _questionController.text.trim(),
        'type': 'true_false',
        'correctAnswer': _trueFalseAnswer ? 'true' : 'false',
        'options': null,
        'hasTimer': _hasTimer,
        'timerSeconds': _hasTimer ? _timerSeconds.toInt() : null,
      });
    }
  }
}
