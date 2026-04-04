import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../models/ai_health_check.dart';
import '../../router/route_names.dart';
import '../../theme/colors.dart';
import '../../services/health_check/health_check_service.dart';
import '../../providers/pet_providers.dart';
import '../../services/analytics/analytics_service.dart';
import '../../providers/premium_provider.dart';
import '../../services/api/api_client.dart';
import '../../theme/durations.dart';
import '../../../l10n/app_localizations.dart';

/// 건강체크 분석 중 로딩 화면
class HealthCheckAnalyzingScreen extends ConsumerStatefulWidget {
  const HealthCheckAnalyzingScreen({
    super.key,
    required this.mode,
    this.part,
    required this.imageBytes,
    required this.fileName,
    this.notes,
  });

  final VisionMode mode;
  final BodyPart? part;
  final Uint8List imageBytes;
  final String fileName;
  final String? notes;

  @override
  ConsumerState<HealthCheckAnalyzingScreen> createState() =>
      _HealthCheckAnalyzingScreenState();
}

class _HealthCheckAnalyzingScreenState
    extends ConsumerState<HealthCheckAnalyzingScreen>
    with SingleTickerProviderStateMixin {
  bool _isAnalyzing = true;
  bool _cancelled = false;
  String? _errorMessage;
  bool _isPremiumError = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: AppDurations.analyzing,
    );
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    _animController.repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPremiumThenAnalyze();
    });
  }

  Future<void> _checkPremiumThenAnalyze() async {
    try {
      final status = await ref.read(premiumStatusProvider.future);
      // Phase 2: quota 기반 접근 체크 (trial remaining > 0이면 허용)
      final hasAccess = status.isPremium ||
          (status.quota?.vision.remaining ?? 0) > 0;
      if (mounted && !hasAccess) {
        context.goNamed(RouteNames.healthCheck);
        return;
      }
    } catch (_) {
      // 프리미엄 확인 실패 시에도 분석 진행 (서버 API에서 403으로 재차단)
    }
    if (!mounted) return;
    _startAnalysis();
  }

  @override
  void dispose() {
    _cancelled = true;
    _animController.dispose();
    super.dispose();
  }

  Future<void> _startAnalysis() async {
    _cancelled = false;
    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _isPremiumError = false;
    });

    try {
      final activePetId = ref.read(activePetProvider).valueOrNull?.id;
      final language = Localizations.localeOf(context).languageCode;
      debugPrint(
        '[HealthCheck] activePetId=$activePetId, mode=${widget.mode.value}, '
        'part=${widget.part?.value}, fileName=${widget.fileName}, '
        'imageSize=${widget.imageBytes.length} bytes, language=$language',
      );

      // food 모드는 펫 없이도 가능, 다른 모드는 펫 필수
      final isFoodMode = widget.mode == VisionMode.food;
      if (activePetId == null && !isFoodMode) {
        throw Exception('펫을 먼저 등록해주세요');
      }

      final Map<String, dynamic> response;
      if (activePetId == null && isFoodMode) {
        response = await HealthCheckService.instance.analyzeFood(
          imageBytes: widget.imageBytes,
          fileName: widget.fileName,
          notes: widget.notes,
          language: language,
        );
      } else {
        response = await HealthCheckService.instance.analyzeImage(
          petId: activePetId!,
          mode: widget.mode.value,
          part: widget.part?.value,
          notes: widget.notes,
          imageBytes: widget.imageBytes,
          fileName: widget.fileName,
          language: language,
        );
      }

      if (!mounted || _cancelled) return;
      debugPrint('[HealthCheck] Analysis response received');

      // Phase 2: Vision 체험 사용 analytics (Free 사용자만)
      try {
        final postStatus = await ref.read(premiumStatusProvider.notifier).refreshAndGet();
        if (!postStatus.isPremium) {
          AnalyticsService.instance.logVisionTrialUsed(
            remainingAfter: postStatus.quota?.vision.remaining ?? 0,
          );
        }
      } catch (_) {}

      // 백엔드 응답: { id, pet_id, check_type, result: { findings, ... }, ... }
      // result 필드 안에 실제 분석 데이터가 중첩되어 있음
      final analysisResult = response['result'] is Map<String, dynamic>
          ? response['result'] as Map<String, dynamic>
          : response;

      // 서버 할당 메타데이터 추출
      final serverId = response['id'] as String?;
      final serverImageUrl = response['image_url'] as String?;
      final serverConfidence =
          (response['confidence_score'] as num?)?.toDouble();
      final serverStatus = response['status'] as String?;
      final serverCheckedAt = response['checked_at'] as String?;

      if (!mounted || _cancelled) return;
      context.pushReplacementNamed(
        RouteNames.healthCheckResult,
        extra: {
          'mode': widget.mode,
          'result': analysisResult,
          'imageBytes': widget.imageBytes,
          if (serverId != null) 'serverId': serverId,
          if (serverImageUrl != null) 'imageUrl': serverImageUrl,
          if (serverConfidence != null) 'serverConfidence': serverConfidence,
          if (serverStatus != null) 'serverStatus': serverStatus,
          if (serverCheckedAt != null) 'serverCheckedAt': serverCheckedAt,
        },
      );
    } on ApiException catch (e) {
      debugPrint('[HealthCheck] ApiException: $e');
      if (!mounted || _cancelled) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _isAnalyzing = false;
        _isPremiumError = e.statusCode == 403;
        _errorMessage = e.statusCode == 403
            ? l10n.premium_healthCheckBlocked
            : (e.statusCode >= 500 ? l10n.error_server : l10n.hc_analysisError);
      });
    } catch (e, st) {
      debugPrint('[HealthCheck] Error: $e');
      debugPrint('[HealthCheck] StackTrace: $st');
      if (!mounted || _cancelled) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _isAnalyzing = false;
        _errorMessage = l10n.hc_analysisError;
      });
    }
  }

  Future<void> _openPremiumPaywallAndRetry() async {
    await context.push('/home/premium?source=vision_403&feature=vision');
    if (!mounted) return;

    try {
      final status = await ref.read(premiumStatusProvider.notifier).refreshAndGet();
      if (!mounted || status.isFree) return;
      await _startAnalysis();
    } catch (_) {}
  }

  Future<bool> _onWillPop() async {
    if (!_isAnalyzing) return true;
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l10n.hc_cancelAnalysis,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          l10n.hc_cancelAnalysisConfirm,
          style: const TextStyle(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              l10n.hc_continueAnalysis,
              style: const TextStyle(),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              l10n.common_cancel,
              style: const TextStyle(
                color: AppColors.brandPrimary,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isAnalyzing,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          context.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: _isAnalyzing ? _buildLoadingState() : _buildErrorState(),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _scaleAnimation,
            child: SvgPicture.asset(
              'assets/images/chatbot.svg',
              width: 100,
              height: 100,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            l10n.hc_analyzing,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.nearBlack,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.hc_aiAnalyzing,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.mediumGray,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              color: AppColors.brandPrimary,
              backgroundColor: AppColors.brandSoft,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isPremiumError ? Icons.workspace_premium : Icons.error_outline,
              size: 64,
              color: _isPremiumError
                  ? AppColors.brandPrimary
                  : AppColors.gradientBottom,
            ),
            const SizedBox(height: 24),
            Text(
              _isPremiumError
                  ? l10n.premium_healthCheckBlockedTitle
                  : l10n.hc_analysisErrorTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.nearBlack,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppColors.mediumGray,
                letterSpacing: -0.3,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            if (_isPremiumError) ...[
              // 프리미엄 업그레이드 버튼 (primary)
              Semantics(
                button: true,
                label: l10n.premium_upgradeToPremium,
                child: GestureDetector(
                onTap: () async {
                  AnalyticsService.instance.logPremiumFeatureBlocked(
                    feature: 'vision',
                    sourceScreen: 'health_check_analyzing',
                  );
                  await _openPremiumPaywallAndRetry();
                },
                child: Container(
                  width: 200,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.brandPrimary, AppColors.brandDark],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    l10n.premium_upgradeToPremium,
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
            ] else ...[
              // 다시 시도 버튼 (primary)
              Semantics(
                button: true,
                label: l10n.hc_retry,
                child: GestureDetector(
                onTap: _startAnalysis,
                child: Container(
                  width: 200,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.brandPrimary, AppColors.brandDark],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    l10n.hc_retry,
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
            ],
            const SizedBox(height: 12),
            Semantics(
              button: true,
              label: l10n.hc_goBack,
              child: GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                width: 200,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gray300),
                ),
                alignment: Alignment.center,
                child: Text(
                  l10n.hc_goBack,
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
          ],
        ),
      ),
    );
  }
}
