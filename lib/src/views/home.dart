import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexora/src/models/conversation.dart';
import 'package:nexora/src/services/conversation_tabs_service.dart';
import 'package:nexora/src/services/group_invitation_service.dart';
import 'package:nexora/src/services/identity_protocol.dart';
import 'package:nexora/src/services/local_data_service.dart';
import 'package:nexora/src/services/settings_services.dart';
import 'package:nexora/src/views/p2p_chat.dart';
import 'package:nexora/src/views/widgets/app_theme.dart';
import 'package:nexora/src/views/widgets/conversation_tile.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _query = '';
  String _chatFilter = 'all';
  final _service = LocalDataService.instance;
  final _settings = SettingsService.instance;

  @override
  void initState() {
    super.initState();
    _service.addListener(_refresh);
    _settings.addListener(_refresh);
  }

  @override
  void dispose() {
    _service.removeListener(_refresh);
    _settings.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _copyMyKey() async {
    final key = _service.currentUser.publicKey;
    if (key.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: key));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Chave pública copiada. Envie ao seu contato para iniciar.',
          ),
        ),
      );
    }
  }

  void _open(Conversation conversation) {
    if (conversation.participantIds.any(_service.isBlocked)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contato bloqueado. Desbloqueie nas configurações.'),
        ),
      );
      return;
    }
    ConversationTabsService.instance.openConversation(
      conversation,
      title: _service.conversationName(conversation),
    );
  }

  Future<void> _manage(Conversation conversation, String action) async {
    if (action == 'pin') {
      await _service.togglePinConversation(conversation.id);
      return;
    }
    if (action == 'mute') {
      await _service.toggleMuteConversation(conversation.id);
      return;
    }
    if (action == 'share') {
      try {
        final code = await GroupInvitationService.export(
          conversation,
          _service,
        );
        await Clipboard.setData(ClipboardData(text: code));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Convite de grupo copiado. Compartilhe com os membros por um canal confiável.',
              ),
            ),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não foi possível copiar o convite.')),
          );
        }
      }
      return;
    }
    String name = conversation.title;
    final form = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          action == 'delete' ? 'Excluir conversa local?' : 'Renomear grupo',
        ),
        content: action == 'delete'
            ? const Text(
                'Remove o contato e o histórico salvo deste dispositivo. Cópias da outra pessoa permanecem.',
              )
            : Form(
                key: form,
                child: TextFormField(
                  initialValue: name,
                  maxLength: 48,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Nome do grupo'),
                  onChanged: (value) => name = value,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Informe um nome.'
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
              if (action == 'delete' || form.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: Text(action == 'delete' ? 'Excluir' : 'Salvar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      if (action == 'delete') {
        await _service.deleteConversation(conversation.id);
      } else {
        await _service.renameConversation(conversation.id, name);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível salvar a alteração.')),
        );
      }
    }
  }

  bool conversationBlocked(Conversation c) =>
      c.participantIds.any(_service.isBlocked);

  Future<void> _create() async {
    final form = GlobalKey<FormState>();
    final controller = TextEditingController();
    final result = await showDialog<({String key, String name})>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nova conversa P2P'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Informe a chave pública Ed25519 do contato. Após adicionar, vocês poderão conversar por texto, voz e vídeo P2P.',
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: controller,
                    autofocus: true,
                    maxLength: 100,
                    minLines: 2,
                    maxLines: 3,
                    autocorrect: false,
                    enableSuggestions: false,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Chave pública do contato',
                      hintText: 'Cole a chave Ed25519 (44 caracteres Base64)',
                      suffixIcon: IconButton(
                        tooltip: 'Colar da área de transferência',
                        icon: const Icon(Icons.content_paste_rounded),
                        onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          final text = data?.text?.trim();
                          if (text != null && text.isNotEmpty) {
                            controller.text = text;
                          }
                        },
                      ),
                    ),
                    validator: (value) {
                      try {
                        final normalized = IdentityProtocol.normalize(
                          value ?? '',
                        );
                        if (normalized == _service.currentUser.publicKey) {
                          return 'Use a chave de outra pessoa.';
                        }
                        return null;
                      } catch (_) {
                        return 'Informe uma chave pública Ed25519 válida.';
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(
                  context,
                  (key: controller.text.trim(), name: ''),
                );
              }
            },
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text('Iniciar conversa'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !mounted) return;
    try {
      final conversation = await _service.createConversation(
        title: result.name,
        participantIds: [_service.currentUser.id, result.key],
      );
      if (mounted) _open(conversation);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível criar a conversa. Confira a chave pública.',
          ),
        ),
      );
    }
  }

  Future<void> _createGroup() async {
    final contacts = _service.conversations
        .where((c) => !c.isGroup)
        .expand((c) => c.participantIds)
        .where(
          (key) =>
              key != _service.currentUser.id &&
              !_service.isBlocked(key) &&
              _service.hasContactName(key),
        )
        .toSet()
        .toList();
    final selected = <String>{};
    var name = '';
    final form = GlobalKey<FormState>();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Criar grupo em malha P2P'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      maxLength: 48,
                      decoration: const InputDecoration(
                        labelText: 'Nome do grupo',
                        prefixIcon: Icon(Icons.groups_outlined),
                      ),
                      onChanged: (value) => name = value,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Informe um nome.'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Escolha pelo menos dois contatos já autenticados. Em seguida, compartilhe o convite assinado do grupo com eles.',
                    ),
                    if (contacts.length < 2) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Conecte-se individualmente com pelo menos dois contatos primeiro para receber seus apelidos.',
                          style: TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    for (final key in contacts)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_service.contactName(key)),
                        subtitle: Text(
                          AppTheme.formatKeyPreview(key),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11.5,
                          ),
                        ),
                        value: selected.contains(key),
                        onChanged: (value) => update(() {
                          if (value == true) {
                            selected.add(key);
                          } else {
                            selected.remove(key);
                          }
                        }),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: selected.length < 2
                  ? null
                  : () {
                      if (form.currentState!.validate()) {
                        Navigator.pop(dialogContext, true);
                      }
                    },
              child: const Text('Criar grupo'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !mounted) return;
    try {
      final group = await _service.createConversation(
        title: name,
        participantIds: [_service.currentUser.id, ...selected],
        isGroup: true,
      );
      if (mounted) {
        await _manage(group, 'share');
      }
      if (mounted) _open(group);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível criar o grupo.')),
        );
      }
    }
  }

  Future<void> _joinGroup() async {
    final controller = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Entrar em grupo'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Cole o convite assinado recebido de um contato confiável.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                enableIMEPersonalizedLearning: false,
                decoration: InputDecoration(
                  labelText: 'Convite do grupo',
                  suffixIcon: IconButton(
                    tooltip: 'Colar convite',
                    icon: const Icon(Icons.content_paste_rounded),
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      final text = data?.text?.trim();
                      if (text != null && text.isNotEmpty) {
                        controller.text = text;
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Entrar'),
          ),
        ],
      ),
    );
    final code = controller.text.trim();
    controller.dispose();
    if (accepted != true || !mounted) return;
    try {
      final group = await GroupInvitationService.import(code, _service);
      if (mounted) _open(group);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Convite inválido, contato bloqueado ou sua chave não está entre os membros.',
            ),
          ),
        );
      }
    }
  }

  Widget _buildFilterChip(String id, String label, IconData icon) {
    final colors = Theme.of(context).colorScheme;
    final selected = _chatFilter == id;
    return Material(
      color: selected
          ? colors.primary.withValues(alpha: 0.16)
          : colors.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _chatFilter = id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? colors.primary.withValues(alpha: 0.45)
                  : colors.outlineVariant.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? colors.primary : colors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final user = _service.currentUser;
    final filteredByTab = _service.conversations.where((c) {
      if (c.isCommunity) return false;
      if (_chatFilter == 'direct') {
        return !c.isGroup && !c.isSavedMessages;
      }
      if (_chatFilter == 'groups') {
        return c.isGroup;
      }
      return true;
    });

    final conversations = filteredByTab
        .where(
          (c) => _service.conversationName(c).toLowerCase().contains(_query),
        )
        .toList()
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) {
          return a.isPinned ? -1 : 1;
        }
        return b.updatedAt.compareTo(a.updatedAt);
      });

    return PageFrame(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            sliver: SliverList.list(
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Conversas e Chamadas',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.8,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Mensagens criptografadas, voz e vídeo P2P diretos.',
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          onPressed: _create,
                          icon: const Icon(Icons.person_add_alt_1_rounded, size: 19),
                          label: const Text('Nova conversa'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _createGroup,
                          icon: const Icon(Icons.group_add_outlined, size: 19),
                          label: const Text('Criar grupo'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _joinGroup,
                          icon: const Icon(Icons.login_rounded, size: 18),
                          label: const Text('Entrar em grupo'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () async {
                            final vault = await _service.getOrCreateSavedMessages();
                            _open(vault);
                          },
                          icon: const Icon(Icons.bookmark_rounded, size: 18),
                          label: const Text('Mensagens Salvas'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Quick Identity & Key Sharing Card (Clean modern aesthetic)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withValues(alpha: .35),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.outlineVariant.withValues(alpha: .5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              colors.primary.withValues(alpha: .22),
                              colors.secondary.withValues(alpha: .12),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colors.primary.withValues(alpha: .3),
                          ),
                        ),
                        child: Icon(
                          Icons.fingerprint_rounded,
                          color: colors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.nickname.isEmpty
                                  ? 'Sua chave pública Ed25519'
                                  : 'Identidade ativa: ${user.nickname}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                letterSpacing: -.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.publicKey.isEmpty
                                  ? 'Chave indisponível'
                                  : user.publicKey,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11.5,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.tonalIcon(
                        onPressed: user.publicKey.isEmpty ? null : _copyMyKey,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(44, 38),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copiar'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Filtrar conversas por apelido ou grupo...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () => setState(() => _query = ''),
                          )
                        : null,
                    filled: true,
                    fillColor: colors.surfaceContainerHighest.withValues(alpha: .25),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: colors.outlineVariant.withValues(alpha: .4),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: colors.outlineVariant.withValues(alpha: .4),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: colors.primary.withValues(alpha: .7),
                        width: 1.5,
                      ),
                    ),
                  ),
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                ),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('all', 'Todas', Icons.forum_rounded),
                      const SizedBox(width: 8),
                      _buildFilterChip('direct', 'Diretas (1-a-1)', Icons.person_rounded),
                      const SizedBox(width: 8),
                      _buildFilterChip('groups', 'Grupos', Icons.groups_rounded),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 15,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Criptografia ponta a ponta • Voz e Vídeo DTLS-SRTP • Armazenamento seguro',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
          if (conversations.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: colors.primaryContainer.withValues(alpha: .38),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: colors.primary.withValues(alpha: .25),
                        ),
                      ),
                      child: Icon(
                        Icons.forum_outlined,
                        size: 30,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      _query.isEmpty
                          ? 'Nenhuma conversa iniciada ainda'
                          : 'Nenhuma conversa encontrada',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _query.isEmpty
                          ? 'Adicione a chave pública de um contato para trocar mensagens,\narquivos e realizar chamadas de voz e vídeo P2P.'
                          : 'Tente buscar por outro apelido ou nome de grupo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_query.isEmpty)
                      FilledButton.icon(
                        onPressed: _create,
                        icon: const Icon(Icons.key_rounded, size: 18),
                        label: const Text('Adicionar primeiro contato'),
                      ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              sliver: SliverList.builder(
                itemCount: conversations.length,
                itemBuilder: (context, index) {
                  final isCompact = _settings.settings.layoutDensity == 'compact';
                  return Padding(
                    padding: EdgeInsets.only(bottom: isCompact ? 6 : 10),
                    child: ConversationTile(
                      conversation: conversations[index],
                      displayName: _service.conversationName(
                        conversations[index],
                      ),
                      currentUser: _service.currentUser,
                      isBlocked: conversationBlocked(conversations[index]),
                      stealthMode: _settings.settings.stealthMode,
                      isCompact: isCompact,
                      onManage: (action) => _manage(conversations[index], action),
                      onOpen: () => _open(conversations[index]),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
