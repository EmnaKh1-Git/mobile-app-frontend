// ============================================================
//  MODULE : GESTION DES TRAJETS (Yassine)
//  Fichier : lib/features/trajet/screens/choix_itineraire_page.dart
//  Écran « Indiquer votre itinéraire » (comme inDrive) :
//    - champ « De » rempli automatiquement avec la position GPS
//    - champ « À » avec recherche d'adresse pendant la saisie
//    - onglets « Suggéré » (lieux récents) / « Enregistré » (favoris)
//    - bouton carte dans chaque champ : choisir le point sur la carte
//  Renvoie un ItineraireChoisi (départ + arrivée) avec Navigator.pop.
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/lieu.dart';
import '../services/carte_service.dart';
import 'choix_sur_carte_page.dart';

/// Résultat de l'écran
class ItineraireChoisi {
  final Lieu? depart;
  final Lieu? arrivee;
  const ItineraireChoisi(this.depart, this.arrivee);
}

class ChoixItinerairePage extends StatefulWidget {
  final Lieu? depart;
  final Lieu? arrivee;

  /// true : le curseur démarre dans le champ « À »
  final bool modifierArrivee;

  /// false (page Recherche) : on peut valider avec un seul des deux lieux
  final bool exigerLesDeux;

  /// Remplit « De » avec la position GPS s'il est vide
  final bool positionAuto;

  const ChoixItinerairePage({
    super.key,
    this.depart,
    this.arrivee,
    this.modifierArrivee = false,
    this.exigerLesDeux = true,
    this.positionAuto = true,
  });

  @override
  State<ChoixItinerairePage> createState() => _ChoixItinerairePageState();
}

class _ChoixItinerairePageState extends State<ChoixItinerairePage> {
  final _service = CarteService.instance;
  final _ctrlDepart = TextEditingController();
  final _ctrlArrivee = TextEditingController();
  final _focusDepart = FocusNode();
  final _focusArrivee = FocusNode();

  Lieu? _depart;
  Lieu? _arrivee;
  bool _champArrivee = false; // champ en cours de saisie
  bool _ongletEnregistre = false;

  List<Lieu> _recents = [];
  List<Lieu> _enregistres = [];
  List<Lieu> _resultats = [];
  bool _recherche = false; // requête de recherche en cours
  bool _localisation = false; // GPS en cours
  Timer? _attente;
  int _requete = 0;

  TextEditingController get _ctrlActif =>
      _champArrivee ? _ctrlArrivee : _ctrlDepart;
  Lieu? get _lieuActif => _champArrivee ? _arrivee : _depart;

  /// L'utilisateur tape une adresse (le champ ne contient pas un lieu choisi)
  bool get _enSaisie => _lieuActif == null && _ctrlActif.text.trim().length >= 2;

  @override
  void initState() {
    super.initState();
    _depart = widget.depart;
    _arrivee = widget.arrivee;
    _ctrlDepart.text = _depart?.nom ?? '';
    _ctrlArrivee.text = _arrivee?.nom ?? '';
    _champArrivee = widget.modifierArrivee;

    _focusDepart.addListener(() {
      if (_focusDepart.hasFocus) _activer(false);
    });
    _focusArrivee.addListener(() {
      if (_focusArrivee.hasFocus) _activer(true);
    });

    _chargerListes();
    if (_depart == null && widget.positionAuto) _remplirAvecPosition();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) (_champArrivee ? _focusArrivee : _focusDepart).requestFocus();
    });
  }

  @override
  void dispose() {
    _attente?.cancel();
    _ctrlDepart.dispose();
    _ctrlArrivee.dispose();
    _focusDepart.dispose();
    _focusArrivee.dispose();
    super.dispose();
  }

  // ---------- Données ----------

  Future<void> _chargerListes() async {
    final r = await _service.lieuxRecents();
    final e = await _service.lieuxEnregistres();
    if (!mounted) return;
    setState(() {
      _recents = r;
      _enregistres = e;
    });
  }

  /// Position GPS -> adresse. [forcer] : l'utilisateur a touché
  /// « Ma position actuelle » (sinon : remplissage automatique de « De »).
  Future<void> _remplirAvecPosition({bool forcer = false}) async {
    setState(() => _localisation = true);
    final pos = await _service.positionActuelle();
    final lieu = pos == null ? null : await _service.adresseDe(pos);
    if (!mounted) return;
    setState(() => _localisation = false);

    if (lieu == null) {
      if (forcer) {
        _message('Position indisponible : activez la localisation du téléphone.');
      }
      return;
    }
    if (forcer) {
      _choisir(lieu);
    } else if (_depart == null && _ctrlDepart.text.trim().isEmpty) {
      // Seulement si l'utilisateur n'a rien saisi entre-temps
      setState(() {
        _depart = lieu;
        _ctrlDepart.text = lieu.nom;
      });
    }
  }

  // ---------- Saisie et recherche ----------

  void _activer(bool arrivee) {
    if (_champArrivee == arrivee) return;
    _attente?.cancel();
    _requete++;
    setState(() {
      _champArrivee = arrivee;
      _resultats = [];
      _recherche = false;
    });
    // Sélectionne le texte : il suffit de taper pour le remplacer
    final c = _ctrlActif;
    c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length);
    if (_enSaisie) _saisie(c.text);
  }

  void _saisie(String _) {
    _attente?.cancel();
    final texte = _ctrlActif.text.trim();
    setState(() {
      // Le texte a changé : le lieu choisi pour ce champ n'est plus valable
      if (_champArrivee) {
        _arrivee = null;
      } else {
        _depart = null;
      }
      _recherche = texte.length >= 2;
      if (texte.length < 2) _resultats = [];
    });
    if (texte.length < 2) return;
    // On attend une courte pause dans la frappe avant d'interroger le serveur
    _attente = Timer(
        const Duration(milliseconds: 450), () => _lancerRecherche(texte));
  }

  Future<void> _lancerRecherche(String texte) async {
    final n = ++_requete;
    final res = await _service.rechercher(texte);
    if (!mounted || n != _requete) return; // réponse périmée
    setState(() {
      _resultats = res;
      _recherche = false;
    });
  }

  void _effacer() {
    _attente?.cancel();
    _requete++;
    setState(() {
      _ctrlActif.clear();
      if (_champArrivee) {
        _arrivee = null;
      } else {
        _depart = null;
      }
      _resultats = [];
      _recherche = false;
    });
  }

  // ---------- Choix d'un lieu ----------

  void _choisir(Lieu lieu) {
    _attente?.cancel();
    _requete++;
    setState(() {
      if (_champArrivee) {
        _arrivee = lieu;
        _ctrlArrivee.text = lieu.nom;
      } else {
        _depart = lieu;
        _ctrlDepart.text = lieu.nom;
      }
      _resultats = [];
      _recherche = false;
    });
    _service.memoriser(lieu).then((_) => _chargerListes());

    // Les deux lieux sont connus : on termine. Sinon, champ suivant.
    if (_depart != null && _arrivee != null) {
      _terminer();
    } else if (!_champArrivee) {
      _focusArrivee.requestFocus();
    } else {
      _focusDepart.requestFocus();
    }
  }

  Future<void> _surCarte(bool arrivee) async {
    _activer(arrivee);
    final actuel = arrivee ? _arrivee : _depart;
    final autre = arrivee ? _depart : _arrivee;
    FocusScope.of(context).unfocus();
    final lieu = await Navigator.push<Lieu>(
      context,
      MaterialPageRoute(
        builder: (_) => ChoixSurCartePage(
          initial: actuel ?? (arrivee ? null : autre),
          estArrivee: arrivee,
        ),
      ),
    );
    if (lieu == null || !mounted) return;
    _champArrivee = arrivee;
    _choisir(lieu);
  }

  Future<void> _basculerFavori(Lieu lieu) async {
    await _service.basculerEnregistre(lieu);
    await _chargerListes();
  }

  bool _estFavori(Lieu lieu) =>
      lieu.enregistre || _enregistres.any((e) => e.estLeMemeQue(lieu));

  void _terminer() {
    final d = _depart, a = _arrivee;
    if (widget.exigerLesDeux && (d == null || a == null)) {
      _message('Choisissez le départ et l’arrivée.');
      return;
    }
    if (d == null && a == null) {
      _message('Choisissez au moins un lieu.');
      return;
    }
    if (d != null && a != null && d.distanceVers(a) < 0.5) {
      _message('Le départ et l’arrivée sont trop proches.');
      return;
    }
    FocusScope.of(context).unfocus();
    Navigator.pop(context, ItineraireChoisi(d, a));
  }

  void _message(String texte) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texte)));
  }

  // ---------- Interface ----------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enSaisie = _enSaisie;
    final liste = _ongletEnregistre ? _enregistres : _recents;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text('Indiquer votre itinéraire',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (widget.exigerLesDeux
              ? (_depart != null && _arrivee != null)
              : (_depart != null || _arrivee != null))
            TextButton(onPressed: _terminer, child: const Text('Valider')),
          IconButton(
            tooltip: 'Fermer',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              children: [
                _ChampLieu(
                  label: 'De',
                  indication: _localisation ? 'Localisation…' : 'Point de départ',
                  icone: Icons.hail,
                  controller: _ctrlDepart,
                  focusNode: _focusDepart,
                  actif: !_champArrivee,
                  chargement: _localisation && _depart == null,
                  onChanged: _saisie,
                  onSubmitted: () {
                    if (_resultats.isNotEmpty) _choisir(_resultats.first);
                  },
                  onEffacer: _effacer,
                  onCarte: () => _surCarte(false),
                ),
                const SizedBox(height: 10),
                _ChampLieu(
                  label: 'À',
                  indication: 'Destination',
                  icone: Icons.flag,
                  controller: _ctrlArrivee,
                  focusNode: _focusArrivee,
                  actif: _champArrivee,
                  onChanged: _saisie,
                  onSubmitted: () {
                    if (_resultats.isNotEmpty) _choisir(_resultats.first);
                  },
                  onEffacer: _effacer,
                  onCarte: () => _surCarte(true),
                ),
              ],
            ),
          ),
          if (!enSaisie)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(
                children: [
                  _Onglet(
                    texte: 'Suggéré',
                    actif: !_ongletEnregistre,
                    onTap: () => setState(() => _ongletEnregistre = false),
                  ),
                  const SizedBox(width: 8),
                  _Onglet(
                    texte: 'Enregistré',
                    actif: _ongletEnregistre,
                    onTap: () => setState(() => _ongletEnregistre = true),
                  ),
                ],
              ),
            ),
          SizedBox(
            height: 2,
            child: _recherche ? const LinearProgressIndicator() : null,
          ),
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (enSaisie) ...[
                  // ---- Résultats de la recherche ----
                  for (final l in _resultats)
                    _TuileLieu(
                      lieu: l,
                      icone: Icons.place_outlined,
                      surligne: _ctrlActif.text.trim(),
                      favori: _estFavori(l),
                      onTap: () => _choisir(l),
                      onFavori: () => _basculerFavori(l),
                    ),
                  if (_resultats.isEmpty && !_recherche)
                    ListTile(
                      leading: Icon(Icons.search_off, color: cs.onSurfaceVariant),
                      title: const Text('Aucune adresse trouvée'),
                      subtitle: const Text(
                          'Vérifiez l’orthographe ou placez le point sur la carte.'),
                    ),
                ] else ...[
                  // ---- Raccourcis ----
                  ListTile(
                    leading: Icon(Icons.my_location, color: cs.primary),
                    title: const Text('Ma position actuelle',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    onTap: _localisation
                        ? null
                        : () => _remplirAvecPosition(forcer: true),
                  ),
                  // ---- Lieux récents ou enregistrés ----
                  for (final l in liste)
                    _TuileLieu(
                      lieu: l,
                      icone: _ongletEnregistre ? Icons.bookmark : Icons.schedule,
                      favori: _estFavori(l),
                      onTap: () => _choisir(l),
                      onFavori: () => _basculerFavori(l),
                    ),
                  if (liste.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _ongletEnregistre
                            ? 'Aucun lieu enregistré.\nTouchez le signet d’un lieu pour l’ajouter ici.'
                            : 'Vos derniers lieux apparaîtront ici.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ),
                ],
                ListTile(
                  leading: Icon(Icons.map_outlined, color: cs.primary),
                  title: const Text('Choisir sur la carte',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () => _surCarte(_champArrivee),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Champ « De » / « À » : bordure noire quand il est actif (comme inDrive)
class _ChampLieu extends StatelessWidget {
  final String label;
  final String indication;
  final IconData icone;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool actif;
  final bool chargement;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  final VoidCallback onEffacer;
  final VoidCallback onCarte;

  const _ChampLieu({
    required this.label,
    required this.indication,
    required this.icone,
    required this.controller,
    required this.focusNode,
    required this.actif,
    this.chargement = false,
    required this.onChanged,
    required this.onSubmitted,
    required this.onEffacer,
    required this.onCarte,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: focusNode.requestFocus,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: actif ? cs.onSurface : Colors.transparent, width: 2),
        ),
        child: Row(
          children: [
            Icon(actif ? Icons.search : icone, size: 26, color: cs.onSurface),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style:
                          TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onChanged: onChanged,
                    onSubmitted: (_) => onSubmitted(),
                    textInputAction: TextInputAction.search,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600),
                    decoration: InputDecoration.collapsed(hintText: indication),
                  ),
                ],
              ),
            ),
            if (chargement)
              const Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            if (actif && controller.text.isNotEmpty)
              IconButton(
                tooltip: 'Effacer',
                onPressed: onEffacer,
                icon: Icon(Icons.cancel, color: cs.onSurfaceVariant),
              ),
            IconButton.filledTonal(
              tooltip: 'Choisir sur la carte',
              onPressed: onCarte,
              icon: const Icon(Icons.map_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

/// Onglet « Suggéré » / « Enregistré » (pastille noire quand actif)
class _Onglet extends StatelessWidget {
  final String texte;
  final bool actif;
  final VoidCallback onTap;
  const _Onglet({required this.texte, required this.actif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: actif ? cs.inverseSurface : cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Text(
            texte,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: actif ? cs.onInverseSurface : cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

/// Ligne d'un lieu : icône, nom (partie tapée en couleur), complément, signet
class _TuileLieu extends StatelessWidget {
  final Lieu lieu;
  final IconData icone;
  final String surligne;
  final bool favori;
  final VoidCallback onTap;
  final VoidCallback onFavori;

  const _TuileLieu({
    required this.lieu,
    required this.icone,
    this.surligne = '',
    required this.favori,
    required this.onTap,
    required this.onFavori,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      leading: Icon(icone, color: cs.onSurfaceVariant),
      title: _titre(cs),
      subtitle: lieu.adresse.isEmpty
          ? null
          : Text(lieu.adresse,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: cs.onSurfaceVariant)),
      trailing: IconButton.filledTonal(
        tooltip: favori ? 'Retirer des lieux enregistrés' : 'Enregistrer ce lieu',
        onPressed: onFavori,
        icon: Icon(favori ? Icons.bookmark : Icons.bookmark_border),
      ),
    );
  }

  Widget _titre(ColorScheme cs) {
    final base = TextStyle(
        fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface);
    final nom = lieu.nom;
    final bas = nom.toLowerCase();
    final i = surligne.isEmpty || bas.length != nom.length
        ? -1
        : bas.indexOf(surligne.toLowerCase());
    if (i < 0) {
      return Text(nom,
          maxLines: 1, overflow: TextOverflow.ellipsis, style: base);
    }
    final fin = i + surligne.length;
    return Text.rich(
      TextSpan(style: base, children: [
        TextSpan(text: nom.substring(0, i)),
        TextSpan(
            text: nom.substring(i, fin), style: TextStyle(color: cs.primary)),
        TextSpan(text: nom.substring(fin)),
      ]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
