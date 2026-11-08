// ============================================================
//  MODULE : GESTION DES TRAJETS (Yassine)
//  Fichier : lib/features/trajet/services/discussion_service.dart
//
//  Discussion d'un trajet entre le conducteur et ses passagers.
//  Règles de gestion :
//   - elle s'ouvre 2 h avant le départ (avant : verrouillée, on
//     affiche l'heure d'ouverture) ;
//   - elle reste ouverte pendant le trajet ;
//   - quand le trajet est terminé ou annulé, elle passe en lecture seule ;
//   - seuls le conducteur et les passagers ayant réservé y écrivent.
//  Le service gère aussi l'équipage du trajet :
//   - les passagers (réservations) ; un passager peut annuler jusqu'à
//     30 min avant le départ ;
//   - le pointage au départ : dès l'ouverture de la discussion, le
//     conducteur marque chaque passager présent ou absent ;
//   - les évaluations : une fois le trajet terminé, le conducteur note
//     ses passagers présents et chaque passager note le conducteur
//     (une seule note par personne et par trajet).
//  Même fonctionnement que TrajetService : copie en mémoire + SQLite
//  (sur le web, tout reste en mémoire).
// ============================================================

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/discussion_database.dart';
import '../../../models/discussion_trajet.dart';
import '../../../models/trajet.dart';
import '../utils/trajet_format.dart';

enum EtatDiscussion { verrouillee, ouverte, lectureSeule }

/// La discussion s'ouvre ce temps-là avant l'heure de départ
const Duration ouvertureAvantDepart = Duration(hours: 2);

/// Longueur maximale d'un message
const int longueurMaxMessage = 500;

/// Un passager peut annuler sa réservation jusqu'à ce délai avant le départ
const Duration delaiAnnulationPassager = Duration(minutes: 30);

/// Longueur maximale du commentaire d'une évaluation
const int longueurMaxCommentaire = 300;

/// Une personne à noter après le trajet
typedef CibleEvaluation = ({int id, String nom, bool conducteur});

DateTime ouvertureDiscussion(Trajet t) =>
    t.dateDepart.subtract(ouvertureAvantDepart);

EtatDiscussion etatDiscussion(Trajet t, {DateTime? maintenant}) {
  if (t.statut == StatutTrajet.termine || t.statut == StatutTrajet.annule) {
    return EtatDiscussion.lectureSeule;
  }
  if (t.statut == StatutTrajet.enCours) return EtatDiscussion.ouverte;
  final n = maintenant ?? DateTime.now();
  return n.isBefore(ouvertureDiscussion(t))
      ? EtatDiscussion.verrouillee
      : EtatDiscussion.ouverte;
}

class DiscussionService extends ChangeNotifier {
  DiscussionService._() : _persister = !kIsWeb;

  static final DiscussionService instance = DiscussionService._();

  /// Service sans SQLite, pour les tests
  @visibleForTesting
  DiscussionService.enMemoire() : _persister = false;

  final bool _persister;
  final DiscussionDatabase _db = DiscussionDatabase.instance;

  final List<PassagerTrajet> _passagers = [];
  final List<MessageTrajet> _messages = [];
  final List<EvaluationTrajet> _evaluations = [];

  /// trajet_id → date jusqu'à laquelle l'utilisateur connecté a lu
  final Map<int, DateTime> _lus = {};
  bool _charge = false;
  Future<void>? _chargement;

  bool get estCharge => _charge;

  // ---------- Chargement ----------
  /// Lit passagers, messages et lectures dans SQLite. Au premier
  /// lancement (aucun passager), crée les passagers de démonstration
  /// des trajets déjà réservés. Appelé par TrajetService.
  Future<void> charger(List<Trajet> trajets) =>
      _chargement ??= _charger(trajets);

  /// Oublie les données chargées (changement d'utilisateur) : le prochain
  /// charger() relit tout
  void reinitialiser() {
    _passagers.clear();
    _messages.clear();
    _evaluations.clear();
    _lus.clear();
    _charge = false;
    _chargement = null;
  }

  Future<void> _charger(List<Trajet> trajets) async {
    if (_persister) {
      try {
        _passagers.addAll(await _db.lirePassagers());
        _messages.addAll(await _db.lireMessages());
        _lus.addAll(await _db.lireLectures(monId));
        _evaluations.addAll(await _db.lireEvaluations());
      } catch (e) {
        debugPrint('DiscussionService : erreur de chargement SQLite : $e');
      }
    }
    // Base vide ou illisible : données de démonstration (comme TrajetService)
    if (_passagers.isEmpty) await _insererDemo(trajets);
    _charge = true;
    notifyListeners();
  }

  // ---------- Passagers ----------
  List<PassagerTrajet> passagers(int trajetId) =>
      _passagers.where((p) => p.trajetId == trajetId).toList();

  PassagerTrajet? reservationDe(int trajetId, int userId) {
    for (final p in _passagers) {
      if (p.trajetId == trajetId && p.passagerId == userId) return p;
    }
    return null;
  }

  /// Le conducteur et les passagers du trajet
  bool estParticipant(Trajet t, int userId) =>
      t.conducteurId == userId || reservationDe(t.id, userId) != null;

  int nbParticipants(Trajet t) => 1 + passagers(t.id).length;

  /// Trajets sur lesquels [userId] a réservé des places
  Set<int> trajetsReserves(int userId) => {
        for (final p in _passagers)
          if (p.passagerId == userId) p.trajetId,
      };

  /// Enregistre la réservation (ou ajoute des places à celle existante)
  Future<void> ajouterPassager(
      int trajetId, int passagerId, String nom, int places) async {
    final existante = reservationDe(trajetId, passagerId);
    if (existante != null) {
      final maj = existante.copyWith(places: existante.places + places);
      _passagers[_passagers.indexOf(existante)] = maj;
      await _sql(() => _db.modifierPassager(maj));
    } else {
      final p = PassagerTrajet(
          trajetId: trajetId, passagerId: passagerId, nom: nom, places: places);
      _passagers.add(await _sql(() => _db.ajouterPassager(p)) ?? p);
    }
    notifyListeners();
  }

  /// null si [passagerId] peut annuler sa réservation, sinon la raison
  String? motifRefusAnnulation(Trajet t, int passagerId, {DateTime? maintenant}) {
    if (reservationDe(t.id, passagerId) == null) {
      return 'Vous n’avez pas de réservation sur ce trajet.';
    }
    if (t.statut == StatutTrajet.enCours || !t.statut.estActif) {
      return 'Le trajet est ${t.statut.libelle.toLowerCase()} : '
          'la réservation ne peut plus être annulée.';
    }
    final limite = t.dateDepart.subtract(delaiAnnulationPassager);
    if (!(maintenant ?? DateTime.now()).isBefore(limite)) {
      return 'Trop tard pour annuler (moins de 30 min avant le départ). '
          'Prévenez le conducteur dans la discussion.';
    }
    return null;
  }

  /// Message dans la discussion (si elle est ouverte) quand un passager
  /// annule : le conducteur et les autres passagers sont prévenus
  Future<void> annoncerAnnulation(Trajet t, String nom) async {
    if (etatDiscussion(t) != EtatDiscussion.ouverte) return;
    await assurerOuverture(t);
    await _ajouter(MessageTrajet(
      trajetId: t.id,
      auteurId: 0,
      auteurNom: '',
      type: TypeMessageTrajet.systeme,
      texte: '$nom a annulé sa réservation.',
    ));
  }

  /// Retire des places à la réservation (et le passager s'il n'en a plus)
  Future<void> retirerPassager(int trajetId, int passagerId, int places) async {
    final p = reservationDe(trajetId, passagerId);
    if (p == null) return;
    final reste = p.places - places;
    if (reste > 0) {
      final maj = p.copyWith(places: reste);
      _passagers[_passagers.indexOf(p)] = maj;
      await _sql(() => _db.modifierPassager(maj));
    } else {
      _passagers.remove(p);
      if (p.id != null) await _sql(() => _db.supprimerPassager(p.id!));
    }
    notifyListeners();
  }

  // ---------- Pointage au départ ----------
  /// Le conducteur pointe ses passagers dès l'ouverture de la discussion
  /// (2 h avant le départ) et pendant le trajet
  bool pointagePossible(Trajet t, {DateTime? maintenant}) =>
      t.statut.estActif &&
      etatDiscussion(t, maintenant: maintenant) == EtatDiscussion.ouverte;

  /// Marque un passager présent ou absent.
  /// Retourne null si tout va bien, sinon l'erreur.
  Future<String?> marquerPresence(
    Trajet t,
    int passagerId,
    PresencePassager presence, {
    int? auteurId,
    DateTime? maintenant,
  }) async {
    auteurId ??= monId;
    if (auteurId != t.conducteurId) {
      return 'Seul le conducteur peut pointer les passagers.';
    }
    if (!pointagePossible(t, maintenant: maintenant)) {
      return t.statut.estActif
          ? 'Le pointage s’ouvre 2 h avant le départ.'
          : 'Le trajet est ${t.statut.libelle.toLowerCase()} : le pointage est fermé.';
    }
    final p = reservationDe(t.id, passagerId);
    if (p == null) return 'Ce passager n’a pas réservé ce trajet.';
    if (p.presence == presence) return null;

    final maj = p.copyWith(presence: presence);
    _passagers[_passagers.indexOf(p)] = maj;
    await _sql(() => _db.modifierPassager(maj));
    // Les autres participants voient qui est monté à bord
    if (presence == PresencePassager.present) {
      await assurerOuverture(t, maintenant: maintenant);
      await _ajouter(MessageTrajet(
        trajetId: t.id,
        auteurId: 0,
        auteurNom: '',
        type: TypeMessageTrajet.systeme,
        texte: '${p.nom} est à bord.',
        date: maintenant,
      ));
    }
    notifyListeners();
    return null;
  }

  /// Nombre de passagers pointés présents, absents et pas encore pointés
  ({int presents, int absents, int restants}) bilanPresence(int trajetId) {
    var presents = 0, absents = 0, restants = 0;
    for (final p in passagers(trajetId)) {
      switch (p.presence) {
        case PresencePassager.present:
          presents++;
        case PresencePassager.absent:
          absents++;
        case PresencePassager.inconnue:
          restants++;
      }
    }
    return (presents: presents, absents: absents, restants: restants);
  }

  // ---------- Évaluations après le trajet ----------
  EvaluationTrajet? evaluation(int trajetId, int auteurId, int cibleId) {
    for (final e in _evaluations) {
      if (e.trajetId == trajetId && e.auteurId == auteurId && e.cibleId == cibleId) {
        return e;
      }
    }
    return null;
  }

  /// Personnes que [userId] peut noter sur ce trajet terminé et qu'il
  /// n'a pas encore notées : le conducteur note ses passagers (sauf les
  /// absents), un passager présent note le conducteur.
  List<CibleEvaluation> aNoter(Trajet t, int userId) {
    if (t.statut != StatutTrajet.termine) return const [];
    final cibles = <CibleEvaluation>[];
    if (t.conducteurId == userId) {
      for (final p in passagers(t.id)) {
        if (p.presence != PresencePassager.absent) {
          cibles.add((id: p.passagerId, nom: p.nom, conducteur: false));
        }
      }
    } else {
      final moi = reservationDe(t.id, userId);
      if (moi != null && moi.presence != PresencePassager.absent) {
        cibles.add((id: t.conducteurId, nom: t.conducteurNom, conducteur: true));
      }
    }
    return cibles.where((c) => evaluation(t.id, userId, c.id) == null).toList();
  }

  /// Notes reçues par [userId], de la plus récente à la plus ancienne
  List<EvaluationTrajet> evaluationsRecues(int userId) =>
      _evaluations.where((e) => e.cibleId == userId).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  /// Moyenne (0 si aucune) et nombre des notes reçues par [userId]
  ({double moyenne, int nombre}) noteMoyenne(int userId) {
    final recues = evaluationsRecues(userId);
    if (recues.isEmpty) return (moyenne: 0, nombre: 0);
    final somme = recues.fold<int>(0, (s, e) => s + e.note);
    return (moyenne: somme / recues.length, nombre: recues.length);
  }

  /// Enregistre une note. Retourne null si tout va bien, sinon l'erreur.
  Future<String?> evaluer(
    Trajet t, {
    required int auteurId,
    required String auteurNom,
    required int cibleId,
    required int note,
    String commentaire = '',
  }) async {
    if (note < 1 || note > 5) {
      return 'La note doit être comprise entre 1 et 5 étoiles.';
    }
    final propre = commentaire.trim();
    if (propre.length > longueurMaxCommentaire) {
      return 'Commentaire trop long ($longueurMaxCommentaire caractères maximum).';
    }
    if (t.statut != StatutTrajet.termine) {
      return 'Vous pourrez noter une fois le trajet terminé.';
    }
    if (auteurId == cibleId) return 'Vous ne pouvez pas vous noter vous-même.';
    if (evaluation(t.id, auteurId, cibleId) != null) {
      return 'Vous avez déjà noté cette personne pour ce trajet.';
    }
    final cible = aNoter(t, auteurId).where((c) => c.id == cibleId).firstOrNull;
    if (cible == null) {
      return 'Seuls les participants présents peuvent se noter entre eux.';
    }

    final e = EvaluationTrajet(
      trajetId: t.id,
      auteurId: auteurId,
      auteurNom: auteurNom,
      cibleId: cibleId,
      cibleNom: cible.nom,
      note: note,
      commentaire: propre,
    );
    _evaluations.add(await _sql(() => _db.ajouterEvaluation(e)) ?? e);
    notifyListeners();
    return null;
  }

  // ---------- Messages ----------
  /// Messages du trajet, du plus ancien au plus récent
  /// (à date égale, dans l'ordre où ils ont été ajoutés)
  List<MessageTrajet> messages(int trajetId) {
    final liste = [
      for (final (i, m) in _messages.indexed)
        if (m.trajetId == trajetId) (i, m),
    ]..sort((a, b) {
        final c = a.$2.date.compareTo(b.$2.date);
        return c != 0 ? c : a.$1.compareTo(b.$1);
      });
    return [for (final (_, m) in liste) m];
  }

  /// Messages des autres participants que l'utilisateur n'a pas encore lus
  int nonLus(int trajetId) {
    final lu = _lus[trajetId];
    return _messages
        .where((m) =>
            m.trajetId == trajetId &&
            !m.estSysteme &&
            m.auteurId != monId &&
            (lu == null || m.date.isAfter(lu)))
        .length;
  }

  /// Envoie un message. Retourne null si tout va bien, sinon l'erreur.
  Future<String?> envoyer(
    Trajet t, {
    required int auteurId,
    required String auteurNom,
    required String texte,
    TypeMessageTrajet type = TypeMessageTrajet.texte,
    DateTime? maintenant,
  }) async {
    final propre = texte.trim();
    if (propre.isEmpty) return 'Le message est vide.';
    if (propre.length > longueurMaxMessage) {
      return 'Message trop long ($longueurMaxMessage caractères maximum).';
    }
    if (!estParticipant(t, auteurId)) {
      return 'Seuls le conducteur et les passagers du trajet peuvent écrire ici.';
    }
    switch (etatDiscussion(t, maintenant: maintenant)) {
      case EtatDiscussion.verrouillee:
        final o = ouvertureDiscussion(t);
        return 'La discussion s’ouvrira ${tJourRelatif(o, maintenant: maintenant)} '
            'à ${tHeure(o)} (2 h avant le départ).';
      case EtatDiscussion.lectureSeule:
        return 'Le trajet est terminé : la discussion est en lecture seule.';
      case EtatDiscussion.ouverte:
        break;
    }

    await assurerOuverture(t, maintenant: maintenant);
    await _ajouter(MessageTrajet(
      trajetId: t.id,
      auteurId: auteurId,
      auteurNom: auteurNom,
      texte: propre,
      type: type,
      date: maintenant,
    ));
    if (auteurId == monId) await marquerLu(t.id, maintenant: maintenant);
    return null;
  }

  /// Ajoute le message « Discussion ouverte » (une seule fois), daté de
  /// l'heure d'ouverture pour qu'il reste en tête du fil. Si le
  /// conducteur démarre plus tôt, elle s'ouvre à ce moment-là.
  Future<void> assurerOuverture(Trajet t, {DateTime? maintenant}) async {
    if (etatDiscussion(t, maintenant: maintenant) == EtatDiscussion.verrouillee) {
      return;
    }
    final dejaOuverte = _messages.any((m) =>
        m.trajetId == t.id &&
        m.estSysteme &&
        m.texte.startsWith(_texteOuverture));
    if (dejaOuverte) return;

    final n = maintenant ?? DateTime.now();
    final ouverture = ouvertureDiscussion(t);
    final enAvance = n.isBefore(ouverture);
    final lieu = t.adresseDepart.isNotEmpty
        ? '${t.adresseDepart}, ${t.villeDepart}'
        : t.villeDepart;
    await _ajouter(MessageTrajet(
      trajetId: t.id,
      auteurId: 0,
      auteurNom: '',
      type: TypeMessageTrajet.systeme,
      date: enAvance ? n : ouverture,
      texte: '$_texteOuverture${enAvance ? '' : ' 2 h avant le départ'}. '
          'Rendez-vous à $lieu à ${tHeure(t.dateDepart)}.',
    ));
  }

  static const String _texteOuverture = 'Discussion ouverte';

  /// Message système quand le conducteur démarre, termine ou annule le trajet
  Future<void> signalerStatut(Trajet t, StatutTrajet statut) async {
    final texte = switch (statut) {
      StatutTrajet.enCours => '${t.conducteurNom} a démarré le trajet. Bonne route !',
      StatutTrajet.termine =>
        'Trajet terminé, merci à tous ! La discussion passe en lecture seule.',
      StatutTrajet.annule => 'Le trajet a été annulé par le conducteur.',
      _ => null,
    };
    if (texte == null) return;
    if (statut == StatutTrajet.enCours) await assurerOuverture(t);
    await _ajouter(MessageTrajet(
      trajetId: t.id,
      auteurId: 0,
      auteurNom: '',
      texte: texte,
      type: TypeMessageTrajet.systeme,
    ));
  }

  /// Tout est lu jusqu'à maintenant (à l'ouverture de la discussion)
  Future<void> marquerLu(int trajetId, {DateTime? maintenant}) async {
    if (_lus.containsKey(trajetId) && nonLus(trajetId) == 0) return;
    final date = maintenant ?? DateTime.now();
    _lus[trajetId] = date;
    await _sql(() => _db.enregistrerLecture(trajetId, monId, date));
    notifyListeners();
  }

  /// Le trajet a été supprimé : on efface sa discussion, ses passagers
  /// et ses évaluations
  Future<void> supprimerTrajet(int trajetId) async {
    _passagers.removeWhere((p) => p.trajetId == trajetId);
    _messages.removeWhere((m) => m.trajetId == trajetId);
    _evaluations.removeWhere((e) => e.trajetId == trajetId);
    _lus.remove(trajetId);
    await _sql(() => _db.supprimerTrajet(trajetId));
    notifyListeners();
  }

  Future<void> _ajouter(MessageTrajet m) async {
    _messages.add(await _sql(() => _db.ajouterMessage(m)) ?? m);
    notifyListeners();
  }

  /// Exécute l'écriture SQLite (sauf sur le web) sans bloquer l'écran
  /// en cas d'erreur : la copie en mémoire reste à jour.
  Future<T?> _sql<T>(Future<T> Function() action) async {
    if (!_persister) return null;
    try {
      return await action();
    } catch (e) {
      debugPrint('DiscussionService : erreur SQLite : $e');
      return null;
    }
  }

  // ------------------------------------------------------------
  // DONNÉES DE DÉMONSTRATION (premier lancement seulement)
  // Chaque trajet déjà réservé reçoit des passagers fictifs ;
  // l'utilisateur devient passager du premier trajet réservable et du
  // premier trajet terminé d'un autre conducteur (pour le noter) ; les
  // passagers des trajets terminés sont pointés présents et deux
  // d'entre eux ont noté l'utilisateur ; les discussions déjà ouvertes
  // reçoivent deux messages.
  // ------------------------------------------------------------
  Future<void> _insererDemo(List<Trajet> trajets) async {
    const noms = [
      'Amira S.', 'Youssef M.', 'Ines B.', 'Karim D.',
      'Rania H.', 'Omar F.', 'Sarra L.', 'Nour K.',
    ];
    var k = 0;
    var moiPassager = false;
    var moiPassagerTermine = false;
    var avisRecus = false;
    // Trajets actifs d'abord (du plus proche au plus lointain), puis l'historique
    final parDate = [...trajets]
      ..sort((a, b) {
        if (a.statut.estActif != b.statut.estActif) {
          return a.statut.estActif ? -1 : 1;
        }
        return a.dateDepart.compareTo(b.dateDepart);
      });

    for (final t in parDate) {
      var reste = t.placesReservees;
      if (reste <= 0) continue;
      final termine = t.statut == StatutTrajet.termine;
      if (t.conducteurId != monId &&
          ((!moiPassager && t.estReservable) ||
              (!moiPassagerTermine && termine))) {
        await ajouterPassager(t.id, monId, monNom, 1);
        if (termine) {
          moiPassagerTermine = true;
        } else {
          moiPassager = true;
        }
        reste--;
      }
      while (reste > 0) {
        final places = reste >= 2 && k.isOdd ? 2 : 1;
        await ajouterPassager(
            t.id, 100 + k % noms.length, noms[k % noms.length], places);
        reste -= places;
        k++;
      }

      final autres = passagers(t.id).where((p) => p.passagerId != monId).toList();

      if (termine) {
        // Trajet passé : tout le monde était à bord
        for (final p in passagers(t.id)) {
          final maj = p.copyWith(presence: PresencePassager.present);
          _passagers[_passagers.indexOf(p)] = maj;
          await _sql(() => _db.modifierPassager(maj));
        }
        // Deux passagers ont noté l'utilisateur (conducteur)
        if (!avisRecus && t.conducteurId == monId) {
          avisRecus = true;
          const avis = [
            (5, 'Ponctuel · Conduite sûre · Très agréable, merci !'),
            (4, 'Sympathique · Bon trajet, un peu de retard au départ.'),
          ];
          for (final (i, (note, commentaire)) in avis.indexed) {
            if (i >= autres.length) break;
            final e = EvaluationTrajet(
              trajetId: t.id,
              auteurId: autres[i].passagerId,
              auteurNom: autres[i].nom,
              cibleId: monId,
              cibleNom: monNom,
              note: note,
              commentaire: commentaire,
              date: t.dateArrivee.add(Duration(hours: 2 + i)),
            );
            _evaluations.add(await _sql(() => _db.ajouterEvaluation(e)) ?? e);
          }
        }
        continue;
      }
      if (autres.isEmpty ||
          !t.statut.estActif ||
          etatDiscussion(t) != EtatDiscussion.ouverte) {
        continue;
      }
      final n = DateTime.now();
      await assurerOuverture(t);
      await _ajouter(MessageTrajet(
        trajetId: t.id,
        auteurId: autres.first.passagerId,
        auteurNom: autres.first.nom,
        texte: 'Bonjour ! Je serai au point de rendez-vous à l’heure.',
        date: n.subtract(const Duration(minutes: 12)),
      ));
      if (autres.length > 1) {
        await _ajouter(MessageTrajet(
          trajetId: t.id,
          auteurId: autres[1].passagerId,
          auteurNom: autres[1].nom,
          texte: 'Est-ce que je peux mettre une valise dans le coffre ?',
          date: n.subtract(const Duration(minutes: 4)),
        ));
      }
    }
  }
}
