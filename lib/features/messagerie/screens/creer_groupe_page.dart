import 'package:flutter/material.dart';

import '../../../app/theme.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/helpers.dart';

import '../data/messagerie_mock.dart';

// ============================================================
// PAGE CRÉATION DE GROUPE
// ============================================================

class CreerGroupePage extends StatefulWidget {
  const CreerGroupePage({super.key});

  @override
  State<CreerGroupePage> createState() =>
      _CreerGroupePageState();
}

class _CreerGroupePageState
    extends State<CreerGroupePage> {
  final TextEditingController _nomCtrl =
      TextEditingController();

  TrajetPropose? _trajetChoisi;
  final Set<String> _passagersChoisis = {};

  @override
  void dispose() {
    _nomCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------
  // SÉLECTION D'UN TRAJET
  // ---------------------------------------------------------

  void _choisirTrajet(TrajetPropose trajet) {
    setState(() {
      _trajetChoisi = trajet;
      _passagersChoisis.clear();
    });
  }

  // ---------------------------------------------------------
  // VALIDATION ET CRÉATION
  // ---------------------------------------------------------

  void _creerGroupe() {
    final nom = _nomCtrl.text.trim();

    if (_trajetChoisi == null) {
      _erreur('Choisissez d\'abord un trajet.');
      return;
    }

    if (nom.isEmpty) {
      _erreur('Donnez un nom au groupe.');
      return;
    }

    if (_passagersChoisis.isEmpty) {
      _erreur(
        'Sélectionnez au moins un passager.',
      );
      return;
    }

    ajouterGroupeMock(
      titre: nom,
      trajet: _trajetChoisi!,
      membres: [
        monNom,
        ..._passagersChoisis,
      ],
    );

    Navigator.pop(context, nom);
  }

  void _erreur(String texte) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texte)),
    );
  }

  // ---------------------------------------------------------
  // PASSAGERS DU TRAJET CHOISI
  // ---------------------------------------------------------

  List<String> get _passagersDisponibles {
    final trajet = _trajetChoisi;
    if (trajet == null) return const [];
    return passagersTrajetMock[trajet.id] ?? const [];
  }

  @override
  Widget build(BuildContext context) {
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
                    'Nouveau groupe',
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
            // ÉTAPE 1 — CHOISIR LE TRAJET
            // =====================================================

            const Text(
              '1 — Choisir le trajet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 12),

            for (final trajet
                in trajetsConducteurMock) ...[
              _CarteTrajet(
                trajet: trajet,
                selectionne:
                    _trajetChoisi?.id == trajet.id,
                onTap: () {
                  _choisirTrajet(trajet);
                },
              ),

              const SizedBox(height: 12),
            ],

            const SizedBox(height: 8),

            // =====================================================
            // ÉTAPE 2 — NOM DU GROUPE
            // =====================================================

            const Text(
              '2 — Nom du groupe',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 12),

            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.bordure,
                ),
              ),
              child: TextField(
                controller: _nomCtrl,
                decoration:
                    const InputDecoration(
                  border: InputBorder.none,
                  hintText:
                      'Ex. Groupe Tunis → Hammamet',
                  hintStyle: TextStyle(
                    fontSize: 15,
                    color: AppColors.texte2,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // =====================================================
            // ÉTAPE 3 — PASSAGERS
            // =====================================================

            const Text(
              '3 — Passagers du trajet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 12),

            if (_trajetChoisi == null)
              const Text(
                'Sélectionnez un trajet pour voir '
                    'les passagers.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.texte2,
                ),
              ),

            for (final passager
                in _passagersDisponibles)
              _CasePassager(
                nom: passager,
                coche:
                    _passagersChoisis.contains(
                  passager,
                ),
                onTap: () {
                  setState(() {
                    if (_passagersChoisis.contains(
                      passager,
                    )) {
                      _passagersChoisis.remove(
                        passager,
                      );
                    } else {
                      _passagersChoisis.add(
                        passager,
                      );
                    }
                  });
                },
              ),

            const SizedBox(height: 20),

            // =====================================================
            // BOUTON CRÉER
            // =====================================================

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor:
                      AppColors.primaire,
                  minimumSize: const Size(
                    0,
                    48,
                  ),
                ),
                onPressed: _creerGroupe,
                child: const Text(
                  'Créer le groupe',
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
// CARTE DE TRAJET SÉLECTIONNABLE
// ============================================================

class _CarteTrajet extends StatelessWidget {
  final TrajetPropose trajet;
  final bool selectionne;
  final VoidCallback onTap;

  const _CarteTrajet({
    required this.trajet,
    required this.selectionne,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selectionne
          ? AppColors.primaireDoux
          : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(18),
            border: Border.all(
              color: selectionne
                  ? AppColors.primaire
                  : AppColors.bordure,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor:
                    AppColors.primaireDoux,
                child: const Icon(
                  Icons.directions_car_outlined,
                  color: AppColors.primaire,
                  size: 20,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      trajet.label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      '${fDateCourte(trajet.dateDepart)} · '
                          '${fHeure(trajet.dateDepart)} · '
                          '${trajet.placesTotales} place(s)',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.texte2,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
                selectionne
                    ? Icons
                        .radio_button_checked
                    : Icons
                        .radio_button_unchecked,
                size: 22,
                color: selectionne
                    ? AppColors.primaire
                    : AppColors.texte2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PASSAGER AVEC CASE À COCHER
// ============================================================

class _CasePassager extends StatelessWidget {
  final String nom;
  final bool coche;
  final VoidCallback onTap;

  const _CasePassager({
    required this.nom,
    required this.coche,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius:
              BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.bordure,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: coche
                        ? AppColors.primaire
                        : Colors.white,
                    borderRadius:
                        BorderRadius.circular(
                      6,
                    ),
                    border: Border.all(
                      color: coche
                          ? AppColors.primaire
                          : AppColors.bordure,
                    ),
                  ),
                  child: coche
                      ? const Icon(
                          Icons.check,
                          size: 16,
                          color: Colors.white,
                        )
                      : null,
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    nom,
                    style: const TextStyle(
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
