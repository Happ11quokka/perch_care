import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/ai_health_check.dart';
import '../../router/route_names.dart';
import '../../theme/colors.dart';

/// 건강체크 분석 결과 화면
class HealthCheckResultScreen extends StatelessWidget {
  const HealthCheckResultScreen({
    super.key,
    required this.mode,
    required this.result,
    this.imageBytes,
  });

  final VisionMode mode;
  final Map<String, dynamic> result;
  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => context.goNamed(RouteNames.home),
        ),
        title: const Text(
          '분석 결과',
          style: TextStyle(
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
              _buildOverallStatusCard(),
              const SizedBox(height: 12),

              if (result['vet_visit_needed'] == true) ...[
                _buildVetAlert(),
                const SizedBox(height: 12),
              ],

              _buildSectionTitle('분석 항목'),
              const SizedBox(height: 12),
              _buildFindings(),
              const SizedBox(height: 20),

              _buildSectionTitle('권장 사항'),
              const SizedBox(height: 12),
              _buildRecommendations(),
              const SizedBox(height: 24),

              _buildActionButtons(context),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // --- 종합 상태 카드 ---

  Widget _buildOverallStatusCard() {
    final status = _getOverallStatus();
    final rawConfidence = (result['confidence_score'] as num?)?.toDouble();
    final confidence = rawConfidence?.clamp(0.0, 100.0);
    final (statusColor, statusBg, statusLabel) = _getSeverityStyle(status);

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
              const Text(
                '종합 상태',
                style: TextStyle(
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
                const Text(
                  '신뢰도',
                  style: TextStyle(
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

  // --- 수의사 방문 알림 ---

  Widget _buildVetAlert() {
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
                const Text(
                  '수의사 방문을 권장합니다',
                  style: TextStyle(
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

  // --- 분석 항목 (모드별 분기) ---

  Widget _buildFindings() {
    switch (mode) {
      case VisionMode.fullBody:
      case VisionMode.partSpecific:
        return _buildBodyFindings();
      case VisionMode.droppings:
        return _buildDroppingsFindings();
      case VisionMode.food:
        return _buildFoodFindings();
    }
  }

  Widget _buildBodyFindings() {
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

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildFindingCard(
            title: _getAreaLabel(areaKey.toString()),
            observation: observation,
            severity: severity,
            details: causes,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDroppingsFindings() {
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
              title: _getAreaLabel(component),
              observation: '색상: $color, 질감: $texture',
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
                const Text(
                  '가능한 원인',
                  style: TextStyle(
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

  Widget _buildFoodFindings() {
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
                const Text(
                  '영양 균형',
                  style: TextStyle(
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

  // --- 권장 사항 ---

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

  // --- 액션 버튼 ---

  Widget _buildActionButtons(BuildContext context) {
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
              child: const Text(
                '홈으로',
                style: TextStyle(
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
              child: const Text(
                '다시 체크하기',
                style: TextStyle(
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

  // --- 공통 위젯 ---

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
    required String title,
    required String observation,
    required String severity,
    List<String>? details,
  }) {
    final (severityColor, severityBg, severityLabel) =
        _getSeverityStyle(severity);

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
              '가능 원인: ${details.join(', ')}',
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Color(0xFF97928A),
                letterSpacing: -0.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- 유틸리티 ---

  String _getOverallStatus() {
    return (result['overall_status'] ??
            result['overall_diet_assessment'] ??
            'normal')
        .toString();
  }

  static (Color, Color, String) _getSeverityStyle(String severity) {
    return switch (severity.toLowerCase()) {
      'normal' || 'safe' => (
        const Color(0xFF4CAF50),
        const Color(0xFFE8F5E9),
        '정상',
      ),
      'caution' => (
        const Color(0xFFFF9800),
        const Color(0xFFFFF3E0),
        '주의',
      ),
      'warning' => (
        const Color(0xFFFF9A42),
        const Color(0xFFFFF5ED),
        '경고',
      ),
      'critical' || 'toxic' || 'danger' || 'dangerous' => (
        const Color(0xFFFF572D),
        const Color(0xFFFFEBEE),
        '위험',
      ),
      _ => (
        const Color(0xFF9E9E9E),
        const Color(0xFFF5F5F5),
        '확인 필요',
      ),
    };
  }

  static String _getAreaLabel(String area) {
    return switch (area.toLowerCase()) {
      'feather' => '깃털 상태',
      'posture' => '자세/균형',
      'eye' => '눈 상태',
      'beak' => '부리 상태',
      'foot' => '발/발톱',
      'body_shape' => '체형',
      'feces' => '변',
      'urates' => '요산',
      'urine' => '소변',
      _ => area,
    };
  }
}
