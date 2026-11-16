import 'package:flutter/material.dart';
import 'package:nexora/src/services/local_data_service.dart';
import 'package:nexora/src/services/notification_service.dart';
import 'package:nexora/src/services/permission_service.dart';
import 'package:nexora/src/services/settings_services.dart';
import 'package:nexora/src/views/widgets/app_theme.dart';

class WelcomePermissionsView extends StatefulWidget {
  const WelcomePermissionsView({super.key, required this.onCompleted});

  final VoidCallback onCompleted;

  @override
  State<WelcomePermissionsView> createState() => _WelcomePermissionsViewState();
}

class _WelcomePermissionsViewState extends State<WelcomePermissionsView> {
  final _permissions = PermissionService.instance;
  final _user = LocalDataService.instance;
  final _settings = SettingsService.instance;
  bool _requesting = false;
  bool _hasRequested = false;

  @override
  void initState() {
    super.initState();
    _permissions.addListener(_onPermissionsChanged);
  }

  @override
  void dispose() {
    _permissions.removeListener(_onPermissionsChanged);
    super.dispose();
  }

  void _onPermissionsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _requestPermissions() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    try {
      final state = await _permissions.requestPermissions();
      _hasRequested = true;

      // Dispara uma notificação push de teste caso a permissão esteja ativa
      if (state.notifications) {
        await NotificationService.instance.notifyWelcome();
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  Future<void> _completeOnboarding() async {
    await _settings.updateSetting(
      (s) => s.copyWith(hasCompletedWelcome: true),
    );
    if (mounted) {
      widget.onCompleted();
    }
  }

  Widget _buildPermissionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
  }) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141926) : const Color(0xFFF4F6F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted
              ? Colors.tealAccent.shade700.withOpacity(0.5)
              : colors.outlineVariant.withOpacity(0.4),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isGranted
                  ? Colors.teal.withOpacity(0.18)
                  : colors.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isGranted ? Colors.tealAccent.shade400 : colors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isGranted
                            ? Colors.teal.withOpacity(0.2)
                            : Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isGranted
                              ? Colors.tealAccent.shade400.withOpacity(0.6)
                              : Colors.amber.shade600.withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isGranted
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 13,
                            color: isGranted
                                ? Colors.tealAccent.shade400
                                : Colors.amber.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isGranted ? 'Autorizado' : 'Pendente',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isGranted
                                  ? Colors.tealAccent.shade400
                                  : Colors.amber.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: colors.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final permState = _permissions.state;
    final nickname = _user.currentUser.nickname?.isNotEmpty == true
        ? _user.currentUser.nickname!
        : 'Amigo';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header com Ícone e Boas-Vindas
                      Center(
                        child: Column(
                          children: [
                            const BrandMark(size: 64),
                            const SizedBox(height: 18),
                            Text(
                              'Bem-vindo ao Nexora!',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -.6,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Olá, $nickname. Seu perfil está pronto para conversar.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14.5,
                                color: colors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'O Nexora conecta você diretamente com seus contatos, com privacidade total, sem intermediários e sem anúncios.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.onSurfaceVariant,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Divider(height: 1),
                      const SizedBox(height: 20),

                      // Explicação das permissões
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            color: colors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Permissões do Dispositivo',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Para garantir que chamadas, áudios e mensagens funcionem perfeitamente, confirme as permissões abaixo:',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: colors.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Cartões de Permissões
                      _buildPermissionCard(
                        context: context,
                        icon: Icons.notifications_active_rounded,
                        title: 'Notificações',
                        description:
                            'Receba avisos instantâneos quando alguém enviar uma mensagem, chamada ou arquivo.',
                        isGranted: permState.notifications,
                      ),
                      _buildPermissionCard(
                        context: context,
                        icon: Icons.mic_rounded,
                        title: 'Microfone',
                        description:
                            'Necessário para realizar chamadas de voz e enviar mensagens de áudio.',
                        isGranted: permState.microphone,
                      ),
                      _buildPermissionCard(
                        context: context,
                        icon: Icons.videocam_rounded,
                        title: 'Câmera',
                        description:
                            'Usada para chamadas de vídeo e para ler códigos de convite na tela.',
                        isGranted: permState.camera,
                      ),
                      _buildPermissionCard(
                        context: context,
                        icon: Icons.sensors_rounded,
                        title: 'Dispositivos Próximos',
                        description:
                            'Conecte-se facilmente com pessoas próximas conectadas na mesma rede Wi-Fi.',
                        isGranted: permState.bluetooth,
                      ),

                      const SizedBox(height: 24),

                      // Botão de Solicitar Permissões ao Sistema
                      FilledButton.icon(
                        onPressed: _requesting ? null : _requestPermissions,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: _requesting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.verified_user_rounded),
                        label: Text(
                          _requesting
                              ? 'Solicitando permissões...'
                              : (permState.allGranted || _hasRequested
                                  ? 'Revisar Permissões do Sistema'
                                  : 'Autorizar Permissões do Sistema'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Botão de Avançar / Entrar no aplicativo
                      OutlinedButton.icon(
                        onPressed: _completeOnboarding,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text(
                          'Continuar para o Nexora',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
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
    );
  }
}
