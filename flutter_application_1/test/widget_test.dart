import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:akoro_mobile/app.dart';
import 'package:akoro_mobile/providers/auth_provider.dart';

void main() {
  testWidgets('AKORO affiche l’écran de connexion au démarrage', (WidgetTester tester) async {
    final auth = AuthProvider();
    // Évite le bootstrap async qui charge SharedPreferences
    auth.loading = false;

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const AkoroApp(),
      ),
    );

    await tester.pump();

    // L’utilisateur n’est pas connecté → écran login
    expect(find.text('AKORO'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });
}