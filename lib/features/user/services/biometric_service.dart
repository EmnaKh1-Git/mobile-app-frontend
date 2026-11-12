import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'face_recognition_service.dart';
import 'fingerprint_recognition_service.dart';
import 'database_service.dart';

class BiometricAuthResult {
  final bool success;
  final String message;
  final String? email;
  final String? biometricType;
  final double? similarityScore;

  const BiometricAuthResult({
    required this.success,
    required this.message,
    this.email,
    this.biometricType,
    this.similarityScore,
  });
}

class BiometricDuplicateCheckResult {
  final bool isDuplicate;
  final String? existingEmail;
  final double similarityScore;
  final String message;

  const BiometricDuplicateCheckResult({
    required this.isDuplicate,
    this.existingEmail,
    this.similarityScore = 0.0,
    required this.message,
  });
}

class BiometricService {
  static final BiometricService instance = BiometricService._internal();
  factory BiometricService() => instance;
  BiometricService._internal();

  final LocalAuthentication _auth = LocalAuthentication();
  final ImagePicker _imagePicker = ImagePicker();
  final FaceRecognitionService _faceEngine = FaceRecognitionService.instance;

  static const String _prefAllEnrolledEmails = 'unidrive_all_enrolled_emails';
  static const String _prefLastEnrolledEmail = 'unidrive_last_enrolled_email';

  String _userKey(String email, String key) =>
      'unidrive_bio_${email.trim().toLowerCase()}_$key';

  /// Vérifie si l'appareil supporte la biométrie matérielle
  Future<bool> isDeviceSupported() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return isSupported || canCheck;
    } catch (e) {
      debugPrint('[BiometricService] isDeviceSupported error: $e');
      return false;
    }
  }

  /// Types de biométrie disponibles
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('[BiometricService] getAvailableBiometrics error: $e');
      return [];
    }
  }

  /// Authentification système matérielle (empreinte / FaceID OS)
  Future<bool> authenticateSystem({
    String reason = 'Authentifiez-vous pour accéder à votre compte UniDrive',
  }) async {
    try {
      final canCheck = await isDeviceSupported();
      if (!canCheck) {
        debugPrint('[BiometricService] Biométrie matérielle non disponible, validation autorisée');
        return true;
      }

      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException catch (e) {
      debugPrint('[BiometricService] authenticate error: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[BiometricService] authenticate error: $e');
      return false;
    }
  }

  /// Enregistre la signature biométrique d'empreinte d'un utilisateur
  Future<void> saveFingerprintSignature(
    String email,
    FingerprintSignature signature,
  ) async {
    await FingerprintRecognitionService.instance.saveSignature(email, signature);
  }

  /// Vérifie si l'empreinte candidate correspond au compte cible
  Future<BiometricAuthResult> verifyFingerprintForAccount({
    required FingerprintSignature candidateSignature,
    required String targetEmail,
  }) async {
    final normalizedEmail = targetEmail.trim().toLowerCase();

    // 1. Chercher la signature enregistrée
    final enrolledSignature =
        await FingerprintRecognitionService.instance.getSignature(normalizedEmail);

    if (enrolledSignature == null) {
      return BiometricAuthResult(
        success: false,
        message:
            'Aucune empreinte enregistrée pour le compte "$normalizedEmail". Veuillez configurer votre empreinte.',
        email: normalizedEmail,
        biometricType: 'fingerprint',
      );
    }

    // 2. Comparaison biométrique réelle des caractéristiques de l'empreinte
    final double similarity = FingerprintRecognitionService.instance
        .compareSignatures(enrolledSignature, candidateSignature);

    debugPrint(
        '[BiometricService] Comparaison empreinte pour $normalizedEmail: $similarity% (seuil: ${FingerprintRecognitionService.matchThreshold}%)');

    if (similarity >= FingerprintRecognitionService.matchThreshold) {
      return BiometricAuthResult(
        success: true,
        message:
            'Empreinte authentifiée (${similarity.toStringAsFixed(1)} %) pour $normalizedEmail !',
        email: normalizedEmail,
        biometricType: 'fingerprint',
        similarityScore: similarity,
      );
    } else {
      return BiometricAuthResult(
        success: false,
        message:
            'Empreinte non reconnue (${similarity.toStringAsFixed(1)} %). Cette empreinte ne correspond pas au compte sélectionné ! Accès refusé.',
        email: normalizedEmail,
        biometricType: 'fingerprint',
        similarityScore: similarity,
      );
    }
  }

  /// Identifie le compte correspondant à l'empreinte candidate parmi tous les comptes
  Future<BiometricAuthResult> identifyFingerprintAcrossAllAccounts({
    required FingerprintSignature candidateSignature,
  }) async {
    final allUsers = await DatabaseServicee.instance.getAllUsers();
    final fpUsers = allUsers
        .where((u) => u.fingerprintEnrolled || u.biometrieActive)
        .toList();

    final prefs = await SharedPreferences.getInstance();
    final allEnrolled = prefs.getStringList(_prefAllEnrolledEmails) ?? [];

    final candidateEmails = <String>{
      ...fpUsers.map((u) => u.email),
      ...allEnrolled,
    };

    if (candidateEmails.isEmpty) {
      return const BiometricAuthResult(
        success: false,
        message:
            'Aucun compte avec empreinte digitale configurée sur cet appareil.',
        biometricType: 'fingerprint',
      );
    }

    double bestScore = 0.0;
    String? matchedEmail;

    for (final email in candidateEmails) {
      final sig =
          await FingerprintRecognitionService.instance.getSignature(email);
      if (sig != null) {
        final score = FingerprintRecognitionService.instance
            .compareSignatures(sig, candidateSignature, enforceAccountBinding: false);
        if (score > bestScore) {
          bestScore = score;
          if (score >= FingerprintRecognitionService.matchThreshold) {
            matchedEmail = email;
          }
        }
      }
    }

    if (matchedEmail != null) {
      return BiometricAuthResult(
        success: true,
        message: 'Empreinte reconnue (${bestScore.toStringAsFixed(1)} %) !',
        email: matchedEmail,
        biometricType: 'fingerprint',
        similarityScore: bestScore,
      );
    } else {
      return BiometricAuthResult(
        success: false,
        message:
            'Empreinte non reconnue (similarité: ${bestScore.toStringAsFixed(1)} %). Cette empreinte ne correspond à aucun profil enregistré !',
        biometricType: 'fingerprint',
        similarityScore: bestScore,
      );
    }
  }

  /// Vérifie si l'empreinte tactile candidate est déjà enregistrée sur un autre compte
  Future<BiometricDuplicateCheckResult> checkFingerprintDuplicate(
    FingerprintSignature candidateSignature, {
    String? excludeEmail,
  }) async {
    final normExclude = excludeEmail?.trim().toLowerCase();
    final allUsers = await DatabaseServicee.instance.getAllUsers();
    final prefs = await SharedPreferences.getInstance();
    final allEnrolled = prefs.getStringList(_prefAllEnrolledEmails) ?? [];

    final candidateEmails = <String>{
      ...allUsers.map((u) => u.email.trim().toLowerCase()),
      ...allEnrolled.map((e) => e.trim().toLowerCase()),
    };

    if (normExclude != null && normExclude.isNotEmpty) {
      candidateEmails.remove(normExclude);
    }

    double maxScore = 0.0;
    String? duplicateEmail;

    for (final email in candidateEmails) {
      final sig =
          await FingerprintRecognitionService.instance.getSignature(email);
      if (sig != null) {
        final score = FingerprintRecognitionService.instance.compareSignatures(
          sig,
          candidateSignature,
          enforceAccountBinding: false,
        );
        if (score > maxScore) {
          maxScore = score;
          if (score >= FingerprintRecognitionService.matchThreshold) {
            duplicateEmail = email;
            break;
          }
        }
      }
    }

    if (duplicateEmail != null) {
      return BiometricDuplicateCheckResult(
        isDuplicate: true,
        existingEmail: duplicateEmail,
        similarityScore: maxScore,
        message:
            '❌ Empreinte déjà utilisée ! Cette empreinte est déjà associée au compte "$duplicateEmail" (${maxScore.toStringAsFixed(1)} %). Chaque compte doit posséder sa propre empreinte biométrique unique.',
      );
    }

    return const BiometricDuplicateCheckResult(
      isDuplicate: false,
      message: 'Empreinte unique et valide.',
    );
  }

  /// Vérifie si la photo macro de l'empreinte est déjà enregistrée sur un autre compte
  Future<BiometricDuplicateCheckResult> checkFingerprintPhotoDuplicate(
    String candidateImagePath, {
    String? excludeEmail,
  }) async {
    final normExclude = excludeEmail?.trim().toLowerCase();
    final allUsers = await DatabaseServicee.instance.getAllUsers();
    final prefs = await SharedPreferences.getInstance();
    final allEnrolled = prefs.getStringList(_prefAllEnrolledEmails) ?? [];

    final emailToFpPath = <String, String>{};
    for (final u in allUsers) {
      final email = u.email.trim().toLowerCase();
      if (email == normExclude) continue;
      if (u.fingerprintDataPath != null &&
          File(u.fingerprintDataPath!).existsSync()) {
        emailToFpPath[email] = u.fingerprintDataPath!;
      }
    }
    for (final email in allEnrolled) {
      final norm = email.trim().toLowerCase();
      if (norm == normExclude || emailToFpPath.containsKey(norm)) continue;
      final path = prefs.getString(_userKey(norm, 'fp_path'));
      if (path != null && File(path).existsSync()) {
        emailToFpPath[norm] = path;
      }
    }

    for (final entry in emailToFpPath.entries) {
      final score = await _faceEngine.compareFaceFiles(
        entry.value,
        candidateImagePath,
      );
      if (score >= FaceRecognitionService.matchThreshold) {
        return BiometricDuplicateCheckResult(
          isDuplicate: true,
          existingEmail: entry.key,
          similarityScore: score,
          message:
              '❌ Empreinte déjà utilisée sur un autre compte ("${entry.key}", ${score.toStringAsFixed(1)} %). Chaque compte doit avoir sa propre empreinte biométrique.',
        );
      }
    }

    return const BiometricDuplicateCheckResult(
      isDuplicate: false,
      message: 'Empreinte optique unique et valide.',
    );
  }

  /// Vérifie si le visage candidat est déjà enregistré sur un autre compte
  Future<BiometricDuplicateCheckResult> checkFaceDuplicate(
    String candidateImagePath, {
    String? excludeEmail,
  }) async {
    final normExclude = excludeEmail?.trim().toLowerCase();
    final allUsers = await DatabaseServicee.instance.getAllUsers();
    final prefs = await SharedPreferences.getInstance();
    final allEnrolled = prefs.getStringList(_prefAllEnrolledEmails) ?? [];

    final emailToFacePath = <String, String>{};
    for (final u in allUsers) {
      final email = u.email.trim().toLowerCase();
      if (email == normExclude) continue;
      if (u.faceDataPath != null && File(u.faceDataPath!).existsSync()) {
        emailToFacePath[email] = u.faceDataPath!;
      }
    }
    for (final email in allEnrolled) {
      final norm = email.trim().toLowerCase();
      if (norm == normExclude || emailToFacePath.containsKey(norm)) continue;
      final path = prefs.getString(_userKey(norm, 'face_path'));
      if (path != null && File(path).existsSync()) {
        emailToFacePath[norm] = path;
      }
    }

    for (final entry in emailToFacePath.entries) {
      final score = await _faceEngine.compareFaceFiles(
        entry.value,
        candidateImagePath,
      );
      if (score >= FaceRecognitionService.matchThreshold) {
        return BiometricDuplicateCheckResult(
          isDuplicate: true,
          existingEmail: entry.key,
          similarityScore: score,
          message:
              '❌ Visage déjà enregistré ! Ce visage est déjà associé au compte "${entry.key}" (${score.toStringAsFixed(1)} %). Chaque profil doit avoir son propre visage unique.',
        );
      }
    }

    return const BiometricDuplicateCheckResult(
      isDuplicate: false,
      message: 'Visage unique et valide.',
    );
  }

  /// Met à jour le mot de passe sauvegardé dans la biométrie locale
  Future<void> updateSavedPassword(String email, String newPassword) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedEmail = email.trim().toLowerCase();
    if (prefs.getBool(_userKey(normalizedEmail, 'enabled')) == true) {
      await prefs.setString(_userKey(normalizedEmail, 'password'), newPassword);
      debugPrint('[BiometricService] Mot de passe biométrique mis à jour pour $normalizedEmail');
    }
  }

  /// Authentification par empreinte associée à un compte précis (ou détection de compte)
  Future<BiometricAuthResult> authenticateFingerprintForAccount({
    String? targetEmail,
  }) async {
    final normalizedEmail = targetEmail?.trim().toLowerCase();

    // 1. Si un compte spécifique est spécifié
    if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
      final creds = await getEnrolledCredentialsFor(normalizedEmail);
      bool isEnrolled = creds != null &&
          (creds['hasFingerprint'] == true || creds['enabled'] == true);

      if (!isEnrolled) {
        final dbUser =
            await DatabaseServicee.instance.getUserByEmail(normalizedEmail);
        if (dbUser != null &&
            (dbUser.fingerprintEnrolled || dbUser.biometrieActive)) {
          isEnrolled = true;
        }
      }

      if (!isEnrolled) {
        return BiometricAuthResult(
          success: false,
          message:
              'L\'empreinte digitale n\'est pas activée pour le compte "$normalizedEmail". Veuillez d\'abord vous connecter avec mot de passe et l\'activer.',
          email: normalizedEmail,
          biometricType: 'fingerprint',
        );
      }

      final authenticated = await authenticateSystem(
        reason: 'Validation de l\'empreinte digitale pour $normalizedEmail',
      );

      if (authenticated) {
        return BiometricAuthResult(
          success: true,
          message: 'Empreinte reconnue pour le compte $normalizedEmail !',
          email: normalizedEmail,
          biometricType: 'fingerprint',
        );
      } else {
        return BiometricAuthResult(
          success: false,
          message: 'Échec de la lecture d\'empreinte ou capteur annulé.',
          email: normalizedEmail,
          biometricType: 'fingerprint',
        );
      }
    }

    // 2. Si aucun email n'est saisi, rechercher tous les comptes avec empreinte activée
    final allUsers = await DatabaseServicee.instance.getAllUsers();
    final fpUsers = allUsers
        .where((u) => u.fingerprintEnrolled || u.biometrieActive)
        .toList();

    final prefs = await SharedPreferences.getInstance();
    final lastEmail = prefs.getString(_prefLastEnrolledEmail);

    if (fpUsers.isEmpty && (lastEmail == null || lastEmail.isEmpty)) {
      return const BiometricAuthResult(
        success: false,
        message:
            'Aucun compte avec empreinte digitale configurée n\'a été trouvé sur cet appareil.',
        biometricType: 'fingerprint',
      );
    }

    final authenticated = await authenticateSystem(
      reason: 'Validation de l\'empreinte digitale pour UniDrive',
    );

    if (!authenticated) {
      return const BiometricAuthResult(
        success: false,
        message: 'Lecture d\'empreinte annulée ou non reconnue.',
        biometricType: 'fingerprint',
      );
    }

    String? matchedEmail = lastEmail;
    if (matchedEmail == null || matchedEmail.isEmpty) {
      matchedEmail = fpUsers.isNotEmpty ? fpUsers.first.email : null;
    }

    return BiometricAuthResult(
      success: true,
      message: 'Empreinte validée avec succès !',
      email: matchedEmail,
      biometricType: 'fingerprint',
    );
  }

  /// Enregistre les identifiants biométriques d'un utilisateur spécifique
  Future<void> saveEnrolledCredentials({
    required String email,
    required String password,
    required bool faceEnrolled,
    required bool fingerprintEnrolled,
    String? faceDataPath,
    String? fingerprintDataPath,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedEmail = email.trim().toLowerCase();

    await prefs.setBool(_userKey(normalizedEmail, 'enabled'), true);
    await prefs.setString(_userKey(normalizedEmail, 'password'), password);
    await prefs.setBool(_userKey(normalizedEmail, 'has_face'), faceEnrolled);
    await prefs.setBool(_userKey(normalizedEmail, 'has_fp'), fingerprintEnrolled);

    if (faceDataPath != null && faceDataPath.isNotEmpty) {
      await prefs.setString(_userKey(normalizedEmail, 'face_path'), faceDataPath);
    }
    if (fingerprintDataPath != null && fingerprintDataPath.isNotEmpty) {
      await prefs.setString(_userKey(normalizedEmail, 'fp_path'), fingerprintDataPath);
    }

    // Mise à jour de la liste de tous les comptes enregistrés
    final list = prefs.getStringList(_prefAllEnrolledEmails) ?? [];
    if (!list.contains(normalizedEmail)) {
      list.add(normalizedEmail);
      await prefs.setStringList(_prefAllEnrolledEmails, list);
    }

    await prefs.setString(_prefLastEnrolledEmail, normalizedEmail);

    // Synchronisation avec la base locale si l'utilisateur existe déjà
    try {
      final dbUser = await DatabaseServicee.instance.getUserByEmail(normalizedEmail);
      if (dbUser != null) {
        final updatedUser = dbUser.copyWith(
          biometrieActive: faceEnrolled || fingerprintEnrolled,
          faceEnrolled: faceEnrolled,
          fingerprintEnrolled: fingerprintEnrolled,
          faceDataPath: faceDataPath ?? dbUser.faceDataPath,
          fingerprintDataPath: fingerprintDataPath ?? dbUser.fingerprintDataPath,
        );
        await DatabaseServicee.instance.updateUser(updatedUser);
      }
    } catch (e) {
      debugPrint('[BiometricService] Synchronisation SQLite: $e');
    }
  }

  /// Récupère les données biométriques d'un utilisateur spécifique
  Future<Map<String, dynamic>?> getEnrolledCredentialsFor(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedEmail = email.trim().toLowerCase();

    final enabled = prefs.getBool(_userKey(normalizedEmail, 'enabled')) ?? false;
    if (!enabled) {
      // Vérifier si la base de données contient le profil
      final dbUser = await DatabaseServicee.instance.getUserByEmail(normalizedEmail);
      if (dbUser != null && (dbUser.biometrieActive || dbUser.faceEnrolled || dbUser.fingerprintEnrolled)) {
        return {
          'enabled': true,
          'email': normalizedEmail,
          'password': '',
          'hasFace': dbUser.faceEnrolled,
          'hasFingerprint': dbUser.fingerprintEnrolled,
          'facePath': dbUser.faceDataPath,
          'fingerprintPath': dbUser.fingerprintDataPath,
        };
      }
      return null;
    }

    final dbUser = await DatabaseServicee.instance.getUserByEmail(normalizedEmail);
    return {
      'enabled': true,
      'email': normalizedEmail,
      'password': prefs.getString(_userKey(normalizedEmail, 'password')) ?? '',
      'hasFace': prefs.getBool(_userKey(normalizedEmail, 'has_face')) ?? false,
      'hasFingerprint': prefs.getBool(_userKey(normalizedEmail, 'has_fp')) ?? false,
      'facePath': prefs.getString(_userKey(normalizedEmail, 'face_path')) ?? dbUser?.faceDataPath,
      'fingerprintPath': prefs.getString(_userKey(normalizedEmail, 'fp_path')) ?? dbUser?.fingerprintDataPath,
    };
  }

  /// Récupère les données du dernier utilisateur biométrique
  Future<Map<String, dynamic>?> getEnrolledCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final lastEmail = prefs.getString(_prefLastEnrolledEmail);
    if (lastEmail != null && lastEmail.isNotEmpty) {
      final creds = await getEnrolledCredentialsFor(lastEmail);
      if (creds != null) return creds;
    }

    final all = prefs.getStringList(_prefAllEnrolledEmails) ?? [];
    if (all.isNotEmpty) {
      return getEnrolledCredentialsFor(all.first);
    }
    return null;
  }

  /// Supprime la biométrie pour un compte précis
  Future<void> clearBiometricsFor(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedEmail = email.trim().toLowerCase();

    await prefs.remove(_userKey(normalizedEmail, 'enabled'));
    await prefs.remove(_userKey(normalizedEmail, 'password'));
    await prefs.remove(_userKey(normalizedEmail, 'has_face'));
    await prefs.remove(_userKey(normalizedEmail, 'has_fp'));
    await prefs.remove(_userKey(normalizedEmail, 'face_path'));

    final list = prefs.getStringList(_prefAllEnrolledEmails) ?? [];
    list.remove(normalizedEmail);
    await prefs.setStringList(_prefAllEnrolledEmails, list);

    if (prefs.getString(_prefLastEnrolledEmail) == normalizedEmail) {
      await prefs.remove(_prefLastEnrolledEmail);
    }
  }

  Future<void> clearBiometrics() async {
    final prefs = await SharedPreferences.getInstance();
    final lastEmail = prefs.getString(_prefLastEnrolledEmail);
    if (lastEmail != null) {
      await clearBiometricsFor(lastEmail);
    }
  }

  /// Capture de visage avec la caméra frontale pour l'enregistrement
  Future<String?> captureFaceImage({required String userIdentifier}) async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 90,
      );

      if (photo == null) return null;

      final directory = await getApplicationDocumentsDirectory();
      final facesDir = Directory('${directory.path}/biometric_faces');
      if (!await facesDir.exists()) {
        await facesDir.create(recursive: true);
      }

      final cleanId = userIdentifier.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final fileName = 'face_${cleanId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedPath = '${facesDir.path}/$fileName';
      final File savedFile = await File(photo.path).copy(savedPath);

      return savedFile.path;
    } catch (e) {
      debugPrint('[BiometricService] captureFaceImage error: $e');
      return null;
    }
  }

  /// Capture de l'empreinte digitale via la caméra (macro des sillons)
  Future<String?> captureFingerprintImage({required String userIdentifier}) async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 92,
      );

      if (photo == null) return null;

      final directory = await getApplicationDocumentsDirectory();
      final fpDir = Directory('${directory.path}/biometric_fingerprints');
      if (!await fpDir.exists()) {
        await fpDir.create(recursive: true);
      }

      final cleanId = userIdentifier.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final fileName = 'fp_${cleanId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedPath = '${fpDir.path}/$fileName';
      final File savedFile = await File(photo.path).copy(savedPath);

      return savedFile.path;
    } catch (e) {
      debugPrint('[BiometricService] captureFingerprintImage error: $e');
      return null;
    }
  }

  /// Vérifie si la photo de l'empreinte candidate correspond au compte cible
  Future<BiometricAuthResult> verifyFingerprintImageForAccount({
    required String candidateImagePath,
    required String targetEmail,
  }) async {
    final normalizedEmail = targetEmail.trim().toLowerCase();

    String? enrolledPath;
    final creds = await getEnrolledCredentialsFor(normalizedEmail);
    if (creds != null && creds['fingerprintPath'] != null) {
      enrolledPath = creds['fingerprintPath'] as String?;
    }

    if (enrolledPath == null || !File(enrolledPath).existsSync()) {
      final dbUser = await DatabaseServicee.instance.getUserByEmail(normalizedEmail);
      if (dbUser != null && dbUser.fingerprintDataPath != null) {
        enrolledPath = dbUser.fingerprintDataPath;
      }
    }

    if (enrolledPath == null || !File(enrolledPath).existsSync()) {
      return BiometricAuthResult(
        success: false,
        message: 'Aucune empreinte optique enregistrée pour le compte "$normalizedEmail".',
        email: normalizedEmail,
        biometricType: 'fingerprint',
      );
    }

    final double similarity = await _faceEngine.compareFaceFiles(
      enrolledPath,
      candidateImagePath,
    );

    debugPrint('[BiometricService] Comparaison empreinte optique pour $normalizedEmail: $similarity% (seuil: ${FaceRecognitionService.matchThreshold}%)');

    if (similarity >= FaceRecognitionService.matchThreshold) {
      return BiometricAuthResult(
        success: true,
        message: 'Empreinte reconnue (${similarity.toStringAsFixed(1)} %) pour $normalizedEmail !',
        email: normalizedEmail,
        biometricType: 'fingerprint',
        similarityScore: similarity,
      );
    } else {
      return BiometricAuthResult(
        success: false,
        message:
            'Empreinte non reconnue (${similarity.toStringAsFixed(1)} %). Cette empreinte ne correspond pas au compte sélectionné ! Accès refusé.',
        email: normalizedEmail,
        biometricType: 'fingerprint',
        similarityScore: similarity,
      );
    }
  }

  /// Identifie le compte par photo d'empreinte parmi tous les comptes enregistrés
  Future<BiometricAuthResult> identifyFingerprintImageAcrossAllAccounts({
    required String candidateImagePath,
  }) async {
    final allUsers = await DatabaseServicee.instance.getAllUsers();
    final prefs = await SharedPreferences.getInstance();
    final allEnrolled = prefs.getStringList(_prefAllEnrolledEmails) ?? [];

    final emailToFpPath = <String, Map<String, String>>{};
    for (final u in allUsers) {
      if (u.fingerprintDataPath != null &&
          File(u.fingerprintDataPath!).existsSync()) {
        emailToFpPath[u.email.trim().toLowerCase()] = {
          'path': u.fingerprintDataPath!,
          'name': u.nomComplet,
        };
      }
    }
    for (final email in allEnrolled) {
      final norm = email.trim().toLowerCase();
      if (!emailToFpPath.containsKey(norm)) {
        final path = prefs.getString(_userKey(norm, 'fp_path'));
        if (path != null && File(path).existsSync()) {
          final u = await DatabaseServicee.instance.getUserByEmail(norm);
          emailToFpPath[norm] = {
            'path': path,
            'name': u?.nomComplet ?? norm,
          };
        }
      }
    }

    if (emailToFpPath.isEmpty) {
      return const BiometricAuthResult(
        success: false,
        message: 'Aucun profil avec empreinte optique enregistré sur cet appareil.',
        biometricType: 'fingerprint',
      );
    }

    double bestScore = 0.0;
    String? matchedEmail;
    String? matchedName;

    for (final entry in emailToFpPath.entries) {
      final score = await _faceEngine.compareFaceFiles(
        entry.value['path']!,
        candidateImagePath,
      );
      if (score > bestScore) {
        bestScore = score;
        if (score >= FaceRecognitionService.matchThreshold) {
          matchedEmail = entry.key;
          matchedName = entry.value['name'];
        }
      }
    }

    if (matchedEmail != null) {
      return BiometricAuthResult(
        success: true,
        message: 'Empreinte de $matchedName reconnue (${bestScore.toStringAsFixed(1)} %) !',
        email: matchedEmail,
        biometricType: 'fingerprint',
        similarityScore: bestScore,
      );
    } else {
      return BiometricAuthResult(
        success: false,
        message:
            'Empreinte non reconnue (similarité: ${bestScore.toStringAsFixed(1)} %). Cette empreinte ne correspond à aucun profil enregistré !',
        biometricType: 'fingerprint',
        similarityScore: bestScore,
      );
    }
  }

  /// Vérifie si la photo candidate correspond au compte cible
  Future<BiometricAuthResult> verifyFaceForAccount({
    required String candidateImagePath,
    required String targetEmail,
  }) async {
    final normalizedEmail = targetEmail.trim().toLowerCase();

    // 1. Chercher le chemin de visage enregistré
    String? enrolledPath;
    final creds = await getEnrolledCredentialsFor(normalizedEmail);
    if (creds != null && creds['facePath'] != null) {
      enrolledPath = creds['facePath'] as String?;
    }

    if (enrolledPath == null || !File(enrolledPath).existsSync()) {
      final dbUser = await DatabaseServicee.instance.getUserByEmail(normalizedEmail);
      if (dbUser != null && dbUser.faceDataPath != null) {
        enrolledPath = dbUser.faceDataPath;
      }
    }

    if (enrolledPath == null || !File(enrolledPath).existsSync()) {
      return BiometricAuthResult(
        success: false,
        message: 'Aucun visage enregistré pour le compte "$normalizedEmail".',
        email: normalizedEmail,
        biometricType: 'face',
      );
    }

    // 2. Comparaison biométrique réelle des traits du visage
    final double similarity = await _faceEngine.compareFaceFiles(
      enrolledPath,
      candidateImagePath,
    );

    debugPrint('[BiometricService] Comparaison faciale pour $normalizedEmail: $similarity%');

    if (similarity >= FaceRecognitionService.matchThreshold) {
      return BiometricAuthResult(
        success: true,
        message: 'Visage authentifié (${similarity.toStringAsFixed(1)} %) !',
        email: normalizedEmail,
        biometricType: 'face',
        similarityScore: similarity,
      );
    } else {
      return BiometricAuthResult(
        success: false,
        message:
            'Visage non reconnu (${similarity.toStringAsFixed(1)} %). Ce visage ne correspond pas au compte sélectionné !',
        email: normalizedEmail,
        biometricType: 'face',
        similarityScore: similarity,
      );
    }
  }

  /// Identifie le bon compte parmi tous les utilisateurs enregistrés
  Future<BiometricAuthResult> identifyFaceAcrossAllAccounts({
    required String candidateImagePath,
  }) async {
    final allUsers = await DatabaseServicee.instance.getAllUsers();
    final prefs = await SharedPreferences.getInstance();
    final allEnrolled = prefs.getStringList(_prefAllEnrolledEmails) ?? [];

    final emailToFacePath = <String, Map<String, String>>{};
    for (final u in allUsers) {
      if (u.faceDataPath != null && File(u.faceDataPath!).existsSync()) {
        emailToFacePath[u.email.trim().toLowerCase()] = {
          'path': u.faceDataPath!,
          'name': u.nomComplet,
        };
      }
    }
    for (final email in allEnrolled) {
      final norm = email.trim().toLowerCase();
      if (!emailToFacePath.containsKey(norm)) {
        final path = prefs.getString(_userKey(norm, 'face_path'));
        if (path != null && File(path).existsSync()) {
          final u = await DatabaseServicee.instance.getUserByEmail(norm);
          emailToFacePath[norm] = {
            'path': path,
            'name': u?.nomComplet ?? norm,
          };
        }
      }
    }

    if (emailToFacePath.isEmpty) {
      return const BiometricAuthResult(
        success: false,
        message:
            'Aucun profil avec reconnaissance faciale enregistré sur cet appareil.',
        biometricType: 'face',
      );
    }

    double bestScore = 0.0;
    String? matchedEmail;
    String? matchedName;

    for (final entry in emailToFacePath.entries) {
      final score = await _faceEngine.compareFaceFiles(
        entry.value['path']!,
        candidateImagePath,
      );
      if (score > bestScore) {
        bestScore = score;
        if (score >= FaceRecognitionService.matchThreshold) {
          matchedEmail = entry.key;
          matchedName = entry.value['name'];
        }
      }
    }

    if (matchedEmail != null) {
      return BiometricAuthResult(
        success: true,
        message: 'Visage de $matchedName reconnu (${bestScore.toStringAsFixed(1)} %) !',
        email: matchedEmail,
        biometricType: 'face',
        similarityScore: bestScore,
      );
    } else {
      return BiometricAuthResult(
        success: false,
        message:
            'Visage non reconnu (meilleure correspondance: ${bestScore.toStringAsFixed(1)} %). Aucun compte UniDrive ne correspond à ce visage !',
        biometricType: 'face',
        similarityScore: bestScore,
      );
    }
  }
}
