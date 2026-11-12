import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:covoiturage_etudiant/features/user/services/face_recognition_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = FaceRecognitionService.instance;

  group('FaceRecognitionService Multi-Zone Discrimination Tests', () {
    test('Same person photos produce similarity >= 70% (PASSED)', () {
      final rng = Random(42);
      final baseFace = List.generate(256, (i) => sin(i * 0.15) * 0.3 + 0.5);

      final photo1Grid = baseFace.map((v) => (v + (rng.nextDouble() - 0.5) * 0.04).clamp(0.0, 1.0)).toList();
      final photo2Grid = baseFace.map((v) => (v + (rng.nextDouble() - 0.5) * 0.05).clamp(0.0, 1.0)).toList();

      final upperGrid = List.generate(64, (i) => sin(i * 0.2) * 0.3 + 0.5);
      final midGrid = List.generate(64, (i) => cos(i * 0.2) * 0.3 + 0.5);
      final lowerGrid = List.generate(64, (i) => sin(i * 0.3) * 0.3 + 0.5);

      final baseGradients = List.generate(128, (i) => (sin(i * 0.3) > 0 ? 1 : 0));
      final photo1Grad = baseGradients.map((b) => rng.nextDouble() < 0.90 ? b : 1 - b).toList();
      final photo2Grad = baseGradients.map((b) => rng.nextDouble() < 0.88 ? b : 1 - b).toList();

      final sig1 = {
        'luminanceGrid': photo1Grid,
        'upperGrid': upperGrid,
        'midGrid': midGrid,
        'lowerGrid': lowerGrid,
        'skinCb': 125.0,
        'skinCr': 142.0,
        'gradientBits': photo1Grad,
      };

      final sig2 = {
        'luminanceGrid': photo2Grid,
        'upperGrid': upperGrid.map((v) => (v + 0.02).clamp(0.0, 1.0)).toList(),
        'midGrid': midGrid.map((v) => (v - 0.02).clamp(0.0, 1.0)).toList(),
        'lowerGrid': lowerGrid.map((v) => (v + 0.01).clamp(0.0, 1.0)).toList(),
        'skinCb': 126.0,
        'skinCr': 141.0,
        'gradientBits': photo2Grad,
      };

      final similarity = service.computeSimilarity(sig1, sig2);
      expect(similarity, greaterThanOrEqualTo(FaceRecognitionService.matchThreshold));
    });

    test('Different person (colleague) produces similarity < 35% and is REJECTED', () {
      // Profil enregistré (Personne A)
      final gridA = List.generate(256, (i) => sin(i * 0.12) * 0.35 + 0.5);
      final upperA = List.generate(64, (i) => sin(i * 0.18) * 0.3 + 0.5);
      final midA = List.generate(64, (i) => cos(i * 0.18) * 0.3 + 0.5);
      final lowerA = List.generate(64, (i) => sin(i * 0.28) * 0.3 + 0.5);
      final gradA = List.generate(128, (i) => (sin(i * 0.25) > 0 ? 1 : 0));

      // Collègue (Visage différent : yeux, nez et bouche de morphologie différente)
      final gridColleague = List.generate(256, (i) => cos(i * 0.22 + 1.2) * 0.4 + 0.5);
      final upperColleague = List.generate(64, (i) => cos(i * 0.35 + 0.8) * 0.4 + 0.5);
      final midColleague = List.generate(64, (i) => sin(i * 0.4 + 1.1) * 0.4 + 0.5);
      final lowerColleague = List.generate(64, (i) => cos(i * 0.25 + 2.0) * 0.4 + 0.5);
      final gradColleague = List.generate(128, (i) => (cos(i * 0.4 + 0.8) > 0 ? 1 : 0));

      final sigA = {
        'luminanceGrid': gridA,
        'upperGrid': upperA,
        'midGrid': midA,
        'lowerGrid': lowerA,
        'skinCb': 120.0,
        'skinCr': 145.0,
        'gradientBits': gradA,
      };

      final sigColleague = {
        'luminanceGrid': gridColleague,
        'upperGrid': upperColleague,
        'midGrid': midColleague,
        'lowerGrid': lowerColleague,
        'skinCb': 135.0,
        'skinCr': 130.0,
        'gradientBits': gradColleague,
      };

      final similarity = service.computeSimilarity(sigA, sigColleague);
      expect(similarity, lessThan(35.0));
      expect(similarity < FaceRecognitionService.matchThreshold, isTrue);
    });
  });
}
