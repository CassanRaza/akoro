# flutter_application_1

A new Flutter project.

## Connexion à l'API Laravel en développement

L'API doit être accessible depuis l'appareil mobile. Dans un terminal, depuis `akoro-api`, lancez Laravel sur le réseau local :

```powershell
php artisan serve --host=0.0.0.0 --port=8000
```

Arrêtez d'abord l'instance `php artisan serve` déjà lancée (`Ctrl+C`) pour libérer le port 8000.

- **Émulateur Android** : l'application utilise `http://10.0.2.2:8000/api` par défaut. Aucun `API_URL` supplémentaire n'est nécessaire.
- **Téléphone Android réel** : connectez le téléphone et le PC au même Wi-Fi, puis remplacez `<IP_DU_PC>` par l'adresse IPv4 Wi-Fi affichée par `ipconfig` :

```powershell
flutter run --dart-define=API_URL=http://<IP_DU_PC>:8000/api
```

Pour générer un APK configuré pour ce téléphone :

```powershell
flutter build apk --dart-define=API_URL=http://<IP_DU_PC>:8000/api
```

Si le pare-feu Windows le demande, autorisez PHP sur le réseau privé. Cette configuration sert au développement sur le réseau local ; elle ne remplace pas une URL HTTPS d'API déployée pour une application distribuée.

Une connexion réseau rétablie ne valide pas automatiquement les comptes : une inscription mobile doit d'abord être activée par le Super Admin.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
