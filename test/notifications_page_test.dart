// Tests d'affichage du centre de notifications, des alertes et des
// préférences de recherche, sur un écran de téléphone (375 x 812).

import 'package:covoiturage_etudiant/features/trajet/screens/mes_trajets_page.dart';
import 'package:covoiturage_etudiant/features/trajet/screens/notifications_page.dart';
import 'package:covoiturage_etudiant/features/trajet/screens/resultats_trajet_page.dart';
import 'package:covoiturage_etudiant/features/trajet/services/notification_service.dart';
import 'package:covoiturage_etudiant/features/trajet/services/trajet_service.dart';
import 'package:covoiturage_etudiant/features/trajet/widgets/trajet_card.dart';
import 'package:covoiturage_etudiant/models/notification_trajet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  void ecranTelephone(WidgetTester tester) {
    tester.view.physicalSize = const Size(375 * 3, 812 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  /// Laisse le temps aux services de charger la démonstration
  Future<void> charger(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('la cloche de Mes trajets ouvre les notifications de la démo',
      (tester) async {
    ecranTelephone(tester);
    await tester.pumpWidget(const MaterialApp(home: MesTrajetsPage()));
    await charger(tester);

    final nonLues = NotificationService.instance.nonLues;
    expect(nonLues, greaterThan(0));
    await tester.tap(find.byTooltip('Notifications ($nonLues non lues)'));
    await tester.pumpAndSettle();

    expect(find.byType(NotificationsPage), findsOneWidget);
    expect(find.text('Alertes de recherche'), findsOneWidget);
    expect(find.text('AUJOURD’HUI'), findsOneWidget);
    // L'alerte « Tunis → Sousse » de la démo a trouvé le trajet d'Ahmed
    expect(find.text('Trajet trouvé : Tunis → Sousse'), findsOneWidget);
    // Plus bas dans la liste : la discussion du trajet qui part bientôt,
    // le trajet terminé à noter et les avis reçus
    final types = NotificationService.instance.notifications.map((n) => n.type);
    expect(
        types,
        containsAll([
          TypeNotification.reservation,
          TypeNotification.discussion,
          TypeNotification.evaluation,
          TypeNotification.avis,
          TypeNotification.alerte,
        ]));

    await tester.tap(find.text('Tout lire'));
    await tester.pumpAndSettle();
    expect(NotificationService.instance.nonLues, 0);
    expect(find.text('Tout lire'), findsNothing);
  });

  testWidgets('aucun résultat : créer une alerte en un geste', (tester) async {
    ecranTelephone(tester);
    TrajetService.instance; // chargement lancé, terminé par charger(tester)
    await tester.pumpWidget(const MaterialApp(
        home: ResultatsTrajetPage(depart: 'Gafsa', arrivee: 'Tozeur')));
    await charger(tester);

    expect(find.text('Aucun trajet trouvé'), findsOneWidget);
    await tester.tap(find.text('Créer une alerte'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Alerte créée'), findsOneWidget);
    expect(
        NotificationService.instance.alertes
            .any((a) => a.itineraire == 'Gafsa → Tozeur'),
        isTrue);
  });

  testWidgets('préférence « Entre filles » : seulement les trajets concernés',
      (tester) async {
    ecranTelephone(tester);
    TrajetService.instance; // chargement lancé, terminé par charger(tester)
    await tester.pumpWidget(const MaterialApp(
        home: ResultatsTrajetPage(depart: '', arrivee: '')));
    await charger(tester);

    final avant = tester.widgetList(find.byType(TrajetCard)).length;
    await tester.tap(find.widgetWithText(FilterChip, 'Entre filles'));
    await tester.pumpAndSettle();

    final cartes = tester.widgetList<TrajetCard>(find.byType(TrajetCard));
    expect(cartes, isNotEmpty);
    expect(cartes.length, lessThan(avant));
    expect(cartes.every((c) => c.trajet.entreFilles), isTrue);
  });
}
