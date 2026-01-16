import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import 'package:http/http.dart' as http;

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const ChatScreen({super.key, required this.user});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioRecorder _audioRecorder = AudioRecorder();

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isRecording = false;
  bool _isChatBanned = false; // حظر المحادثة
  String? _currentlyPlayingId;
  RealtimeChannel? _messagesChannel;
  RealtimeChannel? _chatBanChannel;

  late AnimationController _recordingAnimController;

  @override
  void initState() {
    super.initState();
    _recordingAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _loadMessages();
    _subscribeToMessages();
    _checkAndSubscribeChatBan();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _audioPlayer.dispose();
    _audioRecorder.dispose();
    _recordingAnimController.dispose();
    if (_messagesChannel != null) {
      SupabaseService.unsubscribeFromMessages(_messagesChannel!);
    }
    if (_chatBanChannel != null) {
      SupabaseService.unsubscribeFromMessages(_chatBanChannel!);
    }
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await SupabaseService.getMessages();
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _subscribeToMessages() {
    _messagesChannel = SupabaseService.subscribeToMessages((newMessage) {
      if (mounted) {
        final exists = _messages.any((m) => m['id'] == newMessage['id']);
        if (!exists) {
          setState(() {
            _messages.add(newMessage);
          });
          _scrollToBottom();
        }
      }
    });
  }

  /// التحقق من حظر المحادثة والاشتراك في التغييرات
  Future<void> _checkAndSubscribeChatBan() async {
    // التحقق من الحالة الحالية
    final isBanned = await SupabaseService.checkChatBan(widget.user['id']);
    if (mounted) {
      setState(() => _isChatBanned = isBanned);
    }

    // الاشتراك في التغييرات في الوقت الفعلي
    _chatBanChannel = SupabaseService.subscribeToChatBanStatus(
      widget.user['id'],
      (isChatBanned) {
        if (mounted) {
          setState(() => _isChatBanned = isChatBanned);
          if (isChatBanned) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ تم حظرك من المحادثة'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      },
    );
  }

  /// تعديل رسالة
  Future<void> _editMessage(Map<String, dynamic> message) async {
    final controller = TextEditingController(text: message['content'] ?? '');

    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'تعديل الرسالة',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          maxLines: 4,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withAlpha(15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
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
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
            ),
            child: const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != message['content']) {
      final success = await SupabaseService.editMessage(message['id'], result);
      if (success && mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m['id'] == message['id']);
          if (index != -1) {
            _messages[index]['content'] = result;
            _messages[index]['is_edited'] = true;
          }
        });
      }
    }
  }

  /// حذف رسالة
  Future<void> _deleteMessage(Map<String, dynamic> message) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف الرسالة', style: TextStyle(color: Colors.white)),
        content: const Text(
          'هل أنت متأكد من حذف هذه الرسالة؟',
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
      final success = await SupabaseService.deleteMessage(message['id']);
      if (success && mounted) {
        setState(() {
          _messages.removeWhere((m) => m['id'] == message['id']);
        });
      }
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

  Future<void> _sendTextMessage() async {
    // التحقق من حظر المحادثة
    if (_isChatBanned) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⛔ أنت محظور من إرسال الرسائل'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    _messageController.clear();
    setState(() => _isSending = true);

    try {
      final message = await SupabaseService.sendMessage(
        userId: widget.user['id'],
        content: text,
      );

      if (message != null && mounted) {
        final exists = _messages.any((m) => m['id'] == message['id']);
        if (!exists) {
          setState(() {
            _messages.add(message);
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل إرسال الرسالة: ${e.toString()}'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendImage() async {
    // التحقق من حظر المحادثة
    if (_isChatBanned) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⛔ أنت محظور من إرسال الرسائل'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (pickedFile == null) return;

    setState(() => _isSending = true);

    try {
      final bytes = await pickedFile.readAsBytes();
      final message = await SupabaseService.sendImageBytes(
        userId: widget.user['id'],
        imageBytes: bytes,
        fileName: pickedFile.name,
      );

      if (message != null && mounted) {
        final exists = _messages.any((m) => m['id'] == message['id']);
        if (!exists) {
          setState(() {
            _messages.add(message);
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل إرسال الصورة: ${e.toString()}'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _toggleRecording() async {
    // التحقق من حظر المحادثة
    if (_isChatBanned) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⛔ أنت محظور من إرسال الرسائل'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_isRecording) {
      // Stop recording and send
      try {
        final path = await _audioRecorder.stop();
        setState(() => _isRecording = false);

        if (path != null) {
          setState(() => _isSending = true);

          // Read the recorded file as bytes
          Uint8List audioBytes;
          if (kIsWeb) {
            // On web, the path is a blob URL - fetch it using http
            try {
              final response = await http.get(Uri.parse(path));
              if (response.statusCode == 200) {
                audioBytes = response.bodyBytes;
              } else {
                audioBytes = Uint8List(0);
              }
            } catch (e) {
              debugPrint('Error fetching blob: $e');
              audioBytes = Uint8List(0);
            }
          } else {
            // On mobile, read from file path
            final file = await _readFileAsBytes(path);
            audioBytes = file;
          }

          if (audioBytes.isNotEmpty) {
            final message = await SupabaseService.sendVoiceBytes(
              userId: widget.user['id'],
              voiceBytes: audioBytes,
              fileName: 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
            );

            if (message != null && mounted) {
              final exists = _messages.any((m) => m['id'] == message['id']);
              if (!exists) {
                setState(() {
                  _messages.add(message);
                });
                _scrollToBottom();
              }
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('فشل قراءة التسجيل الصوتي'),
                  backgroundColor: Colors.orange.shade400,
                ),
              );
            }
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فشل إرسال الصوت: ${e.toString()}'),
              backgroundColor: Colors.red.shade400,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isSending = false);
      }
    } else {
      // Start recording - first check permission
      try {
        final hasPermission = await _audioRecorder.hasPermission();

        if (!hasPermission) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('يرجى السماح بالوصول للميكروفون'),
                backgroundColor: Colors.orange.shade400,
                action: SnackBarAction(
                  label: 'حسناً',
                  textColor: Colors.white,
                  onPressed: () async {
                    await _audioRecorder.hasPermission();
                  },
                ),
              ),
            );
          }
          return;
        }

        // Start recording
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: kIsWeb ? '' : await _getRecordingPath(),
        );

        setState(() => _isRecording = true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فشل بدء التسجيل: ${e.toString()}'),
              backgroundColor: Colors.red.shade400,
            ),
          );
        }
      }
    }
  }

  Future<String> _getRecordingPath() async {
    if (kIsWeb) return '';

    // For mobile platforms, use path_provider
    try {
      final directory = await _getTemporaryDirectory();
      return '$directory/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    } catch (e) {
      debugPrint('Error getting recording path: $e');
      return '/tmp/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    }
  }

  Future<String> _getTemporaryDirectory() async {
    try {
      // استخدام path_provider للحصول على مسار المجلد المؤقت
      final directory = await getTemporaryDirectory();
      return directory.path;
    } catch (e) {
      debugPrint('Error getting temp directory: $e');
      return '/tmp';
    }
  }

  Future<Uint8List> _readFileAsBytes(String path) async {
    try {
      // قراءة الملف الصوتي من المسار
      final file = File(path);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (e) {
      debugPrint('Error reading file: $e');
    }
    return Uint8List(0);
  }

  Future<void> _playVoice(String url, String messageId) async {
    if (_currentlyPlayingId == messageId) {
      await _audioPlayer.stop();
      setState(() => _currentlyPlayingId = null);
    } else {
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
      setState(() => _currentlyPlayingId = messageId);

      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() => _currentlyPlayingId = null);
        }
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
            colors: [Color(0xFF0A0E27), Color(0xFF1A1F4E)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // شريط المكالمة النشطة
              _buildActiveCallBanner(),
              Expanded(
                child: _isLoading
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(25),
                            shape: BoxShape.circle,
                          ),
                          child: const CircularProgressIndicator(
                            color: Color(0xFF6366F1),
                            strokeWidth: 3,
                          ),
                        ),
                      )
                    : _messages.isEmpty
                    ? _buildEmptyState()
                    : _buildMessagesList(),
              ),
              _buildInputArea(),
            ],
          ),
        ),
      ),
    );
  }

  /// شريط العنوان بتصميم مرعب
  Widget _buildActiveCallBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1a0a0a),
            const Color(0xFF2d0a0a).withAlpha(200),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF8B0000).withAlpha(100),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // زر الرجوع
          GestureDetector(
            onTap: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF8B0000).withAlpha(30),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF8B0000).withAlpha(80),
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Color(0xFFDC143C),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // العنوان
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B0000), Color(0xFFDC143C)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B0000).withAlpha(100),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Text('💀', style: TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'الرسائل',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_messages.length} رسالة',
                      style: TextStyle(
                        color: Colors.white.withAlpha(120),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // أيقونة الحالة
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isChatBanned
                  ? Colors.red.withAlpha(30)
                  : const Color(0xFF00FF41).withAlpha(20),
              shape: BoxShape.circle,
              border: Border.all(
                color: _isChatBanned
                    ? Colors.red.withAlpha(100)
                    : const Color(0xFF00FF41).withAlpha(80),
              ),
            ),
            child: Icon(
              _isChatBanned ? Icons.block : Icons.circle,
              color: _isChatBanned ? Colors.red : const Color(0xFF00FF41),
              size: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // شبح روحي مخيف وجميل
          Stack(
            alignment: Alignment.center,
            children: [
              // هالة خارجية متوهجة
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF1E90FF).withAlpha(60), // أزرق سماوي
                      const Color(0xFF4169E1).withAlpha(40), // أزرق ملكي
                      const Color(0xFF191970).withAlpha(20), // أزرق منتصف الليل
                      Colors.transparent,
                    ],
                    stops: const [0.3, 0.5, 0.7, 1.0],
                  ),
                ),
              ),
              // الحلقة الخارجية المخيفة
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF0D1B2A), // أزرق ليلي داكن
                      const Color(0xFF1B263B), // كحلي غامق
                      const Color(0xFF415A77), // رمادي سماوي
                    ],
                  ),
                  border: Border.all(color: const Color(0xFF778DA9), width: 3),
                  boxShadow: [
                    // ظل سماوي متوهج
                    BoxShadow(
                      color: const Color(0xFF1E90FF).withAlpha(80),
                      blurRadius: 50,
                      spreadRadius: 15,
                    ),
                    // ظل أسود عميق
                    BoxShadow(
                      color: Colors.black.withAlpha(200),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
              ),
              // الحلقة الداخلية مع الشبح
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF87CEEB).withAlpha(40), // سماوي فاتح
                      const Color(0xFF1E3A5F).withAlpha(80), // أزرق داكن
                    ],
                  ),
                  border: Border.all(
                    color: const Color(0xFF87CEEB).withAlpha(100),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Text(
                    '👻',
                    style: TextStyle(
                      fontSize: 80,
                      shadows: [
                        Shadow(color: Color(0xFF1E90FF), blurRadius: 30),
                        Shadow(
                          color: Colors.black,
                          blurRadius: 15,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // نجوم متطايرة حول الشبح
              Positioned(
                top: 20,
                right: 30,
                child: Icon(
                  Icons.star,
                  size: 20,
                  color: const Color(0xFFE0E1DD).withAlpha(180),
                ),
              ),
              Positioned(
                bottom: 25,
                left: 25,
                child: Icon(
                  Icons.star,
                  size: 16,
                  color: const Color(0xFF87CEEB).withAlpha(150),
                ),
              ),
              Positioned(
                top: 50,
                left: 15,
                child: Icon(
                  Icons.auto_awesome,
                  size: 22,
                  color: const Color(0xFF1E90FF).withAlpha(200),
                ),
              ),
              Positioned(
                bottom: 40,
                right: 20,
                child: Icon(
                  Icons.auto_awesome,
                  size: 18,
                  color: const Color(0xFFE0E1DD).withAlpha(160),
                ),
              ),
            ],
          ),
          const SizedBox(height: 35),
          // العنوان الملكي
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1B263B).withAlpha(200),
                  const Color(0xFF0D1B2A).withAlpha(200),
                ],
              ),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: const Color(0xFF778DA9).withAlpha(150),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(100),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Text(
              '✨ لا توجد رسائل ✨',
              style: TextStyle(
                fontSize: 22,
                color: Color(0xFFE0E1DD),
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                shadows: [Shadow(color: Color(0xFF1E90FF), blurRadius: 15)],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // النص الثانوي
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1B263B).withAlpha(150),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF415A77).withAlpha(100)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.nights_stay,
                  color: const Color(0xFF87CEEB).withAlpha(200),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'أرسل رسالتك الأولى الآن',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF778DA9),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.nights_stay,
                  color: const Color(0xFF87CEEB).withAlpha(200),
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return ShaderMask(
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
          stops: [0.0, 0.03, 0.97, 1.0], // تلاشي أسطوري عند الحواف
        ).createShader(rect);
      },
      blendMode: BlendMode.dstIn,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        cacheExtent: 2000, // أقصى مسافة تخزين مؤقت لإلغاء أي "رمشة" بصرية
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final message = _messages[index];
          final isMe = message['user_id'] == widget.user['id'];
          final user = message['users'] as Map<String, dynamic>?;

          final showSenderInfo =
              index == 0 ||
              _messages[index - 1]['user_id'] != message['user_id'];

          return RepaintBoundary(
            child: _buildMessageBubble(message, isMe, user, showSenderInfo),
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble(
    Map<String, dynamic> message,
    bool isMe,
    Map<String, dynamic>? user,
    bool showSenderInfo,
  ) {
    final messageType = message['message_type'] ?? 'text';
    final createdAt = DateTime.parse(message['created_at']);
    final timeStr = DateFormat('HH:mm').format(createdAt);
    final isEdited = message['is_edited'] == true;

    return Padding(
      padding: EdgeInsets.only(top: showSenderInfo ? 16 : 4, bottom: 4),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && showSenderInfo) ...[
            _buildAvatar(user),
            const SizedBox(width: 8),
          ] else if (!isMe) ...[
            const SizedBox(width: 48),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isMe && showSenderInfo)
                  Padding(
                    padding: const EdgeInsets.only(right: 4, bottom: 4),
                    child: Text(
                      user?['name'] ?? 'مستخدم',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withAlpha(180),
                      ),
                    ),
                  ),
                // أزرار التعديل والحذف - تعمل على جميع الرسائل
                GestureDetector(
                  onLongPress: isMe
                      ? () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: const Color(0xFF0D1B2A),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(25),
                              ),
                            ),
                            builder: (context) => Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    const Color(0xFF1E3A5F),
                                    const Color(0xFF0D1B2A),
                                  ],
                                ),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(25),
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(height: 12),
                                  Container(
                                    width: 50,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4A90A4),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  // تعديل (فقط للنصوص)
                                  if (messageType == 'text')
                                    ListTile(
                                      leading: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withAlpha(30),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.edit,
                                          color: Colors.amber,
                                        ),
                                      ),
                                      title: const Text(
                                        'تعديل الرسالة',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _editMessage(message);
                                      },
                                    ),
                                  // حذف (للجميع)
                                  ListTile(
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withAlpha(30),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.delete_forever,
                                        color: Colors.red,
                                      ),
                                    ),
                                    title: Text(
                                      messageType == 'image'
                                          ? 'حذف الصورة'
                                          : messageType == 'voice'
                                          ? 'حذف التسجيل'
                                          : 'حذف الرسالة',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _deleteMessage(message);
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                ],
                              ),
                            ),
                          );
                        }
                      : null,
                  child: Column(
                    crossAxisAlignment: isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      // تصميم الرسالة الملكي الروحي
                      Container(
                        constraints: BoxConstraints(
                          maxWidth:
                              MediaQuery.of(context).size.width *
                              0.85, // عرض أكبر
                          minWidth:
                              MediaQuery.of(context).size.width *
                              0.4, // عرض أدنى
                        ),
                        decoration: BoxDecoration(
                          gradient: isMe
                              ? const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF1E3A5F), // أزرق سماوي ملكي
                                    Color(0xFF2E5077), // أزرق داكن
                                    Color(0xFF4A90A4), // سماوي
                                  ],
                                )
                              : const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF0D1B2A), // أزرق ليلي
                                    Color(0xFF1B2838), // رمادي سماوي
                                  ],
                                ),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(28),
                            topRight: const Radius.circular(28),
                            bottomLeft: Radius.circular(isMe ? 28 : 6),
                            bottomRight: Radius.circular(isMe ? 6 : 28),
                          ),
                          border: Border.all(color: Colors.black, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(150),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: const Color(0xFF4A90A4).withAlpha(40),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Stack(
                            children: [
                              // نجوم روحية كخلفية
                              Positioned(
                                right: isMe ? -20 : null,
                                left: isMe ? null : -20,
                                top: -15,
                                child: Icon(
                                  Icons.auto_awesome,
                                  size: 80,
                                  color: const Color(0xFF87CEEB).withAlpha(20),
                                ),
                              ),
                              Positioned(
                                right: isMe ? 30 : null,
                                left: isMe ? null : 30,
                                bottom: -10,
                                child: Icon(
                                  Icons.star,
                                  size: 40,
                                  color: Colors.white.withAlpha(15),
                                ),
                              ),
                              // المحتوى
                              _buildMessageContent(
                                message,
                                messageType,
                                isMe,
                                timeStr,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // مؤشر التعديل
                      if (isEdited)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '(تم التعديل)',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withAlpha(100),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isMe && showSenderInfo) ...[
            const SizedBox(width: 8),
            _buildAvatar(widget.user),
          ] else if (isMe) ...[
            const SizedBox(width: 48),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(Map<String, dynamic>? user) {
    final profileImage = user?['profile_image'];
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey.shade300,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(25), blurRadius: 4),
        ],
        image: profileImage != null
            ? DecorationImage(
                image: NetworkImage(profileImage),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: profileImage == null
          ? const Icon(Icons.person, color: Colors.grey, size: 24)
          : null,
    );
  }

  Widget _buildMessageContent(
    Map<String, dynamic> message,
    String messageType,
    bool isMe,
    String timeStr,
  ) {
    switch (messageType) {
      case 'image':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: () => _showImageFullScreen(message['media_url']),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  message['media_url'],
                  fit: BoxFit.cover,
                  width: 200,
                  height: 200,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: 200,
                      height: 200,
                      color: Colors.grey.shade200,
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                timeStr,
                style: TextStyle(
                  fontSize: 10,
                  color: isMe ? Colors.white70 : Colors.grey,
                ),
              ),
            ),
          ],
        );

      case 'voice':
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => _playVoice(message['media_url'], message['id']),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _currentlyPlayingId == message['id']
                        ? Icons.stop_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'رسالة صوتية',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withAlpha(180),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

      default:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                message['content'] ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                timeStr,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withAlpha(180),
                ),
              ),
            ],
          ),
        );
    }
  }

  void _showImageFullScreen(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(child: Image.network(imageUrl)),
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, const Color(0xFF1a1a2e).withAlpha(200)],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(15),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withAlpha(25), width: 1),
        ),
        child: Row(
          children: [
            _buildActionButton(
              icon: Icons.image_rounded,
              onTap: _isSending ? null : _sendImage,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: _isRecording
                      ? Colors.red.withAlpha(30)
                      : Colors.white.withAlpha(15),
                  borderRadius: BorderRadius.circular(20),
                  border: _isRecording
                      ? Border.all(color: Colors.red.withAlpha(100), width: 1)
                      : null,
                ),
                child: _isRecording
                    ? _buildRecordingIndicator()
                    : TextField(
                        controller: _messageController,
                        textDirection: ui.TextDirection.rtl,
                        maxLines: 4,
                        minLines: 1,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'اكتب رسالتك...',
                          hintStyle: TextStyle(
                            color: Colors.white.withAlpha(100),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _sendTextMessage(),
                      ),
              ),
            ),
            const SizedBox(width: 8),
            _isSending
                ? Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withAlpha(100),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      ),
                    ),
                  )
                : _messageController.text.isNotEmpty
                ? _buildSendButton()
                : _buildVoiceButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white.withAlpha(200), size: 22),
      ),
    );
  }

  Widget _buildRecordingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _recordingAnimController,
            builder: (context, child) {
              return Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(
                    (150 + (_recordingAnimController.value * 105)).toInt(),
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withAlpha(100),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Text(
            'جاري التسجيل...',
            style: TextStyle(
              color: Colors.red.shade300,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    return GestureDetector(
      onTap: _sendTextMessage,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6366F1), ui.Color.fromARGB(255, 122, 116, 137)],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withAlpha(100),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildVoiceButton() {
    return GestureDetector(
      onTap: _toggleRecording,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: _isRecording
              ? const LinearGradient(
                  colors: [Color(0xFFEF4444), Color(0xFFF87171)],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _isRecording
                  ? Colors.red.withAlpha(100)
                  : const Color(0xFF6366F1).withAlpha(100),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}
