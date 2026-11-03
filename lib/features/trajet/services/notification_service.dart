// ============================================================
//  MODULE : GESTION DES TRAJETS (Yassine)
//  Fichier : lib/features/trajet/services/notification_service.dart
//
//  Centre de notifications (cloche de l'accueil) et alertes de recherche.
//  Les notifications sont déduites de l'état des trajets, des
//  réservations et des évaluations. Chacune a une clé unique
//  (« depart:12 ») : elle n'est créée qu'une seule fois.
//   - nouvelle réservation sur mon trajet / réservation confirmée ;
//   - discussion du trajet ouverte (2 h avant le départ) ;
//   - départ dans moins de 30 min ;
//   - trajet démarré ou annulé par le conducteur (je suis passager) ;
//   - trajet terminé à noter, nouvel avis reçu (7 derniers jours) ;
//   - trajet trouvé pour une de mes alertes.
//  L'annulation d'une réservation par un passager ne laisse pas de
//  trace dans l'état : TrajetService la signale (signalerAnnulation).
//  verifier() est appelé à chaque changement des trajets et des
//  discussions, et toutes les 30 s par la cloche (l'heure avance).
//  Même fonctionnement que les autres services : mémoire + SQLite
//  (base complements.db ; sur le web, tout reste en mémoire).
// ============================================================

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/complements_database.dart';
import '../../../models/discussion_trajet.dart';
import '../../../models/notification_trajet.dart';
import '../../../models/trajet.dart';
import '../utils/trajet_format.dart';
import 'assistant_trajet.dart' show MomentJournee, MomentJourneeX, normaliser;
import 'discussion_service.dart';
import 'trajet_service.dart';

/// Rappel envoyé ce temps-là avant le départ
const Duration rappelAvantDepart = Duration(minutes: 30);

/// Nombre maximum d'alertes de recherche
const int maxAlertes = 10;

/// Les trajets terminés et les avis plus anciens ne sont plus signalés
const Duration _fenetreHistorique = Duration(days: 7);

class NotificationService extends ChangeNotifier {
  NotificationService._()
      : _persister = !kIsWeb,
        _principal = true,
        _trajets = (() => TrajetService.instance.tous),
        _discussions = DiscussionService.instance;

  static final NotificationService instance = NotificationService._();

  /// Service sans SQLite ni données de démonstration, pour les tests :
  /// [_trajets] fournit les trajets, [_discussions] les réservations
  @visibleForTesting
  NotificationService.enMemoire(this._trajets, this._discussions)
      : _persister = false,
        _principal = false;

  final bool _persister;

  /// Service de l'application (démonstration + écoute des autres services)
  final bool _principal;
  final Iterable<Trajet> Function() _trajets;
  final DiscussionService _discussions;
  final ComplementsDatabase _db = ComplementsDatabase.instance;

  final List<NotificationTrajet> _notifications = [];
  final List<AlerteTrajet> _alertes = [];
  Future<void>? _chargement;
  bool _charge = false;

  bool get estCharge => _charge;

  // ---------- Chargement ----------
  /// Lit les notifications et les alertes dans SQLite, puis crée celles
  /// des événements pas encore signalés. Appelé par TrajetService.
  Future<void> charger() => _chargement ??= _charger();

  Future<void> _charger() async {
    var baseVide = true;
    if (_persister) {
      try {
        _notifications.addAll(await _db.lireNotifications());
        _alertes.addAll(await _db.lireAlertes());
        baseVide = _notifications.isEmpty && _alertes.isEmpty;
      } catch (e) {
        debugPrint('NotificationService : erreur de chargement SQLite : $e');
      }
    }
    if (_principal && baseVide) await _insererDemo();
    _charge = true;
    await verifier();
    if (_principal) {
      // Une réservation, une évaluation ou un changement de statut
      // peut créer une notification
      TrajetService.instance.addListener(_surChangement);
      _discussions.addListener(_surChangement);
    }
    notifyListeners();
  }

  void _surChangement() {
    if (_charge) verifier();
  }

  // ---------- Notifications ----------
  /// De la plus récente à la plus ancienne
  List<NotificationTrajet> get notifications =>
      [..._notifications]..sort((a, b) => b.date.compareTo(a.date));

  int get nonLues => _notifications.where((n) => !n.lue).length;

  Future<void> marquerLue(NotificationTrajet n) => _marquerLues({n.cle});

  Future<void> toutMarquerLu() =>
      _marquerLues({for (final n in _notifications) if (!n.lue) n.cle});

  Future<void> _marquerLues(Set<String> cles) async {
    var change = false;
    for (var i = 0; i < _notifications.length; i++) {
      final n = _notifications[i];
      if (!n.lue && cles.contains(n.cle)) {
        _notifications[i] = n.copyWith(lue: true);
        change = true;
      }
    }
    if (!change) return;
    notifyListeners();
    await _sql(() => _db.marquerLues(cles.toList()));
  }

  /// Crée les notifications des événements pas encore signalés
  Future<void> verifier({DateTime? maintenant}) async {
    final n = maintenant ?? DateTime.now();
    final connues = {for (final x in _notifications) x.cle};
    final nouvelles = [
      for (final x in [
        for (final t in _trajets()) ..._pourTrajet(t, n),
        ..._avisRecus(n),
        ..._alertesTrouvees(n),
      ])
        if (connues.add(x.cle)) x,
    ];
    if (nouvelles.isEmpty) return;
    // En mémoire d'abord (sans attendre) : deux vérifications
    // simultanées ne créent pas de doublon
    _notifications.addAll(nouvelles);
    notifyListeners();
    for (final x in nouvelles) {
      await _sql(() => _db.ajouterNotification(x));
    }
  }

  /// Notifications d'un trajet dont l'utilisateur est conducteur ou passager
  Iterable<NotificationTrajet> _pourTrajet(Trajet t, DateTime n) sync* {
    final conducteur = t.conducteurId == monId;
    final moi = _discussions.reservationDe(t.id, monId);
    if (!conducteur && moi == null) return;
    final route = '${t.villeDepart} → ${t.villeArrivee}';
    final quand =
        '${tJourRelatif(t.dateDepart, maintenant: n)} à ${tHeure(t.dateDepart)}';

    switch (t.statut) {
      case StatutTrajet.termine:
        final fin = t.dateArrivee.isBefore(n) ? t.dateArrivee : n;
        if (n.difference(fin) > _fenetreHistorique) return;
        if (_discussions.aNoter(t, monId).isEmpty) return;
        yield NotificationTrajet(
          cle: 'evaluation:${t.id}',
          type: TypeNotification.evaluation,
          titre: 'Notez votre trajet',
          texte: conducteur
              ? 'Comment se sont passés vos passagers sur $route ?'
              : 'Comment s’est passé le trajet $route avec ${t.conducteurNom} ?',
          trajetId: t.id,
          date: fin,
        );
        return;
      case StatutTrajet.annule:
        if (conducteur) return;
        yield NotificationTrajet(
          cle: 'statut:${t.id}:annule',
          type: TypeNotification.statut,
          titre: 'Trajet annulé',
          texte: '${t.conducteurNom} a annulé le trajet $route du '
              '${tDateCourte(t.dateDepart)}.',
          trajetId: t.id,
          date: n,
        );
        return;
      default:
        break;
    }

    // ---- Trajet actif ----
    if (conducteur) {
      for (final p in _discussions.passagers(t.id)) {
        yield NotificationTrajet(
          cle: 'reservation:${t.id}:${p.passagerId}',
          type: TypeNotification.reservation,
          titre: 'Nouvelle réservation',
          texte: '${p.nom} a réservé ${_places(p.places)} · $route, $quand.',
          trajetId: t.id,
          date: p.dateReservation,
        );
      }
    } else {
      yield NotificationTrajet(
        cle: 'reservation:${t.id}:$monId',
        type: TypeNotification.reservation,
        titre: 'Réservation confirmée',
        texte: '${_places(moi!.places)} avec ${t.conducteurNom} · $route, $quand.',
        trajetId: t.id,
        date: moi.dateReservation,
      );
    }

    if (etatDiscussion(t, maintenant: n) == EtatDiscussion.ouverte) {
      final ouverture = ouvertureDiscussion(t);
      yield NotificationTrajet(
        cle: 'discussion:${t.id}',
        type: TypeNotification.discussion,
        titre: 'Discussion ouverte',
        texte: 'Organisez le rendez-vous du trajet $route '
            '(départ à ${tHeure(t.dateDepart)}).',
        trajetId: t.id,
        date: ouverture.isBefore(n) ? ouverture : n,
      );
    }

    final rappel = t.dateDepart.subtract(rappelAvantDepart);
    if ((t.statut == StatutTrajet.publie || t.statut == StatutTrajet.complet) &&
        !n.isBefore(rappel) &&
        n.isBefore(t.dateDepart)) {
      final lieu = t.adresseDepart.isNotEmpty ? t.adresseDepart : t.villeDepart;
      yield NotificationTrajet(
        cle: 'depart:${t.id}',
        type: TypeNotification.depart,
        titre: 'Départ à ${tHeure(t.dateDepart)}',
        texte: '$route : rendez-vous à $lieu dans moins de 30 min.',
        trajetId: t.id,
        date: rappel,
      );
    }

    if (!conducteur && t.statut == StatutTrajet.enCours) {
      yield NotificationTrajet(
        cle: 'statut:${t.id}:enCours',
        type: TypeNotification.statut,
        titre: '${t.conducteurNom} est en route',
        texte: 'Le trajet $route a démarré.',
        trajetId: t.id,
        date: n,
      );
    }
  }

  /// Avis reçus récemment
  Iterable<NotificationTrajet> _avisRecus(DateTime n) sync* {
    for (final e in _discussions.evaluationsRecues(monId)) {
      if (n.difference(e.date) > _fenetreHistorique) continue;
      yield NotificationTrajet(
        cle: 'avis:${e.trajetId}:${e.auteurId}',
        type: TypeNotification.avis,
        titre: 'Nouvel avis : ${e.note}/5',
        texte: e.commentaire.isEmpty
            ? '${e.auteurNom} vous a noté ${e.note}/5.'
            : '${e.auteurNom} : « ${e.commentaire} »',
        trajetId: e.trajetId,
        date: e.date,
      );
    }
  }

  /// Un passager a annulé sa réservation sur un trajet de l'utilisateur
  Future<void> signalerAnnulation(Trajet t, PassagerTrajet p,
      {DateTime? maintenant}) async {
    if (t.conducteurId != monId || p.passagerId == monId) return;
    final n = maintenant ?? DateTime.now();
    final nouvelle = NotificationTrajet(
      cle: 'annulation:${t.id}:${p.passagerId}:${n.millisecondsSinceEpoch}',
      type: TypeNotification.annulation,
      titre: 'Réservation annulée',
      texte: '${p.nom} a annulé (${_places(p.places)} libérée'
          '${p.places > 1 ? 's' : ''}) · ${t.villeDepart} → ${t.villeArrivee}, '
          '${tJourRelatif(t.dateDepart, maintenant: n)} à ${tHeure(t.dateDepart)}.',
      trajetId: t.id,
      date: n,
    );
    if (_notifications.any((x) => x.cle == nouvelle.cle)) return;
    _notifications.add(nouvelle);
    notifyListeners();
    await _sql(() => _db.ajouterNotification(nouvelle));
  }

  /// Le trajet a été supprimé : ses notifications (et ses options,
  /// dans la même base) disparaissent
  Future<void> supprimerTrajet(int trajetId) async {
    _notifications.removeWhere((n) => n.trajetId == trajetId);
    notifyListeners();
    await _sql(() => _db.supprimerTrajet(trajetId));
  }

  // ---------- Alertes de recherche ----------
  /// De la plus récente à la plus ancienne
  List<AlerteTrajet> get alertes => List.unmodifiable(_alertes);

  /// Crée une alerte puis signale aussitôt les trajets qui y correspondent.
  /// Retourne null si tout va bien, sinon l'erreur.
  Future<String?> creerAlerte({
    String depart = '',
    String arrivee = '',
    DateTime? jour,
    int? heure,
    MomentJournee? moment,
    int places = 1,
    DateTime? maintenant,
  }) async {
    final d = depart.trim(), a = arrivee.trim();
    if (d.isEmpty && a.isEmpty) {
      return 'Indiquez au moins la ville de départ ou d’arrivée.';
    }
    final n = maintenant ?? DateTime.now();
    final j = jour == null ? null : DateTime(jour.year, jour.month, jour.day);
    if (j != null && j.isBefore(DateTime(n.year, n.month, n.day))) {
      return 'Cette date est déjà passée.';
    }
    final existe = _alertes.any((x) =>
        normaliser(x.villeDepart) == normaliser(d) &&
        normaliser(x.villeArrivee) == normaliser(a) &&
        x.jour == j &&
        x.heure == heure &&
        x.moment == moment?.name);
    if (existe) return 'Vous avez déjà une alerte pour ce trajet.';
    if (_alertes.length >= maxAlertes) {
      return 'Vous avez déjà $maxAlertes alertes : supprimez-en une.';
    }

    final alerte = AlerteTrajet(
      villeDepart: d,
      villeArrivee: a,
      jour: j,
      heure: heure,
      moment: moment?.name,
      places: places.clamp(1, 4),
      dateCreation: n,
    );
    final prochainId = _alertes.fold<int>(0, (m, x) => (x.id ?? 0) > m ? x.id! : m) + 1;
    _alertes.insert(
        0, await _sql(() => _db.ajouterAlerte(alerte)) ?? alerte.copyWith(id: prochainId));
    notifyListeners();
    await verifier(maintenant: maintenant);
    return null;
  }

  Future<void> supprimerAlerte(AlerteTrajet a) async {
    _alertes.removeWhere((x) => x.id == a.id);
    notifyListeners();
    if (a.id != null) await _sql(() => _db.supprimerAlerte(a.id!));
  }

  /// Le trajet correspond-il à l'alerte ? (villes sans tenir compte des
  /// accents ; l'arrivée peut être une étape du trajet)
  static bool correspond(AlerteTrajet a, Trajet t) {
    bool memeVille(String ville, String cherchee) {
      if (cherchee.isEmpty) return true;
      final x = normaliser(ville), y = normaliser(cherchee);
      return x == y || x.contains(y) || y.contains(x);
    }

    if (!memeVille(t.villeDepart, a.villeDepart)) return false;
    if (!memeVille(t.villeArrivee, a.villeArrivee) &&
        !t.etapes.any((e) => memeVille(e.ville, a.villeArrivee))) {
      return false;
    }
    final j = a.jour;
    if (j != null &&
        (t.dateDepart.year != j.year ||
            t.dateDepart.month != j.month ||
            t.dateDepart.day != j.day)) {
      return false;
    }
    if (a.heure != null) {
      if ((t.dateDepart.hour - a.heure!).abs() > 2) return false;
    } else if (a.moment != null) {
      final m = MomentJournee.values.asNameMap()[a.moment];
      if (m != null && !m.contient(t.dateDepart)) return false;
    }
    return t.placesDispo >= a.places;
  }

  /// Trajets d'autres conducteurs, encore réservables, qui correspondent
  /// à une alerte (une seule notification par trajet)
  Iterable<NotificationTrajet> _alertesTrouvees(DateTime n) sync* {
    if (_alertes.isEmpty) return;
    for (final t in _trajets()) {
      if (t.conducteurId == monId ||
          t.statut != StatutTrajet.publie ||
          !t.dateDepart.isAfter(n) ||
          _discussions.reservationDe(t.id, monId) != null) {
        continue;
      }
      for (final a in _alertes) {
        if (a.id == null || !correspond(a, t)) continue;
        yield NotificationTrajet(
          cle: 'alerte:${a.id}:${t.id}',
          type: TypeNotification.alerte,
          titre: 'Trajet trouvé : ${t.villeDepart} → ${t.villeArrivee}',
          texte: '${t.conducteurNom} part '
              '${tJourRelatif(t.dateDepart, maintenant: n)} à '
              '${tHeure(t.dateDepart)} · ${tPrix(t.prixPlace)} la place, '
              '${_places(t.placesDispo)} libre${t.placesDispo > 1 ? 's' : ''}.',
          trajetId: t.id,
          date: n,
        );
        break;
      }
    }
  }

  /// Exécute l'écriture SQLite (sauf sur le web) sans bloquer l'écran
  /// en cas d'erreur : la copie en mémoire reste à jour.
  Future<T?> _sql<T>(Future<T> Function() action) async {
    if (!_persister) return null;
    try {
      return await action();
    } catch (e) {
      debugPrint('NotificationService : erreur SQLite : $e');
      return null;
    }
  }

  // ------------------------------------------------------------
  // DÉMONSTRATION (premier lancement) : une alerte « Tunis → Sousse »
  // qui correspond déjà à un trajet proposé par un autre conducteur.
  // ------------------------------------------------------------
  Future<void> _insererDemo() async {
    final a = AlerteTrajet(
      villeDepart: 'Tunis',
      villeArrivee: 'Sousse',
      dateCreation: DateTime.now().subtract(const Duration(days: 1)),
    );
    _alertes.add(await _sql(() => _db.ajouterAlerte(a)) ?? a.copyWith(id: 1));
  }
}

/// « 1 place », « 3 places »
String _places(int n) => '$n place${n > 1 ? 's' : ''}';
