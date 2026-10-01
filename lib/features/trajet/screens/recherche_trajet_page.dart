import 'package:flutter/material.dart';

class RechercheTrajetPage extends StatelessWidget {
  const RechercheTrajetPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rechercher un trajet'),
      ),
      body: const Center(
        child: Text('Recherche de trajet'),
      ),
    );
  }
}