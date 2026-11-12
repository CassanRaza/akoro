import 'package:flutter/material.dart';

/// Rendu simple du Markdown renvoyé par FAB'IA (titres, listes, **gras**, *italique*, `code`),
/// comme le composant Markdown du web.
class TexteMarkdown extends StatelessWidget {
  final String texte;
  final TextStyle? style;
  const TexteMarkdown(this.texte, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style.copyWith(height: 1.45);
    final scheme = Theme.of(context).colorScheme;
    final blocs = <Widget>[];

    for (final brut in texte.replaceAll('\r', '').split('\n')) {
      final ligne = brut.trimRight();
      if (ligne.trim().isEmpty) {
        if (blocs.isNotEmpty) blocs.add(const SizedBox(height: 6));
        continue;
      }

      final titre = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(ligne.trim());
      if (titre != null) {
        blocs.add(Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 2),
          child: Text.rich(_enLigne(titre.group(2)!, base.copyWith(fontWeight: FontWeight.w800), scheme)),
        ));
        continue;
      }

      final puce = RegExp(r'^(\s*)([-*•]|\d+[.)])\s+(.*)$').firstMatch(ligne);
      if (puce != null) {
        final retrait = (puce.group(1)!.length ~/ 2) * 14.0;
        final marque = RegExp(r'\d').hasMatch(puce.group(2)!) ? puce.group(2)! : '•';
        blocs.add(Padding(
          padding: EdgeInsets.only(left: retrait, top: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 20, child: Text(marque, style: base.copyWith(fontWeight: FontWeight.w700))),
              Expanded(child: Text.rich(_enLigne(puce.group(3)!, base, scheme))),
            ],
          ),
        ));
        continue;
      }

      blocs.add(Text.rich(_enLigne(ligne, base, scheme)));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: blocs);
  }

  /// **gras**, *italique* / _italique_, `code`
  static TextSpan _enLigne(String s, TextStyle base, ColorScheme scheme) {
    final morceaux = <InlineSpan>[];
    final motif = RegExp(r'\*\*(.+?)\*\*|`([^`]+)`|\*(?!\s)(.+?)\*|(?<![\w])_(?!\s)(.+?)_(?![\w])');
    var pos = 0;
    for (final m in motif.allMatches(s)) {
      if (m.start > pos) morceaux.add(TextSpan(text: s.substring(pos, m.start)));
      if (m.group(1) != null) {
        morceaux.add(TextSpan(text: m.group(1), style: const TextStyle(fontWeight: FontWeight.w800)));
      } else if (m.group(2) != null) {
        morceaux.add(TextSpan(
          text: m.group(2),
          style: TextStyle(fontFamily: 'monospace', backgroundColor: scheme.surfaceContainerHighest),
        ));
      } else {
        morceaux.add(TextSpan(text: m.group(3) ?? m.group(4), style: const TextStyle(fontStyle: FontStyle.italic)));
      }
      pos = m.end;
    }
    if (pos < s.length) morceaux.add(TextSpan(text: s.substring(pos)));
    return TextSpan(style: base, children: morceaux);
  }
}
