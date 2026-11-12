import 'package:flutter/foundation.dart';

import 'deepseek_client.dart';

enum SourceResume { deepseek, local }

class ResumeResultat {
  final String texte;
  final SourceResume source;

  /// Raison pour laquelle l'IA n'a pas été utilisée (si repli local).
  final String? avertissement;

  /// Vrai si le texte était déjà concis et n'a pas pu être raccourci.
  final bool dejaConcis;

  const ResumeResultat({
    required this.texte,
    required this.source,
    this.avertissement,
    this.dejaConcis = false,
  });
}

/// Résume / reformule une description de réclamation.
///
/// 1. DeepSeek (si la clé est fournie) ;
/// 2. sinon, résumé extractif local (suppression du remplissage, des
///    répétitions, sélection des phrases porteuses d'information).
class AiSummarizeService {
  AiSummarizeService._();
  static final AiSummarizeService instance = AiSummarizeService._();

  static const _promptSysteme =
      'Tu es l’assistant support de UniDrive, une application tunisienne de '
      'covoiturage étudiant. On te donne la description brute d’une '
      'réclamation (parfois en langage familier, en derja ou mal '
      'ponctuée). Produis un RÉSUMÉ reformulé en français correct et '
      'professionnel :\n'
      '- 2 à 3 phrases maximum, nettement plus court que l’original si '
      'possible ;\n'
      '- à la première personne (c’est l’étudiant qui parle) ;\n'
      '- conserve tous les faits utiles : heures, durées, montants, lieux, '
      'noms, immatriculations ;\n'
      '- n’invente aucun fait, supprime les répétitions et les insultes ;\n'
      '- réponds UNIQUEMENT avec le texte final, sans guillemets, sans titre '
      'ni introduction.';

  Future<ResumeResultat?> resumer(String texte, {String? sujet}) async {
    final clean = texte.trim();
    if (clean.isEmpty) return null;

    String? avertissement;
    if (DeepSeekClient.instance.estConfigure) {
      try {
        final reponse = await DeepSeekClient.instance.chat(
          system: _promptSysteme,
          user: sujet == null || sujet.trim().isEmpty
              ? clean
              : 'Objet : ${sujet.trim()}\nDescription : $clean',
          temperature: 0.3,
          maxTokens: 350,
        );
        final resultat = _nettoyerSortieIa(reponse);
        if (resultat.isNotEmpty) {
          return ResumeResultat(texte: resultat, source: SourceResume.deepseek);
        }
      } on DeepSeekException catch (e) {
        avertissement = e.message;
        debugPrint('[AiSummarize] DeepSeek : $e');
      } catch (e) {
        avertissement = 'Erreur IA : $e';
        debugPrint('[AiSummarize] Erreur : $e');
      }
    } else {
      avertissement = 'IA non configurée (clé DeepSeek absente)';
    }

    final local = resumerLocal(clean);
    return ResumeResultat(
      texte: local.texte,
      source: SourceResume.local,
      avertissement: avertissement,
      dejaConcis: local.dejaConcis,
    );
  }

  /// Compatibilité avec l'ancienne API.
  Future<String?> reformuler(String texte) async =>
      (await resumer(texte))?.texte;

  String _nettoyerSortieIa(String s) {
    var t = s.trim();
    t = t.replaceFirst(
      RegExp(r'^(r[ée]sum[ée]|reformulation|texte reformul[ée])\s*:\s*',
          caseSensitive: false),
      '',
    );
    if (t.length > 1 &&
        ((t.startsWith('"') && t.endsWith('"')) ||
            (t.startsWith('«') && t.endsWith('»')))) {
      t = t.substring(1, t.length - 1).trim();
    }
    return t;
  }

  // ---------------------------------------------------------------------
  // Résumé extractif local
  // ---------------------------------------------------------------------

  /// Construit une regex « mot entier » compatible avec les lettres
  /// accentuées (le `\b` de Dart ne considère que l'ASCII).
  static RegExp _mot(String motif) => RegExp(
    r'(?<![\p{L}\p{N}])(?:' + motif + r')(?![\p{L}\p{N}])',
    caseSensitive: false,
    unicode: true,
  );

  static final Map<RegExp, String> _abreviations = {
    _mot('slt|bjr'): 'bonjour',
    _mot('svp'): 's’il vous plaît',
    _mot('stp'): 's’il te plaît',
    _mot('pcq|pck|psk|parske'): 'parce que',
    _mot('pk|pq'): 'pourquoi',
    _mot('pr'): 'pour',
    _mot('mm'): 'même',
    _mot('tjrs|tjr|tjs'): 'toujours',
    _mot('bcp'): 'beaucoup',
    _mot('qd'): 'quand',
    _mot('rdv'): 'rendez-vous',
    _mot('fac'): 'faculté',
    _mot('cdd|chauff'): 'conducteur',
    _mot('chui|chuis|jsuis|jsui'): 'je suis',
    _mot('ya'): 'il y a',
    _mot(r'(\d+)\s?(?:mn|mins?|minute)'): r'$1 minutes',
    _mot(r'(\d+)\s?(?:dt|tnd|dinars?)'): r'$1 DT',
    // Élisions oubliées : « j ai » → « j’ai », « l autoroute » → « l’autoroute »
    RegExp(
      r"(?<![\p{L}\p{N}])([jlcdmnst]|qu)[ ']\s*(?=[aeiouhyéèêàâîô])",
      caseSensitive: false,
      unicode: true,
    ): r'$1’',
  };

  /// Expressions de remplissage supprimées.
  static final List<RegExp> _remplissage = [
    _mot(
      'franchement|honn[eê]tement|en fait|du coup|genre|bref|voil[aà]|'
      'euh+|bon ben|bah|carr[ée]ment|vraiment|je vous jure|wallah|'
      'sérieusement|serieux|tout simplement|bon',
    ),
    RegExp(
      r'^(bonjour|salut|bonsoir|salam|aslema)( à tous| madame| monsieur)?[ ,!.]*',
      caseSensitive: false,
    ),
    RegExp(
      r'(merci( beaucoup| bien)?( d’avance| d.avance| pour votre aide)?|'
      r'cordialement)[ .!]*$',
      caseSensitive: false,
    ),
  ];

  static const _motsMetier = {
    'retard', 'minutes', 'heure', 'conducteur', 'chauffeur', 'passager',
    'vehicule', 'voiture', 'climatisation', 'paiement', 'paye', 'rembours',
    'argent', 'prix', 'dt', 'annule', 'absent', 'attendu', 'accident',
    'danger', 'vite', 'vitesse', 'insult', 'comportement', 'trajet', 'rendez',
    'depart', 'arrivee', 'bagage', 'sale', 'fume', 'cigarette', 'telephone',
    'reservation', 'examen', 'rate', 'sanction', 'agress', 'harcel', 'peur',
  };

  /// Propositions qu'on ne doit pas perdre (sécurité, argent, chiffres).
  static final RegExp _critique = RegExp(
    r'\d|rembours|argent|pay|accident|danger|vite|vitesse|agress|harc|'
    r'menace|alcool|insult|sanction',
    caseSensitive: false,
  );

  static const _motsVides = {
    'le', 'la', 'les', 'un', 'une', 'des', 'de', 'du', 'et', 'ou', 'a',
    'au', 'aux', 'en', 'dans', 'sur', 'pour', 'par', 'avec', 'ce', 'cette',
    'il', 'elle', 'ils', 'je', 'j', 'nous', 'vous', 'on', 'est', 'pas',
    'ne', 'n', 'qui', 'que', 'qu', 'l', 'd', 'mon', 'ma', 'son', 'sa',
    'tres', 'plus', 'mais', 'donc', 'car', 'se', 's', 'y', 'ai', 'avait',
    'etait', 'c', 'cest', 'me', 'm', 'moi', 'tout', 'tous', 'trop', 'meme',
  };

  static final RegExp _connecteurs = RegExp(
    r'\s+(?:et\s+)?(?=(?:et puis|ensuite|puis|mais|alors|après|en plus|'
    r'sauf que|parce que|car|sans)(?![\p{L}]))'
    r'|\s+et\s+(?=(?:il|elle|ils|elles|je|j’|on|nous|le|la|les|en plus)(?![\p{L}]))',
    caseSensitive: false,
    unicode: true,
  );

  ({String texte, bool dejaConcis}) resumerLocal(String texte) {
    // 1. Normalisation
    var t = texte.replaceAll(RegExp(r'\s+'), ' ').trim();
    _abreviations.forEach((motif, valeur) {
      t = t.replaceAllMapped(motif, (m) {
        var v = valeur;
        for (var i = 1; i <= m.groupCount; i++) {
          v = v.replaceAll('\$$i', m.group(i) ?? '');
        }
        return v;
      });
    });
    for (final motif in _remplissage) {
      t = t.replaceAll(motif, ' ');
    }
    // Ponctuation répétée et mots répétés (« très très », « !!! »)
    t = t
        .replaceAllMapped(RegExp(r'([!?.])\1+'), (m) => m.group(1)!)
        .replaceAllMapped(
          RegExp(
            r'(?<![\p{L}])([\p{L}]+)(?:\s+\1(?![\p{L}]))+',
            caseSensitive: false,
            unicode: true,
          ),
          (m) => m.group(1)!,
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAllMapped(RegExp(r'\s+([,.!?])'), (m) => m.group(1)!)
        .replaceAll(RegExp(r'^[ ,.;]+'), '')
        .trim();

    final motsOriginaux = _compterMots(texte);

    // 2. Découpage en propositions
    var segments = t
        .split(RegExp(r'(?<=[.!?;])\s+|\n+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    // Phrases trop longues (texte non ponctué) : découpe sur les connecteurs.
    segments = [
      for (final s in segments)
        if (_compterMots(s) > 20)
          ...s
              .split(RegExp(r',\s+'))
              .expand((p) => p.split(_connecteurs))
              .map((p) => p.trim())
              .where((p) => _compterMots(p) >= 2)
        else
          s,
    ];
    if (segments.isEmpty) {
      return (texte: _finaliser(t), dejaConcis: true);
    }

    // 3. Suppression des quasi-doublons (on garde la version la plus riche)
    final uniques = <String>[];
    final motsUniques = <Set<String>>[];
    for (final s in segments) {
      final mots = _mots(s);
      var doublon = false;
      for (var j = 0; j < motsUniques.length; j++) {
        final autres = motsUniques[j];
        if (mots.isEmpty || autres.isEmpty) continue;
        final inter = mots.intersection(autres).length;
        final petit = mots.length < autres.length ? mots.length : autres.length;
        if (inter / petit >= 0.67) {
          doublon = true;
          if (mots.length > autres.length) {
            uniques[j] = s;
            motsUniques[j] = mots;
          }
          break;
        }
      }
      if (!doublon) {
        uniques.add(s);
        motsUniques.add(mots);
      }
    }

    // 4. Score des propositions (fréquence + vocabulaire métier + critique)
    final frequences = <String, int>{};
    for (final mots in motsUniques) {
      for (final m in mots) {
        frequences[m] = (frequences[m] ?? 0) + 1;
      }
    }
    final scores = <int, double>{};
    for (var i = 0; i < uniques.length; i++) {
      final mots = motsUniques[i];
      var score = 0.0;
      for (final m in mots) {
        score += frequences[m] ?? 0;
        if (_motsMetier.any(m.startsWith)) score += 3;
      }
      if (_critique.hasMatch(uniques[i])) score += 8;
      if (i == 0) score += 4; // la première phrase pose le contexte
      scores[i] = mots.isEmpty ? 0 : score / (mots.length + 2);
    }

    // 5. Sélection : ~55 % des mots, 4 propositions au plus
    final cibleMots = (motsOriginaux * 0.55).clamp(12, 70).round();
    // Les propositions critiques (chiffres, argent, sécurité) passent d'abord.
    final ordre = scores.keys.toList()
      ..sort((a, b) {
        final ca = _critique.hasMatch(uniques[a]) ? 1 : 0;
        final cb = _critique.hasMatch(uniques[b]) ? 1 : 0;
        if (ca != cb) return cb - ca;
        return scores[b]!.compareTo(scores[a]!);
      });
    final retenus = <int>[];
    var mots = 0;
    for (final i in ordre) {
      if (retenus.length >= 4) break;
      final n = _compterMots(uniques[i]);
      if (retenus.isNotEmpty && mots + n > cibleMots) continue;
      retenus.add(i);
      mots += n;
    }
    retenus.sort();

    final resultat = retenus.map((i) => _phrase(uniques[i])).join(' ');
    final dejaConcis = _compterMots(resultat) >= motsOriginaux * 0.9;
    return (texte: resultat, dejaConcis: dejaConcis);
  }

  static final RegExp _conjonctionDebut = RegExp(
    r'^(?:et puis|et|puis|mais|alors|donc|en plus)\s+',
    caseSensitive: false,
  );
  static final RegExp _conjonctionFin = RegExp(
    r'\s+(?:et|ou|mais|puis|donc|alors)$',
    caseSensitive: false,
  );

  String _phrase(String s) {
    var p = s.trim().replaceAll(RegExp(r'^[,;:\-–\s]+|[,;:\-–\s.]+$'), '');
    p = p.replaceFirst(_conjonctionDebut, '').replaceFirst(_conjonctionFin, '');
    return _finaliser(p);
  }


  String _finaliser(String s) {
    var p = s.trim();
    if (p.isEmpty) return p;
    p = p[0].toUpperCase() + p.substring(1);
    if (!RegExp(r'[.!?…]$').hasMatch(p)) p = '$p.';
    return p;
  }

  int _compterMots(String s) =>
      s.split(RegExp(r'\s+')).where((m) => m.trim().isNotEmpty).length;

  Set<String> _mots(String s) {
    const avec = 'àâäéèêëîïôöùûüç’\'';
    const sans = 'aaaeeeeiioouuuc  ';
    final b = StringBuffer();
    for (final c in s.toLowerCase().split('')) {
      final i = avec.indexOf(c);
      b.write(i == -1 ? c : sans[i]);
    }
    return b
        .toString()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((m) => m.length > 1 && !_motsVides.contains(m))
        .toSet();
  }
}
