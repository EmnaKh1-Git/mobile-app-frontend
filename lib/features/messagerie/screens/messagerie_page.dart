import 'package:flutter/material.dart';

class MessageriePage extends StatelessWidget {
  const MessageriePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messagerie'),
      ),
      body: const Center(
        child: Text('Messagerie'),
      ),
    );
  }
}