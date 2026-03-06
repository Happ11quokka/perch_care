import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../models/ai_health_check.dart';
import '../../router/route_names.dart';
import '../../theme/colors.dart';
import '../../services/storage/health_check_storage_service.dart';
import '../../services/storage/local_image_storage_service.dart';
import '../../services/pet/active_pet_notifier.dart';
import '../../../l10n/app_localizations.dart';

/// 건강체크 분석 결과 화면
class HealthCheckResultScreen extends StatefulWidget {
  const HealthCheckResultScreen({
    super.key,
    required this.mode,
    required this.result,
    this.imageBytes,
    this.isFromHistory = false,
  });

  final VisionMode mode;
  final Map<String, dynamic> result;
  final Uint8List? imageBytes;
  final bool isFromHistory;

  @override
  State<HealthCheckResultScreen> createState() =>
      _HealthCheckResultScreenState();
}

class _HealthCheckResultScreenState extends State<HealthCheckResultScreen> {
  VisionMode get mode => widget.mode;
  Map<String, dynamic> get result => widget.result;

  @override
  void initState() {
    super.initState();
    if (!widget.isFromHistory) {
      _saveResult();
    }
  }

  Future<void> _saveResult() async {
    try {
      final petId = ActivePetNotifier.instance.activePetId;
      final id = const Uuid().v4();
      final overallStatus = (result['overall_status'] ??
              result['overall_diet_assessment'] ??
              'normal')
          .toString();
      final confidence =
          (result['confidence_score'] as num?)?.toDouble();

      final record = HealthCheckRecord(
        id: id,
        petId: petId,
        mode: mode.value,
        result: result,
        confidenceScore: confidence,
        status: overallStatus,
        checkedAt: DateTime.now(),
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
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
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
            fontFamily: 'Pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
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
              _buildOverallStatusCard(l10n),
              const SizedBox(height: 12),

              if (result['vet_visit_needed'] == true) ...[
                _buildVetAlert(l10n),
                const SizedBox(height: 12),
              ],

              _buildSectionTitle(l10n.hc_analysisItems),
              const SizedBox(height: 12),
              _buildFindings(l10n),
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
                  fontFamily: 'Pretendard',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
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
                    fontFamily: 'Pretendard',
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
              children: [
                Text(
                  l10n.hc_confidence,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF6B6B6B),
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
                      backgroundColor: const Color(0xFFFFE0C0),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${confidence.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
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
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF572D).withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.local_hospital, color: Color(0xFFFF572D), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.hc_vetVisitRecommended,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF572D),
                    letterSpacing: -0.3,
                  ),
                ),
                if (reason != null && reason.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    reason,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF6B6B6B),
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
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
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
                                  color: Color(0xFF6B6B6B), fontSize: 14)),
                          Expanded(
                            child: Text(
                              c,
                              style: const TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF6B6B6B),
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
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  nutritionBalance,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF6B6B6B),
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
                          fontFamily: 'Pretendard',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          r,
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF1A1A1A),
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
          child: GestureDetector(
            onTap: () => context.goNamed(RouteNames.home),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE0E0E0)),
                color: Colors.white,
              ),
              alignment: Alignment.center,
              child: Text(
                l10n.hc_goHome,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B6B6B),
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => context.goNamed(RouteNames.healthCheck),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF9A42), Color(0xFFFF7C2A)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                l10n.hc_recheckButton,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: -0.3,
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
        fontFamily: 'Pretendard',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A1A1A),
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
                    fontFamily: 'Pretendard',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
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
                    fontFamily: 'Pretendard',
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
                fontFamily: 'Pretendard',
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Color(0xFF6B6B6B),
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
                fontFamily: 'Pretendard',
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Color(0xFF97928A),
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
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.hc_firstAidTitle,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE65100),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...firstAidSteps.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      '${e.key + 1}. ${e.value}',
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF6B6B6B),
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

  String _getAreaLabel(String area, AppLocalizations l10n) {
    return switch (area.toLowerCase()) {
      'feather' => l10n.hc_areaFeather,
      'posture' => l10n.hc_areaPosture,
      'eye' => l10n.hc_areaEye,
      'beak' => l10n.hc_areaBeak,
      'foot' => l10n.hc_areaFoot,
      'body_shape' => l10n.hc_areaBodyShape,
      'feces' => l10n.hc_areaFeces,
      'urates' => l10n.hc_areaUrates,
      'urine' => l10n.hc_areaUrine,
      'injury_detected' => l10n.hc_areaInjuryDetected,
      _ => area,
    };
  }
}
