// Tests du centre de notifications, des alertes de recherche, des
// trajets réguliers, des préférences et du bilan d'impact (module Trajets).

import 'package:covoiturage_etudiant/core/constants/app_constants.dart';
import 'package:covoiturage_etudiant/features/trajet/services/assistant_trajet.dart';
import 'package:covoiturage_etudiant/features/trajet/services/bilan_impact.dart';
import 'package:covoiturage_etudiant/features/trajet/services/discussion_service.dart';
import 'package:covoiturage_etudiant/features/trajet/services/notification_service.dart';
import 'package:covoiturage_etudiant/features/trajet/services/trajet_service.dart';
import 'package:covoiturage_etudiant/models/discussion_trajet.dart';
import 'package:covoiturage_etudiant/models/notification_trajet.dart';
import 'package:covoiturage_etudiant/models/trajet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final maintenant = DateTime(2026, 11, 20, 8, 0);

  Trajet trajet(
    int id, {
    int conducteurId = monId,
    String depart = 'Tunis',
    String arrivee = 'Sousse',
    DateTime? date,
    StatutTrajet statut = StatutTrajet.publie,
    int placesTotales = 3,
    int? placesDispo,
    List<Etape>? etapes,
  }) =>
      Trajet(
        id: id,
        conducteurId: conducteurId,
        conducteurNom: conducteurId == monId ? monNom : 'Ahmed B.',
        villeDepart: depart,
        villeArrivee: arrivee,
        dateDepart: date ?? maintenant.add(const Duration(days: 1)),
        dureeMinutes: 60,
        vehicule: 'Golf',
        placesTotales: placesTotales,
        placesDispo: placesDispo,
        prixPlace: 10,
        distanceKm: 100,
        statut: statut,
        etapes: etapes,
      );

  late DiscussionService discussions;
  late List<Trajet> trajets;
  late NotificationService service;

  setUp(() {
    discussions = DiscussionService.enMemoire();
    trajets = [];
    service = NotificationService.enMemoire(() => trajets, discussions);
  });

  Iterable<String> cles() => service.notifications.map((n) => n.cle);

  group('notifications déduites des trajets', () {
    test('réservation, discussion ouverte puis rappel 30 min avant', () async {
      final t = trajet(1,
          date: maintenant.add(const Duration(minutes: 90)), placesDispo: 2);
      trajets.add(t);
      await discussions.ajouterPassager(1, 120, 'Lina T.', 1);

      await service.verifier(maintenant: maintenant);
      expect(cles(), containsAll(['reservation:1:120', 'discussion:1']));
      expect(cles(), isNot(contains('depart:1')));
      final reservation =
          service.notifications.firstWhere((n) => n.cle == 'reservation:1:120');
      expect(reservation.titre, 'Nouvelle réservation');
      expect(reservation.texte, startsWith('Lina T. a réservé 1 place'));

      await service.verifier(
          maintenant: maintenant.add(const Duration(minutes: 65)));
      expect(cles(), contains('depart:1'));

      // Une même notification n'est jamais créée deux fois
      final nombre = service.notifications.length;
      await service.verifier(
          maintenant: maintenant.add(const Duration(minutes: 70)));
      expect(service.notifications.length, nombre);
    });

    test('lues une par une ou toutes d’un coup', () async {
      final t = trajet(1, date: maintenant.add(const Duration(minutes: 90)));
      trajets.add(t);
      await discussions.ajouterPassager(1, 120, 'Lina T.', 1);
      await service.verifier(maintenant: maintenant);
      expect(service.nonLues, 2);

      await service.marquerLue(service.notifications.first);
      expect(service.nonLues, 1);
      await service.toutMarquerLu();
      expect(service.nonLues, 0);
    });

    test('passager : réservation confirmée, trajet démarré puis annulé',
        () async {
      final t = trajet(2, conducteurId: 2, placesDispo: 2);
      trajets.add(t);
      await discussions.ajouterPassager(2, monId, monNom, 1);
      await service.verifier(maintenant: maintenant);
      expect(service.notifications.single.titre, 'Réservation confirmée');

      trajets[0] = t.copyWith(statut: StatutTrajet.enCours);
      await service.verifier(maintenant: maintenant);
      expect(cles(), contains('statut:2:enCours'));

      trajets[0] = t.copyWith(statut: StatutTrajet.annule);
      await service.verifier(maintenant: maintenant);
      expect(cles(), contains('statut:2:annule'));
    });

    test('aucune notification pour le trajet d’un autre sans réservation',
        () async {
      trajets.add(trajet(3,
          conducteurId: 2, date: maintenant.add(const Duration(minutes: 20))));
      await service.verifier(maintenant: maintenant);
      expect(service.notifications, isEmpty);
    });

    test('trajet terminé à noter (7 jours) et nouvel avis reçu', () async {
      final recent = trajet(4,
          date: maintenant.subtract(const Duration(days: 2)),
          statut: StatutTrajet.termine,
          placesDispo: 2);
      final ancien = trajet(5,
          date: maintenant.subtract(const Duration(days: 30)),
          statut: StatutTrajet.termine,
          placesDispo: 2);
      trajets.addAll([recent, ancien]);
      await discussions.ajouterPassager(4, 120, 'Lina T.', 1);
      await discussions.ajouterPassager(5, 121, 'Omar F.', 1);

      await service.verifier(maintenant: maintenant);
      expect(cles(), contains('evaluation:4'));
      expect(cles(), isNot(contains('evaluation:5')));

      // Lina note le conducteur : l'avis arrive dans les notifications
      await discussions.evaluer(recent,
          auteurId: 120, auteurNom: 'Lina T.', cibleId: monId, note: 5,
          commentaire: 'Très ponctuel');
      await service.verifier(maintenant: DateTime.now());
      final avis =
          service.notifications.firstWhere((n) => n.type == TypeNotification.avis);
      expect(avis.titre, 'Nouvel avis : 5/5');
      expect(avis.texte, 'Lina T. : « Très ponctuel »');
    });

    test('annulation d’un passager signalée au conducteur seulement',
        () async {
      final mien = trajet(6);
      final autre = trajet(7, conducteurId: 2);
      final lina = PassagerTrajet(
          trajetId: 6, passagerId: 120, nom: 'Lina T.', places: 2);

      await service.signalerAnnulation(mien, lina, maintenant: maintenant);
      final n = service.notifications.single;
      expect(n.type, TypeNotification.annulation);
      expect(n.texte, startsWith('Lina T. a annulé (2 places libérées)'));

      await service.signalerAnnulation(autre, lina, maintenant: maintenant);
      await service.signalerAnnulation(
          mien,
          PassagerTrajet(trajetId: 6, passagerId: monId, nom: monNom, places: 1),
          maintenant: maintenant);
      expect(service.notifications.length, 1);
    });

    test('trajet supprimé : ses notifications disparaissent', () async {
      trajets.add(trajet(8, date: maintenant.add(const Duration(minutes: 90))));
      await discussions.ajouterPassager(8, 120, 'Lina T.', 1);
      await service.verifier(maintenant: maintenant);
      expect(service.notifications, isNotEmpty);
      await service.supprimerTrajet(8);
      expect(service.notifications, isEmpty);
    });
  });

  group('alertes de recherche', () {
    test('règles : une ville, pas de date passée, pas de doublon', () async {
      expect(await service.creerAlerte(maintenant: maintenant),
          'Indiquez au moins la ville de départ ou d’arrivée.');
      expect(
          await service.creerAlerte(
              arrivee: 'Sousse',
              jour: DateTime(2026, 11, 19),
              maintenant: maintenant),
          'Cette date est déjà passée.');
      expect(
          await service.creerAlerte(
              depart: 'Tunis', arrivee: 'Sousse', maintenant: maintenant),
          isNull);
      expect(
          await service.creerAlerte(
              depart: 'tunis', arrivee: 'SOUSSE', maintenant: maintenant),
          'Vous avez déjà une alerte pour ce trajet.');
      expect(service.alertes.single.itineraire, 'Tunis → Sousse');

      await service.supprimerAlerte(service.alertes.single);
      expect(service.alertes, isEmpty);
    });

    test('un trajet correspondant d’un autre conducteur est signalé',
        () async {
      trajets.addAll([
        trajet(10, conducteurId: 2), // Tunis → Sousse, Ahmed
        trajet(11), // mon propre trajet : ignoré
        trajet(12, conducteurId: 2, arrivee: 'Sfax'), // autre destination
      ]);
      await service.creerAlerte(
          depart: 'Tunis', arrivee: 'Sousse', maintenant: maintenant);

      final n = service.notifications.single;
      expect(n.type, TypeNotification.alerte);
      expect(n.trajetId, 10);
      expect(n.titre, 'Trajet trouvé : Tunis → Sousse');
      expect(n.texte, contains('Ahmed B. part demain'));

      // Nouveau trajet publié plus tard : signalé lui aussi
      trajets.add(trajet(13, conducteurId: 2, date: maintenant.add(const Duration(days: 3))));
      await service.verifier(maintenant: maintenant);
      expect(cles(), contains('alerte:${service.alertes.single.id}:13'));
    });

    test('correspondance : sans accents, étape, jour, heure et places', () {
      final a = AlerteTrajet(id: 1, villeDepart: 'Tunis', villeArrivee: 'Gabes');
      expect(NotificationService.correspond(a, trajet(1, arrivee: 'Gabès')), isTrue);
      expect(
          NotificationService.correspond(
              a,
              trajet(2,
                  arrivee: 'Médenine',
                  etapes: const [Etape(ville: 'Gabès', ordre: 1, prix: 20)])),
          isTrue);

      final demain8h = DateTime(2026, 11, 21, 8, 0);
      final soir = trajet(3, date: DateTime(2026, 11, 21, 18, 30));
      expect(
          NotificationService.correspond(
              AlerteTrajet(id: 2, villeArrivee: 'Sousse', jour: DateTime(2026, 11, 21), heure: 8),
              trajet(4, date: demain8h)),
          isTrue);
      expect(
          NotificationService.correspond(
              AlerteTrajet(id: 3, villeArrivee: 'Sousse', heure: 8), soir),
          isFalse);
      expect(
          NotificationService.correspond(
              AlerteTrajet(id: 4, villeArrivee: 'Sousse', moment: MomentJournee.soir.name),
              soir),
          isTrue);
      expect(
          NotificationService.correspond(
              AlerteTrajet(id: 5, villeArrivee: 'Sousse', places: 3),
              trajet(5, placesDispo: 2)),
          isFalse);
    });
  });

  group('trajets réguliers', () {
    test('dates : les jours choisis pendant N semaines, même heure', () {
      final lundi = DateTime(2026, 11, 9, 7, 45);
      expect(lundi.weekday, DateTime.monday);

      final semaine = datesSerie(lundi, {1, 2, 3, 4, 5}, 2);
      expect(semaine.length, 10);
      expect(semaine.first, lundi);
      expect(semaine.last, DateTime(2026, 11, 20, 7, 45));
      expect(semaine.every((d) => d.weekday <= 5 && d.hour == 7 && d.minute == 45),
          isTrue);

      expect(datesSerie(lundi, {DateTime.wednesday}, 4), [
        DateTime(2026, 11, 11, 7, 45),
        DateTime(2026, 11, 18, 7, 45),
        DateTime(2026, 11, 25, 7, 45),
        DateTime(2026, 12, 2, 7, 45),
      ]);
      expect(datesSerie(lundi, {}, 4), isEmpty);
    });

    test('publiés dans la même série, la suite s’annule d’un coup', () async {
      final service = TrajetService.instance;
      await service.charger();
      final n = DateTime.now();
      final premier = DateTime(n.year, n.month, n.day + 20, 6, 10);
      final modele = Trajet(
        id: 0,
        conducteurId: monId,
        conducteurNom: monNom,
        villeDepart: 'La Marsa',
        villeArrivee: 'Ariana',
        dateDepart: premier,
        vehicule: 'Peugeot 208',
        placesTotales: 3,
        distanceKm: 14,
        prixPlace: 3,
        entreFilles: true,
      );
      final dates = datesSerie(premier, {1, 2, 3, 4, 5, 6, 7}, 1);
      final res = await service.publierSerie(modele, dates);
      expect(res.publies, 7);
      expect(res.refus, isEmpty);

      final serie = service.tous.where((t) => t.villeDepart == 'La Marsa').toList();
      expect(serie.length, 7);
      expect(serie.map((t) => t.serieId).toSet().length, 1);
      expect(serie.every((t) => t.estRegulier && t.entreFilles), isTrue);

      // Une date en conflit avec un trajet de la série est refusée
      final conflit = await service.publierSerie(modele, [dates.first]);
      expect(conflit.publies, 0);
      expect(conflit.refus.single,
          contains('Vous avez déjà un trajet prévu à cette heure-là.'));

      // Annuler à partir du 3e : les 5 derniers sont annulés
      final troisieme = service.prochainsDeSerie(serie.first.serieId!)[2];
      expect(await service.annulerSerie(troisieme), 5);
      expect(service.prochainsDeSerie(serie.first.serieId!).length, 2);

      // « Dupliquer » sort le trajet de la série
      await service.dupliquer(serie.first);
      final copie = service.tous.where((t) =>
          t.villeDepart == 'La Marsa' &&
          t.dateDepart == premier.add(const Duration(days: 7)));
      expect(copie.single.estRegulier, isFalse);
    });
  });

  test('recherche : filtres de préférences', () async {
    final service = TrajetService.instance;
    await service.charger();
    final filles = service.rechercher(entreFilles: true);
    expect(filles, isNotEmpty);
    expect(filles.every((t) => t.entreFilles), isTrue);
    expect(service.rechercher(animaux: true).every((t) => t.animaux), isTrue);
    expect(service.rechercher(nonFumeur: true).every((t) => !t.fumeur), isTrue);
  });

  test('bilan : km partagés, CO₂ évité, gains, économies et badges', () {
    final conduit = trajet(1, statut: StatutTrajet.termine, placesDispo: 0); // 3 passagers
    final seul = trajet(2, statut: StatutTrajet.termine); // aucun passager
    final passager = trajet(3, conducteurId: 2, statut: StatutTrajet.termine);

    final b = calculerBilan(
      commeConducteur: [conduit, seul],
      commePassager: [(trajet: passager, places: 1)],
      note: (moyenne: 4.5, nombre: 2),
    );
    expect(b.trajets, 2); // le trajet sans passager ne compte pas
    expect(b.kmPartages, 200);
    expect(b.co2Evite, closeTo(100 * 3 * co2ParKm + 100 * co2ParKm, 0.001));
    expect(b.gagne, 30);
    expect(b.economise, closeTo(100 * coutVoitureParKm - 10, 0.001));
    expect(b.arbres, 2);

    bool obtenu(TypeBadge t) => b.badges.firstWhere((x) => x.type == t).obtenu;
    expect(obtenu(TypeBadge.premierTrajet), isTrue);
    expect(obtenu(TypeBadge.habitue), isFalse);
    expect(obtenu(TypeBadge.ecoCitoyen), isFalse); // 48 kg < 50 kg
    expect(obtenu(TypeBadge.conducteurEtoile), isTrue);
    expect(
        calculerBilan(
                commeConducteur: const [],
                commePassager: const [],
                note: (moyenne: 5, nombre: 1))
            .badges
            .every((x) => !x.obtenu),
        isTrue);
  });
}
