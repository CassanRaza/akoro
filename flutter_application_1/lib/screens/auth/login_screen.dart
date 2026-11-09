import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../utils/validators.dart';
import '../../widgets/auth_widgets.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    auth.clearErrors();
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    TextInput.finishAutofillContext();
    await auth.login(_email.text, _password.text);
  }

  Future<void> _ouvrirInscription() async {
    final auth = context.read<AuthProvider>();
    auth.clearErrors();
    final email = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
    // Retour après une demande « équipe » : l'email est pré-rempli pour plus tard
    if (email != null && mounted) _email.text = email;
    auth.clearErrors();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return AuthScaffold(
      title: 'Connexion',
      subtitle: 'Bénéficiaires et équipe du FabLab : connectez-vous avec votre email.',
      children: [
        AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  maxLength: 255,
                  inputFormatters: [Validators.emailInput],
                  validator: Validators.email,
                  onChanged: (_) => auth.clearFieldError('email'),
                  onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                  decoration: InputDecoration(
                    labelText: 'Adresse email',
                    hintText: 'nom@haytao.mg',
                    counterText: '',
                    prefixIcon: const Icon(Icons.alternate_email),
                    errorText: auth.fieldErrors['email'],
                  ),
                ),
                const SizedBox(height: 16),
                PasswordField(
                  controller: _password,
                  focusNode: _passwordFocus,
                  validator: Validators.loginPassword,
                  action: TextInputAction.done,
                  onSubmitted: _submit,
                  onChanged: (_) => auth.clearFieldError('password'),
                  serverError: auth.fieldErrors['password'],
                ),
              ],
            ),
          ),
        ),
        if (auth.error != null) ...[
          const SizedBox(height: 16),
          MessageBanner(auth.error!, info: auth.error!.contains('en attente')),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: auth.submitting ? null : _submit,
          child: auth.submitting
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4)),
                    SizedBox(width: 12),
                    Text('Connexion…'),
                  ],
                )
              : const Text('Se connecter'),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Flexible(child: Text('Pas encore de compte ?')),
            TextButton(
              onPressed: auth.submitting ? null : _ouvrirInscription,
              child: const Text('S’inscrire'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'AKORO · application mobile v1.0.8',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
