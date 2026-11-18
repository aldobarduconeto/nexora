import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexora/src/models/community_template.dart';
import 'package:nexora/src/models/conversation.dart';
import 'package:nexora/src/services/conversation_tabs_service.dart';
import 'package:nexora/src/services/group_invitation_service.dart';
import 'package:nexora/src/services/identity_protocol.dart';
import 'package:nexora/src/services/local_data_service.dart';
import 'package:nexora/src/services/settings_services.dart';
import 'package:nexora/src/views/widgets/app_theme.dart';
import 'package:nexora/src/views/widgets/category_chip_strip.dart';
import 'package:nexora/src/views/widgets/conversation_tile.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _searchController = TextEditingController();
  String _query = '';
  String _chatFilter = 'all';
  String? _categoryFilter;
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
    _searchController.dispose();
    _service.removeListener(_refresh);
    _settings.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      final selected = _categoryFilter;
      if (selected != null && !_service.conversations.any((chat) =>
          !chat.isCommunity && chat.category.isNotEmpty &&
          (selected.isEmpty || chat.category.toLowerCase() == selected))) {
        _categoryFilter = null;
      }
    });
  }

  Future<void> _copyMyKey() async {
    final key = _service.currentUser.publicKey;
    if (key.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: key));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Seu código de contato foi copiado.',
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
    if (action == 'category') {
      await _editCategory(conversation);
      return;
    }
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

  Future<void> _editCategory(Conversation conversation) async {
    final categories = <String, String>{
      for (final template in CommunityTemplate.values)
        if (template != CommunityTemplate.general)
          template.label.toLowerCase(): template.label,
      for (final chat in _service.conversations)
        if (!chat.isCommunity && chat.category.isNotEmpty)
          chat.category.toLowerCase(): chat.category,
    }.values.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    var name = conversation.category;
    final category = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Categoria da conversa'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final label in categories)
                      ActionChip(
                        label: Text(label),
                        onPressed: () => Navigator.pop(context, label),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: name,
                  maxLength: 32,
                  decoration: const InputDecoration(labelText: 'Categoria personalizada'),
                  onChanged: (value) => name = value,
                  onFieldSubmitted: (value) => Navigator.pop(context, value),
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (conversation.category.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(context, ''),
              child: const Text('Remover categoria'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, name),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (category == null || !mounted) return;
    try {
      await _service.setConversationCategory(conversation.id, category);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível salvar a categoria.')),
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
        title: const Text('Nova conversa'),
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
                    'Peça à pessoa que copie o código de contato dela no Nexora e cole aqui.',
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
                      labelText: 'Código de contato',
                      hintText: 'Cole o código compartilhado com você',
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
                          return 'Insira o código de outra pessoa.';
                        }
                        return null;
                      } catch (_) {
                        return 'Informe um código de contato válido.';
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
            'Não foi possível criar a conversa. Confira o código de contato.',
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
          title: const Text('Criar grupo'),
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
                      'Escolha pelo menos dois contatos da sua lista para criar o grupo.',
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
              'Convite inválido, contato bloqueado ou você não está entre os participantes.',
            ),
          ),
        );
      }
    }
  }

  Widget _buildFilterChip(String id, String label, IconData icon, int count) {
    final colors = Theme.of(context).colorScheme;
    final selected = _chatFilter == id;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: selected
          ? (isDark ? colors.primary.withValues(alpha: 0.18) : colors.primary.withValues(alpha: 0.12))
          : (isDark ? colors.surface.withValues(alpha: 0.6) : colors.surfaceContainerHighest.withValues(alpha: 0.45)),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _chatFilter = id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? colors.primary.withValues(alpha: 0.4)
                  : colors.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.5),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? colors.primary : colors.onSurfaceVariant.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? colors.primary : colors.onSurface.withValues(alpha: 0.9),
                  letterSpacing: -0.1,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected
                        ? colors.primary.withValues(alpha: 0.2)
                        : colors.onSurface.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: selected ? colors.primary : colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryChip(String? id, String label) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: _categoryFilter == id,
      onSelected: (selected) =>
          setState(() => _categoryFilter = selected ? id : null),
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => _buildConversations(
      context,
      PageFrame.gutter(constraints.maxWidth),
    ),
  );

  Widget _buildConversations(BuildContext context, double gutter) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = _service.currentUser;
    final nonCommunity = _service.conversations.where((c) => !c.isCommunity).toList();
    final totalCount = nonCommunity.length;
    final directCount = nonCommunity.where((c) => !c.isGroup && !c.isSavedMessages).length;
    final groupsCount = nonCommunity.where((c) => c.isGroup).length;
    final categories = <String, String>{
      for (final chat in nonCommunity)
        if (chat.category.isNotEmpty) chat.category.toLowerCase(): chat.category,
    };
    final categoryKeys = categories.keys.toList()..sort();

    final filteredByTab = nonCommunity.where((c) {
      if (_chatFilter == 'direct') {
        return !c.isGroup && !c.isSavedMessages;
      }
      if (_chatFilter == 'groups') {
        return c.isGroup;
      }
      return true;
    });

    final conversations =
        filteredByTab
            .where(
              (c) =>
                  (_categoryFilter == null ||
                      c.category.toLowerCase() == _categoryFilter) &&
                  _service.conversationName(c).toLowerCase().contains(_query),
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
            padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 0),
            sliver: SliverList.list(
              children: [
                PageHeading(
                  title: 'Conversas',
                  actions: [
                    FilledButton.icon(
                      onPressed: _create,
                      icon: const Icon(Icons.add_rounded, size: 19),
                      label: const Text('Nova conversa'),
                    ),
                    PopupMenuButton<VoidCallback>(
                      tooltip: 'Mais ações de conversa',
                      onSelected: (action) => action(),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: _createGroup,
                          child: const Row(
                            children: [
                              Icon(Icons.group_add_rounded, size: 18),
                              SizedBox(width: 10),
                              Text('Criar grupo'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: _joinGroup,
                          child: const Row(
                            children: [
                              Icon(Icons.login_rounded, size: 18),
                              SizedBox(width: 10),
                              Text('Entrar em grupo'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: () async {
                            final vault = await _service.getOrCreateSavedMessages();
                            if (mounted) _open(vault);
                          },
                          child: const Row(
                            children: [
                              Icon(Icons.bookmark_outline_rounded, size: 18),
                              SizedBox(width: 10),
                              Text('Mensagens salvas'),
                            ],
                          ),
                        ),
                        if (user.publicKey.isNotEmpty)
                          PopupMenuItem(
                            value: _copyMyKey,
                            child: const Row(
                              children: [
                                Icon(Icons.copy_rounded, size: 18),
                                SizedBox(width: 10),
                                Text('Copiar meu código P2P'),
                              ],
                            ),
                          ),
                      ],
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colors.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.6),
                          ),
                        ),
                        child: Icon(Icons.more_horiz_rounded, size: 18, color: colors.onSurface),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                            hintText: 'Buscar conversas',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            tooltip: 'Limpar busca',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark
                        ? colors.surface.withValues(alpha: 0.6)
                        : colors.surfaceContainerHighest.withValues(alpha: 0.4),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: colors.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.5),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: colors.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.5),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: colors.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('all', 'Todas', Icons.forum_rounded, totalCount),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'direct',
                        'Contatos',
                        Icons.person_rounded,
                        directCount,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'groups',
                        'Grupos',
                        Icons.groups_rounded,
                        groupsCount,
                      ),
                    ],
                  ),
                ),
                if (categoryKeys.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  CategoryChipStrip(
                    children: [
                      _categoryChip(null, 'Todas as categorias'),
                      _categoryChip('', 'Sem categoria'),
                      for (final key in categoryKeys)
                        _categoryChip(key, categories[key]!),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
          if (conversations.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: FrostedCard(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: colors.primary.withValues(alpha: .25),
                              ),
                            ),
                            child: Icon(
                              _query.isNotEmpty
                                  ? Icons.search_off_rounded
                                  : (_chatFilter == 'groups'
                                      ? Icons.groups_outlined
                                      : Icons.forum_outlined),
                              size: 28,
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            _categoryFilter != null
                                ? 'Nenhuma conversa neste filtro'
                                : _query.isEmpty
                                ? (_chatFilter == 'groups'
                                    ? 'Nenhum grupo ativo'
                                    : 'Nenhuma conversa ainda')
                                : 'Nenhum resultado encontrado',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _categoryFilter != null
                                ? 'Selecione outra categoria ou limpe os filtros.'
                                : _query.isEmpty
                                ? (_chatFilter == 'groups'
                                    ? 'Crie um grupo ou entre com um convite criptografado.'
                                    : 'Adicione um contato com o código P2P dele para iniciar um chat privado.')
                                : 'Verifique se digitou o nome corretamente ou limpe o campo de busca.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.onSurfaceVariant.withValues(alpha: 0.85),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 22),
                          if (_query.isNotEmpty)
                            OutlinedButton.icon(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              label: const Text('Limpar busca'),
                            )
                          else if (_categoryFilter != null)
                            OutlinedButton(
                              onPressed: () => setState(() => _categoryFilter = null),
                              child: const Text('Mostrar todas as categorias'),
                            )
                          else if (_chatFilter == 'groups')
                            FilledButton.icon(
                              onPressed: _createGroup,
                              icon: const Icon(Icons.add_rounded, size: 17),
                              label: const Text('Criar novo grupo'),
                            )
                          else
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                FilledButton.icon(
                                  onPressed: _create,
                                  icon: const Icon(Icons.person_add_rounded, size: 17),
                                  label: const Text('Iniciar conversa'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _joinGroup,
                                  icon: const Icon(Icons.login_rounded, size: 16),
                                  label: const Text('Entrar em grupo'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 32),
              sliver: SliverList.builder(
                itemCount: conversations.length,
                findChildIndexCallback: (Key key) {
                  if (key is ValueKey<String>) {
                    final id = key.value;
                    final idx = conversations.indexWhere((c) => 'conv_${c.id}' == id);
                    return idx != -1 ? idx : null;
                  }
                  return null;
                },
                itemBuilder: (context, index) {
                  final isCompact =
                      _settings.settings.layoutDensity == 'compact';
                  return Padding(
                    key: ValueKey('conv_${conversations[index].id}'),
                    padding: EdgeInsets.only(bottom: isCompact ? 6 : 9),
                    child: ConversationTile(
                      conversation: conversations[index],
                      displayName: _service.conversationName(
                        conversations[index],
                      ),
                      currentUser: _service.currentUser,
                      isBlocked: conversationBlocked(conversations[index]),
                      stealthMode: _settings.settings.stealthMode,
                      isCompact: isCompact,
                      onManage: (action) =>
                          _manage(conversations[index], action),
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
