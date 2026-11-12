import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modèle représentant la signature biométrique d'une empreinte digitale
class FingerprintSignature {
  final double meanPressure;
  final double meanSize;
  final double meanRadiusMajor;
  final double meanRadiusMinor;
  final double radiusRatio;
  final double meanOrientation;
  final double pressureVariance;
  final double sizeVariance;
  final List<double> tremorWaveform;
  final int touchSamplesCount;
  final int timestamp;
  final String? accountEmail;

  // Métriques biométriques dynamiques de contact réel
  final double startX;
  final double startY;
  final double meanX;
  final double meanY;
  final double stdX;
  final double stdY;
  final double trajectoryLength;
  final int dwellDurationMs;
  final String? fingerSlot;

  const FingerprintSignature({
    required this.meanPressure,
    required this.meanSize,
    required this.meanRadiusMajor,
    required this.meanRadiusMinor,
    required this.radiusRatio,
    required this.meanOrientation,
    required this.pressureVariance,
    required this.sizeVariance,
    required this.tremorWaveform,
    required this.touchSamplesCount,
    required this.timestamp,
    this.accountEmail,
    this.startX = 70.0,
    this.startY = 70.0,
    this.meanX = 70.0,
    this.meanY = 70.0,
    this.stdX = 0.5,
    this.stdY = 0.5,
    this.trajectoryLength = 1.0,
    this.dwellDurationMs = 2500,
    this.fingerSlot = 'index_droit',
  });

  Map<String, dynamic> toMap() => {
        'meanPressure': meanPressure,
        'meanSize': meanSize,
        'meanRadiusMajor': meanRadiusMajor,
        'meanRadiusMinor': meanRadiusMinor,
        'radiusRatio': radiusRatio,
        'meanOrientation': meanOrientation,
        'pressureVariance': pressureVariance,
        'sizeVariance': sizeVariance,
        'tremorWaveform': tremorWaveform,
        'touchSamplesCount': touchSamplesCount,
        'timestamp': timestamp,
        'accountEmail': accountEmail,
        'startX': startX,
        'startY': startY,
        'meanX': meanX,
        'meanY': meanY,
        'stdX': stdX,
        'stdY': stdY,
        'trajectoryLength': trajectoryLength,
        'dwellDurationMs': dwellDurationMs,
        'fingerSlot': fingerSlot,
      };

  factory FingerprintSignature.fromMap(Map<String, dynamic> map) {
    return FingerprintSignature(
      meanPressure: (map['meanPressure'] as num?)?.toDouble() ?? 0.5,
      meanSize: (map['meanSize'] as num?)?.toDouble() ?? 0.1,
      meanRadiusMajor: (map['meanRadiusMajor'] as num?)?.toDouble() ?? 45.0,
      meanRadiusMinor: (map['meanRadiusMinor'] as num?)?.toDouble() ?? 30.0,
      radiusRatio: (map['radiusRatio'] as num?)?.toDouble() ?? 0.67,
      meanOrientation: (map['meanOrientation'] as num?)?.toDouble() ?? 0.0,
      pressureVariance: (map['pressureVariance'] as num?)?.toDouble() ?? 0.02,
      sizeVariance: (map['sizeVariance'] as num?)?.toDouble() ?? 0.01,
      tremorWaveform: (map['tremorWaveform'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      touchSamplesCount: (map['touchSamplesCount'] as num?)?.toInt() ?? 30,
      timestamp: (map['timestamp'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      accountEmail: map['accountEmail'] as String?,
      startX: (map['startX'] as num?)?.toDouble() ?? 70.0,
      startY: (map['startY'] as num?)?.toDouble() ?? 70.0,
      meanX: (map['meanX'] as num?)?.toDouble() ?? 70.0,
      meanY: (map['meanY'] as num?)?.toDouble() ?? 70.0,
      stdX: (map['stdX'] as num?)?.toDouble() ?? 0.5,
      stdY: (map['stdY'] as num?)?.toDouble() ?? 0.5,
      trajectoryLength: (map['trajectoryLength'] as num?)?.toDouble() ?? 1.0,
      dwellDurationMs: (map['dwellDurationMs'] as num?)?.toInt() ?? 2500,
      fingerSlot: map['fingerSlot'] as String? ?? 'index_droit',
    );
  }

  String toJson() => jsonEncode(toMap());
  factory FingerprintSignature.fromJson(String source) =>
      FingerprintSignature.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

/// Service de numérisation, extraction et comparaison d'empreintes digitales par profil
class FingerprintRecognitionService {
  static final FingerprintRecognitionService instance =
      FingerprintRecognitionService._();
  FingerprintRecognitionService._();

  /// Seuil de similarité biométrique d'empreinte pour autoriser l'accès (en %)
  static const double matchThreshold = 75.0;

  static const String _prefPrefix = 'unidrive_fp_signature_';

  String _storageKey(String email) =>
      '$_prefPrefix${email.trim().toLowerCase()}';

  /// Enregistre la signature d'empreinte pour un compte spécifique
  Future<void> saveSignature(
    String email,
    FingerprintSignature signature,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _storageKey(email);
    await prefs.setString(key, signature.toJson());
    debugPrint(
        '[FingerprintService] Empreinte enregistrée pour "$email" (${signature.touchSamplesCount} échantillons)');
  }

  /// Récupère la signature d'empreinte d'un compte
  Future<FingerprintSignature?> getSignature(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey(email));
    if (raw == null || raw.isEmpty) return null;
    try {
      return FingerprintSignature.fromJson(raw);
    } catch (e) {
      debugPrint('[FingerprintService] Erreur lecture signature: $e');
      return null;
    }
  }

  /// Vérifie si un compte possède une empreinte enregistrée
  Future<bool> hasSignature(String email) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_storageKey(email));
  }

  /// Supprime l'empreinte d'un compte
  Future<void> deleteSignature(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey(email));
  }

  /// Crée une signature à partir des échantillons tactiles collectés pendant le scan
  FingerprintSignature createSignatureFromSamples({
    required List<Map<String, double>> samples,
    required String? email,
    String? fingerSlot,
  }) {
    if (samples.isEmpty) {
      return FingerprintSignature(
        meanPressure: 0.55,
        meanSize: 0.12,
        meanRadiusMajor: 48.0,
        meanRadiusMinor: 32.0,
        radiusRatio: 0.67,
        meanOrientation: 0.05,
        pressureVariance: 0.03,
        sizeVariance: 0.015,
        tremorWaveform: List.generate(20, (i) => sin(i * 0.4) * 0.05 + 0.5),
        touchSamplesCount: 20,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        accountEmail: email,
        fingerSlot: fingerSlot ?? 'index_droit',
      );
    }

    double sumPressure = 0.0;
    double sumSize = 0.0;
    double sumRadiusMajor = 0.0;
    double sumRadiusMinor = 0.0;
    double sumOrientation = 0.0;
    double sumX = 0.0;
    double sumY = 0.0;

    final startX = samples.first['x'] ?? 70.0;
    final startY = samples.first['y'] ?? 70.0;

    double trajLength = 0.0;
    double prevX = startX;
    double prevY = startY;

    for (final s in samples) {
      final x = s['x'] ?? 70.0;
      final y = s['y'] ?? 70.0;
      sumPressure += s['pressure'] ?? 0.5;
      sumSize += s['size'] ?? 0.1;
      sumRadiusMajor += s['radiusMajor'] ?? 45.0;
      sumRadiusMinor += s['radiusMinor'] ?? 30.0;
      sumOrientation += s['orientation'] ?? 0.0;
      sumX += x;
      sumY += y;

      final dx = x - prevX;
      final dy = y - prevY;
      trajLength += sqrt(dx * dx + dy * dy);
      prevX = x;
      prevY = y;
    }

    final count = samples.length.toDouble();
    final meanP = sumPressure / count;
    final meanS = sumSize / count;
    final meanRMaj = sumRadiusMajor / count;
    final meanRMin = sumRadiusMinor / count;
    final meanO = sumOrientation / count;
    final rRatio = meanRMaj > 0 ? (meanRMin / meanRMaj) : 0.67;
    final meanX = sumX / count;
    final meanY = sumY / count;

    // Calcul des variances
    double varP = 0.0;
    double varS = 0.0;
    double varX = 0.0;
    double varY = 0.0;
    for (final s in samples) {
      final dp = (s['pressure'] ?? 0.5) - meanP;
      final ds = (s['size'] ?? 0.1) - meanS;
      final dx = (s['x'] ?? 70.0) - meanX;
      final dy = (s['y'] ?? 70.0) - meanY;
      varP += dp * dp;
      varS += ds * ds;
      varX += dx * dx;
      varY += dy * dy;
    }
    varP = count > 1 ? (varP / (count - 1)) : 0.02;
    varS = count > 1 ? (varS / (count - 1)) : 0.015;
    final stdX = count > 1 ? sqrt(varX / (count - 1)) : 0.5;
    final stdY = count > 1 ? sqrt(varY / (count - 1)) : 0.5;

    final waveform = samples.map((s) => s['pressure'] ?? 0.5).toList();

    return FingerprintSignature(
      meanPressure: meanP,
      meanSize: meanS,
      meanRadiusMajor: meanRMaj,
      meanRadiusMinor: meanRMin,
      radiusRatio: rRatio,
      meanOrientation: meanO,
      pressureVariance: varP,
      sizeVariance: varS,
      tremorWaveform: waveform,
      touchSamplesCount: samples.length,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      accountEmail: email,
      startX: startX,
      startY: startY,
      meanX: meanX,
      meanY: meanY,
      stdX: stdX,
      stdY: stdY,
      trajectoryLength: trajLength,
      dwellDurationMs: samples.length * 40,
      fingerSlot: fingerSlot ?? 'index_droit',
    );
  }

  /// Compare mathématiquement deux signatures d'empreinte et renvoie la similarité (%)
  double compareSignatures(
    FingerprintSignature enrolled,
    FingerprintSignature candidate, {
    bool enforceAccountBinding = false,
  }) {
    try {
      // 1. VÉRIFICATION STRICTE DU COMPTE (si demandée explicitement)
      if (enforceAccountBinding &&
          enrolled.accountEmail != null &&
          candidate.accountEmail != null &&
          enrolled.accountEmail!.trim().isNotEmpty &&
          candidate.accountEmail!.trim().isNotEmpty) {
        if (enrolled.accountEmail!.trim().toLowerCase() !=
            candidate.accountEmail!.trim().toLowerCase()) {
          debugPrint(
              '[FingerprintService] Rejet : Le compte candidat (${candidate.accountEmail}) != compte inscrit (${enrolled.accountEmail})');
          return 0.0;
        }
      }

      // 2. VÉRIFICATION DU DOIGT (SLOT) :
      if (enrolled.fingerSlot != null &&
          candidate.fingerSlot != null &&
          enrolled.fingerSlot != candidate.fingerSlot) {
        debugPrint(
            '[FingerprintService] Rejet : Doigt candidat (${candidate.fingerSlot}) != doigt inscrit (${enrolled.fingerSlot})');
        return 12.0;
      }

      // 3. SIMILARITÉ DU POINT DE CONTACT ET DE LA DYNAMIQUE (Poids 40%)
      // Compare la position de contact sur le capteur (coordonnées x, y)
      final double distPos = sqrt(
        pow(enrolled.meanX - candidate.meanX, 2) +
            pow(enrolled.meanY - candidate.meanY, 2),
      );
      final double posSim = (1.0 - (distPos / 24.0)).clamp(0.0, 1.0);

      final double diffTraj =
          (enrolled.trajectoryLength - candidate.trajectoryLength).abs();
      final double maxTraj =
          max(enrolled.trajectoryLength, candidate.trajectoryLength);
      final double trajSim =
          maxTraj > 0 ? (1.0 - (diffTraj / maxTraj)).clamp(0.0, 1.0) : 1.0;

      final double diffStdX = (enrolled.stdX - candidate.stdX).abs();
      final double diffStdY = (enrolled.stdY - candidate.stdY).abs();
      final double jitterSim =
          (1.0 - ((diffStdX + diffStdY) / 4.0)).clamp(0.0, 1.0);

      final double dynamicsSim =
          (posSim * 0.50) + (trajSim * 0.25) + (jitterSim * 0.25);

      // 4. SIMILARITÉ GÉOMÉTRIQUE DE L'ELLIPSE (Poids 35%)
      final double diffMajor =
          (enrolled.meanRadiusMajor - candidate.meanRadiusMajor).abs();
      final double normMajor =
          max(enrolled.meanRadiusMajor, candidate.meanRadiusMajor);
      final double simMajor =
          normMajor > 0 ? (1.0 - (diffMajor / normMajor)).clamp(0.0, 1.0) : 1.0;

      final double diffMinor =
          (enrolled.meanRadiusMinor - candidate.meanRadiusMinor).abs();
      final double normMinor =
          max(enrolled.meanRadiusMinor, candidate.meanRadiusMinor);
      final double simMinor =
          normMinor > 0 ? (1.0 - (diffMinor / normMinor)).clamp(0.0, 1.0) : 1.0;

      final double diffRatio =
          (enrolled.radiusRatio - candidate.radiusRatio).abs();
      final double simRatio = (1.0 - (diffRatio * 2.5)).clamp(0.0, 1.0);

      final double diffSize = (enrolled.meanSize - candidate.meanSize).abs();
      final double simSize = (1.0 - (diffSize * 5.0)).clamp(0.0, 1.0);

      final double geometrySim =
          (simMajor * 0.3) + (simMinor * 0.3) + (simRatio * 0.2) + (simSize * 0.2);

      // 5. SIMILARITÉ DE PRESSION DYNAMIQUE & MICRO-VARIATIONS (Poids 25%)
      final double diffPressure =
          (enrolled.meanPressure - candidate.meanPressure).abs();
      final double simPressure =
          (1.0 - (diffPressure * 2.0)).clamp(0.0, 1.0);

      final double diffVarP =
          (enrolled.pressureVariance - candidate.pressureVariance).abs();
      final double simVarP = (1.0 - (diffVarP * 10.0)).clamp(0.0, 1.0);
      final double pressureSim = (simPressure * 0.7) + (simVarP * 0.3);

      final double waveformSim = _compareWaveforms(
        enrolled.tremorWaveform,
        candidate.tremorWaveform,
      );

      final double composite =
          (dynamicsSim * 0.40) + (geometrySim * 0.35) + ((pressureSim * 0.6 + waveformSim * 0.4) * 0.25);

      final double finalScore = (composite * 100.0).clamp(0.0, 100.0);

      debugPrint(
          '[FingerprintService] Dyn: ${(dynamicsSim * 100).toStringAsFixed(1)}% | Geo: ${(geometrySim * 100).toStringAsFixed(1)}% | Press: ${(pressureSim * 100).toStringAsFixed(1)}% | Score: ${finalScore.toStringAsFixed(1)}%');

      return finalScore;
    } catch (e) {
      debugPrint('[FingerprintService] Erreur comparaison empreinte: $e');
      return 0.0;
    }
  }

  double _compareWaveforms(List<double> w1, List<double> w2) {
    if (w1.isEmpty || w2.isEmpty) return 0.75;
    final int len = min(w1.length, w2.length);
    if (len == 0) return 0.75;

    double dot = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;

    for (int i = 0; i < len; i++) {
      dot += w1[i] * w2[i];
      norm1 += w1[i] * w1[i];
      norm2 += w2[i] * w2[i];
    }

    if (norm1 == 0.0 || norm2 == 0.0) return 0.5;
    return (dot / (sqrt(norm1) * sqrt(norm2))).clamp(0.0, 1.0);
  }
}
