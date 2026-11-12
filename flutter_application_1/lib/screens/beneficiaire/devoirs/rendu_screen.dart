import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/api_config.dart';
import '../../../models/devoir.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/api_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/page_header.dart' show SectionTitle;
import '../../../widgets/ui.dart';

const _extensions = ['pdf', 'jpg', 'jpeg', 'png', 'webp'];
const _maxOctets = 10 * 1024 * 1024;

String _taille(int o) => o < 1024 * 1024
    ? '${(o / 1024).ceil()} Ko'
    : '${(o / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} Mo';

/// Temps restant lisible avant la date limite (« 2 jours », « 3 h »…).
String delaiRestant(DateTime limite) {
  final d = limite.difference(DateTime.now());
  if (d.isNegative) return 'date limite passée';
  if (d.inDays >= 1) return 'il reste ${d.inDays} jour${d.inDays > 1 ? 's' : ''}';
  if (d.inHours >= 1) return 'il reste ${d.inHours} h';
  return 'il reste ${d.inMinutes.clamp(1, 59)} min';
}

/// Carte d'un devoir à rendre dans l'onglet Devoirs.
class CarteRendu extends StatelessWidget {
  final DevoirRendu d;
  final VoidCallback onTap;
  const CarteRendu({super.key, required this.d, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final st = StatusColors.of(context);
    final fmt = DateFormat('d MMM à HH:mm', 'fr');

    final (String etat, Color fg, Color bg) = switch (d.etat) {
      'corrige' => (d.rendu?.noteLisible ?? 'Corrigé', st.success, st.successBg),
      'rendu' => ('Rendu', st.success, st.successBg),
      'a_rendre' => ('À rendre', st.warning, st.warningBg),
      _ => ('Non rendu', st.danger, st.dangerBg),
    };
    final details = <String>[
      if ((d.formation ?? '').isNotEmpty) d.formation!,
      if (d.dateLimite != null)
        d.aFaire ? 'avant le ${fmt.format(d.dateLimite!)} · ${delaiRestant(d.dateLimite!)}' : 'limite : ${fmt.format(d.dateLimite!)}',
      if (d.etat == 'rendu') 'en attente de correction',
    ];

    return AppCard(
      onTap: onTap,
      semantique: 'Devoir à rendre ${d.titre}, $etat, ${details.join(', ')}',
      color: d.aFaire ? st.warningBg : null,
      borderColor: d.aFaire ? st.warning.withValues(alpha: 0.5) : null,
      child: Row(
        children: [
          Icon(Icons.upload_file_outlined, color: d.aFaire ? st.warning : scheme.onSurfaceVariant, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.titre, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(details.join(' · '), style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Tag(etat, fg: fg, bg: bg),
        ],
      ),
    );
  }
}

/// Détail d'un devoir à rendre : consigne, dépôt du fichier (PDF ou photo), note et commentaire.
class RenduScreen extends StatefulWidget {
  final int devoirId;
  final String titre;
  const RenduScreen({super.key, required this.devoirId, required this.titre});

  @override
  State<RenduScreen> createState() => _RenduScreenState();
}

class _RenduScreenState extends State<RenduScreen> {
  DevoirRendu? _d;
  String? _erreurChargement;

  // Fichier choisi, pas encore envoyé
  String? _nomChoisi;
  Uint8List? _octets;
  String? _erreurFichier;
  bool _envoi = false;

  ApiService get _api => context.read<AuthProvider>().api;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _erreurChargement = null);
    try {
      final json = await _api.get('/mes-rendus/${widget.devoirId}');
      if (mounted) setState(() => _d = DevoirRendu.fromJson(Map<String, dynamic>.from(json as Map)));
    } on ApiException catch (e) {
      if (mounted) setState(() => _erreurChargement = e.message);
    }
  }

  Future<void> _ouvrir(String? lien) async {
    if (lien == null) return;
    final ok = await launchUrl(ApiConfig.fichier(lien), mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible d’ouvrir le fichier.')));
    }
  }

  void _retenir(String nom, Uint8List octets) {
    final ext = nom.contains('.') ? nom.split('.').last.toLowerCase() : '';
    setState(() {
      _erreurFichier = !_extensions.contains(ext)
          ? 'Format non accepté : choisissez un PDF ou une photo (JPG, PNG, WEBP).'
          : octets.length > _maxOctets
              ? 'Le fichier est trop volumineux (10 Mo maximum).'
              : null;
      _nomChoisi = _erreurFichier == null ? nom : null;
      _octets = _erreurFichier == null ? octets : null;
    });
  }

  Future<void> _choisirFichier() async {
    try {
      final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: _extensions);
      if (f == null) return;
      _retenir(f.name, await f.readAsBytes());
    } catch (_) {
      setState(() => _erreurFichier = 'Impossible d’ouvrir le sélecteur de fichiers.');
    }
  }

  Future<void> _prendrePhoto() async {
    try {
      final img = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 2000, imageQuality: 85);
      if (img == null) return;
      _retenir(img.name.isEmpty ? 'photo-devoir.jpg' : img.name, await img.readAsBytes());
    } catch (_) {
      setState(() => _erreurFichier = 'Impossible d’ouvrir l’appareil photo.');
    }
  }

  Future<void> _envoyer() async {
    final d = _d;
    if (d == null || _octets == null || _nomChoisi == null || _envoi) return;

    if (d.rendu != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.swap_horiz),
          title: const Text('Remplacer votre rendu ?'),
          content: Text('« ${d.rendu!.nomFichier ?? 'Votre fichier'} » sera remplacé par « $_nomChoisi ».'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remplacer')),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() {
      _envoi = true;
      _erreurFichier = null;
    });
    try {
      final json = await _api.postMultipart('/mes-rendus/${d.id}', const {},
          file: ApiFile('fichier', _nomChoisi!, _octets!), timeout: const Duration(seconds: 120));
      if (!mounted) return;
      setState(() {
        _d = DevoirRendu.fromJson(Map<String, dynamic>.from(json as Map));
        _nomChoisi = null;
        _octets = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Devoir envoyé : votre formateur peut maintenant le corriger.')),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _erreurFichier = e.fieldErrors['fichier'] ?? e.message);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return Scaffold(
      appBar: AppBar(title: Text(widget.titre, overflow: TextOverflow.ellipsis), actions: const [ThemeToggleButton()]),
      body: SafeArea(
        child: d == null
            ? (_erreurChargement != null
                ? EtatErreur(message: _erreurChargement!, onRetry: _charger)
                : const Center(child: CircularProgressIndicator()))
            : RefreshIndicator(onRefresh: _charger, child: _contenu(d)),
      ),
    );
  }

  Widget _contenu(DevoirRendu d) {
    final scheme = Theme.of(context).colorScheme;
    final st = StatusColors.of(context);
    final fmt = DateFormat('EEEE d MMMM à HH:mm', 'fr');
    final r = d.rendu;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        if ((d.formation ?? '').isNotEmpty)
          Align(alignment: Alignment.centerLeft, child: Tag(d.formation!, fg: scheme.onPrimaryContainer, bg: scheme.primaryContainer)),
        const SizedBox(height: 10),
        Semantics(
          header: true,
          child: Text(d.titre, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        ),
        if (d.dateLimite != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.event_outlined, size: 20, color: d.aFaire ? st.warning : scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'À rendre avant le ${fmt.format(d.dateLimite!)}${d.aFaire ? ' (${delaiRestant(d.dateLimite!)})' : ''}',
                  style: TextStyle(fontWeight: FontWeight.w600, color: d.aFaire ? st.warning : scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],

        // ---------- Consigne ----------
        const SectionTitle('Consigne'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text((d.description ?? '').isEmpty ? 'Pas de description : consultez le fichier de consigne.' : d.description!,
                  style: const TextStyle(height: 1.45)),
              if (d.consigneUrl != null) ...[
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () => _ouvrir(d.consigneUrl),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Ouvrir la consigne (PDF)'),
                ),
              ],
            ],
          ),
        ),

        // ---------- Mon rendu ----------
        const SectionTitle('Mon rendu'),
        if (d.etat == 'corrige' && r != null)
          AppCard(
            color: st.successBg,
            borderColor: Colors.transparent,
            child: Semantics(
              label: 'Devoir corrigé. Note ${r.noteLisible}. ${r.commentaire ?? ''}',
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.grading_outlined, color: st.success),
                        const SizedBox(width: 10),
                        const Expanded(child: Text('Devoir corrigé', style: TextStyle(fontWeight: FontWeight.w800))),
                        Text(r.noteLisible, style: TextStyle(color: st.success, fontWeight: FontWeight.w800, fontSize: 22)),
                      ],
                    ),
                    if ((r.commentaire ?? '').isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text('Commentaire du formateur', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
                      const SizedBox(height: 2),
                      Text(r.commentaire!, style: const TextStyle(height: 1.45)),
                    ],
                  ],
                ),
              ),
            ),
          )
        else if (d.etat == 'manque')
          AppCard(
            color: st.dangerBg,
            borderColor: Colors.transparent,
            child: const Text('La date limite est passée sans rendu. Contactez votre formateur si besoin.',
                style: TextStyle(fontWeight: FontWeight.w600, height: 1.4)),
          ),
        if (r != null) ...[
          if (d.etat == 'corrige') const SizedBox(height: 10),
          AppCard(
            onTap: d.fichierUrl == null ? null : () => _ouvrir(d.fichierUrl),
            semantique: 'Fichier envoyé : ${r.nomFichier ?? 'fichier'}. Ouvrir',
            child: Row(
              children: [
                Icon(Icons.insert_drive_file_outlined, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.nomFichier ?? 'Fichier envoyé', style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (r.dateSoumission != null)
                        Text('Envoyé le ${DateFormat('d MMM à HH:mm', 'fr').format(r.dateSoumission!)}',
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
                    ],
                  ),
                ),
                Icon(Icons.open_in_new, color: scheme.onSurfaceVariant, size: 20),
              ],
            ),
          ),
        ] else if (d.etat != 'manque')
          Text('Vous n’avez encore rien envoyé.', style: TextStyle(color: scheme.onSurfaceVariant)),

        // ---------- Dépôt ----------
        if (d.peutDeposer) ...[
          SectionTitle(r == null ? 'Envoyer mon devoir' : 'Remplacer mon fichier'),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _envoi ? null : _choisirFichier,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Choisir un fichier'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _envoi ? null : _prendrePhoto,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Photographier'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('PDF ou photo (JPG, PNG, WEBP), 10 Mo maximum.',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
          if (_nomChoisi != null) ...[
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: st.success),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('$_nomChoisi · ${_taille(_octets!.length)}',
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                    tooltip: 'Retirer ce fichier',
                    onPressed: _envoi ? null : () => setState(() {
                      _nomChoisi = null;
                      _octets = null;
                    }),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          ],
          if (_erreurFichier != null) ...[
            const SizedBox(height: 8),
            Semantics(liveRegion: true, child: Text(_erreurFichier!, style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600))),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: st.warning, foregroundColor: Colors.white),
            onPressed: _nomChoisi == null || _envoi ? null : _envoyer,
            icon: _envoi
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : const Icon(Icons.send_rounded),
            label: Text(r == null ? 'Envoyer mon devoir' : 'Envoyer le nouveau fichier'),
          ),
          if (_nomChoisi == null) ...[
            const SizedBox(height: 8),
            Text('Choisissez d’abord un fichier ou prenez une photo.',
                textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
          ],
        ],
      ],
    );
  }
}
