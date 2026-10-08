import 'package:flutter/material.dart';

import '../../../app/theme.dart';

import '../../../core/utils/helpers.dart';

import '../data/messagerie_mock.dart';
import '../models/conversation.dart';

import 'conversation_page.dart';
import 'creer_groupe_page.dart';

// ============================================================
// PAGE MESSAGERIE — liste des conversations
// ============================================================

class MessageriePage extends StatefulWidget {
  const MessageriePage({super.key});

  @override
  State<MessageriePage> createState() =>
      _MessageriePageState();
}

class _MessageriePageState extends State<MessageriePage> {
  final TextEditingController _rechercheCtrl =
      TextEditingController();
  final FocusNode _rechercheFocus = FocusNode();

  String _recherche = '';
  String _filtre = 'tout'; // tout | privees | groupes

  @override
  void dispose() {
    _rechercheCtrl.dispose();
    _rechercheFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------
  // FILTRAGE LOCAL (recherche + type de conversation)
  // ---------------------------------------------------------

  List<Conversation> get _conversationsFiltrees {
    var liste = List<Conversation>.of(conversationsMock);

    if (_filtre == 'privees') {
      liste = liste
          .where((c) => c.type == TypeConversation.prive)
          .toList();
    } else if (_filtre == 'groupes') {
      liste = liste
          .where((c) => c.type == TypeConversation.groupe)
          .toList();
    }

    final requete = _recherche.trim().toLowerCase();
    if (requete.isNotEmpty) {
      liste = liste
          .where(
            (c) => c.titre.toLowerCase().contains(requete),
          )
          .toList();
    }

    return liste;
  }

  Future<void> _ouvrirConversation(
    Conversation conversation,
  ) async {
    final resultat = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ConversationPage(
          conversation: conversation,
        ),
      ),
    );

    if (!mounted) return;

    if (resultat == 'quitte') {
      retirerGroupeMock(conversation.id);

      // Rafraîchit la liste après le départ du groupe.
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vous avez quitté le groupe.',
          ),
        ),
      );
    }
  }

  Future<void> _nouveauGroupe() async {
    final nom = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const CreerGroupePage(),
      ),
    );

    if (!mounted || nom == null) return;

    // La liste mock a changé : on rafraîchit l'affichage.
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Groupe « $nom » créé.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conversations = _conversationsFiltrees;

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
                const Expanded(
                  child: Text(
                    'Messages',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),

                IconButton.outlined(
                  onPressed: () {
                    _rechercheFocus.requestFocus();
                  },
                  icon: const Icon(Icons.search),
                  tooltip: 'Rechercher',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // =====================================================
            // BARRE DE RECHERCHE
            // =====================================================

            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.bordure,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.search,
                    color: AppColors.primaire,
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: TextField(
                      controller: _rechercheCtrl,
                      focusNode: _rechercheFocus,
                      onChanged: (valeur) {
                        setState(() {
                          _recherche = valeur;
                        });
                      },
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Rechercher une conversation…',
                        hintStyle: TextStyle(
                          fontSize: 16,
                          color: AppColors.texte2,
                        ),
                      ),
                    ),
                  ),

                  if (_recherche.isNotEmpty)
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _recherche = '';
                          _rechercheCtrl.clear();
                        });
                      },
                      icon: const Icon(
                        Icons.close,
                        size: 18,
                        color: AppColors.texte2,
                      ),
                      tooltip: 'Effacer',
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // =====================================================
            // FILTRES
            // =====================================================

            Row(
              children: [
                _ChipFiltre(
                  label: 'Tout',
                  selectionne: _filtre == 'tout',
                  onTap: () {
                    setState(() {
                      _filtre = 'tout';
                    });
                  },
                ),

                const SizedBox(width: 10),

                _ChipFiltre(
                  label: 'Privées',
                  selectionne: _filtre == 'privees',
                  onTap: () {
                    setState(() {
                      _filtre = 'privees';
                    });
                  },
                ),

                const SizedBox(width: 10),

                _ChipFiltre(
                  label: 'Groupes',
                  selectionne: _filtre == 'groupes',
                  onTap: () {
                    setState(() {
                      _filtre = 'groupes';
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // =====================================================
            // LISTE DES CONVERSATIONS
            // =====================================================

            if (conversations.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(
                  child: Text(
                    'Aucune conversation trouvée.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.texte2,
                    ),
                  ),
                ),
              ),

            for (final conversation in conversations) ...[
              _CarteConversation(
                conversation: conversation,
                onTap: () {
                  _ouvrirConversation(conversation);
                },
              ),

              const SizedBox(height: 12),
            ],
          ],
        ),
      ),

      // =========================================================
      // BOUTON FLOTTANT — NOUVEAU GROUPE
      // =========================================================

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nouveauGroupe,
        backgroundColor: AppColors.primaire,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.group_add_outlined),
        label: const Text('Nouveau groupe'),
      ),
    );
  }
}

// ============================================================
// CHIP DE FILTRE
// ============================================================

class _ChipFiltre extends StatelessWidget {
  final String label;
  final bool selectionne;
  final VoidCallback onTap;

  const _ChipFiltre({
    required this.label,
    required this.selectionne,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: selectionne
              ? AppColors.primaire
              : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selectionne
                ? AppColors.primaire
                : AppColors.bordure,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selectionne
                ? Colors.white
                : AppColors.texte2,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// CARTE D'UNE CONVERSATION
// ============================================================

class _CarteConversation extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;

  const _CarteConversation({
    required this.conversation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final nonLues = conversation.nonLus > 0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.bordure,
            ),
          ),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 23,
                backgroundColor: AppColors.primaire,
                child: Text(
                  conversation.initiale,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Titre + dernier message
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            conversation.titre,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: nonLues
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                            ),
                          ),
                        ),

                        if (conversation.estGroupe) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.group_outlined,
                            size: 16,
                            color: AppColors.primaire,
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 4),

                    Text(
                      conversation.dernierMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.texte2,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Heure + état (muet / non lus)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    fHeure(
                      conversation.dateDernierMessage,
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.texte2,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (conversation.muet)
                        const Icon(
                          Icons.volume_off_outlined,
                          size: 16,
                          color: AppColors.texte2,
                        ),

                      if (conversation.muet &&
                          nonLues)
                        const SizedBox(width: 6),

                      if (nonLues)
                        Badge(
                          backgroundColor:
                              AppColors.accent,
                          textColor: Colors.white,
                          label: Text(
                            '${conversation.nonLus}',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
