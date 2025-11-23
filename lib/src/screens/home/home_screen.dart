import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../../theme/spacing.dart';
import '../../theme/radius.dart';
import '../../router/route_names.dart';
import '../../services/pet/pet_service.dart';
import '../../models/pet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _petService = PetService();
  DateTime selectedDate = DateTime.now();
  List<Pet> _pets = [];
  Pet? _activePet;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPets();
  }

  Future<void> _loadPets() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final pets = await _petService.getMyPets();
      final activePet = await _petService.getActivePet();

      if (mounted) {
        setState(() {
          _pets = pets;
          _activePet = activePet;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 앵무새 전용 앱이므로 항상 🦜 이모지 사용
  String _getPetEmoji(String species) {
    return '🦜';
  }

  void _showPetSelector() {
    if (_pets.isEmpty) {
      // Navigate to pet add screen if no pets
      context.pushNamed(RouteNames.petAdd).then((_) => _loadPets());
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppSpacing.md),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.lightGray,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '앵무새 선택',
                style: AppTypography.h5.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.nearBlack,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ..._pets.map((pet) => ListTile(
                leading: Text(_getPetEmoji(pet.species), style: const TextStyle(fontSize: 24)),
                title: Text(
                  pet.name,
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: _activePet?.id == pet.id ? FontWeight.w700 : FontWeight.w500,
                    color: AppColors.nearBlack,
                  ),
                ),
                trailing: _activePet?.id == pet.id
                    ? const Icon(Icons.check_circle, color: AppColors.brandPrimary)
                    : null,
                onTap: () async {
                  final navigator = Navigator.of(context);
                  await _petService.setActivePet(pet.id);
                  if (mounted) {
                    navigator.pop();
                    _loadPets();
                  }
                },
              )),
              Divider(color: AppColors.gray200),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: AppColors.brandPrimary),
                ),
                title: Text(
                  '새 앵무새 추가',
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandPrimary,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  context.pushNamed(RouteNames.petAdd).then((_) => _loadPets());
                },
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // App Bar
                      _buildAppBar(),
                      const SizedBox(height: AppSpacing.lg),

                      // AI Camera Banner
                      _buildAICameraBanner(),
                      const SizedBox(height: AppSpacing.lg),

                      // Calendar Widget
                      _buildCalendar(),
                      const SizedBox(height: AppSpacing.lg),

                      // AI Check Section
                      _buildAICheckSection(),
                      const SizedBox(height: AppSpacing.lg),

                      // Bottom Cards
                      _buildBottomCards(),
                      const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Pet Selector
        GestureDetector(
          onTap: _showPetSelector,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.brandPrimary, width: 2),
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brandPrimary.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Text(
                  _activePet != null ? _getPetEmoji(_activePet!.species) : '🐾',
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  _activePet?.name ?? '앵무새 추가',
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.nearBlack,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                const Icon(Icons.arrow_drop_down, size: 24, color: AppColors.brandPrimary),
              ],
            ),
          ),
        ),

        // Right Icons
        Row(
          children: [
            Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(Icons.notifications_outlined, size: 24, color: AppColors.nearBlack),
                    onPressed: () {
                      context.pushNamed(RouteNames.notification);
                    },
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.xs),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(Icons.person_outline, size: 24, color: AppColors.nearBlack),
                onPressed: () {
                  context.pushNamed(RouteNames.profile);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAICameraBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.gradientTop,
            AppColors.brandPrimary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandPrimary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI카메라로 우리 아이',
                  style: AppTypography.h6.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '건강 체크해주세요',
                  style: AppTypography.h6.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text('📱', style: const TextStyle(fontSize: 36)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    '${selectedDate.year}년 ${selectedDate.month.toString().padLeft(2, '0')}월 ${selectedDate.day.toString().padLeft(2, '0')}일',
                    style: AppTypography.h6.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.nearBlack,
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, size: 24, color: AppColors.mediumGray),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.gray50,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: IconButton(
                  icon: Icon(Icons.edit_outlined, size: 20, color: AppColors.brandPrimary),
                  onPressed: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildWeekCalendar(),
        ],
      ),
    );
  }

  Widget _buildWeekCalendar() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday % 7 - 1));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(7, (index) {
        final date = startOfWeek.add(Duration(days: index));
        final isSelected = date.day == selectedDate.day &&
            date.month == selectedDate.month &&
            date.year == selectedDate.year;
        final weekdays = ['일', '월', '화', '수', '목', '금', '토'];

        return GestureDetector(
          onTap: () {
            setState(() {
              selectedDate = date;
            });
          },
          child: Container(
            width: 45,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.brandPrimary : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Column(
              children: [
                Text(
                  weekdays[date.weekday % 7],
                  style: AppTypography.bodySmall.copyWith(
                    color: isSelected ? Colors.white : AppColors.mediumGray,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date.day.toString(),
                  style: AppTypography.h6.copyWith(
                    color: isSelected ? Colors.white : AppColors.nearBlack,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildAICheckSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI체크',
                  style: AppTypography.h5.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.nearBlack,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'AI카메라로 우리 아이 건강을',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.mediumGray,
                  ),
                ),
                Text(
                  '직접 체크해 보세요',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.mediumGray,
                  ),
                ),
              ],
            ),
          ),
          // 앵무새 전용 앱이므로 앵무새 아바타만 표시
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppColors.brandPrimary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('🦜', style: const TextStyle(fontSize: 40)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCards() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              context.pushNamed(RouteNames.weightDetail);
            },
            child: _buildCard(
              title: '체중',
              value: '0',
              unit: 'g',
              color: Colors.lightBlue.shade100,
              iconColor: Colors.blue,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _buildCard(
            title: 'AI 백과사전',
            value: '0',
            unit: 'g',
            color: Colors.brown.shade100,
            iconColor: Colors.brown,
          ),
        ),
      ],
    );
  }

  Widget _buildCard({
    required String title,
    required String value,
    required String unit,
    required Color color,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTypography.h6.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.nearBlack,
                ),
              ),
              Icon(Icons.chevron_right, size: 24, color: AppColors.mediumGray),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const SizedBox(height: AppSpacing.xl),
          const SizedBox(height: AppSpacing.xl),
          Align(
            alignment: Alignment.bottomRight,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: [
                  BoxShadow(
                    color: iconColor.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_circle_outline, color: iconColor, size: 20),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '$value$unit',
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: iconColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
