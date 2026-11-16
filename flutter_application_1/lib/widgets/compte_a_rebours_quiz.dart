import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Le compte à rebours apparaît 5 minutes avant le début d'un quiz.
const rappelQuiz = Duration(minutes: 5);

/// Dernière minute : il clignote en rouge.
const urgenceQuiz = Duration(minutes: 1);

String mmss(Duration d) {
  final s = d.isNegative ? 0 : (d.inMilliseconds / 1000).ceil();
  return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Statut réel d'un QCM (programme → en_cours → termine) d'après ses dates, à la seconde près.
/// Le serveur le met aussi à jour : on l'anticipe pour que l'écran change sans rechargement.
String statutQuizEffectif(Map d, [DateTime? now]) {
  final statut = '${d['statut']}';
  if (d['type'] != 'qcm' || (statut != 'programme' && statut != 'en_cours')) return statut;
  final t = now ?? DateTime.now();
  final debut = DateTime.tryParse('${d['date_debut']}')?.toLocal();
  var fin = DateTime.tryParse('${d['date_limite']}')?.toLocal();
  final duree = int.tryParse('${d['duree_minutes']}');
  if (fin == null && debut != null && duree != null) fin = debut.add(Duration(minutes: duree));
  if (fin != null && !t.isBefore(fin)) return 'termine';
  if (debut != null && !t.isBefore(debut)) return 'en_cours';
  return statut;
}

/// « Commence dans mm:ss » : visible 5 minutes avant [debut], clignote en rouge la dernière minute.
/// [onFini] est appelé quand la minuterie arrive à zéro (le quiz commence).
class CompteAReboursQuiz extends StatefulWidget {
  final DateTime debut;
  final VoidCallback? onFini;

  /// Grand format (écran de présentation du quiz) ou pastille (cartes, listes).
  final bool grand;
  const CompteAReboursQuiz({super.key, required this.debut, this.onFini, this.grand = false});

  @override
  State<CompteAReboursQuiz> createState() => _CompteAReboursQuizState();
}

class _CompteAReboursQuizState extends State<CompteAReboursQuiz> with SingleTickerProviderStateMixin {
  Timer? _timer;
  late Duration _reste;
  bool _fini = false;
  late final AnimationController _clignote =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

  @override
  void initState() {
    super.initState();
    _reste = widget.debut.difference(DateTime.now());
    _fini = _reste <= Duration.zero;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _majClignotement();
  }

  @override
  void didUpdateWidget(covariant CompteAReboursQuiz old) {
    super.didUpdateWidget(old);
    if (old.debut != widget.debut) {
      _fini = false;
      _tick();
    }
  }

  void _tick() {
    if (!mounted) return;
    final reste = widget.debut.difference(DateTime.now());
    setState(() => _reste = reste);
    _majClignotement();
    if (reste <= Duration.zero && !_fini) {
      _fini = true;
      widget.onFini?.call();
    }
  }

  void _majClignotement() {
    final urgent = _reste > Duration.zero && _reste <= urgenceQuiz;
    // Respecte « Supprimer les animations » de l'appareil
    final animations = !(WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations);
    if (urgent && animations && !_clignote.isAnimating) {
      _clignote.repeat(reverse: true);
    } else if (!urgent && _clignote.isAnimating) {
      _clignote
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _clignote.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reste <= Duration.zero || _reste > rappelQuiz) return const SizedBox.shrink();
    final st = StatusColors.of(context);
    final urgent = _reste <= urgenceQuiz;
    final fg = urgent ? st.danger : st.warning;
    final bg = urgent ? st.dangerBg : st.warningBg;
    final secondes = (_reste.inMilliseconds / 1000).ceil();

    return Semantics(
      liveRegion: urgent,
      label: 'Le quiz commence dans ${secondes ~/ 60} minutes ${secondes % 60} secondes',
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _clignote,
          builder: (context, _) {
            // Clignotement : le fond passe du rouge pâle au rouge plein
            final t = urgent ? _clignote.value : 0.0;
            final fond = Color.lerp(bg, fg, t)!;
            final texte = Color.lerp(fg, Colors.white, t)!;
            return widget.grand ? _grand(fond, texte) : _pastille(fond, texte);
          },
        ),
      ),
    );
  }

  Widget _pastille(Color fond, Color texte) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: fond, borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined, size: 13, color: texte),
            const SizedBox(width: 4),
            Text('DANS ${mmss(_reste)}',
                style: TextStyle(
                  color: texte,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  fontFeatures: const [FontFeature.tabularFigures()],
                )),
          ],
        ),
      );

  Widget _grand(Color fond, Color texte) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(color: fond, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Text('Le quiz commence dans', style: TextStyle(color: texte, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(mmss(_reste),
                style: TextStyle(
                  color: texte,
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                )),
          ],
        ),
      );
}
