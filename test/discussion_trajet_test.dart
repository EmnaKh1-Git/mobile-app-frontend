// Tests de la discussion de trajet (conducteur + passagers) du module Trajets.

import 'package:covoiturage_etudiant/core/constants/app_constants.dart';
import 'package:covoiturage_etudiant/features/trajet/services/discussion_service.dart';
import 'package:covoiturage_etudiant/models/discussion_trajet.dart';
import 'package:covoiturage_etudiant/models/trajet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final depart = DateTime(2026, 11, 20, 8, 30);

  Trajet trajet({
    int id = 1,
    int conducteurId = monId,
    DateTime? date,
    StatutTrajet statut = StatutTrajet.publie,
    int placesTotales = 3,
    int? placesDispo,
  }) =>
      Trajet(
        id: id,
        conducteurId: conducteurId,
        conducteurNom: conducteurId == monId ? monNom : 'Ahmed B.',
        villeDepart: 'Tunis',
        adresseDepart: 'Place Barcelone',
        villeArrivee: 'Sousse',
        dateDepart: date ?? depart,
        vehicule: 'Golf',
        placesTotales: placesTotales,
        placesDispo: placesDispo,
        statut: statut,
      );

  group('ouverture 2 h avant le départ', () {
    test('verrouillée avant, ouverte à partir de 2 h avant', () {
      final t = trajet();
      expect(
          etatDiscussion(t, maintenant: DateTime(2026, 11, 20, 6, 29)),
          EtatDiscussion.verrouillee);
      expect(etatDiscussion(t, maintenant: DateTime(2026, 11, 20, 6, 30)),
          EtatDiscussion.ouverte);
      expect(ouvertureDiscussion(t), DateTime(2026, 11, 20, 6, 30));
    });

    test('ouverte pendant le trajet, lecture seule après', () {
      final avant = DateTime(2026, 11, 19);
      expect(
          etatDiscussion(trajet(statut: StatutTrajet.enCours),
              maintenant: avant),
          EtatDiscussion.ouverte);
      expect(etatDiscussion(trajet(statut: StatutTrajet.termine)),
          EtatDiscussion.lectureSeule);
      expect(etatDiscussion(trajet(statut: StatutTrajet.annule)),
          EtatDiscussion.lectureSeule);
    });
  });

  group('envoi de messages', () {
    late DiscussionService service;
    final t = trajet();
    final ouvert = DateTime(2026, 11, 20, 7, 0);

    setUp(() async {
      service = DiscussionService.enMemoire();
      await service.ajouterPassager(t.id, 10, 'Amira S.', 1);
    });

    test('refusé tant que la discussion est verrouillée', () async {
      final erreur = await service.envoyer(t,
          auteurId: monId,
          auteurNom: monNom,
          texte: 'Bonjour',
          maintenant: DateTime(2026, 11, 20, 5, 0));
      expect(erreur, contains('s’ouvrira'));
      expect(service.messages(t.id), isEmpty);
    });

    test('ouverte : message d’ouverture puis le message', () async {
      final erreur = await service.envoyer(t,
          auteurId: monId,
          auteurNom: monNom,
          texte: '  Je suis en route  ',
          type: TypeMessageTrajet.statut,
          maintenant: ouvert);
      expect(erreur, isNull);
      final messages = service.messages(t.id);
      expect(messages.map((m) => m.type),
          [TypeMessageTrajet.systeme, TypeMessageTrajet.statut]);
      expect(messages.first.texte, contains('Place Barcelone'));
      expect(messages.last.texte, 'Je suis en route');
    });

    test('réservé au conducteur et aux passagers', () async {
      final erreur = await service.envoyer(t,
          auteurId: 99, auteurNom: 'Inconnu', texte: 'Salut', maintenant: ouvert);
      expect(erreur, contains('Seuls le conducteur et les passagers'));
      expect(
          await service.envoyer(t,
              auteurId: 10,
              auteurNom: 'Amira S.',
              texte: 'J’arrive',
              maintenant: ouvert),
          isNull);
    });

    test('message vide, trop long ou trajet terminé : refusé', () async {
      expect(
          await service.envoyer(t,
              auteurId: monId, auteurNom: monNom, texte: '   ', maintenant: ouvert),
          'Le message est vide.');
      expect(
          await service.envoyer(t,
              auteurId: monId,
              auteurNom: monNom,
              texte: 'a' * (longueurMaxMessage + 1),
              maintenant: ouvert),
          contains('trop long'));
      expect(
          await service.envoyer(trajet(statut: StatutTrajet.termine),
              auteurId: monId, auteurNom: monNom, texte: 'Merci'),
          contains('lecture seule'));
    });

    test('messages non lus des autres participants', () async {
      await service.envoyer(t,
          auteurId: 10,
          auteurNom: 'Amira S.',
          texte: 'Bonjour !',
          maintenant: ouvert);
      expect(service.nonLus(t.id), 1);
      await service.envoyer(t,
          auteurId: monId,
          auteurNom: monNom,
          texte: 'Bonjour Amira',
          maintenant: ouvert.add(const Duration(minutes: 1)));
      // Répondre marque la discussion comme lue
      expect(service.nonLus(t.id), 0);
    });
  });

  group('passagers', () {
    test('une réservation s’ajoute, se réduit puis disparaît', () async {
      final service = DiscussionService.enMemoire();
      final t = trajet(conducteurId: 2);
      await service.ajouterPassager(t.id, monId, monNom, 1);
      await service.ajouterPassager(t.id, monId, monNom, 1);
      expect(service.reservationDe(t.id, monId)?.places, 2);
      expect(service.estParticipant(t, monId), isTrue);
      expect(service.trajetsReserves(monId), {t.id});

      await service.retirerPassager(t.id, monId, 1);
      expect(service.reservationDe(t.id, monId)?.places, 1);
      await service.retirerPassager(t.id, monId, 1);
      expect(service.estParticipant(t, monId), isFalse);
    });

    test('démarrage, suppression : messages système et nettoyage', () async {
      final service = DiscussionService.enMemoire();
      final t = trajet(statut: StatutTrajet.enCours);
      await service.ajouterPassager(t.id, 10, 'Amira S.', 1);
      await service.signalerStatut(t, StatutTrajet.enCours);
      expect(service.messages(t.id).last.texte, contains('a démarré le trajet'));

      await service.supprimerTrajet(t.id);
      expect(service.messages(t.id), isEmpty);
      expect(service.passagers(t.id), isEmpty);
    });
  });

  group('pointage au départ', () {
    late DiscussionService service;
    final t = trajet();
    final ouvert = DateTime(2026, 11, 20, 8, 0);

    setUp(() async {
      service = DiscussionService.enMemoire();
      await service.ajouterPassager(t.id, 10, 'Amira S.', 1);
      await service.ajouterPassager(t.id, 11, 'Youssef M.', 1);
    });

    test('possible 2 h avant, par le conducteur seulement', () async {
      expect(
          await service.marquerPresence(t, 10, PresencePassager.present,
              maintenant: DateTime(2026, 11, 20, 5, 0)),
          'Le pointage s’ouvre 2 h avant le départ.');
      expect(
          await service.marquerPresence(t, 10, PresencePassager.present,
              auteurId: 11, maintenant: ouvert),
          contains('Seul le conducteur'));
    });

    test('présent : annoncé dans la discussion, bilan à jour', () async {
      expect(
          await service.marquerPresence(t, 10, PresencePassager.present,
              maintenant: ouvert),
          isNull);
      await service.marquerPresence(t, 11, PresencePassager.absent,
          maintenant: ouvert);
      expect(service.reservationDe(t.id, 10)?.presence,
          PresencePassager.present);
      expect(service.messages(t.id).last.texte, 'Amira S. est à bord.');
      expect(service.bilanPresence(t.id),
          (presents: 1, absents: 1, restants: 0));
    });

    test('fermé une fois le trajet terminé', () async {
      expect(
          await service.marquerPresence(trajet(statut: StatutTrajet.termine),
              10, PresencePassager.absent),
          contains('pointage est fermé'));
    });
  });

  group('annulation par le passager', () {
    test('jusqu’à 30 min avant le départ', () async {
      final service = DiscussionService.enMemoire();
      final t = trajet(conducteurId: 2);
      await service.ajouterPassager(t.id, monId, monNom, 1);

      expect(
          service.motifRefusAnnulation(t, monId,
              maintenant: DateTime(2026, 11, 20, 7, 30)),
          isNull);
      expect(
          service.motifRefusAnnulation(t, monId,
              maintenant: DateTime(2026, 11, 20, 8, 10)),
          contains('Trop tard'));
      expect(
          service.motifRefusAnnulation(
              trajet(conducteurId: 2, statut: StatutTrajet.enCours), monId),
          contains('ne peut plus être annulée'));
      expect(service.motifRefusAnnulation(t, 99), contains('pas de réservation'));
    });

    test('annoncée dans la discussion seulement si elle est ouverte', () async {
      final service = DiscussionService.enMemoire();
      final bientot = trajet(
          id: 1, date: DateTime.now().add(const Duration(hours: 1)));
      final demain = trajet(
          id: 2, date: DateTime.now().add(const Duration(days: 1)));
      await service.annoncerAnnulation(bientot, 'Amira S.');
      await service.annoncerAnnulation(demain, 'Amira S.');
      expect(service.messages(bientot.id).last.texte,
          'Amira S. a annulé sa réservation.');
      expect(service.messages(demain.id), isEmpty);
    });
  });

  group('évaluations après le trajet', () {
    late DiscussionService service;
    final termine = trajet(statut: StatutTrajet.termine);

    setUp(() async {
      service = DiscussionService.enMemoire();
      // Amira présente, Youssef absent (pointage fait pendant le trajet)
      final enCours = trajet(statut: StatutTrajet.enCours);
      await service.ajouterPassager(enCours.id, 10, 'Amira S.', 1);
      await service.ajouterPassager(enCours.id, 11, 'Youssef M.', 1);
      await service.marquerPresence(enCours, 10, PresencePassager.present);
      await service.marquerPresence(enCours, 11, PresencePassager.absent);
    });

    test('seulement une fois le trajet terminé', () async {
      expect(
          await service.evaluer(trajet(),
              auteurId: monId, auteurNom: monNom, cibleId: 10, note: 5),
          contains('une fois le trajet terminé'));
    });

    test('le conducteur note les passagers présents, une seule fois',
        () async {
      expect(service.aNoter(termine, monId).map((c) => c.id), [10]);
      expect(
          await service.evaluer(termine,
              auteurId: monId, auteurNom: monNom, cibleId: 11, note: 5),
          contains('participants présents'));
      expect(
          await service.evaluer(termine,
              auteurId: monId, auteurNom: monNom, cibleId: 10, note: 6),
          contains('entre 1 et 5'));
      expect(
          await service.evaluer(termine,
              auteurId: monId, auteurNom: monNom, cibleId: 10, note: 5,
              commentaire: ' Ponctuelle '),
          isNull);
      expect(service.aNoter(termine, monId), isEmpty);
      expect(
          await service.evaluer(termine,
              auteurId: monId, auteurNom: monNom, cibleId: 10, note: 4),
          contains('déjà noté'));
      expect(service.evaluation(termine.id, monId, 10)?.commentaire,
          'Ponctuelle');
    });

    test('les passagers présents notent le conducteur : moyenne', () async {
      expect(
          await service.evaluer(termine,
              auteurId: 10, auteurNom: 'Amira S.', cibleId: monId, note: 4),
          isNull);
      // Absent : ne peut pas noter
      expect(service.aNoter(termine, 11), isEmpty);
      expect(
          await service.evaluer(termine,
              auteurId: 11, auteurNom: 'Youssef M.', cibleId: monId, note: 1),
          contains('participants présents'));
      expect(service.noteMoyenne(monId), (moyenne: 4.0, nombre: 1));
      expect(
          await service.evaluer(termine,
              auteurId: monId, auteurNom: monNom, cibleId: monId, note: 5),
          contains('vous noter vous-même'));
    });
  });

  test('démo : passagers des trajets réservés et discussion déjà ouverte',
      () async {
    final n = DateTime.now();
    final bientot = trajet(
        id: 1, date: n.add(const Duration(minutes: 75)), placesDispo: 1);
    final autre = trajet(
        id: 2,
        conducteurId: 2,
        date: n.add(const Duration(days: 1)),
        placesDispo: 2);
    final service = DiscussionService.enMemoire();
    await service.charger([bientot, autre]);

    // Les places déjà réservées ont des passagers
    expect(service.passagers(bientot.id).fold<int>(0, (s, p) => s + p.places), 2);
    // L'utilisateur est passager du trajet d'un autre conducteur
    expect(service.reservationDe(autre.id, monId), isNotNull);
    // Discussion ouverte (départ dans 1 h 15) : ouverture + 2 messages
    expect(service.messages(bientot.id).length, 3);
    expect(service.nonLus(bientot.id), 2);
    // Trajet de demain : discussion verrouillée, pas de message
    expect(service.messages(autre.id), isEmpty);
  });

  test('démo : trajets terminés pointés, notes reçues, conducteur à noter',
      () async {
    final n = DateTime.now();
    final monTermine = trajet(
        id: 1,
        date: n.subtract(const Duration(days: 5)),
        statut: StatutTrajet.termine,
        placesTotales: 4,
        placesDispo: 0);
    final autreTermine = trajet(
        id: 2,
        conducteurId: 8,
        date: n.subtract(const Duration(days: 3)),
        statut: StatutTrajet.termine,
        placesDispo: 1);
    final service = DiscussionService.enMemoire();
    await service.charger([monTermine, autreTermine]);

    expect(service.passagers(monTermine.id).map((p) => p.presence).toSet(),
        {PresencePassager.present});
    expect(service.noteMoyenne(monId), (moyenne: 4.5, nombre: 2));
    // L'utilisateur était passager de l'autre trajet : il peut le noter
    expect(service.aNoter(autreTermine, monId).single.id, 8);
  });
}
