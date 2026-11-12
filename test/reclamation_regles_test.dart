import 'package:covoiturage_etudiant/features/reclamation/models/reclamation.dart';
import 'package:covoiturage_etudiant/features/reclamation/services/reclamation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('workflow : transitions autorisées', () {
    expect(
      ReclamationStatus.enAttente.transitionsAutorisees,
      isNot(contains(ReclamationStatus.resolue)),
    );
    expect(
      ReclamationStatus.resolue.transitionsAutorisees,
      {ReclamationStatus.enCours},
    );
  });

  test('SLA : urgente en retard après 6 h', () {
    final r = Reclamation(
      id: 1,
      type: ReclamationType.conducteur,
      sujet: 'x',
      description: 'y',
      trajet: 't',
      date: DateTime.now().subtract(const Duration(hours: 7)),
      status: ReclamationStatus.enAttente,
      priorite: ReclamationPriorite.urgente,
    );
    expect(r.estEnRetard, isTrue);
    expect(r.copyWith(status: ReclamationStatus.resolue).estEnRetard, isFalse);
  });

  test('priorité estimée', () {
    expect(
      ReclamationService.prioriteEstimee(
        ReclamationType.conducteur,
        'Il roulait à une vitesse excessive, j’avais peur',
      ),
      ReclamationPriorite.urgente,
    );
    expect(
      ReclamationService.prioriteEstimee(ReclamationType.paiement, 'payé 2 fois'),
      ReclamationPriorite.haute,
    );
  });
}
