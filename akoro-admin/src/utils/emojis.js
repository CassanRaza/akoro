// Emojis proposés dans la messagerie, rangés par catégorie (même liste que l'application mobile)
export const CATEGORIES_EMOJIS = [
  {
    id: 'smileys',
    label: 'Smileys',
    icone: '😀',
    emojis: [
      '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂', '🙂', '🙃', '😉', '😊', '😇', '🥰', '😍', '🤩',
      '😘', '😗', '😚', '😋', '😛', '😜', '🤪', '😝', '🤗', '🤭', '🤫', '🤔', '🤐', '🤨', '😐', '😑',
      '😶', '😏', '😒', '🙄', '😬', '😌', '😔', '😪', '😴', '😷', '🤒', '🤕', '🤢', '🥵', '🥶', '😵',
      '🤯', '🤠', '🥳', '😎', '🤓', '🧐', '😕', '😟', '🙁', '😮', '😯', '😲', '😳', '🥺', '😦', '😧',
      '😨', '😰', '😥', '😢', '😭', '😱', '😖', '😣', '😞', '😓', '😩', '😫', '🥱', '😤', '😡', '😠',
    ],
  },
  {
    id: 'gestes',
    label: 'Gestes',
    icone: '👍',
    emojis: [
      '👍', '👎', '👌', '✌️', '🤞', '🤟', '🤘', '🤙', '👈', '👉', '👆', '👇', '☝️', '✋', '🤚', '🖐️',
      '🖖', '👋', '👏', '🙌', '👐', '🤲', '🤝', '🙏', '✍️', '💪', '🧠', '👀', '👁️', '🙋', '🙆', '🙅',
      '🤷', '🤦', '🙇', '💁', '🧑‍💻', '🧑‍🏫', '🧑‍🎓', '🧑‍🔧', '🧑‍🔬', '🧑‍🎨',
    ],
  },
  {
    id: 'coeurs',
    label: 'Cœurs',
    icone: '❤️',
    emojis: [
      '❤️', '🧡', '💛', '💚', '💙', '💜', '🤎', '🖤', '🤍', '💔', '❣️', '💕', '💞', '💓', '💗', '💖',
      '💘', '💝', '💯', '💢', '💥', '💫', '💦', '💨', '🔥', '✨', '⭐', '🌟', '⚡', '🎉', '🎊', '🏆',
    ],
  },
  {
    id: 'objets',
    label: 'Objets',
    icone: '💡',
    emojis: [
      '💡', '📚', '📖', '📝', '✏️', '🖊️', '📌', '📎', '📁', '📂', '📄', '📅', '📆', '⏰', '⏳', '⌛',
      '💻', '🖥️', '⌨️', '🖱️', '🖨️', '📱', '☎️', '📷', '🎥', '🎧', '🎤', '🔧', '🔨', '🛠️', '⚙️', '🔩',
      '🧪', '🔬', '🔭', '📡', '🔋', '🔌', '🧲', '🧰', '🤖', '🚀', '🎯', '🎓', '🏫', '✅', '❌', '⚠️',
      '❓', '❗', '➕', '➖', '🔔', '🔒', '🔑', '📢', '💬', '💭', '🗓️', '📊', '📈', '📉', '🗂️', '🧾',
    ],
  },
  {
    id: 'nature',
    label: 'Nature & repas',
    icone: '🌿',
    emojis: [
      '☀️', '🌤️', '⛅', '🌧️', '⛈️', '🌈', '🌙', '🌍', '🌿', '🌱', '🌳', '🌸', '🌻', '🌺', '🍀', '🐶',
      '🐱', '🐭', '🐰', '🦊', '🐻', '🐼', '🦁', '🐯', '🐸', '🐵', '🐔', '🐧', '🦋', '🐝', '🐢', '🦎',
      '☕', '🍵', '🥤', '🍔', '🍕', '🍟', '🥗', '🍚', '🍜', '🍰', '🎂', '🍫', '🍎', '🍌', '🥭', '🍉',
    ],
  },
];

/** Insère `texte` à la position du curseur d'un champ et renvoie la nouvelle valeur + position. */
export function insererAuCurseur(champ, valeur, texte) {
  if (!champ) return { valeur: valeur + texte, position: (valeur + texte).length };
  const debut = champ.selectionStart ?? valeur.length;
  const fin = champ.selectionEnd ?? valeur.length;
  const nouvelle = valeur.slice(0, debut) + texte + valeur.slice(fin);
  return { valeur: nouvelle, position: debut + texte.length };
}
