import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/roles.dart';
import '../../utils/validators.dart';
import '../../widgets/auth_widgets.dart';

enum TypeCompte { beneficiaire, equipe }

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nom = TextEditingController();
  final _email = TextEditingController();
  final _telephone = TextEditingController();
  final _adresse = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  TypeCompte? _type;
  String? _role;
  int? _etablissementId;
  int? _parcoursId;
  ApiFile? _photo;
  bool _formIncomplet = false;

  // FabLabs et parcours (bénéficiaire)
  List<EtablissementOption>? _options;
  String? _optionsErreur;
  bool _optionsChargement = false;

  // Demande « équipe » envoyée
  String? _demandeEnvoyee;

  @override
  void initState() {
    super.initState();
    _nom.addListener(() => setState(() {})); // initiales de l'avatar
  }

  @override
  void dispose() {
    for (final c in [_nom, _email, _telephone, _adresse, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _chargerOptions() async {
    setState(() {
      _optionsChargement = true;
      _optionsErreur = null;
    });
    try {
      final options = await context.read<AuthProvider>().optionsInscription();
      if (!mounted) return;
      setState(() {
        _options = options;
        // Un seul FabLab : il est choisi d'office (une décision de moins pour l'utilisateur)
        if (options.length == 1) _etablissementId = options.first.id;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _optionsErreur = e.message);
    } finally {
      if (mounted) setState(() => _optionsChargement = false);
    }
  }

  void _choisirType(TypeCompte type) {
    context.read<AuthProvider>().clearErrors();
    setState(() {
      _type = type;
      _formIncomplet = false;
    });
    if (type == TypeCompte.beneficiaire && _options == null && !_optionsChargement) _chargerOptions();
  }

  EtablissementOption? get _etablissement =>
      _options?.where((e) => e.id == _etablissementId).firstOrNull;

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    auth.clearErrors();
    final ok = _formKey.currentState!.validate();
    setState(() => _formIncomplet = !ok);
    if (!ok) return;
    FocusScope.of(context).unfocus();

    final inscription = Inscription(
      nom: _nom.text,
      email: _email.text,
      telephone: _telephone.text,
      adresse: _adresse.text,
      password: _password.text,
      role: _type == TypeCompte.equipe ? _role : null,
      etablissementId: _type == TypeCompte.beneficiaire ? _etablissementId : null,
      parcoursId: _type == TypeCompte.beneficiaire ? _parcoursId : null,
      photo: _photo,
    );

    final message = await auth.inscrire(inscription, equipe: _type == TypeCompte.equipe);
    if (message != null && mounted) {
      TextInput.finishAutofillContext();
      setState(() => _demandeEnvoyee = message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (_demandeEnvoyee != null) return _confirmationEquipe();

    return PopScope(
      canPop: !auth.submitting,
      child: AuthScaffold(
        showBack: true,
        title: 'Inscription',
        subtitle: 'Choisissez d’abord votre profil, puis complétez le formulaire.',
        children: [
          _choixType(),
          if (_type != null) ...[
            const SizedBox(height: 24),
            AutofillGroup(child: Form(key: _formKey, child: _formulaire(auth))),
            if (_formIncomplet && auth.fieldErrors.isEmpty) ...[
              const SizedBox(height: 16),
              const MessageBanner('Certains champs sont incomplets ou incorrects : corrigez ceux indiqués en rouge.'),
            ],
            if (auth.error != null) ...[
              const SizedBox(height: 16),
              MessageBanner(auth.error!),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: auth.submitting || (_type == TypeCompte.beneficiaire && _options == null) ? null : _submit,
              child: auth.submitting
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4)),
                        SizedBox(width: 12),
                        Text('Envoi…'),
                      ],
                    )
                  : Text(_type == TypeCompte.beneficiaire ? 'Envoyer mon inscription' : 'Envoyer ma demande'),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Flexible(child: Text('Déjà un compte ?')),
              TextButton(
                onPressed: auth.submitting ? null : () => Navigator.of(context).pop(),
                child: const Text('Se connecter'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- Étape 1 : type de compte ----------

  Widget _choixType() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Vous êtes…', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          _CarteType(
            icon: Icons.school_outlined,
            titre: 'Bénéficiaire',
            texte: 'Apprenant du FabLab. Le Super Admin valide votre inscription avant votre première connexion.',
            selectionne: _type == TypeCompte.beneficiaire,
            onTap: () => _choisirType(TypeCompte.beneficiaire),
          ),
          const SizedBox(height: 10),
          _CarteType(
            icon: Icons.badge_outlined,
            titre: 'Membre de l’équipe',
            texte: 'Formateur, gérant ou manager. Un Super Admin doit valider votre compte avant la première connexion.',
            selectionne: _type == TypeCompte.equipe,
            onTap: () => _choisirType(TypeCompte.equipe),
          ),
        ],
      );

  // ---------- Étape 2 : formulaire ----------

  Widget _formulaire(AuthProvider auth) {
    InputDecoration deco(String label, IconData icon, String champ, {String? hint, String? helper}) =>
        InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helper,
          counterText: '',
          prefixIcon: Icon(icon),
          errorText: auth.fieldErrors[champ],
        );

    const espace = SizedBox(height: 16);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section('Identité'),
        TextFormField(
          controller: _nom,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          maxLength: 100,
          inputFormatters: [Validators.nameInput],
          validator: Validators.name,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          onChanged: (_) => auth.clearFieldError('nom'),
          decoration: deco('Nom et prénoms', Icons.person_outline, 'nom', hint: 'Rasolofoniaina Hervé'),
        ),
        espace,
        TextFormField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          autocorrect: false,
          maxLength: 255,
          inputFormatters: [Validators.emailInput],
          validator: Validators.email,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          onChanged: (_) => auth.clearFieldError('email'),
          decoration: deco('Adresse email', Icons.alternate_email, 'email', hint: 'nom@haytao.mg'),
        ),
        espace,
        TextFormField(
          controller: _telephone,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.telephoneNumber],
          maxLength: 20,
          inputFormatters: [Validators.phoneInput],
          validator: Validators.phone,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          onChanged: (_) => auth.clearFieldError('telephone'),
          decoration: deco('Téléphone', Icons.phone_outlined, 'telephone', hint: '+261 34 12 345 67'),
        ),
        espace,
        TextFormField(
          controller: _adresse,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.fullStreetAddress],
          maxLength: 150,
          inputFormatters: [Validators.addressInput],
          validator: Validators.address,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          onChanged: (_) => auth.clearFieldError('adresse'),
          decoration: deco('Adresse', Icons.home_outlined, 'adresse', hint: 'Lot 12 Ambalakilonga, Fianarantsoa'),
        ),
        espace,
        PhotoPickerField(
          name: _nom.text,
          onChanged: (f) {
            _photo = f;
            auth.clearFieldError('photo');
          },
          serverError: auth.fieldErrors['photo'],
        ),
        const SizedBox(height: 24),
        if (_type == TypeCompte.beneficiaire) ..._champsBeneficiaire(auth) else ..._champsEquipe(auth),
        const SizedBox(height: 24),
        _Section('Sécurité'),
        PasswordField(
          controller: _password,
          isNew: true,
          validator: Validators.password,
          helper: '8 caractères minimum, avec une lettre et un chiffre, sans espace',
          onChanged: (_) => auth.clearFieldError('password'),
          serverError: auth.fieldErrors['password'],
        ),
        espace,
        PasswordField(
          controller: _confirm,
          isNew: true,
          label: 'Confirmer le mot de passe',
          validator: (v) => Validators.confirm(_password.text, v),
          action: TextInputAction.done,
          onSubmitted: _submit,
        ),
      ],
    );
  }

  List<Widget> _champsBeneficiaire(AuthProvider auth) {
    final scheme = Theme.of(context).colorScheme;
    if (_optionsChargement) {
      return [
        _Section('Mon FabLab'),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4)),
            SizedBox(width: 12),
            Text('Chargement des FabLabs et des parcours…'),
          ]),
        ),
      ];
    }
    if (_optionsErreur != null || _options == null) {
      return [
        _Section('Mon FabLab'),
        MessageBanner(_optionsErreur ?? 'Impossible de charger les FabLabs.'),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: _chargerOptions, icon: const Icon(Icons.refresh), label: const Text('Réessayer')),
      ];
    }
    if (_options!.isEmpty) {
      return [_Section('Mon FabLab'), const MessageBanner('Aucun FabLab n’accepte d’inscription pour le moment.')];
    }

    final parcours = _etablissement?.parcours ?? const [];
    return [
      _Section('Mon FabLab'),
      DropdownButtonFormField<int>(
        initialValue: _etablissementId,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'FabLab',
          prefixIcon: const Icon(Icons.location_on_outlined),
          errorText: auth.fieldErrors['etablissement_id'],
        ),
        items: [
          for (final e in _options!)
            DropdownMenuItem(
              value: e.id,
              child: Text(e.adresse == null || e.adresse!.isEmpty ? e.nom : '${e.nom} · ${e.adresse}',
                  overflow: TextOverflow.ellipsis),
            ),
        ],
        validator: (v) => v == null ? 'Veuillez choisir votre FabLab.' : null,
        onChanged: (v) {
          auth.clearFieldError('etablissement_id');
          setState(() {
            _etablissementId = v;
            _parcoursId = null; // les parcours dépendent du FabLab
          });
        },
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<int?>(
        key: ValueKey('parcours-$_etablissementId'),
        initialValue: _parcoursId,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Parcours (facultatif)',
          prefixIcon: const Icon(Icons.route_outlined),
          helperText: 'Pas encore décidé ? L’équipe pourra vous l’attribuer plus tard.',
          errorText: auth.fieldErrors['parcours_id'],
        ),
        items: [
          DropdownMenuItem<int?>(
            value: null,
            child: Text('Je ne sais pas encore', style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
          for (final p in parcours) DropdownMenuItem<int?>(value: p.id, child: Text(p.nom)),
        ],
        onChanged: _etablissementId == null
            ? null
            : (v) {
                auth.clearFieldError('parcours_id');
                setState(() => _parcoursId = v);
              },
      ),
    ];
  }

  List<Widget> _champsEquipe(AuthProvider auth) {
    final scheme = Theme.of(context).colorScheme;
    return [
      _Section('Rôle souhaité'),
      FormField<String>(
        initialValue: _role,
        validator: (_) => _role == null ? 'Veuillez choisir un rôle.' : null,
        builder: (field) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RadioGroup<String>(
              groupValue: _role,
              onChanged: (v) {
                auth.clearFieldError('role');
                setState(() => _role = v);
                field.didChange(v);
              },
              child: Column(
                children: [
                  for (final r in Roles.choisissables)
                    RadioListTile<String>(
                      value: r,
                      contentPadding: EdgeInsets.zero,
                      title: Text(Roles.label(r)),
                      subtitle: Text(Roles.descriptions[r] ?? ''),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 2),
              child: Text(
                field.errorText ?? auth.fieldErrors['role'] ?? 'Le Super Admin confirmera votre rôle lors de la validation.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: (field.errorText ?? auth.fieldErrors['role']) != null ? scheme.error : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  // ---------- Inscription envoyée : en attente du Super Admin ----------

  Widget _confirmationEquipe() {
    final scheme = Theme.of(context).colorScheme;
    final st = StatusColors.of(context);
    final equipe = _type == TypeCompte.equipe;

    Widget etape(int n, String titre, String texte, {required bool fait, bool enCours = false}) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: fait ? st.success : enCours ? st.warningBg : scheme.outlineVariant.withValues(alpha: 0.6),
              child: fait
                  ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                  : Text('$n', style: TextStyle(fontWeight: FontWeight.w800, color: enCours ? st.warning : scheme.onSurfaceVariant)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titre, style: TextStyle(fontWeight: FontWeight.w800, color: enCours ? st.warning : scheme.onSurface)),
                    const SizedBox(height: 2),
                    Text(texte, style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4)),
                  ],
                ),
              ),
            ),
          ],
        );

    return AuthScaffold(
      title: 'Inscription envoyée',
      subtitle: 'Votre compte est en attente de validation.',
      children: [
        MessageBanner(_demandeEnvoyee!, info: true),
        const SizedBox(height: 24),
        etape(1, 'Inscription envoyée', 'Vos informations ont bien été reçues.', fait: true),
        etape(
          2,
          'Validation par le Super Admin',
          equipe
              ? 'Il vérifie votre demande et confirme votre rôle (${Roles.label(_role)}).'
              : 'Il vérifie votre inscription au FabLab${_etablissement != null ? ' ${_etablissement!.nom}' : ''}.',
          fait: false,
          enCours: true,
        ),
        etape(3, 'Connexion à AKORO', 'Connectez-vous avec ${_email.text} dès que votre compte est activé.', fait: false),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_email.text),
          child: const Text('Retour à la connexion'),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String texte;
  const _Section(this.texte);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          texte.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
        ),
      );
}

/// Carte de choix du type de compte (grande zone tactile, état sélectionné visible).
class _CarteType extends StatelessWidget {
  final IconData icon;
  final String titre;
  final String texte;
  final bool selectionne;
  final VoidCallback onTap;

  const _CarteType({
    required this.icon,
    required this.titre,
    required this.texte,
    required this.selectionne,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selectionne,
      child: Material(
        color: selectionne ? scheme.primaryContainer.withValues(alpha: 0.55) : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selectionne ? scheme.primary : scheme.outlineVariant, width: selectionne ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, size: 30, color: selectionne ? scheme.primary : scheme.onSurfaceVariant),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                      const SizedBox(height: 3),
                      Text(texte, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13, height: 1.35)),
                    ],
                  ),
                ),
                Icon(
                  selectionne ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: selectionne ? scheme.primary : scheme.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
