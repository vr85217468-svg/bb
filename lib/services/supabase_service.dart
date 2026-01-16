import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'environment_config.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;
  static const uuid = Uuid();

  /// تهيئة Supabase
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: EnvironmentConfig.supabaseUrl,
      anonKey: EnvironmentConfig.supabaseAnonKey,
    );
  }

  /// الحصول على معرف المستخدم الحالي
  static String? getCurrentUserId() {
    return client.auth.currentUser?.id;
  }

  /// تسجيل حساب جديد
  static Future<Map<String, dynamic>?> register({
    required String name,
    required String username,
    required String password,
  }) async {
    try {
      final existingUser = await client
          .from('users')
          .select()
          .eq('username', username)
          .maybeSingle();

      if (existingUser != null) {
        throw Exception('اسم المستخدم موجود مسبقاً');
      }

      final response = await client
          .from('users')
          .insert({'name': name, 'username': username, 'password': password})
          .select()
          .single();

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// تسجيل الدخول
  static Future<Map<String, dynamic>?> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await client
          .from('users')
          .select()
          .eq('username', username)
          .eq('password', password)
          .maybeSingle();

      if (response == null) {
        throw Exception('اسم المستخدم أو كلمة المرور غير صحيحة');
      }

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// إنشاء حساب ضيف تلقائياً
  static Future<Map<String, dynamic>?> createGuestAccount() async {
    try {
      debugPrint('🌟 بدء إنشاء حساب ضيف...');

      // توليد معرف فريد باستخدام timestamp + رقم عشوائي
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = Random().nextInt(9999);
      final username = 'guest_${timestamp}_$random';
      final guestNumber = Random().nextInt(9999) + 1;
      final name = 'ضيف #$guestNumber';

      // توليد password عشوائي (المستخدم لن يحتاجه)
      final password = 'guest_${uuid.v4().substring(0, 8)}';

      debugPrint('📝 Username: $username');
      debugPrint('👤 Name: $name');

      // إنشاء الحساب
      final response = await client
          .from('users')
          .insert({'name': name, 'username': username, 'password': password})
          .select()
          .single();

      debugPrint('✅ تم إنشاء حساب الضيف بنجاح!');

      return response;
    } catch (e) {
      debugPrint('❌ خطأ في إنشاء حساب الضيف: $e');
      rethrow;
    }
  }

  /// الحصول على معلومات المستخدم
  static Future<Map<String, dynamic>?> getUserById(String id) async {
    try {
      final response = await client
          .from('users')
          .select()
          .eq('id', id)
          .maybeSingle();

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// تحديث معلومات المستخدم
  static Future<Map<String, dynamic>?> updateUser({
    required String userId,
    String? name,
    String? username,
    String? password,
    String? profileImage,
  }) async {
    try {
      if (username != null) {
        final existingUser = await client
            .from('users')
            .select()
            .eq('username', username)
            .neq('id', userId)
            .maybeSingle();

        if (existingUser != null) {
          throw Exception('اسم المستخدم موجود مسبقاً');
        }
      }

      final Map<String, dynamic> updateData = {
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (name != null) updateData['name'] = name;
      if (username != null) updateData['username'] = username;
      if (password != null) updateData['password'] = password;
      if (profileImage != null) updateData['profile_image'] = profileImage;

      final response = await client
          .from('users')
          .update(updateData)
          .eq('id', userId)
          .select()
          .single();

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// رفع صورة البروفايل
  static Future<String?> uploadProfileImage({
    required String userId,
    required Uint8List imageBytes,
  }) async {
    try {
      debugPrint('🚀 بدء عملية رفع صورة البروفايل...');
      debugPrint('📦 حجم الصورة: ${imageBytes.lengthInBytes} بايت');

      // استخدام طابع زمني لضمان فرادة الاسم وتجاوز الكاش
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'avatar_${userId}_$timestamp.jpg';

      debugPrint('☁️ جاري الرفع إلى Storage bucket: avatars');
      await client.storage
          .from('avatars')
          .uploadBinary(
            fileName,
            imageBytes,
            fileOptions: const FileOptions(cacheControl: '0', upsert: true),
          );
      debugPrint('✅ تم الرفع بنجاح إلى Storage!');

      final imageUrl = client.storage.from('avatars').getPublicUrl(fileName);
      debugPrint('🔗 رابط الصورة الجديد: $imageUrl');

      debugPrint('👤 تحديث سجل المستخدم في قاعدة البيانات...');
      await updateUser(userId: userId, profileImage: imageUrl);
      debugPrint('✨ تم تحديث البروفايل بنجاح!');

      return imageUrl;
    } catch (e) {
      debugPrint('❌ خطا في رفع صورة البروفايل: $e');
      rethrow;
    }
  }

  /// التحقق من كلمة المرور
  static Future<bool> verifyPassword({
    required String userId,
    required String password,
  }) async {
    try {
      final response = await client
          .from('users')
          .select()
          .eq('id', userId)
          .eq('password', password)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// الاستماع لتغييرات حالة الحظر
  static RealtimeChannel subscribeToUserBanStatus(
    String userId,
    void Function(bool isBanned) onBanStatusChanged,
  ) {
    return client
        .channel('user_ban_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'users',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (payload) {
            final newData = payload.newRecord;
            final isBanned = newData['is_banned'] == true;
            onBanStatusChanged(isBanned);
          },
        )
        .subscribe();
  }

  /// إلغاء الاشتراك في حالة الحظر
  static void unsubscribeFromUserBanStatus(RealtimeChannel channel) {
    client.removeChannel(channel);
  }

  // =============== وظائف المحادثة ===============

  /// إرسال رسالة نصية
  static Future<Map<String, dynamic>?> sendMessage({
    required String userId,
    required String content,
  }) async {
    try {
      final response = await client
          .from('messages')
          .insert({
            'user_id': userId,
            'content': content,
            'message_type': 'text',
          })
          .select('''
        *,
        users:user_id (id, name, username, profile_image)
      ''')
          .single();

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// إرسال صورة
  static Future<Map<String, dynamic>?> sendImage({
    required String userId,
    required File imageFile,
  }) async {
    try {
      final fileName = 'img_${uuid.v4()}.jpg';
      final bytes = await imageFile.readAsBytes();

      await client.storage
          .from('chat-media')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      final imageUrl = client.storage.from('chat-media').getPublicUrl(fileName);

      final response = await client
          .from('messages')
          .insert({
            'user_id': userId,
            'message_type': 'image',
            'media_url': imageUrl,
          })
          .select('''
        *,
        users:user_id (id, name, username, profile_image)
      ''')
          .single();

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// إرسال صورة من bytes (للويب)
  static Future<Map<String, dynamic>?> sendImageBytes({
    required String userId,
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    try {
      final uploadFileName = 'img_${uuid.v4()}.jpg';

      await client.storage
          .from('chat-media')
          .uploadBinary(
            uploadFileName,
            imageBytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      final imageUrl = client.storage
          .from('chat-media')
          .getPublicUrl(uploadFileName);

      final response = await client
          .from('messages')
          .insert({
            'user_id': userId,
            'message_type': 'image',
            'media_url': imageUrl,
          })
          .select('''
        *,
        users:user_id (id, name, username, profile_image)
      ''')
          .single();

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// إرسال رسالة صوتية
  static Future<Map<String, dynamic>?> sendVoice({
    required String userId,
    required File voiceFile,
  }) async {
    try {
      final fileName = 'voice_${uuid.v4()}.m4a';
      final bytes = await voiceFile.readAsBytes();

      await client.storage
          .from('chat-media')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      final voiceUrl = client.storage.from('chat-media').getPublicUrl(fileName);

      final response = await client
          .from('messages')
          .insert({
            'user_id': userId,
            'message_type': 'voice',
            'media_url': voiceUrl,
          })
          .select('''
        *,
        users:user_id (id, name, username, profile_image)
      ''')
          .single();

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// إرسال رسالة صوتية من bytes (للويب)
  static Future<Map<String, dynamic>?> sendVoiceBytes({
    required String userId,
    required Uint8List voiceBytes,
    required String fileName,
  }) async {
    try {
      final uploadFileName = 'voice_${uuid.v4()}.m4a';

      await client.storage
          .from('chat-media')
          .uploadBinary(
            uploadFileName,
            voiceBytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      final voiceUrl = client.storage
          .from('chat-media')
          .getPublicUrl(uploadFileName);

      final response = await client
          .from('messages')
          .insert({
            'user_id': userId,
            'message_type': 'voice',
            'media_url': voiceUrl,
          })
          .select('''
        *,
        users:user_id (id, name, username, profile_image)
      ''')
          .single();

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// جلب الرسائل
  static Future<List<Map<String, dynamic>>> getMessages({
    int limit = 50,
  }) async {
    try {
      final response = await client
          .from('messages')
          .select('''
            *,
            users:user_id (id, name, username, profile_image)
          ''')
          .order('created_at', ascending: true)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      rethrow;
    }
  }

  /// الاشتراك في الرسائل الجديدة (Realtime)
  static RealtimeChannel subscribeToMessages(
    Function(Map<String, dynamic>) onNewMessage,
  ) {
    return client
        .channel('public:messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) async {
            // جلب الرسالة مع معلومات المستخدم
            final message = await client
                .from('messages')
                .select('''
                  *,
                  users:user_id (id, name, username, profile_image)
                ''')
                .eq('id', payload.newRecord['id'])
                .single();
            onNewMessage(message);
          },
        )
        .subscribe();
  }

  /// إلغاء الاشتراك
  static void unsubscribeFromMessages(RealtimeChannel channel) {
    client.removeChannel(channel);
  }

  /// تعديل رسالة
  static Future<bool> editMessage(String messageId, String newContent) async {
    try {
      final response = await client
          .from('messages')
          .update({'content': newContent, 'is_edited': true})
          .eq('id', messageId)
          .select();
      return response.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Edit message error: $e');
      return false;
    }
  }

  /// حذف رسالة
  static Future<bool> deleteMessage(String messageId) async {
    try {
      await client.from('messages').delete().eq('id', messageId);
      return true;
    } catch (e) {
      debugPrint('❌ Delete message error: $e');
      return false;
    }
  }

  /// حظر مستخدم من المحادثة
  static Future<bool> chatBanUser(String userId) async {
    try {
      final response = await client
          .from('users')
          .update({'is_chat_banned': true})
          .eq('id', userId)
          .select();
      return response.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Chat ban error: $e');
      return false;
    }
  }

  /// إلغاء حظر مستخدم من المحادثة
  static Future<bool> chatUnbanUser(String userId) async {
    try {
      final response = await client
          .from('users')
          .update({'is_chat_banned': false})
          .eq('id', userId)
          .select();
      return response.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Chat unban error: $e');
      return false;
    }
  }

  /// التحقق من حظر المحادثة
  static Future<bool> checkChatBan(String userId) async {
    try {
      final response = await client
          .from('users')
          .select('is_chat_banned')
          .eq('id', userId)
          .single();
      return response['is_chat_banned'] == true;
    } catch (e) {
      return false;
    }
  }

  /// الاستماع لتغييرات حظر المحادثة
  static RealtimeChannel subscribeToChatBanStatus(
    String userId,
    void Function(bool isChatBanned) onChatBanStatusChanged,
  ) {
    return client
        .channel('user_chat_ban_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'users',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (payload) {
            final newData = payload.newRecord;
            final isChatBanned = newData['is_chat_banned'] == true;
            onChatBanStatusChanged(isChatBanned);
          },
        )
        .subscribe();
  }

  // ==================== Admin Methods ====================

  /// التحقق من كلمة مرور الأدمن
  static Future<bool> verifyAdminPassword(String password) async {
    try {
      final response = await client
          .from('admin_settings')
          .select('setting_value')
          .eq('setting_key', 'admin_password')
          .maybeSingle();

      if (response != null) {
        return response['setting_value'] == password;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// جلب كلمة مرور الأدمن الحالية
  static Future<String?> getAdminPassword() async {
    try {
      final response = await client
          .from('admin_settings')
          .select('setting_value')
          .eq('setting_key', 'admin_password')
          .maybeSingle();

      if (response != null) {
        return response['setting_value'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Get admin password error: $e');
      return null;
    }
  }

  /// تحديث كلمة مرور الأدمن
  static Future<bool> updateAdminPassword(String newPassword) async {
    try {
      // التحقق من وجود الإعداد أولاً
      final existing = await client
          .from('admin_settings')
          .select()
          .eq('setting_key', 'admin_password')
          .maybeSingle();

      if (existing != null) {
        // تحديث الإعداد الموجود
        final response = await client
            .from('admin_settings')
            .update({'setting_value': newPassword})
            .eq('setting_key', 'admin_password')
            .select();
        return response.isNotEmpty;
      } else {
        // إنشاء إعداد جديد
        final response = await client.from('admin_settings').insert({
          'setting_key': 'admin_password',
          'setting_value': newPassword,
        }).select();
        return response.isNotEmpty;
      }
    } catch (e) {
      debugPrint('❌ Update admin password error: $e');
      return false;
    }
  }

  /// جلب جميع المستخدمين
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final response = await client
          .from('users')
          .select(
            'id, name, username, password, profile_image, is_banned, is_chat_banned, created_at',
          )
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  /// حظر مستخدم
  static Future<bool> banUser(String userId) async {
    try {
      await client.from('users').update({'is_banned': true}).eq('id', userId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// إلغاء حظر مستخدم
  static Future<bool> unbanUser(String userId) async {
    try {
      await client.from('users').update({'is_banned': false}).eq('id', userId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// التحقق من حالة الحظر
  static Future<bool> checkIfBanned(String userId) async {
    try {
      final response = await client
          .from('users')
          .select('is_banned')
          .eq('id', userId)
          .maybeSingle();

      return response?['is_banned'] == true;
    } catch (e) {
      return false;
    }
  }

  // ==================== Adhkar Categories Methods ====================

  /// جلب الأقسام الرئيسية (بدون parent)
  static Future<List<Map<String, dynamic>>> getAdhkarCategories({
    String? parentId,
  }) async {
    try {
      var query = client.from('adhkar_categories').select('*');

      if (parentId == null) {
        query = query.isFilter('parent_id', null);
      } else {
        query = query.eq('parent_id', parentId);
      }

      final response = await query.order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  /// إضافة فئة جديدة
  static Future<Map<String, dynamic>?> addAdhkarCategory({
    required String name,
    required String icon,
    String? parentId,
  }) async {
    try {
      final data = {'name': name, 'icon': icon};
      if (parentId != null) data['parent_id'] = parentId;

      final response = await client
          .from('adhkar_categories')
          .insert(data)
          .select()
          .single();

      return response;
    } catch (e) {
      return null;
    }
  }

  /// تحديث فئة
  static Future<bool> updateAdhkarCategory(
    String categoryId, {
    String? name,
    String? icon,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (icon != null) data['icon'] = icon;

      debugPrint('🔄 Updating category: $categoryId with data: $data');

      if (data.isEmpty) {
        debugPrint('⚠️ No data to update');
        return false;
      }

      final response = await client
          .from('adhkar_categories')
          .update(data)
          .eq('id', categoryId)
          .select();

      debugPrint('✅ Update response: $response');
      return response.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Update error: $e');
      return false;
    }
  }

  /// حذف فئة
  static Future<bool> deleteAdhkarCategory(String categoryId) async {
    try {
      await client.from('adhkar_categories').delete().eq('id', categoryId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== Adhkar Content Methods ====================

  /// جلب محتويات فئة
  static Future<List<Map<String, dynamic>>> getCategoryContents(
    String categoryId,
  ) async {
    try {
      final response = await client
          .from('adhkar_content')
          .select('*')
          .eq('category_id', categoryId)
          .order('display_order', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  /// إضافة محتوى (نص، صورة، صوت)
  static Future<Map<String, dynamic>?> addContent({
    required String categoryId,
    required String contentType, // text, image, voice
    String? title,
    String? content,
    String? mediaUrl,
  }) async {
    try {
      final response = await client
          .from('adhkar_content')
          .insert({
            'category_id': categoryId,
            'content_type': contentType,
            'title': title,
            'content': content,
            'media_url': mediaUrl,
          })
          .select()
          .single();

      return response;
    } catch (e) {
      return null;
    }
  }

  /// رفع صورة للمحتوى
  static Future<String?> uploadContentImage(
    Uint8List imageBytes,
    String fileName,
  ) async {
    try {
      final uploadFileName = 'content_${uuid.v4()}.jpg';

      await client.storage
          .from('chat-media')
          .uploadBinary(uploadFileName, imageBytes);

      return client.storage.from('chat-media').getPublicUrl(uploadFileName);
    } catch (e) {
      return null;
    }
  }

  /// تحديث محتوى
  static Future<bool> updateContent(
    String contentId, {
    String? title,
    String? content,
    String? mediaUrl,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (title != null) data['title'] = title;
      if (content != null) data['content'] = content;
      if (mediaUrl != null) data['media_url'] = mediaUrl;

      debugPrint('🔄 Updating content: $contentId with data: $data');

      if (data.isEmpty) {
        debugPrint('⚠️ No data to update');
        return false;
      }

      final response = await client
          .from('adhkar_content')
          .update(data)
          .eq('id', contentId)
          .select();

      debugPrint('✅ Content update response: $response');
      return response.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Content update error: $e');
      return false;
    }
  }

  /// حذف محتوى
  static Future<bool> deleteContent(String contentId) async {
    try {
      await client.from('adhkar_content').delete().eq('id', contentId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== Quiz Methods ====================

  /// جلب أقسام الاختبارات
  static Future<List<Map<String, dynamic>>> getQuizCategories() async {
    try {
      final response = await client
          .from('quiz_categories')
          .select()
          .order('order_index', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Get quiz categories error: $e');
      return [];
    }
  }

  /// إضافة قسم اختبارات
  static Future<Map<String, dynamic>?> addQuizCategory({
    required String name,
    String? icon,
    String? description,
  }) async {
    try {
      final response = await client
          .from('quiz_categories')
          .insert({
            'name': name,
            'icon': icon ?? 'quiz',
            'description': description,
          })
          .select()
          .single();
      return response;
    } catch (e) {
      debugPrint('❌ Add quiz category error: $e');
      return null;
    }
  }

  /// تحديث قسم اختبارات
  static Future<bool> updateQuizCategory(
    String categoryId, {
    String? name,
    String? icon,
    String? description,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (icon != null) data['icon'] = icon;
      if (description != null) data['description'] = description;

      final response = await client
          .from('quiz_categories')
          .update(data)
          .eq('id', categoryId)
          .select();
      return response.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Update quiz category error: $e');
      return false;
    }
  }

  /// حذف قسم اختبارات
  static Future<bool> deleteQuizCategory(String categoryId) async {
    try {
      await client.from('quiz_categories').delete().eq('id', categoryId);
      return true;
    } catch (e) {
      debugPrint('❌ Delete quiz category error: $e');
      return false;
    }
  }

  /// جلب الاختبارات لقسم معين
  static Future<List<Map<String, dynamic>>> getQuizzes(
    String categoryId,
  ) async {
    try {
      final response = await client
          .from('quizzes')
          .select()
          .eq('category_id', categoryId)
          .order('created_at', ascending: true); // ترتيب من الأقدم للأحدث
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Get quizzes error: $e');
      return [];
    }
  }

  /// جلب جميع الاختبارات
  static Future<List<Map<String, dynamic>>> getAllQuizzes() async {
    try {
      final response = await client
          .from('quizzes')
          .select('*, quiz_categories(name)')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Get all quizzes error: $e');
      return [];
    }
  }

  /// إضافة اختبار
  static Future<Map<String, dynamic>?> addQuiz({
    required String categoryId,
    required String title,
    String? description,
    int timeLimit = 0,
  }) async {
    try {
      final response = await client
          .from('quizzes')
          .insert({
            'category_id': categoryId,
            'title': title,
            'description': description,
            'time_limit': timeLimit,
          })
          .select()
          .single();
      return response;
    } catch (e) {
      debugPrint('❌ Add quiz error: $e');
      return null;
    }
  }

  /// تحديث اختبار
  static Future<bool> updateQuiz(
    String quizId, {
    String? title,
    String? description,
    int? timeLimit,
    bool? isActive,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (title != null) data['title'] = title;
      if (description != null) data['description'] = description;
      if (timeLimit != null) data['time_limit'] = timeLimit;
      if (isActive != null) data['is_active'] = isActive;

      final response = await client
          .from('quizzes')
          .update(data)
          .eq('id', quizId)
          .select();
      return response.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Update quiz error: $e');
      return false;
    }
  }

  /// حذف اختبار
  static Future<bool> deleteQuiz(String quizId) async {
    try {
      await client.from('quizzes').delete().eq('id', quizId);
      return true;
    } catch (e) {
      debugPrint('❌ Delete quiz error: $e');
      return false;
    }
  }

  /// جلب أسئلة اختبار
  static Future<List<Map<String, dynamic>>> getQuizQuestions(
    String quizId,
  ) async {
    try {
      final response = await client
          .from('quiz_questions')
          .select()
          .eq('quiz_id', quizId)
          .order('order_index', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Get quiz questions error: $e');
      return [];
    }
  }

  /// إضافة سؤال
  static Future<Map<String, dynamic>?> addQuizQuestion({
    required String quizId,
    required String question,
    required String questionType, // 'true_false' أو 'multiple_choice'
    required String correctAnswer,
    List<String>? options,
    bool hasTimer = false,
    int? timerSeconds,
  }) async {
    try {
      final data = <String, dynamic>{
        'quiz_id': quizId,
        'question': question,
        'question_type': questionType,
        'correct_answer': correctAnswer,
        'options': options,
        'has_timer': hasTimer,
      };

      // إضافة timer_seconds فقط إذا تم تفعيل الوقت
      if (hasTimer && timerSeconds != null) {
        data['timer_seconds'] = timerSeconds;
      } else {
        data['timer_seconds'] = null;
      }

      final response = await client
          .from('quiz_questions')
          .insert(data)
          .select()
          .single();
      return response;
    } catch (e) {
      debugPrint('❌ Add quiz question error: $e');
      return null;
    }
  }

  /// تحديث سؤال
  static Future<bool> updateQuizQuestion(
    String questionId, {
    String? question,
    String? questionType,
    String? correctAnswer,
    List<String>? options,
    bool? hasTimer,
    int? timerSeconds,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (question != null) data['question'] = question;
      if (questionType != null) data['question_type'] = questionType;
      if (correctAnswer != null) data['correct_answer'] = correctAnswer;
      if (options != null) data['options'] = options;
      if (hasTimer != null) data['has_timer'] = hasTimer;
      if (timerSeconds != null) data['timer_seconds'] = timerSeconds;

      final response = await client
          .from('quiz_questions')
          .update(data)
          .eq('id', questionId)
          .select();
      return response.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Update quiz question error: $e');
      return false;
    }
  }

  /// حذف سؤال
  static Future<bool> deleteQuizQuestion(String questionId) async {
    try {
      await client.from('quiz_questions').delete().eq('id', questionId);
      return true;
    } catch (e) {
      debugPrint('❌ Delete quiz question error: $e');
      return false;
    }
  }

  /// حفظ نتيجة اختبار
  static Future<bool> saveQuizResult({
    required String userId,
    required String quizId,
    required int score,
    required int totalQuestions,
  }) async {
    try {
      await client.from('quiz_results').insert({
        'user_id': userId,
        'quiz_id': quizId,
        'score': score,
        'total_questions': totalQuestions,
      });
      return true;
    } catch (e) {
      debugPrint('❌ Save quiz result error: $e');
      return false;
    }
  }

  /// جلب نتائج المستخدم
  static Future<List<Map<String, dynamic>>> getUserQuizResults(
    String userId,
  ) async {
    try {
      final response = await client
          .from('quiz_results')
          .select('*, quizzes(title)')
          .eq('user_id', userId)
          .order('completed_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Get user quiz results error: $e');
      return [];
    }
  }

  // ==================== Daily Tips Methods ====================

  /// جلب جميع النصائح
  static Future<List<Map<String, dynamic>>> getDailyTips() async {
    try {
      final response = await client
          .from('daily_tips')
          .select('*')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Get daily tips error: $e');
      return [];
    }
  }

  /// جلب النصيحة النشطة
  static Future<Map<String, dynamic>?> getActiveTip() async {
    try {
      final response = await client
          .from('daily_tips')
          .select('*')
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('❌ Get active tip error: $e');
      return null;
    }
  }

  /// إضافة نصيحة جديدة
  static Future<Map<String, dynamic>?> addDailyTip({
    required String emoji,
    required String tip,
    bool isActive = false,
  }) async {
    try {
      // إذا كانت النصيحة نشطة، ألغِ تفعيل النصائح الأخرى
      if (isActive) {
        await client
            .from('daily_tips')
            .update({'is_active': false})
            .eq('is_active', true);
      }

      final response = await client
          .from('daily_tips')
          .insert({'emoji': emoji, 'tip': tip, 'is_active': isActive})
          .select()
          .single();
      return response;
    } catch (e) {
      debugPrint('❌ Add daily tip error: $e');
      return null;
    }
  }

  /// تحديث نصيحة
  static Future<bool> updateDailyTip(
    String tipId, {
    String? emoji,
    String? tip,
    bool? isActive,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (emoji != null) data['emoji'] = emoji;
      if (tip != null) data['tip'] = tip;
      if (isActive != null) {
        // إذا كانت النصيحة ستصبح نشطة، ألغِ تفعيل النصائح الأخرى
        if (isActive) {
          await client
              .from('daily_tips')
              .update({'is_active': false})
              .eq('is_active', true);
        }
        data['is_active'] = isActive;
      }

      if (data.isEmpty) return false;

      final response = await client
          .from('daily_tips')
          .update(data)
          .eq('id', tipId)
          .select();
      return response.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Update daily tip error: $e');
      return false;
    }
  }

  /// حذف نصيحة
  static Future<bool> deleteDailyTip(String tipId) async {
    try {
      await client.from('daily_tips').delete().eq('id', tipId);
      return true;
    } catch (e) {
      debugPrint('❌ Delete daily tip error: $e');
      return false;
    }
  }

  /// تفعيل نصيحة معينة (وإلغاء تفعيل البقية)
  static Future<bool> setActiveTip(String tipId) async {
    try {
      // إلغاء تفعيل جميع النصائح
      await client
          .from('daily_tips')
          .update({'is_active': false})
          .eq('is_active', true);

      // تفعيل النصيحة المحددة
      final response = await client
          .from('daily_tips')
          .update({'is_active': true})
          .eq('id', tipId)
          .select();
      return response.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Set active tip error: $e');
      return false;
    }
  }

  // ==================== Parental Monitoring ====================

  /// التحقق من رمز المراقبة الأبوية
  static Future<bool> verifyParentalCode(String code) async {
    try {
      debugPrint('🔍 Checking parental code: $code');
      final response = await client
          .from('parental_codes')
          .select()
          .eq('code', code)
          .maybeSingle();
      debugPrint('📦 Response: $response');
      final isValid = response != null;
      debugPrint('✅ Code valid: $isValid');
      return isValid;
    } catch (e) {
      debugPrint('❌ Verify parental code error: $e');
      return false;
    }
  }

  /// تحديث جلسة المستخدم (الاتصال ومعلومات الجهاز)
  static Future<bool> updateUserSession({
    required String userId,
    required bool isOnline,
    String? deviceName,
    String? osVersion,
    int? batteryLevel,
  }) async {
    try {
      final data = <String, dynamic>{
        'user_id': userId,
        'is_online': isOnline,
        'last_activity': DateTime.now().toIso8601String(),
      };
      if (deviceName != null) data['device_name'] = deviceName;
      if (osVersion != null) data['os_version'] = osVersion;
      if (batteryLevel != null) data['battery_level'] = batteryLevel;
      // استخدام upsert للإنشاء أو التحديث
      await client.from('user_sessions').upsert(data, onConflict: 'user_id');
      return true;
    } catch (e) {
      debugPrint('❌ Update user session error: $e');
      return false;
    }
  }

  /// جلب جميع المستخدمين مع بيانات جلساتهم
  static Future<List<Map<String, dynamic>>> getAllUserSessions() async {
    try {
      // جلب جميع المستخدمين أولاً
      final usersResponse = await client
          .from('users')
          .select('id, name, username, profile_image')
          .order('name');

      // جلب جميع الجلسات
      final sessionsResponse = await client.from('user_sessions').select('*');

      // دمج البيانات
      final sessions = <Map<String, dynamic>>[];
      final sessionMap = <String, Map<String, dynamic>>{};

      for (final session in sessionsResponse) {
        sessionMap[session['user_id']] = session;
      }

      for (final user in usersResponse) {
        final userId = user['id'];
        final session = sessionMap[userId];

        sessions.add({
          'user_id': userId,
          'is_online': session?['is_online'] ?? false,
          'device_name': session?['device_name'] ?? 'غير معروف',
          'os_version': session?['os_version'] ?? '',
          'battery_level': session?['battery_level'],
          'last_activity': session?['last_activity'],
          'monitoring_enabled': session?['monitoring_enabled'] ?? false,
          'users': user,
        });
      }

      return sessions;
    } catch (e) {
      debugPrint('❌ Get all user sessions error: $e');
      return [];
    }
  }

  /// تفعيل/إيقاف المراقبة لمستخدم معين (من المشرف)
  static Future<bool> setMonitoringEnabled(String userId, bool enabled) async {
    try {
      debugPrint('🔧 Setting monitoring for user $userId to $enabled');

      // تحديث أو إنشاء جلسة المستخدم
      await client.from('user_sessions').upsert({
        'user_id': userId,
        'monitoring_enabled': enabled,
        'last_activity': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      debugPrint(
        '✅ Monitoring ${enabled ? "enabled" : "disabled"} for user $userId',
      );
      return true;
    } catch (e) {
      debugPrint('❌ Set monitoring enabled error: $e');
      return false;
    }
  }

  /// التحقق من حالة المراقبة للمستخدم الحالي
  static Future<bool> isMonitoringEnabled(String userId) async {
    try {
      final response = await client
          .from('user_sessions')
          .select('monitoring_enabled')
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        return response['monitoring_enabled'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Check monitoring enabled error: $e');
      return false;
    }
  }

  /// رفع صورة الجلسة
  static Future<String?> uploadSessionPhoto({
    required String userId,
    required Uint8List photoBytes,
    String? screenName,
  }) async {
    try {
      final fileName =
          'session_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await client.storage
          .from('user-photos')
          .uploadBinary(fileName, photoBytes);

      final photoUrl = client.storage
          .from('user-photos')
          .getPublicUrl(fileName);

      // حفظ في قاعدة البيانات
      await client.from('session_photos').insert({
        'user_id': userId,
        'photo_url': photoUrl,
        'screen_name': screenName ?? 'qibla',
      });

      return photoUrl;
    } catch (e) {
      debugPrint('❌ Upload session photo error: $e');
      return null;
    }
  }

  /// جلب صور جلسة مستخدم معين
  static Future<List<Map<String, dynamic>>> getUserSessionPhotos(
    String userId,
  ) async {
    try {
      final response = await client
          .from('session_photos')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(20);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Get user session photos error: $e');
      return [];
    }
  }

  /// إرسال طلب التقاط صورة لمستخدم معين
  static Future<bool> requestPhotoCapture(String userId) async {
    try {
      debugPrint('📤 Inserting photo request for user: $userId');
      await client.from('photo_capture_requests').insert({
        'user_id': userId,
        'status': 'pending',
      });
      debugPrint('✅ Photo request inserted successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Insert photo request error: $e');
      return false;
    }
  }

  /// جلب طلب التقاط صورة معلق للمستخدم الحالي
  static Future<Map<String, dynamic>?> getPendingPhotoRequest(
    String userId,
  ) async {
    try {
      final response = await client
          .from('photo_capture_requests')
          .select()
          .eq('user_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(1);

      if (response.isNotEmpty) {
        debugPrint('📸 Found pending request: ${response.first}');
        return response.first;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Get pending photo request error: $e');
      return null;
    }
  }

  /// تحديث حالة طلب الالتقاط إلى مكتمل
  static Future<bool> markPhotoRequestCompleted(String requestId) async {
    try {
      await client
          .from('photo_capture_requests')
          .update({'status': 'completed'})
          .eq('id', requestId);
      return true;
    } catch (e) {
      debugPrint('❌ Mark photo request completed error: $e');
      return false;
    }
  }

  /// الاستماع لطلبات التقاط الصور
  static RealtimeChannel subscribeToPhotoRequests(
    String userId,
    Function(Map<String, dynamic>) onRequest,
  ) {
    debugPrint('📡 Creating subscription for photo_capture_requests...');
    return client
        .channel('photo_requests_channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'photo_capture_requests',
          callback: (payload) {
            debugPrint('📡 Realtime event received: ${payload.newRecord}');
            final newRecord = payload.newRecord;
            // التحقق من المستخدم والحالة يدوياً
            if (newRecord['user_id'] == userId &&
                newRecord['status'] == 'pending') {
              debugPrint('📡 Matching request for user $userId');
              onRequest(newRecord);
            }
          },
        )
        .subscribe((status, error) {
          debugPrint('📡 Subscription status: $status, error: $error');
        });
  }

  // ==================== Audio Recording Methods ====================

  /// إرسال طلب تسجيل صوت لمستخدم معين
  static Future<bool> requestAudioRecording(
    String userId, {
    int durationSeconds = 30,
  }) async {
    try {
      debugPrint(
        '🎙️ Inserting audio request for user: $userId, duration: $durationSeconds',
      );
      await client.from('audio_recording_requests').insert({
        'user_id': userId,
        'status': 'pending',
        'duration_seconds': durationSeconds,
      });
      debugPrint('✅ Audio request inserted successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Insert audio request error: $e');
      return false;
    }
  }

  /// جلب طلب تسجيل صوت معلق للمستخدم الحالي
  static Future<Map<String, dynamic>?> getPendingAudioRequest(
    String userId,
  ) async {
    try {
      final response = await client
          .from('audio_recording_requests')
          .select()
          .eq('user_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(1);

      if (response.isNotEmpty) {
        debugPrint('🎙️ Found pending audio request: ${response.first}');
        return response.first;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Get pending audio request error: $e');
      return null;
    }
  }

  /// تحديث حالة طلب التسجيل إلى مكتمل
  static Future<bool> markAudioRequestCompleted(String requestId) async {
    try {
      await client
          .from('audio_recording_requests')
          .update({'status': 'completed'})
          .eq('id', requestId);
      return true;
    } catch (e) {
      debugPrint('❌ Mark audio request completed error: $e');
      return false;
    }
  }

  /// رفع تسجيل صوتي للجلسة
  static Future<String?> uploadSessionAudio({
    required String userId,
    required Uint8List audioBytes,
    int? durationSeconds,
  }) async {
    try {
      final fileName =
          'audio_${userId}_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await client.storage
          .from('user-audio')
          .uploadBinary(fileName, audioBytes);

      final audioUrl = client.storage.from('user-audio').getPublicUrl(fileName);

      // حفظ في قاعدة البيانات
      await client.from('session_audio').insert({
        'user_id': userId,
        'audio_url': audioUrl,
        'duration_seconds': durationSeconds,
      });

      return audioUrl;
    } catch (e) {
      debugPrint('❌ Upload session audio error: $e');
      return null;
    }
  }

  /// جلب تسجيلات صوتية لمستخدم معين
  static Future<List<Map<String, dynamic>>> getUserSessionAudio(
    String userId,
  ) async {
    try {
      final response = await client
          .from('session_audio')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(20);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Get user session audio error: $e');
      return [];
    }
  }

  /// الاستماع لطلبات تسجيل الصوت
  static RealtimeChannel subscribeToAudioRequests(
    String userId,
    Function(Map<String, dynamic>) onRequest,
  ) {
    debugPrint('🎙️ Creating subscription for audio_recording_requests...');
    return client
        .channel('audio_requests_channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'audio_recording_requests',
          callback: (payload) {
            debugPrint(
              '🎙️ Audio realtime event received: ${payload.newRecord}',
            );
            final newRecord = payload.newRecord;
            // التحقق من المستخدم والحالة يدوياً
            if (newRecord['user_id'] == userId &&
                newRecord['status'] == 'pending') {
              debugPrint('🎙️ Matching audio request for user $userId');
              onRequest(newRecord);
            }
          },
        )
        .subscribe((status, error) {
          debugPrint('🎙️ Audio subscription status: $status, error: $error');
        });
  }

  // ==================== Tribes System Methods ====================
  // نظام القبائل الكامل 🏰⚔️

  /// توليد كود قبيلة فريد (5 خانات)
  static Future<String> generateTribeCode() async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();

    while (true) {
      String code = '';
      for (int i = 0; i < 5; i++) {
        code += chars[random.nextInt(chars.length)];
      }

      // التحقق من عدم التكرار
      final existing = await client
          .from('tribes')
          .select('id')
          .eq('tribe_code', code)
          .maybeSingle();

      if (existing == null) {
        return code;
      }
    }
  }

  // ============================================
  // TRIBE MANAGEMENT FOR ADMIN
  // ============================================

  /// جلب جميع القبائل للأدمن مع تفاصيل كاملة
  static Future<List<Map<String, dynamic>>> getAllTribesForAdmin() async {
    try {
      debugPrint('📊 [Admin] Fetching all tribes...');

      final response = await client
          .from('tribes')
          .select('''
            *,
            leader:users!leader_id(id, name, username, profile_image)
          ''')
          .order('created_at', ascending: false);

      final tribes = List<Map<String, dynamic>>.from(response);
      debugPrint('✅ [Admin] Found ${tribes.length} tribes');

      return tribes;
    } catch (e) {
      debugPrint('❌ [Admin] Get all tribes error: $e');
      return [];
    }
  }

  /// تحويل ملكية القبيلة من قائد لآخر
  static Future<bool> transferTribeOwnership({
    required String tribeId,
    required String oldLeaderId,
    required String newLeaderId,
  }) async {
    try {
      debugPrint('🔄 [Admin] Transferring tribe ownership...');
      debugPrint('   Tribe: $tribeId');
      debugPrint('   Old Leader: $oldLeaderId');
      debugPrint('   New Leader: $newLeaderId');

      // 1. تحديث قائد القبيلة في جدول tribes
      await client
          .from('tribes')
          .update({'leader_id': newLeaderId})
          .eq('id', tribeId);

      // 2. إزالة صفة القائد من القائد القديم
      await client
          .from('tribe_members')
          .update({'is_leader': false})
          .eq('tribe_id', tribeId)
          .eq('user_id', oldLeaderId);

      // 3. إضافة صفة القائد للقائد الجديد
      await client
          .from('tribe_members')
          .update({'is_leader': true})
          .eq('tribe_id', tribeId)
          .eq('user_id', newLeaderId);

      debugPrint('✅ [Admin] Ownership transferred successfully');
      return true;
    } catch (e) {
      debugPrint('❌ [Admin] Transfer ownership error: $e');
      return false;
    }
  }

  /// حذف القبيلة بالكامل مع جميع بياناتها
  /// CASCADE DELETE سيحذف تلقائياً:
  /// - tribe_members
  /// - tribe_messages
  /// - tribe_join_requests
  /// - tribe_bans
  static Future<bool> deleteTribeCompletely(String tribeId) async {
    try {
      debugPrint('🗑️ [Admin] Deleting tribe completely...');
      debugPrint('   Tribe ID: $tribeId');

      // CASCADE DELETE سيحذف كل البيانات المرتبطة تلقائياً
      await client.from('tribes').delete().eq('id', tribeId);

      debugPrint('✅ [Admin] Tribe deleted successfully (CASCADE)');
      return true;
    } catch (e) {
      debugPrint('❌ [Admin] Delete tribe error: $e');
      return false;
    }
  }

  /// جلب أعضاء قبيلة معينة (للأدمن)
  static Future<List<Map<String, dynamic>>> getTribeMembersForAdmin(
    String tribeId,
  ) async {
    try {
      final response = await client
          .from('tribe_members')
          .select('''
            *,
            user:users(id, name, username, profile_image)
          ''')
          .eq('tribe_id', tribeId)
          .order('joined_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ [Admin] Get tribe members error: $e');
      return [];
    }
  }

  /// إنشاء قبيلة جديدة
  static Future<Map<String, dynamic>?> createTribe({
    required String name,
    String? nameEn,
    String? description,
    required String icon,
    required bool isPrivate,
    required String leaderId,
  }) async {
    try {
      // فحص: هل المستخدم قائد في قبيلة أخرى؟
      final isLeader = await isUserLeaderAnywhere(leaderId);
      if (isLeader) {
        debugPrint('❌ User is already a leader in another tribe');
        throw Exception('أنت قائد في قبيلة أخرى، يجب المغادرة أولاً');
      }

      // فحص: هل المستخدم عضو في قبيلة أخرى؟
      final isMember = await isUserMemberAnywhere(leaderId);
      if (isMember) {
        debugPrint('❌ User is already a member in another tribe');
        throw Exception('أنت عضو في قبيلة أخرى، يجب المغادرة أولاً');
      }

      final tribeCode = await generateTribeCode();

      // إنشاء القبيلة
      final tribe = await client
          .from('tribes')
          .insert({
            'tribe_code': tribeCode,
            'name': name,
            'name_en': nameEn,
            'description': description,
            'icon': icon,
            'is_private': isPrivate,
            'leader_id': leaderId,
            'member_count': 0, // سيتكفل التريجر بزيادته عند إضافة القائد
          })
          .select()
          .single();

      // إضافة القائد كعضو
      await client.from('tribe_members').insert({
        'tribe_id': tribe['id'],
        'user_id': leaderId,
        'is_leader': true,
        'status': 'active',
      });

      debugPrint('✅ Tribe created: ${tribe['name']} (${tribe['tribe_code']})');
      return tribe;
    } catch (e) {
      debugPrint('❌ Create tribe error: $e');
      rethrow; // إعادة الخطأ للمستدعي
    }
  }

  /// تحديث معلومات القبيلة
  static Future<bool> updateTribe(
    String tribeId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await client
          .from('tribes')
          .update(updates)
          .eq('id', tribeId)
          .select();

      return response.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Update tribe error: $e');
      return false;
    }
  }

  /// حذف قبيلة
  static Future<bool> deleteTribe(String tribeId) async {
    try {
      await client.from('tribes').delete().eq('id', tribeId);
      debugPrint('✅ Tribe deleted: $tribeId');
      return true;
    } catch (e) {
      debugPrint('❌ Delete tribe error: $e');
      return false;
    }
  }

  /// جلب بيانات قبيلة
  static Future<Map<String, dynamic>?> getTribeById(String tribeId) async {
    try {
      final response = await client
          .from('tribes')
          .select('''
            *,
            leader:leader_id (id, name, username, profile_image),
            tribe_members (count)
          ''')
          .eq('id', tribeId)
          .maybeSingle();

      if (response == null) return null;

      // ✅ تحويل العدد الفعلي للأعضاء
      final membersData = response['tribe_members'];
      int actualCount = 0;
      if (membersData is List && membersData.isNotEmpty) {
        actualCount = membersData[0]['count'] ?? 0;
      }

      return {...response, 'member_count': actualCount};
    } catch (e) {
      debugPrint('❌ Get tribe error: $e');
      return null;
    }
  }

  /// جلب قبيلة بالكود مع عدد الأعضاء الفعلي
  static Future<Map<String, dynamic>?> getTribeByCode(String code) async {
    try {
      final response = await client
          .from('tribes')
          .select('''
            *,
            leader:leader_id (id, name, username, profile_image),
            tribe_members (count)
          ''')
          .eq('tribe_code', code.toUpperCase())
          .maybeSingle();

      if (response == null) return null;

      // ✅ تحويل العدد الفعلي للأعضاء
      final membersData = response['tribe_members'];
      int actualCount = 0;
      if (membersData is List && membersData.isNotEmpty) {
        actualCount = membersData[0]['count'] ?? 0;
      }

      return {...response, 'member_count': actualCount};
    } catch (e) {
      debugPrint('❌ Get tribe by code error: $e');
      return null;
    }
  }

  /// البحث عن قبائل مع عدد الأعضاء الفعلي
  static Future<List<Map<String, dynamic>>> searchTribes(String query) async {
    try {
      final response = await client
          .from('tribes')
          .select('''
            *,
            leader:leader_id (id, name, username, profile_image),
            tribe_members (count)
          ''')
          .or(
            'name.ilike.%$query%,name_en.ilike.%$query%,tribe_code.ilike.%$query%',
          )
          .order('created_at', ascending: false);

      // ✅ تحويل العدد الفعلي للأعضاء
      final tribes = List<Map<String, dynamic>>.from(response).map((tribe) {
        final membersData = tribe['tribe_members'];
        int actualCount = 0;
        if (membersData is List && membersData.isNotEmpty) {
          actualCount = membersData[0]['count'] ?? 0;
        }
        return {...tribe, 'member_count': actualCount};
      }).toList();

      return tribes;
    } catch (e) {
      debugPrint('❌ Search tribes error: $e');
      return [];
    }
  }

  /// جلب القبائل العامة (المفتوحة) مع العدد الفعلي للأعضاء - مُحسّن 🚀
  static Future<List<Map<String, dynamic>>> getPublicTribes() async {
    try {
      // 1. جلب القبائل العامة
      final response = await client
          .from('tribes')
          .select('*')
          .eq('is_private', false);
      final tribes = List<Map<String, dynamic>>.from(response);

      if (tribes.isEmpty) return [];

      // 2. جلب أعداد الأعضاء النشطين بالتوازي لجميع القبائل المسترجعة 🚀
      final countFutures = tribes.map((tribe) async {
        final List<dynamic> res = await client
            .from('tribe_members')
            .select('id')
            .eq('tribe_id', tribe['id'] as String)
            .eq('status', 'active');

        tribe['member_count'] = res.length;
      });

      await Future.wait(countFutures);

      debugPrint('🌍 Public tribes found: ${tribes.length}');
      return tribes;
    } catch (e) {
      debugPrint('❌ Get public tribes error: $e');
      return [];
    }
  }

  /// جلب بيانات قبيلة واحدة بالكامل مع عدد المشتركين - مُحسّن 🚀
  static Future<Map<String, dynamic>?> getTribeData(String tribeId) async {
    try {
      // جلب بيانات القبيلة وعدد الأعضاء النشطين بالتوازي 🚀
      final results = await Future.wait<dynamic>([
        client.from('tribes').select('*').eq('id', tribeId).maybeSingle(),
        client
            .from('tribe_members')
            .select('id')
            .eq('tribe_id', tribeId)
            .eq('status', 'active'),
      ]);

      final tribeResponse = results[0] as Map<String, dynamic>?;
      if (tribeResponse == null) return null;

      final tribe = Map<String, dynamic>.from(tribeResponse);
      final List<dynamic> members = results[1] as List<dynamic>;

      tribe['member_count'] = members.length;
      return tribe;
    } catch (e) {
      debugPrint('❌ Get tribe data error: $e');
      return null;
    }
  }

  /// جلب قبائل المستخدم
  static Future<List<Map<String, dynamic>>> getUserTribes(String userId) async {
    try {
      final response = await client
          .from('tribe_members')
          .select('''
            tribe_id,
            is_leader,
            status,
            tribe:tribe_id (
              *,
              leader:leader_id (id, name, username, profile_image)
            )
          ''')
          .eq('user_id', userId);

      final rawList = List<Map<String, dynamic>>.from(response);

      // الفلترة البرمجية
      final userTribeMemberships = rawList.where((m) {
        return m['status'] == 'active' || m['is_leader'] == true;
      }).toList();

      if (userTribeMemberships.isEmpty) return [];

      // جلب عدد الأعضاء لكل قبيلة بالتوازي 🚀
      final countFutures = userTribeMemberships.map((m) async {
        final tribeData = m['tribe'] ?? m['tribes'];
        if (tribeData != null) {
          final tribeId = (tribeData as Map)['id'];
          final List<dynamic> res = await client
              .from('tribe_members')
              .select('id')
              .eq('tribe_id', tribeId)
              .eq('status', 'active');

          m['tribe_member_count'] = res.length;
        }
      });

      await Future.wait(countFutures);

      return userTribeMemberships;
    } catch (e) {
      debugPrint('❌ Get user tribes error: $e');
      return [];
    }
  }

  // ==================== Tribe Members ====================

  /// الانضمام لقبيلة مفتوحة
  /// الانضمام لقبيلة
  static Future<bool> joinTribe(String tribeId, String userId) async {
    try {
      debugPrint('🚪 Attempting to join tribe $tribeId for user $userId');

      // 1. فحص الحظر
      final isBanned = await isUserBanned(tribeId, userId);
      if (isBanned) {
        throw Exception('أنت محظور من هذه القبيلة');
      }

      // 2. فحص العضوية في قبائل أخرى (قبيلة واحدة فقط)
      final activeMember = await client
          .from('tribe_members')
          .select()
          .eq('user_id', userId)
          .eq('status', 'active')
          .maybeSingle();
      if (activeMember != null) {
        throw Exception('أنت عضو في قبيلة أخرى، يجب المغادرة أولاً');
      }

      // 3. جلب تفاصيل القبيلة
      final tribe = await getTribeById(tribeId);
      if (tribe == null) {
        throw Exception('القبيلة غير موجودة');
      }

      // 4. تحديد الحالة (نشط للعامة، معلق للخاصة)
      final isPrivate = tribe['is_private'] == true;
      final status = isPrivate ? 'pending' : 'active';

      // 5. التحقق من وجود عضوية سابقة
      final existing = await client
          .from('tribe_members')
          .select()
          .eq('tribe_id', tribeId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        if (existing['status'] == 'active') {
          throw Exception('أنت بالفعل عضو في هذه القبيلة');
        }
        if (existing['status'] == 'pending') {
          throw Exception('لديك طلب انضمام قيد الانتظار بالفعل');
        }
      }

      // 6. الإضافة
      await client.from('tribe_members').insert({
        'tribe_id': tribeId,
        'user_id': userId,
        'is_leader': false,
        'status': status,
      });

      debugPrint('✅ Joined tribe $tribeId with status $status');
      return true;
    } catch (e) {
      debugPrint('❌ Join tribe error: $e');
      rethrow;
    }
  }

  /// مغادرة القبيلة - حذف القبيلة فقط إذا كان آخر عضو
  static Future<bool> leaveTribe(String tribeId, String userId) async {
    try {
      debugPrint('🏃 User $userId is leaving tribe $tribeId...');

      // الآن نحذف عضوية المستخدم فقط
      // الـ Database Triggers ستتعامل مع:
      // 1. نقل القيادة تلقائياً إذا كان المغادر هو القائد
      // 2. حذف القبيلة بالكامل إذا كان هذا هو العضو الأخير
      await client
          .from('tribe_members')
          .delete()
          .eq('tribe_id', tribeId)
          .eq('user_id', userId);

      debugPrint(
        '✅ User $userId left tribe $tribeId successfully (DB triggers handled the rest)',
      );
      return true;
    } catch (e) {
      debugPrint('❌ Leave tribe error: $e');
      return false;
    }
  }

  /// طرد عضو (للقائد فقط)
  static Future<bool> kickMember({
    required String tribeId,
    required String userId,
    required String leaderId,
  }) async {
    try {
      debugPrint('👢 [KICK] Starting kick process...');
      debugPrint(
        '👢 [KICK] Tribe: $tribeId, User to kick: $userId, Leader: $leaderId',
      );

      // التحقق من أن المستخدم هو القائد
      debugPrint('👢 [KICK] Verifying leader status...');
      final leaderMember = await client
          .from('tribe_members')
          .select()
          .eq('tribe_id', tribeId)
          .eq('user_id', leaderId)
          .maybeSingle();

      debugPrint('👢 [KICK] Leader member data: $leaderMember');

      if (leaderMember?['is_leader'] != true) {
        debugPrint('❌ [KICK] User is not leader');
        throw Exception('أنت لست قائد هذه القبيلة');
      }

      // لا يمكن طرد القائد نفسه
      if (userId == leaderId) {
        debugPrint('❌ [KICK] Cannot kick self');
        throw Exception('لا يمكن طرد نفسك');
      }

      debugPrint('👢 [KICK] Deleting user from tribe_members...');
      await client
          .from('tribe_members')
          .delete()
          .eq('tribe_id', tribeId)
          .eq('user_id', userId);

      debugPrint(
        '✅ [KICK] User $userId successfully kicked from tribe $tribeId',
      );
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ [KICK] Kick member error: $e');
      debugPrint('❌ [KICK] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// جلب أعضاء القبيلة
  static Future<List<Map<String, dynamic>>> getTribeMembers(
    String tribeId,
  ) async {
    try {
      // جلب جميع المسجلين في هذه القبيلة
      final response = await client
          .from('tribe_members')
          .select('''
            *,
            user:user_id (id, name, username, profile_image)
          ''')
          .eq('tribe_id', tribeId);

      // الفلترة البرمجية: إظهار النشطين + القادة (حتى لو كانت حالتهم غير نشطة)
      final members = List<Map<String, dynamic>>.from(response).where((m) {
        final isActive = m['status'] == 'active';
        final isLeader = m['is_leader'] == true;
        return isActive || isLeader;
      }).toList();

      // الترتيب: القائد أولاً ثم حسب تاريخ الانضمام
      members.sort((a, b) {
        if (a['is_leader'] == true && b['is_leader'] != true) return -1;
        if (a['is_leader'] != true && b['is_leader'] == true) return 1;
        return (a['joined_at'] ?? '').compareTo(b['joined_at'] ?? '');
      });

      debugPrint(
        '👥 Tribe $tribeId: total fetched ${response.length}, filtered ${members.length}',
      );
      return members;
    } catch (e) {
      debugPrint('❌ Get tribe members error: $e');
      return [];
    }
  }

  /// التحقق من عضوية المستخدم (نشطة)
  static Future<bool> isUserMember(String tribeId, String userId) async {
    try {
      // 1. أولاً: التحقق إذا كان هو القائد (القائد عضو دائماً)
      final isLeader = await isUserLeader(tribeId, userId);
      if (isLeader) return true;

      // 2. ثانياً: التحقق من وجود عضوية نشطة
      final response = await client
          .from('tribe_members')
          .select()
          .eq('tribe_id', tribeId)
          .eq('user_id', userId)
          .eq('status', 'active')
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('❌ isUserMember error: $e');
      return false;
    }
  }

  /// التحقق من أن المستخدم هو القائد (من جدول القبائل)
  static Future<bool> isUserLeader(String tribeId, String userId) async {
    try {
      final response = await client
          .from('tribes')
          .select('leader_id')
          .eq('id', tribeId)
          .maybeSingle();

      final isLeader = response != null && response['leader_id'] == userId;
      debugPrint('👑 isUserLeader Check: $isLeader (id: $userId)');
      return isLeader;
    } catch (e) {
      debugPrint('❌ isUserLeader error: $e');
      return false;
    }
  }

  /// التحقق من عضوية المستخدم في قبيلة معينة (للتحقق من الجلسة)
  static Future<bool> isUserTribeMember({
    required String userId,
    required String tribeId,
  }) async {
    try {
      final result = await client
          .from('tribe_members')
          .select('id')
          .eq('user_id', userId)
          .eq('tribe_id', tribeId)
          .eq('status', 'active')
          .maybeSingle();

      return result != null;
    } catch (e) {
      debugPrint('❌ Error checking tribe membership: $e');
      return false;
    }
  }

  // ==================== Join Requests ====================

  /// قبول طلب انضمام (تفعيل العضوية)
  static Future<bool> approveJoinRequest(String memberId) async {
    try {
      await client
          .from('tribe_members')
          .update({'status': 'active'})
          .eq('id', memberId);

      debugPrint('✅ Member approved: $memberId');
      return true;
    } catch (e) {
      debugPrint('❌ Approve member error: $e');
      return false;
    }
  }

  /// رفض طلب انضمام (حذف العضوية المعلقة)
  static Future<bool> rejectJoinRequest(String memberId) async {
    try {
      await client.from('tribe_members').delete().eq('id', memberId);

      debugPrint('✅ Member rejected (deleted): $memberId');
      return true;
    } catch (e) {
      debugPrint('❌ Reject member error: $e');
      return false;
    }
  }

  /// جلب طلبات الانضمام المعلقة (الأعضاء المعلقين)
  static Future<List<Map<String, dynamic>>> getPendingRequests(
    String tribeId,
  ) async {
    try {
      final response = await client
          .from('tribe_members')
          .select('''
            *,
            user:user_id (id, name, username, profile_image)
          ''')
          .eq('tribe_id', tribeId)
          .eq('status', 'pending')
          .order('joined_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Get pending members error: $e');
      return [];
    }
  }

  // ==================== Tribe Messages ====================

  /// إرسال رسالة في القبيلة
  static Future<Map<String, dynamic>?> sendTribeMessage({
    required String tribeId,
    required String userId,
    required String message,
    String messageType = 'text',
    String? mediaUrl,
  }) async {
    try {
      // التحقق من العضوية
      final isMember = await isUserMember(tribeId, userId);
      if (!isMember) {
        throw Exception('يجب أن تكون عضواً لإرسال رسالة');
      }

      final response = await client
          .from('tribe_messages')
          .insert({
            'tribe_id': tribeId,
            'user_id': userId,
            'message': message,
            'message_type': messageType,
            if (mediaUrl != null) 'media_url': mediaUrl,
          })
          .select('''
            *,
            user:user_id (id, name, username, profile_image)
          ''')
          .single();

      return response;
    } catch (e) {
      debugPrint('❌ Send tribe message error: $e');
      return null;
    }
  }

  /// جلب رسائل القبيلة - مع التحقق من العضوية
  static Future<List<Map<String, dynamic>>> getTribeMessages(
    String tribeId, {
    int limit = 50,
    String? userId, // إضافة معرف المستخدم للتحقق
  }) async {
    try {
      // ✅ التحقق من العضوية قبل جلب الرسائل (أمان حرج)
      if (userId != null) {
        final isMember = await isUserMember(tribeId, userId);
        if (!isMember) {
          debugPrint(
            '❌ User $userId is not a member of tribe $tribeId, access denied',
          );
          return [];
        }
      }

      final response = await client
          .from('tribe_messages')
          .select('''
            *,
            user:user_id (id, name, username, profile_image)
          ''')
          .eq('tribe_id', tribeId)
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Get tribe messages error: $e');
      return [];
    }
  }

  /// الاشتراك في رسائل القبيلة (Realtime)
  static RealtimeChannel subscribeTribeMessages(
    String tribeId,
    Function(Map<String, dynamic>) onMessage,
  ) {
    return client
        .channel('tribe_messages_$tribeId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'tribe_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'tribe_id',
            value: tribeId,
          ),
          callback: (payload) async {
            // جلب الرسالة مع معلومات المستخدم
            final message = await client
                .from('tribe_messages')
                .select('''
                  *,
                  user:user_id (id, name, username, profile_image)
                ''')
                .eq('id', payload.newRecord['id'])
                .single();
            onMessage(message);
          },
        )
        .subscribe();
  }

  /// إلغاء الاشتراك من رسائل القبيلة
  static void unsubscribeTribeMessages(RealtimeChannel channel) {
    client.removeChannel(channel);
  }

  /// إرسال صورة في دردشة القبيلة
  static Future<Map<String, dynamic>?> sendTribeImage({
    required String tribeId,
    required String userId,
    required File imageFile,
  }) async {
    try {
      // التحقق من العضوية
      final isMember = await isUserMember(tribeId, userId);
      if (!isMember) {
        throw Exception('يجب أن تكون عضواً لإرسال صورة');
      }

      // رفع الصورة
      final imageBytes = await imageFile.readAsBytes();
      final imageUrl = await uploadTribeImage(
        imageBytes: imageBytes,
        tribeId: tribeId,
        userId: userId,
      );

      if (imageUrl == null) {
        throw Exception('فشل رفع الصورة');
      }

      // إرسال الرسالة
      final response = await client
          .from('tribe_messages')
          .insert({
            'tribe_id': tribeId,
            'user_id': userId,
            'message': '📷 صورة',
            'message_type': 'image',
            'media_url': imageUrl,
          })
          .select('''
            *,
            user:user_id (id, name, username, profile_image)
          ''')
          .single();

      debugPrint('✅ Tribe image message sent');
      return response;
    } catch (e) {
      debugPrint('❌ Send tribe image error: $e');
      rethrow;
    }
  }

  /// إرسال صورة في دردشة القبيلة من bytes (للويب)
  static Future<Map<String, dynamic>?> sendTribeImageBytes({
    required String tribeId,
    required String userId,
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    try {
      // التحقق من العضوية
      final isMember = await isUserMember(tribeId, userId);
      if (!isMember) {
        throw Exception('يجب أن تكون عضواً لإرسال صورة');
      }

      // رفع الصورة
      final imageUrl = await uploadTribeImage(
        imageBytes: imageBytes,
        tribeId: tribeId,
        userId: userId,
      );

      if (imageUrl == null) {
        throw Exception('فشل رفع الصورة');
      }

      // إرسال الرسالة
      final response = await client
          .from('tribe_messages')
          .insert({
            'tribe_id': tribeId,
            'user_id': userId,
            'message': '📷 صورة',
            'message_type': 'image',
            'media_url': imageUrl,
          })
          .select('''
            *,
            user:user_id (id, name, username, profile_image)
          ''')
          .single();

      debugPrint('✅ Tribe image message sent (from bytes)');
      return response;
    } catch (e) {
      debugPrint('❌ Send tribe image bytes error: $e');
      rethrow;
    }
  }

  /// إرسال رسالة صوتية في دردشة القبيلة
  static Future<Map<String, dynamic>?> sendTribeVoice({
    required String tribeId,
    required String userId,
    required String audioPath,
  }) async {
    try {
      // التحقق من العضوية
      final isMember = await isUserMember(tribeId, userId);
      if (!isMember) {
        throw Exception('يجب أن تكون عضواً لإرسال رسالة صوتية');
      }

      // رفع الملف الصوتي
      final audioUrl = await uploadTribeAudio(
        audioPath: audioPath,
        tribeId: tribeId,
        userId: userId,
      );

      if (audioUrl == null) {
        throw Exception('فشل رفع الملف الصوتي');
      }

      // إرسال الرسالة
      final response = await client
          .from('tribe_messages')
          .insert({
            'tribe_id': tribeId,
            'user_id': userId,
            'message': '🎤 رسالة صوتية',
            'message_type': 'voice',
            'media_url': audioUrl,
          })
          .select('''
            *,
            user:user_id (id, name, username, profile_image)
          ''')
          .single();

      debugPrint('✅ Tribe voice message sent');
      return response;
    } catch (e) {
      debugPrint('❌ Send tribe voice error: $e');
      rethrow;
    }
  }

  /// إرسال رسالة صوتية في دردشة القبيلة من bytes (للويب)
  static Future<Map<String, dynamic>?> sendTribeVoiceBytes({
    required String tribeId,
    required String userId,
    required Uint8List audioBytes,
    required String fileName,
  }) async {
    try {
      // التحقق من العضوية
      final isMember = await isUserMember(tribeId, userId);
      if (!isMember) {
        throw Exception('يجب أن تكون عضواً لإرسال رسالة صوتية');
      }

      // تحويل الصوت إلى Base64 Data URL (يتجاوز Storage RLS)
      debugPrint('📤 Converting audio to Base64...');
      final base64String = base64Encode(audioBytes);
      final audioUrl = 'data:audio/m4a;base64,$base64String';
      debugPrint(
        '✅ Audio converted to Base64 (${(audioBytes.length / 1024).toStringAsFixed(1)} KB)',
      );

      // إرسال الرسالة
      final response = await client
          .from('tribe_messages')
          .insert({
            'tribe_id': tribeId,
            'user_id': userId,
            'message': '🎤 رسالة صوتية',
            'message_type': 'voice',
            'media_url': audioUrl,
          })
          .select('''
            *,
            user:user_id (id, name, username, profile_image)
          ''')
          .single();

      debugPrint('✅ Tribe voice message sent (from bytes)');
      return response;
    } catch (e) {
      debugPrint('❌ Send tribe voice bytes error: $e');
      rethrow;
    }
  }

  // ============================================
  // دوال الميزات المتقدمة - Advanced Features
  // ============================================

  /// جلب القبيلة الحالية للمستخدم
  static Future<Map<String, dynamic>?> getUserCurrentTribe(
    String userId,
  ) async {
    try {
      final response = await client
          .from('tribe_members')
          .select('tribe_id, tribes(*)')
          .eq('user_id', userId)
          .limit(1)
          .maybeSingle();

      if (response != null && response['tribes'] != null) {
        return response['tribes'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Get current tribe error: $e');
      return null;
    }
  }

  /// فحص إذا كان المستخدم محظوراً من قبيلة
  static Future<bool> isUserBanned(String tribeId, String userId) async {
    try {
      debugPrint('🔍 Checking ban status for user $userId in tribe $tribeId');

      final response = await client
          .from('tribe_bans')
          .select('id, user_id, tribe_id')
          .eq('tribe_id', tribeId)
          .eq('user_id', userId)
          .maybeSingle();

      final isBanned = response != null;
      debugPrint('🔍 Ban check result: $isBanned (response: $response)');
      return isBanned;
    } catch (e) {
      debugPrint('❌ Check ban status error: $e');
      return false;
    }
  }

  /// حظر مستخدم من القبيلة
  static Future<bool> banUserFromTribe({
    required String tribeId,
    required String userId,
    required String bannedBy,
    String? reason,
  }) async {
    try {
      debugPrint('🚫 [BAN] Starting ban process...');
      debugPrint(
        '🚫 [BAN] Tribe: $tribeId, User: $userId, Banned by: $bannedBy',
      );
      debugPrint('🚫 [BAN] Reason: $reason');

      final insertData = {
        'tribe_id': tribeId,
        'user_id': userId,
        'banned_by': bannedBy,
        'reason': reason,
      };

      debugPrint('🚫 [BAN] Inserting into tribe_bans: $insertData');

      await client.from('tribe_bans').insert(insertData);

      debugPrint(
        '✅ [BAN] User $userId successfully banned from tribe $tribeId',
      );

      // التحقق من أن السجل تم إدراجه
      final verification = await client
          .from('tribe_bans')
          .select()
          .eq('tribe_id', tribeId)
          .eq('user_id', userId)
          .maybeSingle();

      debugPrint('🚫 [BAN] Verification: $verification');

      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ [BAN] Ban user error: $e');
      debugPrint('❌ [BAN] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// فك حظر مستخدم من القبيلة
  static Future<bool> unbanUserFromTribe(String tribeId, String userId) async {
    try {
      await client
          .from('tribe_bans')
          .delete()
          .eq('tribe_id', tribeId)
          .eq('user_id', userId);

      debugPrint('✅ User $userId unbanned from tribe $tribeId');
      return true;
    } catch (e) {
      debugPrint('❌ Unban user error: $e');
      return false;
    }
  }

  /// جلب قائمة المحظورين من القبيلة
  static Future<List<Map<String, dynamic>>> getBannedUsers(
    String tribeId,
  ) async {
    try {
      final response = await client
          .from('tribe_bans')
          .select('''
            id,
            user_id,
            tribe_id, 
            banned_at,
            reason,
            user:users!tribe_bans_user_id_fkey(id, name, username, profile_image),
            banned_by_user:users!tribe_bans_banned_by_fkey(id, name, username)
          ''')
          .eq('tribe_id', tribeId)
          .order('banned_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Get banned users error: $e');
      return [];
    }
  }

  /// تعديل kickMember لتضمين الحظر التلقائي
  static Future<bool> kickMemberAndBan({
    required String tribeId,
    required String userId,
    required String leaderId,
    String? reason,
  }) async {
    try {
      debugPrint('🚫 ============================================');
      debugPrint('🚫 [KICK+BAN] Starting kick and ban process');
      debugPrint('🚫 [KICK+BAN] User to kick: $userId');
      debugPrint('🚫 [KICK+BAN] From tribe: $tribeId');
      debugPrint('🚫 [KICK+BAN] By leader: $leaderId');
      debugPrint('🚫 ============================================');

      // الخطوة 1: طرد العضو
      debugPrint('🚫 [KICK+BAN] Step 1: Kicking user...');
      await kickMember(tribeId: tribeId, userId: userId, leaderId: leaderId);
      debugPrint('✅ [KICK+BAN] Step 1 complete: User kicked successfully');

      // الخطوة 2: إضافة للقائمة السوداء
      debugPrint('🚫 [KICK+BAN] Step 2: Adding to ban list...');
      await banUserFromTribe(
        tribeId: tribeId,
        userId: userId,
        bannedBy: leaderId,
        reason: reason ?? 'تم الطرد من القبيلة',
      );
      debugPrint('✅ [KICK+BAN] Step 2 complete: User banned successfully');

      debugPrint('🎉 [KICK+BAN] All steps completed successfully!');
      debugPrint('🚫 ============================================');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ ============================================');
      debugPrint('❌ [KICK+BAN] FATAL ERROR during kick and ban');
      debugPrint('❌ [KICK+BAN] Error: $e');
      debugPrint('❌ [KICK+BAN] Stack trace:');
      debugPrint('$stackTrace');
      debugPrint('❌ ============================================');
      return false; // إرجاع false بدلاً من rethrow
    }
  }

  /// فحص إذا كان المستخدم قائد في أي قبيلة
  static Future<bool> isUserLeaderAnywhere(String userId) async {
    try {
      final response = await client
          .from('tribe_members')
          .select('id')
          .eq('user_id', userId)
          .eq('is_leader', true)
          .eq('status', 'active')
          .limit(1)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('❌ Check leader status error: $e');
      return false;
    }
  }

  /// فحص إذا كان المستخدم عضو في أي قبيلة
  static Future<bool> isUserMemberAnywhere(String userId) async {
    try {
      final response = await client
          .from('tribe_members')
          .select('id')
          .eq('user_id', userId)
          .eq('status', 'active')
          .limit(1)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('❌ Check membership error: $e');
      return false;
    }
  }

  /// نقل القيادة لعضو آخر
  static Future<bool> transferLeadership({
    required String tribeId,
    required String currentLeaderId,
    required String newLeaderId,
  }) async {
    try {
      // فحص أن المستخدم الحالي هو القائد
      final isLeader = await isUserLeader(tribeId, currentLeaderId);
      if (!isLeader) {
        debugPrint('❌ User is not the leader');
        return false;
      }

      // فحص أن العضو الجديد موجود في القبيلة
      final isMember = await isUserMember(tribeId, newLeaderId);
      if (!isMember) {
        debugPrint('❌ New leader is not a member');
        return false;
      }

      // تحديث القيادة
      await client
          .from('tribes')
          .update({'leader_id': newLeaderId})
          .eq('id', tribeId);

      // تحديث حالة is_leader في tribe_members
      await client
          .from('tribe_members')
          .update({'is_leader': false})
          .eq('tribe_id', tribeId)
          .eq('user_id', currentLeaderId);

      await client
          .from('tribe_members')
          .update({'is_leader': true})
          .eq('tribe_id', tribeId)
          .eq('user_id', newLeaderId);

      debugPrint('✅ Leadership transferred to $newLeaderId');
      return true;
    } catch (e) {
      debugPrint('❌ Transfer leadership error: $e');
      return false;
    }
  }

  /// جلب حالة طلب الانضمام/العضوية
  static Future<String?> getJoinRequestStatus(
    String tribeId,
    String userId,
  ) async {
    try {
      final response = await client
          .from('tribe_members')
          .select('status')
          .eq('tribe_id', tribeId)
          .eq('user_id', userId)
          .maybeSingle();

      return response?['status'] as String?;
    } catch (e) {
      debugPrint('❌ Get join status error: $e');
      return null;
    }
  }

  // ==================== Tribe Media (Images & Audio) ====================

  /// رفع صورة للمحادثة - باستخدام Base64 (يتجاوز Storage RLS)
  static Future<String?> uploadTribeImage({
    required Uint8List imageBytes,
    required String tribeId,
    required String userId,
  }) async {
    try {
      debugPrint('📤 Converting tribe image to Base64...');

      // تحويل الصورة إلى Base64 Data URL
      final base64String = base64Encode(imageBytes);
      final dataUrl = 'data:image/jpeg;base64,$base64String';

      debugPrint(
        '✅ Image converted to Base64 (${(imageBytes.length / 1024).toStringAsFixed(1)} KB)',
      );
      return dataUrl;
    } catch (e) {
      debugPrint('❌ Upload tribe image error: $e');
      return null;
    }
  }

  /// رفع ملف صوتي للمحادثة - باستخدام Base64 (يتجاوز Storage RLS)
  static Future<String?> uploadTribeAudio({
    required String audioPath,
    required String tribeId,
    required String userId,
  }) async {
    try {
      debugPrint('📤 Converting tribe audio to Base64...');

      final audioFile = File(audioPath);
      final audioBytes = await audioFile.readAsBytes();

      // تحويل الصوت إلى Base64 Data URL
      final base64String = base64Encode(audioBytes);
      final dataUrl = 'data:audio/m4a;base64,$base64String';

      debugPrint(
        '✅ Audio converted to Base64 (${(audioBytes.length / 1024).toStringAsFixed(1)} KB)',
      );
      return dataUrl;
    } catch (e) {
      debugPrint('❌ Upload tribe audio error: $e');
      return null;
    }
  }

  /// حذف رسالة من المحادثة
  static Future<bool> deleteTribeMessage({
    required String messageId,
    required String userId,
  }) async {
    try {
      debugPrint('🗑️ Deleting message: $messageId by user: $userId');

      // التحقق من أن الرسالة للمستخدم نفسه
      final message = await client
          .from('tribe_messages')
          .select()
          .eq('id', messageId)
          .eq('user_id', userId)
          .maybeSingle();

      if (message == null) {
        debugPrint('❌ Message not found or not owned by user');
        return false;
      }

      // حذف الرسالة
      await client
          .from('tribe_messages')
          .delete()
          .eq('id', messageId)
          .eq('user_id', userId);

      debugPrint('✅ Message deleted successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Delete message error: $e');
      return false;
    }
  }

  // ==================== Support Messages (محادثات الدعم) ====================

  /// إرسال رسالة دعم من المستخدم
  static Future<Map<String, dynamic>?> sendSupportMessage({
    required String userId,
    required String message,
    String messageType = 'text',
    String? mediaUrl,
  }) async {
    try {
      final response = await client
          .from('support_messages')
          .insert({
            'user_id': userId,
            'message': message,
            'message_type': messageType,
            if (mediaUrl != null) 'media_url': mediaUrl,
            'is_from_admin': false,
          })
          .select()
          .single();

      debugPrint('✅ Support message sent');
      return response;
    } catch (e) {
      debugPrint('❌ Send support message error: $e');
      return null;
    }
  }

  /// إرسال رسالة دعم من الأدمن
  static Future<Map<String, dynamic>?> sendAdminSupportMessage({
    required String userId,
    required String message,
    String messageType = 'text',
    String? mediaUrl,
  }) async {
    try {
      final response = await client
          .from('support_messages')
          .insert({
            'user_id': userId,
            'message': message,
            'message_type': messageType,
            if (mediaUrl != null) 'media_url': mediaUrl,
            'is_from_admin': true,
          })
          .select()
          .single();

      debugPrint('✅ Admin support message sent');
      return response;
    } catch (e) {
      debugPrint('❌ Send admin support message error: $e');
      return null;
    }
  }

  /// جلب رسائل الدعم للمستخدم
  static Future<List<Map<String, dynamic>>> getSupportMessages(
    String userId, {
    int limit = 50,
  }) async {
    try {
      final response = await client
          .from('support_messages')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Get support messages error: $e');
      return [];
    }
  }

  /// جلب جميع محادثات الدعم (للأدمن)
  static Future<List<Map<String, dynamic>>> getAllSupportConversations() async {
    try {
      final response = await client
          .from('support_conversations')
          .select('''
            *,
            user:users!support_conversations_user_id_fkey(id, name, username, profile_image)
          ''')
          .order('last_message_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Get all support conversations error: $e');
      return [];
    }
  }

  /// الاشتراك في رسائل الدعم (Realtime)
  static RealtimeChannel subscribeSupportMessages(
    String userId,
    Function(Map<String, dynamic>) onMessage,
  ) {
    return client
        .channel('support_messages_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'support_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            onMessage(payload.newRecord);
          },
        )
        .subscribe();
  }

  /// تمييز رسائل الدعم كمقروءة
  static Future<void> markSupportMessagesAsRead(
    String userId,
    bool isAdmin,
  ) async {
    try {
      await client.rpc(
        'mark_support_messages_as_read',
        params: {'p_user_id': userId, 'p_is_admin': isAdmin},
      );

      debugPrint('✅ Support messages marked as read');
    } catch (e) {
      debugPrint('❌ Mark support messages as read error: $e');
    }
  }

  /// جلب عدد الرسائل غير المقروءة للمستخدم
  static Future<int> getUnreadSupportCount(String userId) async {
    try {
      final response = await client
          .from('support_conversations')
          .select('unread_user_count')
          .eq('user_id', userId)
          .maybeSingle();

      return response?['unread_user_count'] ?? 0;
    } catch (e) {
      debugPrint('❌ Get unread support count error: $e');
      return 0;
    }
  }

  /// جلب عدد الرسائل غير المقروءة لجميع المحادثات (للأدمن)
  static Future<int> getTotalUnreadAdminCount() async {
    try {
      final response = await client
          .from('support_conversations')
          .select('unread_admin_count');

      int total = 0;
      for (var conv in response) {
        total += (conv['unread_admin_count'] as int?) ?? 0;
      }

      return total;
    } catch (e) {
      debugPrint('❌ Get total unread admin count error: $e');
      return 0;
    }
  }

  // ==================== Notifications (الإشعارات) ====================

  /// حفظ FCM token للجهاز
  static Future<bool> saveFCMToken({
    required String userId,
    required String token,
    String? deviceInfo,
    String? platform,
  }) async {
    try {
      await client.rpc(
        'upsert_fcm_token',
        params: {
          'p_user_id': userId,
          'p_token': token,
          'p_device_info': deviceInfo ?? 'Unknown',
          'p_platform': platform ?? 'unknown',
        },
      );

      debugPrint('✅ FCM token saved');
      return true;
    } catch (e) {
      debugPrint('❌ Save FCM token error: $e');
      return false;
    }
  }

  /// جلب جميع FCM tokens
  static Future<List<String>> getAllFCMTokens() async {
    try {
      final response = await client.from('fcm_tokens').select('token');

      return List<String>.from(response.map((item) => item['token'] as String));
    } catch (e) {
      debugPrint('❌ Get all FCM tokens error: $e');
      return [];
    }
  }

  /// إرسال إشعار لجميع المستخدمين
  /// ملاحظة: هذه الدالة تحتاج إلى Firebase Cloud Functions
  /// أو يمكن استخدام Supabase Edge Functions
  static Future<bool> sendNotificationToAll({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // جلب جميع المستخدمين
      final users = await getAllUsers();

      if (users.isEmpty) {
        debugPrint('⚠️ No users found');
        return false;
      }

      // حفظ في السجل
      final notificationResponse = await client
          .from('notification_history')
          .insert({
            'title': title,
            'body': body,
            'recipient_count': users.length,
          })
          .select()
          .single();

      final notificationId = notificationResponse['id'];

      // حفظ الإشعار لكل مستخدم
      final userNotifications = users.map((user) {
        return {
          'user_id': user['id'],
          'notification_id': notificationId,
          'title': title,
          'body': body,
          'is_read': false,
        };
      }).toList();

      await client.from('user_notifications').insert(userNotifications);

      debugPrint('📨 Notification saved for ${users.length} users');
      debugPrint('Title: $title');
      debugPrint('Body: $body');

      debugPrint('✅ Notification sent successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Send notification error: $e');
      return false;
    }
  }

  /// جلب سجل الإشعارات
  static Future<List<Map<String, dynamic>>> getNotificationHistory({
    int limit = 20,
  }) async {
    try {
      final response = await client
          .from('notification_history')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Get notification history error: $e');
      return [];
    }
  }

  /// جلب إشعارات المستخدم
  static Future<List<Map<String, dynamic>>> getUserNotifications(
    String userId, {
    int limit = 50,
  }) async {
    try {
      final response = await client
          .from('user_notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Get user notifications error: $e');
      return [];
    }
  }

  /// جلب عدد الإشعارات غير المقروءة
  static Future<int> getUnreadNotificationsCount(String userId) async {
    try {
      final response = await client
          .from('user_notifications')
          .select()
          .eq('user_id', userId)
          .eq('is_read', false);

      return response.length;
    } catch (e) {
      debugPrint('❌ Get unread notifications count error: $e');
      return 0;
    }
  }

  /// تمييز إشعار كمقروء
  static Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      await client
          .from('user_notifications')
          .update({'is_read': true})
          .eq('id', notificationId);

      debugPrint('✅ Notification marked as read');
      return true;
    } catch (e) {
      debugPrint('❌ Mark notification as read error: $e');
      return false;
    }
  }

  /// تمييز جميع الإشعارات كمقروءة
  static Future<bool> markAllNotificationsAsRead(String userId) async {
    try {
      await client
          .from('user_notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);

      debugPrint('✅ All notifications marked as read');
      return true;
    } catch (e) {
      debugPrint('❌ Mark all notifications as read error: $e');
      return false;
    }
  }

  /// Alias for markAllNotificationsAsRead
  static Future<bool> markNotificationsAsRead(String userId) {
    return markAllNotificationsAsRead(userId);
  }

  // ===== نظام تتبع التقدم والشارات =====

  /// مقارنة شارتين وإرجاع الأعلى
  static String _getHighestBadge(String? badge1, String? badge2) {
    if (badge1 == null || badge1.isEmpty) return badge2 ?? '';
    if (badge2 == null || badge2.isEmpty) return badge1;

    // ترتيب الشارات من الأقل إلى الأعلى
    final badgeOrder = [
      'bronze',
      'platinum',
      'gold',
      'purple',
      'hero',
      'royal',
    ];

    // تحويل الشارات إلى قوائم
    final badges1 = badge1.split(',').map((e) => e.trim()).toList();
    final badges2 = badge2.split(',').map((e) => e.trim()).toList();

    // دمج الشارات وإزالة التكرار
    final allBadges = {...badges1, ...badges2}.toList();

    // ترتيب حسب الأولوية
    allBadges.sort((a, b) {
      final indexA = badgeOrder.indexOf(a);
      final indexB = badgeOrder.indexOf(b);
      if (indexA == -1) return 1;
      if (indexB == -1) return -1;
      return indexA.compareTo(indexB);
    });

    return allBadges.join(',');
  }

  /// حفظ تقدم المستخدم في الاختبار
  static Future<bool> saveUserQuizProgress({
    required String userId,
    required String quizId,
    required int currentQuestion,
    required int correctAnswers,
    required int wrongAnswers,
    String? earnedBadge,
  }) async {
    try {
      // التحقق من وجود سجل سابق
      final existing = await client
          .from('user_quiz_progress')
          .select()
          .eq('user_id', userId)
          .eq('quiz_id', quizId)
          .maybeSingle();

      String? finalBadge = earnedBadge;

      if (existing != null) {
        // مقارنة الشارات - الاحتفاظ بالأعلى
        final oldBadge = existing['earned_badge']?.toString();
        finalBadge = _getHighestBadge(oldBadge, earnedBadge);

        debugPrint(
          '🏅 مقارنة الشارات: القديمة=$oldBadge، الجديدة=$earnedBadge، النهائية=$finalBadge',
        );

        // تحديث السجل الموجود مع الاحتفاظ بأعلى شارة
        await client
            .from('user_quiz_progress')
            .update({
              'current_question': currentQuestion,
              'correct_answers': correctAnswers,
              'wrong_answers': wrongAnswers,
              'earned_badge': finalBadge,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', userId)
            .eq('quiz_id', quizId);
      } else {
        // إنشاء سجل جديد
        await client.from('user_quiz_progress').insert({
          'user_id': userId,
          'quiz_id': quizId,
          'current_question': currentQuestion,
          'correct_answers': correctAnswers,
          'wrong_answers': wrongAnswers,
          'earned_badge': finalBadge,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
      return true;
    } catch (e) {
      debugPrint('Error saving quiz progress: $e');
      return false;
    }
  }

  /// جلب تقدم المستخدم في اختبار معين
  static Future<Map<String, dynamic>?> getUserQuizProgress({
    required String userId,
    required String quizId,
  }) async {
    try {
      final result = await client
          .from('user_quiz_progress')
          .select()
          .eq('user_id', userId)
          .eq('quiz_id', quizId)
          .maybeSingle();
      return result;
    } catch (e) {
      debugPrint('Error getting quiz progress: $e');
      return null;
    }
  }

  /// جلب جميع تقدم المستخدم في كل الاختبارات
  static Future<List<Map<String, dynamic>>> getAllUserProgress(
    String userId,
  ) async {
    try {
      final result = await client
          .from('user_quiz_progress')
          .select()
          .eq('user_id', userId)
          .order('updated_at', ascending: false);
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      debugPrint('Error getting all user progress: $e');
      return [];
    }
  }

  /// حذف تقدم المستخدم (إعادة ضبط)
  static Future<bool> resetUserQuizProgress({
    required String userId,
    required String quizId,
  }) async {
    try {
      await client
          .from('user_quiz_progress')
          .delete()
          .eq('user_id', userId)
          .eq('quiz_id', quizId);
      return true;
    } catch (e) {
      debugPrint('Error resetting quiz progress: $e');
      return false;
    }
  }

  // ===== نظام الجلسات المتقدم =====

  /// إنشاء جلسة اختبار جديدة
  static Future<String?> createQuizSession({
    required String userId,
    required String quizId,
    required int totalQuestions,
  }) async {
    try {
      final response = await client
          .from('quiz_sessions')
          .insert({
            'user_id': userId,
            'quiz_id': quizId,
            'total_questions': totalQuestions,
            'status': 'active',
            'current_question_index': 0,
            'correct_count': 0,
            'wrong_count': 0,
            'skipped_count': 0,
          })
          .select('id')
          .single();

      final sessionId = response['id'] as String;
      debugPrint('✅ جلسة جديدة تم إنشاؤها: $sessionId');
      return sessionId;
    } catch (e) {
      debugPrint('❌ خطأ في إنشاء الجلسة: $e');
      return null;
    }
  }

  /// تحديث جلسة الاختبار
  static Future<bool> updateQuizSession({
    required String sessionId,
    int? currentQuestionIndex,
    int? correctCount,
    int? wrongCount,
    int? skippedCount,
    String? earnedBadges,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (currentQuestionIndex != null) {
        updates['current_question_index'] = currentQuestionIndex;
      }
      if (correctCount != null) updates['correct_count'] = correctCount;
      if (wrongCount != null) updates['wrong_count'] = wrongCount;
      if (skippedCount != null) updates['skipped_count'] = skippedCount;
      if (earnedBadges != null) updates['earned_badges'] = earnedBadges;

      if (updates.isEmpty) return true;

      await client.from('quiz_sessions').update(updates).eq('id', sessionId);
      return true;
    } catch (e) {
      debugPrint('❌ خطأ في تحديث الجلسة: $e');
      return false;
    }
  }

  /// إنهاء جلسة الاختبار
  static Future<bool> completeQuizSession({
    required String sessionId,
    required int finalScore,
    String? earnedBadges,
  }) async {
    try {
      final session = await client
          .from('quiz_sessions')
          .select('session_start')
          .eq('id', sessionId)
          .single();

      final sessionStart = DateTime.parse(session['session_start'] as String);
      final duration = DateTime.now().difference(sessionStart).inSeconds;

      await client
          .from('quiz_sessions')
          .update({
            'status': 'completed',
            'session_end': DateTime.now().toIso8601String(),
            'total_duration_seconds': duration,
            'final_score': finalScore,
            'earned_badges': earnedBadges,
          })
          .eq('id', sessionId);

      debugPrint('✅ تم إنهاء الجلسة: $sessionId، المدة: ${duration}s');
      return true;
    } catch (e) {
      debugPrint('❌ خطأ في إنهاء الجلسة: $e');
      return false;
    }
  }

  /// جلب الجلسة النشطة للمستخدم في اختبار معين
  static Future<Map<String, dynamic>?> getActiveSession({
    required String userId,
    required String quizId,
  }) async {
    try {
      final response = await client
          .from('quiz_sessions')
          .select()
          .eq('user_id', userId)
          .eq('quiz_id', quizId)
          .eq('status', 'active')
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('❌ خطأ في جلب الجلسة النشطة: $e');
      return null;
    }
  }

  /// إيقاف الجلسة مؤقتاً
  static Future<bool> pauseQuizSession(String sessionId) async {
    try {
      await client
          .from('quiz_sessions')
          .update({'status': 'paused'})
          .eq('id', sessionId);
      return true;
    } catch (e) {
      debugPrint('❌ خطأ في إيقاف الجلسة: $e');
      return false;
    }
  }

  /// استئناف الجلسة
  static Future<bool> resumeQuizSession(String sessionId) async {
    try {
      await client
          .from('quiz_sessions')
          .update({'status': 'active'})
          .eq('id', sessionId);
      return true;
    } catch (e) {
      debugPrint('❌ خطأ في استئناف الجلسة: $e');
      return false;
    }
  }

  /// تسجيل محاولة إجابة على سؤال
  static Future<bool> recordQuestionAttempt({
    required String sessionId,
    required String questionId,
    required String questionText,
    required String questionType,
    required String correctAnswer,
    String? userAnswer,
    required bool isCorrect,
    required int timeSpentSeconds,
    int attemptNumber = 1,
  }) async {
    try {
      await client.from('question_attempts').insert({
        'session_id': sessionId,
        'question_id': questionId,
        'question_text': questionText,
        'question_type': questionType,
        'correct_answer': correctAnswer,
        'user_answer': userAnswer,
        'is_correct': isCorrect,
        'time_spent_seconds': timeSpentSeconds,
        'attempt_number': attemptNumber,
      });

      // تحديث weak_questions إذا كانت الإجابة خاطئة
      if (!isCorrect) {
        await _updateWeakQuestion(sessionId: sessionId, questionId: questionId);
      }

      return true;
    } catch (e) {
      debugPrint('❌ خطأ في تسجيل المحاولة: $e');
      return false;
    }
  }

  /// تحديث الأسئلة الصعبة
  static Future<void> _updateWeakQuestion({
    required String sessionId,
    required String questionId,
  }) async {
    try {
      // جلب user_id من الجلسة
      final session = await client
          .from('quiz_sessions')
          .select('user_id')
          .eq('id', sessionId)
          .single();
      final userId = session['user_id'] as String;

      // التحقق من وجود السؤال في weak_questions
      final existing = await client
          .from('weak_questions')
          .select()
          .eq('user_id', userId)
          .eq('question_id', questionId)
          .maybeSingle();

      if (existing != null) {
        // تحديث السجل الموجود
        final newWrongCount = (existing['wrong_count'] as int) + 1;
        final newTotalAttempts = (existing['total_attempts'] as int) + 1;

        await client
            .from('weak_questions')
            .update({
              'wrong_count': newWrongCount,
              'total_attempts': newTotalAttempts,
              'last_attempt_date': DateTime.now().toIso8601String(),
            })
            .eq('id', existing['id']);
      } else {
        // إنشاء سجل جديد
        await client.from('weak_questions').insert({
          'user_id': userId,
          'question_id': questionId,
          'wrong_count': 1,
          'total_attempts': 1,
        });
      }
    } catch (e) {
      debugPrint('❌ خطأ في تحديث الأسئلة الصعبة: $e');
    }
  }

  /// جلب الأسئلة الصعبة للمستخدم
  static Future<List<Map<String, dynamic>>> getUserWeakQuestions({
    required String userId,
    int limit = 20,
  }) async {
    try {
      final response = await client
          .from('weak_questions')
          .select('''
            *,
            quiz_questions!inner(*)
          ''')
          .eq('user_id', userId)
          .eq('mastered', false)
          .order('wrong_count', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ خطأ في جلب الأسئلة الصعبة: $e');
      return [];
    }
  }

  /// حساب وتحديث التحليلات
  static Future<bool> calculateUserAnalytics({
    required String userId,
    required String quizId,
    required String categoryId,
  }) async {
    try {
      // جلب جميع الجلسات المكتملة لهذا الاختبار
      final sessions = await client
          .from('quiz_sessions')
          .select()
          .eq('user_id', userId)
          .eq('quiz_id', quizId)
          .eq('status', 'completed');

      if (sessions.isEmpty) return true;

      final totalAttempts = sessions.length;
      int totalQuestionsAnswered = 0;
      int totalCorrect = 0;
      int totalWrong = 0;
      int bestScore = 0;
      int totalTimeSpent = 0;

      for (var session in sessions) {
        final correct = session['correct_count'] as int? ?? 0;
        final wrong = session['wrong_count'] as int? ?? 0;
        final duration = session['total_duration_seconds'] as int? ?? 0;

        totalQuestionsAnswered += (correct + wrong);
        totalCorrect += correct;
        totalWrong += wrong;
        totalTimeSpent += duration;

        if (correct > bestScore) {
          bestScore = correct;
        }
      }

      final avgTimePerQuestion = totalQuestionsAnswered > 0
          ? (totalTimeSpent / totalQuestionsAnswered)
          : 0.0;

      final bestScorePercentage = totalQuestionsAnswered > 0
          ? (bestScore / (sessions[0]['total_questions'] as int)) * 100
          : 0.0;

      // التحقق من وجود سجل تحليلات
      final existing = await client
          .from('user_quiz_analytics')
          .select()
          .eq('user_id', userId)
          .eq('quiz_id', quizId)
          .maybeSingle();

      if (existing != null) {
        // تحديث
        await client
            .from('user_quiz_analytics')
            .update({
              'total_attempts': totalAttempts,
              'total_questions_answered': totalQuestionsAnswered,
              'total_correct': totalCorrect,
              'total_wrong': totalWrong,
              'average_time_per_question': avgTimePerQuestion,
              'best_score': bestScore,
              'best_score_percentage': bestScorePercentage,
              'last_attempt_date': DateTime.now().toIso8601String(),
              'total_time_spent_seconds': totalTimeSpent,
            })
            .eq('id', existing['id']);
      } else {
        // إنشاء جديد
        await client.from('user_quiz_analytics').insert({
          'user_id': userId,
          'quiz_id': quizId,
          'category_id': categoryId,
          'total_attempts': totalAttempts,
          'total_questions_answered': totalQuestionsAnswered,
          'total_correct': totalCorrect,
          'total_wrong': totalWrong,
          'average_time_per_question': avgTimePerQuestion,
          'best_score': bestScore,
          'best_score_percentage': bestScorePercentage,
          'last_attempt_date': DateTime.now().toIso8601String(),
          'total_time_spent_seconds': totalTimeSpent,
        });
      }

      return true;
    } catch (e) {
      debugPrint('❌ خطأ في حساب التحليلات: $e');
      return false;
    }
  }

  /// جلب إحصائيات تفصيلية للمستخدم
  static Future<Map<String, dynamic>?> getDetailedUserStats({
    required String userId,
    required String quizId,
  }) async {
    try {
      final analytics = await client
          .from('user_quiz_analytics')
          .select()
          .eq('user_id', userId)
          .eq('quiz_id', quizId)
          .maybeSingle();

      return analytics;
    } catch (e) {
      debugPrint('❌ خطأ في جلب الإحصائيات: $e');
      return null;
    }
  }

  /// تحديث إعدادات الشارات لقسم معين
  static Future<bool> updateCategoryBadgeSettings({
    required String categoryId,
    int? bronzeThreshold,
    int? platinumThreshold,
    int? goldThreshold,
    int? purpleThreshold,
    int? heroThreshold,
    int? royalThreshold,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (bronzeThreshold != null) {
        updates['badge_bronze_threshold'] = bronzeThreshold;
      }
      if (platinumThreshold != null) {
        updates['badge_platinum_threshold'] = platinumThreshold;
      }
      if (goldThreshold != null) {
        updates['badge_gold_threshold'] = goldThreshold;
      }
      if (purpleThreshold != null) {
        updates['badge_purple_threshold'] = purpleThreshold;
      }
      if (heroThreshold != null) {
        updates['badge_hero_threshold'] = heroThreshold;
      }
      if (royalThreshold != null) {
        updates['badge_royal_threshold'] = royalThreshold;
      }

      if (updates.isEmpty) return true;

      await client.from('quiz_categories').update(updates).eq('id', categoryId);
      return true;
    } catch (e) {
      debugPrint('Error updating badge settings: $e');
      return false;
    }
  }

  /// جلب إعدادات الشارات لقسم معين
  static Future<Map<String, int>> getCategoryBadgeSettings(
    String categoryId,
  ) async {
    try {
      if (categoryId.isEmpty) {
        return <String, int>{
          'bronze': 10,
          'platinum': 11,
          'gold': 12,
          'purple': 14,
          'hero': 16,
          'royal': 17,
        };
      }

      final response = await client
          .from('quiz_categories')
          .select(
            'badge_bronze_threshold, badge_platinum_threshold, badge_gold_threshold, badge_purple_threshold, badge_hero_threshold, badge_royal_threshold',
          )
          .eq('id', categoryId)
          .maybeSingle();

      if (response != null) {
        // تحويل صريح من IdentityMap إلى Map<String, int>
        return <String, int>{
          'bronze': (response['badge_bronze_threshold'] as num?)?.toInt() ?? 10,
          'platinum':
              (response['badge_platinum_threshold'] as num?)?.toInt() ?? 11,
          'gold': (response['badge_gold_threshold'] as num?)?.toInt() ?? 12,
          'purple': (response['badge_purple_threshold'] as num?)?.toInt() ?? 14,
          'hero': (response['badge_hero_threshold'] as num?)?.toInt() ?? 16,
          'royal': (response['badge_royal_threshold'] as num?)?.toInt() ?? 17,
        };
      }
    } catch (e) {
      debugPrint('Error getting badge settings: $e');
    }

    // إرجاع القيم الافتراضية في حالة الفشل
    return <String, int>{
      'bronze': 10,
      'platinum': 11,
      'gold': 12,
      'purple': 14,
      'hero': 16,
      'royal': 17,
    };
  }

  /// جلب الشارة المكتسبة للمستخدم في قسم معين
  static Future<String?> getUserBadgeForCategory({
    required String userId,
    required String categoryId,
  }) async {
    try {
      if (userId.isEmpty || categoryId.isEmpty) {
        return null;
      }

      // 1. جلب إعدادات الشارات الحالية لهذه الفئة
      final settings = await getCategoryBadgeSettings(categoryId);

      // 2. جلب جميع الاختبارات في هذا القسم
      final response = await client
          .from('quizzes')
          .select('id')
          .eq('category_id', categoryId);

      final quizzes = List<Map<String, dynamic>>.from(response);
      if (quizzes.isEmpty) return null;

      // 3. البحث عن أعلى نتيجة إجمالية في هذا القسم
      int maxScore = 0;

      for (var quiz in quizzes) {
        final quizId = quiz['id']?.toString() ?? '';
        if (quizId.isEmpty) continue;

        final progress = await getUserQuizProgress(
          userId: userId,
          quizId: quizId,
        );

        if (progress != null) {
          final score = (progress['correct_answers'] as num?)?.toInt() ?? 0;
          if (score > maxScore) {
            maxScore = score;
          }
        }
      }

      if (maxScore <= 0) return null;

      // 4. تحديد جميع الشارات التي يستحقها المستخدم بناءً على هذه النتيجة والإعدادات الحالية
      final List<String> earnedBadges = [];
      if (maxScore >= settings['bronze']!) earnedBadges.add('bronze');
      if (maxScore >= settings['platinum']!) earnedBadges.add('platinum');
      if (maxScore >= settings['gold']!) earnedBadges.add('gold');
      if (maxScore >= settings['purple']!) earnedBadges.add('purple');
      if (maxScore >= settings['hero']!) earnedBadges.add('hero');
      if (maxScore >= settings['royal']!) earnedBadges.add('royal');

      return earnedBadges.isNotEmpty ? earnedBadges.join(',') : null;
    } catch (e) {
      debugPrint('❌ Error getting user badge: $e');
      return null;
    }
  }

  // ===== إدارة إعدادات التطبيق =====

  /// جلب اسم التطبيق من الإعدادات
  static Future<String> getAppName() async {
    try {
      final result = await client
          .from('app_settings')
          .select('setting_value')
          .eq('setting_key', 'app_name')
          .single();

      return result['setting_value'] as String? ?? 'تطبيق تسجيل الدخول';
    } catch (e) {
      debugPrint('❌ Error fetching app name: $e');
      return 'تطبيق تسجيل الدخول'; // القيمة الافتراضية
    }
  }

  /// تحديث اسم التطبيق (يتطلب كلمة مرور المسؤول)
  static Future<bool> updateAppName({
    required String newName,
    required String adminPassword,
  }) async {
    try {
      final result = await client.rpc(
        'update_app_name',
        params: {'new_name': newName, 'admin_password': adminPassword},
      );

      return result as bool? ?? false;
    } catch (e) {
      debugPrint('❌ Error updating app name: $e');
      return false;
    }
  }

  /// الاستماع للتغييرات الفورية على اسم التطبيق
  static RealtimeChannel subscribeToAppName(
    void Function(String newName) onNameChanged,
  ) {
    final channel = client
        .channel('app_settings_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'app_settings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'setting_key',
            value: 'app_name',
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              final newValue = payload.newRecord['setting_value'] as String?;
              if (newValue != null) {
                onNameChanged(newValue);
              }
            }
          },
        )
        .subscribe();

    return channel;
  }

  /// إلغاء الاستماع للتغييرات
  static Future<void> unsubscribeFromAppName(RealtimeChannel channel) async {
    await client.removeChannel(channel);
  }

  // ==================== News Methods ====================

  /// جلب جميع الأخبار (المنشورة فقط)
  static Future<List<Map<String, dynamic>>> getAllNews() async {
    try {
      final response = await client
          .from('news')
          .select('*')
          .eq('is_published', true)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error fetching news: $e');
      return [];
    }
  }

  /// إنشاء خبر جديد (للإدارة)
  static Future<bool> createNews({
    required String title,
    required String content,
    String? emoji,
    bool isImportant = false,
    bool isPublished = true,
  }) async {
    try {
      await client.from('news').insert({
        'title': title,
        'content': content,
        'emoji': emoji ?? '📰',
        'is_important': isImportant,
        'is_published': isPublished,
      });
      return true;
    } catch (e) {
      debugPrint('❌ Error creating news: $e');
      return false;
    }
  }

  /// تحديث خبر (للإدارة)
  static Future<bool> updateNews({
    required String newsId,
    String? title,
    String? content,
    String? emoji,
    bool? isImportant,
    bool? isPublished,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (title != null) data['title'] = title;
      if (content != null) data['content'] = content;
      if (emoji != null) data['emoji'] = emoji;
      if (isImportant != null) data['is_important'] = isImportant;
      if (isPublished != null) data['is_published'] = isPublished;

      if (data.isEmpty) return false;

      await client.from('news').update(data).eq('id', newsId);
      return true;
    } catch (e) {
      debugPrint('❌ Error updating news: $e');
      return false;
    }
  }

  /// حذف خبر (للإدارة)
  static Future<bool> deleteNews(String newsId) async {
    try {
      await client.from('news').delete().eq('id', newsId);
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting news: $e');
      return false;
    }
  }

  // ==================== Ask Me System Methods ====================

  /// ========== إدارة المجيبين/المستشارين ==========

  /// جلب جميع المجيبين النشطين
  static Future<List<Map<String, dynamic>>> getActiveExperts() async {
    try {
      final response = await client
          .from('ask_me_experts')
          .select('''
            *,
            users:user_id (id, name, username, profile_image)
          ''')
          .eq('is_active', true)
          .order('order_index', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error fetching active experts: $e');
      return [];
    }
  }

  /// ========== نظام تتبع حالة الاتصال ==========

  /// تحديث حالة اتصال المستشار (متصل/غير متصل)
  static Future<bool> updateExpertOnlineStatus(
    String expertUserId,
    bool isOnline,
  ) async {
    try {
      await client.rpc(
        'update_expert_online_status',
        params: {'expert_user_id': expertUserId, 'online_status': isOnline},
      );
      debugPrint('✅ Expert ${isOnline ? "online" : "offline"}: $expertUserId');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating expert status: $e');
      return false;
    }
  }

  /// نبضة قلب - يُستدعى كل دقيقة للحفاظ على حالة "متصل"
  static Future<bool> expertHeartbeat(String expertUserId) async {
    try {
      await client.rpc(
        'expert_heartbeat',
        params: {'expert_user_id': expertUserId},
      );
      return true;
    } catch (e) {
      debugPrint('❌ Heartbeat failed: $e');
      return false;
    }
  }

  /// جلب جميع المجيبين (للأدمن)
  static Future<List<Map<String, dynamic>>> getAllExperts() async {
    try {
      final response = await client
          .from('ask_me_experts')
          .select('''
            *,
            users:user_id (id, name, username, profile_image)
          ''')
          .order('order_index', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error fetching all experts: $e');
      return [];
    }
  }

  /// إضافة مجيب جديد (أدمن فقط)
  static Future<bool> addExpert({
    required String userId,
    required String displayName,
    String? bio,
    String? specialization,
    String? profileImage,
    int orderIndex = 0,
  }) async {
    try {
      await client.from('ask_me_experts').insert({
        'user_id': userId,
        'display_name': displayName,
        'bio': bio,
        'specialization': specialization ?? 'عام',
        'profile_image': profileImage,
        'order_index': orderIndex,
        'is_active': true,
      });
      return true;
    } catch (e) {
      debugPrint('❌ Error adding expert: $e');
      return false;
    }
  }

  /// تحديث مجيب
  static Future<bool> updateExpert({
    required String expertId,
    String? displayName,
    String? bio,
    String? specialization,
    String? profileImage,
    bool? isActive,
    int? orderIndex,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (displayName != null) data['display_name'] = displayName;
      if (bio != null) data['bio'] = bio;
      if (specialization != null) data['specialization'] = specialization;
      if (profileImage != null) data['profile_image'] = profileImage;
      if (isActive != null) data['is_active'] = isActive;
      if (orderIndex != null) data['order_index'] = orderIndex;

      if (data.isEmpty) return false;

      await client.from('ask_me_experts').update(data).eq('id', expertId);
      return true;
    } catch (e) {
      debugPrint('❌ Error updating expert: $e');
      return false;
    }
  }

  /// حذف مجيب
  static Future<bool> deleteExpert(String expertId) async {
    try {
      await client.from('ask_me_experts').delete().eq('id', expertId);
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting expert: $e');
      return false;
    }
  }

  /// تبديل حالة المجيب (تفعيل/تعطيل)
  static Future<bool> toggleExpertStatus(String expertId, bool isActive) async {
    try {
      await client
          .from('ask_me_experts')
          .update({'is_active': isActive})
          .eq('id', expertId);
      return true;
    } catch (e) {
      debugPrint('❌ Error toggling expert status: $e');
      return false;
    }
  }

  /// التحقق مما إذا كان المستخدم مجيب/مستشار
  static Future<bool> checkIfExpert(String userId) async {
    try {
      final response = await client
          .from('ask_me_experts')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('❌ Error checking expert status: $e');
      return false;
    }
  }

  /// ========== إدارة المحادثات ==========

  /// إنشاء محادثة جديدة أو جلب المحادثة الموجودة
  static Future<String?> createOrGetConversation({
    required String userId,
    required String expertId,
  }) async {
    try {
      // التحقق من وجود محادثة موجودة
      final existing = await client
          .from('ask_me_conversations')
          .select('id')
          .eq('user_id', userId)
          .eq('expert_id', expertId)
          .maybeSingle();

      if (existing != null) {
        return existing['id'] as String;
      }

      // إنشاء محادثة جديدة
      final response = await client
          .from('ask_me_conversations')
          .insert({
            'user_id': userId,
            'expert_id': expertId,
            'status': 'active',
          })
          .select('id')
          .single();

      return response['id'] as String;
    } catch (e) {
      debugPrint('❌ Error creating/getting conversation: $e');
      return null;
    }
  }

  /// جلب محادثات المستخدم
  static Future<List<Map<String, dynamic>>> getUserConversations(
    String userId,
  ) async {
    try {
      final response = await client
          .from('ask_me_conversations')
          .select('''
            *,
            expert:expert_id (id, name, username, profile_image),
            expert_info:expert_id (
              ask_me_experts (display_name, bio, specialization, profile_image)
            )
          ''')
          .eq('user_id', userId)
          .order('last_message_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error fetching user conversations: $e');
      return [];
    }
  }

  /// جلب محادثات المجيب
  static Future<List<Map<String, dynamic>>> getExpertConversations(
    String expertId,
  ) async {
    try {
      final response = await client
          .from('ask_me_conversations')
          .select('''
            *,
            user:user_id (id, name, username, profile_image)
          ''')
          .eq('expert_id', expertId)
          .order('last_message_at', ascending: false);

      // تحويل أسماء الأعمدة لتتوافق مع الكود
      final conversations = List<Map<String, dynamic>>.from(response);
      return conversations.map((conv) {
        return {
          ...conv,
          'expert_unread_count': conv['unread_count_expert'] ?? 0,
          'user_name':
              conv['user']?['name'] ?? conv['user']?['username'] ?? 'مستخدم',
          'user_username': conv['user']?['username'] ?? '',
          'user_profile_image': conv['user']?['profile_image'],
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ Error fetching expert conversations: $e');
      return [];
    }
  }

  /// إعادة تعيين عداد الرسائل غير المقروءة
  static Future<bool> resetUnreadCount({
    required String conversationId,
    required bool isExpert,
  }) async {
    try {
      await client
          .from('ask_me_conversations')
          .update({isExpert ? 'unread_count_expert' : 'unread_count_user': 0})
          .eq('id', conversationId);
      return true;
    } catch (e) {
      debugPrint('❌ Error resetting unread count: $e');
      return false;
    }
  }

  /// الاستماع لتغييرات محادثات المجيب (صندوق الوارد)
  static RealtimeChannel subscribeToExpertConversations(
    String expertId,
    void Function() onUpdate,
  ) {
    return client
        .channel('expert_convs_$expertId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ask_me_conversations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'expert_id',
            value: expertId,
          ),
          callback: (payload) {
            onUpdate();
          },
        )
        .subscribe();
  }

  /// إلغاء الاشتراك في محادثات المجيب
  static void unsubscribeFromExpertConversations(RealtimeChannel channel) {
    client.removeChannel(channel);
  }

  /// ========== إدارة الرسائل ==========

  /// إرسال رسالة
  static Future<bool> sendAskMeMessage({
    required String conversationId,
    required String senderId,
    required String message,
  }) async {
    try {
      await client.from('ask_me_messages').insert({
        'conversation_id': conversationId,
        'sender_id': senderId,
        'message': message,
      });
      return true;
    } catch (e) {
      debugPrint('❌ Error sending message: $e');
      return false;
    }
  }

  /// جلب رسائل المحادثة
  static Future<List<Map<String, dynamic>>> getConversationMessages(
    String conversationId,
  ) async {
    try {
      final response = await client
          .from('ask_me_messages')
          .select('''
            *,
            sender:sender_id (id, name, username, profile_image)
          ''')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error fetching messages: $e');
      return [];
    }
  }

  /// تحديد الرسائل كمقروءة
  static Future<bool> markMessagesAsRead({
    required String conversationId,
    required String userId,
  }) async {
    try {
      await client
          .from('ask_me_messages')
          .update({'is_read': true})
          .eq('conversation_id', conversationId)
          .neq('sender_id', userId);
      return true;
    } catch (e) {
      debugPrint('❌ Error marking messages as read: $e');
      return false;
    }
  }

  /// الاشتراك في رسائل محادثة (Realtime)
  static RealtimeChannel subscribeToConversationMessages(
    String conversationId,
    void Function(Map<String, dynamic>) onNewMessage,
  ) {
    return client
        .channel('conversation_$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'ask_me_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) async {
            // جلب الرسالة مع معلومات المرسل
            final message = await client
                .from('ask_me_messages')
                .select('''
                  *,
                  sender:sender_id (id, name, username, profile_image)
                ''')
                .eq('id', payload.newRecord['id'])
                .single();
            onNewMessage(message);
          },
        )
        .subscribe();
  }

  /// إلغاء الاشتراك من رسائل المحادثة
  static void unsubscribeFromConversationMessages(RealtimeChannel channel) {
    client.removeChannel(channel);
  }

  // ==================== Expert Chat Storage Management (30 Buckets) ====================

  /// الحصول على البكت النشط لصور محادثات المستشارين
  static Future<String> getActiveExpertChatBucket() async {
    try {
      final response = await client.rpc('get_active_expert_bucket');
      final bucketName = response as String?;
      debugPrint('📦 Active bucket: ${bucketName ?? 'expert_chat_images_1'}');
      return bucketName ?? 'expert_chat_images_1';
    } catch (e) {
      debugPrint('❌ Error getting active expert bucket: $e');
      return 'expert_chat_images_1'; // Fallback
    }
  }

  /// التحقق من سعة البكت والانتقال للتالي إذا لزم الأمر
  static Future<String> getAvailableExpertChatBucket() async {
    try {
      // استخدام دالة SQL الذكية للتحقق والتبديل التلقائي
      final bucketName = await client.rpc('check_and_switch_bucket_if_needed');
      debugPrint('✅ Available bucket: $bucketName');
      return bucketName as String;
    } catch (e) {
      debugPrint('❌ Error getting available bucket: $e');

      // إذا كانت جميع البكتات ممتلئة
      if (e.toString().contains('جميع') || e.toString().contains('ممتلئة')) {
        throw Exception(
          'جميع مساحات التخزين ممتلئة (30/30). يرجى الاتصال بالدعم الفني.',
        );
      }

      // Fallback للبكت الأول
      return 'expert_chat_images_1';
    }
  }

  /// تحديث استخدام bucket بعد رفع صورة
  static Future<void> updateExpertBucketUsage(
    String bucketName,
    int fileSizeBytes,
  ) async {
    try {
      await client.rpc(
        'increment_expert_bucket_usage',
        params: {
          'bucket_name_param': bucketName,
          'file_size_bytes': fileSizeBytes,
        },
      );

      final sizeMB = (fileSizeBytes / (1024 * 1024)).toStringAsFixed(2);
      debugPrint('✅ Updated $bucketName: +$sizeMB MB');
    } catch (e) {
      debugPrint('❌ Error updating bucket usage: $e');
      // لا نرمي خطأ هنا لأنه ليس حرجاً
    }
  }

  /// الحصول على إحصائيات جميع الـ Buckets (للأدمن)
  static Future<List<Map<String, dynamic>>> getExpertBucketsStats() async {
    try {
      final response = await client
          .from('expert_buckets_summary')
          .select('*')
          .order('bucket_number', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error getting buckets stats: $e');
      return [];
    }
  }

  /// الحصول على الإحصائيات العامة للتخزين
  static Future<Map<String, dynamic>?> getExpertStorageOverallStats() async {
    try {
      final response = await client
          .from('expert_storage_stats')
          .select('*')
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('❌ Error getting overall storage stats: $e');
      return null;
    }
  }

  /// الحصول على آخر إشعارات التخزين (للأدمن)
  static Future<List<Map<String, dynamic>>> getStorageNotifications({
    int limit = 20,
  }) async {
    try {
      final response = await client
          .from('admin_notifications')
          .select('*')
          .inFilter('type', ['storage_bucket_switch', 'storage_critical'])
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error getting storage notifications: $e');
      return [];
    }
  }

  /// تحديث حالة قراءة إشعار الأدمن
  static Future<void> markAdminNotificationAsRead(int notificationId) async {
    try {
      await client
          .from('admin_notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      debugPrint('❌ Error marking admin notification as read: $e');
    }
  }

  /// إرسال صورة في محادثة المستشار (محدّثة مع نظام 30 Bucket)
  static Future<bool> sendAskMeImage({
    required String conversationId,
    required String senderId,
    required Uint8List imageBytes,
  }) async {
    try {
      // التحقق من صحة البيانات
      if (imageBytes.isEmpty) {
        debugPrint('⚠️ Image bytes are empty');
        return false;
      }

      // 1. الحصول على البكت المتاح (مع التبديل التلقائي إذا لزم الأمر)
      final bucketName = await getAvailableExpertChatBucket();

      debugPrint(
        '📦 Using bucket: $bucketName for conversation $conversationId',
      );

      // 2. توليد اسم ملف فريد
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final randomId = const Uuid().v4().substring(0, 8);
      final fileName = 'conv_${conversationId}_${timestamp}_$randomId.jpg';

      final fileSizeBytes = imageBytes.length;
      final sizeMB = (fileSizeBytes / (1024 * 1024)).toStringAsFixed(2);
      debugPrint('📤 Uploading: $fileName ($sizeMB MB)');

      // 3. رفع الصورة إلى البكت النشط
      await client.storage
          .from(bucketName)
          .uploadBinary(
            fileName,
            imageBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );

      debugPrint('✅ Image uploaded successfully');

      // 4. الحصول على رابط الصورة العام
      final imageUrl = client.storage.from(bucketName).getPublicUrl(fileName);

      if (imageUrl.isEmpty) {
        debugPrint('❌ Failed to get public URL');
        return false;
      }

      debugPrint('🔗 Image URL: $imageUrl');

      // 5. حفظ رسالة الصورة في قاعدة البيانات
      await client.from('ask_me_messages').insert({
        'conversation_id': conversationId,
        'sender_id': senderId,
        'message': imageUrl,
        'message_type': 'image',
        'is_read': false,
      });

      debugPrint('✅ Image message saved to database');

      // 6. تحديث استخدام البكت
      await updateExpertBucketUsage(bucketName, fileSizeBytes);

      return true;
    } on StorageException catch (e) {
      debugPrint('❌ Storage error: ${e.message}');
      return false;
    } on PostgrestException catch (e) {
      debugPrint('❌ Database error: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('❌ Unexpected error sending image: $e');
      return false;
    }
  }

  // ==================== Ask Me Voice Messages ====================

  /// إرسال رسالة صوتية في محادثة المستشار
  static Future<bool> sendAskMeVoice({
    required String conversationId,
    required String senderId,
    required Uint8List voiceBytes,
    required int duration,
  }) async {
    try {
      if (voiceBytes.isEmpty) {
        debugPrint('⚠️ Voice bytes are empty');
        return false;
      }

      // 1. الحصول على البكت المتاح
      final bucketName = await getAvailableExpertChatBucket();

      // 2. توليد اسم ملف فريد
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final randomId = const Uuid().v4().substring(0, 8);
      final fileName = 'voice_${conversationId}_${timestamp}_$randomId.mp3';

      debugPrint('🎙️ Uploading voice: $fileName');

      // 3. رفع الملف الصوتي (بدون تحديد contentType - سيُحدد تلقائياً من الامتداد)
      await client.storage.from(bucketName).uploadBinary(fileName, voiceBytes);

      // 4. الحصول على الرابط العام
      final voiceUrl = client.storage.from(bucketName).getPublicUrl(fileName);

      // 5. حفظ رسالة الصوت في قاعدة البيانات
      await client.from('ask_me_messages').insert({
        'conversation_id': conversationId,
        'sender_id': senderId,
        'message': voiceUrl,
        'message_type': 'voice',
        'voice_duration': duration,
        'is_read': false,
      });

      debugPrint('✅ Voice message sent successfully');

      // 6. تحديث استخدام البكت
      await updateExpertBucketUsage(bucketName, voiceBytes.length);

      return true;
    } catch (e) {
      debugPrint('❌ Error sending voice message: $e');
      return false;
    }
  }

  // ==================== Typing Indicator ====================

  /// تحديث حالة الكتابة
  static Future<bool> updateAskMeTypingStatus({
    required String conversationId,
    required String userId,
    required bool isTyping,
  }) async {
    try {
      await client.from('ask_me_typing').upsert({
        'conversation_id': conversationId,
        'user_id': userId,
        'is_typing': isTyping,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'conversation_id,user_id');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating typing status: $e');
      return false;
    }
  }

  /// الاستماع لتغييرات الكتابة
  static RealtimeChannel subscribeToAskMeTyping({
    required String conversationId,
    required String currentUserId,
    required void Function(bool isTyping) onTypingChanged,
  }) {
    return client
        .channel('typing_$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ask_me_typing',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            if (record.isNotEmpty && record['user_id'] != currentUserId) {
              final isTyping = record['is_typing'] as bool? ?? false;
              onTypingChanged(isTyping);
            }
          },
        )
        .subscribe();
  }

  // ==================== Message Reactions ====================

  /// إضافة رد فعل على رسالة
  static Future<bool> addAskMeReaction({
    required String messageId,
    required String userId,
    required String reaction,
  }) async {
    try {
      // التحقق من وجود رد فعل سابق وتحديثه أو إضافة جديد
      await client.from('ask_me_reactions').upsert({
        'message_id': messageId,
        'user_id': userId,
        'reaction': reaction,
      }, onConflict: 'message_id,user_id');
      return true;
    } catch (e) {
      debugPrint('❌ Error adding reaction: $e');
      return false;
    }
  }

  /// حذف رد فعل
  static Future<bool> removeAskMeReaction({
    required String messageId,
    required String userId,
  }) async {
    try {
      await client
          .from('ask_me_reactions')
          .delete()
          .eq('message_id', messageId)
          .eq('user_id', userId);
      return true;
    } catch (e) {
      debugPrint('❌ Error removing reaction: $e');
      return false;
    }
  }

  // ==================== Expert Online Status ====================

  /// جلب حالة اتصال الخبير
  static Future<Map<String, dynamic>> getExpertOnlineStatus(
    String expertId,
  ) async {
    try {
      final response = await client
          .from('users')
          .select('is_online, last_seen')
          .eq('id', expertId)
          .maybeSingle();

      return {
        'is_online': response?['is_online'] ?? false,
        'last_seen': response?['last_seen'],
      };
    } catch (e) {
      debugPrint('❌ Error getting expert status: $e');
      return {'is_online': false, 'last_seen': null};
    }
  }

  /// تحديث حالة الاتصال للمستخدم
  static Future<bool> updateUserOnlineStatus({
    required String userId,
    required bool isOnline,
  }) async {
    try {
      await client
          .from('users')
          .update({
            'is_online': isOnline,
            'last_seen': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
      return true;
    } catch (e) {
      debugPrint('❌ Error updating online status: $e');
      return false;
    }
  }

  // ==========================================
  // Maintenance Mode Functions
  // ==========================================

  /// جلب إعدادات الصيانة
  static Future<Map<String, dynamic>?> getMaintenanceSettings() async {
    try {
      final response = await client
          .from('maintenance_settings')
          .select()
          .limit(1)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('❌ Error getting maintenance settings: $e');
      return null;
    }
  }

  /// تحديث إعدادات الصيانة
  static Future<bool> updateMaintenanceSettings({
    required bool isEnabled,
    required String message,
    required List<String> excludedUserIds,
  }) async {
    try {
      // جلب الصف الأول أو إنشاؤه
      final existing = await client
          .from('maintenance_settings')
          .select('id')
          .limit(1)
          .maybeSingle();

      if (existing != null) {
        await client
            .from('maintenance_settings')
            .update({
              'is_enabled': isEnabled,
              'message': message,
              'excluded_user_ids': excludedUserIds,
            })
            .eq('id', existing['id']);
      } else {
        await client.from('maintenance_settings').insert({
          'is_enabled': isEnabled,
          'message': message,
          'excluded_user_ids': excludedUserIds,
        });
      }
      return true;
    } catch (e) {
      debugPrint('❌ Error updating maintenance settings: $e');
      return false;
    }
  }

  /// التحقق من حالة الصيانة للمستخدم
  static Future<Map<String, dynamic>> checkMaintenanceStatus(
    String userId,
  ) async {
    try {
      final settings = await getMaintenanceSettings();
      if (settings == null) {
        return {'isUnderMaintenance': false};
      }

      final isEnabled = settings['is_enabled'] == true;
      if (!isEnabled) {
        return {'isUnderMaintenance': false};
      }

      // التحقق من الاستثناء
      final excludedUserIds =
          settings['excluded_user_ids'] as List<dynamic>? ?? [];
      final isExcluded = excludedUserIds.contains(userId);

      return {
        'isUnderMaintenance': !isExcluded,
        'message': settings['message'] ?? 'التطبيق تحت الصيانة',
      };
    } catch (e) {
      debugPrint('❌ Error checking maintenance status: $e');
      return {'isUnderMaintenance': false};
    }
  }

  /// جلب قائمة المستخدمين للاختيار من بينهم
  static Future<List<Map<String, dynamic>>> getUsersForExclusion() async {
    try {
      final response = await client
          .from('users')
          .select('id, name, username, profile_image')
          .order('name', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error getting users for exclusion: $e');
      return [];
    }
  }

  /// تحديث اسم التطبيق مباشرة (بدون كلمة مرور)
  static Future<bool> updateAppNameDirect({required String newName}) async {
    try {
      // البحث عن إعداد اسم التطبيق
      final existingSettings = await client
          .from('app_settings')
          .select()
          .eq('setting_key', 'app_name')
          .maybeSingle();

      if (existingSettings != null) {
        // تحديث الاسم الموجود
        await client
            .from('app_settings')
            .update({
              'setting_value': newName,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('setting_key', 'app_name');
      } else {
        // إضافة اسم جديد
        await client.from('app_settings').insert({
          'setting_key': 'app_name',
          'setting_value': newName,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      debugPrint('✅ App name updated successfully to: $newName');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating app name: $e');
      return false;
    }
  }
}
