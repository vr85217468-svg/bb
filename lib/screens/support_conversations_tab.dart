import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'admin_support_chat_screen.dart';

class SupportConversationsTab extends StatefulWidget {
  const SupportConversationsTab({super.key});

  @override
  State<SupportConversationsTab> createState() =>
      _SupportConversationsTabState();
}

class _SupportConversationsTabState extends State<SupportConversationsTab> {
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);
    try {
      final conversations = await SupabaseService.getAllSupportConversations();
      final unreadCount = await SupabaseService.getTotalUnreadAdminCount();

      if (mounted) {
        setState(() {
          _conversations = conversations;
          _unreadCount = unreadCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black, const Color(0xFF0a0a0a)],
        ),
      ),
      child: Column(
        children: [
          // Header مع عداد الرسائل
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF8B0000).withValues(alpha: 0.3),
                  const Color(0xFF1a1a1a),
                  const Color(0xFFD4AF37).withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                  blurRadius: 15,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B0000), Color(0xFFD4AF37)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.support_agent_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'محادثات الدعم',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_conversations.length} محادثة',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_unreadCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF0000), Color(0xFF8B0000)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF0000).withValues(alpha: 0.4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Text(
                      '$_unreadCount جديد',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.refresh,
                      color: Color(0xFFD4AF37),
                      size: 20,
                    ),
                  ),
                  onPressed: _loadConversations,
                ),
              ],
            ),
          ),
          // قائمة المحادثات
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
                  )
                : _conversations.isEmpty
                ? _buildEmptyState()
                : _buildConversationsList(),
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
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFD4AF37).withValues(alpha: 0.2),
                  Colors.transparent,
                ],
              ),
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'لا توجد محادثات بعد',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ستظهر المحادثات هنا عندما يتواصل المستخدمون',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _conversations.length,
      itemBuilder: (context, index) {
        final conversation = _conversations[index];
        final user = conversation['user'];
        final unreadCount = conversation['unread_admin_count'] ?? 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1a1a1a),
                Colors.black,
                unreadCount > 0
                    ? const Color(0xFF8B0000).withValues(alpha: 0.2)
                    : const Color(0xFFD4AF37).withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: unreadCount > 0
                  ? const Color(0xFFFF0000).withValues(alpha: 0.4)
                  : const Color(0xFFD4AF37).withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              if (unreadCount > 0)
                BoxShadow(
                  color: const Color(0xFFFF0000).withValues(alpha: 0.2),
                  blurRadius: 10,
                ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminSupportChatScreen(user: user),
                  ),
                );
                _loadConversations(); // تحديث بعد العودة
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [const Color(0xFF1a1a1a), Colors.black],
                        ),
                        border: Border.all(
                          color: unreadCount > 0
                              ? const Color(0xFFFF0000)
                              : const Color(0xFFD4AF37),
                          width: 2.5,
                        ),
                        image: user['profile_image'] != null
                            ? DecorationImage(
                                image: NetworkImage(user['profile_image']),
                                fit: BoxFit.cover,
                              )
                            : null,
                        boxShadow: [
                          if (unreadCount > 0)
                            BoxShadow(
                              color: const Color(0xFFFF0000).withValues(alpha: 0.3),
                              blurRadius: 10,
                            ),
                        ],
                      ),
                      child: user['profile_image'] == null
                          ? Icon(
                              Icons.person,
                              color: unreadCount > 0
                                  ? const Color(0xFFFF0000)
                                  : const Color(0xFFD4AF37),
                              size: 28,
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user['name'] ?? 'مستخدم',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '@${user['username'] ?? ''}',
                            style: TextStyle(
                              color: const Color(0xFFD4AF37).withValues(alpha: 0.7),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (unreadCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF0000), Color(0xFF8B0000)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF0000).withValues(alpha: 0.4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.6),
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
