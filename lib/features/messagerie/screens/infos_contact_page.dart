import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/utils/helpers.dart';
import '../../user/models/user_model.dart';

import '../models/conversation.dart';
import '../models/membre.dart';
import '../services/contexte_utilisateur.dart';
import '../services/messagerie_service.dart';

// ============================================================
// PAGE INFOS DU CONTACT (conversation privée)
// ============================================================
//
// Profil public de l'interlocuteur : nom, rôle, note, trajets,
// université, gouvernorat et véhicule. L'e-mail, le téléphone et
// l'immatriculation ne sont pas affichés (vie privée).

class InfosContactPage extends StatelessWidget {
  final Conversation conversation;

  const InfosContactPage({
    super.key,
    required this.conversation,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MessagerieService.instance,
      builder: (context, _) {
        final service = MessagerieService.instance;
        final conv = service.conversation(conversation.id) ?? conversation;
        final contact = _interlocuteur(conv);
        final user = contact == null ? null : service.utilisateur(contact.id);
        final nom = user?.nomComplet.trim().isNotEmpty == true
            ? user!.nomComplet
            : (contact?.nom ?? conv.titre);

        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Row(
                  children: [
                    IconButton.outlined(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Retour',
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Infos du contact',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // AVATAR, NOM, RÔLE
                Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.primaire,
                    child: Text(
                      nom.trim().isEmpty ? '?' : nom.trim()[0].toUpperCase(),
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
                    nom,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (user != null) ...[
                  const SizedBox(height: 8),
                  Center(child: _Pastille(texte: user.role.label)),
                ],
                if (conv.bloque) ...[
                  const SizedBox(height: 8),
                  const Center(
                    child: _Pastille(texte: 'Bloqué', alerte: true),
                  ),
                ],
                const SizedBox(height: 20),

                if (user == null)
                  const _Carte(
                    children: [
                      Text(
                        'Profil indisponible pour le moment.',
                        style: TextStyle(color: AppColors.texte2),
                      ),
                    ],
                  )
                else ...[
                  _Carte(
                    children: [
                      Row(
                        children: [
                          _Stat(
                            icone: Icons.star_rounded,
                            valeur: user.note.toStringAsFixed(1),
                            libelle: 'Note',
                          ),
                          _Stat(
                            icone: Icons.directions_car_outlined,
                            valeur: '${user.nombreTrajets}',
                            libelle: 'Trajets',
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _Carte(
                    children: [
                      _Ligne(
                        icone: Icons.school_outlined,
                        libelle: 'Université',
                        valeur: user.universite,
                      ),
                      _Ligne(
                        icone: Icons.location_on_outlined,
                        libelle: 'Gouvernorat',
                        valeur: user.gouvernorat,
                      ),
                      if (user.dateInscription != null)
                        _Ligne(
                          icone: Icons.calendar_today_outlined,
                          libelle: 'Membre depuis',
                          valeur: fDateCourte(user.dateInscription!),
                        ),
                    ],
                  ),
                  if (_vehicule(user) != null) ...[
                    const SizedBox(height: 12),
                    _Carte(
                      children: [
                        _Ligne(
                          icone: Icons.directions_car_filled_outlined,
                          libelle: 'Véhicule',
                          valeur: _vehicule(user)!,
                        ),
                      ],
                    ),
                  ],
                ],
                const SizedBox(height: 20),

                // ACTIONS
                _Carte(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.notifications_off_outlined),
                      title: const Text('Mettre en sourdine'),
                      value: conv.muet,
                      onChanged: (valeur) =>
                          service.changerModeMuet(conv.id, valeur),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        conv.bloque ? Icons.lock_open : Icons.block,
                        color: AppColors.alerte,
                      ),
                      title: Text(
                        conv.bloque
                            ? 'Débloquer $nom'
                            : 'Bloquer $nom',
                        style: const TextStyle(color: AppColors.alerte),
                      ),
                      onTap: () => _basculerBloque(context, conv),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Membre? _interlocuteur(Conversation conv) {
    final moi = ContexteUtilisateur.instance.idConnecte;
    for (final membre in conv.membres) {
      if (membre.id != moi) return membre;
    }
    return null;
  }

  String? _vehicule(UserModel user) {
    final parties = [
      user.marqueVehicule,
      user.modeleVehicule,
      user.couleurVehicule,
    ].whereType<String>().where((p) => p.trim().isNotEmpty).toList();
    return parties.isEmpty ? null : parties.join(' · ');
  }

  Future<void> _basculerBloque(
    BuildContext context,
    Conversation conv,
  ) async {
    try {
      await MessagerieService.instance.basculerBloque(conv.id);
    } on MessagerieException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }
}

class _Carte extends StatelessWidget {
  final List<Widget> children;

  const _Carte({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.bordure),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _Pastille extends StatelessWidget {
  final String texte;
  final bool alerte;

  const _Pastille({required this.texte, this.alerte = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: alerte ? AppColors.bordure : AppColors.infoFond,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        texte,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: alerte ? AppColors.alerte : AppColors.infoTexte,
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icone;
  final String valeur;
  final String libelle;

  const _Stat({
    required this.icone,
    required this.valeur,
    required this.libelle,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icone, color: AppColors.primaire),
          const SizedBox(height: 4),
          Text(
            valeur,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          Text(
            libelle,
            style: const TextStyle(fontSize: 12, color: AppColors.texte2),
          ),
        ],
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  final IconData icone;
  final String libelle;
  final String valeur;

  const _Ligne({
    required this.icone,
    required this.libelle,
    required this.valeur,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icone, size: 20, color: AppColors.texte2),
          const SizedBox(width: 12),
          Text(
            libelle,
            style: const TextStyle(color: AppColors.texte2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              valeur,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
