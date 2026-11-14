import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexora/src/models/mirrored_device.dart';
import 'package:nexora/src/models/scheduled_message.dart';
import 'package:nexora/src/models/seting.dart';
import 'package:nexora/src/services/local_data_service.dart';
import 'package:nexora/src/services/notification_service.dart';
import 'package:nexora/src/services/permission_service.dart';
import 'package:nexora/src/services/scheduled_message_service.dart';
import 'package:nexora/src/services/settings_services.dart';
import 'package:nexora/src/utils/app_locale.dart';
import 'package:nexora/src/utils/qr_code.dart';
import 'package:nexora/src/views/device_mirror_host_view.dart';
import 'package:nexora/src/views/device_mirror_receive_view.dart';
import 'package:nexora/src/views/welcome_permissions_view.dart';
import 'package:nexora/src/views/widgets/app_theme.dart';
import 'package:nexora/src/views/widgets/confirmation_dialog.dart';
import 'package:nexora/src/views/widgets/crypto_avatar.dart';
import 'package:nexora/src/views/widgets/theme_preview_card.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _user = LocalDataService.instance;
  final _settings = SettingsService.instance;
  final _permissions = PermissionService.instance;
  final _notifications = NotificationService.instance;
  final _scheduled = ScheduledMessageService.instance;

  String _searchQuery = '';
  String _selectedCategory = 'all';
  bool _saving = false;
  bool _requestingPermissions = false;

  final TextEditingController _searchController = TextEditingController();

  final List<({String id, String label, IconData icon})> _categories = const [
    (id: 'all', label: 'Tudo', icon: Icons.grid_view_rounded),
    (id: 'profile', label: 'Identidade', icon: Icons.person_pin_rounded),
    (id: 'streaming', label: 'Streaming 4K & Chamadas', icon: Icons.four_k_rounded),
    (id: 'messages', label: 'Mensagens & Envio', icon: Icons.schedule_send_rounded),
    (id: 'communities', label: 'Comunidades P2P', icon: Icons.hub_rounded),
    (id: 'theme', label: 'Aparência & Tema', icon: Icons.palette_outlined),
    (id: 'privacy', label: 'Segurança & Privacidade', icon: Icons.shield_outlined),
    (id: 'notifications', label: 'Notificações', icon: Icons.notifications_active_outlined),
    (id: 'network', label: 'Rede P2P & Espelhamento', icon: Icons.sensors_rounded),
    (id: 'storage', label: 'Armazenamento', icon: Icons.storage_rounded),
    (id: 'about', label: 'Sobre & Permissões', icon: Icons.info_outline_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _settings.addListener(_refresh);
    _user.addListener(_refresh);
    _permissions.addListener(_refresh);
    _notifications.addListener(_refresh);
    _scheduled.addListener(_refresh);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _settings.removeListener(_refresh);
    _user.removeListener(_refresh);
    _permissions.removeListener(_refresh);
    _notifications.removeListener(_refresh);
    _scheduled.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _notice(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _update(Setting Function(Setting) update) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _settings.updateSetting(update);
    } catch (_) {
      _notice('Não foi possível salvar as configurações.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _matchesSearch(String term) {
    if (_searchQuery.trim().isEmpty) return true;
    return term.toLowerCase().contains(_searchQuery.toLowerCase().trim());
  }

  bool _isCategoryVisible(String categoryId) {
    if (_searchQuery.trim().isNotEmpty) return true;
    if (_selectedCategory == 'all') return true;
    return _selectedCategory == categoryId;
  }

  // --- Ações de Identidade ---
  Future<void> _editNickname() async {
    String nickname = _user.currentUser.nickname;
    final form = GlobalKey<FormState>();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Apelido Local'),
        content: Form(
          key: form,
          child: TextFormField(
            initialValue: nickname,
            maxLength: 32,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Apelido visível',
              hintText: 'Como os outros verão seu contato',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            onChanged: (v) => nickname = v,
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Informe um apelido de 1 a 32 caracteres.'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, nickname.trim());
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (value != null && value.isNotEmpty) {
      try {
        await _user.updateNickname(value);
        _notice('Apelido atualizado com sucesso.');
      } catch (e) {
        _notice(e.toString());
      }
    }
  }

  void _showPublicKeyDialog() {
    final key = _user.currentUser.publicKey;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.qr_code_2_rounded, size: 28),
            const SizedBox(width: 10),
            const Text('Sua Chave Pública'),
          ],
        ),
        content: SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: CustomPaint(
                    size: const Size(220, 220),
                    painter: QrCodePainter(data: key, color: Colors.black),
                  ),
                ),
                const SizedBox(height: 18),
                SelectableText(
                  key,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Compartilhe esta chave com contatos para iniciar uma conversa P2P criptografada direta.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: key));
              if (context.mounted) {
                Navigator.pop(context);
                _notice('Chave pública copiada para a área de transferência.');
              }
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copiar Chave'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestSystemPermissions() async {
    if (_requestingPermissions) return;
    setState(() => _requestingPermissions = true);
    try {
      await _permissions.requestPermissions();
      _notice('Permissões verificadas e atualizadas.');
    } finally {
      if (mounted) setState(() => _requestingPermissions = false);
    }
  }

  void _showBlockedContactsDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final blocked = _user.currentUser.blockedUserIds;
          return AlertDialog(
            title: Text('Contatos Bloqueados (${blocked.length})'),
            content: SizedBox(
              width: 440,
              height: 320,
              child: blocked.isEmpty
                  ? const Center(
                      child: Text(
                        'Nenhum contato bloqueado.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: blocked.length,
                      itemBuilder: (context, index) {
                        final key = blocked[index];
                        final name = _user.contactName(key) ?? 'Contato Desconhecido';
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CryptoAvatar(
                            seedKey: key,
                            title: name,
                            size: 38,
                            isBlocked: true,
                          ),
                          title: Text(name),
                          subtitle: Text(
                            AppTheme.formatKeyPreview(key),
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.lock_open_rounded, color: Colors.tealAccent),
                            tooltip: 'Desbloquear',
                            onPressed: () async {
                              await _user.setBlocked(key, false);
                              setDialogState(() {});
                              _notice('Contato desbloqueado.');
                            },
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Concluído'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showScheduledMessagesManagerDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final allScheduled = _scheduled.allMessages;
          final colors = Theme.of(context).colorScheme;

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.schedule_send_rounded, color: Colors.tealAccent),
                const SizedBox(width: 10),
                Text('Mensagens Agendadas (${allScheduled.length})'),
              ],
            ),
            content: SizedBox(
              width: 480,
              height: 340,
              child: allScheduled.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 48,
                            color: colors.primary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Nenhuma mensagem agendada no momento.',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Você pode agendar mensagens diretamente na tela de qualquer conversa.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: allScheduled.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final msg = allScheduled[index];
                        final targetTime = msg.scheduledFor;
                        final formattedTime =
                            '${targetTime.day.toString().padLeft(2, '0')}/${targetTime.month.toString().padLeft(2, '0')} às ${targetTime.hour.toString().padLeft(2, '0')}:${targetTime.minute.toString().padLeft(2, '0')}';
                        final conv = _user.conversations
                            .where((c) => c.id == msg.conversationId)
                            .firstOrNull;
                        final convName = conv?.title ?? 'Conversa P2P';

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: colors.primary.withOpacity(0.15),
                            child: Icon(Icons.access_time_rounded, color: colors.primary, size: 20),
                          ),
                          title: Text(
                            msg.content,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 3),
                              Text(
                                'Destino: $convName',
                                style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
                              ),
                              Text(
                                'Envio previsto: $formattedTime',
                                style: const TextStyle(fontSize: 11, color: Colors.tealAccent, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                            tooltip: 'Cancelar agendamento',
                            onPressed: () async {
                              await _scheduled.cancelMessage(msg.id);
                              setDialogState(() {});
                              _notice('Agendamento cancelado com sucesso.');
                            },
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportBackup() async {
    try {
      final seed = await _user.extractPrivateSeed();
      final base64Seed = base64Encode(seed);
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.vpn_key_rounded, color: Colors.amber),
              SizedBox(width: 10),
              Text('Backup da Chave Privada'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Esta semente de 256 bits recupera sua identidade em qualquer outro dispositivo. NUNCA a compartilhe com terceiros.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withOpacity(0.5)),
                ),
                child: SelectableText(
                  base64Seed,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: base64Seed));
                Navigator.pop(context);
                _notice('Semente copiada com segurança.');
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copiar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    } catch (_) {
      _notice('Não foi possível extrair a chave privada.');
    }
  }

  Future<void> _wipeData() async {
    final confirmed = await confirmAction(
      context,
      title: 'Destruir Identidade e Dados Locais?',
      description:
          'Esta ação apagará permanentemente sua chave privada, histórico de mensagens e configurações deste aparelho. Não é possível desfazer.',
      action: 'Destruir Tudo',
    );
    if (confirmed && mounted) {
      await _user.wipeAllData();
      _notice('Todos os dados locais foram destruídos com segurança.');
    }
  }

  // --- Componentes Visuais Modernos ---
  Widget _buildSectionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131826) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant.withOpacity(0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: colors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildChoicePill<T>({
    required BuildContext context,
    required String title,
    required String subtitle,
    required T selected,
    required Map<T, String> options,
    required ValueChanged<T> onSelected,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.entries.map((e) {
              final isCur = e.key == selected;
              return ChoiceChip(
                label: Text(e.value),
                selected: isCur,
                onSelected: (val) {
                  if (val) onSelected(e.key);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String label, bool isOk) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOk ? Colors.teal.withOpacity(0.18) : Colors.amber.withOpacity(0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOk ? Colors.tealAccent.shade400.withOpacity(0.5) : Colors.amber.withOpacity(0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOk ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            size: 13,
            color: isOk ? Colors.tealAccent.shade400 : Colors.amber.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isOk ? Colors.tealAccent.shade400 : Colors.amber.shade700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _settings.settings;
    final currentUser = _user.currentUser;
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final permState = _permissions.state;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header / Search Bar moderna
          SliverToBoxAdapter(
            child: PageFrame(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Campo de Busca
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF131826) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.outlineVariant.withOpacity(0.5)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: 'Buscar ajustes (tema, notificações, rede, PIN)...',
                          hintStyle: TextStyle(fontSize: 13.5, color: colors.onSurfaceVariant),
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 20),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Barra de Categorias Horizontal (Pills)
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final cat = _categories[i];
                          final isSelected = _selectedCategory == cat.id;
                          return ChoiceChip(
                            avatar: Icon(
                              cat.icon,
                              size: 16,
                              color: isSelected ? colors.onPrimary : colors.primary,
                            ),
                            label: Text(cat.label),
                            selected: isSelected,
                            onSelected: (val) {
                              if (val) {
                                setState(() {
                                  _selectedCategory = cat.id;
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Conteúdo Principal Filtrado
          SliverToBoxAdapter(
            child: PageFrame(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ==========================================
                    // 1. HERO PROFILE CARD
                    // ==========================================
                    if (_isCategoryVisible('theme') &&
                        _matchesSearch('idioma language região locale'))
                      ListTile(
                        leading: const Icon(Icons.language),
                        title: Text(AppLocale.pickerTitle(context)),
                        subtitle: Text(
                          s.languageCode.isEmpty
                              ? AppLocale.systemLabel(context)
                              : AppLocale.label(
                                  AppLocale.fromPreference(s.languageCode),
                                ),
                        ),
                        onTap: () async {
                          final languageCode = await showDialog<String>(
                            context: context,
                            builder: (_) => AppLanguageDialog(
                              selected: s.languageCode,
                            ),
                          );
                          if (languageCode != null && mounted) {
                            await _update(
                              (previous) =>
                                  previous.copyWith(languageCode: languageCode),
                            );
                          }
                        },
                      ),
                    if (_isCategoryVisible('profile') && _matchesSearch('perfil identidade chave apelido qr'))
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colors.primary.withOpacity(0.18),
                              colors.surfaceContainerHighest.withOpacity(0.35),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: colors.primary.withOpacity(0.35), width: 1.5),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CryptoAvatar(
                                  seedKey: currentUser.publicKey,
                                  title: currentUser.nickname,
                                  size: 64,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              currentUser.nickname.isEmpty
                                                  ? 'Identidade Local'
                                                  : currentUser.nickname,
                                              style: const TextStyle(
                                                fontSize: 19,
                                                fontWeight: FontWeight.w800,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, size: 20),
                                            tooltip: 'Editar apelido',
                                            onPressed: _editNickname,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(Icons.lock_outline_rounded, size: 14, color: colors.primary),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Chave: ${AppTheme.formatKeyPreview(currentUser.publicKey)}',
                                            style: TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 12,
                                              color: colors.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            const Divider(height: 1),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton.tonalIcon(
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: currentUser.publicKey));
                                    _notice('Chave pública copiada!');
                                  },
                                  icon: const Icon(Icons.copy_rounded, size: 16),
                                  label: const Text('Copiar Chave'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _showPublicKeyDialog,
                                  icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                                  label: const Text('Exibir QR Code'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const DeviceMirrorHostView(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.devices_rounded, size: 18),
                                  label: const Text('Espelhar Conta'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                    // ==========================================
                    // STREAMING DE VÍDEO & CHAMADAS (ATÉ 4K@60FPS)
                    // ==========================================
                    if (_isCategoryVisible('streaming') && _matchesSearch('streaming video 4k 60fps qualidade chamadas tela resolução taxa quadros'))
                      _buildSectionCard(
                        context: context,
                        icon: Icons.four_k_rounded,
                        title: 'Streaming de Vídeo & Chamadas (Até 4K@60fps)',
                        subtitle: 'Transmissão ponto a ponto de alta fidelidade até 4K UHD @ 60 FPS liberado para todos os usuários',
                        children: [
                          SwitchListTile(
                            secondary: const Icon(Icons.hd_rounded),
                            title: const Text('Habilitar Streaming Ultra HD 4K'),
                            subtitle: const Text('Permite transmitir e receber vídeos e telas em até 3840×2160 pixels a 60 quadros por segundo para todos os usuários sem cobranças.'),
                            value: s.enable4kStreaming,
                            onChanged: (val) => _update((prev) => prev.copyWith(enable4kStreaming: val)),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.speed_rounded),
                            title: const Text('Predefinição Padrão de Resolução'),
                            subtitle: Text(
                              switch (s.videoStreamingPreset) {
                                '4k60' => '💎 4K Ultra HD • 60 FPS (Até 35 Mbps)',
                                '4k30' => '💎 4K Ultra HD • 30 FPS (Até 22 Mbps)',
                                '2k60' => '⚡ 2K Quad HD • 60 FPS (Até 16 Mbps)',
                                '1080p60' => '🚀 Full HD • 60 FPS (Até 9 Mbps)',
                                '1080p30' => 'Full HD • 30 FPS (Até 5 Mbps)',
                                '720p30' => 'HD • 30 FPS (Até 2.5 Mbps)',
                                '480p24' => 'Econômico • 24 FPS (Até 1 Mbps)',
                                _ => '💎 4K Ultra HD • 60 FPS',
                              },
                            ),
                            trailing: DropdownButton<String>(
                              value: s.videoStreamingPreset,
                              underline: const SizedBox.shrink(),
                              items: const [
                                DropdownMenuItem(value: '4k60', child: Text('4K @ 60 FPS (Max)')),
                                DropdownMenuItem(value: '4k30', child: Text('4K @ 30 FPS')),
                                DropdownMenuItem(value: '2k60', child: Text('2K @ 60 FPS')),
                                DropdownMenuItem(value: '1080p60', child: Text('1080p @ 60 FPS')),
                                DropdownMenuItem(value: '1080p30', child: Text('1080p @ 30 FPS')),
                                DropdownMenuItem(value: '720p30', child: Text('720p @ 30 FPS')),
                                DropdownMenuItem(value: '480p24', child: Text('480p @ 24 FPS')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  _update((prev) => prev.copyWith(videoStreamingPreset: val));
                                }
                              },
                            ),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            secondary: const Icon(Icons.memory_rounded),
                            title: const Text('Aceleração de Hardware / GPU'),
                            subtitle: const Text('Utiliza o codificador/decodificador de vídeo da GPU para processar 4K a 60 FPS com baixo consumo de CPU e bateria.'),
                            value: s.videoHardwareAcceleration,
                            onChanged: (val) => _update((prev) => prev.copyWith(videoHardwareAcceleration: val)),
                          ),
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.diamond_rounded,
                                    color: Theme.of(context).colorScheme.primary,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'O Nexora é 100% P2P direto: transmissões em 4K@60fps não passam por servidores centrais, garantindo privacidade ponta a ponta e máxima taxa de bits.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                    // ==========================================
                    // 2. MENSAGENS, ENVIO & AGENDAMENTO
                    // ==========================================
                    if (_isCategoryVisible('messages') && _matchesSearch('mensagens envio agendar enter mídia arquivo recibo prévia link feedback'))
                      _buildSectionCard(
                        context: context,
                        icon: Icons.schedule_send_rounded,
                        title: 'Mensagens, Envio & Agendamento',
                        subtitle: 'Controle opções de envio imediato, agendamento e preferências de chat',
                        children: [
                          SwitchListTile(
                            secondary: const Icon(Icons.keyboard_return_rounded),
                            title: const Text('Pressionar Enter para Enviar'),
                            subtitle: const Text('Enviar a mensagem ao teclar Enter no teclado físico. Use Shift+Enter para nova linha.'),
                            value: s.enterIsSend,
                            onChanged: (val) => _update((prev) => prev.copyWith(enterIsSend: val)),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            secondary: const Icon(Icons.alarm_on_rounded),
                            title: const Text('Notificação de Mensagens Agendadas'),
                            subtitle: const Text('Receber alerta push do sistema quando uma mensagem agendada for disparada'),
                            value: s.scheduledMessagesNotification,
                            onChanged: (val) => _update((prev) => prev.copyWith(scheduledMessagesNotification: val)),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            secondary: const Icon(Icons.attach_file_rounded),
                            title: const Text('Confirmar Envio de Arquivos & Mídias'),
                            subtitle: const Text('Exibir diálogo de confirmação prévia antes de iniciar o envio de arquivos P2P'),
                            value: s.confirmBeforeSendingMedia,
                            onChanged: (val) => _update((prev) => prev.copyWith(confirmBeforeSendingMedia: val)),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            secondary: const Icon(Icons.done_all_rounded),
                            title: const Text('Confirmações de Leitura P2P'),
                            subtitle: const Text('Compartilhar recibos de visualização de mensagens com os pares conectados'),
                            value: s.readReceipts,
                            onChanged: (val) => _update((prev) => prev.copyWith(readReceipts: val)),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            secondary: const Icon(Icons.vibration_rounded),
                            title: const Text('Feedback Tátil & Vibração'),
                            subtitle: const Text('Retorno háptico ao enviar mensagens e alternar modos de chat'),
                            value: s.hapticFeedback,
                            onChanged: (val) => _update((prev) => prev.copyWith(hapticFeedback: val)),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            secondary: const Icon(Icons.link_rounded),
                            title: const Text('Pré-visualização de Links Web'),
                            subtitle: const Text('Carregar metadados de links externos. Desativado por padrão para proteção do IP.'),
                            value: s.linkPreviews,
                            onChanged: (val) => _update((prev) => prev.copyWith(linkPreviews: val)),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.schedule_rounded),
                            title: const Text('Gerenciar Mensagens Agendadas'),
                            subtitle: Text(
                              _scheduled.allMessages.isEmpty
                                  ? 'Nenhuma mensagem agendada pendente'
                                  : '${_scheduled.allMessages.length} mensagem(ns) aguardando o horário de envio',
                            ),
                            trailing: FilledButton.tonal(
                              onPressed: _showScheduledMessagesManagerDialog,
                              child: const Text('Gerenciar'),
                            ),
                          ),
                        ],
                      ),

                    // ==========================================
                    // 3. COMUNIDADES P2P & CANAIS DE TÓPICOS
                    // ==========================================
                    if (_isCategoryVisible('communities') && _matchesSearch('comunidades canais tópicos grupo flood membros lenta menções'))
                      _buildSectionCard(
                        context: context,
                        icon: Icons.hub_rounded,
                        title: 'Comunidades P2P & Canais',
                        subtitle: 'Preferências de alertas, inscrição de canais e convites de grupos descentralizados',
                        children: [
                          _buildChoicePill<String>(
                            context: context,
                            title: 'Alertas de Mensagens em Comunidades',
                            subtitle: 'Defina o comportamento das notificações push para os canais de tópicos',
                            selected: s.communityNotificationsMode,
                            options: const {
                              'all': 'Todos os canais',
                              'mentions': 'Apenas menções (@ e anúncios)',
                              'none': 'Silencioso (Sem alertas)',
                            },
                            onSelected: (val) => _update((prev) => prev.copyWith(communityNotificationsMode: val)),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            secondary: const Icon(Icons.sync_alt_rounded),
                            title: const Text('Sincronizar Novos Canais Automaticamente'),
                            subtitle: const Text('Entrar de forma transparente em novos canais de tópicos criados na malha da comunidade'),
                            value: s.communityAutoJoinChannels,
                            onChanged: (val) => _update((prev) => prev.copyWith(communityAutoJoinChannels: val)),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            secondary: const Icon(Icons.download_for_offline_rounded),
                            title: const Text('Download Automático de Mídia em Comunidades'),
                            subtitle: const Text('Baixar automaticamente fotos e áudios em canais de comunidades (desative para poupar dados móveis)'),
                            value: s.communityMediaAutoDownload,
                            onChanged: (val) => _update((prev) => prev.copyWith(communityMediaAutoDownload: val)),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            secondary: const Icon(Icons.group_add_rounded),
                            title: const Text('Receber Convites de Novas Comunidades'),
                            subtitle: const Text('Permitir que seus contatos P2P enviem convites de comunidades diretamente para você'),
                            value: s.allowCommunityInvites,
                            onChanged: (val) => _update((prev) => prev.copyWith(allowCommunityInvites: val)),
                          ),
                          const Divider(height: 1),
                          _buildChoicePill<int>(
                            context: context,
                            title: 'Modo Lento Local (Anti-Flood)',
                            subtitle: 'Tempo mínimo de espera entre envios de mensagens para evitar poluição nos canais',
                            selected: s.communitySlowModeSeconds,
                            options: const {
                              0: 'Desativado (Normal)',
                              5: '5 segundos',
                              15: '15 segundos',
                              30: '30 segundos',
                              60: '60 segundos (Foco)',
                            },
                            onSelected: (val) => _update((prev) => prev.copyWith(communitySlowModeSeconds: val)),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.folder_shared_rounded),
                            title: const Text('Comunidades Ativas neste Aparelho'),
                            subtitle: Text('${_user.conversations.where((c) => c.isCommunity).length} comunidade(s) registradas na malha local'),
                            trailing: Text(
                              '${_user.conversations.where((c) => c.isCommunity).fold<int>(0, (acc, c) => acc + c.channels.length)} canais no total',
                              style: TextStyle(fontSize: 12, color: colors.primary, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),

                    // ==========================================
                    // 4. APARÊNCIA, TEMA & LAYOUT
                    // ==========================================
                    if (_isCategoryVisible('theme') && _matchesSearch('tema aparência cor fonte amoled balão papel layout'))
                      _buildSectionCard(
                        context: context,
                        icon: Icons.palette_outlined,
                        title: 'Aparência, Tema & Layout',
                        subtitle: 'Personalize cores, tipografia e a experiência visual',
                        children: [
                          // Modo Escuro / Claro / AMOLED
                          SwitchListTile(
                            secondary: const Icon(Icons.dark_mode_outlined),
                            title: const Text('Modo escuro'),
                            subtitle: const Text('Ativa a interface com fundo escuro e menor cansaço visual'),
                            value: s.isDarkMode,
                            onChanged: (val) => _update((prev) => prev.copyWith(isDarkMode: val)),
                          ),
                          if (s.isDarkMode) ...[
                            const Divider(height: 1),
                            SwitchListTile(
                              secondary: const Icon(Icons.brightness_2_rounded),
                              title: const Text('Modo AMOLED (Preto absoluto)'),
                              subtitle: const Text('Fundo 100% preto para economia de bateria em telas OLED'),
                              value: s.isAmoledMode,
                              onChanged: (val) => _update((prev) => prev.copyWith(isAmoledMode: val)),
                            ),
                          ],
                          const Divider(height: 1),

                          // Cores de Destaque
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Cor de Destaque Criptográfica',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Altera o acento de botões, destaques e identidades visuais',
                                  style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 10,
                                  children: [
                                    ('mint', 'Verde Mint', const Color(0xFF38E5B1)),
                                    ('blue', 'Cyber Blue', const Color(0xFF5A9BFF)),
                                    ('purple', 'Electric Purple', const Color(0xFFB488FF)),
                                    ('amber', 'Amber Glow', const Color(0xFFFFB84D)),
                                    ('crimson', 'Crimson Red', const Color(0xFFFF5C7C)),
                                    ('monochrome', 'Titanium', const Color(0xFFCFD9EA)),
                                  ].map((c) {
                                    final isSelected = s.accentColor == c.$1;
                                    return InkWell(
                                      onTap: () => _update((prev) => prev.copyWith(accentColor: c.$1)),
                                      borderRadius: BorderRadius.circular(16),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 180),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isSelected ? c.$3.withOpacity(0.22) : colors.surface,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: isSelected ? c.$3 : colors.outlineVariant.withOpacity(0.5),
                                            width: isSelected ? 2 : 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 14,
                                              height: 14,
                                              decoration: BoxDecoration(
                                                color: c.$3,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              c.$2,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                                color: isSelected ? colors.onSurface : colors.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),

                          // Balões de Mensagem & Papel de Parede
                          _buildChoicePill<String>(
                            context: context,
                            title: 'Estilo dos Balões de Conversa',
                            subtitle: 'Formato visual das mensagens enviadas e recebidas',
                            selected: s.chatBubbleStyle,
                            options: const {
                              'modern': 'Moderno (Arredondado)',
                              'minimal': 'Minimalista (Clean)',
                              'bubble': 'Bubble Clássico',
                            },
                            onSelected: (val) => _update((prev) => prev.copyWith(chatBubbleStyle: val)),
                          ),
                          const Divider(height: 1),

                          _buildChoicePill<String>(
                            context: context,
                            title: 'Papel de Parede do Chat',
                            subtitle: 'Textura geométrica de fundo aplicada nas telas de conversa',
                            selected: s.chatWallpaper,
                            options: const {
                              'mesh': 'Gradiente Mesh',
                              'grid': 'Grade Ciberpunk',
                              'dots': 'Pontos Minimalistas',
                              'none': 'Liso Puro',
                            },
                            onSelected: (val) => _update((prev) => prev.copyWith(chatWallpaper: val)),
                          ),
                          const Divider(height: 1),

                          // Raio dos Cartões e Densidade
                          _buildChoicePill<double>(
                            context: context,
                            title: 'Arredondamento dos Cantos (Card Radius)',
                            subtitle: 'Grau de curvatura dos elementos visuais da interface',
                            selected: s.cardRadius,
                            options: {
                              8.0: 'Discreto (8px)',
                              16.0: 'Moderno (16px)',
                              24.0: 'Orgânico (24px)',
                            },
                            onSelected: (val) => _update((prev) => prev.copyWith(cardRadius: val)),
                          ),
                          const Divider(height: 1),

                          _buildChoicePill<String>(
                            context: context,
                            title: 'Densidade do Layout',
                            subtitle: 'Espaçamento entre mensagens e itens das listas',
                            selected: s.layoutDensity,
                            options: const {
                              'comfortable': 'Confortável (Espaçamento Amplo)',
                              'compact': 'Compacto (Alta Densidade)',
                            },
                            onSelected: (val) => _update((prev) => prev.copyWith(layoutDensity: val)),
                          ),
                          const Divider(height: 1),

                          // Slider de Tamanho da Fonte com Preview
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Escala da Fonte',
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                    ),
                                    Text(
                                      '${s.fontSize.toStringAsFixed(0)} pt',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: colors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                Slider(
                                  min: 12.0,
                                  max: 22.0,
                                  divisions: 10,
                                  value: s.fontSize,
                                  onChanged: (val) => _update((prev) => prev.copyWith(fontSize: val)),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),

                          SwitchListTile(
                            secondary: const Icon(Icons.access_time_rounded),
                            title: const Text('Exibir Horários nas Bolhas'),
                            subtitle: const Text('Mostrar horário detalhado de envio e recebimento abaixo de cada mensagem'),
                            value: s.showTimestamps,
                            onChanged: (val) => _update((prev) => prev.copyWith(showTimestamps: val)),
                          ),
                          const Divider(height: 1),

                          // Preview do Chat em Tempo Real
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: ThemePreviewCard(setting: s),
                          ),
                        ],
                      ),

                    // ==========================================
                    // 3. SEGURANÇA & PRIVACIDADE
                    // ==========================================
                    if (_isCategoryVisible('privacy') && _matchesSearch('segurança privacidade criptografia pin furtivo hud bloqueados retenção'))
                      _buildSectionCard(
                        context: context,
                        icon: Icons.shield_outlined,
                        title: 'Segurança & Privacidade Criptográfica',
                        subtitle: 'Controles anti-espião, retenção local e proteção de chaves',
                        children: [
                          SwitchListTile(
                            secondary: const Icon(Icons.visibility_off_outlined),
                            title: const Text('Modo Furtivo Anti-Espião (Stealth Blur)'),
                            subtitle: const Text('Aplica desfoque visual temporário ao redor das mensagens no chat'),
                            value: s.stealthMode,
                            onChanged: (val) => _update((prev) => prev.copyWith(stealthMode: val)),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            secondary: const Icon(Icons.security_rounded),
                            title: const Text('HUD de Inspeção Criptográfica'),
                            subtitle: const Text('Exibe métricas criptográficas, chaves de sessão e handshake no chat'),
                            value: s.showSecurityInspector,
                            onChanged: (val) => _update((prev) => prev.copyWith(showSecurityInspector: val)),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            secondary: const Icon(Icons.fingerprint_rounded),
                            title: const Text('Bloqueio por Biometria / PIN'),
                            subtitle: const Text('Exigir autenticação do sistema ao abrir o Nexora'),
                            value: s.biometricsEnabled,
                            onChanged: (val) => _update((prev) => prev.copyWith(biometricsEnabled: val)),
                          ),
                          const Divider(height: 1),

                          // Contatos Bloqueados
                          ListTile(
                            leading: const Icon(Icons.block_outlined),
                            title: const Text('Gerenciar Contatos Bloqueados'),
                            subtitle: Text(
                              '${currentUser.blockedUserIds.length} contatos bloqueados localmente',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: _showBlockedContactsDialog,
                          ),
                          const Divider(height: 1),

                          // Limpeza Automática / Mensagens Efêmeras
                          _buildChoicePill<int>(
                            context: context,
                            title: 'Limpeza Automática Local de Histórico',
                            subtitle: 'Apaga mensagens antigas deste aparelho após o período escolhido',
                            selected: s.localRetentionMinutes,
                            options: const {
                              0: 'Desativado (Manter Tudo)',
                              60: '1 Hora',
                              1440: '24 Horas',
                              10080: '7 Dias',
                              43200: '30 Dias',
                            },
                            onSelected: (val) => _update((prev) => prev.copyWith(localRetentionMinutes: val)),
                          ),
                          const Divider(height: 1),

                          // Backup e Wipe
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _exportBackup,
                                    icon: const Icon(Icons.vpn_key_outlined, size: 18),
                                    label: const Text('Backup da Chave'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: colors.error,
                                      foregroundColor: colors.onError,
                                    ),
                                    onPressed: _wipeData,
                                    icon: const Icon(Icons.delete_forever_rounded, size: 18),
                                    label: const Text('Destruir Dados'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                    // ==========================================
                    // 4. NOTIFICAÇÕES PUSH MULTIPLATAFORMA
                    // ==========================================
                    if (_isCategoryVisible('notifications') && _matchesSearch('notificações push alertas som vibração teste'))
                      _buildSectionCard(
                        context: context,
                        icon: Icons.notifications_active_outlined,
                        title: 'Notificações Push Multiplataforma',
                        subtitle: 'Alertas em tempo real no Windows, Linux, macOS, Android e iOS',
                        children: [
                          SwitchListTile(
                            secondary: const Icon(Icons.notifications_outlined),
                            title: const Text('Notificações Push Ativas'),
                            subtitle: const Text('Alertas instantâneos do sistema ao receber mensagens ou chamadas'),
                            value: s.notificationsEnabled,
                            onChanged: (val) => _update((prev) => prev.copyWith(notificationsEnabled: val)),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            secondary: const Icon(Icons.volume_up_outlined),
                            title: const Text('Alertas Sonoros e Vibração'),
                            subtitle: const Text('Emitir sinal sonoro e feedback tátil ao receber notificações'),
                            value: s.notificationSound,
                            onChanged: s.notificationsEnabled
                                ? (val) => _update((prev) => prev.copyWith(notificationSound: val))
                                : null,
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            secondary: const Icon(Icons.lock_clock_outlined),
                            title: const Text('Prévia de Mensagens na Notificação'),
                            subtitle: const Text('Ocultar texto confidencial na tela de bloqueio e pop-ups'),
                            value: s.notificationPreview,
                            onChanged: s.notificationsEnabled
                                ? (val) => _update((prev) => prev.copyWith(notificationPreview: val))
                                : null,
                          ),
                          const Divider(height: 1),

                          // Disparar Teste de Notificação
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: FilledButton.icon(
                              onPressed: s.notificationsEnabled
                                  ? () async {
                                      await _notifications.pushNotification(
                                        PushNotificationItem(
                                          id: 'test_${DateTime.now().microsecondsSinceEpoch}',
                                          title: '⚡ Notificação Push Nexora',
                                          body: 'O sistema de notificações push está ativo e respondendo!',
                                          type: NotificationType.message,
                                          createdAt: DateTime.now(),
                                        ),
                                      );
                                      _notice('Notificação de teste disparada com sucesso!');
                                    }
                                  : null,
                              icon: const Icon(Icons.send_rounded, size: 18),
                              label: const Text('Disparar Notificação de Teste Imediata'),
                            ),
                          ),

                          // Histórico de Notificações
                          ListTile(
                            leading: const Icon(Icons.history_rounded),
                            title: const Text('Histórico de Notificações Recentes'),
                            subtitle: Text('${_notifications.history.length} alertas registrados nesta sessão'),
                            trailing: TextButton(
                              onPressed: _notifications.history.isEmpty
                                  ? null
                                  : () async {
                                      await _notifications.clearHistory();
                                      _notice('Histórico de notificações limpo.');
                                    },
                              child: const Text('Limpar'),
                            ),
                          ),
                        ],
                      ),

                    // ==========================================
                    // 5. REDE P2P & ESPELHAMENTO
                    // ==========================================
                    if (_isCategoryVisible('network') && _matchesSearch('rede p2p stun timeout webrtc espelhar conexão'))
                      _buildSectionCard(
                        context: context,
                        icon: Icons.sensors_rounded,
                        title: 'Rede P2P & Conexão Direta',
                        subtitle: 'Configurações de WebRTC, travessia de NAT e espelhamento',
                        children: [
                          ListTile(
                            leading: const Icon(Icons.qr_code_scanner_rounded),
                            title: const Text('Receber Conta por QR Code'),
                            subtitle: const Text('Configurar este dispositivo como espelho de outro aparelho'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => DeviceMirrorReceiveView(
                                    onAccountMirrored: () => Navigator.of(context).pop(),
                                  ),
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.devices_other_rounded),
                            title: const Text('Dispositivos Espelhados Ativos'),
                            subtitle: Text('${_user.mirroredDevices.length} dispositivos autorizados'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const DeviceMirrorHostView(),
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1),

                          // Servidor STUN / ICE
                          _buildChoicePill<String>(
                            context: context,
                            title: 'Servidor STUN (Travessia de NAT P2P)',
                            subtitle: 'Auxilia na descoberta direta de IP sem rotear o tráfego da conversa',
                            selected: s.stunServer,
                            options: const {
                              'stun:stun.l.google.com:19302': 'Google STUN (Padrão Global)',
                              'stun:stun1.l.google.com:19302': 'Google Backup STUN',
                              'stun:stun.cloudflare.com:3478': 'Cloudflare STUN',
                            },
                            onSelected: (val) => _update((prev) => prev.copyWith(stunServer: val)),
                          ),
                          const Divider(height: 1),

                          // Timeout de Conexão
                          _buildChoicePill<int>(
                            context: context,
                            title: 'Tempo Limite de Conexão P2P (Handshake)',
                            subtitle: 'Tempo máximo aguardando a troca de sinais WebRTC',
                            selected: s.connectionTimeoutSeconds,
                            options: const {
                              10: '10s (Rápido)',
                              20: '20s',
                              30: '30s (Recomendado)',
                              45: '45s',
                              60: '60s (Redes Lentas)',
                            },
                            onSelected: (val) => _update((prev) => prev.copyWith(connectionTimeoutSeconds: val)),
                          ),
                          const Divider(height: 1),

                          // Keep-Alive Ping P2P
                          _buildChoicePill<int>(
                            context: context,
                            title: 'Frequência de Keep-Alive WebRTC',
                            subtitle: 'Intervalo de pacotes ping para manter a porta NAT aberta no roteador',
                            selected: s.keepAliveIntervalSeconds,
                            options: const {
                              5: '5s (Intenso)',
                              10: '10s',
                              15: '15s (Recomendado)',
                              30: '30s (Econômico)',
                            },
                            onSelected: (val) => _update((prev) => prev.copyWith(keepAliveIntervalSeconds: val)),
                          ),
                          const Divider(height: 1),

                          SwitchListTile(
                            secondary: const Icon(Icons.sync_rounded),
                            title: const Text('Reconexão P2P Automática'),
                            subtitle: const Text('Tentar restabelecer automaticamente conexões de canais WebRTC interrompidos'),
                            value: s.autoReconnectP2P,
                            onChanged: (val) => _update((prev) => prev.copyWith(autoReconnectP2P: val)),
                          ),
                          const Divider(height: 1),

                          SwitchListTile(
                            secondary: const Icon(Icons.data_saver_on_rounded),
                            title: const Text('Modo Economia de Dados P2P'),
                            subtitle: const Text('Reduz tráfego de diagnóstico de rede e otimiza transferências para planos móveis'),
                            value: s.p2pDataSaver,
                            onChanged: (val) => _update((prev) => prev.copyWith(p2pDataSaver: val)),
                          ),
                        ],
                      ),

                    // ==========================================
                    // 6. ARMAZENAMENTO & MÍDIA
                    // ==========================================
                    if (_isCategoryVisible('storage') && _matchesSearch('armazenamento mídia cache download dados'))
                      _buildSectionCard(
                        context: context,
                        icon: Icons.storage_rounded,
                        title: 'Armazenamento & Mídia P2P',
                        subtitle: 'Controle de arquivos recebidos e cache local',
                        children: [
                          SwitchListTile(
                            secondary: const Icon(Icons.download_for_offline_outlined),
                            title: const Text('Download Automático de Arquivos'),
                            subtitle: const Text('Baixar automaticamente fotos e áudios com tamanho inferior a 5MB'),
                            value: s.autoDownloadFiles,
                            onChanged: (val) => _update((prev) => prev.copyWith(autoDownloadFiles: val)),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.cleaning_services_outlined),
                            title: const Text('Limpar Cache de Arquivos Temporários'),
                            subtitle: const Text('Libera espaço apagando mídias temporárias de transferências'),
                            trailing: TextButton(
                              onPressed: () {
                                _notice('Cache de transferências temporárias limpo.');
                              },
                              child: const Text('Limpar Cache'),
                            ),
                          ),
                        ],
                      ),

                    // ==========================================
                    // 7. SOBRE & PERMISSÕES
                    // ==========================================
                    if (_isCategoryVisible('about') && _matchesSearch('sobre versão permissões sistema boas vindas'))
                      _buildSectionCard(
                        context: context,
                        icon: Icons.info_outline_rounded,
                        title: 'Sobre o Nexora & Permissões do Sistema',
                        subtitle: 'Diagnóstico da instalação e status do sistema operacional',
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Status das Permissões do Sistema',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _buildStatusBadge('Microfone', permState.microphone),
                                    _buildStatusBadge('Câmera', permState.camera),
                                    _buildStatusBadge('Notificações', permState.notifications),
                                    _buildStatusBadge('Bluetooth', permState.bluetooth),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.tonalIcon(
                                        onPressed: _requestingPermissions ? null : _requestSystemPermissions,
                                        icon: const Icon(Icons.verified_user_outlined, size: 16),
                                        label: Text(_requestingPermissions ? 'Verificando...' : 'Revisar Permissões'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => WelcomePermissionsView(
                                                onCompleted: () => Navigator.of(context).pop(),
                                              ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.celebration_outlined, size: 16),
                                        label: const Text('Boas-Vindas'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const BrandMark(size: 32),
                            title: const Text('Nexora - Comunicação P2P Criptografada'),
                            subtitle: const Text(
                              'Versão 1.0.0 (Build Release) • Criptografia Ed25519 & AES-256-GCM',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
