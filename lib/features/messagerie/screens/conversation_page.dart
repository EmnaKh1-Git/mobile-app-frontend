import 'package:flutter/material.dart';

import '../../../app/theme.dart';

import '../../../core/utils/helpers.dart';

import '../models/conversation.dart';
import '../models/message.dart';
import '../services/messagerie_service.dart';

import '../widgets/bulle_message.dart';

import 'infos_groupe_page.dart';

// ============================================================
// PAGE CONVERSATION — discussion
// ============================================================

class ConversationPage extends StatefulWidget {
  final Conversation conversation;

  const ConversationPage({
    super.key,
    required this.conversation,
  });

  @override
  State<ConversationPage> createState() =>
      _ConversationPageState();
}

class _ConversationPageState
    extends State<ConversationPage> {
  final TextEditingController _saisieCtrl =
      TextEditingController();
  final ScrollController _scrollCtrl =
      ScrollController();

  @override
  void initState() {
    super.initState();

    MessagerieService.instance.ouvrirConversation(
      widget.conversation.id,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      MessagerieService.instance.marquerCommeLu(
        widget.conversation.id,
      );
      _defilerEnBas();
    });
  }

  @override
  void dispose() {
    MessagerieService.instance.fermerConversation(
      widget.conversation.id,
    );
    _saisieCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------
  // SIMULER UN MESSAGE REÇU
  // ---------------------------------------------------------

  void _simulerMessageRecu() {
    String? notification;

    try {
      notification = MessagerieService.instance
          .simulerMessageRecu(widget.conversation.id);
    } on MessagerieException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      return;
    }

    if (notification != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(notification)),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _defilerEnBas();
    });
  }

  /// Conversation toujours à jour dans le service
  /// (membres et mode muet modifiables depuis les infos).
  Conversation get _conversation =>
      MessagerieService.instance.conversation(
        widget.conversation.id,
      ) ??
      widget.conversation;

  // ---------------------------------------------------------
  // DÉFILEMENT VERS LE BAS
  // ---------------------------------------------------------

  void _defilerEnBas() {
    if (!_scrollCtrl.hasClients) return;

    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  // ---------------------------------------------------------
  // ENVOI D'UN MESSAGE (via le service)
  // ---------------------------------------------------------

  Future<void> _envoyer() async {
    final texte = _saisieCtrl.text.trim();
    if (texte.isEmpty) return;

    // Avertissement anti-abus : numéro de téléphone ou lien.
    if (MessagerieService.instance
        .contientContenuSensible(texte)) {
      final confirme = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Contenu sensible'),
          content: const Text(
            'Votre message contient un numéro de téléphone '
            'ou un lien. Il sera masqué par « •••• ».',
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
              child: const Text('Envoyer quand même'),
            ),
          ],
        ),
      );

      if (confirme != true || !mounted) return;
    }

    bool masque;

    try {
      masque = MessagerieService.instance.envoyerMessage(
        widget.conversation.id,
        texte,
      );
    } on MessagerieException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      return;
    }

    _saisieCtrl.clear();

    if (masque) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Langage inapproprié détecté',
          ),
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _defilerEnBas();
    });
  }

  // ---------------------------------------------------------
  // SIGNALER UN MESSAGE (appui long)
  // ---------------------------------------------------------

  Future<void> _signaler(Message message) async {
    if (message.estSignale) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ce message est déjà signalé.'),
        ),
      );
      return;
    }

    final motif = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Signaler le message'),
        children: [
          for (final choix in const [
            'Spam',
            'Contenu inapproprié',
            'Harcèlement',
            'Autre',
          ])
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, choix);
              },
              child: Text(choix),
            ),
        ],
      ),
    );

    if (motif == null || !mounted) return;

    try {
      MessagerieService.instance.signalerMessage(
        widget.conversation.id,
        message.id,
      );
    } on MessagerieException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Message signalé ($motif).',
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // BLOQUER / DÉBLOQUER (conversation privée)
  // ---------------------------------------------------------

  void _basculerBloque() {
    try {
      MessagerieService.instance.basculerBloque(
        widget.conversation.id,
      );
    } on MessagerieException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _ouvrirInfos() async {
    if (!_conversation.estGroupe) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Le profil arrivera plus tard.',
          ),
        ),
      );
      return;
    }

    final resultat = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => InfosGroupePage(
          conversation: _conversation,
        ),
      ),
    );

    if (!mounted) return;

    if (resultat == 'quitte') {
      Navigator.pop(context, 'quitte');
    }
  }

  // ---------------------------------------------------------
  // LIBELLÉ D'UNE JOURNÉE (Aujourd'hui / Hier / date)
  // ---------------------------------------------------------

  String _libelleJour(DateTime date) {
    final now = DateTime.now();
    final aujourdhui = DateTime(
      now.year,
      now.month,
      now.day,
    );
    final jour = DateTime(
      date.year,
      date.month,
      date.day,
    );

    final ecart = aujourdhui.difference(jour).inDays;

    if (ecart == 0) return 'Aujourd\'hui';
    if (ecart == 1) return 'Hier';
    return fDateCourte(date);
  }

  // ---------------------------------------------------------
  // LISTE DES BULLES (avec séparateurs de date)
  // ---------------------------------------------------------

  List<Widget> _construireMessages(
    Conversation conversation,
    List<Message> messages,
  ) {
    final enfants = <Widget>[];
    DateTime? jourPrecedent;

    for (final message in messages) {
      final jour = DateTime(
        message.dateEnvoi.year,
        message.dateEnvoi.month,
        message.dateEnvoi.day,
      );

      if (jour != jourPrecedent) {
        enfants.add(
          _SeparateurDate(
            libelle: _libelleJour(jour),
          ),
        );
        jourPrecedent = jour;
      }

      enfants.add(
        Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 4,
          ),
          child: BulleMessage(
            message: message,
            afficherNom:
                conversation.estGroupe,
            onLongPress:
                message.estSysteme ||
                        message.estMien
                    ? null
                    : () {
                        _signaler(message);
                      },
          ),
        ),
      );
    }

    return enfants;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MessagerieService.instance,
      builder: (context, _) {
        final conversation = _conversation;
        final messages =
            MessagerieService.instance.messagesDe(
          conversation.id,
        );
        final archivee = conversation.archive;
        final bloque = conversation.bloque;
        final suspendu =
            MessagerieService.instance.estSuspendu;
        final secondes =
            MessagerieService.instance.secondesRestantes;

        final sousTitre = conversation.estGroupe
            ? '${conversation.membres.length} membres'
            : 'En ligne';

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                // =================================================
                // BANDEAU DU TRAJET
                // =================================================

                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    0,
                  ),
                  child: _BandeauTrajet(
                    trajetLabel:
                        conversation.trajetLabel,
                  ),
                ),

                const SizedBox(height: 12),

                // =================================================
                // BANDEAU UTILISATEUR BLOQUÉ
                // =================================================

                if (bloque)
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      8,
                    ),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentDoux,
                        borderRadius:
                            BorderRadius.circular(
                          18,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.block,
                            size: 18,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Vous avez bloqué '
                              '${conversation.titre}. '
                              'Aucun message ne peut être '
                              'envoyé ou reçu.',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    FontWeight.w700,
                                color:
                                    AppColors.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // =================================================
                // BANDEAU ENVOI SUSPENDU
                // =================================================

                if (suspendu)
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      8,
                    ),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentDoux,
                        borderRadius:
                            BorderRadius.circular(
                          18,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.hourglass_top,
                            size: 18,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Envoi suspendu, réessayez '
                              'dans $secondes s',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    FontWeight.w700,
                                color:
                                    AppColors.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // =================================================
                // MESSAGES
                // =================================================

                Expanded(
                  child: ListView(
                    controller: _scrollCtrl,
                    padding:
                        const EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      16,
                    ),
                    children: _construireMessages(
                      conversation,
                      messages,
                    ),
                  ),
                ),

                // =================================================
                // BARRE DE SAISIE
                // =================================================

                _BarreSaisie(
                  controller: _saisieCtrl,
                  onEnvoyer: _envoyer,
                  enabled: !archivee &&
                      !bloque &&
                      !suspendu,
                ),
              ],
            ),
          ),

          // =====================================================
          // APP BAR (avatar, titre, sous-titre, infos)
          // =====================================================

          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            titleSpacing: 0,
            title: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor:
                      AppColors.primaire,
                  child: Text(
                    conversation.initiale,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Text(
                        conversation.titre,
                        overflow:
                            TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            sousTitre,
                            style: const TextStyle(
                              fontSize: 12,
                              color:
                                  AppColors.texte2,
                            ),
                          ),
                          if (archivee) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration:
                                  BoxDecoration(
                                color:
                                    AppColors.bordure,
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  18,
                                ),
                              ),
                              child: const Text(
                                'Archivé',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight:
                                      FontWeight
                                          .w700,
                                  color: AppColors
                                      .texte2,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton.outlined(
                onPressed: archivee
                    ? null
                    : _simulerMessageRecu,
                icon: const Icon(
                  Icons.mark_email_unread_outlined,
                ),
                tooltip: 'Simuler un message reçu',
              ),
              const SizedBox(width: 4),
              IconButton.outlined(
                onPressed: _ouvrirInfos,
                icon: const Icon(
                  Icons.info_outline,
                ),
                tooltip: 'Informations',
              ),
              if (!conversation.estGroupe)
                PopupMenuButton<String>(
                  tooltip: 'Options',
                  onSelected: (valeur) {
                    if (valeur == 'bloquer') {
                      _basculerBloque();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      value: 'bloquer',
                      child: Text(
                        bloque
                            ? 'Débloquer'
                            : 'Bloquer',
                      ),
                    ),
                  ],
                ),
              const SizedBox(width: 8),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// BANDEAU DU TRAJET
// ============================================================

class _BandeauTrajet extends StatelessWidget {
  final String trajetLabel;

  const _BandeauTrajet({
    required this.trajetLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaireDoux,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.route_outlined,
            size: 18,
            color: AppColors.primaire,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              trajetLabel,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primaire,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SÉPARATEUR DE DATE
// ============================================================

class _SeparateurDate extends StatelessWidget {
  final String libelle;

  const _SeparateurDate({
    required this.libelle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 10,
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: AppColors.infoFond,
            borderRadius: BorderRadius.circular(
              18,
            ),
          ),
          child: Text(
            libelle,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.infoTexte,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// BARRE DE SAISIE
// ============================================================

class _BarreSaisie extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onEnvoyer;
  final bool enabled;

  const _BarreSaisie({
    required this.controller,
    required this.onEnvoyer,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: AppColors.bordure,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              padding:
                  const EdgeInsets.symmetric(
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
                controller: controller,
                enabled: enabled,
                textInputAction:
                    TextInputAction.send,
                onSubmitted: (_) => onEnvoyer(),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText:
                      enabled ? 'Message…' : 'Groupe archivé',
                  hintStyle: const TextStyle(
                    fontSize: 15,
                    color: AppColors.texte2,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          SizedBox(
            width: 48,
            height: 48,
            child: FilledButton(
              style:
                  FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(
                  48,
                  48,
                ),
                backgroundColor:
                    AppColors.primaire,
              ),
              onPressed: enabled ? onEnvoyer : null,
              child: const Icon(
                Icons.send,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
