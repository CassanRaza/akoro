import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:akoro_mobile/app.dart';
import 'package:akoro_mobile/providers/auth_provider.dart';
import 'package:akoro_mobile/providers/theme_provider.dart';
import 'package:akoro_mobile/services/api_service.dart';
import 'package:akoro_mobile/utils/validators.dart';

/// Faux serveur : renvoie la réponse prévue pour chaque chemin.
MockClient fauxServeur(Map<String, http.Response Function(http.BaseRequest)> routes, List<String> appels) =>
    MockClient.streaming((req, body) async {
      final chemin = req.url.path.replaceFirst('/api', '');
      appels.add('${req.method} $chemin');
      final r = routes['${req.method} $chemin']?.call(req) ?? http.Response('{"message":"inconnu"}', 404);
      return http.StreamedResponse(Stream.value(utf8.encode(r.body)), r.statusCode,
          headers: {'content-type': 'application/json'});
    });

http.Response json(Object body, [int status = 200]) => http.Response(jsonEncode(body), status);

Future<AuthProvider> monter(WidgetTester tester, MockClient client) async {
  final auth = AuthProvider(api: ApiService(client: client))..loading = false;
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
    ],
    child: const AkoroApp(),
  ));
  await tester.pumpAndSettle();
  return auth;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Validateurs (mêmes règles que le web)', () {
    test('email', () {
      expect(Validators.email(''), "L'adresse email est obligatoire.");
      expect(Validators.email('nom'), "L'adresse email doit contenir @.");
      expect(Validators.email('nom@haytao.mg'), isNull);
    });
    test('mot de passe', () {
      expect(Validators.password('abc'), contains('8 caractères'));
      expect(Validators.password('abcdefgh'), contains('une lettre et un chiffre'));
      expect(Validators.password('abcdefg1'), isNull);
    });
    test('téléphone et nom', () {
      expect(Validators.phone('+261 34 12 345 67'), isNull);
      expect(Validators.phone('1234'), contains('9 et 15'));
      expect(Validators.name('Rasolofoniaina Hervé'), isNull);
      expect(Validators.name('Jean2'), isNotNull);
    });
  });

  testWidgets('Connexion : champs vides → erreurs sous les champs, aucun appel serveur', (tester) async {
    final appels = <String>[];
    await monter(tester, fauxServeur({}, appels));

    expect(find.text('Connexion'), findsOneWidget);
    await tester.tap(find.text('Se connecter'));
    await tester.pump();

    expect(find.text("L'adresse email est obligatoire."), findsOneWidget);
    expect(find.text('Le mot de passe est obligatoire.'), findsOneWidget);
    expect(appels, isEmpty);
  });

  testWidgets('Connexion : un formateur peut se connecter et arrive sur l’espace équipe', (tester) async {
    final appels = <String>[];
    await monter(
      tester,
      fauxServeur({
        'POST /login': (_) => json({
              'token': 't0k',
              'user': {'id': 2, 'name': 'Rakoto Jean', 'role': 'formateur'},
            }),
      }, appels),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'jean@haytao.mg');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();

    expect(appels, ['POST /login']);
    expect(find.text('Espace équipe'), findsOneWidget);
    expect(find.text('Formateur'), findsOneWidget);
  });

  testWidgets('Connexion : compte en attente → message du serveur affiché', (tester) async {
    await monter(
      tester,
      fauxServeur({
        'POST /login': (_) => json({'message': 'Votre compte est en attente de validation ou désactivé.'}, 403),
      }, []),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'new@haytao.mg');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();

    expect(find.textContaining('en attente de validation'), findsOneWidget);
  });

  testWidgets('Inscription : choix bénéficiaire → FabLab chargé et choisi d’office', (tester) async {
    final appels = <String>[];
    await monter(
      tester,
      fauxServeur({
        'GET /inscription/options': (_) => json([
              {
                'id': 1,
                'nom': 'FabLab Hay Tao',
                'adresse': 'Fianarantsoa',
                'parcours': [
                  {'id': 3, 'nom': 'Couture numérique'},
                ],
              },
            ]),
      }, appels),
    );

    await tester.tap(find.text('S’inscrire'));
    await tester.pumpAndSettle();
    expect(find.text('Vous êtes…'), findsOneWidget);
    // Le bouton d'envoi n'apparaît qu'après le choix du profil
    expect(find.text('Envoyer mon inscription'), findsNothing);

    await tester.tap(find.text('Bénéficiaire'));
    await tester.pumpAndSettle();

    expect(appels, contains('GET /inscription/options'));
    expect(find.text('FabLab Hay Tao · Fianarantsoa'), findsOneWidget);
    expect(find.text('Envoyer mon inscription'), findsOneWidget);
  });

  testWidgets('Inscription équipe : le rôle est obligatoire, la demande part en attente', (tester) async {
    final appels = <String>[];
    await monter(
      tester,
      fauxServeur({
        'POST /admin/register': (_) => json({'message': 'Demande envoyée. Un Super Admin doit valider votre compte.'}, 201),
      }, appels),
    );

    await tester.tap(find.text('S’inscrire'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Membre de l’équipe'));
    await tester.pumpAndSettle();

    final champs = find.byType(TextFormField);
    await tester.enterText(champs.at(0), 'Rabe Hery');
    await tester.enterText(champs.at(1), 'hery@haytao.mg');
    await tester.enterText(champs.at(2), '+261 34 12 345 67');
    await tester.enterText(champs.at(3), 'Lot 12 Ambalakilonga');
    await tester.enterText(champs.at(4), 'secret123');
    await tester.enterText(champs.at(5), 'secret123');

    await tester.ensureVisible(find.text('Envoyer ma demande'));
    await tester.tap(find.text('Envoyer ma demande'));
    await tester.pumpAndSettle();
    expect(find.text('Veuillez choisir un rôle.'), findsOneWidget);
    expect(appels, isEmpty);

    await tester.ensureVisible(find.text('Formateur'));
    await tester.tap(find.text('Formateur'));
    await tester.pump();
    await tester.ensureVisible(find.text('Envoyer ma demande'));
    await tester.tap(find.text('Envoyer ma demande'));
    await tester.pumpAndSettle();

    expect(appels, ['POST /admin/register']);
    expect(find.text('Inscription envoyée'), findsOneWidget);
    expect(find.text('Retour à la connexion'), findsOneWidget);
  });
}
