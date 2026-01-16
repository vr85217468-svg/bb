import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class AgoraVoiceService {
  static RtcEngine? _engine;
  static bool _isInChannel = false;
  static String? _currentChannelName;
  static int? _currentUid;

  // ✅ FIX #10: Event handler مرة واحدة فقط
  static RtcEngineEventHandler? _eventHandler;
  static Function(int)? _onUserJoinedCallback;
  static Function(int)? _onUserOfflineCallback;
  static Function(int, bool)? _onActiveSpeakerCallback;
  // ✅ FIX #15: Error callbacks
  static Function(String)? _onErrorCallback;
  static Function()? _onConnectionLostCallback;

  // 🎥 Video callbacks
  static Function(int uid, bool hasVideo)? _onRemoteVideoStateCallback;

  // App ID من Agora
  static const String appId = '7d9084b8b549453da80f4b0fe0ef9b2b';

  /// التحقق من حالة المكالمة
  static bool get isInChannel => _isInChannel;
  static String? get currentChannelName => _currentChannelName;
  static int? get currentUid => _currentUid; // ✅ getter للوصول لـ UID
  static RtcEngine? get engine =>
      _engine; // 🎥 getter للوصول لـ engine (لعرض الفيديو)

  /// تهيئة Agora Engine
  static Future<void> initialize() async {
    if (_engine != null) return;

    try {
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(
        RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );

      // إعدادات الصوت
      await _engine!.enableAudio();
      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

      debugPrint('✅ Agora initialized successfully');
    } catch (e) {
      debugPrint('❌ Agora initialization error: $e');
      rethrow;
    }
  }

  /// الانضمام لقناة صوتية
  static Future<int?> joinChannel({
    required String channelName,
    required Function(int uid) onUserJoined,
    required Function(int uid) onUserOffline,
    required Function(int uid, bool isSpeaking) onActiveSpeaker,
    Function(String error)? onError, // ✅ FIX #15
    Function()? onConnectionLost, // ✅ FIX #15
    Function(int uid, bool hasVideo)?
    onRemoteVideoStateChanged, // 🎥 Video callback
  }) async {
    try {
      // تهيئة Engine إذا لم يكن مهيأ
      await initialize();

      // ✅ FIX #24: تحسين معالجة الأذونات
      final micStatus = await Permission.microphone.request();
      if (micStatus.isPermanentlyDenied) {
        throw Exception(
          'PERMANENTLY_DENIED: Please enable microphone from settings',
        );
      } else if (!micStatus.isGranted) {
        throw Exception('DENIED: Microphone permission is required');
      }

      // ✅ FIX #10: تسجيل event handler مرة واحدة فقط
      if (_eventHandler == null) {
        _eventHandler = RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint('🎤 Joined channel: \${connection.channelId}');
            _isInChannel = true;
            _currentChannelName = connection.channelId;
            _currentUid = connection.localUid;
          },
          onUserJoined: (RtcConnection connection, int uid, int elapsed) {
            debugPrint('👤 User joined: \$uid');
            _onUserJoinedCallback?.call(uid);
          },
          onUserOffline:
              (
                RtcConnection connection,
                int uid,
                UserOfflineReasonType reason,
              ) {
                debugPrint('👋 User left: \$uid');
                _onUserOfflineCallback?.call(uid);
              },
          onAudioVolumeIndication:
              (
                RtcConnection connection,
                List<AudioVolumeInfo> speakers,
                int speakerNumber,
                int totalVolume,
              ) {
                // معالجة مؤشر التحدث
                for (var speaker in speakers) {
                  if (speaker.volume != null && speaker.volume! > 10) {
                    _onActiveSpeakerCallback?.call(speaker.uid!, true);
                  } else {
                    _onActiveSpeakerCallback?.call(speaker.uid!, false);
                  }
                }
              },
          onLeaveChannel: (RtcConnection connection, RtcStats stats) {
            debugPrint('📴 Left channel');
            _isInChannel = false;
            _currentChannelName = null;
            _currentUid = null;
          },
          // ✅ FIX #15: Error handlers
          onError: (ErrorCodeType err, String msg) {
            debugPrint('❌ Agora Error: $err - $msg');
            _onErrorCallback?.call('$err: $msg');
          },
          onConnectionLost: (RtcConnection connection) {
            debugPrint('📡 Connection lost!');
            _onConnectionLostCallback?.call();
          },
          onConnectionStateChanged:
              (
                RtcConnection connection,
                ConnectionStateType state,
                ConnectionChangedReasonType reason,
              ) {
                debugPrint('🔄 Connection: $state, reason: $reason');
                if (state == ConnectionStateType.connectionStateFailed) {
                  _onErrorCallback?.call('Connection failed: $reason');
                }
              },
          // 🎥 Video state handler
          onRemoteVideoStateChanged:
              (
                RtcConnection connection,
                int uid,
                RemoteVideoState state,
                RemoteVideoStateReason reason,
                int elapsed,
              ) {
                debugPrint('📹 Video state changed: uid=$uid, state=$state');
                final hasVideo =
                    state == RemoteVideoState.remoteVideoStateDecoding ||
                    state == RemoteVideoState.remoteVideoStateStarting;
                _onRemoteVideoStateCallback?.call(uid, hasVideo);
              },
        );

        _engine!.registerEventHandler(_eventHandler!);
        debugPrint('✅ Event handler registered (once)');
      }

      // ✅ تحديث callbacks للغرفة الجديدة
      _onUserJoinedCallback = onUserJoined;
      _onUserOfflineCallback = onUserOffline;
      _onActiveSpeakerCallback = onActiveSpeaker;
      _onErrorCallback = onError;
      _onConnectionLostCallback = onConnectionLost;
      _onRemoteVideoStateCallback = onRemoteVideoStateChanged; // 🎥

      // تفعيل مؤشر الصوت
      await _engine!.enableAudioVolumeIndication(
        interval: 300,
        smooth: 3,
        reportVad: true,
      );

      // الانضمام للقناة (Agora's joinChannel returns void)
      await _engine!.joinChannel(
        token: '',
        channelId: channelName,
        uid: 0, // 0 = auto-assign UID
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          autoSubscribeAudio: true,
          publishMicrophoneTrack: true,
          // 🎥 Video options
          autoSubscribeVideo: true,
          publishCameraTrack: false, // سيتم تفعيله عند الضغط على زر الكاميرا
        ),
      );

      debugPrint('✅ Join channel initiated');
      return 0; // UID الحقيقي يأتي في onJoinChannelSuccess callback
    } catch (e) {
      debugPrint('❌ Error joining channel: \$e');
      rethrow;
    }
  }

  /// مغادرة القناة
  static Future<void> leaveChannel() async {
    try {
      if (_engine != null) {
        await _engine!.leaveChannel();
        _isInChannel = false;
        _currentChannelName = null;
        _currentUid = null;

        // 🎥 تنظيف الفيديو
        try {
          await _engine!.stopPreview();
          await _engine!.disableVideo();
        } catch (e) {
          debugPrint('⚠️ Video cleanup error: $e');
        }

        // ✅ FIX #22: تنظيف callbacks لمنع استدعاء callbacks من غرف قديمة
        _onUserJoinedCallback = null;
        _onUserOfflineCallback = null;
        _onActiveSpeakerCallback = null;
        _onErrorCallback = null;
        _onConnectionLostCallback = null;
        _onRemoteVideoStateCallback = null; // 🎥

        debugPrint('✅ Left channel successfully');
      }
    } catch (e) {
      debugPrint('❌ Error leaving channel: \$e');
    }
  }

  /// كتم/فتح الميكروفون
  static Future<void> muteLocalAudio(bool mute) async {
    try {
      await _engine?.muteLocalAudioStream(mute);
      debugPrint('🎤 Local audio \${mute ? "muted" : "unmuted"}');
    } catch (e) {
      debugPrint('❌ Error muting audio: \$e');
    }
  }

  /// تدمير Engine
  static Future<void> dispose() async {
    try {
      await leaveChannel();
      await _engine?.release();
      _engine = null;
      debugPrint('✅ Agora engine disposed');
    } catch (e) {
      debugPrint('❌ Error disposing Agora: \$e');
    }
  }

  // ========== 🎥 Video Functions ==========

  /// تفعيل الكاميرا بدقة عالية (HD)
  static Future<void> enableVideo() async {
    try {
      await initialize();

      // طلب إذن الكاميرا
      final cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        throw Exception('Camera permission required');
      }

      // تفعيل الفيديو
      await _engine!.enableVideo();

      // إعدادات الفيديو بدقة عالية
      await _engine!.setVideoEncoderConfiguration(
        const VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 1280, height: 720), // HD
          frameRate: 30,
          bitrate: 1500, // 1.5 Mbps
          orientationMode: OrientationMode.orientationModeAdaptive,
        ),
      );

      // بدء معاينة محلية
      await _engine!.startPreview();

      // ✅ تحديث channel options لنشر الفيديو
      if (_isInChannel) {
        await _engine!.updateChannelMediaOptions(
          const ChannelMediaOptions(publishCameraTrack: true),
        );
      }

      debugPrint('✅ Video enabled (HD 1280x720@30fps)');
    } catch (e) {
      debugPrint('❌ Error enabling video: $e');
      rethrow;
    }
  }

  /// إيقاف الكاميرا
  static Future<void> disableVideo() async {
    try {
      // ✅ إيقاف نشر الفيديو أولاً
      if (_isInChannel) {
        await _engine?.updateChannelMediaOptions(
          const ChannelMediaOptions(publishCameraTrack: false),
        );
      }

      await _engine?.stopPreview();
      await _engine?.disableVideo();
      debugPrint('📴 Video disabled');
    } catch (e) {
      debugPrint('❌ Error disabling video: $e');
    }
  }

  /// التبديل بين الكاميرا الأمامية والخلفية
  static Future<void> switchCamera() async {
    try {
      await _engine?.switchCamera();
      debugPrint('🔄 Camera switched');
    } catch (e) {
      debugPrint('❌ Error switching camera: $e');
    }
  }
}
