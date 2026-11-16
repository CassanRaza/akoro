import 'package:flutter/material.dart';

/// Emojis proposés dans la messagerie, rangés par catégorie (même liste que le web : src/utils/emojis.js).
const categoriesEmojis = <({String label, String icone, List<String> emojis})>[
  (
    label: 'Smileys',
    icone: '😀',
    emojis: [
      '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂', '🙂', '🙃', '😉', '😊', '😇', '🥰', '😍', '🤩',
      '😘', '😗', '😚', '😋', '😛', '😜', '🤪', '😝', '🤗', '🤭', '🤫', '🤔', '🤐', '🤨', '😐', '😑',
      '😶', '😏', '😒', '🙄', '😬', '😌', '😔', '😪', '😴', '😷', '🤒', '🤕', '🤢', '🥵', '🥶', '😵',
      '🤯', '🤠', '🥳', '😎', '🤓', '🧐', '😕', '😟', '🙁', '😮', '😯', '😲', '😳', '🥺', '😦', '😧',
      '😨', '😰', '😥', '😢', '😭', '😱', '😖', '😣', '😞', '😓', '😩', '😫', '🥱', '😤', '😡', '😠',
    ],
  ),
  (
    label: 'Gestes',
    icone: '👍',
    emojis: [
      '👍', '👎', '👌', '✌️', '🤞', '🤟', '🤘', '🤙', '👈', '👉', '👆', '👇', '☝️', '✋', '🤚', '🖐️',
      '🖖', '👋', '👏', '🙌', '👐', '🤲', '🤝', '🙏', '✍️', '💪', '🧠', '👀', '👁️', '🙋', '🙆', '🙅',
      '🤷', '🤦', '🙇', '💁', '🧑‍💻', '🧑‍🏫', '🧑‍🎓', '🧑‍🔧', '🧑‍🔬', '🧑‍🎨',
    ],
  ),
  (
    label: 'Cœurs',
    icone: '❤️',
    emojis: [
      '❤️', '🧡', '💛', '💚', '💙', '💜', '🤎', '🖤', '🤍', '💔', '❣️', '💕', '💞', '💓', '💗', '💖',
      '💘', '💝', '💯', '💢', '💥', '💫', '💦', '💨', '🔥', '✨', '⭐', '🌟', '⚡', '🎉', '🎊', '🏆',
    ],
  ),
  (
    label: 'Objets',
    icone: '💡',
    emojis: [
      '💡', '📚', '📖', '📝', '✏️', '🖊️', '📌', '📎', '📁', '📂', '📄', '📅', '📆', '⏰', '⏳', '⌛',
      '💻', '🖥️', '⌨️', '🖱️', '🖨️', '📱', '☎️', '📷', '🎥', '🎧', '🎤', '🔧', '🔨', '🛠️', '⚙️', '🔩',
      '🧪', '🔬', '🔭', '📡', '🔋', '🔌', '🧲', '🧰', '🤖', '🚀', '🎯', '🎓', '🏫', '✅', '❌', '⚠️',
      '❓', '❗', '➕', '➖', '🔔', '🔒', '🔑', '📢', '💬', '💭', '🗓️', '📊', '📈', '📉', '🗂️', '🧾',
    ],
  ),
  (
    label: 'Nature & repas',
    icone: '🌿',
    emojis: [
      '☀️', '🌤️', '⛅', '🌧️', '⛈️', '🌈', '🌙', '🌍', '🌿', '🌱', '🌳', '🌸', '🌻', '🌺', '🍀', '🐶',
      '🐱', '🐭', '🐰', '🦊', '🐻', '🐼', '🦁', '🐯', '🐸', '🐵', '🐔', '🐧', '🦋', '🐝', '🐢', '🦎',
      '☕', '🍵', '🥤', '🍔', '🍕', '🍟', '🥗', '🍚', '🍜', '🍰', '🎂', '🍫', '🍎', '🍌', '🥭', '🍉',
    ],
  ),
];

/// Insère [texte] à la position du curseur du [controller] (remplace la sélection éventuelle).
void insererAuCurseur(TextEditingController controller, String texte, {int maxLength = 2000}) {
  final valeur = controller.text;
  final sel = controller.selection;
  final debut = sel.isValid ? sel.start : valeur.length;
  final fin = sel.isValid ? sel.end : valeur.length;
  final nouvelle = valeur.replaceRange(debut, fin, texte);
  if (nouvelle.length > maxLength) return;
  controller.value = TextEditingValue(
    text: nouvelle,
    selection: TextSelection.collapsed(offset: debut + texte.length),
  );
}

/// Panneau d'emojis affiché à la place du clavier (onglets par catégorie).
class SelecteurEmojis extends StatelessWidget {
  final ValueChanged<String> onChoisir;
  final double hauteur;
  const SelecteurEmojis({super.key, required this.onChoisir, this.hauteur = 280});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: categoriesEmojis.length,
      child: Container(
        height: hauteur,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Column(
          children: [
            TabBar(
              isScrollable: false,
              labelPadding: EdgeInsets.zero,
              tabs: [
                for (final c in categoriesEmojis)
                  Tab(
                    height: 48,
                    child: Tooltip(message: c.label, child: Text(c.icone, style: const TextStyle(fontSize: 22))),
                  ),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  for (final c in categoriesEmojis)
                    GridView.builder(
                      padding: const EdgeInsets.all(6),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 48, mainAxisExtent: 48),
                      itemCount: c.emojis.length,
                      itemBuilder: (_, i) => InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => onChoisir(c.emojis[i]),
                        child: Center(
                          child: Semantics(
                            button: true,
                            label: 'Insérer ${c.emojis[i]}',
                            child: Text(c.emojis[i], style: const TextStyle(fontSize: 26)),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
