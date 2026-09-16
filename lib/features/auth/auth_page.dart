import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/backend/auth_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _auth = AuthRepository();
  var _createAccount = false;
  var _loading = false;
  var _hidePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      if (_createAccount) {
        final response = await _auth.signUp(
          email: _email.text,
          password: _password.text,
          displayName: _name.text,
        );
        if (mounted && response.session == null) {
          _message('Confira seu e-mail para confirmar a conta.');
        }
      } else {
        await _auth.signIn(email: _email.text, password: _password.text);
      }
    } on AuthException catch (error) {
      if (mounted) _message(_friendlyMessage(error), error: true);
    } catch (_) {
      if (mounted) {
        _message('Não foi possível entrar agora. Tente novamente.', error: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyMessage(AuthException error) {
    switch (error.code) {
      case 'invalid_credentials':
        return 'E-mail ou senha incorretos.';
      case 'email_not_confirmed':
        return 'Confirme seu e-mail antes de entrar.';
      case 'user_already_exists':
        return 'Já existe uma conta com este e-mail.';
      default:
        return error.message;
    }
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? AppColors.danger : AppColors.brandHover,
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _formKey,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Align(alignment: Alignment.centerLeft, child: BrandLockup()),
                    const SizedBox(height: 48),
                    Text(_createAccount ? 'Crie sua conta' : 'Entre para continuar', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    Text(_createAccount ? 'Salve provas, acompanhe resultados e participe das discussões.' : 'Sua biblioteca e seu progresso ficam sincronizados.', style: const TextStyle(color: AppColors.muted, height: 1.45)),
                    const SizedBox(height: 32),
                    if (_createAccount) ...[
                      TextFormField(
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Nome', prefixIcon: Icon(Icons.person_outline_rounded)),
                        validator: (value) => (value?.trim().length ?? 0) < 2 ? 'Digite seu nome.' : null,
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.mail_outline_rounded)),
                      validator: (value) => !RegExp(r'^.+@.+\..+$').hasMatch(value?.trim() ?? '') ? 'Digite um e-mail válido.' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _hidePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) {
                        if (!_loading) _submit();
                      },
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _hidePassword = !_hidePassword),
                          icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          tooltip: _hidePassword ? 'Mostrar senha' : 'Ocultar senha',
                        ),
                      ),
                      validator: (value) => (value?.length ?? 0) < 8 ? 'Use pelo menos 8 caracteres.' : null,
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        child: _loading
                            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(_createAccount ? 'Criar conta' : 'Entrar'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: _loading ? null : () => setState(() => _createAccount = !_createAccount),
                      child: Text(_createAccount ? 'Já tenho uma conta' : 'Criar uma conta'),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}
