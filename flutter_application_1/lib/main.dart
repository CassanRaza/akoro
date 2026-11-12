import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/auth_provider.dart';
import 'providers/notifications_provider.dart';
import 'providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Noms des jours et des mois en français (« mardi 12 novembre »)
  await initializeDateFormatting('fr');
  // Thème lu avant le premier affichage : pas de flash clair → sombre au démarrage
  final theme = ThemeProvider();
  await theme.charger();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()..bootstrap()),
        ChangeNotifierProvider<ThemeProvider>.value(value: theme),
        ChangeNotifierProvider<NotificationsProvider>(create: (ctx) => NotificationsProvider(ctx.read<AuthProvider>())),
      ],
      child: const AkoroApp(),
    ),
  );
}
