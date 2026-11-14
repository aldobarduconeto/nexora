import 'package:flutter/material.dart';
import 'package:nexora/src/services/conversation_tabs_service.dart';
import 'package:nexora/src/services/local_data_service.dart';
import 'package:nexora/src/services/notification_service.dart';
import 'package:nexora/src/views/p2p_chat.dart';

class PushNotificationBanner extends StatefulWidget {
  const PushNotificationBanner({super.key});

  @override
  State<PushNotificationBanner> createState() => _PushNotificationBannerState();
}

class _PushNotificationBannerState extends State<PushNotificationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<Offset> _offsetAnim;
  late final Animation<double> _fadeAnim;
  PushNotificationItem? _currentItem;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _offsetAnim = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _anim, curve: Curves.easeIn);

    NotificationService.instance.activeBanner.addListener(_onBannerChanged);
  }

  @override
  void dispose() {
    NotificationService.instance.activeBanner.removeListener(_onBannerChanged);
    _anim.dispose();
    super.dispose();
  }

  void _onBannerChanged() {
    final newItem = NotificationService.instance.activeBanner.value;
    if (newItem != null) {
      setState(() => _currentItem = newItem);
      _anim.forward();
    } else {
      _anim.reverse().then((_) {
        if (mounted && NotificationService.instance.activeBanner.value == null) {
          setState(() => _currentItem = null);
        }
      });
    }
  }

  void _dismiss() {
    NotificationService.instance.dismissActiveBanner();
  }

  void _handleTap(BuildContext context) {
    final item = _currentItem;
    _dismiss();
    if (item == null || item.conversationId == null) return;

    // Navigate to conversation if available
    try {
      final conversations = LocalDataService.instance.conversations;
      final match = conversations.firstWhere(
        (c) => c.id == item.conversationId,
      );
      ConversationTabsService.instance.openConversation(
        match,
        title: match.title,
      );
    } catch (_) {}
  }

  IconData _iconForType(NotificationType type) => switch (type) {
    NotificationType.message => Icons.chat_bubble_rounded,
    NotificationType.call => Icons.phone_in_talk_rounded,
    NotificationType.file => Icons.attach_file_rounded,
    NotificationType.mirror => Icons.devices_rounded,
    NotificationType.security => Icons.security_rounded,
    NotificationType.system => Icons.notifications_active_rounded,
  };

  Color _accentForType(BuildContext context, NotificationType type) {
    final colors = Theme.of(context).colorScheme;
    return switch (type) {
      NotificationType.message => colors.primary,
      NotificationType.call => Colors.greenAccent.shade400,
      NotificationType.file => colors.tertiary,
      NotificationType.mirror => Colors.amberAccent.shade400,
      NotificationType.security => colors.error,
      NotificationType.system => colors.primary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final item = _currentItem;
    if (item == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = _accentForType(context, item.type);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: SlideTransition(
          position: _offsetAnim,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: GestureDetector(
              onVerticalDragUpdate: (details) {
                if (details.primaryDelta != null && details.primaryDelta! < -4) {
                  _dismiss();
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Material(
                      elevation: 8,
                      shadowColor: Colors.black.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(20),
                      color: isDark ? const Color(0xFF161C2C) : Colors.white,
                      child: InkWell(
                        onTap: () => _handleTap(context),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: accent.withOpacity(0.35),
                              width: 1.4,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: accent.withOpacity(0.16),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _iconForType(item.type),
                                  color: accent,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          'agora',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      item.body,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: colors.onSurface.withOpacity(0.85),
                                        height: 1.25,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 20),
                                color: colors.onSurfaceVariant,
                                onPressed: _dismiss,
                                tooltip: 'Dispensar',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
