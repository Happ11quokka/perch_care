import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';

class PickedImage {
  const PickedImage({required this.bytes, required this.fileName});

  final List<int> bytes;
  final String fileName;
}

class AttachmentBottomSheet {
  const AttachmentBottomSheet._();

  /// 카메라/갤러리 중 하나를 선택해 이미지를 반환한다.
  /// 취소 시 `null`. 사이즈 초과 등 유효성 검사는 호출자가 수행.
  static Future<PickedImage?> show(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.bottomSheet,
      ),
      builder: (sheetContext) => const _AttachmentOptions(),
    );

    if (source == null) return null;

    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    if (photo == null) return null;

    final bytes = await photo.readAsBytes();

    // 서버는 jpeg/png/webp 만 허용 — HEIC 확장자를 JPEG 로 교체
    var name = photo.name;
    final ext = name.split('.').last.toLowerCase();
    if (ext == 'heic' || ext == 'heif') {
      name = '${name.substring(0, name.length - ext.length)}jpg';
    }

    return PickedImage(bytes: bytes, fileName: name);
  }
}

class _AttachmentOptions extends StatelessWidget {
  const _AttachmentOptions();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _OptionTile(
              icon: Icons.camera_alt_outlined,
              label: l10n.chatbot_pickFromCamera,
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            _OptionTile(
              icon: Icons.photo_library_outlined,
              label: l10n.chatbot_pickFromGallery,
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.radiusMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.lg,
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: AppColors.brandPrimary),
            const SizedBox(width: AppSpacing.md),
            Text(label, style: AppTypography.bodyLarge),
          ],
        ),
      ),
    );
  }
}
