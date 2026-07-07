import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/radius.dart';
import '../../theme/durations.dart';
import '../../models/notification.dart';
import '../../view_models/notification/notification_view_model.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/app_loading.dart';
import '../../../l10n/app_localizations.dart';

/// 알림 화면
class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  Future<void> _markAsRead(String id) {
    return ref.read(notificationViewModelProvider.notifier).markAsRead(id);
  }

  Future<void> _markAllAsRead() async {
    try {
      await ref.read(notificationViewModelProvider.notifier).markAllAsRead();
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        AppSnackBar.error(context, message: l10n.notification_deleteError);
      }
    }
  }

  Future<void> _deleteNotification(String id) async {
    try {
      await ref.read(notificationViewModelProvider.notifier).delete(id);
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        AppSnackBar.error(context, message: l10n.notification_deleteError);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // 기존 화면의 초기 로드 실패 시 error_network 스낵바를 보존한다.
    // build() 중 직접 스낵바를 띄우면 안 되므로 ref.listen으로 상태 전이를 감지한다.
    ref.listen<AsyncValue<List<AppNotification>>>(
      notificationViewModelProvider,
      (previous, next) {
        final becameError = next.hasError && (previous == null || !previous.hasError);
        if (becameError && mounted) {
          AppSnackBar.error(context, message: l10n.error_network);
        }
      },
    );

    final notificationsAsync = ref.watch(notificationViewModelProvider);
    final notifications = notificationsAsync.valueOrNull ?? const [];
    final isLoading = notificationsAsync.isLoading && !notificationsAsync.hasValue;

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.nearBlack),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.notification_title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.nearBlack,
          ),
        ),
        centerTitle: true,
        actions: [
          if (notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: _markAllAsRead,
              child: Text(
                l10n.notification_markAllRead,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.brandPrimary,
                ),
              ),
            ),
        ],
      ),
      body: isLoading
          ? AppLoading.fullPage()
          : notifications.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: notifications.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return Dismissible(
                      key: Key(notification.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) => _deleteNotification(notification.id),
                      child: _NotificationCard(
                        notification: notification,
                        onTap: () => _markAsRead(notification.id),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context);
    return EmptyStateWidget(
      icon: Icons.notifications_none,
      title: l10n.notification_empty,
    );
  }
}

/// 알림 카드 위젯
class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final timeAgo = _getTimeAgo(notification.timestamp, context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: AnimatedContainer(
        duration: AppDurations.of(context, AppDurations.normal),
        curve: AppCurves.enter,
        padding: EdgeInsets.only(
          left: notification.isRead ? AppSpacing.lg : AppSpacing.md,
          right: AppSpacing.lg,
          top: AppSpacing.md,
          bottom: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: notification.isRead
              ? null
              : Border(
                  left: BorderSide(
                    color: AppColors.brandPrimary,
                    width: 4,
                  ),
                ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              // 알림 아이콘
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: notification.iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  notification.icon,
                  color: notification.iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              // 알림 내용
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.nearBlack,
                            ),
                          ),
                        ),
                        AnimatedScale(
                          duration:
                              AppDurations.of(context, AppDurations.normal),
                          curve: AppCurves.enter,
                          scale: notification.isRead ? 0.0 : 1.0,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.brandPrimary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: AppColors.mediumGray,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      timeAgo,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.gray500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ),
    );
  }

  String _getTimeAgo(DateTime timestamp, BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return l10n.notification_justNow;
    } else if (difference.inHours < 1) {
      return l10n.notification_minutesAgo(difference.inMinutes);
    } else if (difference.inHours < 24) {
      return l10n.notification_hoursAgo(difference.inHours);
    } else if (difference.inDays < 7) {
      return l10n.notification_daysAgo(difference.inDays);
    } else {
      final year = timestamp.year;
      final month = timestamp.month.toString().padLeft(2, '0');
      final day = timestamp.day.toString().padLeft(2, '0');
      return '$year.$month.$day';
    }
  }
}
