import 'dart:io' as io;

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/helpers.dart';

import '../data/messagerie_mock.dart';
import '../models/conversation.dart';
import '../models/message.dart';

import 'audio_service.dart';
import 'filtre_contenu.dart';

export '../data/messagerie_mock.dart' show TrajetPropose;

// ============================================================
// SERVICE MESSAGERIE
// (données en mémoire, aucune base de données)
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
    _conversations = List<Conversation>.of(conversationsMock);
    _messages = {
      for (final entree in messagesMock.entries)
        entree.key: List<Message>.of(entree.value),
    };
    _trajets = List<TrajetPropose>.of(trajetsMock);
    _reservations = List<Reservation>.of(reservationsMock);
  }

  static final MessagerieService instance =
      MessagerieService._();

  late final List<Conversation> _conversations;
  late final Map<int, List<Message>> _messages;
  late final List<TrajetPropose> _trajets;
  late final List<Reservation> _reservations;

  /// Conversation actuellement ouverte (simulation de notification).
  int? _conversationOuverteId;

  /// Horodatage des derniers messages envoyés (anti-abus).
  final List<DateTime> _envoisRecents = [];

  /// Nombre total de signalements (anti-abus).
  int _signalements = 0;

  /// Compteur d'avertissements pour langage inapproprié.
  int _avertissements = 0;

  /// Fin de la suspension d'envoi (après 3 avertissements).
  DateTime? _suspensionFin;

  /// Seuil anti-abus : messages par fenêtre.
  static const int _maxMessages = 5;
  static const Duration _fenetreEnvoi = Duration(seconds: 10);

  /// Nombre d'avertissements avant suspension.
  static const int _maxAvertissements = 3;

  /// Durée de la suspension d'envoi.
  static const Duration _dureeSuspension = Duration(seconds: 60);

  /// Durée maximale d'un message vocal simulé.
  static const int dureeMaxVocalSecondes = 120;

  /// Durée minimale d'un message vocal.
  static const int dureeMinVocalSecondes = 1;

  /// Identifiant du vocal en cours de lecture (un seul à la fois).
  final ValueNotifier<int?> _vocalEnLecture =
      ValueNotifier<int?>(null);

  ValueListenable<int?> get vocalEnLecture => _vocalEnLecture;

  int? get vocalEnLectureId => _vocalEnLecture.value;

  // ---------------------------------------------------------
  // LECTURE
  // ---------------------------------------------------------

  /// Conversations triées de la plus récente à la plus ancienne,
  /// avec le nombre de non lus calculé depuis les messages.
  List<Conversation> conversations() {
    final liste = _conversations
        .map(
          (c) => c.copyWith(nonLus: _nonLusDe(c.id)),
        )
        .toList();
    liste.sort(
      (a, b) => b.dateDernierMessage.compareTo(
        a.dateDernierMessage,
      ),
    );
    return liste;
  }

  /// Nombre total de messages non lus (toutes conversations).
  int get totalNonLus => _conversations.fold<int>(
        0,
        (total, c) => total + _nonLusDe(c.id),
      );

  /// Conversation courante ou null si elle a été supprimée.
  Conversation? conversation(int conversationId) {
    final index = _indexDe(conversationId);
    if (index == -1) return null;

    return _conversations[index].copyWith(
      nonLus: _nonLusDe(conversationId),
    );
  }

  /// Signale qu'une conversation est ouverte (notifications).
  void ouvrirConversation(int conversationId) {
    _conversationOuverteId = conversationId;
  }

  /// Signale que la conversation n'est plus ouverte.
  void fermerConversation(int conversationId) {
    if (_conversationOuverteId == conversationId) {
      _conversationOuverteId = null;
    }
  }

  /// Messages d'une conversation (lecture seule).
  List<Message> messagesDe(int conversationId) {
    return List<Message>.unmodifiable(
      _messages[conversationId] ?? const <Message>[],
    );
  }

  /// Trajets dont je suis le conducteur (création de groupe).
  List<TrajetPropose> trajetsConducteur() {
    return List<TrajetPropose>.unmodifiable(
      _trajets
          .where((t) => t.conducteurId == monId)
          .toList(),
    );
  }

  /// Trajet par identifiant.
  TrajetPropose? trajet(int trajetId) {
    final index = _trajets.indexWhere(
      (t) => t.id == trajetId,
    );
    return index == -1 ? null : _trajets[index];
  }

  /// Passagers avec une réservation confirmée pour ce trajet.
  List<String> passagersDuTrajet(int trajetId) {
    return List<String>.unmodifiable(
      _reservations
          .where(
            (r) => r.trajetId == trajetId && r.confirmee,
          )
          .map((r) => r.passagerNom)
          .toList(),
    );
  }

  // ---------------------------------------------------------
  // ÉCRITURE
  // ---------------------------------------------------------

  /// Envoie un message. Retourne vrai si le message a été masqué
  /// par le filtre anti-abus (langage inapproprié).
  bool envoyerMessage(int conversationId, String contenu) {
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
      id: DateTime.now().millisecondsSinceEpoch,
      expediteurId: monId,
      expediteurNom: monNom,
      contenu: texte,
      dateEnvoi: DateTime.now(),
      type: TypeMessage.texte,
      statut: StatutMessage.envoye,
      masque: inapproprie,
    );

    _listeMessages(conversationId).add(message);

    _remplacerConversation(
      conversation.copyWith(
        dernierMessage: texte,
        dateDernierMessage: message.dateEnvoi,
      ),
    );

    notifyListeners();

    // Simulation : livré après 1 seconde, lu après 3 secondes.
    Future.delayed(const Duration(seconds: 1), () {
      _changerStatutMessage(
        conversationId,
        message.id,
        StatutMessage.livre,
      );
    });

    Future.delayed(const Duration(seconds: 3), () {
      _changerStatutMessage(
        conversationId,
        message.id,
        StatutMessage.lu,
      );
    });

    return inapproprie;
  }

  /// Envoie un message vocal. La durée est bornée à 120 s.
  Message envoyerVocal(
    int conversationId,
    int dureeSecondes,
    String? cheminAudio,
  ) {
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

    final date = DateTime.now();
    final message = Message(
      id: date.millisecondsSinceEpoch,
      expediteurId: monId,
      expediteurNom: monNom,
      contenu: 'Message vocal',
      dateEnvoi: date,
      type: TypeMessage.vocal,
      statut: StatutMessage.envoye,
      dureeSecondes: duree,
      cheminAudio: cheminAudio,
      ecoute: true,
    );

    _listeMessages(conversationId).add(message);

    _remplacerConversation(
      conversation.copyWith(
        dernierMessage:
            '🎤 Message vocal · '
            '${message.dureeVocalFormatee}',
        dateDernierMessage: date,
      ),
    );

    notifyListeners();

    // Simulation : livré après 1 seconde, lu après 3 secondes.
    Future.delayed(const Duration(seconds: 1), () {
      _changerStatutMessage(
        conversationId,
        message.id,
        StatutMessage.livre,
      );
    });

    Future.delayed(const Duration(seconds: 3), () {
      _changerStatutMessage(
        conversationId,
        message.id,
        StatutMessage.lu,
      );
    });

    return message;
  }

  /// Raison pour laquelle le micro est désactivé, ou null.
  String? motifMicroDesactive(int conversationId) {
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
  void marquerEcoute(int messageId) {
    for (final messages in _messages.values) {
      final index = messages.indexWhere(
        (m) => m.id == messageId,
      );
      if (index == -1) continue;

      if (messages[index].ecoute) return;

      messages[index] = messages[index].copyWith(
        ecoute: true,
      );
      notifyListeners();
      return;
    }
  }

  /// Démarre la lecture d'un vocal (met les autres en pause).
  void demarrerLectureVocal(int messageId) {
    _vocalEnLecture.value = messageId;
  }

  /// Arrête la lecture d'un vocal s'il est toujours actif.
  void arreterLectureVocal(int messageId) {
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



  Conversation creerGroupe({
    required String titre,
    required TrajetPropose trajet,
    required List<String> membres,
  }) {
    final trajetComplet = this.trajet(trajet.id);
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
      (c) => c.trajetId == trajetComplet.id,
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

    final autres = <String>[];
    for (final membre in membres) {
      if (membre == monNom) continue;
      if (!autres.contains(membre)) autres.add(membre);
    }

    final membresFinaux = <String>[
      monNom,
      ...autres,
    ];

    // Règle 3 : capacité limitée aux places + 1 (conducteur).
    if (membresFinaux.length >
        trajetComplet.capaciteGroupe) {
      throw MessagerieException(
        'Le groupe ne peut pas dépasser '
        '${trajetComplet.capaciteGroupe} membres '
        '(places du trajet + 1).',
      );
    }

    // Règle 4 : uniquement des réservations confirmées.
    for (final membre in autres) {
      if (!_aReservationConfirmee(
        trajetComplet.id,
        membre,
      )) {
        throw MessagerieException(
          '$membre n\'a pas de réservation confirmée '
          'pour ce trajet.',
        );
      }
    }

    final id = _conversations.fold<int>(
          0,
          (maximum, c) =>
              c.id > maximum ? c.id : maximum,
        ) +
        1;

    final date = DateTime.now();
    final conversation = Conversation(
      id: id,
      type: TypeConversation.groupe,
      titre: titrePropre,
      trajetLabel: '${trajetComplet.label} · '
          '${fDateCourte(trajetComplet.dateDepart)}',
      membres: membresFinaux,
      dernierMessage: '$monNom a créé ce groupe.',
      dateDernierMessage: date,
      nonLus: 0,
      muet: false,
      trajetId: trajetComplet.id,
    );

    _conversations.add(conversation);
    _messages[id] = <Message>[
      Message(
        id: date.millisecondsSinceEpoch,
        expediteurId: 0,
        expediteurNom: 'Système',
        contenu: 'Le groupe « $titrePropre » '
            'a été créé par $monNom.',
        dateEnvoi: date,
        type: TypeMessage.systeme,
        statut: StatutMessage.lu,
      ),
    ];

    notifyListeners();
    return conversation;
  }

  void ajouterMembre(int conversationId, String membre) {
    final conversation = _conversationModifiable(
      conversationId,
    );
    final trajetAssocie = _trajetDe(conversation);

    if (conversation.membres.contains(membre)) {
      throw MessagerieException(
        '$membre est déjà membre du groupe.',
      );
    }

    if (conversation.membres.length + 1 >
        trajetAssocie.capaciteGroupe) {
      throw MessagerieException(
        'Le groupe est complet '
        '(${trajetAssocie.capaciteGroupe} membres maximum).',
      );
    }

    if (!_aReservationConfirmee(
      trajetAssocie.id,
      membre,
    )) {
      throw MessagerieException(
        '$membre n\'a pas de réservation confirmée '
        'pour ce trajet.',
      );
    }

    _remplacerConversation(
      conversation.copyWith(
        membres: [
          ...conversation.membres,
          membre,
        ],
      ),
    );

    _ajouterMessageSysteme(
      conversationId,
      '$membre a rejoint le groupe.',
      notifier: false,
    );

    notifyListeners();
  }

  void retirerMembre(int conversationId, String membre) {
    final conversation = _conversationModifiable(
      conversationId,
    );

    if (conversation.membres.isNotEmpty &&
        conversation.membres.first == membre) {
      throw const MessagerieException(
        'Le conducteur ne peut pas être retiré du groupe.',
      );
    }

    if (!conversation.membres.contains(membre)) return;

    _remplacerConversation(
      conversation.copyWith(
        membres: conversation.membres
            .where((m) => m != membre)
            .toList(),
      ),
    );

    _ajouterMessageSysteme(
      conversationId,
      '$membre a été retiré du groupe.',
      notifier: false,
    );

    notifyListeners();
  }

  void supprimerPourMoi(int conversationId, int messageId) {
    final conversation = this.conversation(conversationId);
    if (conversation == null) {
      throw const MessagerieException('Conversation introuvable.');
    }
    if (conversation.archive) {
      throw const MessagerieException('Ce groupe est archivé : lecture seule.');
    }
    if (conversation.bloque) {
      throw const MessagerieException(
        'Vous avez bloqué cet utilisateur : impossible d\'envoyer un message.',
      );
    }

    final messages = _messages[conversationId];
    if (messages == null) return;
    final index = messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;
    final msg = messages[index];
    if (msg.estSysteme) return;

    messages[index] = msg.copyWith(supprimePourMoi: true);
    notifyListeners();
  }

  bool estConducteurCreateurGroupe(Conversation conversation) {
    if (!conversation.estGroupe || conversation.trajetId == null) return false;
    final t = trajet(conversation.trajetId!);
    return t != null && t.conducteurId == monId;
  }

  void supprimerPourTous(int conversationId, int messageId) {
    final conversation = this.conversation(conversationId);
    if (conversation == null) {
      throw const MessagerieException('Conversation introuvable.');
    }
    if (conversation.archive) {
      throw const MessagerieException('Ce groupe est archivé : lecture seule.');
    }
    if (conversation.bloque) {
      throw const MessagerieException(
        'Vous avez bloqué cet utilisateur : impossible d\'envoyer un message.',
      );
    }

    final messages = _messages[conversationId];
    if (messages == null) return;
    final index = messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;
    final msg = messages[index];
    if (msg.estSysteme) return;
    if (msg.estSignale) {
      throw const MessagerieException(
        'Message signalé : suppression pour tous impossible',
      );
    }

    final estMien = msg.estMien;
    final estConducteur = estConducteurCreateurGroupe(conversation);
    final moinsDe10Min =
        DateTime.now().difference(msg.dateEnvoi).inMinutes < 10;

    if (!(estMien && moinsDe10Min) && !estConducteur) {
      throw const MessagerieException(
        'Suppression pour tous non autorisée.',
      );
    }

    if (msg.estVocal && msg.cheminAudio != null && msg.cheminAudio!.isNotEmpty) {
      try {
        final f = io.File(msg.cheminAudio!);
        if (f.existsSync()) {
          f.deleteSync();
        }
      } catch (_) {}
      if (AudioService.instance.messageIdEnCours == msg.id) {
        try {
          AudioService.instance.arreter();
        } catch (_) {}
        arreterLectureVocal(msg.id);
      }
    }

    messages[index] = msg.copyWith(
      supprimePourTous: true,
      supprimePourMoi: true,
      dateSuppression: DateTime.now(),
    );

    if (!msg.estMien && _estNonLu(msg)) {
      // nonLus recalculés via copie
    }

    _mettreAJourDernierMessageApresSuppression(conversationId);
    notifyListeners();
  }

  void _mettreAJourDernierMessageApresSuppression(int conversationId) {
    final messages = _messages[conversationId];
    if (messages == null) return;
    Message? dernierVisible;
    for (var i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      if (m.estSysteme) {
        dernierVisible = m;
        break;
      }
      if (m.supprimePourTous) continue;
      if (m.supprimePourMoi) continue;
      dernierVisible = m;
      break;
    }
    if (dernierVisible == null) {
      final conv = conversation(conversationId);
      if (conv == null) return;
      _remplacerConversation(
        conv.copyWith(
          dernierMessage: 'Message supprimé',
          dateDernierMessage: DateTime.now(),
        ),
      );
      return;
    }
    final conv = conversation(conversationId);
    if (conv == null) return;
    String txt;
    if (dernierVisible.estSysteme) {
      txt = dernierVisible.contenu;
    } else if (dernierVisible.estVocal) {
      txt = '🎤 Message vocal · ${dernierVisible.dureeVocalFormatee}';
    } else {
      txt = dernierVisible.contenu;
    }
    _remplacerConversation(
      conv.copyWith(
        dernierMessage: txt,
        dateDernierMessage: dernierVisible.dateEnvoi,
      ),
    );
  }

  /// Simulation : un passager annule sa réservation.
  /// Il est retiré du groupe et un message système est ajouté.
  void annulerReservation(
    int conversationId,
    String passagerNom,
  ) {
    final conversation = _conversationModifiable(
      conversationId,
    );
    final trajetAssocie = _trajetDe(conversation);

    final index = _reservations.indexWhere(
      (r) =>
          r.trajetId == trajetAssocie.id &&
          r.passagerNom == passagerNom &&
          r.confirmee,
    );

    if (index == -1) {
      throw MessagerieException(
        'Aucune réservation confirmée pour '
        '$passagerNom.',
      );
    }

    _reservations[index] =
        _reservations[index].copyWith(confirmee: false);

    if (conversation.membres.contains(passagerNom)) {
      _remplacerConversation(
        conversation.copyWith(
          membres: conversation.membres
              .where((m) => m != passagerNom)
              .toList(),
        ),
      );
    }

    _ajouterMessageSysteme(
      conversationId,
      '$passagerNom a annulé sa réservation '
      'et a quitté le groupe.',
      notifier: false,
    );

    notifyListeners();
  }

  /// Simulation : le trajet est terminé, le groupe est archivé.
  void terminerTrajet(int conversationId) {
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

    final indexTrajet = _trajets.indexWhere(
      (t) => t.id == trajetId,
    );
    if (indexTrajet == -1) {
      throw const MessagerieException(
        'Trajet introuvable.',
      );
    }

    if (!_trajets[indexTrajet].termine) {
      _trajets[indexTrajet] =
          _trajets[indexTrajet].copyWith(termine: true);
    }

    _remplacerConversation(
      conversation.copyWith(archive: true),
    );

    _ajouterMessageSysteme(
      conversationId,
      'Le trajet est terminé. '
      'Le groupe est archivé.',
      notifier: false,
    );

    notifyListeners();
  }

  /// Simulation : ajoute un message entrant dans la conversation.
  /// Retourne le texte de notification à afficher, ou null si la
  /// conversation est ouverte ou en mode muet.
  String? simulerMessageRecu(int conversationId) {
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

    final expediteurNom = conversation.estGroupe
        ? conversation.membres.firstWhere(
            (m) => m != monNom,
            orElse: () => 'Un membre',
          )
        : conversation.titre;

    final date = DateTime.now();
    final message = Message(
      id: date.millisecondsSinceEpoch,
      expediteurId: -1,
      expediteurNom: expediteurNom,
      contenu: 'Message simulé reçu.',
      dateEnvoi: date,
      type: TypeMessage.texte,
      statut: StatutMessage.livre,
    );

    _listeMessages(conversationId).add(message);

    _remplacerConversation(
      conversation.copyWith(
        dernierMessage: message.contenu,
        dateDernierMessage: date,
      ),
    );

    notifyListeners();

    if (_conversationOuverteId == conversationId ||
        conversation.muet) {
      return null;
    }

    return 'Nouveau message de $expediteurNom';
  }

  /// Simulation : ajoute un vocal entrant.
  /// Retourne le texte de notification à afficher, ou null si la
  /// conversation est ouverte ou en mode muet.
  String? simulerSuppressionMessageRecu(int conversationId) {
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
      final m = messages[i];
      if (m.estMien || m.estSysteme) continue;
      if (m.supprimePourTous) continue;

      if (m.estVocal && m.cheminAudio != null && m.cheminAudio!.isNotEmpty) {
        try {
          final f = io.File(m.cheminAudio!);
          if (f.existsSync()) {
            f.deleteSync();
          }
        } catch (_) {}
        if (AudioService.instance.messageIdEnCours == m.id) {
          try {
            AudioService.instance.arreter();
          } catch (_) {}
          arreterLectureVocal(m.id);
        }
      }

      messages[i] = m.copyWith(
        supprimePourTous: true,
        supprimePourMoi: true,
        dateSuppression: DateTime.now(),
      );
      _mettreAJourDernierMessageApresSuppression(conversationId);
      notifyListeners();
      if (_conversationOuverteId == conversationId || conversation.muet) {
        return null;
      }
      return 'Un message reçu a été supprimé';
    }
    return null;
  }

  String? simulerVocalRecu(
    int conversationId,
    int dureeSecondes, {
    String? cheminAudio,
  }) {
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

    final expediteurNom = conversation.estGroupe
        ? conversation.membres.firstWhere(
            (m) => m != monNom,
            orElse: () => 'Un membre',
          )
        : conversation.titre;

    final date = DateTime.now();
    final message = Message(
      id: date.millisecondsSinceEpoch,
      expediteurId: -1,
      expediteurNom: expediteurNom,
      contenu: 'Message vocal',
      dateEnvoi: date,
      type: TypeMessage.vocal,
      statut: StatutMessage.livre,
      dureeSecondes: duree,
      cheminAudio: cheminAudio,
      ecoute: false,
    );

    _listeMessages(conversationId).add(message);

    _remplacerConversation(
      conversation.copyWith(
        dernierMessage:
            '🎤 Message vocal · '
            '${message.dureeVocalFormatee}',
        dateDernierMessage: date,
      ),
    );

    notifyListeners();

    if (_conversationOuverteId == conversationId ||
        conversation.muet) {
      return null;
    }

    return 'Message vocal de $expediteurNom';
  }

  void quitterGroupe(int conversationId) {
    _conversations.removeWhere(
      (c) => c.id == conversationId,
    );
    _messages.remove(conversationId);
    notifyListeners();
  }

  /// Passe tous les messages entrants non lus à « lu ».
  void marquerCommeLu(int conversationId) {
    final messages = _messages[conversationId];
    if (messages == null) return;

    var modifie = false;

    for (var i = 0; i < messages.length; i++) {
      final message = messages[i];
      if (message.estMien ||
          message.estSysteme ||
          message.statut == StatutMessage.lu) {
        continue;
      }

      messages[i] = message.copyWith(
        statut: StatutMessage.lu,
      );
      modifie = true;
    }

    if (!modifie) return;
    notifyListeners();
  }

  void changerModeMuet(int conversationId, bool muet) {
    _mettreAJourConversation(
      conversationId,
      (conversation) => conversation.copyWith(muet: muet),
    );
  }

  // ---------------------------------------------------------
  // ANTI-ABUS
  // ---------------------------------------------------------

  /// Bloque ou débloque l'utilisateur d'une conversation privée.
  void basculerBloque(int conversationId) {
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

    _remplacerConversation(
      conversation.copyWith(bloque: !conversation.bloque),
    );
    notifyListeners();
  }

  /// Vrai si l'utilisateur de la conversation est bloqué.
  bool estBloque(int conversationId) {
    return conversation(conversationId)?.bloque ?? false;
  }

  /// Vrai si le contenu contient un numéro de téléphone ou un lien.
  bool contientContenuSensible(String contenu) {
    return _motifNumero.hasMatch(contenu) ||
        _motifLien.hasMatch(contenu);
  }

  /// Signale un message : le marque « Signalé » et incrémente
  /// le compteur global de signalements. Retourne le nouveau total.
  int signalerMessage(int conversationId, int messageId) {
    final messages = _messages[conversationId];
    if (messages == null) {
      throw const MessagerieException(
        'Message introuvable.',
      );
    }

    final index = messages.indexWhere(
      (m) => m.id == messageId,
    );
    if (index == -1) {
      throw const MessagerieException(
        'Message introuvable.',
      );
    }

    messages[index] = messages[index].copyWith(
      signalements: messages[index].signalements + 1,
    );
    _signalements++;

    notifyListeners();
    return messages[index].signalements;
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

  int _indexDe(int conversationId) {
    return _conversations.indexWhere(
      (c) => c.id == conversationId,
    );
  }

  /// Un message est non lu s'il est entrant et pas encore « lu ».
  int _nonLusDe(int conversationId) {
    final messages = _messages[conversationId];
    if (messages == null) return 0;

    return messages.where(_estNonLu).length;
  }

  bool _estNonLu(Message message) {
    return !message.estMien &&
        !message.estSysteme &&
        message.statut != StatutMessage.lu;
  }

  void _changerStatutMessage(
    int conversationId,
    int messageId,
    StatutMessage statut,
  ) {
    final messages = _messages[conversationId];
    if (messages == null) return;

    final index = messages.indexWhere(
      (m) => m.id == messageId,
    );
    if (index == -1) return;

    messages[index] = messages[index].copyWith(
      statut: statut,
    );
    notifyListeners();
  }

  Conversation _conversationModifiable(int conversationId) {
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

  TrajetPropose _trajetDe(Conversation conversation) {
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
    int trajetId,
    String passagerNom,
  ) {
    return _reservations.any(
      (r) =>
          r.trajetId == trajetId &&
          r.passagerNom == passagerNom &&
          r.confirmee,
    );
  }

  List<Message> _listeMessages(int conversationId) {
    return _messages.putIfAbsent(
      conversationId,
      () => <Message>[],
    );
  }

  void _remplacerConversation(
    Conversation conversation,
  ) {
    final index = _indexDe(conversation.id);
    if (index == -1) return;
    _conversations[index] = conversation;
  }

  void _ajouterMessageSysteme(
    int conversationId,
    String contenu, {
    bool notifier = true,
  }) {
    final date = DateTime.now();

    _listeMessages(conversationId).add(
      Message(
        id: date.millisecondsSinceEpoch,
        expediteurId: 0,
        expediteurNom: 'Système',
        contenu: contenu,
        dateEnvoi: date,
        type: TypeMessage.systeme,
        statut: StatutMessage.lu,
      ),
    );

    final conversation = this.conversation(conversationId);
    if (conversation != null) {
      _remplacerConversation(
        conversation.copyWith(
          dernierMessage: contenu,
          dateDernierMessage: date,
        ),
      );
    }

    if (notifier) notifyListeners();
  }

  void _mettreAJourConversation(
    int conversationId,
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
