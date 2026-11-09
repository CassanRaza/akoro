import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/api_config.dart';
import '../../../models/formation.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/api_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/ui.dart';
import 'quiz_screen.dart';

/// Lecture d'un chapitre (document de la leçon) ; « Suivant » le marque comme terminé.
/// Renvoie la formation mise à jour à l'écran précédent.
class ChapitreScreen extends StatefulWidget {
  final FormationDetail formation;
  final int chapitreId;
  const ChapitreScreen({super.key, required this.formation, required this.chapitreId});

  @override
  State<ChapitreScreen> createState() => _ChapitreScreenState();
}

class _ChapitreScreenState extends State<ChapitreScreen> {
  late FormationDetail _f = widget.formation;
  late int _id = widget.chapitreId;
  bool _envoi = false;
  final _scroll = ScrollController();

  Chapitre get _c => _f.chapitres.firstWhere((c) => c.id == _id, orElse: () => _f.chapitres.first);
  int get _index => _f.chapitres.indexWhere((c) => c.id == _c.id);
  bool get _dernier => _index == _f.chapitres.length - 1;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _allerA(Chapitre c) {
    setState(() => _id = c.id);
    _scroll.jumpTo(0);
  }

  Future<void> _ouvrirDocument({bool telecharger = false}) async {
    final uri = ApiConfig.fichier(telecharger ? _c.downloadUrl : _c.url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune application ne peut ouvrir ce document sur ce téléphone.')),
      );
    }
  }

  /// Termine le chapitre (si besoin) puis passe au suivant, ou revient à la formation.
  Future<void> _suivant() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!_c.termine) {
      setState(() => _envoi = true);
      try {
        final json = await context.read<AuthProvider>().api.post('/chapitres/${_c.id}/terminer');
        if (!mounted) return;
        setState(() => _f = FormationDetail.fromJson(Map<String, dynamic>.from(json as Map)));
      } on ApiException catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
        return;
      } finally {
        if (mounted) setState(() => _envoi = false);
      }
    }
    if (!mounted) return;

    if (_dernier) {
      messenger.showSnackBar(SnackBar(
        content: Text(_f.avancement.termine ? 'Bravo, formation terminée ! 🎉' : 'Chapitre terminé.'),
      ));
      Navigator.of(context).pop(_f);
    } else {
      _allerA(_f.chapitres[_index + 1]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final st = StatusColors.of(context);
    final c = _c;
    final quiz = _f.quiz.where((q) => q.jouable).firstOrNull;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_f);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => Navigator.of(context).pop(_f)),
          titleSpacing: 0,
          title: Text.rich(
            TextSpan(children: [
              TextSpan(text: '${_f.titre}  ›  ', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13.5)),
              TextSpan(
                text: 'Chapitre ${c.numero}',
                style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
            ]),
            overflow: TextOverflow.ellipsis,
          ),
          actions: const [ThemeToggleButton()],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: Semantics(
              label: 'Chapitre ${c.numero} sur ${_f.chapitres.length}',
              child: BarreProgression(
                valeur: (_index + 1) / _f.chapitres.length,
                couleur: scheme.primary,
                hauteur: 4,
                fond: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
        body: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Row(
              children: [
                Text('CHAPITRE ${c.numero} / ${_f.chapitres.length}',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.6)),
                const Spacer(),
                if (c.termine) Tag('Terminé', fg: st.success, bg: st.successBg, icon: Icons.check_rounded),
              ],
            ),
            const SizedBox(height: 8),
            Semantics(
              header: true,
              child: Text(c.titre, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            ),
            if ((_f.description ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(_f.description!, style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5, fontSize: 15)),
            ],
            const SizedBox(height: 20),
            _Document(c: c, onOuvrir: () => _ouvrirDocument(), onTelecharger: () => _ouvrirDocument(telecharger: true)),
            const SizedBox(height: 16),
            AppCard(
              color: scheme.primaryContainer.withValues(alpha: 0.4),
              borderColor: Colors.transparent,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, color: scheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      c.termine
                          ? 'Vous avez déjà terminé ce chapitre. Vous pouvez le relire autant que vous voulez.'
                          : 'Lisez le document, puis appuyez sur « ${_dernier ? 'Terminer' : 'Suivant'} » pour valider ce chapitre.',
                      style: const TextStyle(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _index == 0 || _envoi ? null : () => _allerA(_f.chapitres[_index - 1]),
                    child: const Text('Précédent'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _envoi ? null : _suivant,
                    child: _envoi
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
                        : Text(_dernier ? 'Terminer' : 'Suivant'),
                  ),
                ),
              ],
            ),
            if (quiz != null) ...[
              const SizedBox(height: 20),
              AppCard(
                color: st.warningBg,
                borderColor: st.warning.withValues(alpha: 0.4),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => QuizScreen(quiz: quiz)),
                ),
                semantique: 'Évaluez vos acquis : quiz ${quiz.titre}',
                child: Row(
                  children: [
                    Icon(Icons.help_outline, color: st.warning, size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Évaluez vos acquis !', style: TextStyle(color: st.warning, fontWeight: FontWeight.w800, fontSize: 15.5)),
                          const SizedBox(height: 2),
                          Text('Quiz « ${quiz.titre} » · ${quiz.nbQuestions} questions',
                              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
                        ],
                      ),
                    ),
                    Tag('Quiz', fg: Colors.white, bg: st.warning),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Aperçu du document : image affichée, sinon icône + boutons Ouvrir / Télécharger.
class _Document extends StatelessWidget {
  final Chapitre c;
  final VoidCallback onOuvrir, onTelecharger;
  const _Document({required this.c, required this.onOuvrir, required this.onTelecharger});

  IconData get _icone => switch (c.type) {
        'pdf' => Icons.picture_as_pdf_outlined,
        'doc' || 'docx' || 'odt' || 'rtf' || 'txt' => Icons.description_outlined,
        'ppt' || 'pptx' || 'odp' => Icons.slideshow_outlined,
        'xls' || 'xlsx' || 'ods' || 'csv' => Icons.table_chart_outlined,
        'stl' || 'dxf' || 'svg' => Icons.view_in_ar_outlined,
        'ino' => Icons.memory_outlined,
        'zip' => Icons.folder_zip_outlined,
        _ => Icons.insert_drive_file_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (c.estImage)
            Semantics(
              image: true,
              label: 'Illustration du chapitre : ${c.titre}',
              child: Image.network(
                ApiConfig.fichier(c.url).toString(),
                fit: BoxFit.contain,
                height: 220,
                loadingBuilder: (_, child, p) =>
                    p == null ? child : const SizedBox(height: 220, child: Center(child: CircularProgressIndicator())),
                errorBuilder: (_, _, _) => SizedBox(
                  height: 120,
                  child: Center(child: Text('Image indisponible', style: TextStyle(color: scheme.onSurfaceVariant))),
                ),
              ),
            )
          else
            Container(
              height: 150,
              color: scheme.primaryContainer.withValues(alpha: 0.35),
              child: Icon(_icone, size: 64, color: scheme.primary),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(c.nomFichier, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text([c.type.toUpperCase(), c.tailleLisible].where((t) => t.isNotEmpty).join(' · '),
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: const StadiumBorder()),
                        onPressed: onOuvrir,
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: Text(c.estImage ? 'Agrandir' : 'Ouvrir le document'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      tooltip: 'Télécharger',
                      onPressed: onTelecharger,
                      icon: const Icon(Icons.download_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
