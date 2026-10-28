import 'package:flutter/material.dart';
import 'package:nexora/src/services/local_data_service.dart';
import 'package:nexora/src/views/widgets/app_theme.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key, required this.onSignedIn});
  final VoidCallback onSignedIn;
  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _form = GlobalKey<FormState>();
  final _nickname = TextEditingController();
  bool _saving = false;
  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await LocalDataService.instance.signIn(_nickname.text);
      if (mounted) widget.onSignedIn();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível criar a identidade. Tente novamente.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: BrandMark(size: 68),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Conversas privadas.\nConexão direta.',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                            letterSpacing: -1,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Crie sua identidade no Nexora. Sem telefone, e-mail ou cadastro em servidor.',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _nickname,
                      maxLength: 32,
                      enabled: !_saving,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _signIn(),
                      decoration: const InputDecoration(
                        labelText: 'Seu apelido',
                        hintText: 'Como quer ser chamado?',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Informe um apelido.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _saving ? null : _signIn,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Criar identidade'),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 16,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Sua chave privada fica no armazenamento seguro deste dispositivo. Para conversar, compartilhe somente a chave pública.',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 12,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
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
}
