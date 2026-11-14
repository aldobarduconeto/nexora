import 'dart:ui';
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
  void initState() {
    super.initState();
    _nickname.addListener(() {
      if (mounted) setState(() {});
    });
  }

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
          SnackBar(
            content: Text(
              AppText.identityFailed.of(context),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nickText = _nickname.text.trim();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070A12) : const Color(0xFFF4F6F9),
      body: Stack(
        children: [
          // Ambient Gradient Orbs in Background
          Positioned(
            top: -120,
            left: -100,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colors.primary.withValues(alpha: isDark ? 0.22 : 0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            right: -100,
            child: Container(
              width: 420,
              height: 420,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.18 : 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 490),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF101626).withValues(alpha: 0.78)
                              : Colors.white.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.09)
                                : Colors.black.withValues(alpha: 0.06),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                              blurRadius: 32,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _form,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Top Brand Banner
                              Row(
                                children: [
                                  const BrandMark(size: 52),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Text(
                                              'Nexora',
                                              style: TextStyle(
                                                fontSize: 23,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: -0.6,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: colors.primary.withValues(alpha: 0.14),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'v2.0',
                                                style: TextStyle(
                                                  color: colors.primary,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          AppText.encryptedCommunication.of(context),
                                          style: TextStyle(
                                            color: colors.primary,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 26),

                              Text(
                                AppText.signInHeading.of(context),
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      height: 1.18,
                                      letterSpacing: -0.8,
                                      fontSize: 24,
                                    ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                AppText.signInDescription.of(context),
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  height: 1.5,
                                  fontSize: 13.5,
                                ),
                              ),
                              const SizedBox(height: 22),

                              // Feature Pills
                              _FeatureCard(
                                icon: Icons.enhanced_encryption_rounded,
                                title: AppText.encryption.of(context),
                                subtitle: AppText.encryptionDetails.of(context),
                              ),
                              const SizedBox(height: 10),
                              _FeatureCard(
                                icon: Icons.videocam_rounded,
                                title: AppText.media.of(context),
                                subtitle: AppText.mediaDetails.of(context),
                              ),
                              const SizedBox(height: 10),
                              _FeatureCard(
                                icon: Icons.security_rounded,
                                title: AppText.localKey.of(context),
                                subtitle: AppText.localKeyDetails.of(context),
                              ),
                              const SizedBox(height: 24),

                              // Dynamic Nickname Input with live crypto avatar
                              TextFormField(
                                controller: _nickname,
                                maxLength: 32,
                                enabled: !_saving,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _signIn(),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  labelText: AppText.nickname.of(context),
                                  hintText: AppText.nicknameHint.of(context),
                                  prefixIcon: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: nickText.isNotEmpty
                                        ? CircleAvatar(
                                            radius: 12,
                                            backgroundColor: colors.primary.withValues(alpha: 0.2),
                                            child: Text(
                                              nickText.substring(0, 1).toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: colors.primary,
                                              ),
                                            ),
                                          )
                                        : Icon(Icons.person_outline_rounded, color: colors.onSurfaceVariant),
                                  ),
                                  filled: true,
                                  fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.35),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: colors.outlineVariant.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: colors.primary,
                                      width: 1.8,
                                    ),
                                  ),
                                ),
                                validator: (value) => value == null || value.trim().isEmpty
                                    ? AppText.nicknameRequired.of(context)
                                    : null,
                              ),
                              const SizedBox(height: 16),

                              // Gradient Primary Button
                              Container(
                                height: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: _saving
                                        ? [colors.primary.withValues(alpha: 0.5), colors.primary.withValues(alpha: 0.5)]
                                        : [
                                            const Color(0xFF00DC82),
                                            const Color(0xFF00B870),
                                          ],
                                  ),
                                  boxShadow: [
                                    if (!_saving)
                                      BoxShadow(
                                        color: const Color(0xFF00DC82).withValues(alpha: 0.35),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: _saving ? null : _signIn,
                                    child: Center(
                                      child: _saving
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.bolt_rounded,
                                                  size: 20,
                                                  color: Colors.black,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  AppText.createIdentity.of(context),
                                                  style: const TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: -0.2,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),

                              // Divider
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      color: colors.outlineVariant.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    child: Text(
                                      'OU',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color: colors.outlineVariant.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),

                              // Device Mirror Button
                              OutlinedButton.icon(
                                onPressed: _saving
                                    ? null
                                    : () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => DeviceMirrorReceiveView(
                                              onAccountMirrored: () {
                                                Navigator.pop(context);
                                                widget.onSignedIn();
                                              },
                                            ),
                                          ),
                                        );
                                      },
                                icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                                label: Text(AppText.mirrorAccount.of(context)),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(46),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  side: BorderSide(
                                    color: colors.outlineVariant.withValues(alpha: 0.6),
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
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: colors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 11.5,
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
}
