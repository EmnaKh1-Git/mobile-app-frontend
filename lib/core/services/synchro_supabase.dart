// lib/core/services/synchro_supabase.dart
// ============================================================
//  Synchronisation SQLite ⇄ Supabase des tables des modules Trajets,
//  Discussions et Compléments (même principe que planning et trajets :
//  SQLite reste la copie locale, Supabase la base partagée).
//
//  - Écriture : la ligne est d'abord envoyée à Supabase, qui attribue
//    l'id ; sans réseau, SQLite attribue l'id et l'application continue.
//  - Lecture : les lignes Supabase remplacent la copie locale (miroir),
//    pour voir les données des autres utilisateurs ; sans réseau, on lit
//    la copie locale.
//
//  Conversions : SQLite range les dates en texte ISO sans fuseau
//  (heure locale) et les booléens en 0/1 ; Supabase utilise timestamptz
//  et boolean. Les dates partent en UTC et reviennent en heure locale.
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Description d'une table présente dans SQLite et dans Supabase
class TableSynchro {
  /// Nom de la table SQLite
  final String locale;

  /// Nom de la table Supabase (par défaut le même)
  final String distante;

  /// Colonnes communes aux deux bases (id compris s'il existe)
  final List<String> colonnes;

  /// Colonnes de date (texte ISO local ⇄ timestamptz)
  final Set<String> dates;

  /// Colonnes booléennes (0/1 ⇄ boolean)
  final Set<String> booleens;

  /// Colonnes réelles (numeric dans Supabase)
  final Set<String> reels;

  const TableSynchro(
    this.locale, {
    String? distante,
    required this.colonnes,
    this.dates = const {},
    this.booleens = const {},
    this.reels = const {},
  }) : distante = distante ?? locale;

  /// Ligne SQLite → ligne Supabase
  Map<String, Object?> versDistant(Map<String, Object?> ligne) => {
        for (final entree in ligne.entries)
          if (colonnes.contains(entree.key))
            entree.key: _versDistant(entree.key, entree.value),
      };

  Object? _versDistant(String colonne, Object? valeur) {
    if (valeur == null) return null;
    if (dates.contains(colonne)) {
      final date = DateTime.tryParse(valeur.toString());
      return date?.toUtc().toIso8601String() ?? valeur;
    }
    if (booleens.contains(colonne)) return valeur == true || valeur == 1;
    return valeur;
  }

  /// Ligne Supabase → ligne SQLite (colonnes inconnues ignorées)
  Map<String, Object?> versLocal(Map<String, dynamic> ligne) => {
        for (final colonne in colonnes)
          if (ligne.containsKey(colonne))
            colonne: _versLocal(colonne, ligne[colonne]),
      };

  Object? _versLocal(String colonne, Object? valeur) {
    if (valeur == null) return null;
    if (dates.contains(colonne)) {
      final date = DateTime.tryParse(valeur.toString());
      return date?.toLocal().toIso8601String() ?? valeur.toString();
    }
    if (booleens.contains(colonne)) {
      return valeur == true || valeur == 1 ? 1 : 0;
    }
    if (reels.contains(colonne) && valeur is num) return valeur.toDouble();
    if (valeur is num) return valeur.toInt();
    return valeur;
  }
}

class SynchroSupabase {
  SynchroSupabase._();

  /// Client Supabase, ou null s'il n'est pas initialisé (tests)
  static SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static void _journal(String action, TableSynchro t, Object erreur) =>
      debugPrint('[Supabase] $action « ${t.distante} » impossible : $erreur');

  /// Insère la ligne dans Supabase et renvoie l'id attribué (null : échec).
  /// [extra] : colonnes propres à Supabase (ex. user_id).
  static Future<int?> inserer(
    TableSynchro t,
    Map<String, Object?> ligne, {
    Map<String, Object?> extra = const {},
  }) async {
    final client = _client;
    if (client == null) return null;
    try {
      final distant = {...t.versDistant(ligne), ...extra}..remove('id');
      final res =
          await client.from(t.distante).insert(distant).select('id').single();
      return (res['id'] as num).toInt();
    } catch (e) {
      _journal('Insertion dans', t, e);
      return null;
    }
  }

  /// Insère ou remplace la ligne (clé : [conflit], ex. 'trajet_id,user_id')
  static Future<void> upsert(
    TableSynchro t,
    Map<String, Object?> ligne, {
    required String conflit,
  }) async {
    final client = _client;
    if (client == null) return;
    try {
      await client
          .from(t.distante)
          .upsert(t.versDistant(ligne), onConflict: conflit);
    } catch (e) {
      _journal('Enregistrement dans', t, e);
    }
  }

  /// Met à jour la ligne d'identifiant [id]
  static Future<void> modifier(
      TableSynchro t, int id, Map<String, Object?> ligne) async {
    final client = _client;
    if (client == null) return;
    try {
      await client
          .from(t.distante)
          .update(t.versDistant(ligne)..remove('id'))
          .eq('id', id);
    } catch (e) {
      _journal('Mise à jour de', t, e);
    }
  }

  /// Supprime les lignes où [colonne] vaut [valeur]
  static Future<void> supprimer(
      TableSynchro t, String colonne, Object valeur) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from(t.distante).delete().eq(colonne, valeur);
    } catch (e) {
      _journal('Suppression dans', t, e);
    }
  }

  /// Lignes Supabase (filtrées sur [colonne] = [valeur] si donné),
  /// ou null si Supabase est injoignable
  static Future<List<Map<String, dynamic>>?> lire(
    TableSynchro t, {
    String select = '*',
    String? colonne,
    Object? valeur,
  }) async {
    final client = _client;
    if (client == null) return null;
    try {
      final requete = client.from(t.distante).select(select);
      final res = colonne == null
          ? await requete
          : await requete.eq(colonne, valeur!);
      return [for (final l in res) Map<String, dynamic>.from(l)];
    } catch (e) {
      _journal('Lecture de', t, e);
      return null;
    }
  }

  /// Remplace la copie locale de la table par les lignes Supabase.
  /// [filtreDistant] restreint les lignes lues (ex. user_id = moi) ;
  /// la table locale entière est alors remplacée par ces lignes.
  /// Renvoie false si Supabase est injoignable (copie locale inchangée).
  static Future<bool> miroir(
    Database db,
    TableSynchro t, {
    String? filtreDistant,
    Object? valeur,
  }) async {
    final lignes = await lire(t, colonne: filtreDistant, valeur: valeur);
    if (lignes == null) return false;
    try {
      await db.transaction((txn) async {
        await txn.delete(t.locale);
        for (final l in lignes) {
          await txn.insert(t.locale, t.versLocal(l),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
      return true;
    } catch (e) {
      _journal('Copie locale de', t, e);
      return false;
    }
  }
}
