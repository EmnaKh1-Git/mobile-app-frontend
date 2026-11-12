import 'package:flutter_test/flutter_test.dart';
import 'package:covoiturage_etudiant/features/user/models/user_model.dart';
import 'package:covoiturage_etudiant/features/user/services/biometric_service.dart';

void main() {
  group('Biométrie et UserModel tests', () {
    test('UserModel supporte les champs biométriques par défaut', () {
      const user = UserModel(
        id: 'usr_test_1',
        nom: 'Ben Salah',
        prenom: 'Ahmed',
        email: 'ahmed@esprit.tn',
        telephone: '20123456',
        role: UserRole.conducteur,
      );

      expect(user.biometrieActive, isFalse);
      expect(user.faceEnrolled, isFalse);
      expect(user.fingerprintEnrolled, isFalse);
      expect(user.faceDataPath, isNull);
    });

    test('UserModel sérialisation toMap et fromMap avec biométrie active', () {
      final user = const UserModel(
        id: 'usr_test_bio',
        nom: 'Trabelsi',
        prenom: 'Sarra',
        email: 'sarra@esprit.tn',
        telephone: '50123456',
        role: UserRole.passager,
      ).copyWith(
        biometrieActive: true,
        faceEnrolled: true,
        fingerprintEnrolled: true,
        faceDataPath: '/data/faces/face_123.jpg',
      );

      final map = user.toMap();
      expect(map['biometrieActive'], 1);
      expect(map['faceEnrolled'], 1);
      expect(map['fingerprintEnrolled'], 1);
      expect(map['faceDataPath'], '/data/faces/face_123.jpg');

      final reconstructed = UserModel.fromMap(map);
      expect(reconstructed.biometrieActive, isTrue);
      expect(reconstructed.faceEnrolled, isTrue);
      expect(reconstructed.fingerprintEnrolled, isTrue);
      expect(reconstructed.faceDataPath, '/data/faces/face_123.jpg');
    });

    test('BiometricAuthResult structure', () {
      const result = BiometricAuthResult(
        success: true,
        message: 'Empreinte reconnue avec succès',
        email: 'etudiant@esprit.tn',
        biometricType: 'fingerprint',
      );

      expect(result.success, isTrue);
      expect(result.email, 'etudiant@esprit.tn');
      expect(result.biometricType, 'fingerprint');
    });

    test('BiometricService singleton existe', () {
      final service1 = BiometricService.instance;
      final service2 = BiometricService();
      expect(identical(service1, service2), isTrue);
    });
  });
}

