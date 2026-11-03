// ============================================================
//  MODULE : GESTION DES TRAJETS (Yassine)
//  Fichier : lib/features/trajet/screens/notifications_page.dart
//  Écran : centre de notifications (ouvert par la cloche).
//  Notifications regroupées par jour ; toucher une notification la
//  marque comme lue et ouvre le trajet, sa discussion, la notation
//  ou les avis reçus.
// ============================================================

import 'package:flutter/material.dart';

import '../../../models/notification_trajet.dart';
import '../services/notification_service.dart';
import '../services/trajet_service.dart';
import '../utils/trajet_format.dart';
import '../widgets/acces_discussion.dart';
import '../widgets/evaluation_trajet.dart';
import '../widgets/trajet_card.dart';
import 'alertes_page.dart';
import 'detail_trajet_page.dart';

const Color _rouge = Color(0xFFA3281A);
const Color _vert = Color(0xFF1B7F55);
const Color _ambre = Color(0xFFF5A623);
const Color _orange = Color(0xFFE67E22);

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = NotificationService.instance;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final liste = service.notifications;
        final maintenant = DateTime.now();

        // Regroupement par jour (la liste est déjà de la plus récente
        // à la plus ancienne)
        final parJour = <String, List<NotificationTrajet>>{};
        for (final n in liste) {
          parJour.putIfAbsent(_titreJour(n.date, maintenant), () => []).add(n);
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Notifications'),
            actions: [
              if (service.nonLues > 0)
                TextButton(
                  onPressed: service.toutMarquerLu,
                  child: const Text('Tout lire'),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _LienAlertes(nombre: service.alertes.length),
              if (liste.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: EtatVideTrajet(
                    icone: Icons.notifications_none,
                    titre: 'Aucune notification',
                    message: 'Réservations, rappels de départ, avis\n'
                        'et alertes de recherche arriveront ici.',
                  ),
                ),
              for (final e in parJour.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                  child: Text(e.key.toUpperCase(),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant)),
                ),
                for (final n in e.value)
                  _TuileNotification(notification: n, maintenant: maintenant),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// « Aujourd'hui », « Hier », « lundi 2 nov. »
String _titreJour(DateTime d, DateTime n) {
  final ecart = DateTime(n.year, n.month, n.day)
      .difference(DateTime(d.year, d.month, d.day))
      .inDays;
  if (ecart <= 0) return 'Aujourd’hui';
  if (ecart == 1) return 'Hier';
  return '${tJourSemaine(d)} ${tDateCourte(d)}';
}

/// « à l'instant », « il y a 5 min », « il y a 2 h », sinon l'heure
String _quand(DateTime d, DateTime n) {
  final ecart = n.difference(d);
  if (ecart.inMinutes < 1) return 'à l’instant';
  if (ecart.inMinutes < 60) return 'il y a ${ecart.inMinutes} min';
  if (ecart.inHours < 12) return 'il y a ${ecart.inHours} h';
  return tHeure(d);
}

/// Accès à « Mes alertes » en tête de la liste
class _LienAlertes extends StatelessWidget {
  final int nombre;
  const _LienAlertes({required this.nombre});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AlertesPage())),
          leading: Icon(Icons.notifications_active_outlined, color: cs.primary),
          title: const Text('Alertes de recherche',
              style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(nombre == 0
              ? 'Soyez prévenu des nouveaux trajets'
              : '$nombre alerte(s) active(s)'),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}

class _TuileNotification extends StatelessWidget {
  final NotificationTrajet notification;
  final DateTime maintenant;
  const _TuileNotification(
      {required this.notification, required this.maintenant});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final n = notification;
    final (icone, couleur) = switch (n.type) {
      TypeNotification.reservation => (Icons.event_seat_outlined, cs.primary),
      TypeNotification.annulation => (Icons.event_busy_outlined, _rouge),
      TypeNotification.discussion => (Icons.forum_outlined, cs.primary),
      TypeNotification.depart => (Icons.alarm, _orange),
      TypeNotification.statut => (Icons.directions_car_outlined, cs.primary),
      TypeNotification.evaluation => (Icons.star_outline, _ambre),
      TypeNotification.avis => (Icons.star, _ambre),
      TypeNotification.alerte => (Icons.notifications_active_outlined, _vert),
    };

    return Material(
      color: n.lue ? Colors.transparent : cs.primaryContainer.withValues(alpha: 0.45),
      child: InkWell(
        onTap: () => _ouvrir(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: couleur.withValues(alpha: 0.12),
                child: Icon(icone, size: 20, color: couleur),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(n.titre,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                n.lue ? FontWeight.w600 : FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(n.texte,
                        style: TextStyle(
                            fontSize: 13, color: cs.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text(_quand(n.date, maintenant),
                        style: TextStyle(fontSize: 11, color: cs.outline)),
                  ],
                ),
              ),
              if (!n.lue)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 6),
                  child: CircleAvatar(radius: 4, backgroundColor: cs.primary),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _ouvrir(BuildContext context) {
    final n = notification;
    NotificationService.instance.marquerLue(n);
    if (n.type == TypeNotification.avis) {
      afficherAvisRecus(context);
      return;
    }
    final t =
        n.trajetId == null ? null : TrajetService.instance.parId(n.trajetId!);
    if (t == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ce trajet n’existe plus.')));
      return;
    }
    switch (n.type) {
      case TypeNotification.discussion:
        ouvrirDiscussion(context, t);
      case TypeNotification.evaluation:
        ouvrirEvaluations(context, t);
      default:
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => DetailTrajetPage(trajet: t)));
    }
  }
}
