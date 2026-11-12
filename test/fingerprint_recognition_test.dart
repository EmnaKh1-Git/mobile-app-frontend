import 'package:flutter_test/flutter_test.dart';
import 'package:covoiturage_etudiant/features/user/services/fingerprint_recognition_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = FingerprintRecognitionService.instance;

  group('FingerprintRecognitionService Tests', () {
    test('Same user finger touch samples produce high similarity (> 80%)', () {
      final samplesUserA1 = [
        {'x': 70.0, 'y': 69.5, 'pressure': 0.60, 'size': 0.14, 'radiusMajor': 52.0, 'radiusMinor': 36.0, 'orientation': 0.05},
        {'x': 70.2, 'y': 69.8, 'pressure': 0.62, 'size': 0.145, 'radiusMajor': 53.0, 'radiusMinor': 36.5, 'orientation': 0.06},
        {'x': 69.9, 'y': 69.4, 'pressure': 0.59, 'size': 0.138, 'radiusMajor': 51.5, 'radiusMinor': 35.8, 'orientation': 0.04},
      ];

      final samplesUserA2 = [
        {'x': 70.4, 'y': 70.0, 'pressure': 0.61, 'size': 0.142, 'radiusMajor': 52.5, 'radiusMinor': 36.2, 'orientation': 0.05},
        {'x': 70.1, 'y': 69.6, 'pressure': 0.63, 'size': 0.146, 'radiusMajor': 53.2, 'radiusMinor': 36.8, 'orientation': 0.07},
        {'x': 70.3, 'y': 69.9, 'pressure': 0.58, 'size': 0.139, 'radiusMajor': 51.8, 'radiusMinor': 35.9, 'orientation': 0.04},
      ];

      final sigA1 = service.createSignatureFromSamples(
        samples: samplesUserA1,
        email: 'userA@esprit.tn',
      );
      final sigA2 = service.createSignatureFromSamples(
        samples: samplesUserA2,
        email: 'userA@esprit.tn',
      );

      final similarity = service.compareSignatures(sigA1, sigA2);
      expect(similarity, greaterThanOrEqualTo(80.0));
      expect(similarity >= FingerprintRecognitionService.matchThreshold, isTrue);
    });

    test('Different person (colleague) finger touch samples produce low similarity and are REJECTED (< 75%)', () {
      // User A : large thumb/index, centered
      final samplesUserA = [
        {'x': 70.0, 'y': 70.0, 'pressure': 0.85, 'size': 0.22, 'radiusMajor': 68.0, 'radiusMinor': 46.0, 'orientation': 0.15},
        {'x': 70.2, 'y': 70.3, 'pressure': 0.88, 'size': 0.23, 'radiusMajor': 69.0, 'radiusMinor': 47.0, 'orientation': 0.16},
        {'x': 69.8, 'y': 69.7, 'pressure': 0.84, 'size': 0.21, 'radiusMajor': 67.5, 'radiusMinor': 45.5, 'orientation': 0.14},
      ];

      // Colleague : different position, small finger, light pressure, different account
      final samplesColleague = [
        {'x': 92.0, 'y': 48.0, 'pressure': 0.35, 'size': 0.07, 'radiusMajor': 34.0, 'radiusMinor': 22.0, 'orientation': -0.25},
        {'x': 92.5, 'y': 48.4, 'pressure': 0.38, 'size': 0.08, 'radiusMajor': 35.0, 'radiusMinor': 23.0, 'orientation': -0.22},
        {'x': 91.8, 'y': 47.6, 'pressure': 0.34, 'size': 0.065, 'radiusMajor': 33.5, 'radiusMinor': 21.5, 'orientation': -0.26},
      ];

      final sigA = service.createSignatureFromSamples(
        samples: samplesUserA,
        email: 'userA@esprit.tn',
      );
      final sigColleague = service.createSignatureFromSamples(
        samples: samplesColleague,
        email: 'collegue@esprit.tn',
      );

      final similarity = service.compareSignatures(sigA, sigColleague);
      expect(similarity, lessThan(FingerprintRecognitionService.matchThreshold));
      expect(similarity < 75.0, isTrue);
    });

    test('Signature JSON serialization and deserialization preserves all values', () {
      final samples = [
        {'x': 72.5, 'y': 68.0, 'pressure': 0.55, 'size': 0.12, 'radiusMajor': 48.0, 'radiusMinor': 32.0, 'orientation': 0.02},
      ];
      final original = service.createSignatureFromSamples(
        samples: samples,
        email: 'test@unidrive.tn',
      );

      final jsonString = original.toJson();
      final restored = FingerprintSignature.fromJson(jsonString);

      expect(restored.accountEmail, equals('test@unidrive.tn'));
      expect(restored.meanPressure, closeTo(original.meanPressure, 0.001));
      expect(restored.meanRadiusMajor, closeTo(original.meanRadiusMajor, 0.001));
      expect(restored.meanRadiusMinor, closeTo(original.meanRadiusMinor, 0.001));
      expect(restored.meanX, closeTo(original.meanX, 0.001));
      expect(restored.meanY, closeTo(original.meanY, 0.001));
    });

    test('Uniqueness check: same finger on second account is detected (> 75%) to prevent duplicates', () {
      final samplesUserA = [
        {'x': 70.0, 'y': 69.5, 'pressure': 0.60, 'size': 0.14, 'radiusMajor': 52.0, 'radiusMinor': 36.0, 'orientation': 0.05},
        {'x': 70.2, 'y': 69.8, 'pressure': 0.62, 'size': 0.145, 'radiusMajor': 53.0, 'radiusMinor': 36.5, 'orientation': 0.06},
      ];
      final samplesNewAccountAttempt = [
        {'x': 70.3, 'y': 69.7, 'pressure': 0.61, 'size': 0.142, 'radiusMajor': 52.5, 'radiusMinor': 36.2, 'orientation': 0.05},
        {'x': 70.1, 'y': 69.6, 'pressure': 0.59, 'size': 0.141, 'radiusMajor': 51.9, 'radiusMinor': 35.9, 'orientation': 0.04},
      ];

      final sigRegistered = service.createSignatureFromSamples(
        samples: samplesUserA,
        email: 'existing_account@esprit.tn',
      );
      final sigCandidate = service.createSignatureFromSamples(
        samples: samplesNewAccountAttempt,
        email: 'new_account@esprit.tn',
      );

      // Without account binding enforcement, physical comparison detects that it is the SAME finger
      final similarity = service.compareSignatures(sigRegistered, sigCandidate, enforceAccountBinding: false);
      expect(similarity, greaterThanOrEqualTo(FingerprintRecognitionService.matchThreshold));
    });
  });
}
