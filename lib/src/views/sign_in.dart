import 'package:flutter/material.dart';
import 'package:nexora/src/utils/app_text.dart';
import 'package:nexora/src/services/local_data_service.dart';
import 'package:nexora/src/views/device_mirror_receive_view.dart';
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppText.identityFailed.of(context))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildBenefitRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: colors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  color: colors.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Logo & Title
                    Row(
                      children: [
                        const BrandMark(size: 34),
                        const SizedBox(width: 10),
                        Text(
                          'Nexora',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Headings
                    Text(
                      AppText.signInHeading.of(context),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            height: 1.25,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppText.signInDescription.of(context),
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Benefit highlights (clean, friendly, no jargon)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colors.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildBenefitRow(
                            context: context,
                            icon: Icons.shield_outlined,
                            title: AppText.encryption.of(context),
                            subtitle: AppText.encryptionDetails.of(context),
                          ),
                          const SizedBox(height: 14),
                          _buildBenefitRow(
                            context: context,
                            icon: Icons.videocam_outlined,
                            title: AppText.media.of(context),
                            subtitle: AppText.mediaDetails.of(context),
                          ),
                          const SizedBox(height: 14),
                          _buildBenefitRow(
                            context: context,
                            icon: Icons.lock_outline_rounded,
                            title: AppText.localKey.of(context),
                            subtitle: AppText.localKeyDetails.of(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Name input
                    TextFormField(
                      controller: _nickname,
                      maxLength: 32,
                      enabled: !_saving,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _signIn(),
                      decoration: InputDecoration(
                        labelText: AppText.nickname.of(context),
                        hintText: AppText.nicknameHint.of(context),
                        prefixIcon: const Icon(
                          Icons.person_outline_rounded,
                        ),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? AppText.nicknameRequired.of(context)
                          : null,
                    ),
                    const SizedBox(height: 12),

                    // Primary Button
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _saving ? null : _signIn,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: Text(
                        AppText.createIdentity.of(context),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Secondary action (Sync from another device)
                    TextButton.icon(
                      onPressed: _saving
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      DeviceMirrorReceiveView(
                                        onAccountMirrored: () {
                                          Navigator.pop(context);
                                          widget.onSignedIn();
                                        },
                                      ),
                                ),
                              );
                            },
                      icon: const Icon(Icons.devices_rounded, size: 16),
                      label: Text(
                        AppText.mirrorAccount.of(context),
                        style: const TextStyle(fontSize: 12),
                      ),
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
