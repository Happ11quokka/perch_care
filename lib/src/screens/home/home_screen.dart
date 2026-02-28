import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../router/route_names.dart';
import '../../services/analytics/analytics_service.dart';
import '../../services/pet/pet_service.dart';
import '../../services/pet/pet_local_cache_service.dart';
import '../../services/pet/active_pet_notifier.dart';
import '../../services/bhi/bhi_service.dart';
import '../../services/storage/local_image_storage_service.dart';
import '../../widgets/local_image_avatar.dart';
import '../../models/pet.dart';
import '../../models/bhi_result.dart';
import '../../services/coach_mark/coach_mark_service.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/coach_mark_overlay.dart';
import '../../../l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _petService = PetService.instance;
  final _petCache = PetLocalCacheService.instance;
  final _bhiService = BhiService.instance;
  Pet? _activePet;
  BhiResult? _bhiResult;
  bool _isLoading = true;
  bool _isMonthlyView = true; // true: 매월 단위, false: 매주 단위
  int _selectedMonth = DateTime.now().month;
  int _selectedWeek = 1; // 선택된 주차 (1~5)

  // 데이터 유무 상태 (실제로는 서버에서 가져옴)
  bool _hasWeightData = false;
  bool _hasFoodData = false;
  bool _hasWaterData = false;

  // WCI 레벨 (0: 데이터 없음, 1~5: 각 단계)
  int _wciLevel = 0;

  // 코치마크 타겟 키
  final _wciCardKey = GlobalKey();
  final _weightCardKey = GlobalKey();
  final _waterCardKey = GlobalKey();
  final _foodCardKey = GlobalKey();
  final _healthSignalCardKey = GlobalKey();

  // 스크롤 컨트롤러 (코치마크 자동 스크롤용)
  final _scrollController = ScrollController();

  // WCI 단계별 설명 텍스트를 가져오는 메소드
  Map<int, String> _getWciDescriptions(AppLocalizations l10n) => {
    1: l10n.wci_level1,
    2: l10n.wci_level2,
    3: l10n.wci_level3,
    4: l10n.wci_level4,
    5: l10n.wci_level5,
  };

  @override
  void initState() {
    super.initState();
    debugPrint('[HomeScreen] initState called');
    _loadPets();
    debugPrint('[HomeScreen] _loadPets() called');
    ActivePetNotifier.instance.addListener(_onActivePetChanged);
    debugPrint('[HomeScreen] ActivePetNotifier listener added');
  }

  @override
  void dispose() {
    _scrollController.dispose();
    ActivePetNotifier.instance.removeListener(_onActivePetChanged);
    super.dispose();
  }

  void _onActivePetChanged() {
    final petId = ActivePetNotifier.instance.activePetId;
    if (petId != null) {
      _refreshForPet(petId);
    }
  }

  /// 특정 petId로 펫 정보 + BHI를 서버에서 병렬 로드
  Future<void> _refreshForPet(String petId) async {
    // 이미 같은 펫이면 무시
    if (_activePet?.id == petId) return;

    // 펫 정보 + BHI를 동시에 로드 (독립적이므로 병렬 가능)
    late Pet? pet;
    late BhiResult? bhi;

    try {
      final petFuture = _petService.getPetById(petId);
      final bhiFuture = () async {
        try {
          return await _bhiService.getBhi(petId, targetDate: DateTime.now());
        } catch (e) {
          debugPrint('[HomeScreen] BHI 로드 실패: $e');
          return null;
        }
      }();
      final results = await Future.wait<dynamic>([petFuture, bhiFuture]);

      if (!mounted) return;

      pet = results[0] as Pet?;
      bhi = results[1] as BhiResult?;
    } catch (e) {
      debugPrint('[HomeScreen] 펫 정보 로드 실패, 로컬 캐시 복원 시도: $e');
      if (!mounted) return;
      // 서버 실패 시 로컬 캐시에서 펫 이름만이라도 복원
      try {
        final cached = await _petCache.getActivePet();
        if (!mounted) return;
        if (cached != null && cached.id == petId) {
          setState(() {
            _activePet = Pet(
              id: cached.id,
              userId: '',
              name: cached.name,
              species: cached.species ?? '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
          });
        }
      } catch (cacheError) {
        debugPrint('[HomeScreen] 로컬 캐시 복원도 실패: $cacheError');
      }
      return;
    }

    // setState 단일 호출로 배치 처리 (불필요한 리빌드 방지)
    if (pet != null || bhi != null) {
      setState(() {
        if (pet != null) {
          _activePet = pet;
        }
        if (bhi != null) {
          _bhiResult = bhi;
          _wciLevel = bhi.wciLevel;
          _hasWeightData = bhi.hasWeightData;
          _hasFoodData = bhi.hasFoodData;
          _hasWaterData = bhi.hasWaterData;
        }
      });
    }
  }

  Future<void> _loadPets() async {
    debugPrint('[HomeScreen] _loadPets() started');
    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('[HomeScreen] Calling _petService.getActivePet()...');
      final activePet = await _petService.getActivePet();
      debugPrint('[HomeScreen] getActivePet() returned: ${activePet?.name}');

      if (mounted) {
        setState(() {
          _activePet = activePet;
          _isLoading = false;
        });
      }

      // BHI 데이터 로드 (펫이 있을 때만)
      if (activePet != null) {
        _loadBhi(activePet.id);
      }

      // 첫 사용자 코치마크 표시
      _maybeShowCoachMarks();
    } catch (e) {
      debugPrint('[HomeScreen] 펫 목록 로드 실패: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _maybeShowCoachMarks() async {
    final coachService = CoachMarkService.instance;
    if (await coachService.hasSeenHomeCoachMarks()) return;

    // 레이아웃 안정화 대기
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);

    CoachMarkOverlay.show(
      context,
      scrollController: _scrollController,
      steps: [
        // 1. WCI 건강 상태 카드
        CoachMarkStep(
          targetKey: _wciCardKey,
          title: l10n.coach_wciCard_title,
          body: l10n.coach_wciCard_body,
        ),
        // 2. 체중 카드
        CoachMarkStep(
          targetKey: _weightCardKey,
          title: l10n.coach_weightCard_title,
          body: l10n.coach_weightCard_body,
        ),
        // 3. 수분 카드
        CoachMarkStep(
          targetKey: _waterCardKey,
          title: l10n.coach_waterCard_title,
          body: l10n.coach_waterCard_body,
        ),
        // 4. 사료 카드
        CoachMarkStep(
          targetKey: _foodCardKey,
          title: l10n.coach_foodCard_title,
          body: l10n.coach_foodCard_body,
        ),
        // 5. 건강 신호 카드
        CoachMarkStep(
          targetKey: _healthSignalCardKey,
          title: l10n.coach_healthSignalCard_title,
          body: l10n.coach_healthSignalCard_body,
        ),
        // 6. 기록 탭 (하단 네비게이션)
        CoachMarkStep(
          targetKey: BottomNavBar.recordsTabKey,
          title: l10n.coach_recordsTab_title,
          body: l10n.coach_recordsTab_body,
          isScrollable: false,
        ),
        // 7. 앵박사 탭 (하단 네비게이션)
        CoachMarkStep(
          targetKey: BottomNavBar.chatbotTabKey,
          title: l10n.coach_chatbotTab_title,
          body: l10n.coach_chatbotTab_body,
          isScrollable: false,
        ),
      ],
      nextLabel: l10n.coach_next,
      gotItLabel: l10n.coach_gotIt,
      skipLabel: l10n.coach_skip,
      onComplete: () => coachService.markHomeCoachMarksSeen(),
    );
  }

  Future<void> _loadBhi(String petId) async {
    try {
      final bhi = await _bhiService.getBhi(petId, targetDate: DateTime.now());
      if (mounted) {
        setState(() {
          _bhiResult = bhi;
          _wciLevel = bhi.wciLevel;
          _hasWeightData = bhi.hasWeightData;
          _hasFoodData = bhi.hasFoodData;
          _hasWaterData = bhi.hasWaterData;
        });
      }
    } catch (e) {
      debugPrint('[HomeScreen] BHI 로드 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // 스크롤 가능한 컨텐츠
                Column(
                  children: [
                    // 헤더 높이만큼 공간 확보
                    SizedBox(height: MediaQuery.of(context).padding.top + 140),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 17),
                          child: Column(
                            children: [
                              const SizedBox(height: 24),
                              // WCI 건강 상태 카드
                              Container(key: _wciCardKey, child: _buildWCICard()),
                              const SizedBox(height: 12),
                              // 하단 4개 카드
                              _buildBottomCards(),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // 상단 헤더 (고정, 위에 표시)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildHeader(),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            // 토글 버튼, 펫 이름, 프로필 아이콘
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  // 토글 버튼 (왼쪽)
                  _buildViewToggle(),
                  const Spacer(),
                  // 펫 이름 칩
                  GestureDetector(
                    onTap: () {
                      context.pushNamed(RouteNames.profile);
                    },
                    child: Container(
                      padding: const EdgeInsets.only(
                        left: 4,
                        right: 14,
                        top: 4,
                        bottom: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: const Color(0xFFE8E8E8),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 펫 아바타
                          if (_activePet != null)
                            LocalImageAvatar(
                              ownerType: ImageOwnerType.petProfile,
                              ownerId: _activePet!.id,
                              size: 28,
                              placeholder: ClipOval(
                                child: SvgPicture.asset(
                                  'assets/images/profile/pet_profile_placeholder.svg',
                                  width: 28,
                                  height: 28,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            )
                          else
                            ClipOval(
                              child: SvgPicture.asset(
                                'assets/images/profile/pet_profile_placeholder.svg',
                                width: 28,
                                height: 28,
                                fit: BoxFit.cover,
                              ),
                            ),
                          const SizedBox(width: 8),
                          // 이름
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 80),
                            child: Text(
                              _activePet?.name ?? '',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A1A),
                                letterSpacing: -0.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 월/주 선택기 (애니메이션)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.1),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  ),
                );
              },
              child: _isMonthlyView
                  ? _buildMonthSelector()
                  : _buildWeekSelector(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildViewToggle() {
    final l10n = AppLocalizations.of(context);

    return Container(
      width: 170,
      height: 48,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
          children: [
            // 애니메이션되는 배경 pill
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              left: _isMonthlyView ? 0 : 83,
              top: 0,
              bottom: 0,
              child: Container(
                width: 83,
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            // 텍스트 버튼들
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isMonthlyView = true;
                      });
                    },
                    child: Container(
                      color: Colors.transparent,
                      alignment: Alignment.center,
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _isMonthlyView ? Colors.white : const Color(0xFF97928A),
                          letterSpacing: -0.35,
                        ),
                        child: Text(l10n.home_monthlyUnit),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isMonthlyView = false;
                      });
                    },
                    child: Container(
                      color: Colors.transparent,
                      alignment: Alignment.center,
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: !_isMonthlyView ? Colors.white : const Color(0xFF97928A),
                          letterSpacing: -0.35,
                        ),
                        child: Text(l10n.home_weeklyUnit),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
    );
  }

  Widget _buildMonthSelector() {
    final l10n = AppLocalizations.of(context);

    // Generate 7 months centered around current month
    final currentMonth = DateTime.now().month;
    final months = <int>[];
    for (int i = -3; i <= 3; i++) {
      int month = currentMonth + i;
      // Handle year wrap-around
      while (month < 1) { month += 12; }
      while (month > 12) { month -= 12; }
      months.add(month);
    }

    return SizedBox(
      key: const ValueKey('month'),
      height: 36,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: months.map((month) {
          final isSelected = month == _selectedMonth;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedMonth = month;
              });
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.brandPrimary : Colors.transparent,
                borderRadius: BorderRadius.circular(100),
              ),
              alignment: Alignment.center,
              child: Text(
                l10n.home_monthFormat(month),
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? Colors.white : const Color(0xFF6B6B6B),
                  letterSpacing: -0.3,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWeekSelector() {
    final l10n = AppLocalizations.of(context);
    final weeks = [1, 2, 3, 4, 5];

    return SizedBox(
      key: const ValueKey('week'),
      height: 36,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: weeks.map((week) {
          final isSelected = week == _selectedWeek;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedWeek = week;
              });
            },
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.brandPrimary : Colors.transparent,
                borderRadius: BorderRadius.circular(100),
              ),
              alignment: Alignment.center,
              child: Text(
                l10n.home_weekFormat(week),
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? Colors.white : const Color(0xFF6B6B6B),
                  letterSpacing: -0.3,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWCICard() {
    final l10n = AppLocalizations.of(context);
    final petName = _activePet?.name ?? '사랑이';
    final wciDescriptions = _getWciDescriptions(l10n);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // 헤더
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => context.pushNamed(RouteNames.wciIndex),
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                      children: [
                        TextSpan(
                          text: 'WCI',
                          style: const TextStyle(
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        TextSpan(
                          text: '*',
                          style: const TextStyle(
                            color: AppColors.brandPrimary,
                          ),
                        ),
                        TextSpan(text: ' ${l10n.home_wciHealthStatus.replaceAll('WCI* ', '')}'),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 16,
                      color: Color(0xFF97928A),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      l10n.home_updatedAgo(0),
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF97928A),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFFF0F0F0),
            ),
          ),
          const SizedBox(height: 24),
          // 일러스트레이션
          if (_wciLevel == 0)
            SvgPicture.asset(
              'assets/images/home_vector/wci_bird_empty.svg',
              width: 119,
              height: 171,
            )
          else
            Image.asset(
              'assets/images/home_vector/lv$_wciLevel.png',
              width: 160,
              height: 240,
              cacheWidth: 320,
              cacheHeight: 480,
            ),
          const SizedBox(height: 13),
          // 설명 텍스트
          if (_wciLevel == 0) ...[
            Text(
              l10n.home_enterDataPrompt(petName),
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF6B6B6B),
                letterSpacing: -0.35,
                height: 24 / 14,
              ),
            ),
            Text(
              l10n.home_checkStatus,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF6B6B6B),
                letterSpacing: -0.35,
                height: 24 / 14,
              ),
            ),
          ] else
            Text(
              wciDescriptions[_wciLevel] ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF6B6B6B),
                letterSpacing: -0.35,
                height: 24 / 14,
              ),
            ),
          const SizedBox(height: 24),
          // 진행도 바
          _buildProgressBars(),
          const SizedBox(height: 8),
          // 단계 표시
          Text(
            l10n.home_level(_wciLevel),
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
              height: 20 / 16,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildProgressBars() {
    // 5개 슬롯: 동그라미가 현재 레벨 위치로 이동
    // lv0: 중앙(3번) 회색 동그라미, 바 없음(전부 회색)
    // lv1: 1번 동그라미
    // lv2: 1번 바(주황) + 2번 동그라미
    // lv3: 1~2번 바(주황) + 3번 동그라미
    // lv4: 1~3번 바(주황) + 4번 동그라미
    // lv5: 1~4번 바(주황) + 5번 동그라미
    final int circlePos = _wciLevel == 0 ? 3 : _wciLevel; // 0이면 중앙(3)

    final List<Widget> children = [];
    for (int i = 1; i <= 5; i++) {
      if (i > 1) children.add(const SizedBox(width: 2));

      if (i == circlePos) {
        // 동그라미
        children.add(Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _wciLevel > 0 ? AppColors.brandPrimary : const Color(0xFFF0F0F0),
              width: 2,
            ),
            color: Colors.white,
          ),
        ));
      } else {
        // 바: 동그라미 왼쪽이면 채움, 오른쪽이면 비움
        final bool filled = _wciLevel > 0 && i < circlePos;
        children.add(_buildProgressBar(filled));
      }
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: children,
    );
  }

  Widget _buildProgressBar(bool isActive) {
    return Container(
      width: 74,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? AppColors.brandPrimary : const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(1),
        border: Border.all(
          color: const Color(0xFFF0F0F0),
          width: 1,
        ),
      ),
    );
  }

  Widget _buildBottomCards() {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        // 첫 번째 행: 체중, 사료
        Row(
          children: [
            Expanded(
              child: Container(
                key: _weightCardKey,
                child: _buildDataCard(
                  title: l10n.home_weight,
                  subtitle: l10n.home_weightHint,
                  iconPath: 'assets/images/home_vector/weight.svg',
                  hasData: _hasWeightData,
                  onTap: () async {
                    await context.pushNamed(RouteNames.weightRecord);
                    if (_activePet != null) _loadBhi(_activePet!.id);
                  },
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                key: _foodCardKey,
                child: _buildDataCard(
                  title: l10n.home_food,
                  subtitle: l10n.home_foodHint,
                  iconPath: 'assets/images/home_vector/eat.svg',
                  hasData: _hasFoodData,
                  onTap: () async {
                    await context.pushNamed(RouteNames.foodRecord);
                    if (_activePet != null) _loadBhi(_activePet!.id);
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // 두 번째 행: 수분, 오늘의 건강 신호
        Row(
          children: [
            Expanded(
              child: Container(
                key: _waterCardKey,
                child: _buildDataCard(
                  title: l10n.home_water,
                  subtitle: l10n.home_waterHint,
                  iconPath: 'assets/images/home_vector/water.svg',
                  hasData: _hasWaterData,
                  onTap: () async {
                    await context.pushNamed(RouteNames.waterRecord);
                    if (_activePet != null) _loadBhi(_activePet!.id);
                  },
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                key: _healthSignalCardKey,
                child: _buildHealthSignalCard(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDataCard({
    required String title,
    required String subtitle,
    required String iconPath,
    required bool hasData,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 170,
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                    letterSpacing: -0.4,
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 24,
                  color: Color(0xFF97928A),
                ),
              ],
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Color(0xFF6B6B6B),
                letterSpacing: -0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            // 아이콘 (SVG에 이미 원형 테두리가 포함되어 있음)
            Align(
              alignment: Alignment.bottomRight,
              child: SvgPicture.asset(
                iconPath,
                width: 60,
                height: 60,
                colorFilter: hasData
                    ? const ColorFilter.mode(
                        AppColors.brandPrimary,
                        BlendMode.srcIn,
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthSignalCard() {
    final l10n = AppLocalizations.of(context);

    return GestureDetector(
      onTap: () {
        AnalyticsService.instance.logBhiViewed(_activePet?.id ?? '');
        context.pushNamed(
          RouteNames.bhiDetail,
          extra: _bhiResult,
        );
      },
      child: Container(
        height: 170,
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment(-0.7, -0.7),
            end: Alignment(0.7, 0.7),
            colors: [
              Colors.white,
              Color(0xFFFFF5ED),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.brandPrimary,
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.home_todayHealthSignal,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.4,
                        height: 26 / 16,
                      ),
                    ),
                    Text(
                      l10n.home_healthSignal,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.4,
                        height: 26 / 16,
                      ),
                    ),
                  ],
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 24,
                  color: Color(0xFF97928A),
                ),
              ],
            ),
            const Spacer(),
            // 아이콘 (SVG에 이미 배경 원이 포함되어 있음)
            Align(
              alignment: Alignment.bottomRight,
              child: SvgPicture.asset(
                'assets/images/home_vector/daily_health.svg',
                width: 60,
                height: 60,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
