// ============================================================
//  MODULE : GESTION DES TRAJETS (Yassine)
//  Fichier : lib/features/trajet/widgets/presence_passager.dart
//  Pointage des passagers au départ (conducteur) :
//   - PastillePresence : « À bord », « Absent » ou « À pointer » ;
//   - BoutonsPresence : présent / absent, actifs dès l'ouverture de
//     la discussion (2 h avant le départ) et pendant le trajet.
// ============================================================

import 'package:flutter/material.dart';

import '../../../models/discussion_trajet.dart';
import '../../../models/trajet.dart';
import '../services/discussion_service.dart';

const Color _vert = Color(0xFF1B7F55);
const Color _rouge = Color(0xFFA3281A);

class PastillePresence extends StatelessWidget {
  final PresencePassager presence;
  const PastillePresence({super.key, required this.presence});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (libelle, couleur, icone) = switch (presence) {
      PresencePassager.present => ('À bord', _vert, Icons.check_circle),
      PresencePassager.absent => ('Absent', _rouge, Icons.cancel),
      PresencePassager.inconnue =>
        ('À pointer', cs.onSurfaceVariant, Icons.radio_button_unchecked),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 13, color: couleur),
          const SizedBox(width: 4),
          Text(libelle,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: couleur)),
        ],
      ),
    );
  }
}

class BoutonsPresence extends StatelessWidget {
  final Trajet trajet;
  final PassagerTrajet passager;
  const BoutonsPresence(
      {super.key, required this.trajet, required this.passager});

  Future<void> _marquer(BuildContext context, PresencePassager p) async {
    final erreur = await DiscussionService.instance
        .marquerPresence(trajet, passager.passagerId, p);
    if (erreur != null && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erreur)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final present = passager.presence == PresencePassager.present;
    final absent = passager.presence == PresencePassager.absent;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: '${passager.nom} est à bord',
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            backgroundColor: present ? _vert : null,
            foregroundColor: present ? Colors.white : _vert,
            side: BorderSide(color: _vert.withValues(alpha: 0.5)),
          ),
          onPressed: () => _marquer(context, PresencePassager.present),
          icon: const Icon(Icons.check, size: 18),
        ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: '${passager.nom} est absent',
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            backgroundColor: absent ? _rouge : null,
            foregroundColor: absent ? Colors.white : _rouge,
            side: BorderSide(color: _rouge.withValues(alpha: 0.5)),
          ),
          onPressed: () => _marquer(context, PresencePassager.absent),
          icon: const Icon(Icons.close, size: 18),
        ),
      ],
    );
  }
}
