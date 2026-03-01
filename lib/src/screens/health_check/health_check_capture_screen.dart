import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/ai_health_check.dart';
import '../../router/route_names.dart';
import '../../theme/colors.dart';
import '../../widgets/dashed_border.dart';

/// 건강체크 이미지 촬영/선택 화면
class HealthCheckCaptureScreen extends StatefulWidget {
  const HealthCheckCaptureScreen({super.key, required this.mode});

  final VisionMode mode;

  @override
  State<HealthCheckCaptureScreen> createState() =>
      _HealthCheckCaptureScreenState();
}

class _HealthCheckCaptureScreenState extends State<HealthCheckCaptureScreen> {
  final _picker = ImagePicker();

  Uint8List? _selectedImage;
  String _fileName = '';
  BodyPart _selectedPart = BodyPart.eye;
  bool _isPickingImage = false;

  Future<void> _pickImage(ImageSource source) async {
    if (_isPickingImage) return;
    setState(() => _isPickingImage = true);
    try {
      final photo = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      if (bytes.length > 10 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미지 크기가 10MB를 초과합니다')),
        );
        return;
      }
      if (!mounted) return;
      // 서버는 jpeg/png/webp만 허용 — HEIC 파일명을 JPEG로 교체
      var name = photo.name;
      final ext = name.split('.').last.toLowerCase();
      if (ext == 'heic' || ext == 'heif') {
        name = '${name.substring(0, name.length - ext.length)}jpg';
      }
      setState(() {
        _selectedImage = bytes;
        _fileName = name;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 선택 중 오류가 발생했습니다: $e')),
      );
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  void _onAnalyze() {
    if (_selectedImage == null) return;
    context.pushNamed(
      RouteNames.healthCheckAnalyzing,
      extra: {
        'mode': widget.mode,
        'part':
            widget.mode == VisionMode.partSpecific ? _selectedPart : null,
        'imageBytes': _selectedImage!,
        'fileName': _fileName,
      },
    );
  }

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
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.mode.label,
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
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            children: [
              // 이미지 프리뷰 영역
              Expanded(child: _buildImagePreview()),
              const SizedBox(height: 16),

              // 부위 선택 (part_specific 모드)
              if (widget.mode == VisionMode.partSpecific) ...[
                _buildPartSelector(),
                const SizedBox(height: 16),
              ],

              // 카메라/갤러리 버튼
              Row(
                children: [
                  Expanded(child: _buildPickerButton(
                    icon: Icons.camera_alt,
                    label: '촬영하기',
                    onTap: () => _pickImage(ImageSource.camera),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _buildPickerButton(
                    icon: Icons.photo_library,
                    label: '앨범에서 선택',
                    onTap: () => _pickImage(ImageSource.gallery),
                  )),
                ],
              ),
              const SizedBox(height: 16),

              // 분석하기 버튼
              _buildAnalyzeButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_selectedImage != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: double.infinity,
              child: Image.memory(
                _selectedImage!,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => setState(() {
                _selectedImage = null;
                _fileName = '';
              }),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      );
    }

    return DashedBorder(
      radius: 16,
      color: const Color(0xFFBDBDBD),
      strokeWidth: 1.5,
      dashWidth: 8,
      dashGap: 4,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt_outlined,
              size: 48,
              color: const Color(0xFFBDBDBD),
            ),
            const SizedBox(height: 16),
            const Text(
              '사진을 촬영하거나\n앨범에서 선택해주세요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF97928A),
                letterSpacing: -0.3,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartSelector() {
    return SizedBox(
      height: 36,
      child: Row(
        children: BodyPart.values.map((part) {
          final isSelected = _selectedPart == part;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPart = part),
              child: Container(
                margin: EdgeInsets.only(
                  right: part != BodyPart.values.last ? 8 : 0,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.brandPrimary : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: isSelected
                      ? null
                      : Border.all(color: const Color(0xFFE0E0E0)),
                ),
                alignment: Alignment.center,
                child: Text(
                  part.label,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : const Color(0xFF1A1A1A),
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPickerButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.brandPrimary),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.brandPrimary, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.brandPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyzeButton() {
    final isEnabled = _selectedImage != null;
    return GestureDetector(
      onTap: isEnabled ? _onAnalyze : null,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: isEnabled
              ? const LinearGradient(
                  colors: [Color(0xFFFF9A42), Color(0xFFFF7C2A)],
                )
              : null,
          color: isEnabled ? null : const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          '분석하기',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isEnabled ? Colors.white : const Color(0xFF9E9E9E),
            letterSpacing: -0.4,
          ),
        ),
      ),
    );
  }
}
