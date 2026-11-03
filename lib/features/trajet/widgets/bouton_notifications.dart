// ============================================================
//  MODULE : GESTION DES TRAJETS (Yassine)
//  Fichier : lib/features/trajet/widgets/bouton_notifications.dart
//  Cloche des notifications (accueil, Mes trajets) : nombre de
//  notifications non lues, ouvre le centre de notifications.
//  Toutes les 30 s, elle fait vérifier les événements liés à l'heure
//  (discussion qui s'ouvre, départ dans 30 min).
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../screens/notifications_page.dart';
import '../services/notification_service.dart';

class BoutonNotifications extends StatefulWidget {
  /// true : bouton avec contour (accueil) ; false : simple icône (en-tête)
  final bool contour;

  const BoutonNotifications({super.key, this.contour = false});

  @override
  State<BoutonNotifications> createState() => _BoutonNotificationsState();
}

class _BoutonNotificationsState extends State<BoutonNotifications> {
  Timer? _minuteur;

  @override
  void initState() {
    super.initState();
    _minuteur = Timer.periodic(const Duration(seconds: 30), (_) {
      final service = NotificationService.instance;
      if (service.estCharge) service.verifier();
    });
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: NotificationService.instance,
      builder: (context, _) {
        final n = NotificationService.instance.nonLues;
        final icone = Badge(
          isLabelVisible: n > 0,
          label: Text(n > 9 ? '9+' : '$n'),
          backgroundColor: AppColors.accent,
          child: Icon(n > 0 ? Icons.notifications : Icons.notifications_none),
        );
        void ouvrir() => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const NotificationsPage()));
        final tooltip =
            n == 0 ? 'Notifications' : 'Notifications ($n non lues)';
        return widget.contour
            ? IconButton.outlined(
                onPressed: ouvrir, icon: icone, tooltip: tooltip)
            : IconButton(onPressed: ouvrir, icon: icone, tooltip: tooltip);
      },
    );
  }
}
