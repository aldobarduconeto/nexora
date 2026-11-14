import 'package:flutter/material.dart';
import 'package:nexora/src/utils/app_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nexora/src/utils/app_locale.dart';
import 'package:nexora/src/services/conversation_tabs_service.dart';
import 'package:nexora/src/services/local_data_service.dart';
import 'package:nexora/src/services/notification_service.dart';
import 'package:nexora/src/services/permission_service.dart';
import 'package:nexora/src/services/scheduled_message_service.dart';
import 'package:nexora/src/services/settings_services.dart';
import 'package:nexora/src/views/communities.dart';
import 'package:nexora/src/views/home.dart';
import 'package:nexora/src/views/p2p_chat.dart';
import 'package:nexora/src/views/settings.dart';
import 'package:nexora/src/views/sign_in.dart';
import 'package:nexora/src/views/welcome_permissions_view.dart';
import 'package:nexora/src/views/widgets/app_theme.dart';
import 'package:nexora/src/views/widgets/integrated_header_bar.dart';
import 'package:nexora/src/views/widgets/push_notification_banner.dart';

class App extends StatefulWidget {
  const App({super.key});
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  final _settings = SettingsService.instance;
  final _user = LocalDataService.instance;
  final _permissions = PermissionService.instance;
  final _tabs = ConversationTabsService.instance;
  late Future<bool> _initialization;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settings.addListener(_refresh);
    _user.addListener(_refresh);
    _tabs.addListener(_refresh);
    _initialization = _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settings.removeListener(_refresh);
    _user.removeListener(_refresh);
    _tabs.removeListener(_refresh);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _permissions.refreshPermissions();
    }
  }

  Future<bool> _initialize() async {
    await _settings.load();
    await ScheduledMessageService.instance.load();
    await _permissions.initializeAndRequestOnFirstLaunch();
    await NotificationService.instance.initialize();
    final restored = await LocalDataService.instance.restoreSession();
    if (restored) {
      await LocalDataService.instance.load(
        LocalDataService.instance.currentUser.id,
        retentionMinutes: _settings.settings.localRetentionMinutes,
      );
    }
    return restored;
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _copyOwnKey(BuildContext context) async {
    final key = _user.currentUser.publicKey;
    if (key.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: key));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sua chave pública foi copiada.'),
        ),
      );
    }
  }

  void _showNotificationsSheet(BuildContext context) {
    final notifications = NotificationService.instance;
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF131826) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final history = notifications.history;
          return DraggableScrollableSheet(
            initialChildSize: 0.65,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) => Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.notifications_active_rounded, color: colors.primary, size: 22),
                          const SizedBox(width: 10),
                          const Text(
                            'Central de Notificações',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                          ),
                        ],
                      ),
                      if (history.isNotEmpty)
                        TextButton(
                          onPressed: () async {
                            await notifications.clearHistory();
                            setSheetState(() {});
                          },
                          child: const Text('Limpar Tudo'),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: history.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.notifications_none_rounded, size: 52, color: colors.onSurfaceVariant.withOpacity(0.5)),
                              const SizedBox(height: 12),
                              Text(
                                'Nenhuma notificação recente',
                                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          itemCount: history.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final item = history[i];
                            return ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: colors.primary.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.notifications_outlined, color: colors.primary, size: 20),
                              ),
                              title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                              subtitle: Text(item.body, style: TextStyle(fontSize: 12.5, color: colors.onSurfaceVariant)),
                              trailing: Text(
                                '${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showNewConversationDialog(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Criar ou Abrir Conversa',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.person_add_alt_1_rounded, color: colors.primary),
                ),
                title: const Text('Nova conversa P2P'),
                subtitle: const Text('Iniciar chat direto com uma chave pública Ed25519'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _index = 0);
                  ConversationTabsService.instance.openHome();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.group_add_outlined, color: colors.secondary),
                ),
                title: const Text('Criar grupo P2P'),
                subtitle: const Text('Criar uma sala em malha ponto a ponto'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _index = 0);
                  ConversationTabsService.instance.openHome();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.tertiary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.bookmark_rounded, color: colors.tertiary),
                ),
                title: const Text('Mensagens Salvas'),
                subtitle: const Text('Seu cofre de notas e arquivos criptografados'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final vault = await _user.getOrCreateSavedMessages();
                  ConversationTabsService.instance.openConversation(
                    vault,
                    title: 'Mensagens Salvas',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuickSearchDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final colors = Theme.of(context).colorScheme;
          String q = '';
          return AlertDialog(
            contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: SizedBox(
              width: 520,
              height: 400,
              child: StatefulBuilder(
                builder: (context, setInnerState) {
                  final matches = _user.conversations.where((c) {
                    final name = _user.conversationName(c).toLowerCase();
                    return name.contains(q.toLowerCase());
                  }).toList();

                  return Column(
                    children: [
                      TextField(
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Buscar conversa ou grupo...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: colors.outlineVariant),
                          ),
                        ),
                        onChanged: (val) => setInnerState(() => q = val.trim()),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: matches.isEmpty
                            ? Center(
                                child: Text(
                                  'Nenhuma conversa encontrada.',
                                  style: TextStyle(color: colors.onSurfaceVariant),
                                ),
                              )
                            : ListView.builder(
                                itemCount: matches.length,
                                itemBuilder: (context, i) {
                                  final conv = matches[i];
                                  final name = _user.conversationName(conv);
                                  return ListTile(
                                    leading: CircleAvatar(
                                      child: Icon(
                                        conv.isSavedMessages
                                            ? Icons.bookmark_rounded
                                            : (conv.isGroup
                                                ? Icons.groups_rounded
                                                : Icons.person_rounded),
                                        size: 18,
                                      ),
                                    ),
                                    title: Text(name),
                                    subtitle: Text(
                                      conv.isSavedMessages
                                          ? 'Cofre Pessoal'
                                          : (conv.isGroup
                                              ? 'Grupo P2P'
                                              : (conv.isCommunity
                                                  ? 'Comunidade'
                                                  : 'Conversa Direta')),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                    onTap: () {
                                      Navigator.pop(dialogCtx);
                                      ConversationTabsService.instance.openConversation(
                                        conv,
                                        title: name,
                                      );
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _settings.settings;
    final accent = AppTheme.resolveAccentColor(s.accentColor);
    return MaterialApp(
      title: 'Nexora',
      locale: AppLocale.fromPreference(s.languageCode),
      supportedLocales: AppLocale.supported,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(
        s.isDarkMode ? Brightness.dark : Brightness.light,
        accent,
        s.animationsEnabled,
        isAmoled: s.isAmoledMode,
        cardRadius: s.cardRadius,
      ),
      themeAnimationDuration: s.animationsEnabled
          ? const Duration(milliseconds: 180)
          : Duration.zero,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: _PreferenceTextScaler(
              media.textScaler,
              s.fontSize / 14,
            ),
            disableAnimations: media.disableAnimations || !s.animationsEnabled,
          ),
          child: Stack(
            children: [
              child!,
              const PushNotificationBanner(),
            ],
          ),
        );
      },
      home: FutureBuilder<bool>(
        future: _initialization,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              size: 44,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Armazenamento Seguro Indisponível',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Não foi possível carregar os dados locais com segurança.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 22),
                            FilledButton.icon(
                              onPressed: () => setState(
                                () => _initialization = _initialize(),
                              ),
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Tentar novamente'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.data == true) {
            if (!_settings.settings.hasCompletedWelcome) {
              return Scaffold(
                body: Column(
                  children: [
                    const IntegratedHeaderBar(minimal: true),
                    Expanded(
                      child: WelcomePermissionsView(
                        onCompleted: () => setState(() {}),
                      ),
                    ),
                  ],
                ),
              );
            }
            return _shell();
          }
          return Scaffold(
            body: Column(
              children: [
                const IntegratedHeaderBar(minimal: true),
                Expanded(
                  child: SignInPage(
                    onSignedIn: () => setState(() => _initialization = _initialize()),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _shell() => LayoutBuilder(
    builder: (context, constraints) {
      final s = _settings.settings;
      final wide = switch (s.navigationStyle) {
        'side' => constraints.maxWidth >= 540,
        'bottom' => false,
        _ => constraints.maxWidth >= 820,
      };
      final colors = Theme.of(context).colorScheme;
      final homeContent = IndexedStack(
        index: _index,
        children: const [HomePage(), CommunitiesPage(), SettingsPage()],
      );

      final tabsService = _tabs;
      final conversationTabs =
          tabsService.tabs.where((t) => !t.isHome).toList();

      Widget bodyContent;
      if (tabsService.isHomeActive) {
        bodyContent = wide
            ? Row(
                children: [
                  _ModernActivityRail(
                    selectedIndex: _index,
                    onDestinationSelected: (value) =>
                        setState(() => _index = value),
                    extended: constraints.maxWidth >= 1140,
                    onOpenVault: () async {
                      final vault = await _user.getOrCreateSavedMessages();
                      ConversationTabsService.instance.openConversation(
                        vault,
                        title: 'Mensagens Salvas',
                      );
                    },
                    onToggleTheme: () {
                      _settings.updateSetting(
                        (st) => st.copyWith(isDarkMode: !st.isDarkMode),
                      );
                    },
                    isDarkMode: s.isDarkMode,
                  ),
                  Expanded(child: homeContent),
                ],
              )
            : homeContent;
      } else {
        final activeIndex = conversationTabs.indexWhere(
          (t) => t.id == tabsService.activeTab.id,
        );
        bodyContent = IndexedStack(
          index: activeIndex != -1 ? activeIndex : 0,
          children: [
            for (final tab in conversationTabs)
              KeyedSubtree(
                key: ValueKey('tab_${tab.id}'),
                child: P2PChatPage(
                  conversation: tab.conversation!,
                  conversationTitle: tab.title,
                  isTabMode: true,
                ),
              ),
          ],
        );
      }

      return Scaffold(
        body: Column(
          children: [
            IntegratedHeaderBar(
              onNewConversation: () => _showNewConversationDialog(context),
              onSearchPressed: () => _showQuickSearchDialog(context),
              onNotificationsPressed: () => _showNotificationsSheet(context),
            ),
            Expanded(child: bodyContent),
          ],
        ),
        bottomNavigationBar: (wide || !tabsService.isHomeActive)
            ? null
            : Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: 0.7),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: NavigationBar(
                    height: 64,
                    backgroundColor: Colors.transparent,
                    selectedIndex: _index,
                    onDestinationSelected: (value) =>
                        setState(() => _index = value),
                    destinations: [
                      NavigationDestination(
                        icon: Icon(Icons.chat_bubble_outline_rounded),
                        selectedIcon: Icon(Icons.chat_bubble_rounded),
                        label: AppText.chats.of(context),
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.hub_outlined),
                        selectedIcon: Icon(Icons.hub_rounded),
                        label: AppText.communities.of(context),
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.tune_rounded),
                        selectedIcon: Icon(Icons.tune_rounded),
                        label: AppText.settings.of(context),
                      ),
                    ],
                  ),
                ),
              ),
      );
    },
  );
}

class _ModernActivityRail extends StatelessWidget {
  const _ModernActivityRail({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.extended,
    required this.onOpenVault,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool extended;
  final VoidCallback onOpenVault;
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final width = extended ? 220.0 : 72.0;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.18),
        border: Border(
          right: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.45),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Nav items
          _railItem(
            context,
            index: 0,
            icon: Icons.chat_bubble_outline_rounded,
            selectedIcon: Icons.chat_bubble_rounded,
            label: AppText.chats.of(context),
          ),
          const SizedBox(height: 6),
          _railItem(
            context,
            index: 1,
            icon: Icons.hub_outlined,
            selectedIcon: Icons.hub_rounded,
            label: AppText.communities.of(context),
          ),
          const SizedBox(height: 6),
          _railItem(
            context,
            index: 2,
            icon: Icons.tune_rounded,
            selectedIcon: Icons.tune_rounded,
            label: AppText.settings.of(context),
          ),

          const Spacer(),

          // Vault Quick Action
          Padding(
            padding: EdgeInsets.symmetric(horizontal: extended ? 12 : 8, vertical: 4),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onOpenVault,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    mainAxisAlignment: extended ? MainAxisAlignment.start : MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bookmark_rounded, size: 20, color: colors.primary),
                      if (extended) ...[
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Mensagens Salvas',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Theme toggle action
          Padding(
            padding: EdgeInsets.symmetric(horizontal: extended ? 12 : 8, vertical: 4),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onToggleTheme,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    mainAxisAlignment: extended ? MainAxisAlignment.start : MainAxisAlignment.center,
                    children: [
                      Icon(
                        isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                        size: 20,
                        color: colors.onSurfaceVariant,
                      ),
                      if (extended) ...[
                        const SizedBox(width: 12),
                        Text(
                          isDarkMode ? 'Tema Claro' : 'Tema Escuro',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _railItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
  }) {
    final colors = Theme.of(context).colorScheme;
    final isSelected = selectedIndex == index;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: extended ? 12 : 8),
      child: Material(
        color: isSelected
            ? colors.primary.withValues(alpha: 0.16)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onDestinationSelected(index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? colors.primary.withValues(alpha: 0.35)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: extended ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Icon(
                  isSelected ? selectedIcon : icon,
                  size: 21,
                  color: isSelected ? colors.primary : colors.onSurfaceVariant,
                ),
                if (extended) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? colors.primary : colors.onSurface,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreferenceTextScaler extends TextScaler {
  const _PreferenceTextScaler(this.system, this.factor);
  final TextScaler system;
  final double factor;
  @override
  double scale(double fontSize) => system.scale(fontSize) * factor;
  @override
  double get textScaleFactor => system.scale(14) / 14 * factor;
}
