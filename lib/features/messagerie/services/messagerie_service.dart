import 'dart:async';
import 'dart:io' as io;

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/helpers.dart';
import '../../../models/trajet.dart';
import '../../reclamation/models/reclamation.dart';
import '../../reclamation/services/reclamation_service.dart';
import '../../trajet/services/trajet_service.dart';
import '../../user/models/user_model.dart';
import '../../user/services/user_service.dart';

import '../data/messagerie_provisoire.dart';
import '../data/messagerie_repository.dart';
import '../models/conversation.dart';
import '../models/membre.dart';
import '../models/message.dart';

import 'audio_service.dart';
import 'contexte_utilisateur.dart';
import 'filtre_contenu.dart';

export '../data/messagerie_provisoire.dart' show Reservation;

// ============================================================
// SERVICE MESSAGERIE
// Cache mémoire alimenté par MessagerieRepository (SQLite).
// ============================================================

/// Erreur métier avec un message prêt à afficher (français).
class MessagerieException implements Exception {
  final String message;

  const MessagerieException(this.message);

  @override
  String toString() => message;
}

class MessagerieService extends ChangeNotifier {
  MessagerieService._() {
    _reservations = List<Reservation>.of(reservationsProvisoires);
    _dernierIdUtilisateur = _moiId;
    UserService.instance.addListener(_surChangementUtilisateur);
    unawaited(charger());
  }

  static final MessagerieService instance = MessagerieService._();

  /// Les boutons de simulation restent désactivés en production.
  static const bool modeDemo = false;

  static const String _systemeId = 'systeme';

  final MessagerieRepository _repository =
      MessagerieRepository.instance;

  // ---------------------------------------------------------
  // CACHE
  // ---------------------------------------------------------

  List<Conversation> _conversations = const [];
  final Map<String, List<Message>> _messages = {};
  final Set<String> _messagesCharges = {};

  bool _charge = false;
  bool _enChargement = false;
  String? _erreurChargement;
  String? _utilisateurCharge;
  String? _dernierIdUtilisateur;
  Future<void>? _chargementEnCours;

  List<UserModel> _utilisateurs = const [];
  Future<void>? _chargementUtilisateurs;

  bool get estCharge => _charge;
  bool get estEnChargement => _enChargement;
  String? get erreurChargement => _erreurChargement;
  bool estConnecte() => _moiId.isNotEmpty;

  bool messagesChargees(String conversationId) =>
      _messagesCharges.contains(conversationId);

  /// Charge (ou recharge) les conversations depuis SQLite.
  Future<void> charger({bool force = false}) {
    if (!force && _charge && _utilisateurCharge == _moiId) {
      return Future<void>.value();
    }
    return _chargementEnCours ??= _charger().whenComplete(() {
      _chargementEnCours = null;
    });
  }

  Future<void> _charger() async {
    _enChargement = true;
    _erreurChargement = null;
    notifyListeners();

    final moi = _moiId;
    if (moi.isEmpty) {
      _conversations = const [];
      _messages.clear();
      _messagesCharges.clear();
      _utilisateurs = const [];
      _utilisateurCharge = null;
      _charge = true;
      _enChargement = false;
      notifyListeners();
      return;
    }

    try {
      final liste = await _repository.conversationsDeLUtilisateur();
      _conversations = _appliquerBloques(liste);
      _messages.clear();
      _messagesCharges.clear();
      _utilisateurCharge = moi;
      _charge = true;
      await chargerUtilisateurs();
    } catch (_) {
      _erreurChargement =
          'Impossible de charger vos conversations.';
      _charge = true;
    } finally {
      _enChargement = false;
      notifyListeners();
    }
  }

  /// Charge les messages d'une conversation dans le cache.
  Future<void> chargerMessages(
    String conversationId, {
    bool force = false,
  }) async {
    if (_moiId.isEmpty) return;
    if (!force && _messagesCharges.contains(conversationId)) {
      return;
    }

    try {
      _messages[conversationId] =
          await _repository.messagesDe(conversationId);
      _messagesCharges.add(conversationId);
      notifyListeners();
    } catch (_) {
      _erreurChargement =
          'Impossible de charger les messages.';
      notifyListeners();
    }
  }

  void _surChangementUtilisateur() {
    final id = _moiId;
    if (id == _dernierIdUtilisateur) return;

    _dernierIdUtilisateur = id;
    _conversations = const [];
    _messages.clear();
    _messagesCharges.clear();
    _charge = false;
    _utilisateurCharge = null;
    _bloques.clear();
    _envoisRecents.clear();
    _signalements = 0;
    _avertissements = 0;
    _suspensionFin = null;
    _utilisateurs = const [];
    _reservations = List<Reservation>.of(reservationsProvisoires);
    notifyListeners();

    unawaited(_rechargerApresChangement());
  }

  Future<void> _rechargerApresChangement() async {
    final chargement = _chargementEnCours;
    if (chargement != null) {
      await chargement;
    }
    await charger(force: true);
  }

  List<Conversation> _appliquerBloques(
    List<Conversation> liste,
  ) {
    return [
      for (final conversation in liste)
        _bloques.contains(conversation.id)
            ? conversation.copyWith(bloque: true)
            : conversation,
    ];
  }

  Future<void> _rechargerConversations() async {
    if (_moiId.isEmpty) {
      _conversations = const [];
      return;
    }
    try {
      _conversations = _appliquerBloques(
        await _repository.conversationsDeLUtilisateur(),
      );
      _utilisateurCharge = _moiId;
    } catch (_) {
      _erreurChargement =
          'Impossible de charger vos conversations.';
    }
  }

  Future<void> _rechargerMessages(String conversationId) async {
    try {
      _messages[conversationId] =
          await _repository.messagesDe(conversationId);
      _messagesCharges.add(conversationId);
    } catch (_) {
      _erreurChargement =
          'Impossible de charger les messages.';
    }
  }

  Future<void> _rafraichir(String conversationId) async {
    await _rechargerMessages(conversationId);
    await _rechargerConversations();
    notifyListeners();
  }

  // ---------------------------------------------------------
  // IDENTITÉ
  // ---------------------------------------------------------

  String get _moiId =>
      ContexteUtilisateur.instance.idConnecte ?? '';

  String get _moiNom =>
      ContexteUtilisateur.instance.nomConnecte ?? 'Moi';

  int _compteurMessages = 0;

  String _nouvelIdMessage() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_compteurMessages++}';

  String _nouvelIdConversation() =>
      'conv_${DateTime.now().microsecondsSinceEpoch}';

  /// Conversation actuellement ouverte (notifications).
  String? _conversationOuverteId;

  /// Horodatage des derniers messages envoyés (anti-abus).
  final List<DateTime> _envoisRecents = [];

  /// Nombre total de signalements (anti-abus).
  int _signalements = 0;

  /// Compteur d'avertissements pour langage inapproprié.
  int _avertissements = 0;

  /// Fin de la suspension d'envoi (après 3 avertissements).
  DateTime? _suspensionFin;

  /// Conversations bloquées (état de session).
  final Set<String> _bloques = {};

  /// Seuil anti-abus : messages par fenêtre.
  static const int _maxMessages = 5;
  static const Duration _fenetreEnvoi = Duration(seconds: 10);

  /// Nombre d'avertissements avant suspension.
  static const int _maxAvertissements = 3;

  /// Durée de la suspension d'envoi.
  static const Duration _dureeSuspension = Duration(seconds: 60);

  /// Durée maximale d'un message vocal.
  static const int dureeMaxVocalSecondes = 120;

  /// Durée minimale d'un message vocal.
  static const int dureeMinVocalSecondes = 1;

  /// Identifiant du vocal en cours de lecture (un seul à la fois).
  final ValueNotifier<String?> _vocalEnLecture =
      ValueNotifier<String?>(null);

  ValueListenable<String?> get vocalEnLecture => _vocalEnLecture;

  String? get vocalEnLectureId => _vocalEnLecture.value;

  // ---------------------------------------------------------
  // TRAJETS ET RÉSERVATIONS
  // ---------------------------------------------------------

  List<Reservation> _reservations = [];

  /// Charge les utilisateurs réellement inscrits (table `app_users`).
  Future<void> chargerUtilisateurs() {
    return _chargementUtilisateurs ??=
        _chargerUtilisateurs().whenComplete(() {
      _chargementUtilisateurs = null;
    });
  }

  Future<void> _chargerUtilisateurs() async {
    if (_moiId.isEmpty) {
      _utilisateurs = const [];
      return;
    }
    try {
      final liste = await UserService.instance.getAllUsersForAdmin();
      _utilisateurs = List<UserModel>.unmodifiable(liste);
    } catch (_) {
      _utilisateurs = const [];
    }
    notifyListeners();
  }

  UserModel? utilisateur(String userId) {
    for (final utilisateur in _utilisateurs) {
      if (utilisateur.id == userId) return utilisateur;
    }
    return null;
  }

  // ---------------------------------------------------------
  // LECTURE
  // ---------------------------------------------------------

  /// Conversations (cache) triées de la plus récente à la plus ancienne.
  List<Conversation> conversations() {
    return List<Conversation>.unmodifiable(_conversations);
  }

  /// Nombre total de messages non lus (toutes conversations).
  int get totalNonLus => _conversations.fold<int>(
        0,
        (total, conversation) => total + conversation.nonLus,
      );

  /// Conversation courante ou null si elle a été supprimée.
  Conversation? conversation(String conversationId) {
    final index = _indexDe(conversationId);
    if (index == -1) return null;
    return _conversations[index];
  }

  /// Signale qu'une conversation est ouverte (notifications).
  void ouvrirConversation(String conversationId) {
    _conversationOuverteId = conversationId;
  }

  /// Signale que la conversation n'est plus ouverte.
  void fermerConversation(String conversationId) {
    if (_conversationOuverteId == conversationId) {
      _conversationOuverteId = null;
    }
  }

  /// Messages d'une conversation (cache en lecture seule).
  List<Message> messagesDe(String conversationId) {
    return List<Message>.unmodifiable(
      _messages[conversationId] ?? const <Message>[],
    );
  }

  /// Trajets dont je suis le conducteur (création de groupe).
  ///
  /// Les trajets réels sont fournis par le module Trajets. Le module
  /// trajets identifie le conducteur courant par [monId].
  List<Trajet> trajetsConducteur() {
    if (_moiId.isEmpty) return const [];
    return List<Trajet>.unmodifiable(
      TrajetService.instance.mesTrajets(monId, aVenir: true),
    );
  }

  /// Trajet par identifiant.
  Trajet? trajet(String trajetId) {
    final id = int.tryParse(trajetId);
    if (id == null) return null;
    return TrajetService.instance.parId(id);
  }

  /// Passagers avec une réservation confirmée pour ce trajet.
  ///
  /// Seuls les passagers réellement inscrits (et non bannis/bloqués)
  /// sont proposés.
  List<Membre> passagersDuTrajet(String trajetId) {
    final resultat = <Membre>[];
    final vus = <String>{};
    for (final reservation in _reservations) {
      if (reservation.trajetId != trajetId ||
          !reservation.confirmee) {
        continue;
      }
      final passager = utilisateur(reservation.passagerId);
      if (passager == null ||
          passager.isBanni ||
          passager.isBloque ||
          passager.id == _moiId ||
          !vus.add(passager.id)) {
        continue;
      }
      resultat.add(
        Membre(id: passager.id, nom: passager.nomComplet),
      );
    }
    return List<Membre>.unmodifiable(resultat);
  }

  /// Vrai si l'utilisateur est bloqué dans une conversation privée.
  bool estUtilisateurBloque(String userId) {
    for (final conversation in _conversations) {
      if (conversation.type == TypeConversation.prive &&
          conversation.bloque &&
          conversation.membreParId(userId) != null) {
        return true;
      }
    }
    return false;
  }

  /// Utilisateurs avec qui une conversation privée peut être créée.
  Future<List<UserModel>> utilisateursDisponibles() async {
    if (_moiId.isEmpty) return const [];
    if (_utilisateurs.isEmpty) {
      await chargerUtilisateurs();
    }

    final resultat = <UserModel>[];
    for (final utilisateur in _utilisateurs) {
      if (utilisateur.id == _moiId ||
          utilisateur.isBanni ||
          utilisateur.isBloque ||
          estUtilisateurBloque(utilisateur.id)) {
        continue;
      }
      var dejaPrivee = false;
      try {
        dejaPrivee = await _repository.conversationPriveExiste(
          _moiId,
          utilisateur.id,
        );
      } catch (_) {
        dejaPrivee = false;
      }
      if (dejaPrivee) continue;
      resultat.add(utilisateur);
    }
    return List<UserModel>.unmodifiable(resultat);
  }

  // ---------------------------------------------------------
  // ÉCRITURE
  // ---------------------------------------------------------

  /// Envoie un message. Retourne vrai si le message a été masqué
  /// par le filtre anti-abus (langage inapproprié).
  Future<bool> envoyerMessage(
    String conversationId,
    String contenu,
  ) async {
    if (_moiId.isEmpty) {
      throw const MessagerieException(
        'Connectez-vous pour envoyer un message.',
      );
    }
    final conversation = this.conversation(conversationId);
    if (conversation == null) {
      throw const MessagerieException(
        'Conversation introuvable.',
      );
    }
    if (conversation.archive) {
      throw const MessagerieException(
        'Ce groupe est archivé : lecture seule.',
      );
    }
    if (conversation.bloque) {
      throw const MessagerieException(
        'Vous avez bloqué cet utilisateur : impossible '
        'd\'envoyer un message.',
      );
    }

    // Anti-abus : envoi suspendu après trop d'avertissements.
    if (estSuspendu) {
      throw MessagerieException(
        'Envoi suspendu, réessayez dans '
        '$secondesRestantes s',
      );
    }

    // Anti-abus : filtre des mots interdits.
    final inapproprie =
        FiltreContenu.instance.contientMotInterdit(contenu);

    final texte = inapproprie
        ? FiltreContenu.instance.masquer(contenu).trim()
        : _contenuBloque(contenu);
    if (texte.isEmpty) return false;

    // Anti-abus : 5 messages maximum par 10 secondes.
    _verifierRythme();

    if (inapproprie) {
      _avertissements++;
      if (_avertissements >= _maxAvertissements) {
        _suspensionFin =
            DateTime.now().add(_dureeSuspension);
      }
    }

    final message = Message(
      id: _nouvelIdMessage(),
      conversationId: conversationId,
      expediteurId: _moiId,
      expediteurNom: _moiNom,
      contenu: texte,
      dateEnvoi: DateTime.now(),
      type: TypeMessage.texte,
      statut: StatutMessage.envoye,
      masque: inapproprie,
    );

    await _repository.insererMessage(message);
    await _rafraichir(conversationId);

    // Simulation : livré après 1 seconde, lu après 3 secondes.
    _programmerStatuts(conversationId, message.id);

    return inapproprie;
  }

  /// Envoie un message vocal. La durée est bornée à 120 s.
  Future<Message> envoyerVocal(
    String conversationId,
    int dureeSecondes,
    String? cheminAudio,
  ) async {
    if (_moiId.isEmpty) {
      throw const MessagerieException(
        'Connectez-vous pour envoyer un message.',
      );
    }
    final conversation = this.conversation(conversationId);
    if (conversation == null) {
      throw const MessagerieException(
        'Conversation introuvable.',
      );
    }
    if (conversation.archive) {
      throw const MessagerieException(
        'Ce groupe est archivé : lecture seule.',
      );
    }
    if (conversation.bloque) {
      throw const MessagerieException(
        'Vous avez bloqué cet utilisateur : impossible '
        'd\'envoyer un message.',
      );
    }
    if (estSuspendu) {
      throw MessagerieException(
        'Envoi suspendu, réessayez dans '
        '$secondesRestantes s',
      );
    }
    if (dureeSecondes < dureeMinVocalSecondes) {
      throw const MessagerieException(
        'Message trop court',
      );
    }

    final duree = dureeSecondes > dureeMaxVocalSecondes
        ? dureeMaxVocalSecondes
        : dureeSecondes;

    // Anti-abus : 5 messages maximum par 10 secondes.
    _verifierRythme();

    final message = Message(
      id: _nouvelIdMessage(),
      conversationId: conversationId,
      expediteurId: _moiId,
      expediteurNom: _moiNom,
      contenu: 'Message vocal',
      dateEnvoi: DateTime.now(),
      type: TypeMessage.vocal,
      statut: StatutMessage.envoye,
      dureeSecondes: duree,
      cheminAudio: cheminAudio,
      ecoute: true,
    );

    await _repository.insererMessage(message);
    await _rafraichir(conversationId);

    // Simulation : livré après 1 seconde, lu après 3 secondes.
    _programmerStatuts(conversationId, message.id);

    return message;
  }

  /// Raison pour laquelle le micro est désactivé, ou null.
  String? motifMicroDesactive(String conversationId) {
    final conversation = this.conversation(conversationId);
    if (conversation == null) {
      return 'Conversation introuvable.';
    }
    if (conversation.archive) {
      return 'Groupe archivé : lecture seule.';
    }
    if (conversation.bloque) {
      return 'Vous avez bloqué cet utilisateur : '
          'envoi impossible.';
    }
    if (estSuspendu) {
      return 'Envoi suspendu, réessayez dans '
          '$secondesRestantes s.';
    }
    return null;
  }

  /// Marque un vocal comme écouté.
  Future<void> marquerEcoute(String messageId) async {
    for (final entree in _messages.entries) {
      final index = entree.value.indexWhere(
        (message) => message.id == messageId,
      );
      if (index == -1) continue;

      final message = entree.value[index];
      if (message.ecoute) return;

      final misAJour = message.copyWith(ecoute: true);
      await _repository.mettreAJourMessage(misAJour);
      entree.value[index] = misAJour;
      notifyListeners();
      return;
    }
  }

  /// Démarre la lecture d'un vocal (met les autres en pause).
  void demarrerLectureVocal(String messageId) {
    _vocalEnLecture.value = messageId;
  }

  /// Arrête la lecture d'un vocal s'il est toujours actif.
  void arreterLectureVocal(String messageId) {
    if (_vocalEnLecture.value == messageId) {
      _vocalEnLecture.value = null;
    }
  }

  /// Vrai si l'envoi est actuellement suspendu.
  bool get estSuspendu {
    final fin = _suspensionFin;
    if (fin == null) return false;
    if (DateTime.now().isAfter(fin)) {
      _suspensionFin = null;
      return false;
    }
    return true;
  }

  /// Secondes restantes avant la fin de la suspension.
  int get secondesRestantes {
    final fin = _suspensionFin;
    if (fin == null) return 0;
    final restantes =
        fin.difference(DateTime.now()).inSeconds;
    return restantes < 0 ? 0 : restantes;
  }

  /// Nombre d'avertissements de langage inapproprié.
  int get avertissements => _avertissements;

  /// Crée une conversation privée avec un utilisateur inscrit.
  ///
  /// Si une conversation privée existe déjà, elle est retournée
  /// au lieu d'en créer une seconde.
  Future<Conversation> creerConversationPrivee(
    UserModel destinataire,
  ) async {
    if (_moiId.isEmpty) {
      throw const MessagerieException(
        'Connectez-vous pour démarrer une conversation.',
      );
    }
    if (destinataire.id == _moiId) {
      throw const MessagerieException(
        'Vous ne pouvez pas discuter avec vous-même.',
      );
    }
    if (destinataire.isBanni) {
      throw const MessagerieException(
        'Cet utilisateur est banni.',
      );
    }
    if (destinataire.isBloque) {
      throw const MessagerieException(
        'Cet utilisateur est bloqué.',
      );
    }

    if (_utilisateurs.isEmpty) {
      await chargerUtilisateurs();
    }
    if (!_utilisateurs.any((u) => u.id == destinataire.id)) {
      throw const MessagerieException(
        'Cet utilisateur n\'existe pas.',
      );
    }
    if (estUtilisateurBloque(destinataire.id)) {
      throw const MessagerieException(
        'Cet utilisateur est bloqué.',
      );
    }

    final existante = _conversationPriveeAvec(destinataire.id);
    if (existante != null) return existante;

    var existeEnBase = false;
    try {
      existeEnBase = await _repository.conversationPriveExiste(
        _moiId,
        destinataire.id,
      );
    } catch (_) {
      existeEnBase = false;
    }
    if (existeEnBase) {
      await _rechargerConversations();
      notifyListeners();
      final rechargee = _conversationPriveeAvec(destinataire.id);
      if (rechargee != null) return rechargee;
    }

    final id = _nouvelIdConversation();
    final date = DateTime.now();
    final conversation = Conversation(
      id: id,
      type: TypeConversation.prive,
      titre: destinataire.nomComplet,
      trajetLabel: 'Conversation privée',
      membres: [
        Membre(id: _moiId, nom: _moiNom),
        Membre(id: destinataire.id, nom: destinataire.nomComplet),
      ],
      dernierMessage: '',
      dateDernierMessage: date,
      nonLus: 0,
      muet: false,
      createurId: _moiId,
      dateCreation: date,
    );

    await _repository.creerConversation(
      conversation,
      conversation.membres,
    );
    await _rechargerConversations();
    notifyListeners();
    return conversation;
  }

  Conversation? _conversationPriveeAvec(String userId) {
    for (final conversation in _conversations) {
      if (conversation.type == TypeConversation.prive &&
          conversation.membreParId(_moiId) != null &&
          conversation.membreParId(userId) != null) {
        return conversation;
      }
    }
    return null;
  }

  Future<Conversation> creerGroupe({
    required String titre,
    required Trajet trajet,
    required List<Membre> membres,
  }) async {
    if (_moiId.isEmpty) {
      throw const MessagerieException(
        'Connectez-vous pour créer un groupe.',
      );
    }

    final trajetComplet = this.trajet(trajet.id.toString());
    if (trajetComplet == null) {
      throw const MessagerieException(
        'Trajet introuvable.',
      );
    }

    // Règle 1 : seul le conducteur peut créer le groupe.
    if (trajetComplet.conducteurId != monId) {
      throw const MessagerieException(
        'Seul le conducteur du trajet peut créer '
        'le groupe.',
      );
    }

    // Règle 2 : un seul groupe par trajet.
    if (_conversations.any(
      (conversation) =>
          conversation.trajetId == trajetComplet.id.toString(),
    )) {
      throw const MessagerieException(
        'Un groupe existe déjà pour ce trajet.',
      );
    }

    final titrePropre = titre.trim();
    if (titrePropre.isEmpty) {
      throw const MessagerieException(
        'Donnez un nom au groupe.',
      );
    }

    final autres = <Membre>[];
    for (final membre in membres) {
      if (membre.id == _moiId) continue;
      if (autres.any((m) => m.id == membre.id)) continue;
      autres.add(membre);
    }

    final membresFinaux = <Membre>[
      Membre(
        id: _moiId,
        nom: _moiNom,
        role: RoleMembre.conducteur,
      ),
      ...autres,
    ];

    // Règle 3 : capacité limitée aux places + 1 (conducteur).
    final capacite = trajetComplet.placesTotales + 1;
    if (membresFinaux.length > capacite) {
      throw MessagerieException(
        'Le groupe ne peut pas dépasser '
        '$capacite membres '
        '(places du trajet + 1).',
      );
    }

    // Règle 4 : uniquement des réservations confirmées.
    for (final membre in autres) {
      if (!_aReservationConfirmee(
        trajetComplet.id.toString(),
        membre.id,
      )) {
        throw MessagerieException(
          '${membre.nom} n\'a pas de réservation confirmée '
          'pour ce trajet.',
        );
      }
    }

    final id = _nouvelIdConversation();
    final date = DateTime.now();
    final conversation = Conversation(
      id: id,
      type: TypeConversation.groupe,
      titre: titrePropre,
      trajetLabel:
          '${trajetComplet.villeDepart} → '
          '${trajetComplet.villeArrivee} · '
          '${fDateCourte(trajetComplet.dateDepart)}',
      membres: membresFinaux,
      dernierMessage: '$_moiNom a créé ce groupe.',
      dateDernierMessage: date,
      nonLus: 0,
      muet: false,
      trajetId: trajetComplet.id.toString(),
      createurId: _moiId,
      dateCreation: date,
    );

    await _repository.creerConversation(
      conversation,
      membresFinaux,
    );
    await _rechargerConversations();
    await _insererMessageSysteme(
      id,
      'Le groupe « $titrePropre » '
      'a été créé par $_moiNom.',
      rafraichir: false,
    );
    await _rafraichir(id);

    return conversation;
  }

  Future<void> ajouterMembre(
    String conversationId,
    Membre membre,
  ) async {
    final conversation = _conversationModifiable(
      conversationId,
    );
    final trajetAssocie = _trajetDe(conversation);

    if (conversation.membreParId(membre.id) != null) {
      throw MessagerieException(
        '${membre.nom} est déjà membre du groupe.',
      );
    }

    if (conversation.membres.length + 1 >
        trajetAssocie.placesTotales + 1) {
      throw MessagerieException(
        'Le groupe est complet '
        '(${trajetAssocie.placesTotales + 1} membres maximum).',
      );
    }

    if (!_aReservationConfirmee(
      trajetAssocie.id.toString(),
      membre.id,
    )) {
      throw MessagerieException(
        '${membre.nom} n\'a pas de réservation confirmée '
        'pour ce trajet.',
      );
    }

    await _repository.ajouterMembre(conversationId, membre);
    await _insererMessageSysteme(
      conversationId,
      '${membre.nom} a rejoint le groupe.',
      rafraichir: false,
    );
    await _rafraichir(conversationId);
  }

  Future<void> retirerMembre(
    String conversationId,
    String membreId,
  ) async {
    final conversation = _conversationModifiable(
      conversationId,
    );
    final membre = conversation.membreParId(membreId);
    if (membre == null) return;

    if (membre.estConducteur ||
        conversation.createurId == membreId) {
      throw const MessagerieException(
        'Le conducteur ne peut pas être retiré du groupe.',
      );
    }

    await _repository.retirerMembre(conversationId, membreId);
    await _insererMessageSysteme(
      conversationId,
      '${membre.nom} a été retiré du groupe.',
      rafraichir: false,
    );
    await _rafraichir(conversationId);
  }

  Future<void> supprimerPourMoi(
    String conversationId,
    String messageId,
  ) async {
    _conversationModifiable(conversationId);
    final message = _trouverMessage(conversationId, messageId);
    if (message == null || message.estSysteme) return;

    await _repository.mettreAJourMessage(
      message.copyWith(supprimePourMoi: true),
    );
    await _rafraichir(conversationId);
  }

  bool estConducteurCreateurGroupe(Conversation conversation) {
    if (!conversation.estGroupe) return false;
    if (_moiId.isEmpty) return false;
    return conversation.createurId == _moiId;
  }

  Future<void> supprimerPourTous(
    String conversationId,
    String messageId,
  ) async {
    final conversation = _conversationModifiable(conversationId);
    final message = _trouverMessage(conversationId, messageId);
    if (message == null || message.estSysteme) return;
    if (message.estSignale) {
      throw const MessagerieException(
        'Message signalé : suppression pour tous impossible',
      );
    }

    final estMien = message.estMien;
    final estConducteur =
        estConducteurCreateurGroupe(conversation);
    final moinsDe10Min = DateTime.now()
            .difference(message.dateEnvoi)
            .inMinutes <
        10;

    if (!(estMien && moinsDe10Min) && !estConducteur) {
      throw const MessagerieException(
        'Suppression pour tous non autorisée.',
      );
    }

    if (message.estVocal &&
        message.cheminAudio != null &&
        message.cheminAudio!.isNotEmpty) {
      try {
        final fichier = io.File(message.cheminAudio!);
        if (fichier.existsSync()) {
          fichier.deleteSync();
        }
      } catch (_) {}
      if (AudioService.instance.messageIdEnCours == message.id) {
        try {
          await AudioService.instance.arreter();
        } catch (_) {}
        arreterLectureVocal(message.id);
      }
    }

    await _repository.mettreAJourMessage(
      message.copyWith(
        supprimePourTous: true,
        supprimePourMoi: true,
        dateSuppression: DateTime.now(),
      ),
    );
    await _rafraichir(conversationId);
  }

  /// Un passager annule sa réservation confirmée.
  Future<void> annulerReservation(
    String conversationId,
    String passagerId,
  ) async {
    final conversation = _conversationModifiable(
      conversationId,
    );
    final trajetAssocie = _trajetDe(conversation);

    final index = _reservations.indexWhere(
      (reservation) =>
          reservation.trajetId == trajetAssocie.id.toString() &&
          reservation.passagerId == passagerId &&
          reservation.confirmee,
    );

    if (index == -1) {
      throw MessagerieException(
        'Aucune réservation confirmée pour '
        '$passagerId.',
      );
    }

    final passagerNom =
        utilisateur(passagerId)?.nomComplet ?? passagerId;
    _reservations[index] =
        _reservations[index].copyWith(confirmee: false);

    if (conversation.membreParId(passagerId) != null) {
      await _repository.retirerMembre(
        conversationId,
        passagerId,
      );
    }

    await _insererMessageSysteme(
      conversationId,
      '$passagerNom a annulé sa réservation '
      'et a quitté le groupe.',
      rafraichir: false,
    );
    await _rafraichir(conversationId);
  }

  /// Le trajet est terminé, le groupe est archivé.
  Future<void> terminerTrajet(String conversationId) async {
    final conversation = this.conversation(conversationId);
    if (conversation == null) {
      throw const MessagerieException(
        'Conversation introuvable.',
      );
    }
    if (conversation.archive) {
      throw const MessagerieException(
        'Ce groupe est déjà archivé.',
      );
    }

    final trajetId = conversation.trajetId;
    if (trajetId == null) {
      throw const MessagerieException(
        'Ce groupe n\'est pas lié à un trajet.',
      );
    }

    final trajetAssocie = trajet(trajetId);
    if (trajetAssocie == null) {
      throw const MessagerieException(
        'Trajet introuvable.',
      );
    }
    if (trajetAssocie.statut != StatutTrajet.termine) {
      await TrajetService.instance.terminer(trajetAssocie.id);
    }

    await _repository.archiver(conversationId);
    await _insererMessageSysteme(
      conversationId,
      'Le trajet est terminé. '
      'Le groupe est archivé.',
      rafraichir: false,
    );
    await _rafraichir(conversationId);
  }

  /// Simulation : ajoute un message entrant dans la conversation.
  Future<String?> simulerMessageRecu(
    String conversationId,
  ) async {
    _verifierModeDemo();
    final conversation = this.conversation(conversationId);
    if (conversation == null) {
      throw const MessagerieException(
        'Conversation introuvable.',
      );
    }
    if (conversation.archive) {
      throw const MessagerieException(
        'Ce groupe est archivé : lecture seule.',
      );
    }
    if (conversation.bloque) {
      throw const MessagerieException(
        'Vous avez bloqué cet utilisateur : impossible '
        'de recevoir ses messages.',
      );
    }

    final expediteur = _expediteurSimule(conversation);
    final expediteurNom = conversation.estGroupe
        ? expediteur.nom
        : conversation.titre;

    final message = Message(
      id: _nouvelIdMessage(),
      conversationId: conversationId,
      expediteurId: expediteur.id,
      expediteurNom: expediteurNom,
      contenu: 'Message simulé reçu.',
      dateEnvoi: DateTime.now(),
      type: TypeMessage.texte,
      statut: StatutMessage.livre,
    );

    await _repository.insererMessage(message);
    await _rafraichir(conversationId);

    if (_conversationOuverteId == conversationId ||
        conversation.muet) {
      return null;
    }

    return 'Nouveau message de $expediteurNom';
  }

  /// Simulation : supprime le dernier message reçu.
  Future<String?> simulerSuppressionMessageRecu(
    String conversationId,
  ) async {
    _verifierModeDemo();
    final conversation = this.conversation(conversationId);
    if (conversation == null) {
      throw const MessagerieException('Conversation introuvable.');
    }
    if (conversation.archive) {
      throw const MessagerieException('Ce groupe est archivé : lecture seule.');
    }
    if (conversation.bloque) {
      throw const MessagerieException(
        'Vous avez bloqué cet utilisateur : impossible de recevoir ses messages.',
      );
    }

    final messages = _messages[conversationId];
    if (messages == null || messages.isEmpty) return null;

    // Trouver le dernier message reçu (pas mien, pas système)
    for (var i = messages.length - 1; i >= 0; i--) {
      final message = messages[i];
      if (message.estMien || message.estSysteme) continue;
      if (message.supprimePourTous) continue;

      if (message.estVocal &&
          message.cheminAudio != null &&
          message.cheminAudio!.isNotEmpty) {
        try {
          final fichier = io.File(message.cheminAudio!);
          if (fichier.existsSync()) {
            fichier.deleteSync();
          }
        } catch (_) {}
        if (AudioService.instance.messageIdEnCours == message.id) {
          try {
            await AudioService.instance.arreter();
          } catch (_) {}
          arreterLectureVocal(message.id);
        }
      }

      await _repository.mettreAJourMessage(
        message.copyWith(
          supprimePourTous: true,
          supprimePourMoi: true,
          dateSuppression: DateTime.now(),
        ),
      );
      await _rafraichir(conversationId);

      if (_conversationOuverteId == conversationId ||
          conversation.muet) {
        return null;
      }
      return 'Un message reçu a été supprimé';
    }
    return null;
  }

  /// Simulation : ajoute un vocal entrant.
  Future<String?> simulerVocalRecu(
    String conversationId,
    int dureeSecondes, {
    String? cheminAudio,
  }) async {
    _verifierModeDemo();
    final conversation = this.conversation(conversationId);
    if (conversation == null) {
      throw const MessagerieException(
        'Conversation introuvable.',
      );
    }
    if (conversation.archive) {
      throw const MessagerieException(
        'Ce groupe est archivé : lecture seule.',
      );
    }
    if (conversation.bloque) {
      throw const MessagerieException(
        'Vous avez bloqué cet utilisateur : impossible '
        'de recevoir ses messages.',
      );
    }

    final duree = dureeSecondes < 3
        ? 3
        : dureeSecondes > 45
            ? 45
            : dureeSecondes;

    final expediteur = _expediteurSimule(conversation);
    final expediteurNom = conversation.estGroupe
        ? expediteur.nom
        : conversation.titre;

    final message = Message(
      id: _nouvelIdMessage(),
      conversationId: conversationId,
      expediteurId: expediteur.id,
      expediteurNom: expediteurNom,
      contenu: 'Message vocal',
      dateEnvoi: DateTime.now(),
      type: TypeMessage.vocal,
      statut: StatutMessage.livre,
      dureeSecondes: duree,
      cheminAudio: cheminAudio,
      ecoute: false,
    );

    await _repository.insererMessage(message);
    await _rafraichir(conversationId);

    if (_conversationOuverteId == conversationId ||
        conversation.muet) {
      return null;
    }

    return 'Message vocal de $expediteurNom';
  }

  void _verifierModeDemo() {
    if (!modeDemo) {
      throw const MessagerieException(
        'Simulation désactivée.',
      );
    }
  }

  Future<void> quitterGroupe(String conversationId) async {
    if (_moiId.isNotEmpty) {
      try {
        await _repository.retirerMembre(
          conversationId,
          _moiId,
        );
      } catch (_) {}
    }

    _conversations = _conversations
        .where((conversation) => conversation.id != conversationId)
        .toList();
    _messages.remove(conversationId);
    _messagesCharges.remove(conversationId);
    await _rechargerConversations();
    notifyListeners();
  }

  /// Met à jour `last_read_at` et passe les messages entrants à « lu ».
  Future<void> marquerCommeLu(String conversationId) async {
    if (_moiId.isEmpty) return;

    try {
      await _repository.marquerCommeLu(conversationId);
    } catch (_) {
      return;
    }

    final messages = _messages[conversationId];
    if (messages != null) {
      for (final message in messages) {
        if (message.estMien ||
            message.estSysteme ||
            message.statut == StatutMessage.lu) {
          continue;
        }
        try {
          await _repository.mettreAJourMessage(
            message.copyWith(statut: StatutMessage.lu),
          );
        } catch (_) {}
      }
    }

    await _rechargerMessages(conversationId);
    await _rechargerConversations();
    notifyListeners();
  }

  Future<void> changerModeMuet(
    String conversationId,
    bool muet,
  ) async {
    try {
      await _repository.definirMuet(conversationId, muet);
    } catch (_) {}
    _mettreAJourConversation(
      conversationId,
      (conversation) => conversation.copyWith(muet: muet),
    );
  }

  // ---------------------------------------------------------
  // ANTI-ABUS
  // ---------------------------------------------------------

  /// Bloque ou débloque l'utilisateur d'une conversation privée.
  Future<void> basculerBloque(String conversationId) async {
    final conversation = this.conversation(conversationId);
    if (conversation == null) {
      throw const MessagerieException(
        'Conversation introuvable.',
      );
    }
    if (conversation.estGroupe) {
      throw const MessagerieException(
        'Seules les conversations privées peuvent être '
        'bloquées.',
      );
    }

    final bloque = !conversation.bloque;
    if (bloque) {
      _bloques.add(conversationId);
    } else {
      _bloques.remove(conversationId);
    }
    _mettreAJourConversation(
      conversationId,
      (conversation) => conversation.copyWith(bloque: bloque),
    );
  }

  /// Vrai si l'utilisateur de la conversation est bloqué.
  bool estBloque(String conversationId) {
    return conversation(conversationId)?.bloque ?? false;
  }

  /// Vrai si le contenu contient un numéro de téléphone ou un lien.
  bool contientContenuSensible(String contenu) {
    return _motifNumero.hasMatch(contenu) ||
        _motifLien.hasMatch(contenu);
  }

  /// Signale un message : le marque « Signalé », incrémente le
  /// compteur global et crée une vraie réclamation.
  Future<int> signalerMessage(
    String conversationId,
    String messageId, {
    String? motif,
  }) async {
    final message = _trouverMessage(conversationId, messageId);
    if (message == null) {
      throw const MessagerieException(
        'Message introuvable.',
      );
    }
    if (message.estSignale) {
      throw const MessagerieException(
        'Ce message est déjà signalé.',
      );
    }

    final conversation = this.conversation(conversationId);
    final motifPropre = (motif ?? '').trim();
    final contenu = message.estVocal
        ? 'Message vocal'
        : (message.contenu.trim().isEmpty
            ? 'Message vide'
            : message.contenu.trim());
    final extrait = contenu.length > 160
        ? '${contenu.substring(0, 160)}…'
        : contenu;
    final trajetLabel = (conversation?.trajetLabel ?? '').trim();

    ReclamationService.instance.ajouter(
      Reclamation(
        id: _prochainIdReclamation(),
        type: ReclamationType.autre,
        autreCategorie: 'Messagerie',
        sujet: motifPropre.isEmpty
            ? 'Message signalé'
            : 'Message signalé : $motifPropre',
        description:
            'Message de ${message.expediteurNom} dans '
            '« ${conversation?.titre ?? 'une conversation'} ». '
            'Motif : ${motifPropre.isEmpty ? 'non précisé' : motifPropre}. '
            'Contenu : $extrait',
        trajet: trajetLabel.isEmpty
            ? 'Conversation privée'
            : trajetLabel,
        date: DateTime.now(),
        status: ReclamationStatus.enAttente,
      ),
    );

    final misAJour = message.copyWith(
      signalements: message.signalements + 1,
    );
    await _repository.mettreAJourMessage(misAJour);

    final messages = _messages[conversationId];
    if (messages != null) {
      final index = messages.indexWhere(
        (m) => m.id == messageId,
      );
      if (index != -1) messages[index] = misAJour;
    }
    _signalements++;

    notifyListeners();
    return misAJour.signalements;
  }

  int _prochainIdReclamation() {
    final existantes = ReclamationService.instance.reclamations;
    if (existantes.isEmpty) {
      return DateTime.now().millisecondsSinceEpoch;
    }
    var maximum = existantes.first.id;
    for (final reclamation in existantes) {
      if (reclamation.id > maximum) maximum = reclamation.id;
    }
    return maximum + 1;
  }

  /// Nombre total de signalements effectués.
  int get totalSignalements => _signalements;

  // ---------------------------------------------------------
  // OUTILS INTERNES
  // ---------------------------------------------------------

  /// Détection d'un numéro de téléphone (8 à 15 chiffres,
  /// éventuellement séparés par des espaces, points ou tirets).
  static final RegExp _motifNumero = RegExp(
    r'(\+?\d[\d .\-]{6,}\d)',
  );

  /// Détection d'un lien (http, https, ftp ou www.).
  static final RegExp _motifLien = RegExp(
    r'(https?://\S+|ftp://\S+|www\.\S+)',
    caseSensitive: false,
  );

  /// Remplace numéros de téléphone et liens par « •••• ».
  String _contenuBloque(String contenu) {
    return contenu
        .trim()
        .replaceAll(_motifLien, '••••')
        .replaceAll(_motifNumero, '••••')
        .trim();
  }

  /// Anti-abus : refuse plus de 5 messages par 10 secondes.
  void _verifierRythme() {
    final maintenant = DateTime.now();
    _envoisRecents.removeWhere(
      (date) => maintenant.difference(date) > _fenetreEnvoi,
    );

    if (_envoisRecents.length >= _maxMessages) {
      throw const MessagerieException(
        'Vous envoyez trop vite. Réessayez dans '
        'quelques secondes.',
      );
    }

    _envoisRecents.add(maintenant);
  }

  int _indexDe(String conversationId) {
    return _conversations.indexWhere(
      (conversation) => conversation.id == conversationId,
    );
  }

  Message? _trouverMessage(
    String conversationId,
    String messageId,
  ) {
    final messages = _messages[conversationId];
    if (messages == null) return null;
    final index = messages.indexWhere(
      (message) => message.id == messageId,
    );
    return index == -1 ? null : messages[index];
  }

  void _programmerStatuts(
    String conversationId,
    String messageId,
  ) {
    Future<void>.delayed(const Duration(seconds: 1), () {
      unawaited(
        _changerStatut(
          conversationId,
          messageId,
          StatutMessage.livre,
        ),
      );
    });

    Future<void>.delayed(const Duration(seconds: 3), () {
      unawaited(
        _changerStatut(
          conversationId,
          messageId,
          StatutMessage.lu,
        ),
      );
    });
  }

  Future<void> _changerStatut(
    String conversationId,
    String messageId,
    StatutMessage statut,
  ) async {
    if (_moiId.isEmpty) return;

    final message = _trouverMessage(conversationId, messageId);
    if (message == null || message.statut == statut) return;

    try {
      await _repository.mettreAJourMessage(
        message.copyWith(statut: statut),
      );
    } catch (_) {
      return;
    }

    await _rechargerMessages(conversationId);
    notifyListeners();
  }

  Conversation _conversationModifiable(String conversationId) {
    final conversation = this.conversation(conversationId);
    if (conversation == null) {
      throw const MessagerieException(
        'Conversation introuvable.',
      );
    }
    if (conversation.archive) {
      throw const MessagerieException(
        'Ce groupe est archivé : lecture seule.',
      );
    }
    return conversation;
  }

  Trajet _trajetDe(Conversation conversation) {
    final trajetId = conversation.trajetId;
    if (trajetId == null) {
      throw const MessagerieException(
        'Ce groupe n\'est pas lié à un trajet.',
      );
    }

    final trajetAssocie = trajet(trajetId);
    if (trajetAssocie == null) {
      throw const MessagerieException(
        'Trajet introuvable.',
      );
    }
    return trajetAssocie;
  }

  bool _aReservationConfirmee(
    String trajetId,
    String passagerId,
  ) {
    final passager = utilisateur(passagerId);
    if (passager == null ||
        passager.isBanni ||
        passager.isBloque) {
      return false;
    }
    return _reservations.any(
      (reservation) =>
          reservation.trajetId == trajetId &&
          reservation.passagerId == passagerId &&
          reservation.confirmee,
    );
  }

  Membre _expediteurSimule(Conversation conversation) {
    if (conversation.membres.isEmpty) {
      return const Membre(id: 'usr_inconnu', nom: 'Un membre');
    }
    if (!conversation.estGroupe) {
      return conversation.membres.first;
    }
    for (final membre in conversation.membres) {
      if (membre.id != _moiId) return membre;
    }
    return conversation.membres.first;
  }

  Future<void> _insererMessageSysteme(
    String conversationId,
    String contenu, {
    bool rafraichir = true,
  }) async {
    final message = Message(
      id: _nouvelIdMessage(),
      conversationId: conversationId,
      expediteurId: _systemeId,
      expediteurNom: 'Système',
      contenu: contenu,
      dateEnvoi: DateTime.now(),
      type: TypeMessage.systeme,
      statut: StatutMessage.lu,
    );

    await _repository.insererMessage(message);

    if (rafraichir) {
      await _rafraichir(conversationId);
    }
  }

  void _mettreAJourConversation(
    String conversationId,
    Conversation Function(Conversation) transformation,
  ) {
    final index = _indexDe(conversationId);
    if (index == -1) return;

    final ancienne = _conversations[index];
    final nouvelle = transformation(ancienne);
    if (identical(nouvelle, ancienne)) return;

    _conversations[index] = nouvelle;
    notifyListeners();
  }
}
