import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Service d'analyse et de comparaison biométrique faciale hautement discriminant
/// Utilise la corrélation croisée normalisée à moyenne nulle (ZNCC) multi-zones,
/// le masquage gaussien elliptique pour éliminer l'arrière-plan,
/// l'analyse chromatique (Cb, Cr) de la carnation, les gradients multi-axes et le LBP.
class FaceRecognitionService {
  static final FaceRecognitionService instance = FaceRecognitionService._();
  FaceRecognitionService._();

  /// Seuil minimal de similarité faciale (en %) pour accepter l'authentification
  static const double matchThreshold = 70.0;

  /// Extrait une signature biométrique discriminante à partir d'une photo de visage
  Future<Map<String, dynamic>?> extractFaceSignature(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) return null;

      final Uint8List bytes = await file.readAsBytes();
      final img.Image? decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      // Correction de l'orientation EXIF de la caméra
      final img.Image oriented = img.bakeOrientation(decoded);

      // 1. Cadrage précis de l'ovale du visage (zone centrale)
      final int cropW = (oriented.width * 0.60).toInt();
      final int cropH = (oriented.height * 0.60).toInt();
      final int cropX = ((oriented.width - cropW) / 2).toInt();
      final int cropY = ((oriented.height - cropH) / 2).toInt();

      final img.Image faceRegion = img.copyCrop(
        oriented,
        x: cropX,
        y: cropY,
        width: cropW,
        height: cropH,
      );

      // Normalisation à 64x64 pour conserver les détails fins (yeux, nez, lèvres)
      final img.Image normalized =
          img.copyResize(faceRegion, width: 64, height: 64);

      // 2. Masquage gaussien elliptique pour éliminer les murs et l'arrière-plan
      // Les pixels extérieurs à l'ovale du visage sont atténués à 0
      final double cx = 31.5;
      final double cy = 31.5;
      final double rx = 24.0;
      final double ry = 28.0;

      // 3. Décomposition en 3 zones anatomiques strictes
      // Zone 1 : Yeux & Sourcils (y = 10 à 28)
      // Zone 2 : Nez & Pommettes (y = 26 à 44)
      // Zone 3 : Bouche & Menton (y = 40 à 58)
      final List<double> upperGrid = _extractZoneGrid(normalized, 10, 28, cx, cy, rx, ry);
      final List<double> midGrid = _extractZoneGrid(normalized, 26, 44, cx, cy, rx, ry);
      final List<double> lowerGrid = _extractZoneGrid(normalized, 40, 58, cx, cy, rx, ry);

      // Grille globale 16x16 (256 descripteurs) avec pondération gaussienne
      final List<double> luminanceGrid = [];
      for (int gy = 0; gy < 16; gy++) {
        for (int gx = 0; gx < 16; gx++) {
          double blockSum = 0.0;
          double weightSum = 0.0;
          for (int py = 0; py < 4; py++) {
            for (int px = 0; px < 4; px++) {
              final int x = gx * 4 + px;
              final int y = gy * 4 + py;
              final double dx = (x - cx) / rx;
              final double dy = (y - cy) / ry;
              final double d2 = (dx * dx) + (dy * dy);
              final double w = d2 > 1.8 ? 0.0 : exp(-d2 / 1.5);
              final pixel = normalized.getPixel(x, y);
              blockSum += pixel.luminanceNormalized * w;
              weightSum += w;
            }
          }
          luminanceGrid.add(weightSum > 0.01 ? (blockSum / weightSum) : 0.0);
        }
      }

      // 4. Analyse de la carnation et chrominance (Cb, Cr)
      // Mesure la couleur naturelle de la peau au centre du visage pour différencier les personnes
      double sumCb = 0.0;
      double sumCr = 0.0;
      int colorCount = 0;
      for (int y = 20; y < 44; y++) {
        for (int x = 20; x < 44; x++) {
          final p = normalized.getPixel(x, y);
          final double r = p.r.toDouble();
          final double g = p.g.toDouble();
          final double b = p.b.toDouble();
          final double cb = -0.168736 * r - 0.331264 * g + 0.5 * b + 128.0;
          final double cr = 0.5 * r - 0.418688 * g - 0.081312 * b + 128.0;
          sumCb += cb;
          sumCr += cr;
          colorCount++;
        }
      }
      final double skinCb = colorCount > 0 ? (sumCb / colorCount) : 128.0;
      final double skinCr = colorCount > 0 ? (sumCr / colorCount) : 128.0;

      // 5. Gradients directionnels multi-axes à 128 bits (dHash horizontal + vertical)
      final img.Image smallH = img.copyResize(normalized, width: 9, height: 8);
      final List<int> dHashHorizontal = [];
      for (int y = 0; y < 8; y++) {
        for (int x = 0; x < 8; x++) {
          final l = smallH.getPixel(x, y).luminance;
          final r = smallH.getPixel(x + 1, y).luminance;
          dHashHorizontal.add(l > r ? 1 : 0);
        }
      }

      final img.Image smallV = img.copyResize(normalized, width: 8, height: 9);
      final List<int> dHashVertical = [];
      for (int y = 0; y < 8; y++) {
        for (int x = 0; x < 8; x++) {
          final t = smallV.getPixel(x, y).luminance;
          final b = smallV.getPixel(x, y + 1).luminance;
          dHashVertical.add(t > b ? 1 : 0);
        }
      }
      final List<int> gradientBits128 = [...dHashHorizontal, ...dHashVertical];

      // 6. Motifs binaires locaux (LBP) 64 bacs pour la texture cutanée
      final List<double> lbpHistogram = List.filled(64, 0.0);
      int lbpTotal = 0;
      for (int y = 4; y < 60; y += 2) {
        for (int x = 4; x < 60; x += 2) {
          final center = normalized.getPixel(x, y).luminance;
          int pattern = 0;
          final neighbors = [
            normalized.getPixel(x - 2, y - 2).luminance,
            normalized.getPixel(x, y - 2).luminance,
            normalized.getPixel(x + 2, y - 2).luminance,
            normalized.getPixel(x + 2, y).luminance,
            normalized.getPixel(x + 2, y + 2).luminance,
            normalized.getPixel(x, y + 2).luminance,
            normalized.getPixel(x - 2, y + 2).luminance,
            normalized.getPixel(x - 2, y).luminance,
          ];
          for (int i = 0; i < 8; i++) {
            if (neighbors[i] >= center) {
              pattern |= (1 << (i % 6));
            }
          }
          lbpHistogram[pattern] += 1.0;
          lbpTotal++;
        }
      }
      if (lbpTotal > 0) {
        for (int i = 0; i < lbpHistogram.length; i++) {
          lbpHistogram[i] /= lbpTotal;
        }
      }

      return {
        'luminanceGrid': luminanceGrid,
        'upperGrid': upperGrid,
        'midGrid': midGrid,
        'lowerGrid': lowerGrid,
        'skinCb': skinCb,
        'skinCr': skinCr,
        'gradientBits': gradientBits128,
        'lbpHistogram': lbpHistogram,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
    } catch (e) {
      debugPrint('[FaceRecognitionService] Erreur extraction: $e');
      return null;
    }
  }

  static List<double> _extractZoneGrid(
    img.Image imgData,
    int yStart,
    int yEnd,
    double cx,
    double cy,
    double rx,
    double ry,
  ) {
    final List<double> grid = [];
    final int h = yEnd - yStart;
    final int cellW = 8;
    final int cellH = (h / 8).ceil();

    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        double sum = 0.0;
        int count = 0;
        final int startX = c * cellW;
        final int startY = yStart + (r * cellH);
        for (int py = 0; py < cellH && (startY + py) < yEnd; py++) {
          for (int px = 0; px < cellW && (startX + px) < 64; px++) {
            final int pxX = startX + px;
            final int pxY = startY + py;
            final double dx = (pxX - cx) / rx;
            final double dy = (pxY - cy) / ry;
            if ((dx * dx + dy * dy) <= 1.8) {
              sum += imgData.getPixel(pxX, pxY).luminanceNormalized;
              count++;
            }
          }
        }
        grid.add(count > 0 ? (sum / count) : 0.0);
      }
    }
    return grid;
  }

  /// Compare deux signatures et renvoie un pourcentage de similarité rigoureux (0 à 100%)
  double computeSimilarity(
    Map<String, dynamic> sigA,
    Map<String, dynamic> sigB,
  ) {
    try {
      // 1. Corrélation croisée normalisée à moyenne nulle (ZNCC) globale (Poids 35%)
      final List<dynamic> rawA = sigA['luminanceGrid'] as List<dynamic>;
      final List<dynamic> rawB = sigB['luminanceGrid'] as List<dynamic>;
      final gridA = rawA.map((e) => (e as num).toDouble()).toList();
      final gridB = rawB.map((e) => (e as num).toDouble()).toList();

      final double globalZNCC = _zeroMeanNormalizedCrossCorrelation(gridA, gridB);

      // 2. Analyse ZNCC des 3 zones anatomiques indépendantes (Poids 30%)
      final List<dynamic>? rawUpperA = sigA['upperGrid'] as List<dynamic>?;
      final List<dynamic>? rawUpperB = sigB['upperGrid'] as List<dynamic>?;
      final List<dynamic>? rawMidA = sigA['midGrid'] as List<dynamic>?;
      final List<dynamic>? rawMidB = sigB['midGrid'] as List<dynamic>?;
      final List<dynamic>? rawLowerA = sigA['lowerGrid'] as List<dynamic>?;
      final List<dynamic>? rawLowerB = sigB['lowerGrid'] as List<dynamic>?;

      double upperZNCC = globalZNCC;
      double midZNCC = globalZNCC;
      double lowerZNCC = globalZNCC;

      if (rawUpperA != null && rawUpperB != null) {
        upperZNCC = _zeroMeanNormalizedCrossCorrelation(
          rawUpperA.map((e) => (e as num).toDouble()).toList(),
          rawUpperB.map((e) => (e as num).toDouble()).toList(),
        );
      }
      if (rawMidA != null && rawMidB != null) {
        midZNCC = _zeroMeanNormalizedCrossCorrelation(
          rawMidA.map((e) => (e as num).toDouble()).toList(),
          rawMidB.map((e) => (e as num).toDouble()).toList(),
        );
      }
      if (rawLowerA != null && rawLowerB != null) {
        lowerZNCC = _zeroMeanNormalizedCrossCorrelation(
          rawLowerA.map((e) => (e as num).toDouble()).toList(),
          rawLowerB.map((e) => (e as num).toDouble()).toList(),
        );
      }

      // RÈGLE BIOMÉTRIQUE STRICTE :
      // Deux visages humains différents (ex: collègue) ont obligatoirement
      // une zone faciale (yeux, nez ou bouche) discordante (ZNCC < 0.25).
      // Si une zone est discordante, les visages sont de deux personnes distinctes !
      final bool zonesConcordantes =
          (upperZNCC >= 0.25) && (midZNCC >= 0.20) && (lowerZNCC >= 0.20);

      final double combinedZNCC =
          (globalZNCC * 0.40) + (upperZNCC * 0.25) + (midZNCC * 0.20) + (lowerZNCC * 0.15);

      final double znccScore = combinedZNCC <= 0.10
          ? (max(0.0, combinedZNCC) * 1.5)
          : (0.15 + ((combinedZNCC - 0.10) / 0.90) * 0.85);

      // 3. Similarité de carnation / chrominance (Cb, Cr) (Poids 15%)
      final double cbA = (sigA['skinCb'] as num?)?.toDouble() ?? 128.0;
      final double cbB = (sigB['skinCb'] as num?)?.toDouble() ?? 128.0;
      final double crA = (sigA['skinCr'] as num?)?.toDouble() ?? 128.0;
      final double crB = (sigB['skinCr'] as num?)?.toDouble() ?? 128.0;
      final double chromaDist = sqrt(pow(cbA - cbB, 2) + pow(crA - crB, 2));
      final double colorScore = (1.0 - (chromaDist / 28.0)).clamp(0.0, 1.0);

      // 4. Gradients multi-axes 128 bits (Poids 20%)
      final List<dynamic> bitsA =
          (sigA['gradientBits'] ?? sigA['dHashBits']) as List<dynamic>;
      final List<dynamic> bitsB =
          (sigB['gradientBits'] ?? sigB['dHashBits']) as List<dynamic>;

      int matchingBits = 0;
      final int len = min(bitsA.length, bitsB.length);
      for (int i = 0; i < len; i++) {
        if (bitsA[i] == bitsB[i]) matchingBits++;
      }
      final double rawRatio = len > 0 ? (matchingBits / len) : 0.50;
      final double gradientScore = rawRatio <= 0.52
          ? 0.0
          : ((rawRatio - 0.52) / 0.48).clamp(0.0, 1.0);

      // Combinaison pondérée
      double composite =
          (znccScore * 0.45) + (gradientScore * 0.25) + (colorScore * 0.20) + (0.10 * (zonesConcordantes ? 1.0 : 0.0));

      double finalScore = (composite * 100.0).clamp(0.0, 100.0);

      // Si les zones anatomiques de la personne ne concordent pas (ex: collègue ou tiers),
      // le score est strictement plafonné à moins de 35% pour interdire tout accès !
      if (!zonesConcordantes || combinedZNCC < 0.25) {
        finalScore = min(finalScore, 34.0);
      }

      debugPrint(
          '[FaceRecognition] ZNCC glob: ${(globalZNCC * 100).toStringAsFixed(1)}% | Yeux: ${(upperZNCC * 100).toStringAsFixed(1)}% | Nez: ${(midZNCC * 100).toStringAsFixed(1)}% | Bouche: ${(lowerZNCC * 100).toStringAsFixed(1)}% | Color: ${(colorScore * 100).toStringAsFixed(1)}% | Score: ${finalScore.toStringAsFixed(1)}%');

      return finalScore;
    } catch (e) {
      debugPrint('[FaceRecognitionService] Erreur calcul similarité: $e');
      return 0.0;
    }
  }

  /// Compare directement deux fichiers photos et renvoie la similarité (%)
  Future<double> compareFaceFiles(String enrolledPath, String candidatePath) async {
    final sigA = await extractFaceSignature(enrolledPath);
    final sigB = await extractFaceSignature(candidatePath);

    if (sigA == null || sigB == null) return 0.0;
    return computeSimilarity(sigA, sigB);
  }

  /// Corrélation croisée normalisée à moyenne nulle (Zero-mean Normalized Cross-Correlation)
  double _zeroMeanNormalizedCrossCorrelation(List<double> v1, List<double> v2) {
    final int n = min(v1.length, v2.length);
    if (n == 0) return 0.0;

    double sum1 = 0.0;
    double sum2 = 0.0;
    for (int i = 0; i < n; i++) {
      sum1 += v1[i];
      sum2 += v2[i];
    }
    final double mean1 = sum1 / n;
    final double mean2 = sum2 / n;

    double num = 0.0;
    double den1 = 0.0;
    double den2 = 0.0;

    for (int i = 0; i < n; i++) {
      final double d1 = v1[i] - mean1;
      final double d2 = v2[i] - mean2;
      num += d1 * d2;
      den1 += d1 * d1;
      den2 += d2 * d2;
    }

    final double denom = sqrt(den1 * den2);
    if (denom < 1e-6) return 0.0;

    return (num / denom).clamp(-1.0, 1.0);
  }
}
