import 'package:flutter/material.dart';

class MesTrajetsPage extends StatelessWidget {
  const MesTrajetsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes trajets'),
      ),
      body: const Center(
        child: Text('Mes trajets'),
      ),
    );
  }
}