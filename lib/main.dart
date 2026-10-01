import 'package:flutter/material.dart';

import 'screens/accueil_page.dart';

void main() {
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