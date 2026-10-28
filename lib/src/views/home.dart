import 'package:flutter/services.dart';
import 'package:nexora/src/services/group_invitation_service.dart';
import 'package:flutter/material.dart';
import 'package:nexora/src/models/conversation.dart';
import 'package:nexora/src/services/local_data_service.dart';
import 'package:nexora/src/services/identity_protocol.dart';
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
  final _service = LocalDataService.instance;
  @override
  void initState() {
    super.initState();
    _service.addListener(_refresh);
  }

  @override
  void dispose() {
    _service.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
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
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => P2PChatPage(
          conversation: conversation,
          conversationTitle: _service.conversationName(conversation),
        ),
      ),
    );
  }

  Future<void> _manage(Conversation conversation, String action) async {
    if (action == 'share') {
      try {
        final code = await GroupInvitationService.export(
          conversation,
          _service,
        );
        await Clipboard.setData(ClipboardData(text: code));
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Convite de grupo copiado. Compartilhe com os membros por um canal confiável.',
              ),
            ),
          );
      } catch (_) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não foi possível copiar o convite.')),
          );
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
              if (action == 'delete' || form.currentState!.validate())
                Navigator.pop(context, true);
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
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível salvar a alteração.')),
        );
    }
  }

  bool conversationBlocked(Conversation c) =>
      c.participantIds.any(_service.isBlocked);

  Future<void> _create() async {
    final form = GlobalKey<FormState>();
    String key = '';
    final result = await showDialog<({String key, String name})>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nova conversa'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Peça a chave pública do contato e confirme por outro canal.',
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    autofocus: true,
                    maxLength: 100,
                    minLines: 2,
                    maxLines: 3,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Chave pública do contato',
                      hintText: 'Cole a chave Ed25519',
                    ),
                    onChanged: (value) => key = value,
                    validator: (value) {
                      try {
                        final normalized = IdentityProtocol.normalize(
                          value ?? '',
                        );
                        if (normalized == _service.currentUser.publicKey)
                          return 'Use a chave de outra pessoa.';
                        return null;
                      } catch (_) {
                        return 'Informe uma chave pública válida.';
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
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate())
                Navigator.pop(context, (key: key.trim(), name: ''));
            },
            child: const Text('Iniciar conversa'),
          ),
        ],
      ),
    );
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
          title: const Text('Criar grupo'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      maxLength: 48,
                      decoration: const InputDecoration(
                        labelText: 'Nome do grupo',
                      ),
                      onChanged: (value) => name = value,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Informe um nome.'
                          : null,
                    ),
                    const Text(
                      'Escolha pelo menos dois contatos. Depois, compartilhe o convite de grupo com eles.',
                    ),
                    if (contacts.length < 2)
                      const Text(
                        'Conecte-se individualmente com pelo menos dois contatos primeiro, para receber seus apelidos.',
                      ),
                    for (final key in contacts)
                      CheckboxListTile(
                        title: Text(_service.contactName(key)),
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
                      if (form.currentState!.validate())
                        Navigator.pop(dialogContext, true);
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
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível criar o grupo.')),
        );
    }
  }

  Future<void> _joinGroup() async {
    var code = '';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Entrar em grupo'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Cole um convite recebido por um canal confiável. Entrar compartilha suas mensagens com todos os membros do convite.',
              ),
              TextField(
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                enableIMEPersonalizedLearning: false,
                decoration: const InputDecoration(
                  labelText: 'Convite do grupo',
                ),
                onChanged: (value) => code = value,
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
    if (accepted != true || !mounted) return;
    try {
      final group = await GroupInvitationService.import(code.trim(), _service);
      if (mounted) _open(group);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Convite inválido, contato bloqueado ou sua chave não está entre os membros.',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final conversations =
        _service.conversations
            .where(
              (c) =>
                  _service.conversationName(c).toLowerCase().contains(_query),
            )
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
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
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Conversas',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -.8,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Um espaço para conversar em privado.',
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                    FilledButton.icon(
                      onPressed: _create,
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Nova conversa'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _createGroup,
                      icon: const Icon(Icons.group_add_outlined),
                      label: const Text('Criar grupo'),
                    ),
                    TextButton(
                      onPressed: _joinGroup,
                      child: const Text('Entrar em grupo'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Buscar apelido ou grupo',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Icon(Icons.lock_outline, size: 14, color: colors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Conexão direta • Histórico em armazenamento seguro',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
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
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: colors.primaryContainer.withValues(alpha: .35),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.chat_bubble_outline,
                        size: 28,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _query.isEmpty
                          ? 'Sua primeira conversa começa aqui'
                          : 'Nenhuma conversa encontrada',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _query.isEmpty
                          ? 'Adicione a chave pública de alguém.\nDepois, troquem um convite para se conectar.'
                          : 'Tente outro apelido ou grupo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (_query.isEmpty)
                      OutlinedButton.icon(
                        onPressed: _create,
                        icon: const Icon(Icons.key_outlined, size: 18),
                        label: const Text('Adicionar contato'),
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
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ConversationTile(
                    conversation: conversations[index],
                    displayName: _service.conversationName(
                      conversations[index],
                    ),
                    currentUser: _service.currentUser,
                    isBlocked: conversationBlocked(conversations[index]),
                    onManage: (action) => _manage(conversations[index], action),
                    onOpen: () => _open(conversations[index]),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
