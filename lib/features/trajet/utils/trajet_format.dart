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

const List<String> _moisLongs = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
];

const List<String> _joursSemaine = [
  'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'
];

/// oct.
String tMoisCourt(DateTime d) => _moisTrajet[d.month - 1];

/// octobre 2026
String tMoisAnnee(DateTime d) => '${_moisLongs[d.month - 1]} ${d.year}';

/// lundi, mardi…
String tJourSemaine(DateTime d) => _joursSemaine[d.weekday - 1];

/// LUN, MAR…
String tJourSemaineCourt(DateTime d) =>
    _joursSemaine[d.weekday - 1].substring(0, 3).toUpperCase();

/// aujourd'hui, demain, après-demain, sinon « jeudi 29 oct. »
String tJourRelatif(DateTime d, {DateTime? maintenant}) {
  final n = maintenant ?? DateTime.now();
  final ecart = DateTime(d.year, d.month, d.day)
      .difference(DateTime(n.year, n.month, n.day))
      .inDays;
  if (ecart == 0) return 'aujourd’hui';
  if (ecart == 1) return 'demain';
  if (ecart == 2) return 'après-demain';
  return '${tJourSemaine(d)} ${tDateCourte(d)}';
}

/// dans 25 min, dans 3 h, dans 2 j 4 h (ou « départ passé »)
String tCompteARebours(DateTime d, {DateTime? maintenant}) {
  final reste = d.difference(maintenant ?? DateTime.now());
  if (reste.isNegative) return 'départ passé';
  if (reste.inMinutes < 60) return 'dans ${reste.inMinutes} min';
  if (reste.inHours < 24) return 'dans ${reste.inHours} h';
  final heures = reste.inHours % 24;
  return 'dans ${reste.inDays} j${heures > 0 ? ' $heures h' : ''}';
}
