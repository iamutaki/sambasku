import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../providers/auth_login_providers.dart';

/// Halaman login (email + password). Google sign-in menyusul - backend
/// Section 23 belum diimplement. Sukses login -> router redirect ke
/// splash (isAuth sudah true).
// TODO(theming): ganti komponen Material -> forui saat tema final dipilih
class LoginPage extends HookConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authLoginProvider);
    final email = useTextEditingController();
    final password = useTextEditingController();
    final obscure = useState(true);

    // pindah ke splash begitu sesi tersimpan (redirect bawa isAuth)
    ref.listen(authLoginProvider.select((s) => s.session), (_, next) {
      if (next != null) context.go('/splash');
    });

    final canSubmit = email.text.contains('@') &&
        password.text.length >= 8 &&
        !state.isSubmitting;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.menu_book, size: 64),
                const Gap(12),
                Text(
                  'Kamus Sambas',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Gap(32),
                TextField(
                  controller: email,
                  enabled: !state.isSubmitting,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                ),
                const Gap(12),
                TextField(
                  controller: password,
                  enabled: !state.isSubmitting,
                  obscureText: obscure.value,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure.value ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => obscure.value = !obscure.value,
                    ),
                  ),
                  onSubmitted: canSubmit
                      ? (_) => ref
                            .read(authLoginProvider.notifier)
                            .submit(
                              email: email.text,
                              password: password.text,
                            )
                      : null,
                ),
                const Gap(8),
                if (state.errorMessage != null)
                  Text(
                    state.errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const Gap(16),
                FilledButton(
                  onPressed: canSubmit
                      ? () => ref
                            .read(authLoginProvider.notifier)
                            .submit(
                              email: email.text,
                              password: password.text,
                            )
                      : null,
                  child: state.isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Masuk'),
                ),
                const Gap(8),
                TextButton(
                  onPressed: state.isSubmitting
                      ? null
                      : () => context.go('/'), // lanjut sebagai tamu
                  child: const Text('Lanjut tanpa login (tamu)'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
