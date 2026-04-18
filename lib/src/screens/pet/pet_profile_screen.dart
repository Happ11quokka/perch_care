import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../router/route_names.dart';
import '../../services/auth/auth_service.dart';
import '../../models/pet.dart';
import '../../providers/pet_providers.dart';
import '../../../l10n/app_localizations.dart';

/// 반려동물 프로필 목록 화면 — MVVM(ViewModel + Repository) 구조.
///
/// 펫 목록/활성 펫은 `petListViewModelProvider` / `activePetViewModelProvider`를
/// 구독해 받는다. 로컬 캐시 sync와 오프라인 fallback은 Repository가 담당한다.
class PetProfileScreen extends ConsumerStatefulWidget {
  const PetProfileScreen({super.key});

  @override
  ConsumerState<PetProfileScreen> createState() => _PetProfileScreenState();
}

class _PetProfileScreenState extends ConsumerState<PetProfileScreen> {
  final _authService = AuthService.instance;
  String _userNickname = '';

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await _authService.getProfile();
      if (profile == null || !mounted) return;
      setState(() {
        _userNickname = profile['nickname'] as String? ?? '사용자';
      });
    } catch (_) {
      // 프로필 로드 실패 시 기본값 사용
    }
  }

  String _formatAge(DateTime? birthDate) {
    final l10n = AppLocalizations.of(context);
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

    final segments = <String>[];
    if (years > 0) segments.add('$years년');
    if (months > 0) segments.add('$months개월');
    if (days > 0) segments.add('$days일');
    return segments.isEmpty ? l10n.profile_zeroDay : segments.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final petsAsync = ref.watch(petListViewModelProvider);
    final activePetAsync = ref.watch(activePetViewModelProvider);
    final selectedPetId = activePetAsync.valueOrNull?.id;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.nearBlack),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed(RouteNames.home);
            }
          },
        ),
        centerTitle: true,
        title: Text(
          l10n.profile_title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: AppColors.nearBlack,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileSection(),
                  const SizedBox(height: 4),
                  Container(height: 1, color: AppColors.gray100),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      l10n.profile_myPets,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.nearBlack,
                        letterSpacing: 0.08,
                      ),
                    ),
                  ),
                  const SizedBox(height: 11),
                  petsAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                    // Repository 4-tier fallback(서버→인메모리→로컬캐시)으로 실제 도달 거의 없음
                    error: (_, __) => const SizedBox.shrink(),
                    data: (pets) => Column(
                      children: pets
                          .map((pet) => _buildPetCard(pet, selectedPetId))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildAddPetButton(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 7, 32, 20),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.gray300,
            ),
            child: Center(
              child: SvgPicture.asset(
                'assets/images/default_profile.svg',
                width: 30,
                height: 30,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            _userNickname.isEmpty
                ? l10n.profile_user
                : '$_userNickname${l10n.profile_userSuffix}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.nearBlack,
              letterSpacing: 0.08,
            ),
          ),
          const Spacer(),
          Semantics(
            button: true,
            label: l10n.profile_title,
            child: GestureDetector(
              onTap: () {
                context.pushNamed(RouteNames.profile);
              },
              child: SvgPicture.asset(
                'assets/images/settings_icon.svg',
                width: 24,
                height: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetCard(Pet pet, String? selectedPetId) {
    final l10n = AppLocalizations.of(context);
    final isSelected = pet.id == selectedPetId;
    final speciesLabel = (pet.breed?.isNotEmpty == true
            ? pet.breed!
            : (pet.species.isNotEmpty ? pet.species : l10n.profile_noSpecies));

    return Semantics(
      button: true,
      label: pet.name,
      child: GestureDetector(
        onTap: () async {
          // 서버에 활성 펫 변경 저장 + provider 상태 갱신
          await ref.read(activePetViewModelProvider.notifier).switchPet(pet.id);
        },
        child: Container(
          margin: const EdgeInsets.only(left: 32, right: 32, bottom: 12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.brandLight : AppColors.gray100,
            border: Border.all(
              color: isSelected ? AppColors.brandPrimary : Colors.transparent,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 62.64,
                height: 62.64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gray350,
                ),
                child: Center(
                  child: SvgPicture.asset(
                    'assets/images/pet_profile.svg',
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          pet.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.nearBlack,
                            letterSpacing: 0.08,
                          ),
                        ),
                        const SizedBox(width: 1),
                        if (pet.gender == 'male' || pet.gender == 'female')
                          SvgPicture.asset(
                            pet.gender == 'male'
                                ? 'assets/images/gender_male.svg'
                                : 'assets/images/gender_female.svg',
                            width: 20,
                            height: 20,
                          )
                        else
                          const SizedBox(width: 20, height: 20),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      speciesLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.mediumGray,
                        letterSpacing: 0.06,
                      ),
                    ),
                    Text(
                      _formatAge(pet.birthDate),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.mediumGray,
                        letterSpacing: 0.06,
                      ),
                    ),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: 'Edit ${pet.name}',
                child: GestureDetector(
                  onTap: () async {
                    await context.pushNamed(
                      RouteNames.petAdd,
                      extra: {'petId': pet.id},
                    );
                    // 수정 후 목록/활성펫 동기화
                    await ref.read(petListViewModelProvider.notifier).refresh();
                    await ref.read(activePetViewModelProvider.notifier).refresh();
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? AppColors.brandPrimary
                          : AppColors.warmGray,
                    ),
                    child: const Icon(
                      Icons.edit,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddPetButton() {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l10n.profile_addNewPet,
      child: GestureDetector(
        onTap: () async {
          await context.pushNamed(RouteNames.petAdd);
          // 새 펫 등록 후 목록/활성펫 동기화
          await ref.read(petListViewModelProvider.notifier).refresh();
          await ref.read(activePetViewModelProvider.notifier).refresh();
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.warmGray,
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 14.15,
                height: 14.15,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.warmGray,
                ),
                child: const Icon(
                  Icons.add,
                  size: 10,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.profile_addNewPet,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.warmGray,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
