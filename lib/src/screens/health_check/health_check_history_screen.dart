import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../l10n/app_localizations.dart';
import '../../models/ai_health_check.dart';
import '../../router/route_names.dart';
import '../../theme/colors.dart';
import '../../services/api/api_client.dart';
import '../../services/premium/premium_service.dart';
import '../../services/storage/health_check_storage_service.dart';
import '../../services/storage/local_image_storage_service.dart';
import '../../services/pet/active_pet_notifier.dart';

/// 건강체크 히스토리 화면
class HealthCheckHistoryScreen extends StatefulWidget {
  const HealthCheckHistoryScreen({super.key});

  @override
  State<HealthCheckHistoryScreen> createState() =>
      _HealthCheckHistoryScreenState();
}

class _HealthCheckHistoryScreenState extends State<HealthCheckHistoryScreen> {
  List<HealthCheckRecord> _records = [];
  List<_DateGroup>? _groupedRecords;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
    ActivePetNotifier.instance.addListener(_onPetChanged);
  }

  @override
  void dispose() {
    ActivePetNotifier.instance.removeListener(_onPetChanged);
    super.dispose();
  }

  void _onPetChanged() {
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    if (!_isLoading) {
      setState(() { _isLoading = true; });
    }
    final petId = ActivePetNotifier.instance.activePetId;

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
    }
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
    final petId = ActivePetNotifier.instance.activePetId;
    if (petId == null) return;

    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    try {
      final status = await PremiumService.instance.getTier();
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

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          l10n.hc_historyTitle,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.local_hospital_outlined,
                color: Color(0xFF6B6B6B)),
            tooltip: l10n.report_vetSummary,
            onPressed: () =>
                context.pushNamed(RouteNames.vetSummary),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined,
                color: Color(0xFF6B6B6B)),
            tooltip: l10n.report_shareHealth,
            onPressed: _shareHealthReport,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadRecords,
                color: AppColors.brandPrimary,
                child: _records.isEmpty
                    ? ListView(
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.6,
                            child: _buildEmptyState(l10n),
                          ),
                        ],
                      )
                    : _buildRecordList(l10n),
              ),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.history,
            size: 64,
            color: Color(0xFFD0D0D0),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.hc_historyEmpty,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B6B6B),
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.hc_historyEmptyDesc,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF97928A),
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
        ],
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
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF97928A),
                  letterSpacing: -0.3,
                ),
              ),
            ),
            ...group.records.map((record) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildRecordCard(record, l10n),
                )),
          ],
        );
      },
    );
  }

  Widget _buildRecordCard(HealthCheckRecord record, AppLocalizations l10n) {
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
      child: GestureDetector(
        onTap: () {
          context.pushNamed(
            RouteNames.healthCheckResult,
            extra: {
              'mode': mode,
              'result': record.result,
              'isFromHistory': true,
            },
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: mode == VisionMode.fullBody
                    ? SvgPicture.asset(
                        'assets/images/brand.svg',
                        width: 22,
                        height: 22,
                        colorFilter: ColorFilter.mode(
                          iconColor,
                          BlendMode.srcIn,
                        ),
                      )
                    : Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getModeLabel(mode, l10n),
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF97928A),
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
                    fontFamily: 'Pretendard',
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
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF97928A),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  (IconData, Color) _getModeIcon(VisionMode mode) {
    return switch (mode) {
      VisionMode.fullBody => (Icons.pets, AppColors.brandPrimary),
      VisionMode.partSpecific => (Icons.search, const Color(0xFF42A5F5)),
      VisionMode.droppings => (Icons.science_outlined, const Color(0xFF7E57C2)),
      VisionMode.food => (Icons.restaurant, const Color(0xFF66BB6A)),
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
        const Color(0xFF4CAF50),
        const Color(0xFFE8F5E9),
        l10n.hc_severityNormal,
      ),
      'caution' => (
        const Color(0xFFFF9800),
        const Color(0xFFFFF3E0),
        l10n.hc_severityCaution,
      ),
      'warning' => (
        const Color(0xFFFF9A42),
        const Color(0xFFFFF5ED),
        l10n.hc_severityWarning,
      ),
      'critical' || 'toxic' || 'danger' || 'dangerous' => (
        const Color(0xFFFF572D),
        const Color(0xFFFFEBEE),
        l10n.hc_severityCritical,
      ),
      _ => (
        const Color(0xFF9E9E9E),
        const Color(0xFFF5F5F5),
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
