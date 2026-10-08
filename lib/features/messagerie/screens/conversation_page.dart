import 'package:flutter/material.dart';

import '../../../app/theme.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/helpers.dart';

import '../data/messagerie_mock.dart';
import '../models/conversation.dart';
import '../models/message.dart';

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
  late final List<Message> _messages;

  final TextEditingController _saisieCtrl =
      TextEditingController();
  final ScrollController _scrollCtrl =
      ScrollController();

  @override
  void initState() {
    super.initState();
    _messages =
        List.of(messagesDe(widget.conversation.id));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _defilerEnBas();
    });
  }

  @override
  void dispose() {
    _saisieCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Conversation toujours à jour dans la liste mock
  /// (membres et mode muet modifiables depuis les infos).
  Conversation get _conversation =>
      conversationsMock.firstWhere(
        (c) => c.id == widget.conversation.id,
      );

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
  // ENVOI D'UN MESSAGE (liste locale, setState)
  // ---------------------------------------------------------

  void _envoyer() {
    final texte = _saisieCtrl.text.trim();
    if (texte.isEmpty) return;

    setState(() {
      _messages.add(
        Message(
          id: DateTime.now()
              .millisecondsSinceEpoch,
          expediteurId: monId,
          expediteurNom: monNom,
          contenu: texte,
          dateEnvoi: DateTime.now(),
          type: TypeMessage.texte,
          statut: StatutMessage.envoye,
        ),
      );

      _saisieCtrl.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _defilerEnBas();
    });
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

    // Rafraîchit les infos (membres, mode muet).
    setState(() {});

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

  List<Widget> _construireMessages() {
    final enfants = <Widget>[];
    DateTime? jourPrecedent;

    for (final message in _messages) {
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
                _conversation.estGroupe,
          ),
        ),
      );
    }

    return enfants;
  }

  @override
  Widget build(BuildContext context) {
    final conversation = _conversation;

    final sousTitre = conversation.estGroupe
        ? '${conversation.membres.length} membres'
        : 'En ligne';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // =====================================================
            // BANDEAU DU TRAJET
            // =====================================================

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

            // =====================================================
            // MESSAGES
            // =====================================================

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
                children: _construireMessages(),
              ),
            ),

            // =====================================================
            // BARRE DE SAISIE
            // =====================================================

            _BarreSaisie(
              controller: _saisieCtrl,
              onEnvoyer: _envoyer,
            ),
          ],
        ),
      ),

      // =========================================================
      // APP BAR (avatar, titre, sous-titre, infos)
      // =========================================================

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
                  Text(
                    sousTitre,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.texte2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton.outlined(
            onPressed: _ouvrirInfos,
            icon: const Icon(
              Icons.info_outline,
            ),
            tooltip: 'Informations',
          ),
          const SizedBox(width: 8),
        ],
      ),
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

  const _BarreSaisie({
    required this.controller,
    required this.onEnvoyer,
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
                textInputAction:
                    TextInputAction.send,
                onSubmitted: (_) => onEnvoyer(),
                decoration:
                    const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Message…',
                  hintStyle: TextStyle(
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
              onPressed: onEnvoyer,
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
