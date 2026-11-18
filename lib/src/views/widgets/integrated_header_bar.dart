import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexora/src/services/conversation_tabs_service.dart';
import 'package:nexora/src/services/local_data_service.dart';
import 'package:nexora/src/services/notification_service.dart';
import 'package:nexora/src/services/settings_services.dart';
import 'package:nexora/src/services/window_service.dart';
import 'package:nexora/src/views/widgets/app_theme.dart';

class IntegratedHeaderBar extends StatefulWidget implements PreferredSizeWidget {
  const IntegratedHeaderBar({
    super.key,
    this.minimal = false,
    this.onNewConversation,
    this.onSearchPressed,
    this.onNotificationsPressed,
    this.onToggleTheme,
    this.onOpenSettings,
    this.onOpenVault,
  });

  final bool minimal;
  final VoidCallback? onNewConversation;
  final VoidCallback? onSearchPressed;
  final VoidCallback? onNotificationsPressed;
  final VoidCallback? onToggleTheme;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenVault;

  @override
  State<IntegratedHeaderBar> createState() => _IntegratedHeaderBarState();

  @override
  Size get preferredSize => const Size.fromHeight(42);
}

typedef _CaptionArea = ({double width, double height, double left, double right});

class _IntegratedHeaderBarState extends State<IntegratedHeaderBar>
    with WidgetsBindingObserver {
  static const _captionChannel = MethodChannel('nexora/desktop_caption');
  final _tabsService = ConversationTabsService.instance;
  final _windowService = WindowService.instance;
  final _settingsService = SettingsService.instance;
  final _localData = LocalDataService.instance;
  final ScrollController _tabsScrollController = ScrollController();
  Animation<double>? _secondaryAnimation;
  _CaptionArea? _captionArea;
  bool _captionUpdateScheduled = false;
  bool _captionRequested = false;
  bool _darkCaption = false;
  double _topInset = 0;
  int _captionRequest = 0;

  bool get _supportsAndroidCaption =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _tabsService.addListener(_refresh);
    _settingsService.addListener(_refresh);
    _localData.addListener(_refresh);
    _windowService.addListener(_refresh);
    if (_supportsAndroidCaption) WidgetsBinding.instance.addObserver(this);
    if (_windowService.isDesktop) {
      _windowService.checkIsMaximized();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_supportsAndroidCaption) return;

    final animation = ModalRoute.of(context)?.secondaryAnimation;
    if (_secondaryAnimation != animation) {
      _secondaryAnimation?.removeStatusListener(_onRouteTransition);
      _secondaryAnimation = animation;
      animation?.addStatusListener(_onRouteTransition);
    }
    _darkCaption = Theme.of(context).brightness == Brightness.dark;
    _topInset = MediaQuery.paddingOf(context).top;
    _scheduleCaptionUpdate();
  }

  @override
  void didUpdateWidget(covariant IntegratedHeaderBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.minimal != widget.minimal) _scheduleCaptionUpdate();
  }

  @override
  void didChangeMetrics() => _scheduleCaptionUpdate();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _scheduleCaptionUpdate();
  }

  void _onRouteTransition(AnimationStatus status) => _scheduleCaptionUpdate();

  void _scheduleCaptionUpdate() {
    if (!_supportsAndroidCaption || _captionUpdateScheduled) return;
    _captionUpdateScheduled = true;
    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) {
      _captionUpdateScheduled = false;
      if (mounted) _updateCaption();
    });
    binding.ensureVisualUpdate();
  }

  Future<Map<String, double>?> _configureCaption({required bool enabled}) async {
    try {
      return await _captionChannel.invokeMapMethod<String, double>('update', {
        'enabled': enabled,
        'dark': _darkCaption,
        'topInset': _topInset,
        'minimumWidth': widget.minimal ? 240 : 600,
      });
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<void> _updateCaption() async {
    final request = ++_captionRequest;
    final enabled = _secondaryAnimation?.isDismissed ?? true;
    if (!enabled && !_captionRequested) return;
    _captionRequested = enabled;
    final result = await _configureCaption(enabled: enabled);
    if (!mounted || request != _captionRequest) return;

    final area = result == null
        ? null
        : (
            width: result['width']!,
            height: result['height']!,
            left: result['left']!,
            right: result['right']!,
          );
    if (_captionArea != area) setState(() => _captionArea = area);
  }

  @override
  void dispose() {
    if (_supportsAndroidCaption) {
      WidgetsBinding.instance.removeObserver(this);
      _secondaryAnimation?.removeStatusListener(_onRouteTransition);
      if (_captionRequested) _configureCaption(enabled: false);
    }
    _tabsService.removeListener(_refresh);
    _settingsService.removeListener(_refresh);
    _localData.removeListener(_refresh);
    _windowService.removeListener(_refresh);
    _tabsScrollController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _showTabContextMenu(BuildContext context, TapDownDetails details, ConversationTab tab) {
    _showTabContextMenuAt(context, details.globalPosition, tab);
  }

  void _showTabContextMenuAt(BuildContext context, Offset globalPosition, ConversationTab tab) {
    if (tab.isHome) return;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

  void _showNetworkStatusDialog(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final user = _localData.currentUser;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isStealth = _settingsService.settings.stealthMode;
          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00DC82).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shield_outlined, color: Color(0xFF00DC82), size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rede P2P & Segurança',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Conexão direta e descentralizada',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        _infoMetricRow(
                          icon: Icons.lock_outline_rounded,
                          label: 'Criptografia',
                          value: 'Ed25519 • AES-256-GCM',
                          color: colors.primary,
                        ),
                        const SizedBox(height: 8),
                        _infoMetricRow(
                          icon: Icons.swap_calls_rounded,
                          label: 'Áudio & Vídeo',
                          value: 'DTLS-SRTP 4K@60fps',
                          color: const Color(0xFF00DC82),
                        ),
                        const SizedBox(height: 8),
                        _infoMetricRow(
                          icon: Icons.hub_outlined,
                          label: 'Topologia',
                          value: 'P2P Direto (Sem Servidor Central)',
                          color: Colors.blueAccent,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    dense: true,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.3)),
                    ),
                    secondary: Icon(
                      isStealth ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: isStealth ? colors.primary : colors.onSurfaceVariant,
                      size: 20,
                    ),
                    title: const Text('Modo Furtivo (Anti-Ombro)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Oculta mensagens sensíveis com desfoque temporário', style: TextStyle(fontSize: 11)),
                    value: isStealth,
                    onChanged: (val) async {
                      await _settingsService.updateSetting((st) => st.copyWith(stealthMode: val));
                      setDialogState(() {});
                    },
                  ),
                  if (user.publicKey.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copiar meu código de contato P2P', style: TextStyle(fontSize: 12)),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: user.publicKey));
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Código de contato copiado para a área de transferência.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _infoMetricRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDesktop = _windowService.isDesktop;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeCallTab = _tabsService.getTabWithActiveCall();
    final isCallInBackground = activeCallTab != null && activeCallTab.id != _tabsService.activeTab.id;
    final currentUser = _localData.currentUser;

    final topPadding = MediaQuery.paddingOf(context).top;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final caption = _captionArea;
    final useCaption = caption != null &&
        (caption.width - screenWidth).abs() < 1 &&
        (caption.height - topPadding).abs() < 1;
    final isMobile = !isDesktop && screenWidth < 600;
    final hasSubBar = isMobile && !widget.minimal;
    final barHeight = 42.0 + (hasSubBar ? 38.0 : 0.0);
    final totalHeight = useCaption
        ? math.max(barHeight, caption.height)
        : barHeight + (isDesktop ? 0.0 : topPadding);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: isDesktop ? (_) => _windowService.startDragging() : null,
      onDoubleTap: isDesktop ? () => _windowService.toggleMaximize() : null,
      child: Container(
        height: totalHeight,
        padding: useCaption
            ? EdgeInsets.only(left: caption.left, right: caption.right)
            : EdgeInsets.only(top: isDesktop ? 0.0 : topPadding),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(
            bottom: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.35)),
          ),
        ),
        child: hasSubBar
            ? Column(
                children: [
                  // Tier 1: Main Header Row (Mobile)
                  SizedBox(
                    height: 42,
                    child: Row(
                      children: [
                        // Left: Brand & P2P Status Pill
                        Padding(
                          padding: const EdgeInsets.only(left: 12, right: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const BrandMark(size: 22),
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
                              _NetworkStatusPill(
                                onTap: () => _showNetworkStatusDialog(context),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),

                        // Right actions on mobile
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isCallInBackground)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Material(
                                  color: const Color(0xFF00DC82).withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(999),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(999),
                                    onTap: () => _tabsService.selectTabById(activeCallTab.id),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(
                                          color: const Color(0xFF00DC82).withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.phone_in_talk_rounded,
                                        size: 13,
                                        color: Color(0xFF00DC82),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                            // Search icon button on mobile
                            if (widget.onSearchPressed != null)
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Buscar',
                                icon: const Icon(Icons.search_rounded, size: 19),
                                onPressed: widget.onSearchPressed,
                              ),

                            // Theme toggle button
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: isDark ? 'Modo Claro' : 'Modo Escuro',
                              icon: Icon(
                                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                                size: 17,
                              ),
                              onPressed: widget.onToggleTheme ??
                                  () => _settingsService.updateSetting(
                                        (s) => s.copyWith(isDarkMode: !s.isDarkMode),
                                      ),
                            ),

                            // Notifications Bell
                            ListenableBuilder(
                              listenable: NotificationService.instance,
                              builder: (context, _) {
                                final count = NotificationService.instance.history.length;
                                return IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Notificações',
                                  onPressed: widget.onNotificationsPressed,
                                  icon: Badge(
                                    isLabelVisible: count > 0,
                                    smallSize: 7,
                                    child: const Icon(Icons.notifications_none_rounded, size: 18),
                                  ),
                                );
                              },
                            ),

                            // User Profile Capsule
                            if (currentUser.publicKey.isNotEmpty) ...[
                              const SizedBox(width: 2),
                              _UserProfileCapsule(
                                nickname: currentUser.nickname,
                                publicKey: currentUser.publicKey,
                                onOpenVault: widget.onOpenVault ?? () {},
                                onOpenSettings: widget.onOpenSettings ?? () {},
                              ),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Tier 2: Sub-Bar (Mobile Tabs Strip or Search Capsule)
                  SizedBox(
                    height: 38,
                    child: _tabsService.tabs.length > 1
                        ? Padding(
                            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
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
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 2),
                                      child: Material(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(6),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(6),
                                          onTap: widget.onNewConversation,
                                          child: Padding(
                                            padding: const EdgeInsets.all(5),
                                            child: Icon(
                                              Icons.add_rounded,
                                              size: 16,
                                              color: colors.onSurfaceVariant.withValues(alpha: 0.8),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                            child: _MobileSearchCapsule(
                              onTap: widget.onSearchPressed ?? () {},
                            ),
                          ),
                  ),
                ],
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 780;

                  return Row(
                    children: [
                      // Left: App Brand & P2P Status Pill
                      Padding(
                        padding: const EdgeInsets.only(left: 12, right: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const BrandMark(size: 22),
                            const SizedBox(width: 8),
                            const Text(
                              'Nexora',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                fontSize: 14,
                              ),
                            ),
                            if (!widget.minimal) ...[
                              const SizedBox(width: 8),
                              _NetworkStatusPill(
                                onTap: () => _showNetworkStatusDialog(context),
                              ),
                            ],
                          ],
                        ),
                      ),

                      if (!widget.minimal) ...[
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
                                    padding: const EdgeInsets.symmetric(horizontal: 2),
                                    child: Material(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(6),
                                        onTap: widget.onNewConversation,
                                        child: Padding(
                                          padding: const EdgeInsets.all(5),
                                          child: Icon(
                                            Icons.add_rounded,
                                            size: 16,
                                            color: colors.onSurfaceVariant.withValues(alpha: 0.8),
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

                        // Search Capsule (visible on wider screens)
                        if (isWide && widget.onSearchPressed != null) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: _SearchBarCapsule(onTap: widget.onSearchPressed!),
                          ),
                        ],
                      ] else ...[
                        const Spacer(),
                      ],

                      // Right side: Active call banner, Quick Actions, and Window Controls
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!widget.minimal) ...[
                            // Return to Active Call Pill (if calling in another tab)
                            if (isCallInBackground)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Material(
                                  color: const Color(0xFF00DC82).withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(999),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(999),
                                    onTap: () => _tabsService.selectTabById(activeCallTab.id),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
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
                                            size: 13,
                                            color: Color(0xFF00DC82),
                                          ),
                                          SizedBox(width: 5),
                                          Text(
                                            'Chamada ativa',
                                            style: TextStyle(
                                              color: Color(0xFF00DC82),
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                            // Compact Search Button (when search capsule is hidden)
                            if (!isWide && widget.onSearchPressed != null)
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Buscar (Ctrl+K)',
                                icon: const Icon(Icons.search_rounded, size: 18),
                                onPressed: widget.onSearchPressed,
                              ),

                            // Quick Theme Toggle (Sol / Lua)
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                tooltip: isDark ? 'Modo Claro' : 'Modo Escuro',
                                icon: Icon(
                                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                                  size: 16,
                                ),
                                onPressed: widget.onToggleTheme ??
                                    () => _settingsService.updateSetting(
                                          (s) => s.copyWith(isDarkMode: !s.isDarkMode),
                                        ),
                              ),
                            ),

                            // Notifications Bell
                            ListenableBuilder(
                              listenable: NotificationService.instance,
                              builder: (context, _) {
                                final count = NotificationService.instance.history.length;
                                return SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    tooltip: 'Notificações',
                                    onPressed: widget.onNotificationsPressed,
                                    icon: Badge(
                                      isLabelVisible: count > 0,
                                      smallSize: 7,
                                      child: const Icon(Icons.notifications_none_rounded, size: 17),
                                    ),
                                  ),
                                );
                              },
                            ),

                            // User Profile Capsule Menu
                            if (currentUser.publicKey.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              _UserProfileCapsule(
                                nickname: currentUser.nickname,
                                publicKey: currentUser.publicKey,
                                onOpenVault: widget.onOpenVault ?? () {},
                                onOpenSettings: widget.onOpenSettings ?? () {},
                              ),
                            ],
                          ] else ...[
                            // Quick Theme Toggle for Minimal Header (Sign-in / onboarding)
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                tooltip: isDark ? 'Modo Claro' : 'Modo Escuro',
                                icon: Icon(
                                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                                  size: 16,
                                ),
                                onPressed: widget.onToggleTheme ??
                                    () => _settingsService.updateSetting(
                                          (s) => s.copyWith(isDarkMode: !s.isDarkMode),
                                        ),
                              ),
                            ),
                          ],

                          // Desktop Window Action Buttons (Minimize, Maximize, Close)
                          if (isDesktop) ...[
                            const SizedBox(width: 6),
                            SizedBox(
                              height: 14,
                              child: VerticalDivider(
                                width: 1,
                                thickness: 1,
                                color: colors.outlineVariant.withValues(alpha: 0.35),
                              ),
                            ),
                            const SizedBox(width: 4),
                            _WindowButton.minimize(
                              onPressed: _windowService.minimize,
                            ),
                            _WindowButton.maximize(
                              isMaximized: _windowService.isMaximized,
                              onPressed: _windowService.toggleMaximize,
                            ),
                            _WindowButton.close(
                              onPressed: _windowService.close,
                            ),
                          ],
                        ],
                      ),
                    ],
                  );
                },
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
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: GestureDetector(
        onSecondaryTapDown: (details) => _showTabContextMenuAt(context, details.globalPosition, tab),
        onLongPressStart: (details) => _showTabContextMenuAt(context, details.globalPosition, tab),
        child: Material(
          color: isSelected
              ? colors.surfaceContainerHighest.withValues(alpha: 0.65)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _tabsService.selectTabByIndex(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    iconData,
                    size: 13,
                    color: isSelected ? colors.primary : colors.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 130),
                    child: Text(
                      tab.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? colors.onSurface : colors.onSurfaceVariant,
                      ),
                    ),
                  ),

                  // Call in progress indicator on tab
                  if (tab.hasActiveCall) ...[
                    const SizedBox(width: 5),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF00DC82),
                      ),
                    ),
                  ],

                  // Unread counter on tab
                  if (tab.unreadCount > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${tab.unreadCount}',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: colors.onPrimary,
                        ),
                      ),
                    ),
                  ],

                  // Close tab button (except for home tab)
                  if (!tab.isHome) ...[
                    const SizedBox(width: 4),
                    InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () => _tabsService.closeTab(tab.id),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          Icons.close_rounded,
                          size: 12,
                          color: colors.onSurfaceVariant.withValues(alpha: 0.6),
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
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.builder,
    this.isClose = false,
  });

  factory _WindowButton.minimize({
    Key? key,
    required VoidCallback onPressed,
  }) {
    return _WindowButton(
      key: key,
      tooltip: 'Minimizar',
      onPressed: onPressed,
      builder: (color) => CustomPaint(
        size: const Size(10, 10),
        painter: _MinimizePainter(color),
      ),
    );
  }

  factory _WindowButton.maximize({
    Key? key,
    required bool isMaximized,
    required VoidCallback onPressed,
  }) {
    return _WindowButton(
      key: key,
      tooltip: isMaximized ? 'Restaurar' : 'Maximizar',
      onPressed: onPressed,
      builder: (color) => CustomPaint(
        size: const Size(10, 10),
        painter: isMaximized ? _RestorePainter(color) : _MaximizePainter(color),
      ),
    );
  }

  factory _WindowButton.close({
    Key? key,
    required VoidCallback onPressed,
  }) {
    return _WindowButton(
      key: key,
      tooltip: 'Fechar',
      isClose: true,
      onPressed: onPressed,
      builder: (color) => CustomPaint(
        size: const Size(10, 10),
        painter: _ClosePainter(color),
      ),
    );
  }

  final String tooltip;
  final VoidCallback onPressed;
  final Widget Function(Color color) builder;
  final bool isClose;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.transparent;
    Color fg = Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.85);

    if (_hovered) {
      if (widget.isClose) {
        bg = const Color(0xFFE81123);
        fg = Colors.white;
      } else {
        bg = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08);
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
            width: 46,
            height: double.infinity,
            alignment: Alignment.center,
            color: bg,
            child: widget.builder(fg),
          ),
        ),
      ),
    );
  }
}

class _MinimizePainter extends CustomPainter {
  final Color color;
  const _MinimizePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    // Align line horizontally at the vertical center (matching center of maximize and close icons)
    final y = size.height / 2;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }

  @override
  bool shouldRepaint(_MinimizePainter oldDelegate) => oldDelegate.color != color;
}

class _MaximizePainter extends CustomPainter {
  final Color color;
  const _MaximizePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(Rect.fromLTWH(0.5, 0.5, size.width - 1.0, size.height - 1.0), paint);
  }

  @override
  bool shouldRepaint(_MaximizePainter oldDelegate) => oldDelegate.color != color;
}

class _RestorePainter extends CustomPainter {
  final Color color;
  const _RestorePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Back square (top right)
    final backPath = Path()
      ..moveTo(2.5, 0.5)
      ..lineTo(size.width - 0.5, 0.5)
      ..lineTo(size.width - 0.5, size.height - 2.5)
      ..lineTo(size.width - 2.5, size.height - 2.5)
      ..moveTo(2.5, 0.5)
      ..lineTo(2.5, 2.5);
    canvas.drawPath(backPath, paint);

    // Front square (bottom left)
    canvas.drawRect(Rect.fromLTWH(0.5, 2.5, size.width - 3.0, size.height - 3.0), paint);
  }

  @override
  bool shouldRepaint(_RestorePainter oldDelegate) => oldDelegate.color != color;
}

class _ClosePainter extends CustomPainter {
  final Color color;
  const _ClosePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawLine(const Offset(0.5, 0.5), Offset(size.width - 0.5, size.height - 0.5), paint);
    canvas.drawLine(Offset(size.width - 0.5, 0.5), Offset(0.5, size.height - 0.5), paint);
  }

  @override
  bool shouldRepaint(_ClosePainter oldDelegate) => oldDelegate.color != color;
}

class _SearchBarCapsule extends StatefulWidget {
  const _SearchBarCapsule({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_SearchBarCapsule> createState() => _SearchBarCapsuleState();
}

class _SearchBarCapsuleState extends State<_SearchBarCapsule> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 27,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _hovered
                ? colors.surfaceContainerHighest.withValues(alpha: 0.8)
                : colors.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hovered
                  ? colors.primary.withValues(alpha: 0.45)
                  : colors.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_rounded,
                size: 13.5,
                color: _hovered ? colors.primary : colors.onSurfaceVariant.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 7),
              Text(
                'Buscar ou comandos...',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: colors.onSurfaceVariant.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  'Ctrl K',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    color: colors.onSurfaceVariant.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NetworkStatusPill extends StatelessWidget {
  const _NetworkStatusPill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Rede P2P & Segurança • Clique para detalhes',
      waitDuration: const Duration(milliseconds: 500),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF00DC82).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: const Color(0xFF00DC82).withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5.5,
                  height: 5.5,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00DC82),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                const Text(
                  'P2P',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF00DC82),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserProfileCapsule extends StatelessWidget {
  const _UserProfileCapsule({
    required this.nickname,
    required this.publicKey,
    required this.onOpenVault,
    required this.onOpenSettings,
  });

  final String nickname;
  final String publicKey;
  final VoidCallback onOpenVault;
  final VoidCallback onOpenSettings;

  void _showMenu(BuildContext context, TapDownDetails details) {
    final colors = Theme.of(context).colorScheme;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    final shortKey = publicKey.length > 10
        ? '${publicKey.substring(0, 5)}...${publicKey.substring(publicKey.length - 4)}'
        : publicKey;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        details.globalPosition & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nickname.isNotEmpty ? nickname : 'Meu Perfil',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'ID: $shortKey',
                style: TextStyle(
                  fontSize: 10.5,
                  fontFamily: 'monospace',
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              const Divider(height: 1),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'copy_key',
          child: Row(
            children: const [
              Icon(Icons.copy_rounded, size: 16),
              SizedBox(width: 10),
              Text('Copiar código de contato'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'vault',
          child: Row(
            children: const [
              Icon(Icons.bookmark_rounded, size: 16),
              SizedBox(width: 10),
              Text('Mensagens Salvas'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'settings',
          child: Row(
            children: const [
              Icon(Icons.settings_outlined, size: 16),
              SizedBox(width: 10),
              Text('Configurações'),
            ],
          ),
        ),
      ],
    ).then((value) async {
      if (value == 'copy_key' && publicKey.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: publicKey));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Código de contato copiado para a área de transferência.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else if (value == 'vault') {
        onOpenVault();
      } else if (value == 'settings') {
        onOpenSettings();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final initial = nickname.isNotEmpty ? nickname[0].toUpperCase() : 'N';
    return GestureDetector(
      onTapDown: (details) => _showMenu(context, details),
      child: Tooltip(
        message: nickname.isNotEmpty ? '$nickname (Meu Perfil)' : 'Meu Perfil',
        child: Container(
          width: 25,
          height: 25,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: colors.primary.withValues(alpha: 0.4),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            initial,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: colors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileSearchCapsule extends StatelessWidget {
  const _MobileSearchCapsule({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          height: 31,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                size: 15,
                color: colors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Buscar conversas, canais ou comandos...',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w400,
                  color: colors.onSurfaceVariant.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
