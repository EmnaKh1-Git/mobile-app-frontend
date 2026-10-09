import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../reclamation/models/reclamation.dart';
import '../../reclamation/screens/reclamation_page.dart';
import '../../reclamation/services/reclamation_service.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final reclamations = ReclamationService.instance.reclamations;
    final reclamationsActives = reclamations
        .where((reclamation) => reclamation.status != ReclamationStatus.resolue)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon profil'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.primaire,
                    child: Text(
                      'H',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hajer',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Étudiante · Niveau 2',
                          style: TextStyle(
                            color: AppColors.texte2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.report_problem_outlined, color: AppColors.accent),
            title: const Text('Mes réclamations'),
            subtitle: Text('$reclamationsActives dossiers actifs'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ReclamationPage(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.add_circle_outline, color: AppColors.primaire),
            title: const Text('Déclarer un problème'),
            subtitle: const Text('Signaler un retard ou un incident'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AjouterReclamationPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}