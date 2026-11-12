import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/roles.dart';
import '../utils/validators.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/page_header.dart' show SectionTitle, UserAvatarButton;
import 'team_home_screen.dart' show confirmerDeconnexion;

/// Paramètres du compte (tous les rôles) : photo de profil, informations personnelles,
/// mot de passe, déconnexion. Mêmes règles de saisie que l'inscription et que le web.
class CompteScreen extends StatefulWidget {
  const CompteScreen({super.key});

  @override
  State<CompteScreen> createState() => _CompteScreenState();
}

class _CompteScreenState extends State<CompteScreen> {
  static const _maxPhoto = 2 * 1024 * 1024;
  static const _extensionsPhoto = ['jpg', 'jpeg', 'png', 'webp'];

  final _formInfos = GlobalKey<FormState>();
  final _formMdp = GlobalKey<FormState>();
  late final TextEditingController _nom, _email, _tel, _adresse;
  final _actuel = TextEditingController();
  final _nouveau = TextEditingController();
  final _confirmation = TextEditingController();

  bool _envoiInfos = false, _envoiMdp = false, _envoiPhoto = false;
  Map<String, String> _erreursInfos = const {}, _erreursMdp = const {};
  String? _erreurPhoto;

  AuthProvider get _auth => context.read<AuthProvider>();
  ApiService get _api => _auth.api;

  @override
  void initState() {
    super.initState();
    final u = _auth.user ?? const {};
    _nom = TextEditingController(text: '${u['name'] ?? ''}');
    _email = TextEditingController(text: '${u['email'] ?? ''}');
    _tel = TextEditingController(text: '${u['telephone'] ?? ''}');
    _adresse = TextEditingController(text: '${u['adresse'] ?? ''}');
  }

  @override
  void dispose() {
    for (final c in [_nom, _email, _tel, _adresse, _actuel, _nouveau, _confirmation]) {
      c.dispose();
    }
    super.dispose();
  }

  void _message(String texte, {bool erreur = false}) {
    final st = StatusColors.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Icon(erreur ? Icons.error_outline : Icons.check_circle_outline, color: erreur ? st.dangerBg : st.successBg),
          const SizedBox(width: 10),
          Expanded(child: Text(texte)),
        ]),
      ));
  }

  // ---------------------------------------------------------------------
  // Photo
  // ---------------------------------------------------------------------
  Future<void> _choisirPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    final XFile? fichier;
    try {
      fichier = await ImagePicker().pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
    } catch (_) {
      setState(() => _erreurPhoto = 'Impossible d’ouvrir la galerie ou l’appareil photo.');
      return;
    }
    if (fichier == null) return;

    final nom = fichier.name.isEmpty ? 'photo.jpg' : fichier.name;
    final ext = nom.contains('.') ? nom.split('.').last.toLowerCase() : 'jpg';
    final octets = await fichier.readAsBytes();
    if (!_extensionsPhoto.contains(ext)) {
      setState(() => _erreurPhoto = 'Formats acceptés : JPG, PNG ou WEBP.');
      return;
    }
    if (octets.length > _maxPhoto) {
      setState(() => _erreurPhoto = 'La photo est trop volumineuse (2 Mo maximum).');
      return;
    }

    setState(() {
      _envoiPhoto = true;
      _erreurPhoto = null;
    });
    try {
      final user = await _api.postMultipart('/user/photo', const {}, file: ApiFile('photo', nom, octets));
      await _auth.majUtilisateur(user);
      if (mounted) _message('Photo de profil mise à jour.');
    } on ApiException catch (e) {
      if (mounted) setState(() => _erreurPhoto = e.fieldErrors['photo'] ?? e.message);
    } finally {
      if (mounted) setState(() => _envoiPhoto = false);
    }
  }

  Future<void> _retirerPhoto() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.no_photography_outlined),
        title: const Text('Retirer la photo ?'),
        content: const Text('Vos initiales s’afficheront à la place.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Retirer')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _envoiPhoto = true;
      _erreurPhoto = null;
    });
    try {
      await _auth.majUtilisateur(await _api.delete('/user/photo'));
      if (mounted) _message('Photo retirée.');
    } on ApiException catch (e) {
      if (mounted) setState(() => _erreurPhoto = e.message);
    } finally {
      if (mounted) setState(() => _envoiPhoto = false);
    }
  }

  // ---------------------------------------------------------------------
  // Informations
  // ---------------------------------------------------------------------
  Future<void> _enregistrerInfos() async {
    setState(() => _erreursInfos = const {});
    if (!_formInfos.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _envoiInfos = true);
    try {
      final user = await _api.put('/user/profile', {
        'name': _nom.text.trim(),
        'email': _email.text.trim(),
        'telephone': _tel.text.trim(),
        'adresse': _adresse.text.trim(),
      });
      await _auth.majUtilisateur(user);
      if (mounted) _message('Vos informations sont enregistrées.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _erreursInfos = e.fieldErrors);
      if (e.fieldErrors.isEmpty) _message(e.message, erreur: true);
    } finally {
      if (mounted) setState(() => _envoiInfos = false);
    }
  }

  // ---------------------------------------------------------------------
  // Mot de passe
  // ---------------------------------------------------------------------
  Future<void> _changerMdp() async {
    setState(() => _erreursMdp = const {});
    if (!_formMdp.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _envoiMdp = true);
    try {
      await _api.put('/user/password', {
        'current_password': _actuel.text,
        'password': _nouveau.text,
        'password_confirmation': _confirmation.text,
      });
      _actuel.clear();
      _nouveau.clear();
      _confirmation.clear();
      if (mounted) _message('Mot de passe modifié.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _erreursMdp = e.fieldErrors);
      if (e.fieldErrors.isEmpty) _message(e.message, erreur: true);
    } finally {
      if (mounted) setState(() => _envoiMdp = false);
    }
  }

  // ---------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final scheme = Theme.of(context).colorScheme;
    final photo = auth.user?['photo_url']?.toString();

    Widget bouton(String libelle, bool envoi, VoidCallback action, IconData icone) => FilledButton.icon(
          onPressed: envoi ? null : action,
          icon: envoi
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
              : Icon(icone),
          label: Text(libelle),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres du compte'), actions: const [ThemeToggleButton()]),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            // ---------- Photo ----------
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 52,
                    backgroundColor: scheme.primaryContainer,
                    foregroundImage: photo != null && photo.isNotEmpty ? NetworkImage(photo) : null,
                    onForegroundImageError: photo != null && photo.isNotEmpty ? (_, _) {} : null,
                    child: Text(UserAvatarButton.initiales(auth.userName),
                        style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w800, fontSize: 30)),
                  ),
                  if (_envoiPhoto) const SizedBox(width: 110, height: 110, child: CircularProgressIndicator()),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(auth.userName,
                textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
            Text(Roles.label(auth.role), textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: _envoiPhoto ? null : _choisirPhoto,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(photo == null ? 'Ajouter une photo' : 'Changer la photo'),
                ),
                if (photo != null)
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: scheme.error),
                    onPressed: _envoiPhoto ? null : _retirerPhoto,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Retirer'),
                  ),
              ],
            ),
            if (_erreurPhoto != null) ...[
              const SizedBox(height: 8),
              Text(_erreurPhoto!, textAlign: TextAlign.center, style: TextStyle(color: scheme.error)),
            ],
            Text('JPG, PNG ou WEBP, 2 Mo maximum.',
                textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),

            // ---------- Informations ----------
            const SectionTitle('Mes informations'),
            Form(
              key: _formInfos,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nom,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    inputFormatters: [Validators.nameInput],
                    maxLength: 100,
                    decoration: InputDecoration(
                      labelText: 'Nom et prénoms',
                      prefixIcon: const Icon(Icons.person_outline),
                      counterText: '',
                      errorText: _erreursInfos['nom'],
                    ),
                    validator: Validators.name,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    inputFormatters: [Validators.emailInput],
                    decoration: InputDecoration(
                      labelText: 'Adresse email',
                      prefixIcon: const Icon(Icons.alternate_email),
                      errorText: _erreursInfos['email'],
                    ),
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _tel,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    inputFormatters: [Validators.phoneInput],
                    maxLength: 20,
                    decoration: InputDecoration(
                      labelText: 'Téléphone',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      counterText: '',
                      errorText: _erreursInfos['telephone'],
                    ),
                    validator: Validators.phone,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _adresse,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.fullStreetAddress],
                    inputFormatters: [Validators.addressInput],
                    maxLength: 150,
                    decoration: InputDecoration(
                      labelText: 'Adresse',
                      prefixIcon: const Icon(Icons.home_outlined),
                      counterText: '',
                      errorText: _erreursInfos['adresse'],
                    ),
                    validator: Validators.address,
                    onFieldSubmitted: (_) => _enregistrerInfos(),
                  ),
                  const SizedBox(height: 18),
                  bouton('Enregistrer mes informations', _envoiInfos, _enregistrerInfos, Icons.save_outlined),
                ],
              ),
            ),

            // ---------- Mot de passe ----------
            const SectionTitle('Mot de passe'),
            Form(
              key: _formMdp,
              child: Column(
                children: [
                  PasswordField(
                    controller: _actuel,
                    label: 'Mot de passe actuel',
                    validator: Validators.loginPassword,
                    serverError: _erreursMdp['current_password'],
                  ),
                  const SizedBox(height: 14),
                  PasswordField(
                    controller: _nouveau,
                    label: 'Nouveau mot de passe',
                    helper: '8 caractères minimum, au moins une lettre et un chiffre.',
                    isNew: true,
                    validator: (v) => Validators.password(v) ??
                        (v == _actuel.text && v!.isNotEmpty ? 'Le nouveau mot de passe doit être différent de l’actuel.' : null),
                    serverError: _erreursMdp['password'],
                  ),
                  const SizedBox(height: 14),
                  PasswordField(
                    controller: _confirmation,
                    label: 'Confirmer le nouveau mot de passe',
                    isNew: true,
                    action: TextInputAction.done,
                    validator: (v) => Validators.confirm(_nouveau.text, v),
                    onSubmitted: _changerMdp,
                  ),
                  const SizedBox(height: 18),
                  bouton('Changer le mot de passe', _envoiMdp, _changerMdp, Icons.lock_reset),
                ],
              ),
            ),

            // ---------- Session ----------
            const SectionTitle('Session'),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.error,
                side: BorderSide(color: scheme.error.withValues(alpha: 0.6)),
                backgroundColor: StatusColors.of(context).dangerBg,
              ),
              onPressed: () => confirmerDeconnexion(context),
              icon: const Icon(Icons.logout),
              label: const Text('Se déconnecter'),
            ),
          ],
        ),
      ),
    );
  }
}
