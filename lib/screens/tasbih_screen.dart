import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// صفحة المسبحة الإلكترونية - تصميم مرعب 💀
class TasbihScreen extends StatefulWidget {
  const TasbihScreen({super.key});

  @override
  State<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends State<TasbihScreen>
    with SingleTickerProviderStateMixin {
  int _count = 0;
  int _totalCount = 0;
  int _targetCount = 0; // 0 = غير محدود (افتراضي)
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  final List<int> _targetOptions = [0, 33, 99, 100, 500, 1000]; // 0 = غير محدود

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _incrementCount() {
    HapticFeedback.lightImpact();
    _animationController.forward().then((_) {
      _animationController.reverse();
    });

    setState(() {
      _count++;
      _totalCount++;
      // عرض رسالة الإكمال فقط إذا كان هناك هدف محدد
      if (_targetCount > 0 && _count >= _targetCount) {
        _showCompletionDialog();
      }
    });
  }

  void _resetCount() {
    HapticFeedback.mediumImpact();
    setState(() {
      _count = 0;
    });
  }

  void _resetAll() {
    HapticFeedback.heavyImpact();
    setState(() {
      _count = 0;
      _totalCount = 0;
    });
  }

  void _showCompletionDialog() {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A0A0A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF00FF41), width: 2),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏆', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 16),
            const Text(
              'أحسنت!',
              style: TextStyle(
                color: Color(0xFF00FF41),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'أكملت $_targetCount تسبيحة',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetCount();
            },
            child: const Text(
              'متابعة',
              style: TextStyle(color: Color(0xFF00FF41)),
            ),
          ),
        ],
      ),
    );
  }

  void _showTargetSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A0A0A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🎯 اختر الهدف',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _targetOptions.map((target) {
                final isSelected = _targetCount == target;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _targetCount = target;
                      _count = 0;
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [Color(0xFF8B0000), Color(0xFFDC143C)],
                            )
                          : null,
                      color: isSelected ? null : const Color(0xFF2D1515),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFDC143C)
                            : const Color(0xFF8B0000).withAlpha(50),
                      ),
                    ),
                    child: Text(
                      target == 0 ? '∞' : '$target',
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // إذا كان الهدف غير محدود، لا نعرض شريط التقدم
    final bool isUnlimited = _targetCount == 0;
    final progress = isUnlimited ? 0.0 : _count / _targetCount;

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
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B0000).withAlpha(30),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Color(0xFFDC143C),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      '📿 المسبحة',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    // زر تغيير الهدف
                    GestureDetector(
                      onTap: _showTargetSelector,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B0000).withAlpha(30),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF8B0000).withAlpha(50),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.flag,
                              color: Color(0xFFDC143C),
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _targetCount == 0 ? '∞' : '$_targetCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // العداد الرئيسي
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // العداد الكلي
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00FF41).withAlpha(20),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF00FF41).withAlpha(50),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '📊 الإجمالي: ',
                            style: TextStyle(color: Colors.white70),
                          ),
                          Text(
                            '$_totalCount',
                            style: const TextStyle(
                              color: Color(0xFF00FF41),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // دائرة التقدم والعد
                    GestureDetector(
                      onTap: _incrementCount,
                      child: AnimatedBuilder(
                        animation: _scaleAnimation,
                        builder: (context, child) => Transform.scale(
                          scale: _scaleAnimation.value,
                          child: child,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // دائرة التقدم
                            SizedBox(
                              width: 250,
                              height: 250,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 12,
                                backgroundColor: const Color(
                                  0xFF8B0000,
                                ).withAlpha(30),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFFDC143C),
                                ),
                              ),
                            ),
                            // الدائرة الداخلية
                            Container(
                              width: 220,
                              height: 220,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    const Color(0xFF2D1515),
                                    const Color(0xFF1A0A0A),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF8B0000,
                                    ).withAlpha(50),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  ),
                                ],
                                border: Border.all(
                                  color: const Color(0xFF8B0000).withAlpha(100),
                                  width: 3,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '$_count',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 72,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    isUnlimited ? '' : 'من $_targetCount',
                                    style: TextStyle(
                                      color: Colors.white.withAlpha(150),
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'اضغط للتسبيح',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),

                    const SizedBox(height: 40),

                    // أزرار التحكم
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // زر إعادة العد
                        GestureDetector(
                          onTap: _resetCount,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B0000).withAlpha(30),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF8B0000).withAlpha(50),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.refresh, color: Color(0xFFDC143C)),
                                SizedBox(width: 8),
                                Text(
                                  'إعادة العد',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // زر إعادة الكل
                        GestureDetector(
                          onTap: _resetAll,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.withAlpha(30),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.red.withAlpha(50),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.delete_forever, color: Colors.red),
                                SizedBox(width: 8),
                                Text(
                                  'مسح الكل',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
