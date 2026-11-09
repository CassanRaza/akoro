import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/beneficiaire/beneficiaire_shell.dart';
import 'screens/team_home_screen.dart';
import 'theme/app_theme.dart';

class AkoroApp extends StatelessWidget {
  const AkoroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AKORO',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: context.watch<ThemeProvider>().mode,
      // Textes système (sélecteurs, boutons copier/coller…) en français
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.loading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator(semanticsLabel: 'Chargement de la session')),
            );
          }
          if (!auth.isAuthenticated) return const LoginScreen();
          // Même compte, même règles que le web : l'écran dépend du rôle
          return auth.isBeneficiaire ? const BeneficiaireShell() : const TeamHomeScreen();
        },
      ),
    );
  }
}
