import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/supabase_service.dart';

class AskMeChatScreen extends StatefulWidget {
  final String conversationId;
  final String userId;
  final String expertId;
  final String expertName;
  final String? expertImage;

  const AskMeChatScreen({
    super.key,
    required this.conversationId,
    required this.userId,
    required this.expertId,
    required this.expertName,
    this.expertImage,
  });

  @override
  State<AskMeChatScreen> createState() => _AskMeChatScreenState();
}

class _AskMeChatScreenState extends State<AskMeChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isUploadingImage = false;
  bool _isRecording = false;
  bool _isPlayingVoice = false;
  String? _playingMessageId;
  int _recordingDuration = 0;
  Timer? _recordingTimer;
  RealtimeChannel? _realtimeChannel;
  RealtimeChannel? _typingChannel;

  // مؤشر الكتابة
  bool _isOtherTyping = false;
  Timer? _typingTimer;
  bool _hasText = false;

  // حالة الاتصال
  bool _isExpertOnline = true;
  String _expertStatus = 'متصل';

  // الردود السريعة المقترحة
  final List<String> _quickReplies = [
    'شكراً جزيلاً 🙏',
    'حسناً، فهمت ✅',
    'هل يمكنك التوضيح أكثر؟',
    'ممتاز! 👍',
  ];

  late AnimationController _typingAnimController;
  late Animation<double> _typingAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadMessages();
    _subscribeToMessages();
    _subscribeToTyping();
    _markAsRead();
    _checkExpertStatus();

    _messageController.addListener(_onTextChanged);
  }

  void _initAnimations() {
    _typingAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _typingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _typingAnimController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _typingTimer?.cancel();
    _recordingTimer?.cancel();
    _typingAnimController.dispose();

    if (_realtimeChannel != null) {
      SupabaseService.unsubscribeFromConversationMessages(_realtimeChannel!);
    }
    if (_typingChannel != null) {
      Supabase.instance.client.removeChannel(_typingChannel!);
    }

    // إيقاف مؤشر الكتابة عند الخروج
    _updateTypingStatus(false);

    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _messageController.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }

    // تحديث مؤشر الكتابة
    if (hasText) {
      _updateTypingStatus(true);
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _updateTypingStatus(false);
      });
    }
  }

  Future<void> _updateTypingStatus(bool isTyping) async {
    try {
      await SupabaseService.updateAskMeTypingStatus(
        conversationId: widget.conversationId,
        userId: widget.userId,
        isTyping: isTyping,
      );
    } catch (e) {
      debugPrint('❌ Error updating typing status: $e');
    }
  }

  void _subscribeToTyping() {
    _typingChannel = SupabaseService.subscribeToAskMeTyping(
      conversationId: widget.conversationId,
      currentUserId: widget.userId,
      onTypingChanged: (isTyping) {
        if (mounted) {
          setState(() => _isOtherTyping = isTyping);
        }
      },
    );
  }

  Future<void> _checkExpertStatus() async {
    try {
      final status = await SupabaseService.getExpertOnlineStatus(
        widget.expertId,
      );
      if (mounted) {
        setState(() {
          _isExpertOnline = status['is_online'] ?? false;
          _expertStatus = _isExpertOnline ? 'متصل' : 'غير متصل';
        });
      }
    } catch (e) {
      debugPrint('❌ Error checking expert status: $e');
    }
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final messages = await SupabaseService.getConversationMessages(
        widget.conversationId,
      );
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('❌ Error loading messages: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _subscribeToMessages() {
    _realtimeChannel = SupabaseService.subscribeToConversationMessages(
      widget.conversationId,
      (newMessage) {
        if (mounted) {
          setState(() {
            // تجنب التكرار
            final exists = _messages.any((m) => m['id'] == newMessage['id']);
            if (!exists) {
              _messages.add(newMessage);
            }
          });
          _scrollToBottom();
          if (newMessage['sender_id'] != widget.userId) {
            _markAsRead();
            // إضافة اهتزاز للإشعار
            HapticFeedback.lightImpact();
          }
        }
      },
    );
  }

  Future<void> _markAsRead() async {
    await SupabaseService.markMessagesAsRead(
      conversationId: widget.conversationId,
      userId: widget.userId,
    );
    await SupabaseService.resetUnreadCount(
      conversationId: widget.conversationId,
      isExpert: widget.userId == widget.expertId,
    );
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();
    _updateTypingStatus(false);

    try {
      await SupabaseService.sendAskMeMessage(
        conversationId: widget.conversationId,
        senderId: widget.userId,
        message: message,
      );
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('❌ Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('فشل إرسال الرسالة'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _pickAndSendImage() async {
    if (_isUploadingImage) return;

    try {
      // طلب إذن الوصول للصور (Android 13+) - فقط على الموبايل
      if (!kIsWeb && Platform.isAndroid) {
        PermissionStatus status = await Permission.photos.request();
        if (status.isDenied || status.isPermanentlyDenied) {
          // fallback للإصدارات الأقدم
          status = await Permission.storage.request();
        }

        if (status.isPermanentlyDenied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('يرجى السماح بالوصول للصور من الإعدادات'),
                backgroundColor: Colors.orange.shade700,
                behavior: SnackBarBehavior.floating,
                action: SnackBarAction(
                  label: 'الإعدادات',
                  textColor: Colors.white,
                  onPressed: () => openAppSettings(),
                ),
              ),
            );
          }
          return;
        }
      }

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920, // دقة عالية
        maxHeight: 1920, // الحفاظ على نسبة العرض للارتفاع
        imageQuality: 95, // جودة عالية جداً
      );

      if (image == null) return;

      if (mounted) {
        setState(() => _isUploadingImage = true);
      }

      final imageBytes = await image.readAsBytes();
      final fileSizeMB = imageBytes.length / (1024 * 1024);

      if (fileSizeMB > 10) {
        // رفع الحد الأقصى إلى 10 ميغابايت
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                '⚠️ الصورة كبيرة جداً (الحد الأقصى 10 ميغابايت)',
              ),
              backgroundColor: Colors.orange.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final success = await SupabaseService.sendAskMeImage(
        conversationId: widget.conversationId,
        senderId: widget.userId,
        imageBytes: imageBytes,
      );

      if (mounted) {
        if (success) {
          HapticFeedback.lightImpact();
          _scrollToBottom();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('❌ فشل إرسال الصورة'),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error in _pickAndSendImage: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  // ============ تسجيل الصوت ============
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        // محاولة الحصول على المسار من path_provider أو استخدام fallback
        String path;
        try {
          final dir = await getTemporaryDirectory();
          path =
              '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        } catch (e) {
          // fallback إذا فشل path_provider
          debugPrint('⚠️ path_provider failed, using fallback: $e');
          // على الويب نستخدم اسم ملف فقط، على native نستخدم مسار كامل
          if (kIsWeb) {
            path = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
          } else if (Platform.isAndroid) {
            path =
                '/data/user/0/com.example.test7/cache/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
          } else {
            path = '/tmp/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
          }
        }

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _recordingDuration = 0;
        });

        HapticFeedback.heavyImpact();

        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() => _recordingDuration++);
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('يرجى السماح بالوصول للميكروفون'),
              backgroundColor: Colors.orange.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error starting recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل بدء التسجيل: ${e.toString().split('\n').first}'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      _recordingTimer?.cancel();
      final path = await _audioRecorder.stop();

      setState(() => _isRecording = false);

      if (path != null && _recordingDuration >= 1) {
        await _sendVoiceMessage(path);
      }
    } catch (e) {
      debugPrint('❌ Error stopping recording: $e');
      if (mounted) {
        setState(() => _isRecording = false);
      }
    }
  }

  Future<void> _sendVoiceMessage(String path) async {
    try {
      setState(() => _isSending = true);

      // على الويب نستخدم http.get للحصول على البيانات من blob URL
      // على native نستخدم File
      late final Uint8List bytes;
      if (kIsWeb) {
        try {
          final response = await http.get(Uri.parse(path));
          if (response.statusCode == 200) {
            bytes = response.bodyBytes;
          } else {
            throw Exception('Failed to fetch audio: ${response.statusCode}');
          }
        } catch (e) {
          debugPrint('❌ Error fetching audio on web: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('❌ فشل إرسال الرسالة الصوتية على الويب'),
                backgroundColor: Colors.red.shade700,
              ),
            );
          }
          return;
        }
      } else {
        final file = File(path);
        bytes = await file.readAsBytes();
      }

      final success = await SupabaseService.sendAskMeVoice(
        conversationId: widget.conversationId,
        senderId: widget.userId,
        voiceBytes: bytes,
        duration: _recordingDuration,
      );

      if (success) {
        HapticFeedback.lightImpact();
        _scrollToBottom();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('❌ فشل إرسال الرسالة الصوتية'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error sending voice: $e');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _playVoice(String url, String messageId) async {
    try {
      if (_isPlayingVoice && _playingMessageId == messageId) {
        await _audioPlayer.stop();
        setState(() {
          _isPlayingVoice = false;
          _playingMessageId = null;
        });
      } else {
        await _audioPlayer.stop();
        await _audioPlayer.play(UrlSource(url));
        setState(() {
          _isPlayingVoice = true;
          _playingMessageId = messageId;
        });

        _audioPlayer.onPlayerComplete.listen((_) {
          if (mounted) {
            setState(() {
              _isPlayingVoice = false;
              _playingMessageId = null;
            });
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Error playing voice: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showImageFullScreen(String imageUrl) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: _FullScreenImage(imageUrl: imageUrl),
          );
        },
      ),
    );
  }

  void _showReactionPicker(Map<String, dynamic> message) {
    final reactions = ['❤️', '👍', '😂', '😮', '😢', '🙏'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'أضف رد فعل',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: reactions.map((emoji) {
                return GestureDetector(
                  onTap: () {
                    _addReaction(message['id'], emoji);
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 28)),
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

  Future<void> _addReaction(String messageId, String emoji) async {
    try {
      await SupabaseService.addAskMeReaction(
        messageId: messageId,
        userId: widget.userId,
        reaction: emoji,
      );
      HapticFeedback.lightImpact();
      _loadMessages(); // إعادة تحميل الرسائل لعرض الرد
    } catch (e) {
      debugPrint('❌ Error adding reaction: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0E27), Color(0xFF000000)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              if (_isOtherTyping) _buildTypingIndicator(),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF4CAF50),
                        ),
                      )
                    : _buildMessagesList(),
              ),
              if (!_isRecording) _buildQuickReplies(),
              _buildMessageInput(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF4CAF50).withValues(alpha: 0.2),
            Colors.transparent,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          ),
          Hero(
            tag: 'expert_${widget.expertId}',
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: widget.expertImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.network(
                        widget.expertImage!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 28,
                            ),
                      ),
                    )
                  : const Icon(Icons.person, color: Colors.white, size: 28),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.expertName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isExpertOnline
                            ? const Color(0xFF4CAF50)
                            : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _expertStatus,
                      style: TextStyle(
                        fontSize: 13,
                        color: _isExpertOnline
                            ? const Color(0xFF66BB6A)
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return AnimatedBuilder(
      animation: _typingAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...List.generate(3, (index) {
                      final delay = index * 0.2;
                      final opacity =
                          ((_typingAnimation.value + delay) % 1.0) > 0.5
                          ? 1.0
                          : 0.4;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF4CAF50,
                          ).withValues(alpha: opacity),
                          shape: BoxShape.circle,
                        ),
                      );
                    }),
                    const SizedBox(width: 8),
                    Text(
                      'يكتب...',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickReplies() {
    if (_messages.isEmpty || _hasText) return const SizedBox.shrink();

    return Container(
      height: 45,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _quickReplies.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(left: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  _messageController.text = _quickReplies[index];
                  _sendMessage();
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    _quickReplies[index],
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessagesList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF4CAF50).withValues(alpha: 0.2),
                          const Color(0xFF4CAF50).withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF4CAF50,
                          ).withValues(alpha: 0.15),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline,
                      size: 56,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'ابدأ المحادثة',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'أرسل رسالتك الأولى إلى ${widget.expertName}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    return Scrollbar(
      thickness: 6,
      radius: const Radius.circular(10),
      interactive: true,
      child: ListView.builder(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final message = _messages[index];
          final isMe = message['sender_id'] == widget.userId;
          return _buildMessageBubble(message, isMe);
        },
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isMe) {
    final messageType = message['message_type'] ?? 'text';
    final createdAt = message['created_at'];
    final isRead = message['is_read'] ?? false;
    final reactions = message['reactions'] as List<dynamic>? ?? [];

    String timeText = '';
    if (createdAt != null) {
      try {
        final date = DateTime.parse(createdAt);
        timeText = DateFormat('HH:mm').format(date);
      } catch (e) {
        timeText = '';
      }
    }

    return GestureDetector(
      onLongPress: () => _showReactionPicker(message),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: isMe
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isMe) ...[
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    padding: EdgeInsets.all(messageType == 'image' ? 4 : 12),
                    decoration: BoxDecoration(
                      gradient: isMe
                          ? const LinearGradient(
                              colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : const LinearGradient(
                              colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                            ),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMe ? 18 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isMe ? const Color(0xFF4CAF50) : Colors.black)
                              .withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMessageContent(message, messageType, isMe),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              timeText,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              Icon(
                                isRead ? Icons.done_all : Icons.done,
                                size: 14,
                                color: isRead
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.6),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (isMe) const SizedBox(width: 8),
              ],
            ),
            // عرض ردود الفعل
            if (reactions.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(
                  top: 4,
                  right: isMe ? 0 : 40,
                  left: isMe ? 40 : 0,
                ),
                child: Wrap(
                  spacing: 4,
                  children: reactions.map((r) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A2E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        r['reaction'] ?? '',
                        style: const TextStyle(fontSize: 14),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(
    Map<String, dynamic> message,
    String messageType,
    bool isMe,
  ) {
    final messageText = message['message'] ?? '';

    if (messageType == 'image') {
      return GestureDetector(
        onTap: () => _showImageFullScreen(messageText),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: CachedNetworkImage(
            imageUrl: messageText,
            fit: BoxFit.cover,
            maxHeightDiskCache: 1920, // حفظ بدقة عالية
            maxWidthDiskCache: 1920,
            memCacheHeight: 1080,
            memCacheWidth: 1080,
            placeholder: (context, url) => Container(
              height: 200,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'جاري التحميل...',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            errorWidget: (context, url, error) => Container(
              height: 150,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, size: 40, color: Colors.white54),
                  SizedBox(height: 8),
                  Text(
                    'فشل تحميل الصورة',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else if (messageType == 'voice') {
      final duration = message['voice_duration'] ?? 0;
      final isPlaying = _isPlayingVoice && _playingMessageId == message['id'];

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => _playVoice(messageText, message['id']),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 120,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: CustomPaint(
                  painter: _WaveformPainter(
                    isPlaying: isPlaying,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(duration ~/ 60).toString().padLeft(2, '0')}:${(duration % 60).toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      return Text(
        messageText,
        style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.4),
      );
    }
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: _isRecording ? _buildRecordingUI() : _buildNormalInputUI(),
      ),
    );
  }

  Widget _buildRecordingUI() {
    return Row(
      children: [
        // زر الإلغاء
        IconButton(
          onPressed: () {
            _recordingTimer?.cancel();
            _audioRecorder.cancel();
            setState(() => _isRecording = false);
          },
          icon: const Icon(Icons.delete, color: Colors.red),
        ),
        // مؤشر التسجيل
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 500),
                  builder: (context, value, child) {
                    return Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: value),
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                Text(
                  '${(_recordingDuration ~/ 60).toString().padLeft(2, '0')}:${(_recordingDuration % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                const Text(
                  'جاري التسجيل...',
                  style: TextStyle(color: Colors.red, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // زر الإرسال
        GestureDetector(
          onTap: _stopRecording,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
              ),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.send, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildNormalInputUI() {
    return Row(
      children: [
        // زر الصورة
        _buildActionButton(
          icon: Icons.image,
          onTap: _isUploadingImage ? null : _pickAndSendImage,
          isLoading: _isUploadingImage,
        ),
        const SizedBox(width: 8),
        // حقل النص
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF16213E),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
              ),
            ),
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'اكتب رسالتك...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                ),
                border: InputBorder.none,
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // زر الإرسال أو الصوت
        _hasText
            ? GestureDetector(
                onTap: _isSending ? null : _sendMessage,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: _isSending
                        ? LinearGradient(
                            colors: [
                              Colors.grey.shade700,
                              Colors.grey.shade600,
                            ],
                          )
                        : const LinearGradient(
                            colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                          ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _isSending
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white, size: 22),
                ),
              )
            : GestureDetector(
                onTap: _toggleRecording,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.mic, color: Colors.white, size: 24),
                ),
              ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
        ),
      ),
      child: IconButton(
        onPressed: onTap,
        icon: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                ),
              )
            : Icon(icon, color: const Color(0xFF4CAF50), size: 22),
      ),
    );
  }
}

// ===== رسام الموجة الصوتية =====
class _WaveformPainter extends CustomPainter {
  final bool isPlaying;
  final Color color;

  _WaveformPainter({required this.isPlaying, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final random = [0.3, 0.6, 0.9, 0.5, 0.7, 0.4, 0.8, 0.5, 0.6, 0.3];
    final barWidth = size.width / (random.length * 2);

    for (int i = 0; i < random.length; i++) {
      final x = i * barWidth * 2 + barWidth / 2;
      final height = size.height * random[i] * (isPlaying ? 1.0 : 0.5);
      final y = (size.height - height) / 2;

      canvas.drawLine(Offset(x, y), Offset(x, y + height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// عرض الصورة بملء الشاشة مع zoom
class _FullScreenImage extends StatelessWidget {
  final String imageUrl;

  const _FullScreenImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // الصورة بملء الشاشة مع إمكانية التكبير
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                // حفظ بدقة كاملة للعرض الكامل
                maxHeightDiskCache: 2560,
                maxWidthDiskCache: 2560,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(
                    Icons.broken_image,
                    size: 80,
                    color: Colors.white54,
                  ),
                ),
              ),
            ),
          ),
          // زر الإغلاق
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
