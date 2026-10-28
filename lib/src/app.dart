import 'package:nexora/src/services/local_data_service.dart';
import 'package:flutter/material.dart';
import 'package:nexora/src/services/settings_services.dart';
import 'package:nexora/src/views/home.dart';
import 'package:nexora/src/views/sign_in.dart';
import 'package:nexora/src/views/settings.dart';
import 'package:nexora/src/views/widgets/app_theme.dart';

class App extends StatefulWidget {
  const App({super.key});
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final _settings = SettingsService.instance;
  late Future<bool> _initialization;
  int _index = 0;
  @override
  void initState() {
    super.initState();
    _settings.addListener(_refresh);
    _initialization = _initialize();
  }

  @override
  void dispose() {
    _settings.removeListener(_refresh);
    super.dispose();
  }

  Future<bool> _initialize() async {
    await _settings.load();
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

  @override
  Widget build(BuildContext context) {
    final s = _settings.settings;
    final accent = switch (s.accentColor) {
      'blue' => const Color(0xFF89B6FF),
      'purple' => const Color(0xFFB7A1FF),
      _ => const Color(0xFF62E0BD),
    };
    return MaterialApp(
      title: 'Nexora',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(
        s.isDarkMode ? Brightness.dark : Brightness.light,
        accent,
        s.animationsEnabled,
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
          child: child!,
        );
      },
      home: FutureBuilder<bool>(
        future: _initialization,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, size: 40),
                      const SizedBox(height: 16),
                      const Text(
                        'Não foi possível carregar os dados locais com segurança.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () =>
                            setState(() => _initialization = _initialize()),
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          if (snapshot.connectionState != ConnectionState.done)
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          return snapshot.data == true
              ? _shell()
              : SignInPage(
                  onSignedIn: () =>
                      setState(() => _initialization = _initialize()),
                );
        },
      ),
    );
  }

  Widget _shell() => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 800;
      final content = IndexedStack(
        index: _index,
        children: const [HomePage(), SettingsPage()],
      );
      return Scaffold(
        appBar: AppBar(
          titleSpacing: 24,
          title: const Row(
            children: [
              BrandMark(size: 32),
              SizedBox(width: 10),
              Text(
                'Nexora',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.6,
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 24),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  const Text('P2P', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: wide
              ? Row(
                  children: [
                    NavigationRail(
                      extended: constraints.maxWidth >= 1100,
                      minExtendedWidth: 210,
                      backgroundColor: Colors.transparent,
                      selectedIndex: _index,
                      onDestinationSelected: (value) =>
                          setState(() => _index = value),
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.chat_bubble_outline),
                          selectedIcon: Icon(Icons.chat_bubble),
                          label: Text('Conversas'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.settings_outlined),
                          selectedIcon: Icon(Icons.settings),
                          label: Text('Configurações'),
                        ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: content),
                  ],
                )
              : content,
        ),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (value) =>
                    setState(() => _index = value),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.chat_bubble_outline),
                    selectedIcon: Icon(Icons.chat_bubble),
                    label: 'Conversas',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: 'Configurações',
                  ),
                ],
              ),
      );
    },
  );
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
