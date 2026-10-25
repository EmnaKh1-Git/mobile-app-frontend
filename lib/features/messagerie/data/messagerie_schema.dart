import 'package:sqflite/sqflite.dart';

class MessagerieSchema {
  static Future<void> creerTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS msg_conversation (
        id TEXT PRIMARY KEY,
        type TEXT,
        titre TEXT,
        trajet_id TEXT,
        trajet_label TEXT,
        createur_id TEXT,
        archivee INTEGER DEFAULT 0,
        muet INTEGER DEFAULT 0,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS msg_membre (
        conversation_id TEXT,
        user_id TEXT,
        nom TEXT,
        role TEXT,
        last_read_at TEXT,
        PRIMARY KEY (conversation_id, user_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS msg_message (
        id TEXT PRIMARY KEY,
        conversation_id TEXT,
        expediteur_id TEXT,
        expediteur_nom TEXT,
        contenu TEXT,
        type TEXT,
        statut TEXT,
        duree_secondes INTEGER,
        chemin_audio TEXT,
        ecoute INTEGER DEFAULT 0,
        signale INTEGER DEFAULT 0,
        masque INTEGER DEFAULT 0,
        supprime_pour_tous INTEGER DEFAULT 0,
        supprime_pour_moi INTEGER DEFAULT 0,
        date_envoi TEXT,
        date_suppression TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_msg_message_conv_date ON msg_message(conversation_id, date_envoi)',
    );
  }
}
