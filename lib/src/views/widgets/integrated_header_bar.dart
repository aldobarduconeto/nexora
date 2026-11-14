import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexora/src/services/conversation_tabs_service.dart';
import 'package:nexora/src/services/local_data_service.dart';
import 'package:nexora/src/services/notification_service.dart';
import 'package:nexora/src/services/window_service.dart';
import 'package:nexora/src/views/widgets/app_theme.dart';

class IntegratedHeaderBar extends StatefulWidget implements PreferredSizeWidget {
  const IntegratedHeaderBar({
    super.key,
    this.minimal = false,
    this.onNewConversation,
    this.onSearchPressed,
    this.onNotificationsPressed,
  });

  final bool minimal;
  final VoidCallback? onNewConversation;
  final VoidCallback? onSearchPressed;
  final VoidCallback? onNotificationsPressed;

  @override
  State<IntegratedHeaderBar> createState() => _IntegratedHeaderBarState();

  @override
  Size get preferredSize => const Size.fromHeight(46);
}

class _IntegratedHeaderBarState extends State<IntegratedHeaderBar> {
  final _tabsService = ConversationTabsService.instance;
  final _windowService = WindowService.instance;
  final _localData = LocalDataService.instance;
  final ScrollController _tabsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabsService.addListener(_refresh);
    _localData.addListener(_refresh);
  }

  @override
  void dispose() {
    _tabsService.removeListener(_refresh);
    _localData.removeListener(_refresh);
    _tabsScrollController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _copyMyKey() async {
    final key = _localData.currentUser.publicKey;
    if (key.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: key));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sua chave pública foi copiada.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showTabContextMenu(BuildContext context, TapDownDetails details, ConversationTab tab) {
    if (tab.isHome) return;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        details.globalPosition & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          value: 'close',
          child: Row(
            children: const [
              Icon(Icons.close_rounded, size: 18),
              SizedBox(width: 8),
              Text('Fechar esta aba'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'close_others',
          child: Row(
            children: const [
              Icon(Icons.tab_unselected_rounded, size: 18),
              SizedBox(width: 8),
              Text('Fechar outras abas'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'close') {
        _tabsService.closeTab(tab.id);
      } else if (value == 'close_others') {
        _tabsService.closeOtherTabs(tab.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDesktop = _windowService.isDesktop;
    final activeCallTab = _tabsService.getTabWithActiveCall();
    final isCallInBackground = activeCallTab != null && activeCallTab.id != _tabsService.activeTab.id;

    final topPadding = MediaQuery.paddingOf(context).top;
    final totalHeight = widget.preferredSize.height + (isDesktop ? 0.0 : topPadding);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: isDesktop ? (_) => _windowService.startDragging() : null,
      onDoubleTap: isDesktop ? () => _windowService.toggleMaximize() : null,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            height: totalHeight,
            padding: EdgeInsets.only(top: isDesktop ? 0.0 : topPadding),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.28),
              border: Border(
                bottom: BorderSide(
                  color: colors.outlineVariant.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
            ),
            child: Row(
          children: [
            // Left: App Brand & E2EE Status Pill
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandMark(size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'Nexora',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // E2EE Indicator Dot
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.primary,
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withValues(alpha: 0.6),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'E2EE',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: colors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (!widget.minimal) ...[
              const SizedBox(width: 4),
              Container(
                height: 20,
                width: 1,
                color: colors.outlineVariant.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 6),

              // Middle: Multi-Conversation Tabs
              Expanded(
                child: Scrollbar(
                  controller: _tabsScrollController,
                  child: SingleChildScrollView(
                    controller: _tabsScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0; i < _tabsService.tabs.length; i++)
                          _buildTabItem(context, _tabsService.tabs[i], i),

                        // "+" Button to add/open new conversation
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: widget.onNewConversation,
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(
                                  Icons.add_rounded,
                                  size: 18,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ] else ...[
              const Spacer(),
            ],

            // Right side: Active call banner, Quick Actions, Key, and Window Controls
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!widget.minimal) ...[
                  // Return to Active Call Pill (if calling in another tab)
                  if (isCallInBackground)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Material(
                        color: const Color(0xFF00DC82).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () => _tabsService.selectTabById(activeCallTab.id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0xFF00DC82).withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.phone_in_talk_rounded,
                                  size: 14,
                                  color: Color(0xFF00DC82),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Chamada em andamento',
                                  style: TextStyle(
                                    color: Color(0xFF00DC82),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Search Action
                  if (widget.onSearchPressed != null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Buscar conversas e mensagens',
                      icon: const Icon(Icons.search_rounded, size: 18),
                      onPressed: widget.onSearchPressed,
                    ),

                  // Notifications Bell
                  ListenableBuilder(
                    listenable: NotificationService.instance,
                    builder: (context, _) {
                      final count = NotificationService.instance.history.length;
                      return IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Central de Notificações',
                        onPressed: widget.onNotificationsPressed,
                        icon: Badge(
                          isLabelVisible: count > 0,
                          smallSize: 8,
                          child: const Icon(Icons.notifications_outlined, size: 18),
                        ),
                      );
                    },
                  ),

                  // Copy User Key Pill
                  if (_localData.currentUser.publicKey.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Material(
                        color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(999),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: _copyMyKey,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: colors.outlineVariant.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.key_rounded, size: 12, color: colors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  _localData.currentUser.publicKey.length > 8
                                      ? '${_localData.currentUser.publicKey.substring(0, 4)}..${_localData.currentUser.publicKey.substring(_localData.currentUser.publicKey.length - 3)}'
                                      : 'Chave',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w600,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],

                // Desktop Window Action Buttons (Minimize, Maximize, Close)
                if (isDesktop) ...[
                  const SizedBox(width: 6),
                  _WindowButton(
                    icon: Icons.remove_rounded,
                    tooltip: 'Minimizar',
                    onPressed: _windowService.minimize,
                  ),
                  _WindowButton(
                    icon: Icons.crop_square_rounded,
                    tooltip: 'Maximizar / Restaurar',
                    onPressed: _windowService.toggleMaximize,
                  ),
                  _WindowButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Fechar',
                    isClose: true,
                    onPressed: _windowService.close,
                  ),
                ],
              ],
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(BuildContext context, ConversationTab tab, int index) {
    final colors = Theme.of(context).colorScheme;
    final isSelected = index == _tabsService.activeIndex;

    IconData iconData = Icons.forum_rounded;
    if (tab.isHome) {
      iconData = Icons.dashboard_rounded;
    } else if (tab.isSavedMessages) {
      iconData = Icons.bookmark_rounded;
    } else if (tab.isCommunity) {
      iconData = Icons.hub_rounded;
    } else if (tab.isGroup) {
      iconData = Icons.groups_rounded;
    } else {
      iconData = Icons.person_rounded;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
      child: GestureDetector(
        onSecondaryTapDown: (details) => _showTabContextMenu(context, details, tab),
        child: Material(
          color: isSelected
              ? colors.primary.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _tabsService.selectTabByIndex(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? colors.primary.withValues(alpha: 0.4)
                      : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    iconData,
                    size: 14,
                    color: isSelected ? colors.primary : colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 130),
                    child: Text(
                      tab.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? colors.onSurface : colors.onSurfaceVariant,
                      ),
                    ),
                  ),

                  // Call in progress indicator on tab
                  if (tab.hasActiveCall) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF00DC82),
                      ),
                    ),
                  ],

                  // Unread counter on tab
                  if (tab.unreadCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${tab.unreadCount}',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: colors.onPrimary,
                        ),
                      ),
                    ),
                  ],

                  // Close tab button (except for home tab)
                  if (!tab.isHome) ...[
                    const SizedBox(width: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => _tabsService.closeTab(tab.id),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          Icons.close_rounded,
                          size: 13,
                          color: isSelected
                              ? colors.onSurfaceVariant
                              : colors.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  const _WindowButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isClose = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isClose;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.transparent;
    Color fg = Theme.of(context).colorScheme.onSurfaceVariant;

    if (_hovered) {
      if (widget.isClose) {
        bg = const Color(0xFFE81123);
        fg = Colors.white;
      } else {
        bg = Theme.of(context).colorScheme.surfaceContainerHighest;
        fg = Theme.of(context).colorScheme.onSurface;
      }
    }

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Container(
            width: 40,
            height: 32,
            alignment: Alignment.center,
            color: bg,
            child: Icon(widget.icon, size: 14, color: fg),
          ),
        ),
      ),
    );
  }
}
