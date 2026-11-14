import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexora/src/models/conversation.dart';
import 'package:nexora/src/services/conversation_tabs_service.dart';
import 'package:nexora/src/services/group_invitation_service.dart';
import 'package:nexora/src/services/local_data_service.dart';
import 'package:nexora/src/services/settings_services.dart';
import 'package:nexora/src/utils/qr_code.dart';
import 'package:nexora/src/views/p2p_chat.dart';
import 'package:nexora/src/views/widgets/app_theme.dart';
import 'package:nexora/src/views/widgets/confirmation_dialog.dart';
import 'package:nexora/src/views/widgets/crypto_avatar.dart';

class CommunitiesPage extends StatefulWidget {
  const CommunitiesPage({super.key});

  @override
  State<CommunitiesPage> createState() => _CommunitiesPageState();
}

class _CommunitiesPageState extends State<CommunitiesPage> {
  final _service = LocalDataService.instance;
  final _settings = SettingsService.instance;
  String _query = '';

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

  void _open(Conversation community) {
    if (community.participantIds.any(_service.isBlocked)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comunidade possui participantes bloqueados.'),
        ),
      );
      return;
    }
    ConversationTabsService.instance.openConversation(
      community,
      title: _service.conversationName(community),
    );
  }

  Conversation? _latestCommunity(String id) {
    return _service.conversations.where((c) => c.id == id).firstOrNull;
  }

  Future<void> _showInviteDialog(Conversation community) async {
    try {
      final code = await GroupInvitationService.export(community, _service);
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.qr_code_2_rounded, size: 26, color: Colors.tealAccent),
              const SizedBox(width: 10),
              Flexible(child: Text('Convite: ${community.title}')),
            ],
          ),
          content: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: CustomPaint(
                      size: const Size(200, 200),
                      painter: QrCodePainter(data: code, color: Colors.black),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Escaneie com outro dispositivo Nexora ou copie o código criptografado abaixo para entrar nesta comunidade P2P:',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SelectableText(
                      code,
                      maxLines: 4,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Código do convite copiado com sucesso!')),
                  );
                }
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copiar Convite'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível gerar o convite da comunidade.')),
        );
      }
    }
  }

  Future<void> _showAddChannelDialog(Conversation community) async {
    String channelName = '';
    final form = GlobalKey<FormState>();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Novo Canal de Tópico'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Crie um canal temático para organizar as conversas e mídias da comunidade.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextFormField(
                autofocus: true,
                maxLength: 32,
                decoration: const InputDecoration(
                  labelText: 'Nome do canal',
                  hintText: 'Ex: projetos, memes, anúncios',
                  prefixText: '#',
                ),
                onChanged: (v) => channelName = v,
                validator: (v) => v == null || v.trim().isEmpty ? 'Informe o nome do canal.' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Criar Canal'),
          ),
        ],
      ),
    );

    if (created == true && channelName.trim().isNotEmpty) {
      await _service.addChannelToConversation(community.id, channelName.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Canal "#${channelName.trim().toLowerCase()}" criado com sucesso!')),
        );
      }
    }
  }

  Future<void> _showRenameChannelDialog(Conversation community, String oldChannel) async {
    String newName = oldChannel;
    final form = GlobalKey<FormState>();
    final renamed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Renomear Canal #$oldChannel'),
        content: Form(
          key: form,
          child: TextFormField(
            initialValue: oldChannel,
            autofocus: true,
            maxLength: 32,
            decoration: const InputDecoration(
              labelText: 'Novo nome do canal',
              prefixText: '#',
            ),
            onChanged: (v) => newName = v,
            validator: (v) => v == null || v.trim().isEmpty ? 'Informe um nome.' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Renomear'),
          ),
        ],
      ),
    );

    if (renamed == true && newName.trim().isNotEmpty && newName.trim() != oldChannel) {
      await _service.renameChannelInConversation(community.id, oldChannel, newName.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Canal renomeado para "#${newName.trim().toLowerCase()}"')),
        );
      }
    }
  }

  Future<void> _showAddMembersDialog(Conversation community) async {
    final available = _service.conversations
        .where((c) => !c.isGroup && !c.isSavedMessages && !c.isCommunity)
        .expand((c) => c.participantIds)
        .where((key) =>
            key != _service.currentUser.id &&
            !community.participantIds.contains(key) &&
            !_service.isBlocked(key))
        .toSet()
        .toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todos os seus contatos 1:1 já fazem parte desta comunidade ou você pode compartilhar o convite assinado.'),
        ),
      );
      return;
    }

    final selected = <String>{};
    final added = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('Adicionar Membros à Comunidade'),
          content: SizedBox(
            width: 400,
            height: 280,
            child: ListView.builder(
              itemCount: available.length,
              itemBuilder: (context, index) {
                final key = available[index];
                final name = _service.contactName(key);
                final isSel = selected.contains(key);
                return CheckboxListTile(
                  dense: true,
                  value: isSel,
                  title: Text(name),
                  subtitle: Text(AppTheme.formatKeyPreview(key)),
                  onChanged: (val) {
                    setDlgState(() {
                      if (val == true) {
                        selected.add(key);
                      } else {
                        selected.remove(key);
                      }
                    });
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: selected.isEmpty ? null : () => Navigator.pop(context, true),
              child: Text('Adicionar (${selected.length})'),
            ),
          ],
        ),
      ),
    );

    if (added == true && selected.isNotEmpty) {
      for (final key in selected) {
        await _service.addMemberToCommunity(community.id, key);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${selected.length} membro(s) adicionado(s) com sucesso!')),
        );
      }
    }
  }

  void _showCommunitySettingsDialog(Conversation initialCommunity) {
    final colors = Theme.of(context).colorScheme;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final comm = _latestCommunity(initialCommunity.id) ?? initialCommunity;
          final channels = comm.channels.isNotEmpty ? comm.channels : ['geral'];
          final isOwner = comm.creatorId == _service.currentUser.id || comm.adminIds.contains(_service.currentUser.id);

          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ListView(
                controller: scrollController,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header da Comunidade
                  Row(
                    children: [
                      CryptoAvatar(
                        seedKey: comm.id,
                        title: comm.title,
                        isCommunity: true,
                        size: 56,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              comm.title,
                              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${comm.participantIds.length} membros • ${channels.length} canais de tópicos',
                              style: TextStyle(fontSize: 12.5, color: colors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Editar nome ou descrição',
                        onPressed: () async {
                          await _editCommunityDetails(comm);
                          setSheetState(() {});
                        },
                      ),
                    ],
                  ),
                  if (comm.description != null && comm.description!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        comm.description!,
                        style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant, height: 1.4),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  const Divider(),

                  // Seção: Canais de Tópicos
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.tag_rounded, color: colors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Canais de Tópicos (${channels.length})',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          await _showAddChannelDialog(comm);
                          setSheetState(() {});
                        },
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Novo Canal'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.outlineVariant.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: channels.map((ch) {
                        final isOnly = channels.length <= 1;
                        return ListTile(
                          dense: true,
                          leading: Icon(Icons.tag_rounded, size: 18, color: colors.primary),
                          title: Text('#$ch', style: const TextStyle(fontWeight: FontWeight.w600)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 17),
                                tooltip: 'Renomear canal',
                                onPressed: () async {
                                  await _showRenameChannelDialog(comm, ch);
                                  setSheetState(() {});
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.cleaning_services_outlined, size: 17),
                                tooltip: 'Limpar mensagens deste canal',
                                onPressed: () async {
                                  final confirmed = await confirmAction(
                                    context,
                                    title: 'Limpar canal #$ch?',
                                    description: 'Apagará todas as mensagens locais do canal #$ch nesta comunidade.',
                                    action: 'Limpar',
                                  );
                                  if (confirmed) {
                                    await _service.clearCommunityMessages(comm.id, channel: ch);
                                    setSheetState(() {});
                                  }
                                },
                              ),
                              if (!isOnly)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 17, color: Colors.redAccent),
                                  tooltip: 'Excluir canal',
                                  onPressed: () async {
                                    final confirmed = await confirmAction(
                                      context,
                                      title: 'Excluir canal #$ch?',
                                      description: 'O canal #$ch será removido desta comunidade.',
                                      action: 'Excluir',
                                    );
                                    if (confirmed) {
                                      await _service.removeChannelFromConversation(comm.id, ch);
                                      setSheetState(() {});
                                    }
                                  },
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Divider(),

                  // Seção: Membros da Malha
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.people_outline_rounded, color: colors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Membros na Malha (${comm.participantIds.length})',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await _showAddMembersDialog(comm);
                          setSheetState(() {});
                        },
                        icon: const Icon(Icons.person_add_outlined, size: 16),
                        label: const Text('Convidar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.outlineVariant.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: comm.participantIds.map((key) {
                        final isMe = key == _service.currentUser.id;
                        final isCreator = comm.creatorId == key;
                        final isAdmin = comm.adminIds.contains(key);
                        final name = isMe ? 'Você' : _service.contactName(key);

                        return ListTile(
                          dense: true,
                          leading: CryptoAvatar(seedKey: key, title: name, size: 32),
                          title: Row(
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(width: 6),
                              if (isCreator)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('Criador', style: TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold)),
                                )
                              else if (isAdmin)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('Admin', style: TextStyle(fontSize: 10, color: Colors.tealAccent, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          subtitle: Text(AppTheme.formatKeyPreview(key), style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                          trailing: isOwner && !isMe
                              ? PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert_rounded, size: 18),
                                  onSelected: (val) async {
                                    if (val == 'toggle_admin') {
                                      await _service.toggleCommunityAdmin(comm.id, key);
                                      setSheetState(() {});
                                    } else if (val == 'remove') {
                                      await _service.removeMemberFromCommunity(comm.id, key);
                                      setSheetState(() {});
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    PopupMenuItem(
                                      value: 'toggle_admin',
                                      child: Text(isAdmin ? 'Remover de Admin' : 'Promover a Admin'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'remove',
                                      child: Text('Remover da Comunidade', style: TextStyle(color: Colors.redAccent)),
                                    ),
                                  ],
                                )
                              : null,
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Divider(),

                  // Seção: Ações e Convite
                  ListTile(
                    leading: const Icon(Icons.qr_code_2_rounded, color: Colors.tealAccent),
                    title: const Text('Convite Criptografado & QR Code'),
                    subtitle: const Text('Exibir QR Code e código assinado para novos membros'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showInviteDialog(comm),
                  ),
                  SwitchListTile(
                    secondary: Icon(comm.isMuted ? Icons.volume_off_outlined : Icons.volume_up_outlined),
                    title: const Text('Silenciar Comunidade'),
                    subtitle: const Text('Desativar notificações sonoras e push desta comunidade'),
                    value: comm.isMuted,
                    onChanged: (val) async {
                      await _service.toggleMuteConversation(comm.id);
                      setSheetState(() {});
                    },
                  ),
                  SwitchListTile(
                    secondary: Icon(comm.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined),
                    title: const Text('Fixar no Topo'),
                    subtitle: const Text('Manter no topo da lista de conversas e comunidades'),
                    value: comm.isPinned,
                    onChanged: (val) async {
                      await _service.togglePinConversation(comm.id);
                      setSheetState(() {});
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.cleaning_services_outlined, color: Colors.amber),
                    title: const Text('Limpar Mensagens Locais'),
                    subtitle: const Text('Apaga todas as mensagens salvas em todos os canais desta comunidade'),
                    onTap: () async {
                      final confirmed = await confirmAction(
                        context,
                        title: 'Limpar histórico da comunidade?',
                        description: 'Todas as mensagens recebidas nos canais desta comunidade serão apagadas deste aparelho.',
                        action: 'Limpar Tudo',
                      );
                      if (confirmed) {
                        await _service.clearCommunityMessages(comm.id);
                        setSheetState(() {});
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.exit_to_app_rounded, color: Colors.redAccent),
                    title: const Text('Sair da Comunidade Local', style: TextStyle(color: Colors.redAccent)),
                    subtitle: const Text('Remove a comunidade e todos os seus canais deste dispositivo'),
                    onTap: () async {
                      final confirmed = await confirmAction(
                        context,
                        title: 'Sair da comunidade?',
                        description: 'Você deixará de participar desta comunidade P2P neste dispositivo.',
                        action: 'Sair e Excluir',
                      );
                      if (confirmed) {
                        await _service.deleteConversation(comm.id);
                        if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _editCommunityDetails(Conversation community) async {
    String name = community.title;
    String description = community.description ?? '';
    final form = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Comunidade'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: name,
                maxLength: 48,
                decoration: const InputDecoration(labelText: 'Nome da Comunidade'),
                onChanged: (v) => name = v,
                validator: (v) => v == null || v.trim().isEmpty ? 'Informe um nome.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: description,
                maxLength: 140,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Descrição ou Regras'),
                onChanged: (v) => description = v,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (saved == true) {
      if (name.trim() != community.title) {
        await _service.renameConversation(community.id, name.trim());
      }
      if (description.trim() != (community.description ?? '')) {
        await _service.updateConversationDescription(community.id, description.trim());
      }
    }
  }

  Future<void> _manage(Conversation community, String action) async {
    if (action == 'settings') {
      _showCommunitySettingsDialog(community);
      return;
    }
    if (action == 'channels') {
      await _showAddChannelDialog(community);
      return;
    }
    if (action == 'members') {
      await _showAddMembersDialog(community);
      return;
    }
    if (action == 'pin') {
      await _service.togglePinConversation(community.id);
      return;
    }
    if (action == 'mute') {
      await _service.toggleMuteConversation(community.id);
      return;
    }
    if (action == 'share') {
      await _showInviteDialog(community);
      return;
    }
    if (action == 'clear') {
      final confirmed = await confirmAction(
        context,
        title: 'Limpar mensagens locais?',
        description: 'Remove o histórico de mensagens salvas de todos os canais desta comunidade.',
        action: 'Limpar',
      );
      if (confirmed) {
        await _service.clearCommunityMessages(community.id);
      }
      return;
    }
    if (action == 'rename') {
      await _editCommunityDetails(community);
      return;
    }
    if (action == 'delete') {
      final confirmed = await confirmAction(
        context,
        title: 'Sair da comunidade local?',
        description: 'Remove os canais e o histórico local desta comunidade neste dispositivo.',
        action: 'Sair e Excluir',
      );
      if (confirmed) {
        await _service.deleteConversation(community.id);
      }
      return;
    }
  }

  Future<void> _createCommunity() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final channelsCtrl = TextEditingController(text: 'geral, anúncios, mídia');
    final form = GlobalKey<FormState>();

    final available = _service.conversations
        .where((c) => !c.isGroup && !c.isSavedMessages && !c.isCommunity)
        .expand((c) => c.participantIds)
        .where(
          (key) =>
              key != _service.currentUser.id &&
              !_service.isBlocked(key) &&
              _service.hasContactName(key),
        )
        .toSet()
        .toList();
    final selectedKeys = <String>{};

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('Nova Comunidade em Malha P2P'),
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
                      'Comunidades reúnem pessoas em canais de tópicos separados com criptografia ponta a ponta.',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameCtrl,
                      autofocus: true,
                      maxLength: 48,
                      decoration: const InputDecoration(
                        labelText: 'Nome da Comunidade',
                        hintText: 'Ex: Desenvolvedores Nexora, Equipe Design',
                        prefixIcon: Icon(Icons.hub_rounded),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Informe um nome.' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descCtrl,
                      maxLines: 2,
                      maxLength: 140,
                      decoration: const InputDecoration(
                        labelText: 'Descrição ou Propósito (opcional)',
                        hintText: 'Ex: Canal oficial de discussão e atualizações.',
                        prefixIcon: Icon(Icons.description_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: channelsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Canais de tópicos (separados por vírgula)',
                        hintText: 'geral, anúncios, mídia, dúvidas',
                        prefixIcon: Icon(Icons.tag_rounded),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Informe pelo menos um canal inicial.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Adicionar membros iniciais (contatos salvos):',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (available.isEmpty)
                      const Text(
                        'Nenhum contato 1:1 disponível ainda. Você poderá convidar membros depois.',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    else
                      Container(
                        constraints: const BoxConstraints(maxHeight: 140),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: available.length,
                          itemBuilder: (context, index) {
                            final key = available[index];
                            final name = _service.contactName(key);
                            final isSel = selectedKeys.contains(key);
                            return CheckboxListTile(
                              dense: true,
                              value: isSel,
                              title: Text(name),
                              subtitle: Text(AppTheme.formatKeyPreview(key)),
                              onChanged: (val) {
                                setDlgState(() {
                                  if (val == true) {
                                    selectedKeys.add(key);
                                  } else {
                                    selectedKeys.remove(key);
                                  }
                                });
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (form.currentState!.validate()) {
                  Navigator.pop(context, true);
                }
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Criar Comunidade'),
            ),
          ],
        ),
      ),
    );

    if (created == true && mounted) {
      final rawCh = channelsCtrl.text
          .split(',')
          .map(
            (s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-'),
          )
          .where((s) => s.isNotEmpty)
          .toList();
      final channels = rawCh.isEmpty ? ['geral'] : rawCh;
      final comm = await _service.createCommunity(
        title: nameCtrl.text.trim(),
        description: descCtrl.text.trim(),
        channels: channels,
        participantKeys: selectedKeys.toList(),
      );
      if (mounted) _open(comm);
    }
  }

  Future<void> _joinCommunity() async {
    final controller = TextEditingController();
    final form = GlobalKey<FormState>();

    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Entrar em comunidade ou grupo P2P'),
        content: SizedBox(
          width: 440,
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Cole o convite assinado recebido de um membro da comunidade.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  maxLines: 4,
                  minLines: 2,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  decoration: const InputDecoration(
                    labelText: 'Código do convite',
                    hintText: 'Cole o convite JSON assinado aqui...',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Cole o convite.' : null,
                ),
              ],
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
              if (form.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Entrar'),
          ),
        ],
      ),
    );

    if (accepted != true || !mounted) return;
    try {
      final comm = await GroupInvitationService.import(
        controller.text.trim(),
        _service,
      );
      if (mounted) _open(comm);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Convite inválido ou você já participa desta comunidade.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isCompact = _settings.settings.layoutDensity == 'compact';

    final communities = _service.conversations.where((c) {
      if (!c.isCommunity) return false;
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      if (c.title.toLowerCase().contains(q)) return true;
      if ((c.description ?? '').toLowerCase().contains(q)) return true;
      if (c.channels.any((ch) => ch.toLowerCase().contains(q))) return true;
      return false;
    }).toList()
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) {
          return a.isPinned ? -1 : 1;
        }
        return b.updatedAt.compareTo(a.updatedAt);
      });

    return PageFrame(
      maxWidth: 960,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colors.primary,
                              colors.primary.withValues(alpha: .7),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withValues(alpha: .28),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.hub_rounded,
                          color: colors.onPrimary,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Comunidades P2P',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -.5,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.primary.withValues(alpha: .15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${communities.length}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: colors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Grupos descentralizados organizados por múltiplos canais de tópicos com criptografia ponta a ponta.',
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.onSurfaceVariant,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Actions bar
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: _createCommunity,
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: const Text('Criar comunidade'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _joinCommunity,
                        icon: const Icon(Icons.login_rounded, size: 18),
                        label: const Text('Entrar por convite'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Search input
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Filtrar comunidades por nome, tópico ou canal',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: (val) =>
                        setState(() => _query = val.trim().toLowerCase()),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // Community list
          if (communities.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: colors.primaryContainer.withValues(alpha: .4),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.hub_outlined,
                            size: 32,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          _query.isNotEmpty
                              ? 'Nenhuma comunidade encontrada'
                              : 'Você ainda não participa de comunidades',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _query.isNotEmpty
                              ? 'Tente outro termo de busca.'
                              : 'Crie um espaço P2P para seu projeto, equipe ou amigos com canais de tópicos e discussões criptografadas.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                        if (_query.isEmpty) ...[
                          const SizedBox(height: 22),
                          FilledButton.icon(
                            onPressed: _createCommunity,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Criar primeira comunidade'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              sliver: SliverList.builder(
                itemCount: communities.length,
                itemBuilder: (context, index) {
                  final comm = communities[index];
                  final channels = comm.channels.isNotEmpty
                      ? comm.channels
                      : const ['geral'];
                  final lastMessage = comm.messages.isNotEmpty
                      ? comm.messages.last
                      : null;

                  return Padding(
                    padding: EdgeInsets.only(bottom: isCompact ? 10 : 14),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _open(comm),
                        child: Padding(
                          padding: EdgeInsets.all(isCompact ? 14 : 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top row
                              Row(
                                children: [
                                  CryptoAvatar(
                                    seedKey: comm.id,
                                    title: comm.title,
                                    isCommunity: true,
                                    size: isCompact ? 44 : 52,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            if (comm.isPinned) ...[
                                              Icon(
                                                Icons.push_pin_rounded,
                                                size: 13,
                                                color: colors.primary,
                                              ),
                                              const SizedBox(width: 4),
                                            ],
                                            if (comm.isMuted) ...[
                                              Icon(
                                                Icons.volume_off_rounded,
                                                size: 13,
                                                color: colors.onSurfaceVariant,
                                              ),
                                              const SizedBox(width: 4),
                                            ],
                                            Flexible(
                                              child: Text(
                                                comm.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: colors.primary
                                                    .withValues(alpha: .14),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'COMUNIDADE',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                  color: colors.primary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.people_outline_rounded,
                                              size: 14,
                                              color: colors.onSurfaceVariant,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${comm.participantIds.length} membros na malha',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: colors.onSurfaceVariant,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              '•  ${channels.length} canais',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: colors.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    tooltip: 'Opções da comunidade',
                                    onSelected: (action) =>
                                        _manage(comm, action),
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(
                                        value: 'settings',
                                        child: Row(
                                          children: [
                                            Icon(Icons.tune_rounded, size: 18, color: Colors.tealAccent),
                                            SizedBox(width: 10),
                                            Text('Opções da Comunidade', style: TextStyle(fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'channels',
                                        child: Row(
                                          children: [
                                            Icon(Icons.add_rounded, size: 18),
                                            SizedBox(width: 10),
                                            Text('Criar Novo Canal'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'members',
                                        child: Row(
                                          children: [
                                            Icon(Icons.person_add_outlined, size: 18),
                                            SizedBox(width: 10),
                                            Text('Adicionar Membros'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'share',
                                        child: Row(
                                          children: [
                                            Icon(Icons.qr_code_2_rounded, size: 18),
                                            SizedBox(width: 10),
                                            Text('Convite & QR Code'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuDivider(),
                                      PopupMenuItem(
                                        value: 'pin',
                                        child: Row(
                                          children: [
                                            Icon(
                                              comm.isPinned
                                                  ? Icons.push_pin_rounded
                                                  : Icons.push_pin_outlined,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              comm.isPinned
                                                  ? 'Desafixar comunidade'
                                                  : 'Fixar no topo',
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'mute',
                                        child: Row(
                                          children: [
                                            Icon(
                                              comm.isMuted
                                                  ? Icons.volume_up_outlined
                                                  : Icons.volume_off_outlined,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              comm.isMuted
                                                  ? 'Reativar notificações'
                                                  : 'Silenciar comunidade',
                                            ),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'clear',
                                        child: Row(
                                          children: [
                                            Icon(Icons.cleaning_services_outlined, size: 18, color: Colors.amber),
                                            SizedBox(width: 10),
                                            Text('Limpar mensagens locais'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuDivider(),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.delete_outline_rounded,
                                              size: 18,
                                              color: Colors.redAccent,
                                            ),
                                            SizedBox(width: 10),
                                            Text(
                                              'Sair da comunidade',
                                              style: TextStyle(color: Colors.redAccent),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              // Description
                              if (comm.description != null &&
                                  comm.description!.trim().isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  comm.description!.trim(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: colors.onSurfaceVariant,
                                    height: 1.3,
                                  ),
                                ),
                              ],

                              const SizedBox(height: 12),

                              // Channels chips preview
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: channels.take(6).map((ch) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.surfaceContainerHighest
                                          .withValues(alpha: .5),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: colors.outlineVariant
                                            .withValues(alpha: .6),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.tag_rounded,
                                          size: 12,
                                          color: colors.primary,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          ch,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: colors.onSurface,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList()
                                  ..addAll(
                                    channels.length > 6
                                        ? [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 4,
                                              ),
                                              child: Text(
                                                '+${channels.length - 6} outros',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: colors.onSurfaceVariant,
                                                ),
                                              ),
                                            ),
                                          ]
                                        : [],
                                  ),
                              ),

                              // Last message snippet if present
                              if (lastMessage != null) ...[
                                const SizedBox(height: 10),
                                const Divider(height: 1),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '#${lastMessage.channel ?? "geral"}: ${lastMessage.textMsg}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${lastMessage.sentAt.hour.toString().padLeft(2, '0')}:${lastMessage.sentAt.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
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
