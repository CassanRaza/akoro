import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thème choisi par l'utilisateur : Système (suit le téléphone), Clair ou Sombre. Mémorisé sur l'appareil.
class ThemeProvider extends ChangeNotifier {
  static const _cle = 'akoro_theme';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  Future<void> charger() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _mode = switch (prefs.getString(_cle)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      notifyListeners();
    } catch (_) {
      // Préférence illisible : on garde le thème du téléphone
    }
  }

  Future<void> choisir(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cle, mode.name);
    } catch (_) {}
  }

  /// Bascule rapide Clair ⇄ Sombre (à partir de ce qui est affiché).
  Future<void> basculer(Brightness affiche) =>
      choisir(affiche == Brightness.dark ? ThemeMode.light : ThemeMode.dark);
}

/// Bouton soleil / lune : bascule Clair ⇄ Sombre.
class ThemeToggleButton extends StatelessWidget {
  final Color? color;
  const ThemeToggleButton({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final sombre = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: sombre ? 'Passer en mode clair' : 'Passer en mode sombre',
      color: color,
      onPressed: () => context.read<ThemeProvider>().basculer(Theme.of(context).brightness),
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, anim) => RotationTransition(turns: anim, child: FadeTransition(opacity: anim, child: child)),
        child: Icon(sombre ? Icons.light_mode_rounded : Icons.dark_mode_rounded, key: ValueKey(sombre)),
      ),
    );
  }
}

/// Choix complet Système / Clair / Sombre (panneau « Mon compte »).
class ThemeModeSelector extends StatelessWidget {
  const ThemeModeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return SegmentedButton<ThemeMode>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(minimumSize: const Size(0, 48)),
      segments: const [
        ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined), label: Text('Système')),
        ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Clair')),
        ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Sombre')),
      ],
      selected: {theme.mode},
      onSelectionChanged: (s) => context.read<ThemeProvider>().choisir(s.first),
    );
  }
}
