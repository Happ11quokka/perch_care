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
import '../../services/pet/pet_service.dart';
import '../../services/pet/active_pet_notifier.dart';
import '../../data/terms_content.dart';
import '../../widgets/dashed_border.dart';
import '../../widgets/local_image_avatar.dart';
import '../../services/storage/local_image_storage_service.dart';
import '../../services/api/token_service.dart';
import '../../widgets/app_snack_bar.dart';
import '../../providers/locale_provider.dart';
import '../../../l10n/app_localizations.dart';

/// 프로필 화면 - 반려동물 프로필 목록
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _unselectedCardColor = Color(0xFFE7E5E1);
  final _petCache = PetLocalCacheService.instance;
  final _petService = PetService.instance;
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
      final l10n = AppLocalizations.of(context);
      AppSnackBar.success(context, message: l10n.snackbar_googleLinked);
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      AppSnackBar.error(context, message: l10n.error_linkGoogle);
    } finally {
      if (mounted) setState(() => _isLinkingSocial = false);
    }
  }

  Future<void> _handleLinkApple() async {
    if (_isLinkingSocial) return;
    setState(() => _isLinkingSocial = true);
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final idToken = credential.identityToken;
      if (idToken == null) throw Exception('identityToken is null');
      await _authService.linkSocialAccount(
        provider: 'apple',
        idToken: idToken,
        providerId: credential.userIdentifier,
        providerEmail: credential.email,
      );
      await _loadSocialAccounts();
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      AppSnackBar.success(context, message: l10n.snackbar_appleLinked);
    } catch (e) {
      if (!mounted) return;
      debugPrint('Apple Link Error: $e');
      final l10n = AppLocalizations.of(context);
      AppSnackBar.error(context, message: l10n.error_linkApple);
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
        accessToken: token.accessToken,
      );
      await _loadSocialAccounts();
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      AppSnackBar.success(context, message: l10n.snackbar_kakaoLinked);
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      AppSnackBar.error(context, message: l10n.error_linkKakao);
    } finally {
      if (mounted) setState(() => _isLinkingSocial = false);
    }
  }

  Future<void> _handleUnlinkSocial(String provider) async {
    final l10n = AppLocalizations.of(context);
    final providerName = switch (provider) {
      'google' => l10n.social_google,
      'apple' => l10n.social_apple,
      'kakao' => l10n.social_kakao,
      _ => provider,
    };

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n.dialog_unlinkTitle,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        content: Text(
          l10n.dialog_unlinkContent(providerName),
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
            child: Text(
              l10n.common_cancel,
              style: const TextStyle(fontFamily: 'Pretendard', color: Color(0xFF97928A)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              l10n.profile_unlink,
              style: const TextStyle(
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
      AppSnackBar.success(context, message: l10n.snackbar_unlinked(providerName));
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.error(context, message: l10n.error_unlinkFailed(providerName));
    }
  }

  Future<void> _loadPets() async {
    try {
      // API에서 펫 목록 조회 (UUID 형식 보장)
      final apiPets = await _petService.getMyPets();
      if (!mounted) return;

      for (final pet in apiPets) {
        await _petCache.upsertPet(
          PetProfileCache(
            id: pet.id,
            name: pet.name,
            species: pet.breed,
            gender: pet.gender,
            birthDate: pet.birthDate,
          ),
          setActive: false,
        );
      }

      final activePet = await _petService.getActivePet();
      if (activePet != null) {
        await _petCache.setActivePetId(activePet.id);
      }

      final cachedPets = await _petCache.getPets();
      if (!mounted) return;
      setState(() {
        _cachedPets = cachedPets;
        _isLoadingPets = false;
        // 활성 펫의 인덱스를 찾아서 선택
        if (activePet != null) {
          final idx = _cachedPets.indexWhere((p) => p.id == activePet.id);
          _selectedPetIndex = idx >= 0 ? idx : 0;
        } else if (_cachedPets.isNotEmpty) {
          _selectedPetIndex = 0;
        }
      });
    } catch (_) {
      // API 실패 시 로컬 캐시 폴백
      final pets = await _petCache.getPets();
      final cachedActive = await _petCache.getActivePet();
      if (!mounted) return;
      setState(() {
        _cachedPets = pets;
        _isLoadingPets = false;
        if (cachedActive != null) {
          final idx = _cachedPets.indexWhere((p) => p.id == cachedActive.id);
          _selectedPetIndex = idx >= 0 ? idx : 0;
        } else if (_cachedPets.isNotEmpty) {
          _selectedPetIndex = 0;
        }
      });
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await _authService.getProfile();
      if (profile == null || !mounted) return;
      setState(() {
        _userName = profile['nickname'] as String? ?? '';
      });
    } catch (_) {
      // 프로필 로드 실패 시 기본값 사용
    }
  }

  List<Map<String, dynamic>> _getDisplayPets(AppLocalizations l10n) {
    return _cachedPets.map((pet) => _mapCacheToDisplay(pet, l10n)).toList();
  }

  Map<String, dynamic> _mapCacheToDisplay(PetProfileCache pet, AppLocalizations l10n) {
    return {
      'id': pet.id,
      'name': pet.name,
      'species': pet.species?.isNotEmpty == true ? pet.species! : l10n.profile_noSpecies,
      'age': _formatAge(pet.birthDate, l10n),
      'gender': pet.gender,
      'isCached': true,
    };
  }

  String _formatAge(DateTime? birthDate, AppLocalizations l10n) {
    if (birthDate == null) return l10n.profile_noAge;
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

    return l10n.profile_ageFormat(years, months, days);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final displayPets = _getDisplayPets(l10n);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 앱바
            _buildAppBar(l10n),

            // 스크롤 가능한 컨텐츠
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 사용자 프로필 섹션
                    _buildUserProfileSection(l10n),

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
                        l10n.profile_myPets,
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
                      ...displayPets.asMap().entries.map((entry) {
                        return _buildPetProfileCard(
                          index: entry.key,
                          pet: entry.value,
                        );
                      }),

                    const SizedBox(height: 12),

                    // 새로운 아이 등록하기 버튼
                    _buildAddPetButton(l10n),

                    // 구분선
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(vertical: 20),
                      color: const Color(0xFFF0F0F0),
                    ),

                    // 소셜 계정 연동 섹션
                    _buildSocialAccountsSection(l10n),

                    // 구분선
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(vertical: 20),
                      color: const Color(0xFFF0F0F0),
                    ),

                    // 언어 설정 섹션
                    _buildLanguageSection(l10n),

                    // 구분선
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(vertical: 20),
                      color: const Color(0xFFF0F0F0),
                    ),

                    // 약관 및 정책 섹션
                    _buildTermsPolicySection(l10n),

                    // 구분선
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(vertical: 20),
                      color: const Color(0xFFF0F0F0),
                    ),

                    // 계정 관리 섹션
                    _buildAccountManagementSection(l10n),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 언어 설정 섹션
  Widget _buildLanguageSection(AppLocalizations l10n) {
    final currentLocale = LocaleProvider.instance.currentLanguageCode;
    final displayName = currentLocale != null
        ? LocaleProvider.getDisplayName(currentLocale)
        : l10n.profile_deviceDefault;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.profile_languageSettings,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A1A),
              height: 22 / 16,
              letterSpacing: 0.08,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _showLanguageDialog(l10n),
            child: Container(
              width: double.infinity,
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE7E5E1)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.language,
                    size: 20,
                    color: Color(0xFF6B6B6B),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      displayName,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: Color(0xFF97928A),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 언어 선택 다이얼로그
  Future<void> _showLanguageDialog(AppLocalizations l10n) async {
    final currentLocale = LocaleProvider.instance.currentLanguageCode;

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n.profile_languageSelect,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 기기 설정 옵션
            _buildLanguageOption(
              dialogContext: dialogContext,
              label: l10n.profile_deviceDefault,
              subtitle: l10n.profile_deviceDefaultSubtitle,
              isSelected: currentLocale == null,
              onTap: () async {
                await LocaleProvider.instance.setLocale(null);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                setState(() {});
              },
            ),
            const Divider(height: 1),
            // 한국어
            _buildLanguageOption(
              dialogContext: dialogContext,
              label: '한국어',
              isSelected: currentLocale == 'ko',
              onTap: () async {
                await LocaleProvider.instance.setLocale(const Locale('ko'));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                setState(() {});
              },
            ),
            const Divider(height: 1),
            // English
            _buildLanguageOption(
              dialogContext: dialogContext,
              label: 'English',
              isSelected: currentLocale == 'en',
              onTap: () async {
                await LocaleProvider.instance.setLocale(const Locale('en'));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                setState(() {});
              },
            ),
            const Divider(height: 1),
            // 中文
            _buildLanguageOption(
              dialogContext: dialogContext,
              label: '中文',
              isSelected: currentLocale == 'zh',
              onTap: () async {
                await LocaleProvider.instance.setLocale(const Locale('zh'));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption({
    required BuildContext dialogContext,
    required String label,
    String? subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? AppColors.brandPrimary : const Color(0xFF1A1A1A),
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF97928A),
                      ),
                    ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check,
                size: 20,
                color: AppColors.brandPrimary,
              ),
          ],
        ),
      ),
    );
  }

  /// 약관 및 정책 섹션
  Widget _buildTermsPolicySection(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.terms_sectionTitle,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A1A),
              height: 22 / 16,
              letterSpacing: 0.08,
            ),
          ),
          const SizedBox(height: 12),
          _buildTermsRow(
            label: l10n.terms_termsOfService,
            onTap: () => context.pushNamed(
              RouteNames.termsDetail,
              extra: TermsType.termsOfService,
            ),
          ),
          const SizedBox(height: 8),
          _buildTermsRow(
            label: l10n.terms_privacyPolicy,
            onTap: () => context.pushNamed(
              RouteNames.termsDetail,
              extra: TermsType.privacyPolicy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsRow({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE7E5E1)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: Color(0xFF97928A),
            ),
          ],
        ),
      ),
    );
  }

  /// 상단 앱바
  Widget _buildAppBar(AppLocalizations l10n) {
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
                onTap: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.goNamed(RouteNames.home);
                  }
                },
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
              l10n.profile_title,
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
  Widget _buildUserProfileSection(AppLocalizations l10n) {
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
                  if (TokenService.instance.userId != null)
                    LocalImageAvatar(
                      ownerType: ImageOwnerType.userProfile,
                      ownerId: TokenService.instance.userId!,
                      size: 50,
                      placeholder: SvgPicture.asset(
                        'assets/images/profile/profile.svg',
                        width: 50,
                        height: 50,
                      ),
                    )
                  else
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
            _userName.isEmpty
                ? l10n.profile_user
                : '$_userName${l10n.profile_userSuffix}',
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
      onTap: () async {
        setState(() {
          _selectedPetIndex = index;
        });
        final petId = pet['id'] as String?;
        if (petId != null) {
          _petCache.setActivePetId(petId);
          // 서버에 활성 펫 변경 저장
          try {
            await _petService.setActivePet(petId);
          } catch (_) {}
          // 서버 저장 후 다른 화면에 알림
          ActivePetNotifier.instance.notify(petId);
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
            LocalImageAvatar(
              ownerType: ImageOwnerType.petProfile,
              ownerId: pet['id'] as String? ?? '',
              size: 62.64,
              placeholder: SvgPicture.asset(
                'assets/images/profile/pet_profile_placeholder.svg',
                width: 62.64,
                height: 62.64,
              ),
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
  Widget _buildSocialAccountsSection(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.profile_socialAccounts,
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
              label: l10n.social_kakao,
              icon: SvgPicture.asset(
                'assets/images/btn_kakao/btn_kakao.svg',
                width: 24,
                height: 24,
              ),
              isLinked: _isProviderLinked('kakao'),
              onLink: _handleLinkKakao,
              onUnlink: () => _handleUnlinkSocial('kakao'),
              l10n: l10n,
            ),
            const SizedBox(height: 8),
            _buildSocialAccountRow(
              provider: 'google',
              label: l10n.social_google,
              icon: SvgPicture.asset(
                'assets/images/btn_google/btn_google.svg',
                width: 24,
                height: 24,
              ),
              isLinked: _isProviderLinked('google'),
              onLink: _handleLinkGoogle,
              onUnlink: () => _handleUnlinkSocial('google'),
              l10n: l10n,
            ),
            const SizedBox(height: 8),
            _buildSocialAccountRow(
              provider: 'apple',
              label: l10n.social_apple,
              icon: const Icon(Icons.apple, size: 24, color: Colors.black),
              isLinked: _isProviderLinked('apple'),
              onLink: _handleLinkApple,
              onUnlink: () => _handleUnlinkSocial('apple'),
              l10n: l10n,
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
    required AppLocalizations l10n,
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
                isLinked ? l10n.profile_unlink : l10n.profile_link,
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
  Future<void> _handleLogout(AppLocalizations l10n) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n.dialog_logoutTitle,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        content: Text(
          l10n.dialog_logoutContent,
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
            child: Text(
              l10n.common_cancel,
              style: const TextStyle(fontFamily: 'Pretendard', color: Color(0xFF97928A)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              l10n.profile_logout,
              style: const TextStyle(
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
  Future<void> _handleDeleteAccount(AppLocalizations l10n) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n.dialog_deleteAccountTitle,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        content: Text(
          l10n.dialog_deleteAccountContent,
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
            child: Text(
              l10n.common_cancel,
              style: const TextStyle(fontFamily: 'Pretendard', color: Color(0xFF97928A)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              l10n.dialog_delete,
              style: const TextStyle(
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
      AppSnackBar.error(context, message: l10n.error_deleteAccount);
    }
  }

  /// 계정 관리 섹션 (로그아웃 + 회원 탈퇴)
  Widget _buildAccountManagementSection(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.profile_accountManagement,
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
            onTap: () => _handleLogout(l10n),
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE7E5E1)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  l10n.profile_logout,
                  style: const TextStyle(
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
            onTap: () => _handleDeleteAccount(l10n),
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE7E5E1)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  l10n.profile_deleteAccount,
                  style: const TextStyle(
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
  Widget _buildAddPetButton(AppLocalizations l10n) {
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
                  l10n.profile_addNewPet,
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
