// ============================================================
//  MODULE : GESTION DES TRAJETS (Yassine)
//  Fichier : lib/features/trajet/services/assistant_trajet.dart
//
//  Assistant de recherche (chatbot) : il comprend des phrases simples
//  en français (« Tunis à Sousse demain matin, moins de 20 DT »),
//  cherche les trajets correspondants, les classe avec un score
//  (prix, note du conducteur, horaire) et recommande le meilleur.
//  Fonctionne hors connexion : aucune clé API, aucun serveur.
//  Les critères compris sont gardés d'un message à l'autre : on peut
//  affiner (« le moins cher », « plutôt le soir », « 2 places »…).
// ============================================================

import '../../../models/trajet.dart';
import '../utils/trajet_format.dart';
import 'trajet_service.dart';

// ------------------------------------------------------------
// 1. CRITÈRES COMPRIS PAR L'ASSISTANT
// ------------------------------------------------------------

/// Ce qui compte le plus pour l'utilisateur
enum PrioriteAssistant { equilibre, prix, note, heure }

extension PrioriteAssistantX on PrioriteAssistant {
  String get libelle {
    switch (this) {
      case PrioriteAssistant.equilibre:
        return 'Meilleur compromis';
      case PrioriteAssistant.prix:
        return 'Le moins cher';
      case PrioriteAssistant.note:
        return 'Le mieux noté';
      case PrioriteAssistant.heure:
        return 'Le plus tôt';
    }
  }
}

enum MomentJournee { matin, apresMidi, soir }

extension MomentJourneeX on MomentJournee {
  String get libelle {
    switch (this) {
      case MomentJournee.matin:
        return 'Le matin';
      case MomentJournee.apresMidi:
        return 'L’après-midi';
      case MomentJournee.soir:
        return 'Le soir';
    }
  }

  bool contient(DateTime d) {
    switch (this) {
      case MomentJournee.matin:
        return d.hour >= 5 && d.hour < 12;
      case MomentJournee.apresMidi:
        return d.hour >= 12 && d.hour < 18;
      case MomentJournee.soir:
        return d.hour >= 17 || d.hour < 5;
    }
  }
}

class CriteresAssistant {
  String? depart;
  String? arrivee;
  DateTime? date;

  /// L'utilisateur a dit « peu importe la date » : on ne la redemande plus
  bool dateIndifferente = false;
  MomentJournee? moment;

  /// Heure souhaitée (« vers 8h »)
  int? heure;
  int places = 1;
  double? prixMax;
  bool animaux = false;
  bool bagages = false;
  bool nonFumeur = false;
  bool reservationInstantanee = false;
  PrioriteAssistant priorite = PrioriteAssistant.equilibre;

  bool get aUneVille => depart != null || arrivee != null;

  /// « Tunis → Sousse », « Tunis → toutes destinations »…
  String get itineraire =>
      '${depart ?? 'Partout'} → ${arrivee ?? 'toutes destinations'}';

  /// Étiquettes « Ce que j'ai compris » affichées en haut du chat
  List<String> resume(DateTime maintenant) => [
        if (depart != null) 'De $depart',
        if (arrivee != null) 'Vers $arrivee',
        if (date != null)
          _majuscule(tJourRelatif(date!, maintenant: maintenant))
        else if (dateIndifferente)
          'Toutes dates',
        if (heure != null)
          'Vers ${heure}h'
        else if (moment != null)
          moment!.libelle,
        if (places > 1) '$places places',
        if (prixMax != null) '≤ ${tPrix(prixMax!)}',
        if (animaux) 'Animaux',
        if (bagages) 'Bagages',
        if (nonFumeur) 'Non-fumeur',
        if (reservationInstantanee) 'Réservation instantanée',
        if (priorite != PrioriteAssistant.equilibre) priorite.libelle,
      ];
}

// ------------------------------------------------------------
// 2. MESSAGES ÉCHANGÉS
// ------------------------------------------------------------

/// Ce que fait une réponse rapide quand on la touche
enum ActionAssistant { envoyer, voirResultats, creerAlerte }

class SuggestionAssistant {
  final String libelle;
  final ActionAssistant action;
  const SuggestionAssistant(this.libelle,
      [this.action = ActionAssistant.envoyer]);
}

class TrajetRecommande {
  final Trajet trajet;

  /// Prix payé par le passager (prix de l'étape s'il descend avant la fin)
  final double prix;

  /// Score de 0 à 100 (affiché « Compatible à 92 % »)
  final int score;
  final List<String> raisons;

  const TrajetRecommande({
    required this.trajet,
    required this.prix,
    required this.score,
    required this.raisons,
  });
}

class MessageAssistant {
  final bool deUtilisateur;
  final String texte;

  /// Trajets proposés, du meilleur au moins bon (le premier est recommandé)
  final List<TrajetRecommande> trajets;
  final List<SuggestionAssistant> suggestions;
  final DateTime heure;

  MessageAssistant({
    required this.deUtilisateur,
    required this.texte,
    this.trajets = const [],
    this.suggestions = const [],
    DateTime? heure,
  }) : heure = heure ?? DateTime.now();
}

// ------------------------------------------------------------
// 3. L'ASSISTANT
// ------------------------------------------------------------

class AssistantTrajet {
  AssistantTrajet({
    this.prenom = '',
    this.utilisateurId,
    List<Trajet> Function()? source,
    DateTime Function()? horloge,
  })  : _source = source ?? (() => TrajetService.instance.tous),
        _horloge = horloge ?? DateTime.now;

  final String prenom;

  /// Utilisateur connecté : on ne lui propose pas ses propres trajets
  final int? utilisateurId;
  final List<Trajet> Function() _source;
  final DateTime Function() _horloge;

  CriteresAssistant criteres = CriteresAssistant();

  /// Nombre maximum de trajets montrés dans une réponse
  static const int nbProposes = 3;

  DateTime get maintenant => _horloge();

  /// Trajets qu'on peut proposer : réservables et publiés par quelqu'un d'autre
  Iterable<Trajet> get _proposables => _source()
      .where((t) => t.estReservable && t.conducteurId != utilisateurId);

  // ---------- Accueil ----------
  MessageAssistant accueil() {
    final salut = prenom.isEmpty ? 'Bonjour !' : 'Bonjour $prenom !';
    return _bot(
      '$salut Je suis votre assistant covoiturage.\n'
      'Dites-moi où vous voulez aller et je vous aide à choisir le '
      'meilleur trajet : prix, horaire, note du conducteur…',
      suggestions: [
        for (final r in _itinerairesPopulaires().take(3))
          SuggestionAssistant(r),
        const SuggestionAssistant('Le moins cher demain'),
      ],
    );
  }

  // ---------- Réponse à un message ----------
  MessageAssistant repondre(String message) {
    final t = normaliser(message);
    if (t.isEmpty) return _incompris();

    if (_contient(t, [
      'nouvelle recherche',
      'recommencer',
      'reinitialiser',
      'on recommence',
      'tout effacer',
      'reset',
    ])) {
      criteres = CriteresAssistant();
      return _bot(
        'C’est reparti ! Où souhaitez-vous aller ?',
        suggestions: _suggestionsDestinations(),
      );
    }

    final prioriteAvant = criteres.priorite;
    final compris = _analyser(t);

    if (!compris) {
      if (_contient(t, ['merci', 'parfait', 'super', 'genial', 'top', 'chokran', 'yaatik'])) {
        return _bot(
          'Avec plaisir ! Touchez « Voir » sur un trajet pour le réserver. '
          'Bon voyage !',
          suggestions: const [SuggestionAssistant('Nouvelle recherche')],
        );
      }
      if (_contient(t, ['au revoir', 'bye', 'a bientot', 'bslema', 'bonne journee'])) {
        return _bot('À bientôt et bonne route !');
      }
      if (_contient(t, ['bonjour', 'salut', 'bonsoir', 'hello', 'coucou', 'salam', 'aslema', 'ahla'])) {
        return accueil();
      }
      if (_contient(t, ['reserv'])) {
        return _bot(
          'Pour réserver, touchez « Voir » sur le trajet qui vous plaît '
          'puis « Réserver ». Dites-moi d’abord où vous allez !',
          suggestions: _suggestionsDestinations(),
        );
      }
      if (_contient(t, ['aide', 'comment ca marche', 'que peux-tu', 'tu peux faire', 'help'])) {
        return _aide();
      }
      return _incompris();
    }

    if (!criteres.aUneVille) {
      return _bot(
        'C’est noté. Où souhaitez-vous aller ?',
        suggestions: _suggestionsDestinations(),
      );
    }

    final accuse = criteres.priorite != prioriteAvant
        ? _accusePriorite(criteres.priorite)
        : '';
    return _proposer(accuse);
  }

  // ------------------------------------------------------------
  // ANALYSE DU MESSAGE (met à jour les critères)
  // Retourne true si au moins une information a été comprise.
  // ------------------------------------------------------------
  bool _analyser(String t) {
    var compris = false;
    if (_analyserVilles(t)) compris = true;
    if (_analyserDate(t)) compris = true;
    if (_analyserMoment(t)) compris = true;
    if (_analyserPrix(t)) compris = true;
    if (_analyserPlaces(t)) compris = true;
    if (_analyserPreferences(t)) compris = true;
    if (_analyserPriorite(t)) compris = true;
    return compris;
  }

  bool _analyserVilles(String t) {
    // Toutes les villes connues : liste fixe + villes des trajets enregistrés
    final connues = <String, String>{..._villesTunisie};
    for (final tr in _source()) {
      for (final v in [tr.villeDepart, tr.villeArrivee, ...tr.etapes.map((e) => e.ville)]) {
        if (v.trim().isNotEmpty) connues.putIfAbsent(normaliser(v), () => v.trim());
      }
    }

    // On cherche les plus longs noms d'abord (« la marsa » avant « marsa »)
    final cles = connues.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    final trouvees = <({int position, String ville})>[];
    final occupe = List<bool>.filled(t.length, false);
    for (final cle in cles) {
      for (final m in RegExp('\\b${RegExp.escape(cle)}\\b').allMatches(t)) {
        if (occupe.sublist(m.start, m.end).any((x) => x)) continue;
        for (var i = m.start; i < m.end; i++) {
          occupe[i] = true;
        }
        trouvees.add((position: m.start, ville: connues[cle]!));
      }
    }
    if (trouvees.isEmpty) return false;
    trouvees.sort((a, b) => a.position.compareTo(b.position));

    // Rôle de chaque ville d'après les mots qui la précèdent
    final roles = <String?>[
      for (final v in trouvees)
        _roleVille(t.substring((v.position - 30).clamp(0, v.position), v.position)),
    ];

    if (trouvees.length >= 2) {
      // « Tunis Sousse », « Tunis → Sousse » : la 1re est le départ
      final dejaDepart = roles.contains('depart');
      for (var i = 0; i < roles.length; i++) {
        roles[i] ??= !dejaDepart && i == 0 ? 'depart' : 'arrivee';
      }
    } else if (roles.first == null) {
      // Une seule ville sans indice : c'est la destination, sauf si
      // la destination est déjà connue et pas le départ
      roles[0] = criteres.arrivee != null && criteres.depart == null
          ? 'depart'
          : 'arrivee';
    }

    for (var i = 0; i < trouvees.length; i++) {
      final ville = trouvees[i].ville;
      if (roles[i] == 'depart') {
        criteres.depart = ville;
        if (criteres.arrivee == ville) criteres.arrivee = null;
      } else {
        criteres.arrivee = ville;
        if (criteres.depart == ville) criteres.depart = null;
      }
    }
    return true;
  }

  /// 'depart', 'arrivee' ou null d'après le texte juste avant la ville
  String? _roleVille(String avant) {
    if (RegExp(r"(direction|destination|vers|jusqu'a|jusqua)\s*(de |d'|du )?\s*$").hasMatch(avant)) {
      return 'arrivee';
    }
    if (RegExp(r"\b(suis|habite|trouve|reste|loge)\s+(a|au|en|sur)\s*$").hasMatch(avant)) {
      return 'depart';
    }
    if (RegExp(r"(\bde|\bdu|\bdepuis|d'|\bquitte|\bquitter|\bdepart)\s*$").hasMatch(avant)) {
      return 'depart';
    }
    if (RegExp(r"\b(a|au|aux|en|pour|arrivee|aller)\s*$").hasMatch(avant)) {
      return 'arrivee';
    }
    return null;
  }

  bool _analyserDate(String t) {
    final n = maintenant;
    final aujourdhui = DateTime(n.year, n.month, n.day);
    DateTime? date;

    if (RegExp(r'apres[- ]demain').hasMatch(t)) {
      date = aujourdhui.add(const Duration(days: 2));
    } else if (RegExp(r'\bdemain\b').hasMatch(t)) {
      date = aujourdhui.add(const Duration(days: 1));
    } else if (_contient(t, ["aujourd'hui", 'aujourdhui', 'ce soir', 'ce matin', 'cet apres-midi', 'maintenant', 'tout de suite'])) {
      date = aujourdhui;
    } else if (_contient(t, ['ce week-end', 'ce weekend', 'le week-end', 'le weekend'])) {
      date = aujourdhui.add(Duration(days: (DateTime.saturday - n.weekday + 7) % 7));
    } else {
      for (var i = 0; i < _joursNormalises.length; i++) {
        if (RegExp('\\b${_joursNormalises[i]}\\b').hasMatch(t)) {
          date = aujourdhui.add(Duration(days: (i + 1 - n.weekday + 7) % 7));
          break;
        }
      }
    }

    // « le 28 », « 28 octobre », « 28/10 »
    if (date == null) {
      final mMois = RegExp(r'\b(\d{1,2})\s*(janv|fev|mars|avr|mai|juin|juil|aout|sept|oct|nov|dec)\w*').firstMatch(t);
      final mSlash = RegExp(r'\b(\d{1,2})/(\d{1,2})\b').firstMatch(t);
      final mLe = RegExp(r"\ble (\d{1,2})\b(?!\s*(dt|tnd|dinars?|places?|personnes?|passagers?|h\b|heures?|km|:))").firstMatch(t);
      int? jour;
      int? mois;
      if (mMois != null) {
        jour = int.parse(mMois.group(1)!);
        mois = _moisNormalises.indexOf(mMois.group(2)!) + 1;
      } else if (mSlash != null) {
        jour = int.parse(mSlash.group(1)!);
        mois = int.parse(mSlash.group(2)!);
      } else if (mLe != null) {
        jour = int.parse(mLe.group(1)!);
      }
      if (jour != null && jour >= 1 && jour <= 31 && (mois == null || (mois >= 1 && mois <= 12))) {
        var d = DateTime(n.year, mois ?? n.month, jour);
        if (d.isBefore(aujourdhui)) {
          d = mois == null ? DateTime(n.year, n.month + 1, jour) : DateTime(n.year + 1, mois, jour);
        }
        date = d;
      }
    }

    if (date != null) {
      criteres.date = date;
      criteres.dateIndifferente = false;
      return true;
    }

    final peuImporteSeul = (RegExp(r'peu importe\s*$').hasMatch(t) ||
            RegExp(r'^peu importe\b').hasMatch(t)) &&
        !_contient(t, ['prix', 'heure', 'moment']);
    if (peuImporteSeul ||
        _contient(t, ['peu importe la date', 'peu importe le jour', "n'importe quand", "n'importe quel jour", 'toutes dates', 'toute date', 'quand vous voulez', 'je suis flexible', 'pas de date'])) {
      criteres.date = null;
      criteres.dateIndifferente = true;
      return true;
    }
    return false;
  }

  bool _analyserMoment(String t) {
    if (_contient(t, ["peu importe l'heure", "n'importe quelle heure", 'toute la journee', "peu importe le moment"])) {
      criteres.moment = null;
      criteres.heure = null;
      return true;
    }

    var compris = false;
    final h = RegExp(r'\b(\d{1,2})\s*(?:h|heures?)\s*(\d{2})?\b').firstMatch(t);
    if (h != null) {
      final heure = int.parse(h.group(1)!);
      if (heure <= 23) {
        criteres.heure = heure;
        criteres.moment = null;
        compris = true;
      }
    } else if (RegExp(r'\ba midi\b').hasMatch(t)) {
      criteres.heure = 12;
      criteres.moment = null;
      compris = true;
    }

    MomentJournee? moment;
    if (_contient(t, ['apres-midi', 'apres midi', 'aprem'])) {
      moment = MomentJournee.apresMidi;
    } else if (RegExp(r'\b(matin|matinee|tot le matin)\b').hasMatch(t)) {
      moment = MomentJournee.matin;
    } else if (RegExp(r'\b(soir|soiree|nuit)\b').hasMatch(t)) {
      moment = MomentJournee.soir;
    }
    if (moment != null) {
      criteres.moment = moment;
      if (h == null) criteres.heure = null;
      compris = true;
    }
    return compris;
  }

  bool _analyserPrix(String t) {
    if (_contient(t, ['peu importe le prix', 'sans limite', "n'importe quel prix", 'pas de budget', 'sans budget'])) {
      criteres.prixMax = null;
      return true;
    }
    final m = RegExp(r"(moins de|max(?:imum)?|pas plus de|au plus|budget(?: de| max)?|jusqu'a|inferieur a|sous|<)\s*(\d+(?:[.,]\d+)?)(?!\s*(places?|personnes?|passagers?|h\b|heures?|km|min))").firstMatch(t) ??
        RegExp(r'(\d+(?:[.,]\d+)?)\s*(dt|tnd|dinars?)\b').firstMatch(t);
    if (m == null) return false;
    final brut = m.groupCount >= 2 && RegExp(r'^\d').hasMatch(m.group(2) ?? '')
        ? m.group(2)!
        : m.group(1)!;
    final prix = double.tryParse(brut.replaceAll(',', '.'));
    if (prix == null || prix <= 0) return false;
    criteres.prixMax = prix;
    return true;
  }

  bool _analyserPlaces(String t) {
    int? places;
    final m = RegExp(r'\b(\d|un|une|deux|trois|quatre)\s*(places?|personnes?|passagers?|sieges?)\b').firstMatch(t) ??
        RegExp(r'\b(?:nous sommes|on est|on sera|nous serons)\s*(\d|deux|trois|quatre)\b').firstMatch(t);
    if (m != null) {
      places = _nombre(m.group(1)!);
    } else if (RegExp(r"\bavec (un|une|mon|ma) (ami|amie|copain|copine|pote|collegue|frere|soeur|camarade)\b").hasMatch(t)) {
      places = 2;
    } else if (RegExp(r'\b(seul|seule|juste moi)\b').hasMatch(t)) {
      places = 1;
    }
    if (places == null) return false;
    criteres.places = places.clamp(1, 8);
    return true;
  }

  bool _analyserPreferences(String t) {
    var compris = false;
    if (RegExp(r'\b(animal|animaux|chien|chat|chiot|chaton)\b').hasMatch(t)) {
      criteres.animaux = true;
      compris = true;
    }
    if (RegExp(r'\b(bagages?|valises?)\b').hasMatch(t)) {
      criteres.bagages = true;
      compris = true;
    }
    if (_contient(t, ['non-fumeur', 'non fumeur', 'sans fumee', 'sans cigarette', 'pas fumeur'])) {
      criteres.nonFumeur = true;
      compris = true;
    }
    if (_contient(t, ['instantane', 'reservation auto', 'confirmation immediate', 'sans attendre'])) {
      criteres.reservationInstantanee = true;
      compris = true;
    }
    return compris;
  }

  bool _analyserPriorite(String t) {
    PrioriteAssistant? p;
    if (_contient(t, ['pas cher', 'moins cher', 'economique', 'petit prix', 'bon marche', 'meilleur prix'])) {
      p = PrioriteAssistant.prix;
    } else if (_contient(t, ['mieux note', 'meilleure note', 'bien note', 'fiable', 'serieux', 'confiance', 'securite', 'meilleur conducteur'])) {
      p = PrioriteAssistant.note;
    } else if (_contient(t, ['plus tot', 'rapide', 'vite', 'urgent', 'le premier', 'des que possible', 'au plus vite'])) {
      p = PrioriteAssistant.heure;
    } else if (_contient(t, ['compromis', 'equilibre', 'le meilleur'])) {
      p = PrioriteAssistant.equilibre;
    }
    if (p == null) return false;
    criteres.priorite = p;
    return true;
  }

  // ------------------------------------------------------------
  // RECHERCHE ET RECOMMANDATION
  // ------------------------------------------------------------

  /// Trajets réservables qui respectent les critères ; les options
  /// « ignorer… » servent à proposer des alternatives proches.
  List<Trajet> _filtrer({
    bool ignorerDate = false,
    bool ignorerMoment = false,
    bool ignorerPrix = false,
    bool ignorerOptions = false,
  }) {
    final c = criteres;
    return _proposables.where((t) {
      if (t.placesDispo < c.places) return false;
      if (c.depart != null && !_memeVille(t.villeDepart, c.depart!)) return false;
      if (c.arrivee != null && _etapeArrivee(t) == null) return false;
      if (!ignorerDate && c.date != null && !_memeJour(t.dateDepart, c.date!)) return false;
      if (!ignorerMoment) {
        if (c.heure != null && (t.dateDepart.hour - c.heure!).abs() > 2) return false;
        if (c.heure == null && c.moment != null && !c.moment!.contient(t.dateDepart)) return false;
      }
      if (!ignorerPrix && c.prixMax != null && _prixPour(t) > c.prixMax!) return false;
      if (!ignorerOptions) {
        if (c.animaux && !t.animaux) return false;
        if (c.bagages && !t.bagages) return false;
        if (c.nonFumeur && t.fumeur) return false;
        if (c.reservationInstantanee && !t.reservationAuto) return false;
      }
      return true;
    }).toList();
  }

  /// Ville où descend le passager : l'arrivée du trajet ou une étape.
  /// null si le trajet ne passe pas par la destination recherchée.
  String? _etapeArrivee(Trajet t) {
    final a = criteres.arrivee;
    if (a == null) return t.villeArrivee;
    if (_memeVille(t.villeArrivee, a)) return t.villeArrivee;
    for (final e in t.etapes) {
      if (_memeVille(e.ville, a)) return e.ville;
    }
    return null;
  }

  double _prixPour(Trajet t) {
    final a = criteres.arrivee;
    if (a != null && !_memeVille(t.villeArrivee, a)) {
      for (final e in t.etapes) {
        if (_memeVille(e.ville, a)) return e.prix;
      }
    }
    return t.prixPlace;
  }

  /// Classe les trajets : score pondéré selon la priorité de l'utilisateur
  List<TrajetRecommande> classer(List<Trajet> liste) {
    if (liste.isEmpty) return const [];
    final c = criteres;

    final prix = [for (final t in liste) _prixPour(t)];
    final pMin = prix.reduce((a, b) => a < b ? a : b);
    final pMax = prix.reduce((a, b) => a > b ? a : b);
    final noteMin = liste.map((t) => t.conducteurNote).reduce((a, b) => a < b ? a : b);
    final noteMax = liste.map((t) => t.conducteurNote).reduce((a, b) => a > b ? a : b);
    final departs = liste.map((t) => t.dateDepart.millisecondsSinceEpoch).toList();
    final dMin = departs.reduce((a, b) => a < b ? a : b);
    final dMax = departs.reduce((a, b) => a > b ? a : b);

    final (wPrix, wNote, wHeure) = switch (c.priorite) {
      PrioriteAssistant.prix => (0.65, 0.25, 0.10),
      PrioriteAssistant.note => (0.20, 0.70, 0.10),
      PrioriteAssistant.heure => (0.15, 0.15, 0.70),
      PrioriteAssistant.equilibre => (0.40, 0.40, 0.20),
    };

    final res = <TrajetRecommande>[];
    for (var i = 0; i < liste.length; i++) {
      final t = liste[i];
      final p = prix[i];
      final sPrix = pMax == pMin ? 1.0 : 1 - (p - pMin) / (pMax - pMin);
      // Les notes sont souvent proches (4,8 / 4,9) : on mélange la note
      // elle-même et sa place parmi les trajets proposés
      final sNote = 0.5 * ((t.conducteurNote - 3.5) / 1.5).clamp(0.0, 1.0) +
          0.5 * (noteMax == noteMin ? 1.0 : (t.conducteurNote - noteMin) / (noteMax - noteMin));
      int? ecartMinutes;
      double sHeure;
      if (c.heure != null) {
        final cible = DateTime(t.dateDepart.year, t.dateDepart.month, t.dateDepart.day, c.heure!);
        ecartMinutes = t.dateDepart.difference(cible).inMinutes.abs();
        sHeure = (1 - ecartMinutes / 360).clamp(0.0, 1.0);
      } else {
        final d = t.dateDepart.millisecondsSinceEpoch;
        sHeure = dMax == dMin ? 1.0 : 1 - (d - dMin) / (dMax - dMin);
      }
      final bonus = (t.reservationAuto ? 0.05 : 0.0) + (t.placesDispo > c.places ? 0.02 : 0.0);
      final score = ((wPrix * sPrix + wNote * sNote + wHeure * sHeure + bonus) * 100)
          .round()
          .clamp(0, 100);

      final plusieurs = liste.length > 1;
      final descente = _etapeArrivee(t);
      final raisons = <String>[
        if (plusieurs && p == pMin) 'Le moins cher',
        if (plusieurs && t.conducteurNote == noteMax)
          'Conducteur le mieux noté'
        else if (t.conducteurNote >= 4.7)
          'Conducteur très bien noté',
        if (ecartMinutes != null && ecartMinutes <= 60)
          'Proche de votre horaire'
        else if (plusieurs && t.dateDepart.millisecondsSinceEpoch == dMin)
          'Départ le plus tôt',
        if (t.reservationAuto) 'Réservation instantanée',
        if (descente != null && descente != t.villeArrivee) 'Dépose à $descente',
        if (c.animaux && t.animaux) 'Animaux acceptés',
        if (t.placesDispo <= c.places)
          'Dernière${t.placesDispo > 1 ? 's' : ''} place${t.placesDispo > 1 ? 's' : ''}',
      ];
      if (raisons.isEmpty) raisons.add('Correspond à vos critères');

      // La raison liée à la priorité de l'utilisateur passe en premier
      final cles = switch (c.priorite) {
        PrioriteAssistant.prix => const ['Le moins cher'],
        PrioriteAssistant.note => const ['Conducteur le mieux noté', 'Conducteur très bien noté'],
        PrioriteAssistant.heure => const ['Proche de votre horaire', 'Départ le plus tôt'],
        PrioriteAssistant.equilibre => const <String>[],
      };
      final prioritaire = raisons.indexWhere(cles.contains);
      if (prioritaire > 0) raisons.insert(0, raisons.removeAt(prioritaire));

      res.add(TrajetRecommande(trajet: t, prix: p, score: score, raisons: raisons));
    }
    // Priorité explicite (« le moins cher »…) : ce critère passe avant le score
    int cleHeure(Trajet t) => c.heure != null
        ? t.dateDepart
            .difference(DateTime(t.dateDepart.year, t.dateDepart.month, t.dateDepart.day, c.heure!))
            .inMinutes
            .abs()
        : t.dateDepart.millisecondsSinceEpoch;
    res.sort((a, b) {
      final critere = switch (c.priorite) {
        PrioriteAssistant.prix => a.prix.compareTo(b.prix),
        PrioriteAssistant.note => b.trajet.conducteurNote.compareTo(a.trajet.conducteurNote),
        PrioriteAssistant.heure => cleHeure(a.trajet).compareTo(cleHeure(b.trajet)),
        PrioriteAssistant.equilibre => 0,
      };
      if (critere != 0) return critere;
      final s = b.score.compareTo(a.score);
      return s != 0 ? s : a.trajet.dateDepart.compareTo(b.trajet.dateDepart);
    });
    return res;
  }

  MessageAssistant _proposer(String accuse) {
    final c = criteres;
    final liste = _filtrer();
    final quand = c.date == null ? '' : ' ${tJourRelatif(c.date!, maintenant: maintenant)}';

    if (liste.isNotEmpty) {
      final classes = classer(liste);
      final meilleur = classes.first;
      final t = meilleur.trajet;
      final n = liste.length;
      final intro = n == 1
          ? 'J’ai trouvé 1 trajet ${c.itineraire}$quand.'
          : 'J’ai trouvé $n trajets ${c.itineraire}$quand.';
      final conseil = n == 1
          ? 'Il part ${tJourRelatif(t.dateDepart, maintenant: maintenant)} à ${tHeure(t.dateDepart)} '
              'avec ${t.conducteurNom} (noté ${t.conducteurNote}/5) pour ${tPrix(meilleur.prix)}.'
          : 'Mon conseil : ${t.conducteurNom}, ${tJourRelatif(t.dateDepart, maintenant: maintenant)} '
              'à ${tHeure(t.dateDepart)} pour ${tPrix(meilleur.prix)} — '
              '${meilleur.raisons.first.toLowerCase()}.';

      final relance = _relance(liste);
      return _bot(
        [if (accuse.isNotEmpty) accuse, intro, conseil, if (relance.question.isNotEmpty) relance.question].join('\n'),
        trajets: classes.take(nbProposes).toList(),
        suggestions: [
          ...relance.suggestions,
          if (n > nbProposes)
            const SuggestionAssistant('Voir tous les résultats', ActionAssistant.voirResultats),
        ],
      );
    }

    // ---- Aucun résultat : on cherche une alternative proche ----
    final alternatives = <({String raison, List<Trajet> trajets, SuggestionAssistant suggestion})>[
      if (c.heure != null || c.moment != null)
        (
          raison: 'Aucun départ ${c.heure != null ? 'vers ${c.heure}h' : c.moment!.libelle.toLowerCase()}$quand, mais à d’autres heures :',
          trajets: _filtrer(ignorerMoment: true),
          suggestion: const SuggestionAssistant('Peu importe l’heure'),
        ),
      if (c.date != null)
        (
          raison: 'Aucun trajet ${c.itineraire}$quand, mais j’en ai trouvé à d’autres dates :',
          trajets: _filtrer(ignorerDate: true, ignorerMoment: true),
          suggestion: const SuggestionAssistant('Peu importe la date'),
        ),
      if (c.prixMax != null)
        (
          raison: 'Rien sous ${tPrix(c.prixMax!)}. Voici les trajets les moins chers :',
          trajets: _filtrer(ignorerPrix: true),
          suggestion: const SuggestionAssistant('Peu importe le prix'),
        ),
      if (c.animaux || c.bagages || c.nonFumeur || c.reservationInstantanee)
        (
          raison: 'Aucun trajet ne coche toutes vos options. Voici les plus proches :',
          trajets: _filtrer(ignorerOptions: true),
          suggestion: const SuggestionAssistant('Nouvelle recherche'),
        ),
    ];
    for (final alt in alternatives) {
      if (alt.trajets.isEmpty) continue;
      final classes = classer(alt.trajets);
      return _bot(
        alt.raison,
        trajets: classes.take(nbProposes).toList(),
        suggestions: [alt.suggestion, const SuggestionAssistant('Nouvelle recherche')],
      );
    }

    // Depuis cette ville, où peut-on aller ?
    final autres = c.depart == null
        ? <String>[]
        : _proposables
            .where((t) => _memeVille(t.villeDepart, c.depart!))
            .map((t) => t.villeArrivee)
            .toSet()
            .take(3)
            .toList();
    return _bot(
      'Je n’ai trouvé aucun trajet ${c.itineraire}$quand pour l’instant.\n'
      '${autres.isEmpty ? 'Créez une alerte : vous serez prévenu dès qu’un conducteur le publie.' : 'Depuis ${c.depart}, il y a des départs vers ${autres.join(', ')}.'}',
      suggestions: [
        const SuggestionAssistant('Créer une alerte', ActionAssistant.creerAlerte),
        for (final v in autres) SuggestionAssistant('De ${c.depart} à $v'),
        const SuggestionAssistant('Nouvelle recherche'),
      ],
    );
  }

  /// Question suivante pour affiner la recherche
  ({String question, List<SuggestionAssistant> suggestions}) _relance(List<Trajet> liste) {
    final c = criteres;
    final villesArrivee = liste.map((t) => t.villeArrivee).toSet();
    if (c.arrivee == null && villesArrivee.length > 1) {
      return (
        question: 'Où allez-vous ?',
        suggestions: [
          for (final v in villesArrivee.take(4)) SuggestionAssistant('Vers $v'),
        ],
      );
    }
    final villesDepart = liste.map((t) => t.villeDepart).toSet();
    if (c.depart == null && villesDepart.length > 1) {
      return (
        question: 'D’où partez-vous ?',
        suggestions: [
          for (final v in villesDepart.take(4)) SuggestionAssistant('Je pars de $v'),
        ],
      );
    }
    if (c.date == null && !c.dateIndifferente && liste.length > 1) {
      return (
        question: 'Quel jour souhaitez-vous partir ?',
        suggestions: const [
          SuggestionAssistant('Aujourd’hui'),
          SuggestionAssistant('Demain'),
          SuggestionAssistant('Après-demain'),
          SuggestionAssistant('Peu importe la date'),
        ],
      );
    }
    if (c.priorite == PrioriteAssistant.equilibre && liste.length > 1) {
      return (
        question: 'Qu’est-ce qui compte le plus pour vous ?',
        suggestions: const [
          SuggestionAssistant('Le moins cher'),
          SuggestionAssistant('Le mieux noté'),
          SuggestionAssistant('Le plus tôt'),
        ],
      );
    }
    return (
      question: '',
      suggestions: [
        if (c.places == 1) const SuggestionAssistant('Nous sommes 2'),
        if (c.moment == null && c.heure == null) const SuggestionAssistant('Plutôt le matin'),
        const SuggestionAssistant('Nouvelle recherche'),
      ],
    );
  }

  String _accusePriorite(PrioriteAssistant p) {
    switch (p) {
      case PrioriteAssistant.prix:
        return 'Compris, je privilégie le prix le plus bas.';
      case PrioriteAssistant.note:
        return 'Compris, je privilégie les conducteurs les mieux notés.';
      case PrioriteAssistant.heure:
        return 'Compris, je privilégie les départs les plus tôt.';
      case PrioriteAssistant.equilibre:
        return 'Compris, je cherche le meilleur compromis.';
    }
  }

  // ------------------------------------------------------------
  // RÉPONSES TOUTES FAITES
  // ------------------------------------------------------------
  MessageAssistant _aide() => _bot(
        'Je comprends des demandes comme :\n'
        '• « De Tunis à Sousse demain matin »\n'
        '• « Vers Sfax, moins de 25 DT, nous sommes 2 »\n'
        '• « Le mieux noté », « plutôt le soir », « avec mon chien »\n'
        'Je garde vos critères : vous pouvez affiner au fur et à mesure.',
        suggestions: _suggestionsDestinations(),
      );

  MessageAssistant _incompris() => _bot(
        'Je n’ai pas bien compris. Essayez par exemple « De Tunis à Sousse '
        'demain matin » ou « Le moins cher vers Sfax ».',
        suggestions: [
          ..._suggestionsDestinations().take(2),
          const SuggestionAssistant('Aide'),
        ],
      );

  List<SuggestionAssistant> _suggestionsDestinations() {
    final routes = _itinerairesPopulaires();
    return routes.isEmpty
        ? const [SuggestionAssistant('Aide')]
        : [for (final r in routes.take(4)) SuggestionAssistant(r)];
  }

  /// « Tunis → Sousse »… les itinéraires les plus proposés en ce moment
  List<String> _itinerairesPopulaires() {
    final compte = <String, int>{};
    for (final t in _proposables) {
      final cle = '${t.villeDepart} → ${t.villeArrivee}';
      compte[cle] = (compte[cle] ?? 0) + 1;
    }
    return compte.keys.toList()..sort((a, b) => compte[b]!.compareTo(compte[a]!));
  }

  MessageAssistant _bot(
    String texte, {
    List<TrajetRecommande> trajets = const [],
    List<SuggestionAssistant> suggestions = const [],
  }) =>
      MessageAssistant(
        deUtilisateur: false,
        texte: texte,
        trajets: trajets,
        suggestions: suggestions,
        heure: maintenant,
      );
}

// ------------------------------------------------------------
// 4. OUTILS DE TEXTE
// ------------------------------------------------------------

/// Minuscules, sans accents, apostrophes droites, espaces simples
String normaliser(String s) {
  const avec = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿ';
  const sans = 'aaaaaaceeeeiiiinooooouuuuyy';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().replaceAll('œ', 'oe').replaceAll('æ', 'ae').split('')) {
    final i = avec.indexOf(ch);
    if (i != -1) {
      b.write(sans[i]);
    } else if (ch == '’' || ch == '`' || ch == '´') {
      b.write("'");
    } else {
      b.write(ch);
    }
  }
  return b.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

bool _contient(String t, List<String> mots) => mots.any(t.contains);

bool _memeVille(String a, String b) {
  final x = normaliser(a);
  final y = normaliser(b);
  return x == y || x.contains(y) || y.contains(x);
}

bool _memeJour(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _majuscule(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

int _nombre(String s) {
  const mots = {'un': 1, 'une': 1, 'deux': 2, 'trois': 3, 'quatre': 4};
  return mots[s] ?? int.tryParse(s) ?? 1;
}

const List<String> _joursNormalises = [
  'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'
];

const List<String> _moisNormalises = [
  'janv', 'fev', 'mars', 'avr', 'mai', 'juin',
  'juil', 'aout', 'sept', 'oct', 'nov', 'dec'
];

/// Villes reconnues même sans trajet publié (clé normalisée → nom affiché)
const Map<String, String> _villesTunisie = {
  'tunis': 'Tunis',
  'ariana': 'Ariana',
  'ben arous': 'Ben Arous',
  'manouba': 'Manouba',
  'la marsa': 'La Marsa',
  'marsa': 'La Marsa',
  'carthage': 'Carthage',
  'el mourouj': 'El Mourouj',
  'mourouj': 'El Mourouj',
  'rades': 'Radès',
  'ezzahra': 'Ezzahra',
  'bizerte': 'Bizerte',
  'nabeul': 'Nabeul',
  'hammamet': 'Hammamet',
  'zaghouan': 'Zaghouan',
  'enfidha': 'Enfidha',
  'sousse': 'Sousse',
  'monastir': 'Monastir',
  'mahdia': 'Mahdia',
  'kairouan': 'Kairouan',
  'sfax': 'Sfax',
  'gabes': 'Gabès',
  'medenine': 'Médenine',
  'djerba': 'Djerba',
  'jerba': 'Djerba',
  'zarzis': 'Zarzis',
  'tataouine': 'Tataouine',
  'gafsa': 'Gafsa',
  'tozeur': 'Tozeur',
  'kebili': 'Kébili',
  'kasserine': 'Kasserine',
  'sidi bouzid': 'Sidi Bouzid',
  'beja': 'Béja',
  'jendouba': 'Jendouba',
  'tabarka': 'Tabarka',
  'le kef': 'Le Kef',
  'kef': 'Le Kef',
  'siliana': 'Siliana',
};
