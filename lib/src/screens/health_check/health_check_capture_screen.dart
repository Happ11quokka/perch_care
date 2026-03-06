import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../l10n/app_localizations.dart';
import '../../models/ai_health_check.dart';
import '../../router/route_names.dart';
import '../../services/premium/premium_service.dart';
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
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkPremium();
  }

  Future<void> _checkPremium() async {
    try {
      final status = await PremiumService.instance.getTier();
      if (mounted && status.isFree) {
        context.goNamed(RouteNames.healthCheck);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

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
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.hc_imageSizeExceeded)),
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
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.hc_imagePickError(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  void _onAnalyze() {
    if (_selectedImage == null) return;
    final notes = _notesController.text.trim();
    context.pushNamed(
      RouteNames.healthCheckAnalyzing,
      extra: {
        'mode': widget.mode,
        'part':
            widget.mode == VisionMode.partSpecific ? _selectedPart : null,
        'imageBytes': _selectedImage!,
        'fileName': _fileName,
        if (notes.isNotEmpty) 'notes': notes,
      },
    );
  }

  String _getModeLabel(AppLocalizations l10n, VisionMode mode) {
    switch (mode) {
      case VisionMode.fullBody:
        return l10n.hc_modeFullBody;
      case VisionMode.partSpecific:
        return l10n.hc_modePartSpecific;
      case VisionMode.droppings:
        return l10n.hc_modeDroppings;
      case VisionMode.food:
        return l10n.hc_modeFood;
    }
  }

  String _getPartLabel(AppLocalizations l10n, BodyPart part) {
    switch (part) {
      case BodyPart.eye:
        return l10n.hc_partEye;
      case BodyPart.beak:
        return l10n.hc_partBeak;
      case BodyPart.feather:
        return l10n.hc_partFeather;
      case BodyPart.foot:
        return l10n.hc_partFoot;
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
          _getModeLabel(l10n, widget.mode),
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
            children: [
              // 이미지 프리뷰 영역
              Expanded(child: _buildImagePreview(l10n)),
              const SizedBox(height: 16),

              // 부위 선택 (part_specific 모드)
              if (widget.mode == VisionMode.partSpecific) ...[
                _buildPartSelector(l10n),
                const SizedBox(height: 16),
              ],

              // 상황 설명 (선택)
              _buildNotesField(l10n),
              const SizedBox(height: 12),

              // 카메라/갤러리 버튼
              Row(
                children: [
                  Expanded(child: _buildPickerButton(
                    icon: Icons.camera_alt,
                    label: l10n.hc_takePhoto,
                    onTap: () => _pickImage(ImageSource.camera),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _buildPickerButton(
                    icon: Icons.photo_library,
                    label: l10n.hc_selectFromAlbum,
                    onTap: () => _pickImage(ImageSource.gallery),
                  )),
                ],
              ),
              const SizedBox(height: 16),

              // 분석하기 버튼
              _buildAnalyzeButton(l10n),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildImagePreview(AppLocalizations l10n) {
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
            Text(
              l10n.hc_photoHint,
              textAlign: TextAlign.center,
              style: const TextStyle(
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

  Widget _buildPartSelector(AppLocalizations l10n) {
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
                  _getPartLabel(l10n, part),
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

  String _getNotesHint(AppLocalizations l10n) {
    switch (widget.mode) {
      case VisionMode.fullBody:
        return l10n.hc_notesHintFullBody;
      case VisionMode.partSpecific:
        return l10n.hc_notesHint;
      case VisionMode.droppings:
        return l10n.hc_notesHintDroppings;
      case VisionMode.food:
        return l10n.hc_notesHintFood;
    }
  }

  Widget _buildNotesField(AppLocalizations l10n) {
    return TextField(
      controller: _notesController,
      maxLines: 2,
      maxLength: 200,
      style: const TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: Color(0xFF1A1A1A),
        letterSpacing: -0.3,
      ),
      decoration: InputDecoration(
        hintText: _getNotesHint(l10n),
        hintStyle: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: Color(0xFF97928A),
          letterSpacing: -0.3,
        ),
        filled: true,
        fillColor: Colors.white,
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brandPrimary),
        ),
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

  Widget _buildAnalyzeButton(AppLocalizations l10n) {
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
          l10n.hc_analyze,
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
