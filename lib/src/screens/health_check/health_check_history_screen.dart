import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../l10n/app_localizations.dart';
import '../../config/environment.dart';
import '../../models/ai_health_check.dart';
import '../../router/route_names.dart';
import '../../theme/colors.dart';
import '../../services/api/api_client.dart';
import '../../providers/premium_provider.dart';
import '../../services/storage/health_check_storage_service.dart';
import '../../services/storage/local_image_storage_service.dart';
import '../../providers/pet_providers.dart';
import '../../widgets/coach_mark_overlay.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/app_loading.dart';
import '../../services/coach_mark/coach_mark_service.dart';
import '../../theme/durations.dart';

/// 건강체크 히스토리 화면
class HealthCheckHistoryScreen extends ConsumerStatefulWidget {
  const HealthCheckHistoryScreen({super.key});

  @override
  ConsumerState<HealthCheckHistoryScreen> createState() =>
      _HealthCheckHistoryScreenState();
}

class _HealthCheckHistoryScreenState
    extends ConsumerState<HealthCheckHistoryScreen> {
  List<HealthCheckRecord> _records = [];
  List<_DateGroup>? _groupedRecords;
  bool _isLoading = true;

  // Coach mark target keys
  final _vetSummaryButtonKey = GlobalKey();
  final _shareButtonKey = GlobalKey();
  final _firstHistoryCardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    if (!_isLoading) {
      setState(() { _isLoading = true; });
    }
    final petId = ref.read(activePetProvider).valueOrNull?.id;

    // Try server first
    if (petId != null) {
      try {
        final serverRecords =
            await HealthCheckStorageService.instance.fetchFromServer(petId);
        // Update local cache
        await HealthCheckStorageService.instance.syncWithServer(petId);
        if (mounted) {
          setState(() {
            _records = serverRecords;
            _groupedRecords = null;
            _isLoading = false;
          });
          if (_records.isNotEmpty) {
            _maybeShowCoachMarks();
          }
        }
        return;
      } catch (e) {
        debugPrint('[HealthCheckHistory] Server load failed, using local: $e');
      }
    }

    // Fallback to local
    final records =
        await HealthCheckStorageService.instance.getRecords(petId);
    if (mounted) {
      setState(() {
        _records = records;
        _groupedRecords = null;
        _isLoading = false;
      });
      if (_records.isNotEmpty) {
        _maybeShowCoachMarks();
      }
    }
  }

  Future<void> _maybeShowCoachMarks() async {
    final service = CoachMarkService.instance;
    if (await service.hasSeen(CoachMarkService.screenHealthCheckHistory)) return;
    if (!mounted) return;
    await Future.delayed(AppDurations.coachMarkDelay);
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    final steps = [
      CoachMarkStep(
        targetKey: _vetSummaryButtonKey,
        title: l10n.coach_hcHistoryVet_title,
        body: l10n.coach_hcHistoryVet_body,
        isScrollable: false,
      ),
      CoachMarkStep(
        targetKey: _shareButtonKey,
        title: l10n.coach_hcHistoryShare_title,
        body: l10n.coach_hcHistoryShare_body,
        isScrollable: false,
      ),
      CoachMarkStep(
        targetKey: _firstHistoryCardKey,
        title: l10n.coach_hcHistorySwipe_title,
        body: l10n.coach_hcHistorySwipe_body,
        isScrollable: true,
      ),
    ];

    CoachMarkOverlay.show(
      context,
      steps: steps,
      nextLabel: l10n.coach_next,
      gotItLabel: l10n.coach_gotIt,
      skipLabel: l10n.coach_skip,
      onComplete: () {
        service.markSeen(CoachMarkService.screenHealthCheckHistory);
      },
    );
  }

  /// 삭제 확인 다이얼로그 표시. true 반환 시 Dismissible이 애니메이션 처리.
  Future<bool> _showDeleteConfirmDialog() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.hc_deleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.common_delete),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  /// Dismissible onDismissed에서 호출: 스토리지 + 이미지 + 서버 삭제
  Future<void> _performDelete(HealthCheckRecord record) async {
    await HealthCheckStorageService.instance
        .deleteRecord(record.petId, record.id);
    await LocalImageStorageService.instance.deleteImage(
      ownerType: ImageOwnerType.healthCheck,
      ownerId: record.id,
    );
    // Also delete from server
    if (record.petId != null) {
      try {
        await ApiClient.instance
            .delete('/pets/${record.petId}/health-checks/${record.id}');
      } catch (e) {
        debugPrint('[HealthCheckHistory] Server delete failed: $e');
      }
    }
    if (mounted) {
      final l10n = AppLocalizations.of(context);
      setState(() {
        _records.removeWhere((r) => r.id == record.id);
        _groupedRecords = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.hc_deleteSuccess)),
      );
    }
  }

  Future<void> _shareHealthReport() async {
    final l10n = AppLocalizations.of(context);
    final petId = ref.read(activePetProvider).valueOrNull?.id;
    if (petId == null) return;

    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    try {
      final status = await ref.read(premiumStatusProvider.future);
      if (status.isFree) {
        if (mounted) context.pushNamed(RouteNames.premium);
        return;
      }

      final now = DateTime.now();
      final from = now.subtract(const Duration(days: 30));
      String fmt(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      final result = await ApiClient.instance.post(
        '/reports/share/health/$petId?date_from=${fmt(from)}&date_to=${fmt(now)}',
      );

      final shareUrl = result['share_url'] as String;
      await Share.share(shareUrl, sharePositionOrigin: origin);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 403) {
        context.pushNamed(RouteNames.premium);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.report_shareFailed)),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.report_shareFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    ref.listen(activePetProvider, (previous, next) {
      if (previous?.valueOrNull?.id != next.valueOrNull?.id) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _loadRecords();
        });
      }
    });

    return Scaffold(
      backgroundColor: AppColors.gray100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.nearBlack),
          onPressed: () => context.pop(),
        ),
        title: Text(
          l10n.hc_historyTitle,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.nearBlack,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          IconButton(
            key: _vetSummaryButtonKey,
            icon: const Icon(Icons.local_hospital_outlined,
                color: AppColors.mediumGray),
            tooltip: l10n.report_vetSummary,
            onPressed: () =>
                context.pushNamed(RouteNames.vetSummary),
          ),
          IconButton(
            key: _shareButtonKey,
            icon: const Icon(Icons.share_outlined,
                color: AppColors.mediumGray),
            tooltip: l10n.report_shareHealth,
            onPressed: _shareHealthReport,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? AppLoading.fullPage()
            : RefreshIndicator(
                onRefresh: _loadRecords,
                color: AppColors.brandPrimary,
                child: _records.isEmpty
                    ? ListView(
                        children: [
                          _buildEmptyState(),
                        ],
                      )
                    : _buildRecordList(l10n),
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: EmptyStateWidget(
        icon: Icons.history,
        title: l10n.hc_historyEmpty,
        subtitle: l10n.hc_historyEmptyDesc,
      ),
    );
  }

  Widget _buildRecordList(AppLocalizations l10n) {
    final grouped = _groupedRecords ??= _groupByDate(_records, l10n);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final group = grouped[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (index > 0) const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                group.label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.warmGray,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            ...group.records.asMap().entries.map((entry) {
              final recordIndex = entry.key;
              final record = entry.value;
              final isFirstCard = index == 0 && recordIndex == 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildRecordCard(
                  record,
                  l10n,
                  key: isFirstCard ? _firstHistoryCardKey : null,
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildRecordCard(
    HealthCheckRecord record,
    AppLocalizations l10n, {
    GlobalKey? key,
  }) {
    final mode = VisionMode.fromValue(record.mode);
    final (icon, iconColor) = _getModeIcon(mode);
    final (statusColor, statusBg, statusLabel) =
        _getStatusStyle(record.status, l10n);
    final timeStr = _formatTime(record.checkedAt);

    return Dismissible(
      key: Key(record.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) => _showDeleteConfirmDialog(),
      onDismissed: (_) => _performDelete(record),
      child: Semantics(
        button: true,
        label: _getModeLabel(mode, l10n),
        child: GestureDetector(
        onTap: () {
          context.pushNamed(
            RouteNames.healthCheckResult,
            extra: {
              'mode': mode,
              'result': record.result,
              'isFromHistory': true,
              if (record.imageUrl != null) 'imageUrl': record.imageUrl,
            },
          );
        },
        child: Container(
          key: key,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              if (record.imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    Environment.resolveImageUrl(record.imageUrl!),
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildModeIcon(mode, icon, iconColor),
                  ),
                )
              else
                _buildModeIcon(mode, icon, iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getModeLabel(mode, l10n),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.nearBlack,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.warmGray,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
              if (record.confidenceScore != null) ...[
                const SizedBox(width: 8),
                Text(
                  '${record.confidenceScore!.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.warmGray,
                  ),
                ),
              ],
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildModeIcon(VisionMode mode, IconData icon, Color iconColor) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: mode == VisionMode.fullBody
          ? SvgPicture.asset(
              'assets/images/brand.svg',
              width: 22,
              height: 22,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
            )
          : Icon(icon, color: iconColor, size: 22),
    );
  }

  (IconData, Color) _getModeIcon(VisionMode mode) {
    return switch (mode) {
      VisionMode.fullBody => (Icons.pets, AppColors.brandPrimary),
      VisionMode.partSpecific => (Icons.search, AppColors.partSpecificBlue),
      VisionMode.droppings => (Icons.science_outlined, AppColors.droppingsPurple),
      VisionMode.food => (Icons.restaurant, AppColors.foodGreen),
    };
  }

  String _getModeLabel(VisionMode mode, AppLocalizations l10n) {
    return switch (mode) {
      VisionMode.fullBody => l10n.hc_modeFullBody,
      VisionMode.partSpecific => l10n.hc_modePartSpecific,
      VisionMode.droppings => l10n.hc_modeDroppings,
      VisionMode.food => l10n.hc_modeFood,
    };
  }

  (Color, Color, String) _getStatusStyle(
      String status, AppLocalizations l10n) {
    return switch (status.toLowerCase()) {
      'normal' || 'safe' => (
        AppColors.success,
        AppColors.successLight,
        l10n.hc_severityNormal,
      ),
      'caution' => (
        AppColors.warning,
        AppColors.brandLighter,
        l10n.hc_severityCaution,
      ),
      'warning' => (
        AppColors.brandPrimary,
        AppColors.brandLight,
        l10n.hc_severityWarning,
      ),
      'critical' || 'toxic' || 'danger' || 'dangerous' => (
        AppColors.gradientBottom,
        AppColors.dangerLight,
        l10n.hc_severityCritical,
      ),
      _ => (
        AppColors.gray500,
        AppColors.gray100,
        l10n.hc_severityUnknown,
      ),
    };
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} $h:$m';
  }

  List<_DateGroup> _groupByDate(
      List<HealthCheckRecord> records, AppLocalizations l10n) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final last7Days = today.subtract(const Duration(days: 7));

    final groups = <String, List<HealthCheckRecord>>{};
    final order = <String>[];

    for (final record in records) {
      final recordDate = DateTime(
        record.checkedAt.year,
        record.checkedAt.month,
        record.checkedAt.day,
      );

      String label;
      if (recordDate == today) {
        label = l10n.hc_dateToday;
      } else if (recordDate == yesterday) {
        label = l10n.hc_dateYesterday;
      } else if (recordDate.isAfter(last7Days)) {
        label = l10n.hc_dateLast7Days;
      } else {
        label = l10n.hc_dateEarlier;
      }

      if (!groups.containsKey(label)) {
        groups[label] = [];
        order.add(label);
      }
      groups[label]!.add(record);
    }

    return order.map((label) => _DateGroup(label, groups[label]!)).toList();
  }
}

class _DateGroup {
  final String label;
  final List<HealthCheckRecord> records;

  const _DateGroup(this.label, this.records);
}
