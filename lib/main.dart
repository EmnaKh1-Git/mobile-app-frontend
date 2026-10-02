import 'package:flutter/material.dart';
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
      home: const AccueilPage(),
    );
  }
}