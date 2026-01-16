import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:test7/services/agora_voice_service.dart';
import 'dart:async';

class VoiceRoomActiveScreen extends StatefulWidget {
  final Map<String, dynamic> room;
  final Map<String, dynamic> user;

  const VoiceRoomActiveScreen({
    super.key,
    required this.room,
    required this.user,
  });

  @override
  State<VoiceRoomActiveScreen> createState() => _VoiceRoomActiveScreenState();
}

class _VoiceRoomActiveScreenState extends State<VoiceRoomActiveScreen>
    with WidgetsBindingObserver {
  final _client = Supabase.instance.client;
  RealtimeChannel? _participantsSubscription;

  List<Map<String, dynamic>> _participants = [];
  final Map<int, bool> _speakingUsers = {};
  bool _isMuted = false;
  bool _isInChannel = false;
  bool _isJoining = false;
  int? _myAgoraUid;
  Timer? _heartbeatTimer;
  int _heartbeatFailures = 0;
  Timer? _participantDebounce;

  // 🎥 Video state
  bool _isCameraOn = false;
  final Map<int, bool> _usersWithVideo = {}; // track which users have video on

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadParticipants();
    _subscribeToParticipants();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _joinChannel();
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => _updateHeartbeat(),
    );
  }

  Future<void> _updateHeartbeat() async {
    if (!_isInChannel) return;

    try {
      await _client
          .from('voice_room_participants')
          .update({'last_seen': DateTime.now().toIso8601String()})
          .match({
            'room_name': widget.room['room_name'],
            'user_id': widget.user['id'],
          })
          .timeout(const Duration(seconds: 5));

      _heartbeatFailures = 0;
    } catch (e) {
      _heartbeatFailures++;
      debugPrint('⚠️ Heartbeat failed ($_heartbeatFailures/3): $e');

      if (_heartbeatFailures >= 3) {
        debugPrint('🔄 Retrying heartbeat after 5 seconds...');
        await Future.delayed(const Duration(seconds: 5));
        if (_isInChannel && mounted) {
          unawaited(_updateHeartbeat());
        }
      }
    }
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _participantDebounce?.cancel();
    _isJoining = false;

    WidgetsBinding.instance.removeObserver(this);
    if (_participantsSubscription != null) {
      _client.removeChannel(_participantsSubscription!);
      _participantsSubscription = null;
    }

    unawaited(AgoraVoiceService.leaveChannel());
    unawaited(_removeParticipantFromDB());

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      unawaited(_removeParticipantFromDB());
    } else if (state == AppLifecycleState.paused) {
      _heartbeatTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      if (_isInChannel &&
          (_heartbeatTimer == null || !_heartbeatTimer!.isActive)) {
        _startHeartbeat();
      }
    }
  }

  Future<void> _loadParticipants() async {
    try {
      final response = await _client
          .from('voice_room_participants')
          .select('*, users:user_id(id, name, username, profile_image)')
          .eq('room_name', widget.room['room_name']);

      if (mounted) {
        setState(() {
          _participants = List<Map<String, dynamic>>.from(response as List);
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading participants: $e');
    }
  }

  Future<void> _subscribeToParticipants() async {
    try {
      final roomName = widget.room['room_name'];
      _participantsSubscription = _client
          .channel('room_${roomName}_participants')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'voice_room_participants',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'room_name',
              value: roomName,
            ),
            callback: (payload) {
              _participantDebounce?.cancel();
              _participantDebounce = Timer(
                const Duration(milliseconds: 300),
                () {
                  if (mounted) {
                    _loadParticipants().catchError((e) {
                      debugPrint('❌ Failed to reload participants: $e');
                    });
                  }
                },
              );
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('❌ Error subscribing: $e');
      _participantsSubscription = null;
    }
  }

  Future<void> _joinChannel() async {
    if (_isInChannel || _isJoining) return;

    _isJoining = true;
    try {
      setState(() => _isInChannel = true);

      if (kIsWeb) {
        debugPrint('⚠️ Agora is disabled on web platform');

        _startHeartbeat();

        await _client
            .from('voice_room_participants')
            .upsert({
              'room_name': widget.room['room_name'],
              'user_id': widget.user['id'],
              'last_seen': DateTime.now().toIso8601String(),
            })
            .timeout(const Duration(seconds: 8));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'الصوت غير مدعوم على الويب. استخدم التطبيق على Android/iOS للمكالمات الصوتية.',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      final roomName = widget.room['room_name'];
      final uid = await AgoraVoiceService.joinChannel(
        channelName: 'room_$roomName',
        onUserJoined: (uid) {
          debugPrint('👤 User $uid joined');
          _loadParticipants();
        },
        onUserOffline: (uid) {
          debugPrint('👋 User $uid left');
          _loadParticipants();
          if (mounted) {
            setState(() {
              _speakingUsers.remove(uid);
              _usersWithVideo.remove(uid); // 🎥 تنظيف حالة الفيديو
            });
          }
        },
        onActiveSpeaker: (uid, isSpeaking) {
          if (mounted) {
            setState(() {
              _speakingUsers[uid] = isSpeaking;
            });
          }
        },
        onError: (error) {
          debugPrint('❌ Agora error: $error');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('مشكلة في الصوت: $error'),
                backgroundColor: Colors.red,
                action: SnackBarAction(
                  label: 'إعادة المحاولة',
                  onPressed: () {
                    _leaveChannel();
                    Future.delayed(const Duration(seconds: 1), () {
                      if (mounted) {
                        _joinChannel();
                      }
                    });
                  },
                ),
              ),
            );
          }
        },
        onConnectionLost: () {
          debugPrint('📡 Connection lost');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('انقطع الاتصال... يتم إعادة المحاولة'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        },
        onRemoteVideoStateChanged: (uid, hasVideo) {
          debugPrint('📹 User $uid video: $hasVideo');
          if (mounted) {
            setState(() {
              _usersWithVideo[uid] = hasVideo;
            });
          }
        },
      );

      _myAgoraUid = uid;
      debugPrint('✅ Joined channel, my UID: $uid');

      _startHeartbeat();

      await _client
          .from('voice_room_participants')
          .upsert({
            'room_name': widget.room['room_name'],
            'user_id': widget.user['id'],
            'last_seen': DateTime.now().toIso8601String(),
          })
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('❌ Error joining: $e');

      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;

      setState(() => _isInChannel = false);

      if (mounted) {
        String errorMessage = 'حدث خطأ في الانضمام للغرفة';

        if (e.toString().contains('PERMANENTLY_DENIED')) {
          errorMessage =
              'يرجى تفعيل إذن الميكروفون من إعدادات الجهاز ثم المحاولة مرة أخرى';
        } else if (e.toString().contains('DENIED')) {
          errorMessage = 'يجب السماح بإذن الميكروفون للانضمام للغرفة الصوتية';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      _isJoining = false;
    }
  }

  Future<void> _leaveChannel() async {
    try {
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;

      if (!kIsWeb) {
        // 🎥 إيقاف الكاميرا قبل المغادرة
        if (_isCameraOn) {
          try {
            await AgoraVoiceService.disableVideo();
          } catch (e) {
            debugPrint('⚠️ Camera disable error: $e');
          }
        }
        await AgoraVoiceService.leaveChannel();
      }

      await _removeParticipantFromDB();

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('❌ Error leaving: $e');
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _removeParticipantFromDB() async {
    try {
      await _client
          .from('voice_room_participants')
          .delete()
          .eq('room_name', widget.room['room_name'])
          .eq('user_id', widget.user['id'])
          .timeout(const Duration(seconds: 10));

      await _client
          .rpc(
            'decrement_participants_count',
            params: {'room_name_param': widget.room['room_name']},
          )
          .catchError((e) {
            debugPrint(
              '⚠️ Manual count decrement failed (trigger should handle it): $e',
            );
          });
    } catch (e) {
      debugPrint('❌ Error removing participant: $e');
    }
  }

  Future<void> _toggleMute() async {
    if (mounted) {
      setState(() {
        _isMuted = !_isMuted;
      });
    }
    await AgoraVoiceService.muteLocalAudio(_isMuted);
  }

  // 🎥 Toggle camera
  Future<void> _toggleCamera() async {
    try {
      if (_isCameraOn) {
        await AgoraVoiceService.disableVideo();
      } else {
        await AgoraVoiceService.enableVideo();
      }

      if (mounted) {
        setState(() {
          _isCameraOn = !_isCameraOn;
          if (_myAgoraUid != null) {
            _usersWithVideo[_myAgoraUid!] = _isCameraOn;
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Error toggling camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('permission')
                  ? 'يرجى السماح بإذن الكاميرا'
                  : 'حدث خطأ في تشغيل الكاميرا',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _leaveChannel();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(widget.room['title'] ?? 'غرفة صوتية'),
          backgroundColor: const Color(0xFFE91E63),
          elevation: 0,
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFCE4EC),
                Color(0xFFF8BBD0),
                Color(0xFFF48FB1),
                Color(0xFFEC407A),
              ],
              stops: [0.0, 0.3, 0.7, 1.0],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -80,
                right: -80,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -120,
                left: -80,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFFFD54F).withValues(alpha: 0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 100,
                left: 30,
                child: Icon(
                  Icons.favorite,
                  color: Colors.white.withValues(alpha: 0.15),
                  size: 40,
                ),
              ),
              Positioned(
                top: 200,
                right: 50,
                child: Icon(
                  Icons.favorite,
                  color: Colors.white.withValues(alpha: 0.1),
                  size: 30,
                ),
              ),
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE91E63), Color(0xFFEC407A)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFE91E63,
                                ).withValues(alpha: 0.3),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.people_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'المشاركون',
                                style: TextStyle(
                                  color: Color(0xFF880E4F),
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${_participants.length} متصل',
                                style: const TextStyle(
                                  color: Color(0xFFAD1457),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _participants.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline_rounded,
                                  size: 64,
                                  color: const Color(
                                    0xFFAD1457,
                                  ).withValues(alpha: 0.3),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'لا يوجد مشاركون حالياً',
                                  style: TextStyle(
                                    color: Color(0xFFAD1457),
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            physics: const BouncingScrollPhysics(),
                            cacheExtent: 500,
                            itemCount: _participants.length,
                            itemBuilder: (context, index) {
                              final participant = _participants[index];
                              final user = participant['users'];
                              final isSpeaking =
                                  _speakingUsers[_myAgoraUid] == true &&
                                  participant['user_id'] == widget.user['id'];

                              return RepaintBoundary(
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withValues(alpha: 0.7),
                                        Colors.white.withValues(alpha: 0.5),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSpeaking
                                          ? const Color(0xFFE91E63)
                                          : const Color(
                                              0xFFF8BBD0,
                                            ).withValues(alpha: 0.5),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isSpeaking
                                            ? const Color(
                                                0xFFE91E63,
                                              ).withValues(alpha: 0.3)
                                            : const Color(
                                                0xFFF8BBD0,
                                              ).withValues(alpha: 0.2),
                                        blurRadius: isSpeaking ? 12 : 8,
                                        spreadRadius: isSpeaking ? 2 : 0,
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        Stack(
                                          children: [
                                            Container(
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFFE91E63,
                                                  ).withValues(alpha: 0.3),
                                                  width: 2,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(
                                                      0xFFE91E63,
                                                    ).withValues(alpha: 0.2),
                                                    blurRadius: 8,
                                                  ),
                                                ],
                                              ),
                                              child: CircleAvatar(
                                                radius: 28,
                                                backgroundImage:
                                                    user?['profile_image'] !=
                                                        null
                                                    ? NetworkImage(
                                                        user['profile_image'],
                                                      )
                                                    : null,
                                                backgroundColor: const Color(
                                                  0xFFFCE4EC,
                                                ),
                                                child:
                                                    user?['profile_image'] ==
                                                        null
                                                    ? const Icon(
                                                        Icons.person,
                                                        color: Color(
                                                          0xFFE91E63,
                                                        ),
                                                        size: 28,
                                                      )
                                                    : null,
                                              ),
                                            ),
                                            if (isSpeaking)
                                              Positioned(
                                                right: 0,
                                                bottom: 0,
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    gradient:
                                                        const LinearGradient(
                                                          colors: [
                                                            Color(0xFFE91E63),
                                                            Color(0xFFEC407A),
                                                          ],
                                                        ),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: Colors.white,
                                                      width: 2,
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color:
                                                            const Color(
                                                              0xFFE91E63,
                                                            ).withValues(
                                                              alpha: 0.5,
                                                            ),
                                                        blurRadius: 8,
                                                        spreadRadius: 1,
                                                      ),
                                                    ],
                                                  ),
                                                  child: const Icon(
                                                    Icons.mic,
                                                    color: Colors.white,
                                                    size: 12,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                user?['name'] ?? 'مستخدم',
                                                style: const TextStyle(
                                                  color: Color(0xFF880E4F),
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '@${user?['username'] ?? ''}',
                                                style: const TextStyle(
                                                  color: Color(0xFFAD1457),
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (participant['user_id'] ==
                                            widget.user['id'])
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFFE91E63),
                                                  Color(0xFFEC407A),
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(
                                                    0xFFE91E63,
                                                  ).withValues(alpha: 0.3),
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                            child: const Text(
                                              'أنت',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  if (_isInChannel)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.9),
                            Colors.white.withValues(alpha: 0.7),
                          ],
                        ),
                        border: const Border(
                          top: BorderSide(color: Color(0xFFF8BBD0), width: 2),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFE91E63,
                            ).withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        top: false,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildControlButton(
                              icon: _isMuted
                                  ? Icons.mic_off_rounded
                                  : Icons.mic_rounded,
                              label: _isMuted ? 'إلغاء الكتم' : 'كتم',
                              color: _isMuted
                                  ? const Color(0xFFE91E63)
                                  : const Color(0xFF4CAF50),
                              onPressed: _toggleMute,
                            ),
                            _buildControlButton(
                              icon: _isCameraOn
                                  ? Icons.videocam_rounded
                                  : Icons.videocam_off_rounded,
                              label: _isCameraOn
                                  ? 'إيقاف الكاميرا'
                                  : 'تشغيل الكاميرا',
                              color: _isCameraOn
                                  ? const Color(0xFF2196F3)
                                  : const Color(0xFF9E9E9E),
                              onPressed: _toggleCamera,
                            ),
                            _buildControlButton(
                              icon: Icons.call_end_rounded,
                              label: 'إنهاء',
                              color: const Color(0xFFE91E63),
                              onPressed: _leaveChannel,
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

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Material(
            color: color,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onPressed,
              customBorder: const CircleBorder(),
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF880E4F),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
