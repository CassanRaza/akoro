import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';

/// Liseré tricolore du logo (rose / vert / bleu).
class BrandStripe extends StatelessWidget {
  final double height;
  const BrandStripe({super.key, this.height = 4});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: const Row(children: [
          Expanded(child: ColoredBox(color: Brand.pink)),
          Expanded(child: ColoredBox(color: Brand.green)),
          Expanded(child: ColoredBox(color: Brand.blue)),
        ]),
      );
}

/// Cadre des écrans d'authentification : en-tête vert canard (logo, TA-Fablab, thème)
/// et formulaire dans un panneau blanc qui chevauche l'en-tête.
class AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool showBack;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sombre = theme.brightness == Brightness.dark;
    final haut = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---------- En-tête ----------
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: sombre
                        ? const [Color(0xFF0D5F55), Color(0xFF083B35)]
                        : const [Color(0xFF13A08D), Color(0xFF0A6458)],
                  ),
                ),
                child: Stack(
                  children: [
                    // Cercles décoratifs discrets
                    Positioned(right: -60, top: -40, child: _Cercle(taille: 200, opacite: 0.08)),
                    Positioned(left: -40, bottom: -10, child: _Cercle(taille: 130, opacite: 0.06)),
                    Padding(
                      padding: EdgeInsets.fromLTRB(8, haut + 4, 8, showBack ? 52 : 60),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              if (showBack)
                                BackButton(color: Colors.white, onPressed: () => Navigator.maybePop(context))
                              else
                                const SizedBox(width: 48),
                              const Spacer(),
                              const ThemeToggleButton(color: Colors.white),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: showBack ? _EnTeteCompact(title: title, subtitle: subtitle) : const _EnTeteMarque(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // ---------- Panneau du formulaire ----------
              Transform.translate(
                offset: const Offset(0, -32),
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                  child: SafeArea(
                    top: false,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!showBack) ...[
                              Semantics(
                                header: true,
                                child: Text(title, style: theme.textTheme.headlineSmall),
                              ),
                              const SizedBox(height: 6),
                              Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                              const SizedBox(height: 24),
                            ],
                            ...children,
                          ],
                        ),
                      ),
                    ),
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

class _EnTeteMarque extends StatelessWidget {
  const _EnTeteMarque();

  @override
  Widget build(BuildContext context) => Column(
        children: [
          const _Logo(),
          const SizedBox(height: 18),
          Semantics(
            header: true,
            child: const Text(
              'TA-Fablab',
              style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 0.5),
            ),
          ),
          const SizedBox(height: 14),
          const SizedBox(width: 72, child: ClipRRect(borderRadius: BorderRadius.all(Radius.circular(4)), child: BrandStripe())),
        ],
      );
}

class _EnTeteCompact extends StatelessWidget {
  final String title, subtitle;
  const _EnTeteCompact({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Semantics(
            header: true,
            child: Text(title,
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), height: 1.4)),
        ],
      );
}

class _Cercle extends StatelessWidget {
  final double taille, opacite;
  const _Cercle({required this.taille, required this.opacite});

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: taille,
          height: taille,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: opacite)),
        ),
      );
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    // Texte du logo officiel, reproduit à l'identique : « FabLab Solidaire / HAY TAO / Fianarantsoa ».
    const blanc = Colors.white;
    return Semantics(
      label: 'Logo du FabLab Solidaire HAY TAO, Fianarantsoa',
      image: true,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo-icone.png', height: 72, fit: BoxFit.contain),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('FabLab Solidaire',
                    style: TextStyle(color: blanc, fontSize: 17, fontWeight: FontWeight.w700, height: 1.15)),
                Text('HAY TAO',
                    style: TextStyle(color: blanc, fontSize: 22, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: 0.5)),
                Text('Fianarantsoa',
                    style: TextStyle(color: blanc, fontSize: 14, fontWeight: FontWeight.w600, height: 1.25)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Bandeau d'erreur ou d'information visible (et lu par le lecteur d'écran).
class MessageBanner extends StatelessWidget {
  final String message;
  final bool success;
  final bool info; // ex. compte en attente de validation : ni succès ni erreur
  const MessageBanner(this.message, {super.key, this.success = false, this.info = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = success ? scheme.tertiary : info ? StatusColors.of(context).warning : scheme.error;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: fg.withValues(alpha: 0.10),
          border: Border.all(color: fg.withValues(alpha: 0.45)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(success ? Icons.check_circle_outline : info ? Icons.hourglass_top_rounded : Icons.error_outline, color: fg),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: TextStyle(color: scheme.onSurface, height: 1.35))),
          ],
        ),
      ),
    );
  }
}

/// Champ mot de passe avec bouton afficher / masquer.
class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final String? helper;
  final String? Function(String?) validator;
  final TextInputAction action;
  final VoidCallback? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool isNew;
  final String? serverError;

  const PasswordField({
    super.key,
    required this.controller,
    required this.validator,
    this.focusNode,
    this.label = 'Mot de passe',
    this.helper,
    this.action = TextInputAction.next,
    this.onSubmitted,
    this.onChanged,
    this.isNew = false,
    this.serverError,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        obscureText: _hidden,
        enableSuggestions: false,
        autocorrect: false,
        maxLength: 64,
        textInputAction: widget.action,
        autofillHints: [widget.isNew ? AutofillHints.newPassword : AutofillHints.password],
        inputFormatters: [Validators.passwordInput],
        validator: widget.validator,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        onChanged: widget.onChanged,
        onFieldSubmitted: (_) => widget.onSubmitted?.call(),
        decoration: InputDecoration(
          labelText: widget.label,
          helperText: widget.helper,
          errorText: widget.serverError,
          counterText: '',
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            tooltip: _hidden ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
            icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            onPressed: () => setState(() => _hidden = !_hidden),
          ),
        ),
      );
}

/// Photo de profil facultative (JPG, PNG ou WEBP, 2 Mo max — comme le web).
class PhotoPickerField extends StatefulWidget {
  final String name;
  final ValueChanged<ApiFile?> onChanged;
  final String? serverError;

  const PhotoPickerField({super.key, required this.name, required this.onChanged, this.serverError});

  @override
  State<PhotoPickerField> createState() => _PhotoPickerFieldState();
}

class _PhotoPickerFieldState extends State<PhotoPickerField> {
  static const _maxOctets = 2 * 1024 * 1024;
  static const _extensions = ['jpg', 'jpeg', 'png', 'webp'];

  Uint8List? _bytes;
  String? _error;

  String get _initiales {
    final parts = widget.name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first.characters.first;
    final last = parts.length > 1 ? parts.last.characters.first : '';
    return (first + last).toUpperCase();
  }

  Future<void> _choisir(ImageSource source) async {
    Navigator.of(context).pop();
    try {
      // Redimensionnée et compressée : évite presque toujours le dépassement des 2 Mo
      final file = await ImagePicker().pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
      if (file == null) return;
      final ext = file.name.split('.').last.toLowerCase();
      final bytes = await file.readAsBytes();
      if (!_extensions.contains(ext)) {
        return _echec('Formats acceptés : JPG, PNG ou WEBP.');
      }
      if (bytes.length > _maxOctets) {
        return _echec('La photo est trop volumineuse (2 Mo maximum).');
      }
      setState(() {
        _bytes = bytes;
        _error = null;
      });
      widget.onChanged(ApiFile('photo', file.name, bytes));
    } on PlatformException {
      _echec('Accès à la caméra ou aux photos refusé. Autorisez-le dans les réglages du téléphone.');
    }
  }

  void _echec(String message) {
    setState(() => _error = message);
  }

  void _retirer() {
    setState(() {
      _bytes = null;
      _error = null;
    });
    widget.onChanged(null);
  }

  void _ouvrirChoix() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Prendre une photo'),
              onTap: () => _choisir(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir dans la galerie'),
              onTap: () => _choisir(ImageSource.gallery),
            ),
            if (_bytes != null)
              ListTile(
                leading: Icon(Icons.delete_outline, color: Theme.of(ctx).colorScheme.error),
                title: const Text('Retirer la photo'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _retirer();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final error = _error ?? widget.serverError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Semantics(
              label: _bytes == null ? 'Aucune photo choisie' : 'Photo de profil choisie',
              child: CircleAvatar(
                radius: 32,
                backgroundColor: scheme.primaryContainer,
                foregroundImage: _bytes != null ? MemoryImage(_bytes!) : null,
                child: Text(_initiales,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: scheme.onPrimaryContainer)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Photo de profil (facultative)', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text('JPG, PNG ou WEBP · 2 Mo maximum',
                      style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            TextButton(
              onPressed: _ouvrirChoix,
              child: Text(_bytes == null ? 'Ajouter' : 'Changer'),
            ),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(error, style: TextStyle(color: scheme.error, fontSize: 12.5)),
          ),
      ],
    );
  }
}
