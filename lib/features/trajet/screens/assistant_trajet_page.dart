// ============================================================
//  MODULE : GESTION DES TRAJETS (Yassine)
//  Fichier : lib/features/trajet/screens/assistant_trajet_page.dart
//  Écran : assistant de recherche (chatbot) qui discute avec le
//  passager et l'aide à choisir le meilleur covoiturage.
//  La logique est dans services/assistant_trajet.dart.
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../services/assistant_trajet.dart';
import '../services/trajet_service.dart';
import '../utils/trajet_format.dart';
import 'alertes_page.dart';
import 'detail_trajet_page.dart';
import 'resultats_trajet_page.dart';

class AssistantTrajetPage extends StatefulWidget {
  /// Premier message envoyé automatiquement (facultatif)
  final String? question;
  const AssistantTrajetPage({super.key, this.question});

  @override
  State<AssistantTrajetPage> createState() => _AssistantTrajetPageState();
}

class _AssistantTrajetPageState extends State<AssistantTrajetPage> {
  final _assistant = AssistantTrajet(prenom: monNom, utilisateurId: monId);
  final _messages = <MessageAssistant>[];
  final _saisie = TextEditingController();
  final _defilement = ScrollController();
  final _cleDernier = GlobalKey();

  /// true pendant que l'assistant « écrit »
  bool _repond = false;

  @override
  void initState() {
    super.initState();
    _demarrer();
  }

  Future<void> _demarrer() async {
    await TrajetService.instance.charger();
    if (!mounted) return;
    setState(() => _messages.add(_assistant.accueil()));
    final q = widget.question?.trim() ?? '';
    if (q.isNotEmpty) _envoyer(q);
  }

  @override
  void dispose() {
    _saisie.dispose();
    _defilement.dispose();
    super.dispose();
  }

  Future<void> _envoyer(String texte) async {
    final t = texte.trim();
    if (t.isEmpty || _repond) return;
    _saisie.clear();
    setState(() {
      _messages.add(MessageAssistant(deUtilisateur: true, texte: t));
      _repond = true;
    });
    _defiler(versDebutDuDernier: false);

    // Petit délai : l'assistant « écrit » comme dans une vraie messagerie
    await Future.delayed(
        Duration(milliseconds: 450 + (t.length * 12).clamp(0, 600)));
    if (!mounted) return;
    final reponse = _assistant.repondre(t);
    setState(() {
      _messages.add(reponse);
      _repond = false;
    });
    _defiler(versDebutDuDernier: true);
  }

  /// Fait défiler la conversation : tout en bas, ou au début de la
  /// dernière réponse (pour lire le texte avant les trajets proposés)
  void _defiler({required bool versDebutDuDernier}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _cleDernier.currentContext;
      if (versDebutDuDernier && ctx != null) {
        Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic);
      } else if (_defilement.hasClients) {
        _defilement.animateTo(_defilement.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  void _recommencer() {
    setState(() {
      _assistant.criteres = CriteresAssistant();
      _messages
        ..clear()
        ..add(_assistant.accueil());
      _repond = false;
    });
  }

  Future<void> _toucherSuggestion(SuggestionAssistant s) async {
    final c = _assistant.criteres;
    switch (s.action) {
      case ActionAssistant.envoyer:
        _envoyer(s.libelle);
        break;
      case ActionAssistant.voirResultats:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResultatsTrajetPage(
              depart: c.depart ?? '',
              arrivee: c.arrivee ?? '',
              date: c.date,
              places: c.places,
            ),
          ),
        );
        break;
      case ActionAssistant.creerAlerte:
        final erreur = await creerAlerteEtInformer(
          context,
          depart: c.depart ?? '',
          arrivee: c.arrivee ?? '',
          jour: c.date,
          heure: c.heure,
          moment: c.moment,
          places: c.places,
        );
        if (!mounted) return;
        setState(() => _messages.add(MessageAssistant(
              deUtilisateur: false,
              texte: erreur ??
                  'C’est fait : je vous préviendrai dans les notifications '
                      'dès qu’un trajet ${c.itineraire} sera publié.',
              suggestions: const [SuggestionAssistant('Nouvelle recherche')],
            )));
        _defiler(versDebutDuDernier: true);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dernierBot = _messages.lastWhere((m) => !m.deUtilisateur,
        orElse: () => MessageAssistant(deUtilisateur: false, texte: ''));
    final suggestions = _repond ||
            _messages.isEmpty ||
            _messages.last.deUtilisateur
        ? const <SuggestionAssistant>[]
        : dernierBot.suggestions;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLow,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const AvatarAssistant(rayon: 18),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Assistant covoiturage',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                          color: Color(0xFF22A06B), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Text(_repond ? 'écrit…' : 'En ligne',
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Nouvelle conversation',
            onPressed: _recommencer,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          _BandeauCriteres(
              etiquettes: _assistant.criteres.resume(DateTime.now())),
          Expanded(
            child: ListView(
              controller: _defilement,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              children: [
                const _EnTeteConversation(),
                for (var i = 0; i < _messages.length; i++)
                  _VueMessage(
                    key: i == _messages.length - 1 ? _cleDernier : null,
                    message: _messages[i],
                  ),
                if (_repond) const _IndicateurEcriture(),
              ],
            ),
          ),
          _SuggestionsRapides(
              suggestions: suggestions, onTap: _toucherSuggestion),
          _BarreSaisie(
            controleur: _saisie,
            actif: !_repond,
            onEnvoyer: () => _envoyer(_saisie.text),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// WIDGETS
// ------------------------------------------------------------

/// Pastille ronde de l'assistant (dégradé + étincelles)
class AvatarAssistant extends StatelessWidget {
  final double rayon;
  const AvatarAssistant({super.key, this.rayon = 16});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: rayon * 2,
      height: rayon * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primary, const Color(0xFF7B5CE6)],
        ),
      ),
      child: Icon(Icons.auto_awesome, color: Colors.white, size: rayon),
    );
  }
}

/// « Ce que j'ai compris » : critères actuels sous la barre de titre
class _BandeauCriteres extends StatelessWidget {
  final List<String> etiquettes;
  const _BandeauCriteres({required this.etiquettes});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: etiquettes.isEmpty
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 8, 0, 8),
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(bottom: BorderSide(color: cs.outlineVariant)),
              ),
              child: Row(
                children: [
                  Icon(Icons.tune, size: 16, color: cs.primary),
                  const SizedBox(width: 6),
                  Text('Compris',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: cs.primary)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(right: 14),
                      child: Row(
                        children: [
                          for (final e in etiquettes)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: cs.primaryContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(e,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onPrimaryContainer)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _EnTeteConversation extends StatelessWidget {
  const _EnTeteConversation();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Aujourd’hui',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 12, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'L’assistant fonctionne sur votre téléphone : '
                  'vos messages ne sont envoyés nulle part.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VueMessage extends StatelessWidget {
  final MessageAssistant message;
  const _VueMessage({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final largeurMax = MediaQuery.sizeOf(context).width * 0.78;
    final heure = Text(tHeure(message.heure),
        style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant));

    if (message.deUtilisateur) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              constraints: BoxConstraints(maxWidth: largeurMax),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(message.texte,
                  style: TextStyle(color: cs.onPrimary, fontSize: 15)),
            ),
            const SizedBox(height: 3),
            heure,
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AvatarAssistant(rayon: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BulleAssistant(
                  largeurMax: largeurMax,
                  child: Text(message.texte,
                      style: TextStyle(
                          color: cs.onSurface, fontSize: 15, height: 1.35)),
                ),
                for (var i = 0; i < message.trajets.length; i++)
                  _CarteTrajetChat(
                    reco: message.trajets[i],
                    recommande: i == 0 && message.trajets.length > 1,
                  ),
                const SizedBox(height: 3),
                heure,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BulleAssistant extends StatelessWidget {
  final double largeurMax;
  final Widget child;
  const _BulleAssistant({required this.largeurMax, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      constraints: BoxConstraints(maxWidth: largeurMax),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
      ),
      child: child,
    );
  }
}

/// Trajet proposé dans la conversation (le premier est « Recommandé »)
class _CarteTrajetChat extends StatelessWidget {
  final TrajetRecommande reco;
  final bool recommande;
  const _CarteTrajetChat({required this.reco, required this.recommande});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = reco.trajet;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: cs.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: recommande ? cs.primary : cs.outlineVariant,
            width: recommande ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DetailTrajetPage(trajet: t)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (recommande)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: cs.primary.withValues(alpha: 0.08),
                  child: Row(
                    children: [
                      Icon(Icons.workspace_premium,
                          size: 16, color: cs.primary),
                      const SizedBox(width: 6),
                      Text('Recommandé pour vous',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: cs.primary)),
                      const Spacer(),
                      Text('${reco.score} % compatible',
                          style: TextStyle(fontSize: 11, color: cs.primary)),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tHeure(t.dateDepart),
                                style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800)),
                            Text(tJourRelatif(t.dateDepart),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurfaceVariant)),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${t.villeDepart} → ${t.villeArrivee}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(t.conducteurNom,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: cs.onSurfaceVariant)),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.star,
                                      size: 12, color: Colors.amber),
                                  Text(' ${t.conducteurNote}',
                                      style: const TextStyle(fontSize: 12)),
                                  const SizedBox(width: 6),
                                  Icon(Icons.event_seat,
                                      size: 12, color: cs.onSurfaceVariant),
                                  Text(' ${t.placesDispo}',
                                      style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Text(tPrix(reco.prix),
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: cs.primary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final r in reco.raisons.take(3))
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF22A06B)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check,
                                    size: 12, color: Color(0xFF1B7F55)),
                                const SizedBox(width: 3),
                                Text(r,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1B7F55))),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text('Voir et réserver ›',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: cs.primary)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Trois points animés pendant que l'assistant « écrit »
class _IndicateurEcriture extends StatefulWidget {
  const _IndicateurEcriture();

  @override
  State<_IndicateurEcriture> createState() => _IndicateurEcritureState();
}

class _IndicateurEcritureState extends State<_IndicateurEcriture>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  /// Chaque point s'allume puis s'éteint, avec un décalage d'un tiers
  double _opacitePoint(int i) {
    final phase = (_anim.value - i / 3) % 1.0;
    return 0.25 + 0.6 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const AvatarAssistant(rayon: 14),
          const SizedBox(width: 8),
          _BulleAssistant(
            largeurMax: 80,
            child: AnimatedBuilder(
              animation: _anim,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cs.onSurfaceVariant
                            .withValues(alpha: _opacitePoint(i)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionsRapides extends StatelessWidget {
  final List<SuggestionAssistant> suggestions;
  final ValueChanged<SuggestionAssistant> onTap;
  const _SuggestionsRapides({required this.suggestions, required this.onTap});

  IconData? _icone(ActionAssistant a) {
    switch (a) {
      case ActionAssistant.voirResultats:
        return Icons.list_alt;
      case ActionAssistant.creerAlerte:
        return Icons.notifications_active_outlined;
      case ActionAssistant.envoyer:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: suggestions.isEmpty
          ? const SizedBox(width: double.infinity)
          : SizedBox(
              height: 46,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
                itemCount: suggestions.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final s = suggestions[i];
                  final icone = _icone(s.action);
                  return ActionChip(
                    avatar: icone == null
                        ? null
                        : Icon(icone, size: 16, color: cs.primary),
                    label: Text(s.libelle),
                    labelStyle: TextStyle(
                        color: cs.primary, fontWeight: FontWeight.w600),
                    backgroundColor: cs.surface,
                    side: BorderSide(color: cs.primary.withValues(alpha: 0.4)),
                    shape: const StadiumBorder(),
                    onPressed: () => onTap(s),
                  );
                },
              ),
            ),
    );
  }
}

class _BarreSaisie extends StatelessWidget {
  final TextEditingController controleur;
  final bool actif;
  final VoidCallback onEnvoyer;
  const _BarreSaisie({
    required this.controleur,
    required this.actif,
    required this.onEnvoyer,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controleur,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onEnvoyer(),
                  decoration: InputDecoration(
                    hintText: 'Où voulez-vous aller ?',
                    filled: true,
                    fillColor: cs.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controleur,
                builder: (context, valeur, _) => IconButton.filled(
                  tooltip: 'Envoyer',
                  onPressed: actif && valeur.text.trim().isNotEmpty
                      ? onEnvoyer
                      : null,
                  icon: const Icon(Icons.send_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
