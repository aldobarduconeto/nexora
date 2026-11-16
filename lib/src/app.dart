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
          final isDark = Theme.of(context).brightness == Brightness.dark;
          String q = '';

          final isMobile = MediaQuery.sizeOf(context).width < 600;
          final maxH = (MediaQuery.sizeOf(context).height * 0.78).clamp(320.0, 520.0);

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
            backgroundColor: isDark ? const Color(0xFF111728) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 540, maxHeight: maxH),
              child: StatefulBuilder(
                builder: (context, setInnerState) {
                  final queryLower = q.toLowerCase();

                  final matchingConversations = _user.conversations.where((c) {
                    if (queryLower.isEmpty) return true;
                    final name = _user.conversationName(c).toLowerCase();
                    final lastMsg = c.messages.isNotEmpty ? c.messages.last.textMsg.toLowerCase() : '';
                    return name.contains(queryLower) || lastMsg.contains(queryLower);
                  }).take(queryLower.isEmpty ? 5 : 20).toList();

                  final allActions = [
                    (
                      id: 'nova_conversa',
                      title: 'Nova conversa direta P2P',
                      icon: Icons.person_add_rounded,
                      action: () {
                        Navigator.pop(dialogCtx);
                        _showNewConversationDialog(context);
                      },
                    ),
                    (
                      id: 'novo_grupo',
                      title: 'Criar grupo P2P',
                      icon: Icons.group_add_rounded,
                      action: () {
                        Navigator.pop(dialogCtx);
                        setState(() => _index = 0);
                        ConversationTabsService.instance.openHome();
                      },
                    ),
                    (
                      id: 'vault',
                      title: 'Mensagens Salvas (Cofre Criptografado)',
                      icon: Icons.bookmark_rounded,
                      action: () async {
                        Navigator.pop(dialogCtx);
                        final vault = await _user.getOrCreateSavedMessages();
                        ConversationTabsService.instance.openConversation(
                          vault,
                          title: 'Mensagens Salvas',
                        );
                      },
                    ),
                    (
                      id: 'comunidades',
                      title: 'Explorar Comunidades P2P',
                      icon: Icons.hub_rounded,
                      action: () {
                        Navigator.pop(dialogCtx);
                        setState(() => _index = 1);
                        ConversationTabsService.instance.openHome();
                      },
                    ),
                    (
                      id: 'tema',
                      title: isDark ? 'Ativar Modo Claro' : 'Ativar Modo Escuro',
                      icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                      action: () {
                        Navigator.pop(dialogCtx);
                        _settings.updateSetting((s) => s.copyWith(isDarkMode: !s.isDarkMode));
                      },
                    ),
                    (
                      id: 'stealth',
                      title: 'Alternar Modo Furtivo (Anti-Ombro)',
                      icon: Icons.visibility_off_rounded,
                      action: () {
                        Navigator.pop(dialogCtx);
                        _settings.updateSetting((s) => s.copyWith(stealthMode: !s.stealthMode));
                      },
                    ),
                    (
                      id: 'chave',
                      title: 'Copiar meu código de contato P2P',
                      icon: Icons.copy_rounded,
                      action: () {
                        Navigator.pop(dialogCtx);
                        _copyOwnKey(context);
                      },
                    ),
                    (
                      id: 'configuracoes',
                      title: 'Abrir Configurações',
                      icon: Icons.tune_rounded,
                      action: () {
                        Navigator.pop(dialogCtx);
                        setState(() => _index = 2);
                        ConversationTabsService.instance.openHome();
                      },
                    ),
                  ];

                  final matchingActions = allActions.where((a) {
                    if (queryLower.isEmpty) return true;
                    return a.title.toLowerCase().contains(queryLower);
                  }).toList();

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Search Bar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                        child: TextField(
                          autofocus: true,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Buscar conversas, mensagens ou digitar comando...',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                            prefixIcon: Icon(Icons.search_rounded, color: colors.primary, size: 20),
                            suffixIcon: q.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18),
                                    onPressed: () => setInnerState(() => q = ''),
                                  )
                                : (isMobile
                                    ? IconButton(
                                        icon: const Icon(Icons.close_rounded, size: 20),
                                        onPressed: () => Navigator.pop(dialogCtx),
                                      )
                                    : Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(5),
                                          border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)),
                                        ),
                                        child: Text(
                                          'ESC',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                      )),
                            filled: true,
                            fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.35),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: colors.primary.withValues(alpha: 0.7), width: 1.5),
                            ),
                          ),
                          onChanged: (val) => setInnerState(() => q = val.trim()),
                        ),
                      ),
                      const Divider(height: 1),

                      // Results List
                      Flexible(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shrinkWrap: true,
                          children: [
                            if (matchingConversations.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
                                child: Text(
                                  queryLower.isEmpty ? 'CONVERSAS RECENTES' : 'CONVERSAS ENCONTRADAS',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                    color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                              for (final conv in matchingConversations) ...[
                                ListTile(
                                  dense: true,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  leading: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: colors.primary.withValues(alpha: 0.12),
                                    child: Icon(
                                      conv.isSavedMessages
                                          ? Icons.bookmark_rounded
                                          : (conv.isGroup
                                              ? Icons.groups_rounded
                                              : (conv.isCommunity ? Icons.hub_rounded : Icons.person_rounded)),
                                      size: 16,
                                      color: colors.primary,
                                    ),
                                  ),
                                  title: Text(
                                    _user.conversationName(conv),
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text(
                                    conv.messages.isNotEmpty
                                        ? conv.messages.last.textMsg
                                        : (conv.isSavedMessages ? 'Cofre Pessoal Criptografado' : 'Sem mensagens ainda'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
                                  ),
                                  onTap: () {
                                    Navigator.pop(dialogCtx);
                                    ConversationTabsService.instance.openConversation(
                                      conv,
                                      title: _user.conversationName(conv),
                                    );
                                  },
                                ),
                              ],
                              const SizedBox(height: 6),
                            ],

                            if (matchingActions.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
                                child: Text(
                                  'AÇÕES RÁPIDAS',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                    color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                              for (final act in matchingActions) ...[
                                ListTile(
                                  dense: true,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  leading: Icon(act.icon, size: 18, color: colors.onSurfaceVariant),
                                  title: Text(
                                    act.title,
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                                  ),
                                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 11),
                                  onTap: act.action,
                                ),
                              ],
                            ],

                            if (matchingConversations.isEmpty && matchingActions.isEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 36),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.search_off_rounded, size: 36, color: colors.onSurfaceVariant.withValues(alpha: 0.4)),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Nenhum resultado para "$q"',
                                        style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
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
          child: CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
                _showQuickSearchDialog(context);
              },
              const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () {
                _showQuickSearchDialog(context);
              },
            },
            child: Stack(
              children: [
                child!,
                const PushNotificationBanner(),
              ],
            ),
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
                    IntegratedHeaderBar(
                      minimal: true,
                      onToggleTheme: () => _settings.updateSetting(
                        (st) => st.copyWith(isDarkMode: !st.isDarkMode),
                      ),
                    ),
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
                IntegratedHeaderBar(
                  minimal: true,
                  onToggleTheme: () => _settings.updateSetting(
                    (st) => st.copyWith(isDarkMode: !st.isDarkMode),
                  ),
                ),
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
      final homeContent = IndexedStack(
        index: _index,
        children: const [HomePage(), CommunitiesPage(), SettingsPage()],
      );

      final tabsService = _tabs;
      final conversationTabs =
          tabsService.tabs.where((t) => !t.isHome).toList();

      final homeLayout = wide
        ? Row(
            children: [
              _ModernActivityRail(
                selectedIndex: _index,
                onDestinationSelected: (value) =>
                    setState(() => _index = value),
                extended: constraints.maxWidth >= 820,
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

      final bodyContent = IndexedStack(
        index: tabsService.isHomeActive
            ? 0
            : conversationTabs.indexWhere(
                (tab) => tab.id == tabsService.activeTab.id,
              ) + 1,
        children: [
          homeLayout,
          for (final tab in conversationTabs)
            KeyedSubtree(
              key: ValueKey('tab_${tab.id}'),
              child: TickerMode(
                enabled: tab.id == tabsService.activeTab.id,
                child: P2PChatPage(
                  conversation: tab.conversation!,
                  conversationTitle: tab.title,
                  isTabMode: true,
                ),
              ),
            ),
        ],
      );

      return Scaffold(
        body: Column(
          children: [
            IntegratedHeaderBar(
              onNewConversation: () => _showNewConversationDialog(context),
              onSearchPressed: () => _showQuickSearchDialog(context),
              onNotificationsPressed: () => _showNotificationsSheet(context),
              onToggleTheme: () => _settings.updateSetting(
                (st) => st.copyWith(isDarkMode: !st.isDarkMode),
              ),
              onOpenSettings: () {
                setState(() => _index = 2);
                ConversationTabsService.instance.openHome();
              },
              onOpenVault: () async {
                final vault = await _user.getOrCreateSavedMessages();
                ConversationTabsService.instance.openConversation(
                  vault,
                  title: 'Mensagens Salvas',
                );
              },
            ),
            Expanded(child: bodyContent),
          ],
        ),
        bottomNavigationBar: (wide || !tabsService.isHomeActive)
            ? null
            : NavigationBar(
                height: 64,
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
