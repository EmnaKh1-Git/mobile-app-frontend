import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';  // <-- AJOUTER
import 'package:intl/date_symbol_data_local.dart';
import 'screens/accueil_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);
  runApp(const CovoiturageApp());
}

class CovoiturageApp extends StatelessWidget {
  const CovoiturageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Covoiturage Étudiant',
      // ⬇️⬇️⬇️ AJOUTER CES 4 LIGNES ⬇️⬇️⬇️
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [
        Locale('fr', 'FR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // ⬆️⬆️⬆️ FIN DE L'AJOUT ⬆️⬆️⬆️
      home: const AccueilPage(),
    );
  }
}