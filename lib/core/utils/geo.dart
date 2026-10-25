// ============================================================
//  Fichier : lib/core/utils/geo.dart
//  Calculs géographiques simples (sans dépendance externe),
//  utilisables par les modèles comme par les services.
// ============================================================

import 'dart:math' as math;

/// Distance « à vol d'oiseau » en km entre deux points GPS (formule de haversine).
double distanceEntre(double lat1, double lng1, double lat2, double lng2) {
  const rayonTerre = 6371.0; // km
  double rad(double deg) => deg * math.pi / 180;

  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return 2 * rayonTerre * math.asin(math.min(1.0, math.sqrt(h)));
}
