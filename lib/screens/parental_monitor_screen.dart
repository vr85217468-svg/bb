import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

/// صفحة مراقبة الأطفال 👨‍👩‍👧‍👦
class ParentalMonitorScreen extends StatefulWidget {
  const ParentalMonitorScreen({super.key});

  @override
  State<ParentalMonitorScreen> createState() => _ParentalMonitorScreenState();
}

class _ParentalMonitorScreenState extends State<ParentalMonitorScreen> {
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;
  Timer? _refreshTimer;
  String? _selectedUserId;

  // متغيرات التسجيل الصوتي
  double _audioDuration = 30; // مدة التسجيل بالثواني (5-120)
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingId;

  @override
  void initState() {
    super.initState();
    _loadSessions();
    // تحديث تلقائي كل 10 ثواني
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadSessions();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    final sessions = await SupabaseService.getAllUserSessions();
    if (mounted) {
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
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
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f0f23)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF6366F1),
                        ),
                      )
                    : _selectedUserId != null
                    ? _buildUserPhotos()
                    : _buildSessionsList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (_selectedUserId != null) {
                setState(() => _selectedUserId = null);
              } else {
                Navigator.pop(context);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.family_restroom,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _selectedUserId != null ? 'صور المستخدم' : 'مراقبة الأطفال',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          GestureDetector(
            onTap: _loadSessions,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.refresh, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsList() {
    if (_sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: Colors.white.withAlpha(50),
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد جلسات نشطة',
              style: TextStyle(
                color: Colors.white.withAlpha(150),
                fontSize: 18,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sessions.length,
      itemBuilder: (context, index) => _buildSessionCard(_sessions[index]),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    final user = session['users'] as Map<String, dynamic>?;
    final isOnline = session['is_online'] == true;
    final deviceName = session['device_name'] ?? 'غير معروف';
    final osVersion = session['os_version'] ?? '';
    final batteryLevel = session['battery_level'] as int?;
    final lastActivity = session['last_activity'];
    final profileImage = user?['profile_image'];
    final monitoringEnabled = session['monitoring_enabled'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white.withAlpha(20), Colors.white.withAlpha(10)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOnline
              ? Colors.green.withAlpha(100)
              : Colors.red.withAlpha(50),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // صورة المستخدم مع حالة الاتصال
                GestureDetector(
                  onTap: () {
                    if (user != null) {
                      setState(() => _selectedUserId = user['id']);
                    }
                  },
                  child: Stack(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withAlpha(20),
                          image: profileImage != null
                              ? DecorationImage(
                                  image: NetworkImage(profileImage),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: profileImage == null
                            ? Icon(
                                Icons.person,
                                color: Colors.white.withAlpha(150),
                                size: 30,
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: isOnline ? Colors.green : Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF1a1a2e),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // معلومات المستخدم
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (user != null) {
                        setState(() => _selectedUserId = user['id']);
                      }
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                user?['name'] ?? 'مستخدم',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isOnline
                                    ? Colors.green.withAlpha(50)
                                    : Colors.red.withAlpha(50),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isOnline ? '🟢 متصل' : '🔴 غير متصل',
                                style: TextStyle(
                                  color: isOnline ? Colors.green : Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // معلومات الجهاز
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            _buildInfoChip(Icons.phone_android, deviceName),
                            if (osVersion.isNotEmpty)
                              _buildInfoChip(Icons.android, osVersion),
                            if (batteryLevel != null)
                              _buildInfoChip(
                                batteryLevel > 20
                                    ? Icons.battery_std
                                    : Icons.battery_alert,
                                '$batteryLevel%',
                                color: batteryLevel > 20
                                    ? Colors.green
                                    : Colors.red,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // آخر نشاط
                        if (lastActivity != null)
                          Text(
                            'آخر نشاط: ${_formatTime(lastActivity)}',
                            style: TextStyle(
                              color: Colors.white.withAlpha(100),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // سهم للصور
                GestureDetector(
                  onTap: () {
                    if (user != null) {
                      setState(() => _selectedUserId = user['id']);
                    }
                  },
                  child: Icon(
                    Icons.photo_library,
                    color: Colors.white.withAlpha(100),
                  ),
                ),
              ],
            ),

            // ======== زر تفعيل/إيقاف المراقبة ========
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: monitoringEnabled
                      ? [
                          const Color(0xFF10B981).withAlpha(40),
                          const Color(0xFF059669).withAlpha(20),
                        ]
                      : [
                          const Color(0xFF6B7280).withAlpha(40),
                          const Color(0xFF4B5563).withAlpha(20),
                        ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: monitoringEnabled
                      ? const Color(0xFF10B981).withAlpha(60)
                      : const Color(0xFF6B7280).withAlpha(40),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    monitoringEnabled ? Icons.visibility : Icons.visibility_off,
                    color: monitoringEnabled
                        ? const Color(0xFF10B981)
                        : Colors.white.withAlpha(100),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'خدمة المراقبة',
                          style: TextStyle(
                            color: monitoringEnabled
                                ? const Color(0xFF10B981)
                                : Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          monitoringEnabled ? 'مفعّلة ✓' : 'متوقفة',
                          style: TextStyle(
                            color: monitoringEnabled
                                ? const Color(0xFF10B981).withAlpha(180)
                                : Colors.white.withAlpha(100),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: monitoringEnabled,
                    activeTrackColor: const Color(0xFF10B981).withAlpha(100),
                    activeThumbColor: const Color(0xFF10B981),
                    inactiveTrackColor: Colors.white.withAlpha(30),
                    inactiveThumbColor: Colors.white.withAlpha(150),
                    onChanged: (value) async {
                      if (user != null) {
                        final success =
                            await SupabaseService.setMonitoringEnabled(
                              user['id'],
                              value,
                            );
                        if (success) {
                          _loadSessions(); // إعادة تحميل القائمة
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  value
                                      ? '✅ تم تفعيل المراقبة على ${user['name']}'
                                      : '⏸️ تم إيقاف المراقبة على ${user['name']}',
                                ),
                                backgroundColor: value
                                    ? const Color(0xFF10B981)
                                    : Colors.grey,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? Colors.white.withAlpha(150)),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color ?? Colors.white.withAlpha(150),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserPhotos() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // أزرار التحكم
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // زر التقاط صورة
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _requestRemotePhoto,
                    icon: const Icon(Icons.camera_alt, size: 22),
                    label: const Text(
                      '📸 التقاط صورة الآن',
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // زر تسجيل الصوت
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showAudioRecordingDialog,
                    icon: const Icon(Icons.mic, size: 22),
                    label: const Text(
                      '🎙️ تسجيل صوت الآن',
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // تبويبات الصور والتسجيلات
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withAlpha(100),
              indicatorColor: const Color(0xFF6366F1),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(icon: Icon(Icons.photo_library), text: 'الصور'),
                Tab(icon: Icon(Icons.audiotrack), text: 'التسجيلات'),
              ],
            ),
          ),
          // محتوى التبويبات
          Expanded(
            child: TabBarView(
              children: [_buildPhotosGrid(), _buildAudioList()],
            ),
          ),
        ],
      ),
    );
  }

  /// شبكة الصور
  Widget _buildPhotosGrid() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: SupabaseService.getUserSessionPhotos(_selectedUserId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF6366F1)),
          );
        }

        final photos = snapshot.data ?? [];
        if (photos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  size: 80,
                  color: Colors.white.withAlpha(50),
                ),
                const SizedBox(height: 16),
                Text(
                  'لا توجد صور بعد',
                  style: TextStyle(
                    color: Colors.white.withAlpha(150),
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: photos.length,
          itemBuilder: (context, index) {
            final photo = photos[index];
            return GestureDetector(
              onTap: () => _showPhotoDialog(photo['photo_url']),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  image: DecorationImage(
                    image: NetworkImage(photo['photo_url']),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(150),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(16),
                      ),
                    ),
                    child: Text(
                      _formatTime(photo['created_at']),
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// قائمة التسجيلات الصوتية
  Widget _buildAudioList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: SupabaseService.getUserSessionAudio(_selectedUserId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF6366F1)),
          );
        }

        final audioList = snapshot.data ?? [];
        if (audioList.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.audiotrack_outlined,
                  size: 80,
                  color: Colors.white.withAlpha(50),
                ),
                const SizedBox(height: 16),
                Text(
                  'لا توجد تسجيلات بعد',
                  style: TextStyle(
                    color: Colors.white.withAlpha(150),
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: audioList.length,
          itemBuilder: (context, index) {
            final audio = audioList[index];
            final isPlaying = _currentlyPlayingId == audio['id'];
            final duration = audio['duration_seconds'] ?? 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withAlpha(20),
                    Colors.white.withAlpha(10),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isPlaying
                      ? const Color(0xFF8B5CF6)
                      : Colors.white.withAlpha(30),
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: GestureDetector(
                  onTap: () => _playAudio(audio['audio_url'], audio['id']),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isPlaying
                            ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                            : [
                                const Color(0xFF8B5CF6),
                                const Color(0xFF7C3AED),
                              ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPlaying ? Icons.stop : Icons.play_arrow,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                title: Text(
                  '🎙️ تسجيل صوتي',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      'المدة: ${_formatDuration(duration)}',
                      style: TextStyle(
                        color: Colors.white.withAlpha(150),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      _formatTime(audio['created_at']),
                      style: TextStyle(
                        color: Colors.white.withAlpha(100),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                trailing: Icon(
                  Icons.audiotrack,
                  color: Colors.white.withAlpha(100),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// نافذة اختيار مدة التسجيل
  void _showAudioRecordingDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            '🎙️ تسجيل صوت عن بعد',
            style: TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'اختر مدة التسجيل:',
                style: TextStyle(
                  color: Colors.white.withAlpha(180),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _formatDuration(_audioDuration.toInt()),
                style: const TextStyle(
                  color: Color(0xFF8B5CF6),
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Slider(
                value: _audioDuration,
                min: 5,
                max: 120,
                divisions: 23,
                activeColor: const Color(0xFF8B5CF6),
                inactiveColor: Colors.white.withAlpha(30),
                label: _formatDuration(_audioDuration.toInt()),
                onChanged: (value) {
                  setDialogState(() => _audioDuration = value);
                  setState(() {});
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '5 ثواني',
                    style: TextStyle(
                      color: Colors.white.withAlpha(100),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'دقيقتين',
                    style: TextStyle(
                      color: Colors.white.withAlpha(100),
                      fontSize: 12,
                    ),
                  ),
                ],
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
                Navigator.pop(context);
                _requestRemoteAudio();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
              ),
              child: const Text(
                '🎙️ ابدأ التسجيل',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// إرسال طلب تسجيل صوت
  Future<void> _requestRemoteAudio() async {
    if (_selectedUserId == null) return;

    final success = await SupabaseService.requestAudioRecording(
      _selectedUserId!,
      durationSeconds: _audioDuration.toInt(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '🎙️ تم إرسال طلب تسجيل صوت (${_formatDuration(_audioDuration.toInt())})!'
                : '❌ فشل إرسال الطلب',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  /// تشغيل تسجيل صوتي
  Future<void> _playAudio(String audioUrl, String audioId) async {
    try {
      if (_currentlyPlayingId == audioId) {
        await _audioPlayer.stop();
        setState(() => _currentlyPlayingId = null);
      } else {
        await _audioPlayer.stop();
        await _audioPlayer.play(UrlSource(audioUrl));
        setState(() => _currentlyPlayingId = audioId);

        _audioPlayer.onPlayerComplete.listen((_) {
          if (mounted) {
            setState(() => _currentlyPlayingId = null);
          }
        });
      }
    } catch (e) {
      // تجاهل خطأ AbortError على الويب
      debugPrint('⚠️ Audio play error (ignored): $e');
    }
  }

  /// تنسيق المدة
  String _formatDuration(int seconds) {
    if (seconds < 60) {
      return '$seconds ثانية';
    } else {
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      if (remainingSeconds == 0) {
        return '$minutes دقيقة';
      }
      return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _requestRemotePhoto() async {
    if (_selectedUserId == null) return;

    final success = await SupabaseService.requestPhotoCapture(_selectedUserId!);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? '📸 تم إرسال طلب التقاط صورة!' : '❌ فشل إرسال الطلب',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _showPhotoDialog(String photoUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(child: Image.network(photoUrl)),
        ),
      ),
    );
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'الآن';
      if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
      if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
      return 'منذ ${diff.inDays} يوم';
    } catch (e) {
      return '';
    }
  }
}
