import 'package:flutter_test/flutter_test.dart';
import 'package:covoiturage_etudiant/core/services/ai_summarize_service.dart';
import 'package:covoiturage_etudiant/features/reclamation/models/reclamation.dart';

void main() {
  group('AiSummarizeService Tests', () {
    test('Reformulation nettoie et structure le texte', () async {
      final input = 'slt svp le cdd nest pas venu pck voiture en panne';
      final output = await AiSummarizeService.instance.reformuler(input);

      expect(output, isNotNull);
      expect(output!.contains('Bonjour'), isTrue);
      expect(output.contains("s'il vous plaît"), isTrue);
      expect(output.contains('conducteur'), isTrue);
      expect(output.endsWith('.'), isTrue);
    });

    test('Texte vide retourne null', () async {
      final res = await AiSummarizeService.instance.reformuler('   ');
      expect(res, isNull);
    });
  });

  group('Reclamation Model Tests', () {
    test('Support des réponses vocales', () {
      final response = ReclamationResponse(
        message: 'Réponse vocale transmise',
        date: DateTime.now(),
        audioPath: 'https://glbpfzacfvkzhxooqsox.supabase.co/storage/v1/object/public/unidrive-uploads/audio/test.m4a',
      );

      expect(response.audioPath, isNotNull);
      expect(response.audioPath!.startsWith('https://'), isTrue);
    });

    test('Labels de type et statut', () {
      final rec = Reclamation(
        id: 101,
        type: ReclamationType.retard,
        sujet: 'Retard important',
        description: 'Conducteur en retard de 30 min',
        trajet: 'Tunis -> Ariana',
        date: DateTime.now(),
        status: ReclamationStatus.enAttente,
      );

      expect(rec.typeLabel, equals('Retard'));
      expect(rec.statusLabel, equals('En attente'));
    });
  });
}

