import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/auth_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider<AuthProvider>(
      create: (_) => AuthProvider()..bootstrap(),
      child: const AkoroApp(),
    ),
  );
}
