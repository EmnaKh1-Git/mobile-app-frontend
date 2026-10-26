import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../models/trajet.dart';

import '../models/conversation.dart';
import '../models/membre.dart';
import '../services/contexte_utilisateur.dart';
import '../services/messagerie_service.dart';

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
  /// Conversation toujours à jour dans le service.
  Conversation get _conversation =>
      MessagerieService.instance.conversation(
        widget.conversation.id,
      ) ??
      widget.conversation;

  // ---------------------------------------------------------
  // RÔLES ET DONNÉES
  // ---------------------------------------------------------

  /// Vrai si l'utilisateur connecté est le créateur du groupe.
  bool get _jeConduis =>
      _conversation.createurId ==
      ContexteUtilisateur.instance.idConnecte;

  /// Trajet associé au groupe.
  Trajet? get _trajet {
    final trajetId = _conversation.trajetId;
    if (trajetId == null) return null;
    return MessagerieService.instance.trajet(trajetId);
  }

  /// Passagers du trajet pas encore dans le groupe.
  List<Membre> get _passagersEligibles {
    final trajet = _trajet;
    if (trajet == null) return const [];

    final passagers = MessagerieService.instance
        .passagersDuTrajet(trajet.id.toString());

    return passagers
        .where(
          (p) => _conversation.membreParId(p.id) == null,
        )
        .toList();
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

    final choix = await showDialog<Membre>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Ajouter un membre'),
        children: [
          for (final membre in eligibles)
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, membre);
              },
              child: Text(membre.nom),
            ),
        ],
      ),
    );

    if (choix == null || !mounted) return;

    await _executer(
      () => MessagerieService.instance.ajouterMembre(
        widget.conversation.id,
        choix,
      ),
    );
  }

  // ---------------------------------------------------------
  // RETIRER UN MEMBRE (confirmation)
  // ---------------------------------------------------------

  Future<void> _confirmerRetrait(
    Membre membre,
  ) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer un membre ?'),
        content: Text(
          '${membre.nom} ne fera plus partie du groupe.',
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

    await _executer(
      () => MessagerieService.instance.retirerMembre(
        widget.conversation.id,
        membre.id,
      ),
    );
  }

  // ---------------------------------------------------------
  // ANNULER UNE RÉSERVATION (simulation)
  // ---------------------------------------------------------

  Future<void> _annulerReservation(Membre passager) async {
    await _executer(
      () => MessagerieService.instance.annulerReservation(
        widget.conversation.id,
        passager.id,
      ),
    );
  }

  // ---------------------------------------------------------
  // TERMINER LE TRAJET (simulation → groupe archivé)
  // ---------------------------------------------------------

  Future<void> _terminerTrajet() async {
    await _executer(
      () => MessagerieService.instance.terminerTrajet(
        widget.conversation.id,
      ),
    );
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

  Future<void> _executer(
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on MessagerieException catch (e) {
      if (!mounted) return;
      _message(e.message);
    }
  }

  // ---------------------------------------------------------
  // CONSTRUCTION
  // ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MessagerieService.instance,
      builder: (context, _) {
        final conversation = _conversation;
        final membres = conversation.membres;
        final archivee = conversation.archive;

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

            if (archivee) ...[
              const SizedBox(height: 8),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bordure,
                    borderRadius:
                        BorderRadius.circular(18),
                  ),
                  child: const Text(
                    'Archivé',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.texte2,
                    ),
                  ),
                ),
              ),
            ],

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
              'Membres (${membres.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 12),

            for (final membre in membres)
              _CarteMembre(
                nom: membre.nom,
                conducteur: membre.estConducteur,
                onRetirer: _jeConduis &&
                        !archivee &&
                        membre.id !=
                            ContexteUtilisateur.instance.idConnecte
                    ? () {
                        _confirmerRetrait(membre);
                      }
                    : null,
                onAnnulerReservation:
                    !archivee && !membre.estConducteur
                        ? () {
                            _annulerReservation(
                              membre,
                            );
                          }
                        : null,
              ),

            const SizedBox(height: 12),

            // =====================================================
            // AJOUTER UN MEMBRE (conducteur uniquement)
            // =====================================================

            if (_jeConduis && !archivee)
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
                    value: conversation.muet,
                    onChanged: archivee
                        ? null
                        : (valeur) {
                            MessagerieService.instance
                                .changerModeMuet(
                              widget.conversation.id,
                              valeur,
                            );
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
            // TERMINER LE TRAJET
            // =====================================================

            if (!archivee) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        AppColors.primaireDoux,
                    foregroundColor:
                        AppColors.primaire,
                    minimumSize: const Size(
                      0,
                      44,
                    ),
                  ),
                  onPressed: _terminerTrajet,
                  child: const Text(
                    'Marquer le trajet terminé',
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

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
      },
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
  final VoidCallback? onAnnulerReservation;

  const _CarteMembre({
    required this.nom,
    required this.conducteur,
    this.onRetirer,
    this.onAnnulerReservation,
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
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
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
                      fontWeight:
                          FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    nom,
                    overflow:
                        TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight:
                          FontWeight.w700,
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
                      fontWeight:
                          FontWeight.w700,
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

            if (onAnnulerReservation != null) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onAnnulerReservation,
                  icon: const Icon(
                    Icons.event_busy_outlined,
                    size: 18,
                    color: AppColors.accent,
                  ),
                  label: const Text(
                    'Annuler la réservation',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
