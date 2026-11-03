// Tests d'affichage de la discussion de trajet et de Mes trajets,
// sur un écran de téléphone (375 x 812).

import 'package:covoiturage_etudiant/core/constants/app_constants.dart';
import 'package:covoiturage_etudiant/features/trajet/screens/detail_trajet_page.dart';
import 'package:covoiturage_etudiant/features/trajet/screens/discussion_trajet_page.dart';
import 'package:covoiturage_etudiant/features/trajet/screens/mes_trajets_page.dart';
import 'package:covoiturage_etudiant/features/trajet/services/discussion_service.dart';
import 'package:covoiturage_etudiant/models/discussion_trajet.dart';
import 'package:covoiturage_etudiant/models/trajet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Trajet trajet(int id, Duration avantDepart) => Trajet(
        id: id,
        conducteurId: monId,
        conducteurNom: monNom,
        villeDepart: 'Tunis',
        adresseDepart: 'Place Barcelone',
        villeArrivee: 'Sousse',
        dateDepart: DateTime.now().add(avantDepart),
        vehicule: 'Peugeot 208',
        placesTotales: 3,
      );

  void ecranTelephone(WidgetTester tester) {
    tester.view.physicalSize = const Size(375 * 3, 812 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('avant l’ouverture : écran verrouillé, pas de saisie',
      (tester) async {
    ecranTelephone(tester);
    await tester.pumpWidget(MaterialApp(
        home: DiscussionTrajetPage(trajet: trajet(900, const Duration(days: 1)))));
    await tester.pump();

    expect(find.text('La discussion n’est pas encore ouverte'), findsOneWidget);
    expect(find.textContaining('Ouverture dans'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('2 h avant : ouverte, un statut rapide arrive dans le fil',
      (tester) async {
    ecranTelephone(tester);
    await tester.pumpWidget(MaterialApp(
        home: DiscussionTrajetPage(
            trajet: trajet(901, const Duration(minutes: 90)))));
    await tester.pumpAndSettle();

    expect(find.textContaining('Discussion ouverte 2 h avant le départ'),
        findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.text('Je suis en route'));
    await tester.pumpAndSettle();
    // La puce + la bulle envoyée
    expect(find.text('Je suis en route'), findsNWidgets(2));

    await tester.enterText(find.byType(TextField), 'Je pars dans 10 minutes');
    await tester.tap(find.byTooltip('Envoyer'));
    await tester.pumpAndSettle();
    expect(find.text('Je pars dans 10 minutes'), findsOneWidget);
  });

  testWidgets('pointage depuis la liste des participants', (tester) async {
    ecranTelephone(tester);
    final t = trajet(902, const Duration(minutes: 90));
    await DiscussionService.instance.ajouterPassager(t.id, 120, 'Lina T.', 1);
    await tester.pumpWidget(MaterialApp(home: DiscussionTrajetPage(trajet: t)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Participants'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Lina T. est à bord'));
    await tester.pumpAndSettle();
    expect(find.text('À bord'), findsNothing); // boutons tant que le pointage est ouvert
    expect(DiscussionService.instance.reservationDe(t.id, 120)?.presence,
        PresencePassager.present);

    // Fermer la liste : l'événement apparaît dans le fil
    await tester.tapAt(const Offset(187, 60));
    await tester.pumpAndSettle();
    expect(find.text('Lina T. est à bord.'), findsOneWidget);
  });

  testWidgets('Mes trajets : trois onglets sans débordement', (tester) async {
    ecranTelephone(tester);
    await tester.pumpWidget(const MaterialApp(home: MesTrajetsPage()));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    Finder onglet(String texte) => find.descendant(
        of: find.byType(TabBar), matching: find.text(texte));
    expect(onglet('À venir'), findsOneWidget);
    expect(onglet('Réservés'), findsOneWidget);
    expect(onglet('Historique'), findsOneWidget);

    // Toucher l'onglet change d'onglet (sans ouvrir le bandeau du
    // prochain départ, juste au-dessus)
    await tester.tap(onglet('Réservés'));
    await tester.pumpAndSettle();
    expect(find.byType(DetailTrajetPage), findsNothing);
    expect(DefaultTabController.of(tester.element(find.byType(TabBar))).index,
        1);
    expect(find.textContaining('Discussion ·'), findsOneWidget);
  });

  testWidgets('Réservés : noter le conducteur d’un trajet terminé',
      (tester) async {
    ecranTelephone(tester);
    await tester.pumpWidget(const MaterialApp(home: MesTrajetsPage()));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    Finder onglet(String texte) => find.descendant(
        of: find.byType(TabBar), matching: find.text(texte));

    await tester.tap(onglet('Réservés'));
    await tester.pumpAndSettle();
    expect(find.text('TERMINÉS'), findsOneWidget);

    final noter = find.widgetWithText(FilledButton, 'Noter');
    await tester.ensureVisible(noter);
    await tester.pumpAndSettle();
    await tester.tap(noter);
    await tester.pumpAndSettle();
    expect(find.textContaining('Comment s’est passé le trajet avec Sami R.'),
        findsOneWidget);

    await tester.tap(find.byTooltip('5 étoiles'));
    await tester.tap(find.text('Conduite sûre'));
    await tester.pump();
    expect(find.text('Excellent'), findsOneWidget);
    await tester.tap(find.text('Envoyer mon avis'));
    await tester.pumpAndSettle();
    expect(find.text('Votre note  '), findsOneWidget);

    // Historique : note moyenne reçue, impact et passagers à noter
    await tester.tap(onglet('Historique'));
    await tester.pumpAndSettle();
    expect(find.textContaining('4.5/5 · 2 avis'), findsOneWidget);
    expect(find.text('Votre impact'), findsOneWidget);
    // Badges : premier trajet, éco-citoyen et conducteur 5★ obtenus
    expect(find.text('Badges · 3/5'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('Noter ('), 200,
        scrollable: find
            .descendant(
                of: find.byKey(const PageStorageKey('historique')),
                matching: find.byType(Scrollable))
            .first);
    expect(find.textContaining('Noter ('), findsOneWidget);
  });
}
