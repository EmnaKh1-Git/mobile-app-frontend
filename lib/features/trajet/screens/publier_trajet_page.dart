import 'package:flutter/material.dart';

class PublierTrajetPage extends StatelessWidget {
  const PublierTrajetPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Publier un trajet'),
      ),
      body: const Center(
        child: Text('Publication d’un trajet'),
      ),
    );
  }
}