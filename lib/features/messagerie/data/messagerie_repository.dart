import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/database_service.dart';
import '../models/conversation.dart';
import '../models/membre.dart';
import '../models/message.dart';
import '../services/contexte_utilisateur.dart';

/// Accès SQLite aux conversations, membres et messages de la messagerie.
///
/// Toutes les lectures et écritures sont filtrées par l'utilisateur
/// connecté ([ContexteUtilisateur]) : une conversation n'est visible
/// que s'il en est membre.
class MessagerieRepository {
  MessagerieRepository._();

  static final MessagerieRepository instance = MessagerieRepository._();

  final DatabaseService _databaseService = DatabaseService.instance;
  SupabaseClient get _supabase => Supabase.instance.client;

  String _idUtilisateur() {
    final id = ContexteUtilisateur.instance.idConnecte;
    if (id == null || id.isEmpty) {
      throw StateError('Aucun utilisateur connecté.');
    }
    return id;
  }

  Future<void> _verifierMembre(Database db, String conversationId) async {
    final moi = _idUtilisateur();
    final lignes = await db.query(
      'msg_membre',
      columns: ['user_id'],
      where: 'conversation_id = ? AND user_id = ?',
      whereArgs: [conversationId, moi],
      limit: 1,
    );
    if (lignes.isEmpty) {
      throw StateError(
        "L'utilisateur connecté n'appartient pas à cette conversation.",
      );
    }
  }

  /// Conversations de l'utilisateur connecté, triées par date du dernier
  /// message décroissante.
  ///
  /// `dernierMessage` et `nonLus` sont calculés par requête :
  /// - dernier message = dernier message non supprimé (pour moi ou pour tous) ;
  /// - non lus = messages d'autres expéditeurs postérieurs au `last_read_at`
  ///   du membre connecté, non supprimés pour moi ni pour tous.
  Future<List<Conversation>> conversationsDeLUtilisateur() async {
    final moi = _idUtilisateur();
    final db = await _databaseService.database;
    await _syncRemote(db);

    final lignes = await db.rawQuery(
      '''
      SELECT c.*,
        (SELECT m.contenu FROM msg_message m
          WHERE m.conversation_id = c.id
            AND m.supprime_pour_tous = 0
            AND m.supprime_pour_moi = 0
          ORDER BY m.date_envoi DESC, m.id DESC
          LIMIT 1) AS dernier_contenu,
        (SELECT m.type FROM msg_message m
          WHERE m.conversation_id = c.id
            AND m.supprime_pour_tous = 0
            AND m.supprime_pour_moi = 0
          ORDER BY m.date_envoi DESC, m.id DESC
          LIMIT 1) AS dernier_type,
        (SELECT m.duree_secondes FROM msg_message m
          WHERE m.conversation_id = c.id
            AND m.supprime_pour_tous = 0
            AND m.supprime_pour_moi = 0
          ORDER BY m.date_envoi DESC, m.id DESC
          LIMIT 1) AS derniere_duree,
        (SELECT m.date_envoi FROM msg_message m
          WHERE m.conversation_id = c.id
            AND m.supprime_pour_tous = 0
            AND m.supprime_pour_moi = 0
          ORDER BY m.date_envoi DESC, m.id DESC
          LIMIT 1) AS derniere_date,
        (SELECT COUNT(*) FROM msg_message m
          JOIN msg_membre mb
            ON mb.conversation_id = m.conversation_id
           AND mb.user_id = ?
          WHERE m.conversation_id = c.id
            AND m.expediteur_id <> ?
            AND m.type <> ?
            AND (mb.last_read_at IS NULL OR m.date_envoi > mb.last_read_at)
            AND m.supprime_pour_tous = 0
            AND m.supprime_pour_moi = 0) AS non_lus
      FROM msg_conversation c
      JOIN msg_membre moi
        ON moi.conversation_id = c.id
       AND moi.user_id = ?
      ORDER BY derniere_date DESC, c.created_at DESC
    ''',
      [moi, moi, TypeMessage.systeme.name, moi],
    );

    final conversations = <Conversation>[];
    for (final ligne in lignes) {
      final conversation = Conversation.fromMap(ligne);
      final membres = await listerMembres(conversation.id);
      final dateDerniere =
          DateTime.tryParse(ligne['derniere_date']?.toString() ?? '') ??
          conversation.dateDernierMessage;

      conversations.add(
        conversation.copyWith(
          membres: membres,
          dernierMessage: _formaterDernierMessage(ligne),
          dateDernierMessage: dateDerniere,
          nonLus: (ligne['non_lus'] as int?) ?? 0,
        ),
      );
    }
    return conversations;
  }

  String _formaterDernierMessage(Map<String, Object?> ligne) {
    final contenu = ligne['dernier_contenu']?.toString();
    if (contenu == null || contenu.isEmpty) return '';

    if (ligne['dernier_type']?.toString() == TypeMessage.vocal.name) {
      final duree = (ligne['derniere_duree'] as int?) ?? 0;
      return '🎤 Message vocal · ${formaterDureeVocale(duree)}';
    }
    return contenu;
  }

  /// Messages d'une conversation, dans l'ordre chronologique.
  ///
  /// Les messages supprimés pour moi sont exclus. Ceux supprimés pour tous
  /// sont conservés (la bulle affiche alors « Ce message a été supprimé »).
  Future<List<Message>> messagesDe(String conversationId) async {
    final moi = _idUtilisateur();
    final db = await _databaseService.database;
    await _syncRemote(db);

    final lignes = await db.rawQuery(
      '''
      SELECT m.* FROM msg_message m
      WHERE m.conversation_id = ?
        AND (m.supprime_pour_moi = 0 OR m.supprime_pour_tous = 1)
        AND m.conversation_id IN (
          SELECT conversation_id FROM msg_membre WHERE user_id = ?
        )
      ORDER BY m.date_envoi ASC, m.id ASC
    ''',
      [conversationId, moi],
    );

    return lignes.map(Message.fromMap).toList();
  }

  /// Insère un message dans sa conversation.
  Future<void> insererMessage(Message message) async {
    final conversationId = message.conversationId;
    if (conversationId == null || conversationId.isEmpty) {
      throw ArgumentError('Le message doit être rattaché à une conversation.');
    }

    final db = await _databaseService.database;
    await _verifierMembre(db, conversationId);
    await db.insert(
      'msg_message',
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    try {
      await _supabase
          .from('msg_message')
          .upsert(_messageRemoteMap(message), onConflict: 'id');
    } catch (error) {
      debugPrint('[MessagerieRepository] Message non synchronisé : $error');
    }
  }

  /// Met à jour l'état d'un message (statut, signalement, masquage,
  /// écoute, suppression).
  Future<void> mettreAJourMessage(Message message) async {
    final moi = _idUtilisateur();
    final db = await _databaseService.database;

    await db.update(
      'msg_message',
      {
        'statut': message.statut.name,
        'signale': message.estSignale ? 1 : 0,
        'masque': message.masque ? 1 : 0,
        'ecoute': message.ecoute ? 1 : 0,
        'supprime_pour_tous': message.supprimePourTous ? 1 : 0,
        'supprime_pour_moi': message.supprimePourMoi ? 1 : 0,
        'date_suppression': message.dateSuppression?.toIso8601String(),
      },
      where: '''
        id = ? AND conversation_id IN (
          SELECT conversation_id FROM msg_membre WHERE user_id = ?
        )
      ''',
      whereArgs: [message.id, moi],
    );
    try {
      await _supabase
          .from('msg_message')
          .update(_messageRemoteMap(message))
          .eq('id', message.id);
    } catch (error) {
      debugPrint(
        '[MessagerieRepository] Mise à jour message non synchronisée : $error',
      );
    }
  }

  /// Crée une conversation et ses membres dans une seule transaction.
  Future<void> creerConversation(
    Conversation conversation,
    List<Membre> membres,
  ) async {
    final moi = _idUtilisateur();
    if (!membres.any((membre) => membre.id == moi)) {
      throw StateError(
        "L'utilisateur connecté doit faire partie de la conversation.",
      );
    }

    final db = await _databaseService.database;
    await db.transaction((txn) async {
      await txn.insert(
        'msg_conversation',
        conversation.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      for (final membre in membres) {
        await txn.insert('msg_membre', {
          'conversation_id': conversation.id,
          ...membre.toMap(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    try {
      await _supabase
          .from('msg_conversation')
          .upsert(_conversationRemoteMap(conversation), onConflict: 'id');
      await _supabase
          .from('msg_membre')
          .upsert(
            membres
                .map(
                  (membre) => {
                    'conversation_id': conversation.id,
                    ...membre.toMap(),
                  },
                )
                .toList(),
            onConflict: 'conversation_id,user_id',
          );
    } catch (error) {
      debugPrint(
        '[MessagerieRepository] Conversation non synchronisée : $error',
      );
    }
  }

  /// Ajoute un membre à une conversation dont l'utilisateur connecté
  /// fait partie.
  Future<void> ajouterMembre(String conversationId, Membre membre) async {
    final db = await _databaseService.database;
    await _verifierMembre(db, conversationId);
    await db.insert('msg_membre', {
      'conversation_id': conversationId,
      ...membre.toMap(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    try {
      await _supabase.from('msg_membre').upsert({
        'conversation_id': conversationId,
        ...membre.toMap(),
      }, onConflict: 'conversation_id,user_id');
    } catch (error) {
      debugPrint('[MessagerieRepository] Membre non synchronisé : $error');
    }
  }

  /// Retire un membre d'une conversation dont l'utilisateur connecté
  /// fait partie.
  Future<void> retirerMembre(String conversationId, String membreId) async {
    final db = await _databaseService.database;
    await _verifierMembre(db, conversationId);
    await db.delete(
      'msg_membre',
      where: 'conversation_id = ? AND user_id = ?',
      whereArgs: [conversationId, membreId],
    );
    try {
      await _supabase
          .from('msg_membre')
          .delete()
          .eq('conversation_id', conversationId)
          .eq('user_id', membreId);
    } catch (error) {
      debugPrint(
        '[MessagerieRepository] Suppression membre non synchronisée : $error',
      );
    }
  }

  /// Membres d'une conversation, conducteur en premier.
  Future<List<Membre>> listerMembres(String conversationId) async {
    final moi = _idUtilisateur();
    final db = await _databaseService.database;

    final lignes = await db.rawQuery(
      '''
      SELECT * FROM msg_membre
      WHERE conversation_id = ?
        AND conversation_id IN (
          SELECT conversation_id FROM msg_membre WHERE user_id = ?
        )
      ORDER BY CASE role WHEN 'conducteur' THEN 0 ELSE 1 END,
               nom COLLATE NOCASE
    ''',
      [conversationId, moi],
    );

    return lignes.map(Membre.fromMap).toList();
  }

  /// Met à jour `last_read_at` du membre connecté.
  Future<void> marquerCommeLu(String conversationId) async {
    final moi = _idUtilisateur();
    final db = await _databaseService.database;

    await db.update(
      'msg_membre',
      {'last_read_at': DateTime.now().toIso8601String()},
      where: 'conversation_id = ? AND user_id = ?',
      whereArgs: [conversationId, moi],
    );
    try {
      await _supabase
          .from('msg_membre')
          .update({'last_read_at': DateTime.now().toIso8601String()})
          .eq('conversation_id', conversationId)
          .eq('user_id', moi);
    } catch (error) {
      debugPrint('[MessagerieRepository] Lecture non synchronisée : $error');
    }
  }

  /// Archive une conversation de l'utilisateur connecté.
  Future<void> archiver(String conversationId) async {
    final moi = _idUtilisateur();
    final db = await _databaseService.database;

    await db.update(
      'msg_conversation',
      {'archivee': 1},
      where: '''
        id = ? AND id IN (
          SELECT conversation_id FROM msg_membre WHERE user_id = ?
        )
      ''',
      whereArgs: [conversationId, moi],
    );
    try {
      await _supabase
          .from('msg_conversation')
          .update({'archivee': true})
          .eq('id', conversationId);
    } catch (error) {
      debugPrint('[MessagerieRepository] Archivage non synchronisé : $error');
    }
  }

  /// Active ou coupe le son d'une conversation de l'utilisateur connecté.
  Future<void> definirMuet(String conversationId, bool muet) async {
    final moi = _idUtilisateur();
    final db = await _databaseService.database;

    await db.update(
      'msg_conversation',
      {'muet': muet ? 1 : 0},
      where: '''
        id = ? AND id IN (
          SELECT conversation_id FROM msg_membre WHERE user_id = ?
        )
      ''',
      whereArgs: [conversationId, moi],
    );
    try {
      await _supabase
          .from('msg_conversation')
          .update({'muet': muet})
          .eq('id', conversationId);
    } catch (error) {
      debugPrint('[MessagerieRepository] Préférence non synchronisée : $error');
    }
  }

  /// Vrai s'il existe déjà une conversation privée entre ces deux
  /// utilisateurs (l'utilisateur connecté doit en faire partie).
  Future<bool> conversationPriveExiste(String userIdA, String userIdB) async {
    final moi = _idUtilisateur();
    final db = await _databaseService.database;

    final lignes = await db.rawQuery(
      '''
      SELECT c.id FROM msg_conversation c
      WHERE c.type = ?
        AND EXISTS (
          SELECT 1 FROM msg_membre m
          WHERE m.conversation_id = c.id AND m.user_id = ?
        )
        AND EXISTS (
          SELECT 1 FROM msg_membre m
          WHERE m.conversation_id = c.id AND m.user_id = ?
        )
        AND (SELECT COUNT(*) FROM msg_membre m
              WHERE m.conversation_id = c.id) = 2
        AND c.id IN (
          SELECT conversation_id FROM msg_membre WHERE user_id = ?
        )
      LIMIT 1
    ''',
      [TypeConversation.prive.name, userIdA, userIdB, moi],
    );

    return lignes.isNotEmpty;
  }

  Future<void> _syncRemote(Database db) async {
    try {
      final conversations = await _supabase.from('msg_conversation').select();
      final membres = await _supabase.from('msg_membre').select();
      final messages = await _supabase.from('msg_message').select();
      for (final row in conversations) {
        await db.insert(
          'msg_conversation',
          _localConversationMap(Map<String, dynamic>.from(row)),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final row in membres) {
        await db.insert(
          'msg_membre',
          _localMemberMap(Map<String, dynamic>.from(row)),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final row in messages) {
        await db.insert(
          'msg_message',
          _localMessageMap(Map<String, dynamic>.from(row)),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (error) {
      debugPrint(
        '[MessagerieRepository] Synchronisation distante impossible : $error',
      );
    }
  }

  Map<String, dynamic> _conversationRemoteMap(Conversation value) => {
    ...value.toMap(),
    'archivee': value.archive,
    'muet': value.muet,
  };

  Map<String, dynamic> _messageRemoteMap(Message value) => {
    ...value.toMap(),
    'ecoute': value.ecoute,
    'signale': value.estSignale,
    'masque': value.masque,
    'supprime_pour_tous': value.supprimePourTous,
    'supprime_pour_moi': value.supprimePourMoi,
  };

  Map<String, dynamic> _localConversationMap(Map<String, dynamic> value) => {
    ...value,
    'archivee': value['archivee'] == true ? 1 : value['archivee'],
    'muet': value['muet'] == true ? 1 : value['muet'],
  };

  Map<String, dynamic> _localMemberMap(Map<String, dynamic> value) => value;

  Map<String, dynamic> _localMessageMap(Map<String, dynamic> value) => {
    ...value,
    'ecoute': value['ecoute'] == true ? 1 : value['ecoute'],
    'signale': value['signale'] == true ? 1 : value['signale'],
    'masque': value['masque'] == true ? 1 : value['masque'],
    'supprime_pour_tous': value['supprime_pour_tous'] == true
        ? 1
        : value['supprime_pour_tous'],
    'supprime_pour_moi': value['supprime_pour_moi'] == true
        ? 1
        : value['supprime_pour_moi'],
  };
}
