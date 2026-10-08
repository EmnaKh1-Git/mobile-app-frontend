// ============================================================
//  MODULE : GESTION DES TRAJETS (Yassine)
//  Fichier : lib/features/trajet/utils/trajet_format.dart
//  Formatage des dates, durées et prix (préfixe « t » pour ne pas
//  entrer en conflit avec core/utils/helpers.dart).
// ============================================================

const List<String> _moisTrajet = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'
];

/// 2 oct. 2026
String tDateLongue(DateTime d) => '${d.day} ${_moisTrajet[d.month - 1]} ${d.year}';

/// 2 oct.
String tDateCourte(DateTime d) => '${d.day} ${_moisTrajet[d.month - 1]}';

/// 07:30
String tHeure(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// 45 min, 2h15
String tDuree(int min) => min < 60
    ? '$min min'
    : '${min ~/ 60}h${(min % 60).toString().padLeft(2, '0')}';

/// 18 DT, 12.50 DT
String tPrix(double p) => '${p.toStringAsFixed(p % 1 == 0 ? 0 : 2)} DT';
