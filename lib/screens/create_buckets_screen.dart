import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

/// ==========================================
/// سكريبت لإنشاء 30 Bucket تلقائياً
/// ⚠️ يُشغل مرة واحدة فقط عند الإعداد الأولي
/// ==========================================

class CreateBucketsScreen extends StatefulWidget {
  const CreateBucketsScreen({super.key});

  @override
  State<CreateBucketsScreen> createState() => _CreateBucketsScreenState();
}

class _CreateBucketsScreenState extends State<CreateBucketsScreen> {
  bool _isCreating = false;
  final List<String> _logs = [];
  int _successCount = 0;
  int _failCount = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      appBar: AppBar(
        title: const Text('إنشاء Buckets للتخزين'),
        backgroundColor: const Color(0xFF1A1A2E),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // معلومات تحذيرية
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange, width: 2),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'تحذير مهم',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    '• هذا السكريبت يُشغل مرة واحدة فقط\n'
                    '• سيتم إنشاء 30 bucket للتخزين\n'
                    '• لا تقم بإعادة تشغيله مرة أخرى\n'
                    '• تأكد من اتصال الإنترنت',
                    style: TextStyle(color: Colors.white70, height: 1.5),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // زر البدء
            if (!_isCreating)
              ElevatedButton.icon(
                onPressed: _createBuckets,
                icon: const Icon(Icons.create_new_folder, size: 28),
                label: const Text(
                  'إنشاء 30 Bucket',
                  style: TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

            // شريط التقدم
            if (_isCreating) ...[
              const CircularProgressIndicator(color: Color(0xFF4CAF50)),
              const SizedBox(height: 16),
              Text(
                'جارٍ الإنشاء: $_successCount/30',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],

            const SizedBox(height: 24),

            // الإحصائيات
            if (_successCount > 0 || _failCount > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStatCard('نجح', _successCount, Colors.green),
                  const SizedBox(width: 16),
                  _buildStatCard('فشل', _failCount, Colors.red),
                ],
              ),

            const SizedBox(height: 24),

            // سجل العمليات
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    final isError = log.contains('❌') || log.contains('فشل');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        log,
                        style: TextStyle(
                          color: isError ? Colors.red : Colors.green,
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(label, style: TextStyle(color: color, fontSize: 14)),
        ],
      ),
    );
  }

  Future<void> _createBuckets() async {
    setState(() {
      _isCreating = true;
      _logs.clear();
      _successCount = 0;
      _failCount = 0;
    });

    _addLog('🚀 بدء إنشاء 30 bucket...');

    for (int i = 1; i <= 30; i++) {
      final bucketName = 'expert_chat_images_$i';

      try {
        _addLog('⏳ جارٍ إنشاء: $bucketName');

        // محاولة إنشاء البكت
        await SupabaseService.client.rpc(
          'create_storage_bucket',
          params: {'bucket_name': bucketName, 'is_public': true},
        );

        setState(() => _successCount++);
        _addLog('✅ تم إنشاء: $bucketName بنجاح');
      } catch (e) {
        // قد يفشل إذا كان موجوداً مسبقاً
        if (e.toString().contains('already exists') ||
            e.toString().contains('duplicate')) {
          setState(() => _successCount++);
          _addLog('ℹ️ $bucketName موجود مسبقاً');
        } else {
          setState(() => _failCount++);
          _addLog('❌ فشل إنشاء $bucketName: ${e.toString()}');
        }
      }

      // تأخير صغير لتجنب Rate Limiting
      await Future.delayed(const Duration(milliseconds: 200));
    }

    _addLog('');
    _addLog('━━━━━━━━━━━━━━━━━━━━━━');
    _addLog('✅ اكتمل! النجاح: $_successCount/30');
    if (_failCount > 0) {
      _addLog('⚠️ الفشل: $_failCount');
    }
    _addLog('━━━━━━━━━━━━━━━━━━━━━━');

    setState(() => _isCreating = false);

    // عرض رسالة نهائية
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _failCount == 0
                ? '✅ تم إنشاء جميع الـ Buckets بنجاح!'
                : '⚠️ بعض الـ Buckets فشل إنشاءها',
          ),
          backgroundColor: _failCount == 0 ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _addLog(String message) {
    setState(() {
      _logs.add(message);
    });
    debugPrint(message);
  }
}

// ==========================================
// كيفية الاستخدام:
// ==========================================

// 1. أضف هذا الملف في lib/screens/create_buckets_screen.dart

// 2. في main.dart أو أي مكان مؤقت، أضف زر للوصول:
/*
FloatingActionButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateBucketsScreen(),
      ),
    );
  },
  child: const Icon(Icons.settings),
)
*/

// 3. شغّل التطبيق واضغط على الزر
// 4. اضغط "إنشاء 30 Bucket"
// 5. انتظر حتى الانتهاء
// 6. احذف الكود بعد الانتهاء (لمرة واحدة فقط!)
