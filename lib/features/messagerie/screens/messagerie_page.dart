import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';

import '../../../core/utils/helpers.dart';

import '../../user/models/user_model.dart';

import '../models/conversation.dart';
import '../services/messagerie_service.dart';

import 'conversation_page.dart';
import 'creer_groupe_page.dart';

// ============================================================
// PAGE MESSAGERIE — liste des conversations
// ============================================================

class MessageriePage extends StatefulWidget {
  final bool isStandalone;
  const MessageriePage({super.key, this.isStandalone = true});

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
  void initState() {
    super.initState();
    unawaited(MessagerieService.instance.charger());
  }

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
    var liste = MessagerieService.instance.conversations();

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
      await MessagerieService.instance.quitterGroupe(
        conversation.id,
      );

      if (!mounted) return;

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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Groupe « $nom » créé.'),
      ),
    );
  }

  Future<void> _nouvelleConversationPrivee() async {
    final destinataire =
        await showModalBottomSheet<UserModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (_) => const _FeuilleUtilisateurs(),
    );

    if (!mounted || destinataire == null) return;

    try {
      final conversation = await MessagerieService
          .instance
          .creerConversationPrivee(destinataire);
      if (!mounted) return;
      await _ouvrirConversation(conversation);
    } on MessagerieException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MessagerieService.instance,
      builder: (context, _) {
        final service = MessagerieService.instance;
        final toutes = service.conversations();
        final conversations = _conversationsFiltrees;
        final connecte = service.estConnecte();
        final enChargement =
            service.estEnChargement && !service.estCharge;

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
                if (widget.isStandalone) ...[
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).maybePop();
                    },
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 4),
                ],
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
                  onPressed: _nouvelleConversationPrivee,
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  tooltip: 'Nouvelle conversation',
                ),

                const SizedBox(width: 8),

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

            if (enChargement)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (!connecte)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(
                  child: Text(
                    'Connectez-vous pour accéder à vos messages',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.texte2,
                    ),
                  ),
                ),
              )
            else if (toutes.isEmpty && _recherche.trim().isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(
                  child: Text(
                    'Aucune conversation. Appuyez sur + pour démarrer',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.texte2,
                    ),
                  ),
                ),
              )
            else if (conversations.isEmpty)
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
            floatingActionButton: connecte
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 80),
                    child: FloatingActionButton.extended(
                      onPressed: _nouveauGroupe,
                      backgroundColor: AppColors.primaire,
                      foregroundColor: Colors.white,
                      icon: const Icon(Icons.group_add_outlined),
                      label: const Text('Nouveau groupe'),
                    ),
                  )
                : null,
        );
      },
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

                        if (conversation.archive) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.bordure,
                              borderRadius:
                                  BorderRadius.circular(
                                18,
                              ),
                            ),
                            child: const Text(
                              'Archivé',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight:
                                    FontWeight.w700,
                                color:
                                    AppColors.texte2,
                              ),
                            ),
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

// ============================================================
// FEUILLE DE SÉLECTION D'UN UTILISATEUR (CONVERSATION PRIVÉE)
// ============================================================

class _FeuilleUtilisateurs extends StatefulWidget {
  const _FeuilleUtilisateurs();

  @override
  State<_FeuilleUtilisateurs> createState() =>
      _FeuilleUtilisateursState();
}

class _FeuilleUtilisateursState
    extends State<_FeuilleUtilisateurs> {
  late Future<List<UserModel>> _utilisateurs;

  @override
  void initState() {
    super.initState();
    _utilisateurs = MessagerieService.instance
        .utilisateursDisponibles();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                16,
                16,
                8,
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Nouvelle conversation',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.close),
                    tooltip: 'Fermer',
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<UserModel>>(
                future: _utilisateurs,
                builder: (context, snapshot) {
                  if (snapshot.connectionState !=
                      ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Impossible de charger les '
                        'utilisateurs.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.texte2,
                        ),
                      ),
                    );
                  }

                  final utilisateurs =
                      snapshot.data ?? const <UserModel>[];
                  if (utilisateurs.isEmpty) {
                    return const Center(
                      child: Text(
                        'Aucun utilisateur disponible.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.texte2,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                    ),
                    itemCount: utilisateurs.length,
                    itemBuilder: (context, index) {
                      final utilisateur = utilisateurs[index];
                      final nom = utilisateur.nomComplet.trim();
                      final initiale =
                          nom.isEmpty ? '?' : nom[0].toUpperCase();
                      final avatar =
                          (utilisateur.avatarUrl ?? '').trim();
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppColors.primaireDoux,
                          backgroundImage: avatar.isEmpty
                              ? null
                              : NetworkImage(avatar),
                          child: avatar.isEmpty
                              ? Text(
                                  initiale,
                                  style: const TextStyle(
                                    color:
                                        AppColors.primaire,
                                    fontWeight:
                                        FontWeight.w700,
                                  ),
                                )
                              : null,
                        ),
                        title: Text(
                          utilisateur.nomComplet,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: utilisateur.email.trim().isEmpty
                            ? null
                            : Text(utilisateur.email),
                        onTap: () {
                          Navigator.pop(context, utilisateur);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
