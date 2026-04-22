import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../theme/colors.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';

/// AI 챗봇의 멀티모달 입력 바 — 첨부 버튼, 이미지 썸네일 미리보기, 전송 버튼
class ChatInputMultimodal extends StatelessWidget {
  const ChatInputMultimodal({
    super.key,
    required this.controller,
    required this.isSending,
    required this.isQuotaExhausted,
    required this.onSend,
    required this.onAttachPressed,
    required this.onRemoveAttachment,
    this.attachedImageBytes,
  });

  final TextEditingController controller;
  final bool isSending;
  final bool isQuotaExhausted;
  final VoidCallback onSend;
  final VoidCallback onAttachPressed;
  final VoidCallback onRemoveAttachment;
  final Uint8List? attachedImageBytes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasImage = attachedImageBytes != null;
    final hintText = isQuotaExhausted
        ? l10n.aiEncyclopedia_quotaExhaustedHint
        : (hasImage ? l10n.chatbot_multimodalHint : l10n.chatbot_inputHint);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImage) ...[
            _ThumbnailPreview(
              bytes: attachedImageBytes!,
              onRemove: onRemoveAttachment,
              removeLabel: l10n.chatbot_removeAttachment,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Row(
            children: [
              _AttachButton(
                onTap: isQuotaExhausted ? null : onAttachPressed,
                label: l10n.chatbot_attachPhoto,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.gray100,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: TextField(
                    controller: controller,
                    enabled: !isQuotaExhausted,
                    onTapOutside: (_) =>
                        FocusScope.of(context).unfocus(),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: hintText,
                    ),
                    style: AppTypography.bodyMedium,
                    minLines: 1,
                    maxLines: 3,
                    onSubmitted: (_) => _maybeSend(),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _SendButton(
                controller: controller,
                isSending: isSending,
                hasImage: hasImage,
                isQuotaExhausted: isQuotaExhausted,
                onSend: onSend,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _maybeSend() {
    if (isSending || isQuotaExhausted) return;
    final hasText = controller.text.trim().isNotEmpty;
    if (!hasText && attachedImageBytes == null) return;
    onSend();
  }
}

class _ThumbnailPreview extends StatelessWidget {
  const _ThumbnailPreview({
    required this.bytes,
    required this.onRemove,
    required this.removeLabel,
  });

  final Uint8List bytes;
  final VoidCallback onRemove;
  final String removeLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: AppRadius.radiusMd,
            child: Image.memory(
              bytes,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: Semantics(
              button: true,
              label: removeLabel,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: AppColors.gray800,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachButton extends StatelessWidget {
  const _AttachButton({required this.onTap, required this.label});

  final VoidCallback? onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      label: label,
      enabled: enabled,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.gray100,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.add,
            color: enabled ? AppColors.brandPrimary : AppColors.gray400,
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.controller,
    required this.isSending,
    required this.hasImage,
    required this.isQuotaExhausted,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final bool hasImage;
  final bool isQuotaExhausted;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Send message',
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final hasText = controller.text.trim().isNotEmpty;
          final canSend =
              !isSending && !isQuotaExhausted && (hasText || hasImage);
          return GestureDetector(
            onTap: canSend ? onSend : null,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: canSend
                    ? AppColors.brandPrimary
                    : AppColors.brandPrimary.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: isSending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(
                      Icons.arrow_upward_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
            ),
          );
        },
      ),
    );
  }
}
