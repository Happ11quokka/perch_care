import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/ai_health_check.dart';
import '../../router/route_names.dart';
import '../../theme/colors.dart';
import '../../services/health_check/health_check_service.dart';
import '../../services/pet/active_pet_notifier.dart';
import '../../services/api/api_client.dart';

/// 건강체크 분석 중 로딩 화면
class HealthCheckAnalyzingScreen extends StatefulWidget {
  const HealthCheckAnalyzingScreen({
    super.key,
    required this.mode,
    this.part,
    required this.imageBytes,
    required this.fileName,
  });

  final VisionMode mode;
  final BodyPart? part;
  final Uint8List imageBytes;
  final String fileName;

  @override
  State<HealthCheckAnalyzingScreen> createState() =>
      _HealthCheckAnalyzingScreenState();
}

class _HealthCheckAnalyzingScreenState extends State<HealthCheckAnalyzingScreen>
    with SingleTickerProviderStateMixin {
  bool _isAnalyzing = true;
  bool _cancelled = false;
  String? _errorMessage;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    _animController.repeat(reverse: true);
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
    });

    try {
      final activePetId = ActivePetNotifier.instance.activePetId;
      if (activePetId == null) throw Exception('펫을 먼저 등록해주세요');

      final response = await HealthCheckService.instance.analyzeImage(
        petId: activePetId,
        mode: widget.mode.value,
        part: widget.part?.value,
        imageBytes: widget.imageBytes,
        fileName: widget.fileName,
      );

      if (!mounted || _cancelled) return;

      // 백엔드 응답: { id, pet_id, check_type, result: { findings, ... }, ... }
      // result 필드 안에 실제 분석 데이터가 중첩되어 있음
      final analysisResult = response['result'] is Map<String, dynamic>
          ? response['result'] as Map<String, dynamic>
          : response;

      context.pushReplacementNamed(
        RouteNames.healthCheckResult,
        extra: {
          'mode': widget.mode,
          'result': analysisResult,
          'imageBytes': widget.imageBytes,
        },
      );
    } on ApiException catch (e) {
      if (!mounted || _cancelled) return;
      setState(() {
        _isAnalyzing = false;
        _errorMessage = e.statusCode == 403
            ? '프리미엄 전용 기능입니다.\n프리미엄 플랜으로 업그레이드해주세요.'
            : e.message;
      });
    } catch (e) {
      if (!mounted || _cancelled) return;
      setState(() {
        _isAnalyzing = false;
        _errorMessage = '분석 중 오류가 발생했습니다.\n다시 시도해주세요.';
      });
    }
  }

  Future<bool> _onWillPop() async {
    if (!_isAnalyzing) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          '분석 취소',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          '분석을 취소하시겠습니까?',
          style: TextStyle(fontFamily: 'Pretendard'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('계속 분석',
                style: TextStyle(fontFamily: 'Pretendard')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('취소',
                style: TextStyle(
                    fontFamily: 'Pretendard', color: AppColors.brandPrimary)),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.brandPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.pets,
                size: 40,
                color: AppColors.brandPrimary,
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            '분석 중입니다...',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'AI가 이미지를 분석하고 있어요',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF6B6B6B),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              color: AppColors.brandPrimary,
              backgroundColor: const Color(0xFFFFE0C0),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Color(0xFFFF572D),
            ),
            const SizedBox(height: 24),
            const Text(
              '분석 중 오류가 발생했습니다',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF6B6B6B),
                letterSpacing: -0.3,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _startAnalysis,
              child: Container(
                width: 200,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF9A42), Color(0xFFFF7C2A)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Text(
                  '다시 시도',
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
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                width: 200,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                alignment: Alignment.center,
                child: const Text(
                  '돌아가기',
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
          ],
        ),
      ),
    );
  }
}
