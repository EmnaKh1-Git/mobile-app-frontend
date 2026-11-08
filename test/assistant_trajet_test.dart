// Tests de l'assistant de recherche (chatbot) du module Trajets.

import 'package:covoiturage_etudiant/features/trajet/services/assistant_trajet.dart';
import 'package:covoiturage_etudiant/models/trajet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final n = DateTime.now();
  final aujourdhui = DateTime(n.year, n.month, n.day);
  DateTime j(int jours, int h, int m) =>
      DateTime(n.year, n.month, n.day + jours, h, m);

  final trajets = [
    Trajet(
      id: 1,
      conducteurId: 2,
      conducteurNom: 'Ahmed B.',
      conducteurNote: 4.8,
      villeDepart: 'Tunis',
      villeArrivee: 'Sousse',
      dateDepart: j(1, 8, 0),
      vehicule: 'Golf',
      placesTotales: 3,
      placesDispo: 2,
      prixPlace: 18,
      etapes: const [Etape(ville: 'Enfidha', ordre: 1, prix: 12)],
    ),
    Trajet(
      id: 2,
      conducteurId: 3,
      conducteurNom: 'Sami R.',
      conducteurNote: 4.2,
      villeDepart: 'Tunis',
      villeArrivee: 'Sousse',
      dateDepart: j(1, 17, 30),
      vehicule: 'Clio',
      placesTotales: 3,
      prixPlace: 14,
    ),
    Trajet(
      id: 3,
      conducteurId: 4,
      conducteurNom: 'Salma K.',
      conducteurNote: 4.9,
      villeDepart: 'Tunis',
      villeArrivee: 'Sfax',
      dateDepart: j(2, 7, 0),
      vehicule: 'Clio',
      placesTotales: 3,
      prixPlace: 30,
      animaux: true,
      reservationAuto: true,
    ),
    Trajet(
      id: 4,
      conducteurId: 5,
      conducteurNom: 'Mehdi T.',
      villeDepart: 'Bizerte',
      villeArrivee: 'Tunis',
      dateDepart: j(1, 6, 45),
      vehicule: 'i10',
      placesTotales: 3,
      placesDispo: 1,
      prixPlace: 9,
    ),
  ];

  AssistantTrajet nouvelAssistant() =>
      AssistantTrajet(prenom: 'Hajer', source: () => trajets);

  test('comprend départ, arrivée, date et moment', () {
    final a = nouvelAssistant();
    final r = a.repondre('De Tunis à Sousse demain matin');
    expect(a.criteres.depart, 'Tunis');
    expect(a.criteres.arrivee, 'Sousse');
    expect(a.criteres.date, aujourdhui.add(const Duration(days: 1)));
    expect(a.criteres.moment, MomentJournee.matin);
    expect(r.trajets.map((t) => t.trajet.id), [1]);
  });

  test('deux villes sans mot-clé : la première est le départ', () {
    final a = nouvelAssistant();
    a.repondre('Tunis → Sousse');
    expect(a.criteres.depart, 'Tunis');
    expect(a.criteres.arrivee, 'Sousse');
  });

  test('« le moins cher » change la recommandation', () {
    final a = nouvelAssistant();
    a.repondre('Tunis Sousse');
    final r = a.repondre('le moins cher');
    expect(a.criteres.priorite, PrioriteAssistant.prix);
    expect(r.trajets.first.trajet.id, 2);
    expect(r.trajets.first.raisons, contains('Le moins cher'));
  });

  test('« le mieux noté » recommande le conducteur le mieux noté', () {
    final a = nouvelAssistant();
    final r = a.repondre('Je pars de Tunis, le mieux noté');
    expect(r.trajets.first.trajet.conducteurNom, 'Salma K.');
    expect(r.trajets.first.raisons.first, 'Conducteur le mieux noté');
  });

  test('budget trop bas : propose une alternative', () {
    final a = nouvelAssistant();
    final r = a.repondre('vers Sfax, moins de 25 DT');
    expect(a.criteres.arrivee, 'Sfax');
    expect(a.criteres.prixMax, 25);
    expect(r.texte, contains('Rien sous 25 DT'));
    expect(r.trajets.single.trajet.id, 3);
  });

  test('places et prix ne se confondent pas', () {
    final a = nouvelAssistant();
    a.repondre('Tunis Sousse, nous sommes 2');
    expect(a.criteres.places, 2);
    expect(a.criteres.prixMax, isNull);
    a.repondre('pas plus de 3 places');
    expect(a.criteres.prixMax, isNull);
  });

  test('« je suis à » et « d’ » indiquent le départ', () {
    final a = nouvelAssistant();
    a.repondre('je suis à Bizerte');
    expect(a.criteres.depart, 'Bizerte');
    a.repondre('d’Hammamet à Tunis');
    expect(a.criteres.depart, 'Hammamet');
    expect(a.criteres.arrivee, 'Tunis');
  });

  test('une étape compte comme destination, au prix de l’étape', () {
    final a = nouvelAssistant();
    final r = a.repondre('Je vais à Enfidha');
    final reco = r.trajets.single;
    expect(reco.trajet.id, 1);
    expect(reco.prix, 12);
    expect(reco.raisons, contains('Dépose à Enfidha'));
  });

  test('jour de la semaine et heure précise', () {
    final a = nouvelAssistant();
    a.repondre('Sousse vendredi vers 18h');
    final ecart = (DateTime.friday - n.weekday + 7) % 7;
    expect(a.criteres.date, aujourdhui.add(Duration(days: ecart)));
    expect(a.criteres.heure, 18);
  });

  test('« peu importe le prix » retire le budget sans changer la priorité', () {
    final a = nouvelAssistant();
    a.repondre('Sousse moins de 10 dt');
    expect(a.criteres.prixMax, 10);
    a.repondre('Peu importe le prix');
    expect(a.criteres.prixMax, isNull);
    expect(a.criteres.priorite, PrioriteAssistant.equilibre);
    expect(a.criteres.dateIndifferente, isFalse);
  });

  test('salutation, message incompris et réinitialisation', () {
    final a = nouvelAssistant();
    expect(a.repondre('Bonjour').texte, startsWith('Bonjour Hajer'));
    expect(a.repondre('blabla').texte, contains('pas bien compris'));
    a.repondre('Tunis Sousse');
    a.repondre('Nouvelle recherche');
    expect(a.criteres.aUneVille, isFalse);
  });

  test('ne propose jamais ses propres trajets à l’utilisateur', () {
    final a = AssistantTrajet(
        prenom: 'Mehdi', utilisateurId: 5, source: () => trajets);
    final r = a.repondre('Je vais à Tunis');
    expect(r.trajets, isEmpty);
    expect(a.accueil().suggestions.map((s) => s.libelle),
        isNot(contains('Bizerte → Tunis')));
  });

  test('normaliser enlève accents et apostrophes courbes', () {
    expect(normaliser('  Gabès   l’Après-midi '), "gabes l'apres-midi");
  });
}
