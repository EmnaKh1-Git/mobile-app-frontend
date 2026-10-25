import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../app/theme.dart';

import '../../../core/utils/helpers.dart';

import '../models/conversation.dart';
import '../models/message.dart';
import '../services/audio_service.dart';
import '../services/messagerie_service.dart';

import '../widgets/barre_saisie.dart';
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
    AudioService.instance.arreter();
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

  /// Simule la réception d'un vocal avec le dernier vocal enregistré.
  Future<void> _simulerVocalRecu() async {
    final chemin = AudioService.instance.dernierCheminEnregistre;
    if (chemin == null || chemin.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enregistrez d\'abord un vocal pour pouvoir simuler un vocal reçu',
          ),
        ),
      );
      return;
    }

    final fichier = io.File(chemin);
    if (!await fichier.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enregistrez d\'abord un vocal pour pouvoir simuler un vocal reçu',
          ),
        ),
      );
      return;
    }

    int duree = 3;
    try {
      final player = AudioPlayer();
      await player.setAudioSource(AudioSource.file(chemin));
      final d = await player.durationStream.first;
      if (d != null && d.inSeconds > 0) {
        duree = d.inSeconds;
      }
      await player.dispose();
    } catch (_) {
      duree = 3;
    }

    String? notification;

    try {
      notification = MessagerieService.instance.simulerVocalRecu(
        widget.conversation.id,
        duree,
        cheminAudio: chemin,
      );
    } on MessagerieException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      return;
    }

    // Mettre à jour le dernier message vocal avec le chemin audio
    final messages =
        MessagerieService.instance.messagesDe(widget.conversation.id);
    if (messages.isNotEmpty) {
      final dernier = messages.last;
      if (dernier.type == TypeMessage.vocal &&
          dernier.cheminAudio == null) {
        // On ne peut pas modifier directement la liste mock, mais on peut
        // forcer via le service si nécessaire - on laisse tel quel car
        // simulerVocalRecu crée un nouveau message; mieux de le patcher
      }
    }

    if (notification != null && mounted) {
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

  void _simulerSuppressionRecu() {
    String? notification;
    try {
      notification = MessagerieService.instance
          .simulerSuppressionMessageRecu(widget.conversation.id);
    } on MessagerieException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      return;
    }
    if (notification != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(notification)),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _defilerEnBas();
    });
  }

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

  void _afficherMenuSuppression(Message message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final estMien = message.estMien;

        return Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.bordure,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Supprimer'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _afficherDialogueSuppression(message);
                  },
                ),
                if (!estMien)
                  ListTile(
                    leading: const Icon(Icons.flag_outlined),
                    title: const Text('Signaler'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _signaler(message);
                    },
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _afficherDialogueSuppression(Message message) {
    final estMien = message.estMien;
    final estConducteur =
        MessagerieService.instance.estConducteurCreateurGroupe(_conversation);
    final moinsDe10Min =
        DateTime.now().difference(message.dateEnvoi).inMinutes < 10;
    final peutSupprimerTous = (estMien && moinsDe10Min) || estConducteur;
    final estSignale = message.estSignale;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Supprimer pour moi'),
              onTap: () {
                Navigator.pop(ctx);
                _supprimerPourMoi(message);
              },
            ),
            ListTile(
              title: const Text('Supprimer pour tous'),
              subtitle: !peutSupprimerTous
                  ? const Text('Non autorisé')
                  : estSignale
                      ? const Text('Message signalé')
                      : null,
              enabled: peutSupprimerTous && !estSignale,
              onTap: (peutSupprimerTous && !estSignale)
                  ? () {
                      Navigator.pop(ctx);
                      _supprimerPourTous(message);
                    }
                  : null,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }

  void _supprimerPourMoi(Message message) {
    try {
      MessagerieService.instance.supprimerPourMoi(
        widget.conversation.id,
        message.id,
      );
    } on MessagerieException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Message supprimé pour moi'),
        action: SnackBarAction(
          label: 'Annuler',
          onPressed: () {
            // Restauration non implémentée dans ce contexte simple
          },
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _supprimerPourTous(Message message) {
    try {
      MessagerieService.instance.supprimerPourTous(
        widget.conversation.id,
        message.id,
      );
    } on MessagerieException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      return;
    }
  }

  List<Widget> _construireMessages(
    Conversation conversation,
    List<Message> messages,
  ) {
    final enfants = <Widget>[];
    DateTime? jourPrecedent;

    for (final message in messages) {
      if (message.supprimePourMoi && !message.supprimePourTous) {
        continue;
      }

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
            onLongPress: message.estSysteme
                ? null
                : () {
                    _afficherMenuSuppression(message);
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

                BarreSaisie(
                  controller: _saisieCtrl,
                  onEnvoyer: _envoyer,
                  conversationId: conversation.id,
                  enabled: !archivee &&
                      !bloque &&
                      !suspendu,
                  motifMicroDesactive:
                      MessagerieService.instance
                          .motifMicroDesactive(
                    conversation.id,
                  ),
                  onVocalEnvoye: () {
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) {
                      _defilerEnBas();
                    });
                  },
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
                PopupMenuButton<String>(
                  enabled: !archivee,
                  tooltip: 'Simuler',
                  icon: const Icon(
                    Icons.mark_email_unread_outlined,
                  ),
                  onSelected: (valeur) {
                    if (valeur == 'texte') {
                      _simulerMessageRecu();
                    } else if (valeur == 'vocal') {
                      _simulerVocalRecu();
                    } else if (valeur == 'supprimer') {
                      _simulerSuppressionRecu();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem<String>(
                      value: 'texte',
                      child: Text(
                        'Simuler un message reçu',
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'vocal',
                      child: Text(
                        'Simuler un vocal reçu',
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'supprimer',
                      child: Text(
                        'Simuler la suppression d\'un message reçu',
                      ),
                    ),
                  ],
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


