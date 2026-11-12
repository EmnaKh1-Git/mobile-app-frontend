import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/services/database_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../user/models/user_model.dart';
import '../models/reclamation.dart';

/// Violation d'une règle métier du module réclamation.
class ReclamationRegleException implements Exception {
  final String message;
  const ReclamationRegleException(this.message);

  @override
  String toString() => message;
}

/// Indicateurs agrégés pour le tableau de bord.
class ReclamationStats {
  final int total;
  final Map<ReclamationStatus, int> parStatut;
  final Map<String, int> parCategorie;
  final int enRetard;
  final int urgentesOuvertes;
  final double tauxResolution; // 0..1 sur les réclamations clôturées
  final Duration? delaiMoyenPremiereReponse;
  final Duration? delaiMoyenResolution;
  final double? satisfactionMoyenne;
  final double tauxRespectSla; // 0..1

  const ReclamationStats({
    required this.total,
    required this.parStatut,
    required this.parCategorie,
    required this.enRetard,
    required this.urgentesOuvertes,
    required this.tauxResolution,
    required this.delaiMoyenPremiereReponse,
    required this.delaiMoyenResolution,
    required this.satisfactionMoyenne,
    required this.tauxRespectSla,
  });

  int get ouvertes =>
      (parStatut[ReclamationStatus.enAttente] ?? 0) +
      (parStatut[ReclamationStatus.enCours] ?? 0);
}

class ReclamationService extends ChangeNotifier {
  ReclamationService._() {
    _loadPersisted();
  }

  static final ReclamationService instance = ReclamationService._();

  /// Nombre maximal de réclamations par utilisateur sur 24 h (anti-spam).
  static const int limiteParJour = 5;

  /// Délai pendant lequel une réclamation résolue peut être rouverte.
  static const Duration delaiReouverture = Duration(days: 7);

  /// Nombre maximal de réouvertures autorisées.
  static const int maxReouvertures = 2;

  /// Seuil d'occurrences pour qu'une catégorie libre devienne « système ».
  static const int seuilCategorieSysteme = 5;

  final List<Reclamation> _reclamations = [
    Reclamation(
      id: 1,
      type: ReclamationType.retard,
      sujet: 'Retard au départ',
      description:
          'Le conducteur est arrivé avec 20 minutes de retard au point de rendez-vous et n’a pas informé les passagers à temps.',
      trajet: 'Tunis → Sousse',
      date: DateTime(2026, 9, 28, 17, 30),
      status: ReclamationStatus.enCours,
    ),
    Reclamation(
      id: 2,
      type: ReclamationType.vehicule,
      sujet: 'État du véhicule',
      description:
          'La climatisation ne fonctionnait pas durant le trajet, ce qui a rendu le voyage très inconfortable.',
      trajet: 'Bizerte → Tunis',
      date: DateTime(2026, 9, 18, 8, 15),
      status: ReclamationStatus.resolue,
      priorite: ReclamationPriorite.basse,
      dateCloture: DateTime(2026, 9, 19, 10),
    ),
  ];

  // ---------------------------------------------------------------------
  // Chargement / synchronisation
  // ---------------------------------------------------------------------

  Future<void> _loadPersisted() async {
    try {
      final db = await DatabaseService.instance.database;
      final rows = await db.query('reclamations', orderBy: 'date DESC');
      for (final row in rows) {
        _fusionner(_fromMap(row));
      }
    } catch (error) {
      debugPrint('[ReclamationService] Lecture locale impossible : $error');
    }
    await _loadRemote();
    _trier();
    notifyListeners();
  }

  Future<void> _loadRemote() async {
    try {
      final rows = await SupabaseService.instance.client
          .from('reclamations')
          .select()
          .order('date', ascending: false);
      for (final row in rows) {
        final reclamation = _fromMap(Map<String, Object?>.from(row));
        _fusionner(reclamation);
        await _saveLocal(reclamation);
      }
    } catch (error) {
      debugPrint(
        '[ReclamationService] Synchronisation Supabase impossible : $error',
      );
    }
  }

  void _fusionner(Reclamation reclamation) {
    final index = _reclamations.indexWhere((r) => r.id == reclamation.id);
    if (index == -1) {
      _reclamations.add(reclamation);
    } else {
      _reclamations[index] = reclamation;
    }
  }

  void _trier() => _reclamations.sort((a, b) => b.date.compareTo(a.date));

  Future<void> rafraichir() async {
    await _loadRemote();
    _trier();
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Lecture
  // ---------------------------------------------------------------------

  List<Reclamation> get reclamations => List.unmodifiable(_reclamations);

  Reclamation? parId(int id) {
    for (final r in _reclamations) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Un administrateur voit tout ; un étudiant voit ses réclamations
  /// (et les anciennes réclamations sans auteur, pour compatibilité).
  List<Reclamation> visiblesPour(UserModel? user) {
    if (user == null || user.isAdmin) return reclamations;
    return _reclamations
        .where((r) => r.auteurId == null || r.auteurId == user.id)
        .toList(growable: false);
  }

  List<String> get categoriesSysteme {
    final counts = <String, int>{};
    for (final reclamation in _reclamations) {
      final category = reclamation.autreCategorie?.trim();
      if (reclamation.type == ReclamationType.autre &&
          category != null &&
          category.isNotEmpty) {
        counts[category] = (counts[category] ?? 0) + 1;
      }
    }
    return counts.entries
        .where((entry) => entry.value >= seuilCategorieSysteme)
        .map((entry) => entry.key)
        .toList()
      ..sort();
  }

  // ---------------------------------------------------------------------
  // Règles métier : création
  // ---------------------------------------------------------------------

  /// Vérifie la limite anti-spam. Lève [ReclamationRegleException].
  void verifierLimite(String? auteurId) {
    if (auteurId == null) return;
    final depuis = DateTime.now().subtract(const Duration(hours: 24));
    final recentes = _reclamations
        .where((r) => r.auteurId == auteurId && r.date.isAfter(depuis))
        .length;
    if (recentes >= limiteParJour) {
      throw const ReclamationRegleException(
        'Vous avez atteint la limite de $limiteParJour réclamations '
        'sur 24 h. Merci de compléter une réclamation existante.',
      );
    }
  }

  /// Recherche les réclamations ouvertes similaires (anti-doublon),
  /// par similarité de Jaccard sur les mots significatifs.
  List<Reclamation> trouverDoublons({
    required String sujet,
    required String description,
    String? auteurId,
    double seuil = 0.35,
  }) {
    final cible = _motsCles('$sujet $description');
    if (cible.length < 3) return const [];
    final depuis = DateTime.now().subtract(const Duration(days: 30));
    final resultats = <MapEntry<Reclamation, double>>[];
    for (final r in _reclamations) {
      if (r.status.estCloturee || r.date.isBefore(depuis)) continue;
      if (auteurId != null && r.auteurId != null && r.auteurId != auteurId) {
        continue;
      }
      final mots = _motsCles('${r.sujet} ${r.description}');
      if (mots.isEmpty) continue;
      final inter = cible.intersection(mots).length;
      final union = cible.union(mots).length;
      final score = union == 0 ? 0.0 : inter / union;
      if (score >= seuil) resultats.add(MapEntry(r, score));
    }
    resultats.sort((a, b) => b.value.compareTo(a.value));
    return resultats.map((e) => e.key).take(3).toList();
  }

  /// Priorité estimée localement (utilisée si l'IA n'est pas disponible).
  static ReclamationPriorite prioriteEstimee(
    ReclamationType type,
    String texte,
  ) {
    final t = _sansAccents(texte.toLowerCase());
    const urgents = [
      'accident', 'danger', 'agress', 'harcel', 'menace', 'violence',
      'vitesse excessive', 'alcool', 'ivre', 'vol ', 'vole', 'blesse',
      'securite', 'police', 'urgence', 'peur',
    ];
    const hauts = [
      'rembours', 'argent', 'paye', 'paiement', 'facture', 'arnaque',
      'insult', 'irrespect', 'abandonne', 'annule', 'bloque', 'perdu',
    ];
    if (urgents.any(t.contains)) return ReclamationPriorite.urgente;
    if (type == ReclamationType.paiement || hauts.any(t.contains)) {
      return ReclamationPriorite.haute;
    }
    if (type == ReclamationType.vehicule && t.length < 80) {
      return ReclamationPriorite.basse;
    }
    return ReclamationPriorite.normale;
  }

  void ajouter(Reclamation reclamation) {
    final avecHistorique = reclamation.historique.isEmpty
        ? reclamation.copyWith(
            historique: [
              ReclamationEvenement(
                date: reclamation.date,
                libelle:
                    'Réclamation créée (priorité ${reclamation.priorite.label})',
                auteur: reclamation.auteurNom,
              ),
            ],
          )
        : reclamation;
    _reclamations.insert(0, avecHistorique);
    _save(avecHistorique);
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Règles métier : workflow
  // ---------------------------------------------------------------------

  /// Change le statut en respectant le workflow. Lève
  /// [ReclamationRegleException] si la transition est interdite.
  void mettreAJourStatut(
    int id,
    ReclamationStatus nouveauStatut, {
    String? auteur,
    String? motif,
  }) {
    final index = _index(id);
    if (index == -1) return;
    final r = _reclamations[index];
    if (r.status == nouveauStatut) return;

    if (!r.status.transitionsAutorisees.contains(nouveauStatut)) {
      throw ReclamationRegleException(
        'Transition « ${r.status.label} → ${nouveauStatut.label} » '
        'non autorisée.',
      );
    }
    if (nouveauStatut == ReclamationStatus.resolue && !r.aReponseAdmin) {
      throw const ReclamationRegleException(
        'Répondez à l’étudiant avant de marquer la réclamation comme résolue.',
      );
    }
    if (nouveauStatut == ReclamationStatus.rejetee &&
        (motif == null || motif.trim().isEmpty)) {
      throw const ReclamationRegleException(
        'Un motif est obligatoire pour rejeter une réclamation.',
      );
    }

    final cloture = nouveauStatut.estCloturee;
    var libelle = 'Statut : ${r.status.label} → ${nouveauStatut.label}';
    if (motif != null && motif.trim().isNotEmpty) {
      libelle += ' (motif : ${motif.trim()})';
    }
    _reclamations[index] = r.copyWith(
      status: nouveauStatut,
      dateCloture: cloture ? DateTime.now() : null,
      historique: [
        ...r.historique,
        ReclamationEvenement(
          date: DateTime.now(),
          libelle: libelle,
          auteur: auteur,
        ),
      ],
    );
    _save(_reclamations[index]);
    notifyListeners();
  }

  void changerPriorite(int id, ReclamationPriorite priorite, {String? auteur}) {
    final index = _index(id);
    if (index == -1) return;
    final r = _reclamations[index];
    if (r.priorite == priorite) return;
    _reclamations[index] = r.copyWith(
      priorite: priorite,
      historique: [
        ...r.historique,
        ReclamationEvenement(
          date: DateTime.now(),
          libelle: 'Priorité : ${r.priorite.label} → ${priorite.label}',
          auteur: auteur,
        ),
      ],
    );
    _save(_reclamations[index]);
    notifyListeners();
  }

  /// Vérifie si l'étudiant peut encore rouvrir sa réclamation.
  String? raisonRefusReouverture(Reclamation r) {
    if (r.status != ReclamationStatus.resolue) {
      return 'Seule une réclamation résolue peut être rouverte.';
    }
    if (r.nombreReouvertures >= maxReouvertures) {
      return 'Nombre maximal de réouvertures atteint ($maxReouvertures).';
    }
    final cloture = r.dateCloture ?? r.derniereActivite;
    if (DateTime.now().difference(cloture) > delaiReouverture) {
      return 'Le délai de réouverture (${delaiReouverture.inDays} jours) est dépassé.';
    }
    return null;
  }

  void rouvrir(int id, String motif, {String? auteur}) {
    final index = _index(id);
    if (index == -1) return;
    final r = _reclamations[index];
    final refus = raisonRefusReouverture(r);
    if (refus != null) throw ReclamationRegleException(refus);
    if (motif.trim().isEmpty) {
      throw const ReclamationRegleException(
        'Expliquez pourquoi le problème n’est pas résolu.',
      );
    }
    // Une réouverture fait monter la priorité d'un cran.
    final nouvellePriorite = r.priorite.index < ReclamationPriorite.urgente.index
        ? ReclamationPriorite.values[r.priorite.index + 1]
        : r.priorite;
    _reclamations[index] = r.copyWith(
      status: ReclamationStatus.enCours,
      dateCloture: null,
      satisfaction: null,
      commentaireSatisfaction: null,
      nombreReouvertures: r.nombreReouvertures + 1,
      priorite: nouvellePriorite,
      responses: [
        ...r.responses,
        ReclamationResponse(
          message: 'Réouverture : ${motif.trim()}',
          date: DateTime.now(),
          parAdmin: false,
          auteurNom: auteur,
        ),
      ],
      historique: [
        ...r.historique,
        ReclamationEvenement(
          date: DateTime.now(),
          libelle:
              'Réclamation rouverte (priorité ${nouvellePriorite.label})',
          auteur: auteur,
        ),
      ],
    );
    _save(_reclamations[index]);
    notifyListeners();
  }

  void noter(int id, int note, {String? commentaire, String? auteur}) {
    final index = _index(id);
    if (index == -1) return;
    final r = _reclamations[index];
    if (r.status != ReclamationStatus.resolue) {
      throw const ReclamationRegleException(
        'Vous pourrez noter le traitement une fois la réclamation résolue.',
      );
    }
    if (note < 1 || note > 5) {
      throw const ReclamationRegleException('La note doit être entre 1 et 5.');
    }
    _reclamations[index] = r.copyWith(
      satisfaction: note,
      commentaireSatisfaction:
          (commentaire ?? '').trim().isEmpty ? null : commentaire!.trim(),
      historique: [
        ...r.historique,
        ReclamationEvenement(
          date: DateTime.now(),
          libelle: 'Satisfaction : $note/5',
          auteur: auteur,
        ),
      ],
    );
    _save(_reclamations[index]);
    notifyListeners();
  }

  /// Ajoute un message au fil (texte, vocal et/ou image).
  /// Règles : pas de message sur une réclamation clôturée côté étudiant ;
  /// la première réponse admin fait passer « En attente » → « En cours ».
  void ajouterReponse(
    int id,
    String message, {
    String? audioPath,
    String? imagePath,
    bool parAdmin = true,
    String? auteurNom,
  }) {
    final normalizedMessage = message.trim();
    if (normalizedMessage.isEmpty && audioPath == null && imagePath == null) {
      return;
    }

    final index = _index(id);
    if (index == -1) return;
    final r = _reclamations[index];

    if (!parAdmin && r.status.estCloturee) {
      throw const ReclamationRegleException(
        'Cette réclamation est clôturée. Rouvrez-la pour ajouter un message.',
      );
    }

    final historique = [...r.historique];
    var statut = r.status;
    if (parAdmin && r.status == ReclamationStatus.enAttente) {
      statut = ReclamationStatus.enCours;
      historique.add(
        ReclamationEvenement(
          date: DateTime.now(),
          libelle: 'Prise en charge automatique (première réponse)',
          auteur: auteurNom,
        ),
      );
    }
    historique.add(
      ReclamationEvenement(
        date: DateTime.now(),
        libelle: parAdmin
            ? 'Réponse de l’administration${imagePath != null ? ' (avec image)' : ''}'
            : 'Message de l’étudiant${imagePath != null ? ' (avec image)' : ''}',
        auteur: auteurNom,
      ),
    );

    _reclamations[index] = r.copyWith(
      status: statut,
      historique: historique,
      responses: [
        ...r.responses,
        ReclamationResponse(
          message: normalizedMessage,
          date: DateTime.now(),
          audioPath: audioPath,
          imagePath: imagePath,
          parAdmin: parAdmin,
          auteurNom: auteurNom,
        ),
      ],
    );
    _save(_reclamations[index]);
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Statistiques
  // ---------------------------------------------------------------------

  ReclamationStats statistiques([List<Reclamation>? source]) {
    final liste = source ?? _reclamations;
    final parStatut = {for (final s in ReclamationStatus.values) s: 0};
    final parCategorie = <String, int>{};
    var enRetard = 0;
    var urgentes = 0;
    final premieresReponses = <Duration>[];
    final resolutions = <Duration>[];
    final notes = <int>[];
    var slaRespecte = 0;
    var slaEvalue = 0;

    for (final r in liste) {
      parStatut[r.status] = (parStatut[r.status] ?? 0) + 1;
      parCategorie[r.typeLabel] = (parCategorie[r.typeLabel] ?? 0) + 1;
      if (r.estEnRetard) enRetard++;
      if (!r.status.estCloturee && r.priorite == ReclamationPriorite.urgente) {
        urgentes++;
      }
      final pr = r.delaiPremiereReponse;
      if (pr != null && !pr.isNegative) premieresReponses.add(pr);
      final res = r.delaiResolution;
      if (res != null && !res.isNegative) resolutions.add(res);
      if (r.satisfaction != null) notes.add(r.satisfaction!);
      if (r.status.estCloturee && r.dateCloture != null) {
        slaEvalue++;
        if (!r.dateCloture!.isAfter(r.echeance)) slaRespecte++;
      } else if (!r.status.estCloturee) {
        slaEvalue++;
        if (!r.estEnRetard) slaRespecte++;
      }
    }

    final clotures = (parStatut[ReclamationStatus.resolue] ?? 0) +
        (parStatut[ReclamationStatus.rejetee] ?? 0);

    return ReclamationStats(
      total: liste.length,
      parStatut: parStatut,
      parCategorie: parCategorie,
      enRetard: enRetard,
      urgentesOuvertes: urgentes,
      tauxResolution: clotures == 0
          ? 0
          : (parStatut[ReclamationStatus.resolue] ?? 0) / clotures,
      delaiMoyenPremiereReponse: _moyenne(premieresReponses),
      delaiMoyenResolution: _moyenne(resolutions),
      satisfactionMoyenne: notes.isEmpty
          ? null
          : notes.reduce((a, b) => a + b) / notes.length,
      tauxRespectSla: slaEvalue == 0 ? 1 : slaRespecte / slaEvalue,
    );
  }

  static Duration? _moyenne(List<Duration> valeurs) {
    if (valeurs.isEmpty) return null;
    final total = valeurs.fold<int>(0, (s, d) => s + d.inMinutes);
    return Duration(minutes: total ~/ valeurs.length);
  }

  // ---------------------------------------------------------------------
  // Persistance
  // ---------------------------------------------------------------------

  int _index(int id) => _reclamations.indexWhere((r) => r.id == id);

  Future<void> _save(Reclamation reclamation) async {
    try {
      await _saveLocal(reclamation);
    } catch (error) {
      debugPrint('[ReclamationService] Enregistrement local impossible : $error');
    }
    final client = SupabaseService.instance.client;
    try {
      await client
          .from('reclamations')
          .upsert(_toRemoteMap(reclamation), onConflict: 'id');
    } catch (error) {
      // Compatibilité : si la colonne `meta` n'existe pas encore côté
      // Supabase, on réessaie sans elle.
      if (error.toString().contains('meta')) {
        try {
          final legacy = _toRemoteMap(reclamation)..remove('meta');
          await client.from('reclamations').upsert(legacy, onConflict: 'id');
          return;
        } catch (_) {}
      }
      debugPrint(
        '[ReclamationService] Enregistrement Supabase impossible : $error',
      );
    }
  }

  Future<void> _saveLocal(Reclamation reclamation) async {
    final db = await DatabaseService.instance.database;
    await db.insert(
      'reclamations',
      _toMap(reclamation),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Map<String, dynamic> _toMap(Reclamation reclamation) => {
    'id': reclamation.id,
    'type': reclamation.type.name,
    'sujet': reclamation.sujet,
    'description': reclamation.description,
    'trajet': reclamation.trajet,
    'date': reclamation.date.toIso8601String(),
    'status': reclamation.status.name,
    'autreCategorie': reclamation.autreCategorie,
    'imagePath': reclamation.imagePath,
    'audioPath': reclamation.audioPath,
    'aiConseil': reclamation.aiConseil,
    'responses': jsonEncode(
      reclamation.responses.map((r) => r.toJson()).toList(),
    ),
    'meta': jsonEncode(reclamation.metaToJson()),
  };

  Map<String, dynamic> _toRemoteMap(Reclamation reclamation) {
    final map = _toMap(reclamation);
    map['responses'] = reclamation.responses.map((r) => r.toJson()).toList();
    map['meta'] = reclamation.metaToJson();
    return map;
  }

  Reclamation _fromMap(Map<String, Object?> map) {
    final responses = _decodeList(map['responses'])
        .map(ReclamationResponse.fromJson)
        .toList();
    final meta = _decodeMap(map['meta']);
    final historique = (meta['historique'] is List
            ? meta['historique'] as List
            : const [])
        .whereType<Map>()
        .map(ReclamationEvenement.fromJson)
        .toList();

    ReclamationStatus statut;
    try {
      statut = ReclamationStatus.values.byName(map['status'] as String);
    } catch (_) {
      statut = ReclamationStatus.enAttente;
    }
    ReclamationType type;
    try {
      type = ReclamationType.values.byName(map['type'] as String);
    } catch (_) {
      type = ReclamationType.autre;
    }

    return Reclamation(
      id: (map['id'] as num).toInt(),
      type: type,
      sujet: map['sujet'] as String? ?? '',
      description: map['description'] as String? ?? '',
      trajet: map['trajet'] as String? ?? '',
      date: DateTime.parse(map['date'] as String),
      status: statut,
      autreCategorie: map['autreCategorie'] as String?,
      imagePath: map['imagePath'] as String?,
      audioPath: map['audioPath'] as String?,
      aiConseil: map['aiConseil'] as String?,
      responses: responses,
      priorite:
          ReclamationPriorite.depuisLibelle(meta['priorite'] as String?) ??
          ReclamationPriorite.normale,
      auteurId: meta['auteurId'] as String?,
      auteurNom: meta['auteurNom'] as String?,
      sentiment: meta['sentiment'] as String?,
      satisfaction: (meta['satisfaction'] as num?)?.toInt(),
      commentaireSatisfaction: meta['commentaireSatisfaction'] as String?,
      nombreReouvertures: (meta['nombreReouvertures'] as num?)?.toInt() ?? 0,
      dateCloture: DateTime.tryParse(meta['dateCloture'] as String? ?? ''),
      historique: historique,
    );
  }

  static List<Map> _decodeList(Object? raw) {
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      return (decoded is List ? decoded : const []).whereType<Map>().toList();
    } catch (_) {
      return const [];
    }
  }

  static Map<String, dynamic> _decodeMap(Object? raw) {
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
    } catch (_) {
      return {};
    }
  }

  // ---------------------------------------------------------------------
  // Outils texte
  // ---------------------------------------------------------------------

  static const _motsVides = {
    'le', 'la', 'les', 'un', 'une', 'des', 'de', 'du', 'et', 'ou', 'a',
    'au', 'aux', 'en', 'dans', 'sur', 'pour', 'par', 'avec', 'sans', 'ce',
    'cette', 'ces', 'il', 'elle', 'ils', 'elles', 'je', 'j', 'tu', 'nous',
    'vous', 'on', 'est', 'etait', 'ete', 'pas', 'ne', 'n', 'qui', 'que',
    'qu', 'l', 'd', 'mon', 'ma', 'mes', 'son', 'sa', 'ses', 'tres', 'plus',
    'mais', 'donc', 'car', 'se', 's', 'y', 'avait', 'ai', 'avons',
  };

  static Set<String> _motsCles(String texte) {
    return _sansAccents(texte.toLowerCase())
        .split(RegExp(r'[^a-z0-9]+'))
        .where((m) => m.length > 2 && !_motsVides.contains(m))
        .toSet();
  }

  static String _sansAccents(String s) {
    const avec = 'àâäáãéèêëíìîïóòôöõúùûüçñ';
    const sans = 'aaaaaeeeeiiiiooooouuuucn';
    final buffer = StringBuffer();
    for (final c in s.split('')) {
      final i = avec.indexOf(c);
      buffer.write(i == -1 ? c : sans[i]);
    }
    return buffer.toString();
  }
}
