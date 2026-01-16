import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class ExpertManagementTestScreen extends StatefulWidget {
  const ExpertManagementTestScreen({super.key});

  @override
  State<ExpertManagementTestScreen> createState() =>
      _ExpertManagementTestScreenState();
}

class _ExpertManagementTestScreenState
    extends State<ExpertManagementTestScreen> {
  String _result = '';
  bool _isLoading = false;

  Future<void> _testAddExpert() async {
    setState(() {
      _isLoading = true;
      _result = 'جاري الاختبار...';
    });

    try {
      // اختبار جلب المستخدمين
      final users = await SupabaseService.getAllUsers();
      debugPrint('✅ Users fetched: ${users.length}');

      if (users.isEmpty) {
        setState(() {
          _result = '❌ لا يوجد مستخدمين في القاعدة';
          _isLoading = false;
        });
        return;
      }

      final testUser = users.first;
      debugPrint('Testing with user: ${testUser['name']}');

      // اختبار إضافة مستشار
      final success = await SupabaseService.addExpert(
        userId: testUser['id'],
        displayName: 'مستشار تجريبي',
        bio: 'نبذة تجريبية',
        specialization: 'تخصص تجريبي',
        orderIndex: 0,
      );

      setState(() {
        _result = success
            ? '✅ تم إضافة المستشار بنجاح!'
            : '❌ فشل في إضافة المستشار - تحقق من Console';
        _isLoading = false;
      });

      if (success) {
        debugPrint('✅ Expert added successfully');
      } else {
        debugPrint('❌ Failed to add expert');
      }
    } catch (e) {
      debugPrint('❌ Exception: $e');
      setState(() {
        _result = '❌ خطأ: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اختبار إضافة المستشار'),
        backgroundColor: const Color(0xFF1A1A2E),
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _isLoading ? null : _testAddExpert,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'اختبار إضافة مستشار',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF4CAF50)),
                ),
                child: Text(
                  _result.isEmpty ? 'اضغط الزر للاختبار' : _result,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'تحقق من Console للتفاصيل',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
