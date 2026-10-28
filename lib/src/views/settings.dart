import 'package:nexora/src/views/widgets/confirmation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexora/src/models/seting.dart';
import 'package:nexora/src/services/local_data_service.dart';
import 'package:nexora/src/services/settings_services.dart';
import 'package:nexora/src/views/widgets/app_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _user = LocalDataService.instance;
  final _settings = SettingsService.instance;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _settings.addListener(_refresh);
    _user.addListener(_refresh);
  }

  @override
  void dispose() {
    _settings.removeListener(_refresh);
    _user.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _notice(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save(Setting Function(Setting) update) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _settings.updateSetting(update);
    } catch (_) {
      _notice('Não foi possível salvar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editNickname() async {
    String nickname = _user.currentUser.nickname;
    final form = GlobalKey<FormState>();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar apelido'),
        content: Form(
          key: form,
          child: TextFormField(
            initialValue: nickname,
            autofocus: true,
            maxLength: 32,
            decoration: const InputDecoration(labelText: 'Apelido'),
            onChanged: (value) => nickname = value,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Informe seu apelido.'
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
              if (form.currentState!.validate())
                Navigator.pop(context, nickname.trim());
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (value == null || !mounted) return;
    try {
      await _user.updateNickname(value);
    } catch (_) {
      _notice('Não foi possível salvar o apelido.');
    }
  }

  Future<void> _reset() async {
    final confirmed = await confirmAction(
      context,
      title: 'Restaurar preferências?',
      description: 'A aparência, as opções de histórico e as opções de conexão voltarão ao padrão. Sua identidade será mantida.',
      action: 'Restaurar',
    );
    if (confirmed != true || !mounted) return;
    await _save((_) => Setting.defaults);
  }

  Future<void> _blockedContacts() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Contatos bloqueados'),
        content: SizedBox(
          width: 440,
          child: ListenableBuilder(
            listenable: _user,
            builder: (context, _) => _user.currentUser.blockedUserIds.isEmpty
                ? const Text('Nenhum contato bloqueado.')
                : ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * .5,
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final key in _user.currentUser.blockedUserIds)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              _user.contactName(key),
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                            subtitle: const Text('Bloqueado neste dispositivo'),
                            trailing: TextButton(
                              child: const Text('Desbloquear'),
                              onPressed: () async {
                                try {
                                  await _user.setBlocked(key, false);
                                } catch (_) {
                                  _notice(
                                    'Não foi possível desbloquear o contato.',
                                  );
                                }
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
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Card(child: Column(children: children)),
      ],
    ),
  );

  Widget _choice<T>(
    String label,
    String help,
    T value,
    Map<T, String> values,
    ValueChanged<T> onChanged,
  ) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          help,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<T>(
          key: ValueKey('$label-$value'),
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: label,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
          items: values.entries
              .map(
                (entry) => DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                ),
              )
              .toList(),
          onChanged: _saving
              ? null
              : (value) {
                  if (value != null) onChanged(value);
                },
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final s = _settings.settings;
    final user = _user.currentUser;
    final colors = Theme.of(context).colorScheme;
    return PageFrame(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Configurações',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -.8),
          ),
          const SizedBox(height: 6),
          Text(
            'Seu dispositivo. Suas preferências.',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 28),
          _section('Identidade', [
            ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                backgroundColor: colors.primaryContainer,
                child: Icon(
                  Icons.person_outline,
                  color: colors.onPrimaryContainer,
                ),
              ),
              title: Text(
                user.nickname.isEmpty ? 'Seu apelido' : user.nickname,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Compartilhado com contatos ao conectar'),
              trailing: const Icon(Icons.edit_outlined, size: 20),
              onTap: _editNickname,
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chave pública',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Compartilhe esta chave para receber convites. A chave privada permanece no dispositivo.',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    user.publicKey.isEmpty
                        ? 'Disponível após criar sua identidade.'
                        : user.publicKey,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    label: const Text('Copiar chave pública'),
                    onPressed: user.publicKey.isEmpty
                        ? null
                        : () async {
                            await Clipboard.setData(
                              ClipboardData(text: user.publicKey),
                            );
                            _notice('Chave pública copiada.');
                          },
                  ),
                ],
              ),
            ),
          ]),
          _section('Aparência', [
            SwitchListTile(
              title: const Text('Tema escuro'),
              subtitle: const Text('Também disponível em tema claro.'),
              value: s.isDarkMode,
              onChanged: _saving
                  ? null
                  : (value) => _save((s) => s.copyWith(isDarkMode: value)),
            ),
            const Divider(),
            _choice(
              'Cor de destaque',
              'Aplicada ao fundo, aos cartões, aos botões e à navegação.',
              s.accentColor,
              const {'mint': 'Menta', 'blue': 'Azul', 'purple': 'Violeta'},
              (value) => _save((s) => s.copyWith(accentColor: value)),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Tamanho do texto',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text('${s.fontSize.round()} px'),
                    ],
                  ),
                  Slider(
                    semanticFormatterCallback: (v) => '${v.round()} pixels',
                    value: s.fontSize,
                    min: 12,
                    max: 22,
                    divisions: 10,
                    onChanged: _saving
                        ? null
                        : (value) => _save((s) => s.copyWith(fontSize: value)),
                  ),
                  Text(
                    'O tamanho de acessibilidade do sistema também é respeitado.',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Animações'),
              subtitle: const Text('Transições de tela e rolagem do chat.'),
              value: s.animationsEnabled,
              onChanged: _saving
                  ? null
                  : (value) =>
                        _save((s) => s.copyWith(animationsEnabled: value)),
            ),
          ]),
          _section('Privacidade e histórico', [
            ListTile(
              leading: const Icon(Icons.block_outlined),
              title: const Text('Contatos bloqueados'),
              subtitle: Text(
                '${user.blockedUserIds.length} contatos • bloqueio salvo no dispositivo',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _blockedContacts,
            ),
            const Divider(),
            const ListTile(
              leading: Icon(Icons.sync),
              title: Text('Conexão em segundo plano'),
              subtitle: Text(
                'Minimizar mantém a conversa e os dados locais. No Android, uma notificação acompanha a conexão ativa. A continuidade depende das restrições do sistema.',
              ),
            ),
            const Divider(),
            _choice(
              'Limpeza automática local',
              'Escolha manter o histórico ou excluir após um prazo. Sem limite de quantidade ou tamanho imposto pelo app. Não controla cópias do destinatário.',
              s.localRetentionMinutes,
              const {
                -1: 'Manter histórico (sem exclusão automática)',
                0: 'Ao fechar a conversa',
                1: 'Após 1 minuto',
                5: 'Após 5 minutos',
                30: 'Após 30 minutos',
                60: 'Após 1 hora',
                1440: 'Após 1 dia',
                10080: 'Após 7 dias',
                43200: 'Após 30 dias',
                129600: 'Após 90 dias',
                259200: 'Após 180 dias',
                525600: 'Após 1 ano',
              },
              (value) => _save((s) => s.copyWith(localRetentionMinutes: value)),
            ),
            const Divider(),
            const ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text('Criptografia sempre ativa'),
              subtitle: Text(
                'Mensagens criptografadas e convites autenticados pela chave pública. Identidade e histórico são mantidos no armazenamento seguro do dispositivo.',
              ),
            ),
          ]),
          _section('Conexão', [
            _choice(
              'Tempo de preparação',
              'Prazo para coletar os dados de conexão de um convite.',
              s.connectionTimeoutSeconds,
              const {
                10: '10 segundos',
                20: '20 segundos',
                30: '30 segundos',
                45: '45 segundos',
                60: '60 segundos',
              },
              (value) =>
                  _save((s) => s.copyWith(connectionTimeoutSeconds: value)),
            ),
            const Divider(),
            const ListTile(
              leading: Icon(Icons.hub_outlined),
              title: Text('Privacidade de rede'),
              subtitle: Text(
                'STUN descobre seu IP e seus operadores observam IP e horários. O modo direto expõe o IP ao contato. TURN exclusivo pode ocultá-lo do contato, mas o operador TURN vê seu IP. Não há anonimato Tor. Rede configurada na compilação. Convites expiram em 10 minutos.',
              ),
            ),
          ]),
          _section('Sobre o Nexora', [
            const ListTile(
              leading: BrandMark(),
              title: Text('Nexora'),
              subtitle: Text(
                'Versão 1.0.0 • Conversas privadas, conexão direta',
              ),
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Confira a chave do contato por outro canal. Dados técnicos de conexão ficam ocultos na interface. Dispositivos comprometidos e cópias feitas pelo destinatário podem expor mensagens.',
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.restart_alt),
              title: const Text('Restaurar preferências'),
              subtitle: const Text('Mantém sua identidade e chave privada.'),
              onTap: _saving ? null : _reset,
            ),
          ]),
        ],
      ),
    );
  }
}
