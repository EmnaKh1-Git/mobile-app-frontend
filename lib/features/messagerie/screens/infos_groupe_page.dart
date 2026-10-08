import 'package:flutter/material.dart';

import '../../../app/theme.dart';

import '../../../core/constants/app_constants.dart';

import '../data/messagerie_mock.dart';
import '../models/conversation.dart';

// ============================================================
// PAGE INFOS DU GROUPE
// ============================================================

class InfosGroupePage extends StatefulWidget {
  final Conversation conversation;

  const InfosGroupePage({
    super.key,
    required this.conversation,
  });

  @override
  State<InfosGroupePage> createState() =>
      _InfosGroupePageState();
}

class _InfosGroupePageState
    extends State<InfosGroupePage> {
  late List<String> _membres;
  late bool _muet;

  @override
  void initState() {
    super.initState();
    _membres = List.of(widget.conversation.membres);
    _muet = widget.conversation.muet;
  }

  // ---------------------------------------------------------
  // RÔLES ET DONNÉES
  // ---------------------------------------------------------

  /// Le premier membre de la liste est le conducteur.
  bool get _jeConduis =>
      _membres.isNotEmpty && _membres.first == monNom;

  /// Trajet du groupe dans les trajets factices.
  TrajetPropose? get _trajet {
    final label = widget.conversation.trajetLabel;
    return trajetsConducteurMock.where(
      (t) => label.startsWith(t.label),
    ).firstOrNull;
  }

  /// Passagers du trajet pas encore dans le groupe.
  List<String> get _passagersEligibles {
    final trajet = _trajet;
    if (trajet == null) return const [];

    final passagers =
        passagersTrajetMock[trajet.id] ?? const [];

    return passagers
        .where((p) => !_membres.contains(p))
        .toList();
  }

  /// Sauvegarde locale (liste mock, sans base de données).
  void _enregistrer() {
    mettreAJourGroupeMock(
      id: widget.conversation.id,
      membres: _membres,
      muet: _muet,
    );
  }

  // ---------------------------------------------------------
  // AJOUTER UN MEMBRE
  // ---------------------------------------------------------

  Future<void> _ajouterMembre() async {
    final eligibles = _passagersEligibles;

    if (eligibles.isEmpty) {
      _message(
        'Aucun passager éligible pour ce trajet.',
      );
      return;
    }

    final choix = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Ajouter un membre'),
        children: [
          for (final nom in eligibles)
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, nom);
              },
              child: Text(nom),
            ),
        ],
      ),
    );

    if (choix == null || !mounted) return;

    setState(() {
      _membres.add(choix);
    });
    _enregistrer();
  }

  // ---------------------------------------------------------
  // RETIRER UN MEMBRE (confirmation)
  // ---------------------------------------------------------

  Future<void> _confirmerRetrait(
    String membre,
  ) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer un membre ?'),
        content: Text(
          '$membre ne fera plus partie du groupe.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
            },
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, true);
            },
            child: const Text(
              'Retirer',
              style: TextStyle(
                color: AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirme != true || !mounted) return;

    setState(() {
      _membres.remove(membre);
    });
    _enregistrer();
  }

  // ---------------------------------------------------------
  // QUITTER LE GROUPE (confirmation)
  // ---------------------------------------------------------

  Future<void> _confirmerQuitter() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitter le groupe ?'),
        content: const Text(
          'Vous ne recevrez plus les messages '
              'de ce groupe.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
            },
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, true);
            },
            child: const Text(
              'Quitter',
              style: TextStyle(
                color: AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirme != true || !mounted) return;

    Navigator.pop(context, 'quitte');
  }

  void _message(String texte) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texte)),
    );
  }

  // ---------------------------------------------------------
  // CONSTRUCTION
  // ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final conversation = widget.conversation;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            24,
          ),
          children: [
            // =====================================================
            // HEADER
            // =====================================================

            Row(
              children: [
                IconButton.outlined(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(
                    Icons.arrow_back,
                  ),
                  tooltip: 'Retour',
                ),

                const SizedBox(width: 12),

                const Expanded(
                  child: Text(
                    'Infos du groupe',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // =====================================================
            // AVATAR, NOM ET TRAJET
            // =====================================================

            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor:
                    AppColors.primaire,
                child: Text(
                  conversation.initiale,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 32,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            Center(
              child: Text(
                conversation.titre,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),

            const SizedBox(height: 10),

            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.infoFond,
                  borderRadius:
                      BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.route_outlined,
                      size: 16,
                      color: AppColors.infoTexte,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      conversation.trajetLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight:
                            FontWeight.w700,
                        color:
                            AppColors.infoTexte,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // =====================================================
            // MEMBRES
            // =====================================================

            Text(
              'Membres (${_membres.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 12),

            for (final membre in _membres)
              _CarteMembre(
                nom: membre,
                conducteur:
                    _membres.first == membre,
                onRetirer: _jeConduis &&
                        membre != monNom
                    ? () {
                        _confirmerRetrait(membre);
                      }
                    : null,
              ),

            const SizedBox(height: 12),

            // =====================================================
            // AJOUTER UN MEMBRE (conducteur uniquement)
            // =====================================================

            if (_jeConduis)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style:
                      FilledButton.styleFrom(
                    backgroundColor:
                        AppColors.primaireDoux,
                    foregroundColor:
                        AppColors.primaire,
                    minimumSize: const Size(
                      0,
                      40,
                    ),
                  ),
                  onPressed: _ajouterMembre,
                  child: const Text(
                    'Ajouter un membre',
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // =====================================================
            // MODE MUET
            // =====================================================

            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.bordure,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.volume_off_outlined,
                    size: 20,
                    color: AppColors.texte2,
                  ),

                  const SizedBox(width: 12),

                  const Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          'Mode muet',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Désactiver les notifications '
                              'de ce groupe',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                AppColors.texte2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Switch(
                    value: _muet,
                    onChanged: (valeur) {
                      setState(() {
                        _muet = valeur;
                      });
                      _enregistrer();
                    },
                    activeTrackColor:
                        AppColors.primaire,
                    inactiveTrackColor:
                        AppColors.bordure,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // =====================================================
            // QUITTER LE GROUPE
            // =====================================================

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor:
                      AppColors.accent,
                  minimumSize: const Size(
                    0,
                    48,
                  ),
                ),
                onPressed: _confirmerQuitter,
                child: const Text(
                  'Quitter le groupe',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// CARTE D'UN MEMBRE
// ============================================================

class _CarteMembre extends StatelessWidget {
  final String nom;
  final bool conducteur;
  final VoidCallback? onRetirer;

  const _CarteMembre({
    required this.nom,
    required this.conducteur,
    this.onRetirer,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.bordure,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor:
                  AppColors.primaire,
              child: Text(
                nom.trim().isEmpty
                    ? '?'
                    : nom.trim()[0]
                        .toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Text(
                nom,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: conducteur
                    ? AppColors.infoFond
                    : AppColors.bordure,
                borderRadius:
                    BorderRadius.circular(18),
              ),
              child: Text(
                conducteur
                    ? 'Conducteur'
                    : 'Passager',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: conducteur
                      ? AppColors.infoTexte
                      : AppColors.texte2,
                ),
              ),
            ),

            if (onRetirer != null) ...[
              const SizedBox(width: 4),
              IconButton(
                onPressed: onRetirer,
                icon: const Icon(
                  Icons.person_remove_outlined,
                  size: 20,
                  color: AppColors.accent,
                ),
                tooltip: 'Retirer',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
