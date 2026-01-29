import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import '../../theme/colors.dart';
import '../../router/route_names.dart';
import '../../services/auth/auth_service.dart';
import '../../services/pet/pet_local_cache_service.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/dashed_border.dart';

/// 프로필 화면 - 반려동물 프로필 목록
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _unselectedCardColor = Color(0xFFE7E5E1);
  final _petCache = PetLocalCacheService();
  final _authService = AuthService();
  String _userName = '';
  int? _selectedPetIndex = 0;
  List<PetProfileCache> _cachedPets = [];
  bool _isLoadingPets = true;
  List<LinkedSocialAccount> _socialAccounts = [];
  bool _isLoadingSocial = true;
  bool _isLinkingSocial = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadPets(),
      _loadUserProfile(),
      _loadSocialAccounts(),
    ]);
  }

  Future<void> _loadSocialAccounts() async {
    try {
      final accounts = await _authService.getSocialAccounts();
      if (!mounted) return;
      setState(() {
        _socialAccounts = accounts;
        _isLoadingSocial = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingSocial = false);
    }
  }

  bool _isProviderLinked(String provider) {
    return _socialAccounts.any((a) => a.provider == provider);
  }

  Future<void> _handleLinkGoogle() async {
    if (_isLinkingSocial) return;
    setState(() => _isLinkingSocial = true);
    try {
      final signIn = GoogleSignIn.instance;
      final account = await signIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw Exception('idToken is null');
      await _authService.linkSocialAccount(
        provider: 'google',
        idToken: idToken,
      );
      await _loadSocialAccounts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google 계정이 연동되었습니다.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google 계정 연동에 실패했습니다.')),
      );
    } finally {
      if (mounted) setState(() => _isLinkingSocial = false);
    }
  }

  Future<void> _handleLinkApple() async {
    if (_isLinkingSocial) return;
    setState(() => _isLinkingSocial = true);
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email],
      );
      final idToken = credential.identityToken;
      if (idToken == null) throw Exception('identityToken is null');
      await _authService.linkSocialAccount(
        provider: 'apple',
        idToken: idToken,
      );
      await _loadSocialAccounts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Apple 계정이 연동되었습니다.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Apple 계정 연동에 실패했습니다.')),
      );
    } finally {
      if (mounted) setState(() => _isLinkingSocial = false);
    }
  }

  Future<void> _handleLinkKakao() async {
    if (_isLinkingSocial) return;
    setState(() => _isLinkingSocial = true);
    try {
      OAuthToken token;
      if (await isKakaoTalkInstalled()) {
        token = await UserApi.instance.loginWithKakaoTalk();
      } else {
        token = await UserApi.instance.loginWithKakaoAccount();
      }
      await _authService.linkSocialAccount(
        provider: 'kakao',
        providerId: token.accessToken,
      );
      await _loadSocialAccounts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카카오 계정이 연동되었습니다.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카카오 계정 연동에 실패했습니다.')),
      );
    } finally {
      if (mounted) setState(() => _isLinkingSocial = false);
    }
  }

  Future<void> _handleUnlinkSocial(String provider) async {
    final providerName = switch (provider) {
      'google' => 'Google',
      'apple' => 'Apple',
      'kakao' => '카카오',
      _ => provider,
    };

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '소셜 계정 연동 해제',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        content: Text(
          '$providerName 계정 연동을 해제하시겠습니까?',
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF6B6B6B),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              '취소',
              style: TextStyle(fontFamily: 'Pretendard', color: Color(0xFF97928A)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              '해제',
              style: TextStyle(
                fontFamily: 'Pretendard',
                color: Color(0xFFFF9A42),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _authService.unlinkSocialAccount(provider);
      await _loadSocialAccounts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$providerName 계정 연동이 해제되었습니다.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$providerName 계정 연동 해제에 실패했습니다.')),
      );
    }
  }

  Future<void> _loadPets() async {
    final pets = await _petCache.getPets();
    if (!mounted) return;
    setState(() {
      _cachedPets = pets;
      _isLoadingPets = false;
      if (_cachedPets.isNotEmpty) {
        _selectedPetIndex = 0;
      }
    });
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await _authService.getProfile();
      if (profile == null || !mounted) return;
      setState(() {
        _userName = profile['nickname'] as String? ?? '사용자';
      });
    } catch (_) {
      // 프로필 로드 실패 시 기본값 사용
    }
  }

  List<Map<String, dynamic>> get _displayPets {
    return _cachedPets.map(_mapCacheToDisplay).toList();
  }

  Map<String, dynamic> _mapCacheToDisplay(PetProfileCache pet) {
    return {
      'id': pet.id,
      'name': pet.name,
      'species': pet.species?.isNotEmpty == true ? pet.species! : '종 정보 없음',
      'age': _formatAge(pet.birthDate),
      'gender': pet.gender,
      'isCached': true,
    };
  }

  String _formatAge(DateTime? birthDate) {
    if (birthDate == null) return '나이 정보 없음';
    final now = DateTime.now();
    int years = now.year - birthDate.year;
    int months = now.month - birthDate.month;
    int days = now.day - birthDate.day;

    if (days < 0) {
      final prevMonth = DateTime(now.year, now.month, 0);
      days += prevMonth.day;
      months -= 1;
    }
    if (months < 0) {
      years -= 1;
      months += 12;
    }

    final segments = <String>[];
    if (years > 0) segments.add('${years}년');
    if (months > 0) segments.add('${months}개월');
    if (days > 0) segments.add('${days}일');
    return segments.isEmpty ? '0일' : segments.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 앱바
            _buildAppBar(),

            // 스크롤 가능한 컨텐츠
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 사용자 프로필 섹션
                    _buildUserProfileSection(),

                    // 구분선
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(vertical: 20),
                      color: const Color(0xFFF0F0F0),
                    ),

                    // "나의 반려가족" 타이틀
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        '나의 반려가족',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF1A1A1A),
                          height: 22 / 16,
                          letterSpacing: 0.08,
                        ),
                      ),
                    ),

                    const SizedBox(height: 7),

                    // 반려동물 프로필 카드들
                    if (_isLoadingPets)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: LinearProgressIndicator(minHeight: 2),
                      )
                    else
                      ..._displayPets.asMap().entries.map((entry) {
                        return _buildPetProfileCard(
                          index: entry.key,
                          pet: entry.value,
                        );
                      }),

                    const SizedBox(height: 12),

                    // 새로운 아이 등록하기 버튼
                    _buildAddPetButton(),

                    // 구분선
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(vertical: 20),
                      color: const Color(0xFFF0F0F0),
                    ),

                    // 소셜 계정 연동 섹션
                    _buildSocialAccountsSection(),

                    // 구분선
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(vertical: 20),
                      color: const Color(0xFFF0F0F0),
                    ),

                    // 계정 관리 섹션
                    _buildAccountManagementSection(),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: -1), // 선택 상태 없음
    );
  }

  /// 상단 앱바
  Widget _buildAppBar() {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 뒤로가기 버튼
            Positioned(
              left: 0,
              child: GestureDetector(
                onTap: () => context.goNamed(RouteNames.home),
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: SvgPicture.asset(
                    'assets/images/profile/back_arrow.svg',
                  ),
                ),
              ),
            ),

            // 제목
            Text(
              '프로필',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF1A1A1A),
                height: 34 / 20,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 사용자 프로필 섹션
  Widget _buildUserProfileSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(37, 12, 32, 0),
      child: Row(
        children: [
          // 프로필 아이콘과 편집 버튼
          GestureDetector(
            onTap: () {
              context.pushNamed(RouteNames.profileSetup);
            },
            child: SizedBox(
              width: 50,
              height: 50,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 프로필 아이콘
                  SvgPicture.asset(
                    'assets/images/profile/profile.svg',
                    width: 50,
                    height: 50,
                  ),
                  // 편집 아이콘
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.brandPrimary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/images/profile/edit.svg',
                          width: 10,
                          height: 10,
                          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 16),

          // 사용자 이름
          Text(
            _userName.isEmpty ? '사용자' : '$_userName님',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1A1A1A),
              height: 22 / 16,
              letterSpacing: 0.08,
            ),
          ),
        ],
      ),
    );
  }

  /// 반려동물 프로필 카드
  Widget _buildPetProfileCard({
    required int index,
    required Map<String, dynamic> pet,
  }) {
    final isSelected = index == _selectedPetIndex;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPetIndex = index;
        });
        final petId = pet['id'] as String?;
        if (petId != null) {
          _petCache.setActivePetId(petId);
        }
      },
      child: Container(
        height: 120,
        margin: const EdgeInsets.fromLTRB(32, 0, 32, 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF5ED) : _unselectedCardColor,
          border: Border.all(
            color: isSelected ? AppColors.brandPrimary : Colors.transparent,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // 프로필 이미지
            SvgPicture.asset(
              'assets/images/profile/pet_profile_placeholder.svg',
              width: 62.64,
              height: 62.64,
            ),

            const SizedBox(width: 15),

            // 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 이름과 성별
                  Row(
                    children: [
                      Text(
                        pet['name'],
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF1A1A1A),
                          height: 22 / 16,
                          letterSpacing: 0.08,
                        ),
                      ),
                      const SizedBox(width: 1),
                      if (pet['gender'] == 'male' ||
                          pet['gender'] == 'female')
                        SvgPicture.asset(
                          pet['gender'] == 'male'
                              ? 'assets/images/profile/gender_male.svg'
                              : 'assets/images/profile/gender_female.svg',
                          width: 20,
                          height: 20,
                        )
                      else
                        const SizedBox(width: 20, height: 20),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // 종
                  Text(
                    pet['species'],
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6B6B6B),
                      height: 22 / 12,
                      letterSpacing: 0.06,
                    ),
                  ),

                  // 나이
                  Text(
                    pet['age'],
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6B6B6B),
                      height: 22 / 12,
                      letterSpacing: 0.06,
                    ),
                  ),
                ],
              ),
            ),

            // 편집 아이콘
            GestureDetector(
              onTap: () async {
                await context.pushNamed(RouteNames.petProfileDetail);
                await _loadPets();
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.brandPrimary : const Color(0xFF97928A),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: SvgPicture.asset(
                    'assets/images/profile/edit.svg',
                    width: 14,
                    height: 14,
                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 소셜 계정 연동 관리 섹션
  Widget _buildSocialAccountsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '소셜 계정 연동',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1A1A1A),
              height: 22 / 16,
              letterSpacing: 0.08,
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoadingSocial)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else ...[
            _buildSocialAccountRow(
              provider: 'kakao',
              label: '카카오',
              icon: SvgPicture.asset(
                'assets/images/btn_kakao/btn_kakao.svg',
                width: 24,
                height: 24,
              ),
              isLinked: _isProviderLinked('kakao'),
              onLink: _handleLinkKakao,
              onUnlink: () => _handleUnlinkSocial('kakao'),
            ),
            const SizedBox(height: 8),
            _buildSocialAccountRow(
              provider: 'google',
              label: 'Google',
              icon: SvgPicture.asset(
                'assets/images/btn_google/btn_google.svg',
                width: 24,
                height: 24,
              ),
              isLinked: _isProviderLinked('google'),
              onLink: _handleLinkGoogle,
              onUnlink: () => _handleUnlinkSocial('google'),
            ),
            const SizedBox(height: 8),
            _buildSocialAccountRow(
              provider: 'apple',
              label: 'Apple',
              icon: const Icon(Icons.apple, size: 24, color: Colors.black),
              isLinked: _isProviderLinked('apple'),
              onLink: _handleLinkApple,
              onUnlink: () => _handleUnlinkSocial('apple'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSocialAccountRow({
    required String provider,
    required String label,
    required Widget icon,
    required bool isLinked,
    required VoidCallback onLink,
    required VoidCallback onUnlink,
  }) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(
          color: isLinked ? AppColors.brandPrimary : const Color(0xFFE7E5E1),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color: isLinked ? const Color(0xFFFFF5ED) : Colors.white,
      ),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF1A1A1A),
              ),
            ),
          ),
          GestureDetector(
            onTap: _isLinkingSocial ? null : (isLinked ? onUnlink : onLink),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isLinked ? Colors.white : AppColors.brandPrimary,
                borderRadius: BorderRadius.circular(8),
                border: isLinked
                    ? Border.all(color: const Color(0xFFE7E5E1))
                    : null,
              ),
              child: Text(
                isLinked ? '해제' : '연동',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isLinked ? const Color(0xFF97928A) : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 로그아웃 처리
  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '로그아웃',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        content: const Text(
          '로그아웃 하시겠습니까?',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF6B6B6B),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              '취소',
              style: TextStyle(fontFamily: 'Pretendard', color: Color(0xFF97928A)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              '로그아웃',
              style: TextStyle(
                fontFamily: 'Pretendard',
                color: Color(0xFFFF9A42),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    await _authService.signOut();
    if (!mounted) return;
    context.goNamed(RouteNames.login);
  }

  /// 회원 탈퇴 처리
  Future<void> _handleDeleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '회원 탈퇴',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        content: const Text(
          '탈퇴하시면 모든 데이터가 삭제되며 복구할 수 없습니다.\n정말 탈퇴하시겠습니까?',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF6B6B6B),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              '취소',
              style: TextStyle(fontFamily: 'Pretendard', color: Color(0xFF97928A)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              '탈퇴',
              style: TextStyle(
                fontFamily: 'Pretendard',
                color: Color(0xFFE53935),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await _authService.deleteAccount();
      if (!mounted) return;
      context.goNamed(RouteNames.login);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원 탈퇴에 실패했습니다. 다시 시도해주세요.')),
      );
    }
  }

  /// 계정 관리 섹션 (로그아웃 + 회원 탈퇴)
  Widget _buildAccountManagementSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '계정 관리',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1A1A1A),
              height: 22 / 16,
              letterSpacing: 0.08,
            ),
          ),
          const SizedBox(height: 12),
          // 로그아웃 버튼
          GestureDetector(
            onTap: _handleLogout,
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE7E5E1)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  '로그아웃',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B6B6B),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 회원 탈퇴 버튼
          GestureDetector(
            onTap: _handleDeleteAccount,
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE7E5E1)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  '회원 탈퇴',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFE53935),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 새로운 아이 등록하기 버튼
  Widget _buildAddPetButton() {
    return GestureDetector(
      onTap: () async {
        await context.pushNamed(RouteNames.petProfileDetail);
        await _loadPets();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        child: DashedBorder(
          color: const Color(0xFF97928A),
          radius: 16,
          strokeWidth: 1,
          dashWidth: 6,
          dashGap: 6,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 플러스 아이콘
                Container(
                  width: 14.15,
                  height: 14.15,
                  decoration: const BoxDecoration(
                    color: Color(0xFF97928A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add,
                    size: 10,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(width: 8),

                // 텍스트
                Text(
                  '새로운 아이 등록하기',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF97928A),
                    height: 34 / 16,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
