import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/radius.dart';
import '../../models/notification.dart';
import '../../services/notification/notification_service.dart';
import '../../widgets/app_snack_bar.dart';
import '../../../l10n/app_localizations.dart';

/// 알림 화면
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _notificationService = NotificationService();
  List<AppNotification> _notifications = [];
  StreamSubscription<List<AppNotification>>? _subscription;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _subscribeToNotifications();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final notifications = await _notificationService.fetchNotifications();
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _subscribeToNotifications() {
    _subscription = _notificationService.subscribeToNotifications().listen(
      (notifications) {
        if (mounted) {
          setState(() => _notifications = notifications);
        }
      },
    );
  }

  Future<void> _markAsRead(String id) async {
    // 로컬 상태 먼저 업데이트 (빠른 UI 반응)
    setState(() {
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
      }
    });

    // 서버에 반영
    try {
      await _notificationService.markAsRead(id);
    } catch (e) {
      // 에러 발생 시 다시 로드
      _loadNotifications();
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await _notificationService.markAllAsRead();
      setState(() {
        _notifications = _notifications
            .map((n) => n.copyWith(isRead: true))
            .toList();
      });
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        AppSnackBar.error(context, message: l10n.notification_deleteError);
      }
    }
  }

  Future<void> _deleteNotification(String id) async {
    try {
      await _notificationService.deleteNotification(id);
      setState(() {
        _notifications.removeWhere((n) => n.id == id);
      });
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
          if (_notifications.any((n) => !n.isRead))
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: _notifications.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 64,
            color: AppColors.gray400,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.notification_empty,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.gray600,
            ),
          ),
        ],
      ),
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
      child: Container(
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
        child: Padding(
          padding: EdgeInsets.only(
            left: notification.isRead ? AppSpacing.lg : AppSpacing.md,
            right: AppSpacing.lg,
            top: AppSpacing.md,
            bottom: AppSpacing.md,
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
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.brandPrimary,
                              shape: BoxShape.circle,
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
