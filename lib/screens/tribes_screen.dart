import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';
import '../services/guest_mode_service.dart';
import '../theme/app_theme.dart';
import 'create_tribe_screen.dart';
import 'tribe_info_screen.dart';
import 'tribe_chat_screen.dart';

enum TribesView { listing, info, chat }

/// شاشة القبائل الرئيسية 🏰
class TribesScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const TribesScreen({super.key, required this.user});

  @override
  State<TribesScreen> createState() => _TribesScreenState();
}

class _TribesScreenState extends State<TribesScreen> {
  List<Map<String, dynamic>> _publicTribes = [];
  List<Map<String, dynamic>> _myTribes = [];
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  // إدارة التنقل الداخلي ✨
  TribesView _currentView = TribesView.listing;
  String? _activeTribeId;
  Map<String, dynamic>? _selectedTribeData;

  @override
  void initState() {
    super.initState();
    _cleanupLegacyData(); // مسح البيانات القديمة أولاً
    _restoreView();
    _loadData();
  }

  /// مسح البيانات القديمة التي تم حفظها بدون معرف المستخدم
  Future<void> _cleanupLegacyData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // مسح المفتاح القديم 'active_tribe_id' الذي لا يحتوي على معرف المستخدم
      if (prefs.containsKey('active_tribe_id')) {
        await prefs.remove('active_tribe_id');
        debugPrint('🧹 Cleaned up legacy tribe data');
      }
    } catch (e) {
      debugPrint('❌ Error cleaning legacy data: $e');
    }
  }

  /// استعادة الحالة المحفوظة (آخر قبيلة تم فتحها) - مع عزل لكل مستخدم
  Future<void> _restoreView() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = widget.user['id'];

      // استخدام مفتاح خاص بكل مستخدم لعزل البيانات
      final savedTribeId = prefs.getString('active_tribe_id_$userId');

      if (savedTribeId != null) {
        // إذا كانت هناك قبيلة محفوظة، نحاول جلب بياناتها
        final tribeData = await SupabaseService.getTribeData(savedTribeId);

        if (tribeData != null && mounted) {
          // التحقق الإضافي: هل المستخدم عضو في هذه القبيلة؟
          final isMember = await SupabaseService.isUserTribeMember(
            userId: userId,
            tribeId: savedTribeId,
          );

          if (isMember) {
            setState(() {
              _activeTribeId = savedTribeId;
              _selectedTribeData = tribeData;
              _currentView = TribesView.chat;
            });
          } else {
            // إذا لم يعد المستخدم عضواً، امسح البيانات المحفوظة
            await prefs.remove('active_tribe_id_$userId');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error restoring view: $e');
    }
  }

  /// حفظ الحالة الحالية - مع عزل لكل مستخدم
  Future<void> _saveViewState(String? tribeId, TribesView view) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = widget.user['id'];

      if (tribeId != null && view == TribesView.chat) {
        // حفظ البيانات بمفتاح خاص بالمستخدم
        await prefs.setString('active_tribe_id_$userId', tribeId);
      } else {
        await prefs.remove('active_tribe_id_$userId');
      }
    } catch (e) {
      debugPrint('❌ Error saving view state: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final publicTribes = await SupabaseService.getPublicTribes();

      List<Map<String, dynamic>> myTribes = [];

      // فقط جلب قبائل المستخدم إذا لم يكن زائراً
      if (widget.user['id'] != 'guest') {
        final myTribesData = await SupabaseService.getUserTribes(
          widget.user['id'],
        );

        // معالجة بيانات قبائل المستخدم لاستخراج معلومات القبيلة
        myTribes = myTribesData
            .map((m) {
              // دعم كلا المفتاحين (tribe و tribes) لتجنب الأخطاء
              final tribeData = m['tribe'] ?? m['tribes'];
              if (tribeData == null) return null;

              final tribe = Map<String, dynamic>.from(tribeData);
              return {
                ...tribe,
                'is_leader': m['is_leader'],
                'member_count':
                    m['tribe_member_count'] ?? 0, // استخدام العدد الذي جلبناه
              };
            })
            .whereType<Map<String, dynamic>>()
            .toList();
      }

      if (mounted) {
        // تصفية القبائل العامة لاستبعاد تلك التي انضم إليها المستخدم بالفعل
        final myTribeIds = myTribes.map((t) => t['id'] as String).toSet();
        final filteredPublicTribes = publicTribes
            .where((t) => !myTribeIds.contains(t['id']))
            .toList();

        setState(() {
          _publicTribes = filteredPublicTribes;
          _myTribes = myTribes;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ TribesScreen _loadData error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _searchTribes(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    final results = await SupabaseService.searchTribes(query);

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_activeTribeId != null) {
      debugPrint('🏰 Persistent active tribe: $_activeTribeId');
    }
    // العودة للاحتفاظ بالشريط السفلي: التنقل الداخلي بدل Navigator.push
    switch (_currentView) {
      case TribesView.chat:
        if (_selectedTribeData != null) {
          return TribeChatScreen(
            tribe: _selectedTribeData!,
            user: widget.user,
            onBack: () {
              setState(() => _currentView = TribesView.listing);
              _saveViewState(null, TribesView.listing);
              _loadData(); // تحديث القائمة عند العودة
            },
          );
        }
        break;
      case TribesView.info:
        if (_selectedTribeData != null) {
          return TribeInfoScreen(
            tribeId: _selectedTribeData!['id'],
            user: widget.user,
            onBack: () {
              setState(() => _currentView = TribesView.listing);
              _loadData(); // تحديث القائمة عند العودة
            },
            onJoined: (tribe) {
              setState(() {
                _selectedTribeData = tribe;
                _currentView = TribesView.chat;
                _activeTribeId = tribe['id'];
                _saveViewState(tribe['id'], TribesView.chat);
              });
            },
          );
        }
        break;
      case TribesView.listing:
        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(),

                // Search bar
                _buildSearchBar(),

                // Content
                Expanded(child: _buildContent()),
              ],
            ),
          ),
          floatingActionButton: _buildCreateButton(),
        );
    }
    // حالة احتياطية إذا فشل شيء ما
    return Scaffold(
      backgroundColor: Colors.black,
      body: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 50, 24, 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF630000).withValues(alpha: 0.4),
            const Color(0xFF2A0000).withValues(alpha: 0.1),
            Colors.black,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Color(0xFFFFD700),
                            Color(0xFFFFA500),
                            Color(0xFFFF4500),
                          ],
                        ).createShader(bounds),
                        child: const Text(
                          'القبائل',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Tajawal',
                            letterSpacing: -1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFFFD700,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(
                              0xFFFFD700,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Text(
                          'الملكية',
                          style: TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'حيث يصنع التاريخ ويسود الملوك',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.2),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              _buildHeaderIcon(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIcon() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.1),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(Icons.fort_rounded, color: Color(0xFFFFD700), size: 26),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          TextField(
            controller: _searchController,
            onChanged: _searchTribes,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'ابحث عن مجلسك...',
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true,
              fillColor: const Color(0xFF0F0F0F),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withAlpha(10)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppTheme.accentSilverGold.withAlpha(100),
                ),
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppTheme.accentSilverGold,
                size: 20,
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            Positioned(
              left: 10,
              child: IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white38,
                  size: 18,
                ),
                onPressed: () {
                  _searchController.clear();
                  _searchTribes('');
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accentSilverGold),
      );
    }

    // نتائج البحث
    if (_searchController.text.isNotEmpty) {
      return _buildSearchResults();
    }

    // عرض القائمة الرئيسية
    return _buildExploreTab();
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accentSilverGold),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Text('🔍', style: TextStyle(fontSize: 48)),
            ),
            const SizedBox(height: 16),
            const Text(
              'لا توجد نتائج',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'جرّب البحث بالرمز أو الاسم الرسمي',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _searchTribes(_searchController.text),
      color: const Color(0xFF6B5CE7),
      child: ShaderMask(
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
            stops: [0.0, 0.05, 0.95, 1.0],
          ).createShader(rect);
        },
        blendMode: BlendMode.dstIn,
        child: ListView.builder(
          padding: const EdgeInsets.all(20),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ), // ✅ تمرير سلس
          cacheExtent: 1500, // ✅ تحسين الأداء
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          itemCount: _searchResults.length,
          itemBuilder: (context, index) {
            return RepaintBoundary(
              child: _buildTribeCard(_searchResults[index]),
            );
          },
        ),
      ),
    );
  }

  Widget _buildExploreTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFFFFD700),
      backgroundColor: const Color(0xFF1A0000),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // My Tribes Section
            if (_myTribes.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(28, 20, 24, 15),
                child: Text(
                  'مجالسي',
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Tajawal',
                    letterSpacing: 1,
                  ),
                ),
              ),
              ..._myTribes.map((tribe) => _buildTribeCard(tribe)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: Divider(color: Colors.white10),
              ),
            ],

            // Exploration Section
            const Padding(
              padding: EdgeInsets.fromLTRB(28, 20, 24, 15),
              child: Text(
                'استكشاف المجالس',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Tajawal',
                ),
              ),
            ),

            if (_publicTribes.isEmpty && _myTribes.isEmpty)
              _buildEmptyDiscovery()
            else
              ..._publicTribes.map((tribe) => _buildTribeCard(tribe)),

            const SizedBox(height: 100), // Space for FAB
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyDiscovery() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 40),
          const Text('🌍', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          const Text(
            'لا توجد مجالس عامة متاحة',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'بادر بتأسيس أول مجلس رسمي!',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildTribeCard(Map<String, dynamic> tribe) {
    final memberCount = tribe['member_count'] ?? 0;
    final maxMembers = tribe['max_members'] ?? 12;
    final isPrivate = tribe['is_private'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 18, left: 24, right: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF121212).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.18),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openTribe(tribe),
            splashColor: const Color(0xFFFFD700).withValues(alpha: 0.05),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icon Wrapper with Gradient Shadow
                  _buildTribeCardIcon(tribe['icon']),
                  const SizedBox(width: 16),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                tribe['name'] ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Tajawal',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Member Badge
                            if (_myTribes.any((t) => t['id'] == tribe['id']))
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFFFD700,
                                  ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: const Color(
                                      0xFFFFD700,
                                    ).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: const Text(
                                  'عضو',
                                  style: TextStyle(
                                    color: Color(0xFFFFD700),
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            if (isPrivate)
                              const Icon(
                                Icons.lock_rounded,
                                color: Color(0xFFFFD700),
                                size: 14,
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              tribe['tribe_code'] ?? '',
                              style: TextStyle(
                                color: const Color(
                                  0xFFFFD700,
                                ).withValues(alpha: 0.6),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                              ),
                            ),
                            const Spacer(),
                            _buildMemberCount(memberCount, maxMembers),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white24,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTribeCardIcon(String? icon) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF1E1E1E), const Color(0xFF0A0A0A)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.04),
          width: 1,
        ),
      ),
      child: Center(
        child: Text(icon ?? '⚔️', style: const TextStyle(fontSize: 32)),
      ),
    );
  }

  Widget _buildMemberCount(int count, int max) {
    return Row(
      children: [
        Icon(
          Icons.people_alt_rounded,
          color: Colors.white.withValues(alpha: 0.4),
          size: 13,
        ),
        const SizedBox(width: 4),
        Text(
          '$count/$max',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCreateButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF8B0000), Color(0xFFFF0000)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF0000).withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () async {
          // ✅ تطبيق قيود الزائر
          final canCreate = await GuestModeService.requireLogin(
            context,
            'إنشاء القبائل',
          );
          if (!canCreate || !mounted) return;

          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateTribeScreen(user: widget.user),
            ),
          );

          if (result != null) {
            await _loadData();
            if (result is Map<String, dynamic>) {
              _openTribe(result);
            }
          }
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        icon: const Icon(Icons.add_moderator_rounded, color: Colors.white),
        label: const Text(
          'تأسيس مجلس',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }

  void _openTribe(Map<String, dynamic> tribe) async {
    // ✅ تطبيق قيود الزائر
    final canAccess = await GuestModeService.requireLogin(
      context,
      'الانضمام للقبائل',
    );
    if (!canAccess) return;

    final tribeId = tribe['id'];
    debugPrint('🏰 Opening tribe: $tribeId');

    // التحقق إذا كان المستخدم عضواً بالفعل في هذه القبيلة
    final isMember = _myTribes.any((t) => t['id'] == tribeId);
    debugPrint('🏰 User is member: $isMember');

    setState(() {
      _selectedTribeData = tribe;
      _currentView = isMember ? TribesView.chat : TribesView.info;
      if (isMember) {
        _activeTribeId = tribeId;
        _saveViewState(tribeId, TribesView.chat);
      }
    });
  }
}
