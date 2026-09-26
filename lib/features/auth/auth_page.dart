import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/backend/auth_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand.dart';
import '../home/home_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({this.closeAfterAuth = false, super.key});

  final bool closeAfterAuth;

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
  var _closed = false;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = _auth.changes.listen((state) {
      if (widget.closeAfterAuth && state.session != null && mounted) {
        _closeWithSuccess();
      }
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _authSubscription?.cancel();
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
        _message(
          'Não foi possível entrar agora. Tente novamente.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      final opened = await _auth.signInWithGoogle();
      if (!opened && mounted) {
        _message('Não foi possível abrir o login do Google.', error: true);
      }
    } on AuthException catch (error) {
      if (mounted) _message(_friendlyMessage(error), error: true);
    } catch (_) {
      if (mounted) {
        _message('Não foi possível iniciar o login do Google.', error: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (!RegExp(r'^.+@.+\..+$').hasMatch(email)) {
      _message('Digite seu e-mail antes de recuperar a senha.', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await _auth.sendPasswordReset(email);
      if (mounted) _message('Enviamos o link de recuperação para seu e-mail.');
    } on AuthException catch (error) {
      if (mounted) _message(_friendlyMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _closeWithSuccess() {
    if (_closed) return;
    _closed = true;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(true);
    } else {
      navigator.pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const HomePage()),
      );
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? AppColors.danger : AppColors.brandHover,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: widget.closeAfterAuth
        ? AppBar(
            leading: IconButton(
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Fechar',
            ),
          )
        : null,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(fit: BoxFit.scaleDown, child: BrandLockup()),
                  ),
                  const SizedBox(height: 36),
                  Text(
                    _createAccount ? 'Crie sua conta' : 'Acesse sua conta',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _createAccount
                        ? 'Publique materiais, salve provas e sincronize seu progresso.'
                        : 'Entre somente quando quiser publicar, salvar ou sincronizar.',
                    style: const TextStyle(
                      color: AppColors.muted,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const _AccountBenefit(
                    Icons.cloud_done_outlined,
                    'Progresso protegido e disponível em outros aparelhos',
                  ),
                  const SizedBox(height: 10),
                  const _AccountBenefit(
                    Icons.upload_file_outlined,
                    'Publicação e biblioteca pessoal',
                  ),
                  const SizedBox(height: 32),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _signInWithGoogle,
                    icon: const Icon(Icons.account_circle_outlined),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 13),
                      child: Text('Continuar com Google'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: const [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('ou use seu e-mail'),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (_createAccount) ...[
                    TextFormField(
                      controller: _name,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Nome',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (value) => (value?.trim().length ?? 0) < 2
                          ? 'Digite seu nome.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                    validator: (value) =>
                        !RegExp(r'^.+@.+\..+$').hasMatch(value?.trim() ?? '')
                        ? 'Digite um e-mail válido.'
                        : null,
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
                        onPressed: () =>
                            setState(() => _hidePassword = !_hidePassword),
                        icon: Icon(
                          _hidePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        tooltip: _hidePassword
                            ? 'Mostrar senha'
                            : 'Ocultar senha',
                      ),
                    ),
                    validator: (value) => (value?.length ?? 0) < 8
                        ? 'Use pelo menos 8 caracteres.'
                        : null,
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      child: _loading
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_createAccount ? 'Criar conta' : 'Entrar'),
                    ),
                  ),
                  if (!_createAccount)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _loading ? null : _resetPassword,
                        child: const Text('Esqueci minha senha'),
                      ),
                    ),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () =>
                              setState(() => _createAccount = !_createAccount),
                    child: Text(
                      _createAccount ? 'Já tenho uma conta' : 'Criar uma conta',
                    ),
                  ),
                  if (widget.closeAfterAuth) ...[
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.maybePop(context),
                      child: const Text('Agora não'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _AccountBenefit extends StatelessWidget {
  const _AccountBenefit(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20, color: AppColors.brand),
      const SizedBox(width: 10),
      Expanded(
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ),
    ],
  );
}
