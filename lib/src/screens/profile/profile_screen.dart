import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/radius.dart';
import '../../router/route_names.dart';
import '../../services/auth/auth_service.dart';
import '../../widgets/bottom_nav_bar.dart';

/// 프로필 화면
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();

  // TODO: 실제 사용자 정보로 대체 필요
  String _userName = '사용자';
  String _userEmail = 'user@example.com';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final user = _authService.currentUser;
    if (user == null) return;

    Map<String, dynamic>? profile;
    try {
      profile = await _authService.getProfile();
    } catch (_) {
      // 프로필 불러오기에 실패해도 메타데이터를 사용해 계속 진행
    }

    String? nickname;
    final profileNickname = profile?['nickname'];
    if (profileNickname is String && profileNickname.trim().isNotEmpty) {
      nickname = profileNickname;
    } else {
      final metadataNickname = user.userMetadata?['nickname'];
      if (metadataNickname is String && metadataNickname.trim().isNotEmpty) {
        nickname = metadataNickname;
      }
    }

    if (!mounted) return;
    setState(() {
      _userEmail = user.email ?? 'user@example.com';
      _userName = nickname ?? '사용자';
    });
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _authService.signOut();
        if (!mounted) return;
        context.goNamed(RouteNames.login);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그아웃 중 오류가 발생했습니다.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.nearBlack),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '프로필',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.nearBlack,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildProfileHeader(),
            const SizedBox(height: AppSpacing.lg),
            _buildAccountSection(),
            const SizedBox(height: AppSpacing.lg),
            _buildGeneralSection(),
            const SizedBox(height: AppSpacing.lg),
            _buildInfoSection(),
            const SizedBox(height: AppSpacing.xxxl),
            _buildLogoutButton(),
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 2),
    );
  }

  /// 프로필 헤더
  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 프로필 사진
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.gray200,
              border: Border.all(
                color: AppColors.brandPrimary,
                width: 3,
              ),
            ),
            child: Icon(
              Icons.person,
              size: 40,
              color: AppColors.gray500,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // 사용자명
          Text(
            _userName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.nearBlack,
            ),
          ),
          const SizedBox(height: 4),

          // 이메일
          Text(
            _userEmail,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.mediumGray,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // 프로필 수정 버튼
          OutlinedButton.icon(
            onPressed: () {
              // TODO: 프로필 수정 화면으로 이동
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('프로필 수정 기능은 준비중입니다.')),
              );
            },
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('프로필 수정'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.brandPrimary,
              side: BorderSide(color: AppColors.brandPrimary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.sm,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 계정 섹션
  Widget _buildAccountSection() {
    return _buildSection(
      title: '계정',
      items: [
        _MenuItem(
          icon: Icons.pets,
          title: '반려동물 프로필',
          onTap: () {
            context.pushNamed(RouteNames.petProfile);
          },
        ),
        _MenuItem(
          icon: Icons.account_circle_outlined,
          title: '계정 정보',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('계정 정보 기능은 준비중입니다.')),
            );
          },
        ),
        _MenuItem(
          icon: Icons.lock_outline,
          title: '비밀번호 변경',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('비밀번호 변경 기능은 준비중입니다.')),
            );
          },
        ),
        _MenuItem(
          icon: Icons.delete_outline,
          title: '회원 탈퇴',
          textColor: AppColors.error,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('회원 탈퇴 기능은 준비중입니다.')),
            );
          },
        ),
      ],
    );
  }

  /// 일반 섹션
  Widget _buildGeneralSection() {
    return _buildSection(
      title: '일반',
      items: [
        _MenuItem(
          icon: Icons.notifications_outlined,
          title: '알림 설정',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('알림 설정 기능은 준비중입니다.')),
            );
          },
        ),
        _MenuItem(
          icon: Icons.language_outlined,
          title: '언어 설정',
          trailing: const Text(
            '한국어',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.mediumGray,
            ),
          ),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('언어 설정 기능은 준비중입니다.')),
            );
          },
        ),
        _MenuItem(
          icon: Icons.palette_outlined,
          title: '테마 설정',
          trailing: const Text(
            '라이트',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.mediumGray,
            ),
          ),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('테마 설정 기능은 준비중입니다.')),
            );
          },
        ),
      ],
    );
  }

  /// 정보 섹션
  Widget _buildInfoSection() {
    return _buildSection(
      title: '정보',
      items: [
        _MenuItem(
          icon: Icons.help_outline,
          title: 'FAQ',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('FAQ 기능은 준비중입니다.')),
            );
          },
        ),
        _MenuItem(
          icon: Icons.description_outlined,
          title: '이용약관',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('이용약관 기능은 준비중입니다.')),
            );
          },
        ),
        _MenuItem(
          icon: Icons.privacy_tip_outlined,
          title: '개인정보 처리방침',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('개인정보 처리방침 기능은 준비중입니다.')),
            );
          },
        ),
        _MenuItem(
          icon: Icons.info_outline,
          title: '버전 정보',
          trailing: const Text(
            'v1.0.0',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.mediumGray,
            ),
          ),
          onTap: null,
        ),
      ],
    );
  }

  /// 섹션 빌더
  Widget _buildSection({
    required String title,
    required List<_MenuItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.mediumGray,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              thickness: 1,
              color: AppColors.gray200,
              indent: AppSpacing.lg,
              endIndent: AppSpacing.lg,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                leading: Icon(
                  item.icon,
                  color: item.textColor ?? AppColors.nearBlack,
                  size: 24,
                ),
                title: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: item.textColor ?? AppColors.nearBlack,
                  ),
                ),
                trailing: item.trailing ??
                    (item.onTap != null
                        ? Icon(
                            Icons.chevron_right,
                            color: AppColors.gray400,
                          )
                        : null),
                onTap: item.onTap,
              );
            },
          ),
        ),
      ],
    );
  }

  /// 로그아웃 버튼
  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: _handleLogout,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.error,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          ),
          child: const Text(
            '로그아웃',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// 메뉴 아이템 데이터 클래스
class _MenuItem {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? textColor;

  const _MenuItem({
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
    this.textColor,
  });
}
