import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Carte blanche arrondie des maquettes, cliquable si [onTap].
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String? semantique;
  final EdgeInsets padding;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.semantique,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
    this.borderWidth = 1,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: onTap != null,
      label: semantique,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: color == null ? ombreCarte(context) : const [],
        ),
        child: Material(
          color: color ?? scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: borderColor ?? scheme.outlineVariant.withValues(alpha: 0.8), width: borderWidth),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: padding,
              child: semantique != null ? ExcludeSemantics(child: child) : child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Étiquette en capitales (« ARTISANAT NUMÉRIQUE », « EN COURS »…).
class Tag extends StatelessWidget {
  final String texte;
  final Color fg, bg;
  final IconData? icon;
  const Tag(this.texte, {super.key, required this.fg, required this.bg, this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
            Flexible(
              child: Text(
                texte.toUpperCase(),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: fg, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.3),
              ),
            ),
          ],
        ),
      );
}

/// Barre de progression arrondie.
class BarreProgression extends StatelessWidget {
  final double valeur; // 0..1
  final Color couleur;
  final Color? fond;
  final double hauteur;
  const BarreProgression({super.key, required this.valeur, required this.couleur, this.fond, this.hauteur = 7});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(hauteur),
        child: LinearProgressIndicator(
          value: valeur.clamp(0, 1),
          minHeight: hauteur,
          color: couleur,
          backgroundColor: fond ?? Theme.of(context).colorScheme.outlineVariant,
        ),
      );
}

/// Message centré (liste vide, rien trouvé…).
class EtatVide extends StatelessWidget {
  final IconData icon;
  final String titre;
  final String? texte;
  final Widget? action;
  const EtatVide({super.key, required this.icon, required this.titre, this.texte, this.action});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 52, color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
          const SizedBox(height: 14),
          Text(titre, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          if (texte != null) ...[
            const SizedBox(height: 6),
            Text(texte!, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}

/// Erreur réseau avec bouton « Réessayer ».
class EtatErreur extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const EtatErreur({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => EtatVide(
        icon: Icons.cloud_off_rounded,
        titre: 'Chargement impossible',
        texte: message,
        action: FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Réessayer')),
      );
}
