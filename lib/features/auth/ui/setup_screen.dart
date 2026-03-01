import 'package:flutter/material.dart';
import '../../../app/home_shell.dart';
import '../data/setup_controller.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  static const Color _accentBlue = Color(0xFF2563EB);

  final _pw1 = TextEditingController();
  final _pw2 = TextEditingController();
  final _hint = TextEditingController();

  late final SetupController _c;

  @override
  void initState() {
    super.initState();
    _c = SetupController();
    _c.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _create() async {
    final ok = await _c.createVault(
      password1: _pw1.text,
      password2: _pw2.text,
      hint: _hint.text.trim().isEmpty ? null : _hint.text.trim(),
    );

    if (!ok) return;

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeShell(initialIndex: 0)),
    );
  }

  @override
  void dispose() {
    _c.removeListener(_onControllerChanged);
    _c.dispose();
    _pw1.dispose();
    _pw2.dispose();
    _hint.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(
      BuildContext context, {
        required String label,
        String? helper,
        Widget? suffix,
      }) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      helperText: helper,
      filled: true,
      fillColor: cs.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.55)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.45)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _accentBlue, width: 1.6),
      ),
      suffixIcon: suffix,
    );
  }

  Widget _block(BuildContext context, {required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.28)),
      ),
      padding: const EdgeInsets.all(14),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final cs = baseTheme.colorScheme;

    final localTheme = baseTheme.copyWith(
      colorScheme: cs.copyWith(primary: _accentBlue, secondary: _accentBlue),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _accentBlue,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );

    final pwPreview = _pw1.text;
    final strongNow = pwPreview.isNotEmpty && _c.isStrong(pwPreview);

    return Theme(
      data: localTheme,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: cs.surface,
          surfaceTintColor: cs.surface,
          elevation: 0,
          centerTitle: false,
          title: Text(
            'Crear vault',
            style: baseTheme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _accentBlue.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _accentBlue.withOpacity(0.15),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _accentBlue.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.shield_rounded,
                                color: _accentBlue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Protege tu bóveda',
                                    style: baseTheme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Crea una clave maestra para cifrar el vault en este dispositivo.',
                                    style: baseTheme.textTheme.bodyMedium?.copyWith(
                                      color: cs.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      _block(
                        context,
                        child: Column(
                          children: [
                            TextField(
                              controller: _pw1,
                              obscureText: true,
                              textInputAction: TextInputAction.next,
                              onChanged: (_) => setState(() {}),
                              decoration: _fieldDecoration(
                                context,
                                label: 'Clave maestra',
                                helper:
                                'Mín. 12 chars, mayúscula, minúscula, número y símbolo.',
                                suffix: const Icon(Icons.key_rounded),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _pw2,
                              obscureText: true,
                              textInputAction: TextInputAction.next,
                              decoration: _fieldDecoration(
                                context,
                                label: 'Repetir clave maestra',
                                suffix: const Icon(Icons.check_rounded),
                              ),
                            ),
                            
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Divider(thickness: 1),
                            ),

                            TextField(
                              controller: _hint,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _c.busy ? null : _create(),
                              decoration: _fieldDecoration(
                                context,
                                label: 'Pista de contraseña (opcional)',
                                helper: 'Algo que te ayude a recordarla si la olvidas.',
                                suffix: const Icon(Icons.help_outline_rounded),
                              ),
                            ),
                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: strongNow
                                        ? _accentBlue.withOpacity(0.12)
                                        : cs.surface,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: strongNow
                                          ? _accentBlue.withOpacity(0.25)
                                          : cs.outlineVariant.withOpacity(0.35),
                                    ),
                                  ),
                                  child: Text(
                                    pwPreview.isEmpty
                                        ? 'Introduce una clave'
                                        : (strongNow ? 'Fuerte' : 'Débil'),
                                    style: baseTheme.textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: strongNow ? _accentBlue : cs.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  strongNow ? Icons.verified_rounded : Icons.info_outline_rounded,
                                  color: strongNow ? _accentBlue : cs.onSurfaceVariant,
                                ),
                              ],
                            ),

                            if (_c.error != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: cs.errorContainer,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: cs.error.withOpacity(0.25),
                                  ),
                                ),
                                child: Text(
                                  _c.error!,
                                  style: baseTheme.textTheme.bodyMedium?.copyWith(
                                    color: cs.onErrorContainer,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: cs.outlineVariant.withOpacity(0.28),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Consejos',
                              style: baseTheme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const _TipRow(
                              icon: Icons.lock_outline_rounded,
                              text:
                              'No la compartas con nadie. Sin ella no podrás recuperar el vault.',
                              accent: _accentBlue,
                            ),
                            const SizedBox(height: 8),
                            const _TipRow(
                              icon: Icons.fingerprint_rounded,
                              text:
                              'Si tu móvil lo permite, activaremos biometría automáticamente.',
                              accent: _accentBlue,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _c.busy ? null : _create,
                    child: _c.busy
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Text('Crear vault'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({
    required this.icon,
    required this.text,
    required this.accent,
  });

  final IconData icon;
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: accent, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}