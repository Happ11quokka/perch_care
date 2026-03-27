import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../config/environment.dart';
import '../../models/ai_health_check.dart';
import '../../router/route_names.dart';
import '../../theme/colors.dart';
import '../../services/storage/health_check_storage_service.dart';
import '../../services/storage/local_image_storage_service.dart';
import '../../providers/pet_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/coach_mark_overlay.dart';
import '../../services/coach_mark/coach_mark_service.dart';

/// 건강체크 분석 결과 화면
class HealthCheckResultScreen extends ConsumerStatefulWidget {
  const HealthCheckResultScreen({
    super.key,
    required this.mode,
    required this.result,
    this.imageBytes,
    this.imageUrl,
    this.isFromHistory = false,
    this.serverId,
    this.serverConfidence,
    this.serverStatus,
    this.serverCheckedAt,
  });

  final VisionMode mode;
  final Map<String, dynamic> result;
  final Uint8List? imageBytes;
  final String? imageUrl; // 서버 이미지 상대 경로
  final bool isFromHistory;
  final String? serverId;
  final double? serverConfidence;
  final String? serverStatus;
  final String? serverCheckedAt;

  @override
  ConsumerState<HealthCheckResultScreen> createState() =>
      _HealthCheckResultScreenState();
}

class _HealthCheckResultScreenState extends ConsumerState<HealthCheckResultScreen> {
  VisionMode get mode => widget.mode;
  Map<String, dynamic> get result => widget.result;

  // Coach mark target keys
  final _confidenceBarKey = GlobalKey();
  final _findingsKey = GlobalKey();
  final _recheckButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (!widget.isFromHistory) {
      _saveResult();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowCoachMarks();
    });
  }

  Future<void> _maybeShowCoachMarks() async {
    final service = CoachMarkService.instance;
    if (await service.hasSeen(CoachMarkService.screenHealthCheckResult)) return;
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    final steps = [
      CoachMarkStep(
        targetKey: _confidenceBarKey,
        title: l10n.coach_hcResultConfidence_title,
        body: l10n.coach_hcResultConfidence_body,
      ),
      CoachMarkStep(
        targetKey: _findingsKey,
        title: l10n.coach_hcResultFindings_title,
        body: l10n.coach_hcResultFindings_body,
      ),
      CoachMarkStep(
        targetKey: _recheckButtonKey,
        title: l10n.coach_hcResultRecheck_title,
        body: l10n.coach_hcResultRecheck_body,
        isScrollable: false,
      ),
    ];

    CoachMarkOverlay.show(
      context,
      steps: steps,
      nextLabel: l10n.coach_next,
      gotItLabel: l10n.coach_gotIt,
      skipLabel: l10n.coach_skip,
      onComplete: () {
        service.markSeen(CoachMarkService.screenHealthCheckResult);
      },
    );
  }

  Future<void> _saveResult() async {
    try {
      final petId = ref.read(activePetProvider).valueOrNull?.id;
      final id = widget.serverId ?? const Uuid().v4();
      final overallStatus = widget.serverStatus ??
          (result['overall_status'] ??
                  result['overall_diet_assessment'] ??
                  'normal')
              .toString();
      final confidence = widget.serverConfidence ??
          (result['confidence_score'] as num?)?.toDouble();

      DateTime checkedAt;
      if (widget.serverCheckedAt != null) {
        try {
          checkedAt = DateTime.parse(widget.serverCheckedAt!);
        } catch (_) {
          checkedAt = DateTime.now();
        }
      } else {
        checkedAt = DateTime.now();
      }

      final record = HealthCheckRecord(
        id: id,
        petId: petId,
        mode: mode.value,
        imageUrl: widget.imageUrl,
        result: result,
        confidenceScore: confidence,
        status: overallStatus,
        checkedAt: checkedAt,
      );

      await HealthCheckStorageService.instance.saveRecord(record);

      // 이미지도 로컬에 저장
      if (widget.imageBytes != null) {
        await LocalImageStorageService.instance.saveImage(
          ownerType: ImageOwnerType.healthCheck,
          ownerId: id,
          imageBytes: widget.imageBytes!,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).hc_savedSuccessfully)),
        );
      }
    } catch (_) {
      // 저장 실패해도 결과 화면 표시에는 영향 없음
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.gray100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.nearBlack),
          onPressed: () {
            if (widget.isFromHistory) {
              context.pop();
            } else {
              context.goNamed(RouteNames.home);
            }
          },
        ),
        title: Text(
          l10n.hc_resultTitle,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.nearBlack,
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImagePreview(),
              _buildOverallStatusCard(l10n),
              const SizedBox(height: 12),

              if (result['vet_visit_needed'] == true) ...[
                _buildVetAlert(l10n),
                const SizedBox(height: 12),
              ],

              _buildSectionTitle(l10n.hc_analysisItems),
              const SizedBox(height: 12),
              Container(
                key: _findingsKey,
                child: _buildFindings(l10n),
              ),
              const SizedBox(height: 20),

              _buildSectionTitle(l10n.hc_recommendations),
              const SizedBox(height: 12),
              _buildRecommendations(),
              const SizedBox(height: 24),

              _buildActionButtons(context, l10n),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    final hasImage = widget.imageBytes != null || widget.imageUrl != null;
    if (!hasImage) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: widget.imageBytes != null
            ? Image.memory(
                widget.imageBytes!,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
              )
            : Image.network(
                Environment.resolveImageUrl(widget.imageUrl!),
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: double.infinity,
                  height: 200,
                  color: AppColors.gray100,
                  child: const Center(
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      size: 48,
                      color: AppColors.gray350,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildOverallStatusCard(AppLocalizations l10n) {
    final status = _getOverallStatus();
    final rawConfidence = (result['confidence_score'] as num?)?.toDouble();
    final confidence = rawConfidence?.clamp(0.0, 100.0);
    final (statusColor, statusBg, statusLabel) = _getSeverityStyle(status, l10n);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.hc_overallStatus,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.nearBlack,
                  letterSpacing: -0.4,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          if (confidence != null) ...[
            const SizedBox(height: 16),
            Row(
              key: _confidenceBarKey,
              children: [
                Text(
                  l10n.hc_confidence,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.mediumGray,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: confidence / 100,
                      minHeight: 8,
                      color: AppColors.brandPrimary,
                      backgroundColor: AppColors.brandSoft,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${confidence.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.nearBlack,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVetAlert(AppLocalizations l10n) {
    final reason = result['vet_reason'] as String?;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gradientBottom.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.local_hospital, color: AppColors.gradientBottom, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.hc_vetVisitRecommended,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gradientBottom,
                    letterSpacing: -0.3,
                  ),
                ),
                if (reason != null && reason.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    reason,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppColors.mediumGray,
                      letterSpacing: -0.3,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFindings(AppLocalizations l10n) {
    switch (mode) {
      case VisionMode.fullBody:
      case VisionMode.partSpecific:
        return _buildBodyFindings(l10n);
      case VisionMode.droppings:
        return _buildDroppingsFindings(l10n);
      case VisionMode.food:
        return _buildFoodFindings(l10n);
    }
  }

  Widget _buildBodyFindings(AppLocalizations l10n) {
    final findings = (result['findings'] as List<dynamic>?) ?? [];
    return Column(
      children: findings.map((finding) {
        final f = finding as Map<String, dynamic>;
        final areaKey = f['area'] ?? f['aspect'] ?? '';
        final observation = f['observation'] as String? ?? '';
        final severity = f['severity'] as String? ?? 'normal';
        final causes = (f['possible_causes'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList();
        final rawFirstAid = f['first_aid'];
        final firstAid = rawFirstAid is List
            ? rawFirstAid.map((e) => e.toString()).toList()
            : null;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildFindingCard(
            l10n: l10n,
            title: _getAreaLabel(areaKey.toString(), l10n),
            observation: observation,
            severity: severity,
            details: causes,
            firstAidSteps: firstAid,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDroppingsFindings(AppLocalizations l10n) {
    final findings = (result['findings'] as List<dynamic>?) ?? [];
    final conditions =
        (result['possible_conditions'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList();

    return Column(
      children: [
        ...findings.map((finding) {
          final f = finding as Map<String, dynamic>;
          final component = f['component'] as String? ?? '';
          final color = f['color'] as String? ?? '-';
          final texture = f['texture'] as String? ?? '-';
          final status = f['status'] as String? ?? 'normal';

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildFindingCard(
              l10n: l10n,
              title: _getAreaLabel(component, l10n),
              observation: l10n.hc_colorTexture(color, texture),
              severity: status,
            ),
          );
        }),
        if (conditions != null && conditions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.hc_possibleCauses,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.nearBlack,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                ...conditions.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ',
                              style: TextStyle(
                                  color: AppColors.mediumGray, fontSize: 14)),
                          Expanded(
                            child: Text(
                              c,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: AppColors.mediumGray,
                                letterSpacing: -0.3,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFoodFindings(AppLocalizations l10n) {
    final items = (result['identified_items'] as List<dynamic>?) ?? [];
    final nutritionBalance = result['nutrition_balance'] as String?;

    return Column(
      children: [
        ...items.map((item) {
          final i = item as Map<String, dynamic>;
          final name = i['name'] as String? ?? '';
          final safety = i['safety'] as String? ?? 'unknown';
          final note = i['note'] as String? ?? '';

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildFindingCard(
              l10n: l10n,
              title: name,
              observation: note,
              severity: safety,
            ),
          );
        }),
        if (nutritionBalance != null && nutritionBalance.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.hc_nutritionBalance,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.nearBlack,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  nutritionBalance,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.mediumGray,
                    letterSpacing: -0.3,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRecommendations() {
    final recommendations =
        (result['recommendations'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    if (recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: recommendations
            .map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '• ',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          r,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: AppColors.nearBlack,
                            letterSpacing: -0.3,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: l10n.hc_goHome,
            child: GestureDetector(
            onTap: () => context.goNamed(RouteNames.home),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.gray300),
                color: Colors.white,
              ),
              alignment: Alignment.center,
              child: Text(
                l10n.hc_goHome,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.mediumGray,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Semantics(
            button: true,
            label: l10n.hc_recheckButton,
            child: GestureDetector(
            onTap: () => context.goNamed(RouteNames.healthCheck),
            child: Container(
              key: _recheckButtonKey,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.brandPrimary, AppColors.brandDark],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                l10n.hc_recheckButton,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.nearBlack,
        letterSpacing: -0.4,
      ),
    );
  }

  Widget _buildFindingCard({
    required AppLocalizations l10n,
    required String title,
    required String observation,
    required String severity,
    List<String>? details,
    List<String>? firstAidSteps,
  }) {
    final (severityColor, severityBg, severityLabel) =
        _getSeverityStyle(severity, l10n);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.nearBlack,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: severityBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  severityLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: severityColor,
                  ),
                ),
              ),
            ],
          ),
          if (observation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              observation,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.mediumGray,
                letterSpacing: -0.3,
                height: 1.4,
              ),
            ),
          ],
          if (details != null && details.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${l10n.hc_possibleCausesPrefix}${details.join(', ')}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppColors.warmGray,
                letterSpacing: -0.3,
              ),
            ),
          ],
          if (firstAidSteps != null && firstAidSteps.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.brandLighter,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.hc_firstAidTitle,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warningDark,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...firstAidSteps.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      '${e.key + 1}. ${e.value}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.mediumGray,
                        letterSpacing: -0.3,
                        height: 1.4,
                      ),
                    ),
                  )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getOverallStatus() {
    return (result['overall_status'] ??
            result['overall_diet_assessment'] ??
            'normal')
        .toString();
  }

  (Color, Color, String) _getSeverityStyle(String severity, AppLocalizations l10n) {
    return switch (severity.toLowerCase()) {
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

  String _getAreaLabel(String area, AppLocalizations l10n) {
    return switch (area.toLowerCase()) {
      // full_body 대분류
      'feather' => l10n.hc_areaFeather,
      'posture' => l10n.hc_areaPosture,
      'eye' => l10n.hc_areaEye,
      'beak' => l10n.hc_areaBeak,
      'foot' => l10n.hc_areaFoot,
      'body_shape' => l10n.hc_areaBodyShape,
      'injury_detected' => l10n.hc_areaInjuryDetected,
      // droppings
      'feces' => l10n.hc_areaFeces,
      'urates' => l10n.hc_areaUrates,
      'urine' => l10n.hc_areaUrine,
      // foot 세부
      'plantar surface' => l10n.hc_aspectPlantarSurface,
      'nail length' => l10n.hc_aspectNailLength,
      'swelling' => l10n.hc_aspectSwelling,
      'skin texture' => l10n.hc_aspectSkinTexture,
      'grip strength indicators' || 'grip strength' => l10n.hc_aspectGripStrength,
      'toe alignment' => l10n.hc_aspectToeAlignment,
      'burns' => l10n.hc_aspectBurns,
      'lacerations' => l10n.hc_aspectLacerations,
      'fractures' => l10n.hc_aspectFractures,
      'bite wounds' => l10n.hc_aspectBiteWounds,
      'band injuries' => l10n.hc_aspectBandInjuries,
      // eye 세부
      'discharge' => l10n.hc_aspectDischarge,
      'pupil response' => l10n.hc_aspectPupilResponse,
      'corneal clarity' => l10n.hc_aspectCornealClarity,
      'periorbital area' => l10n.hc_aspectPeriorbitalArea,
      'symmetry' || 'symmetry between eyes' => l10n.hc_aspectSymmetry,
      'corneal scratches' || 'corneal scratches/trauma' => l10n.hc_aspectCornealScratches,
      'foreign body' => l10n.hc_aspectForeignBody,
      // beak 세부
      'color' => l10n.hc_aspectColor,
      'texture' => l10n.hc_aspectTexture,
      'overgrowth' => l10n.hc_aspectOvergrowth,
      'cracks' => l10n.hc_aspectCracks,
      'peeling' => l10n.hc_aspectPeeling,
      'cere condition' => l10n.hc_aspectCereCondition,
      'alignment' => l10n.hc_aspectAlignment,
      // feather 세부
      'density' => l10n.hc_aspectDensity,
      'luster' => l10n.hc_aspectLuster,
      'discoloration' => l10n.hc_aspectDiscoloration,
      'damage patterns' => l10n.hc_aspectDamagePatterns,
      'plucking signs' => l10n.hc_aspectPluckingSigns,
      'pin feathers' => l10n.hc_aspectPinFeathers,
      'stress bars' => l10n.hc_aspectStressBars,
      'molting status' => l10n.hc_aspectMoltingStatus,
      _ => area,
    };
  }
}
