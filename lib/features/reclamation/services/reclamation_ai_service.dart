import 'package:intl/intl.dart';

import '../../../core/services/deepseek_client.dart';
import '../models/reclamation.dart';
import 'reclamation_service.dart';

class ReclamationAiException implements Exception {
  final String message;

  const ReclamationAiException(this.message);

  @override
  String toString() => message;
}

/// Résultat de l'analyse intelligente d'une réclamation.
class ReclamationAnalyse {
  final ReclamationType type;
  final ReclamationPriorite priorite;
  final String sentiment; // calme, mécontent, très mécontent, inquiet
  final String objetSuggere;
  final String conseil;
  final bool locale; // vrai si produite sans l'IA

  const ReclamationAnalyse({
    required this.type,
    required this.priorite,
    required this.sentiment,
    required this.objetSuggere,
    required this.conseil,
    this.locale = false,
  });

  String get texteConseil =>
      'Catégorie suggérée : ${type.label}\n'
      'Priorité : ${priorite.label}\n'
      'Ton détecté : $sentiment\n\n'
      '$conseil';
}

/// Fonctions IA (DeepSeek) du module réclamation.
class ReclamationAiService {
  ReclamationAiService();

  final DeepSeekClient _client = DeepSeekClient.instance;

  bool get estConfiguree => _client.estConfigure;

  static const _contexte =
      'Contexte : UniDrive est une application tunisienne de covoiturage '
      'entre étudiants. Les réclamations concernent des trajets (retards, '
      'comportement du conducteur, état du véhicule, paiements, sécurité).';

  // ---------------------------------------------------------------------
  // 1. Analyse : catégorie, priorité, ton, objet, conseil
  // ---------------------------------------------------------------------

  Future<ReclamationAnalyse> analyser({
    required String sujet,
    required String description,
  }) async {
    if (!estConfiguree) return _analyseLocale(sujet, description);
    try {
      final json = await _client.chatJson(
        system:
            '$_contexte\nAnalyse la réclamation et réponds en JSON strict '
            'avec les clés :\n'
            '"categorie": une valeur parmi retard, conducteur, vehicule, '
            'paiement, autre ;\n'
            '"priorite": basse, normale, haute ou urgente (urgente = '
            'sécurité, accident, agression, harcèlement ; haute = argent '
            'ou trajet annulé/abandonné) ;\n'
            '"sentiment": calme, mécontent, très mécontent ou inquiet ;\n'
            '"objet": un objet court (max 8 mots) ;\n'
            '"conseil": 2 à 3 phrases en français pour l’étudiant : quelles '
            'informations ou preuves ajouter et ce qu’il peut attendre.',
        user: 'Objet : $sujet\nDescription : $description',
      );
      return ReclamationAnalyse(
        type:
            ReclamationType.depuisLibelle(json['categorie'] as String?) ??
            ReclamationType.autre,
        priorite:
            ReclamationPriorite.depuisLibelle(json['priorite'] as String?) ??
            ReclamationService.prioriteEstimee(
              ReclamationType.autre,
              '$sujet $description',
            ),
        sentiment: (json['sentiment'] as String?)?.trim().isNotEmpty == true
            ? (json['sentiment'] as String).trim()
            : 'non déterminé',
        objetSuggere: (json['objet'] as String? ?? sujet).trim(),
        conseil: (json['conseil'] as String? ?? '').trim(),
      );
    } on DeepSeekException catch (e) {
      throw ReclamationAiException(e.message);
    }
  }

  ReclamationAnalyse _analyseLocale(String sujet, String description) {
    final texte = '$sujet $description'.toLowerCase();
    ReclamationType type = ReclamationType.autre;
    if (RegExp(r'retard|attend|minutes|en avance|pas venu|absent')
        .hasMatch(texte)) {
      type = ReclamationType.retard;
    } else if (RegExp(r'pay|paiement|argent|rembours|prix|dt\b|tarif')
        .hasMatch(texte)) {
      type = ReclamationType.paiement;
    } else if (RegExp(r'voiture|véhicule|vehicule|clim|sale|siège|pneu|panne')
        .hasMatch(texte)) {
      type = ReclamationType.vehicule;
    } else if (RegExp(r'conducteur|chauffeur|insult|comportement|vitesse|fume')
        .hasMatch(texte)) {
      type = ReclamationType.conducteur;
    }
    final priorite = ReclamationService.prioriteEstimee(type, texte);
    final sentiment = RegExp(r'!{2,}|inadmissible|honte|scandale|jamais')
            .hasMatch(texte)
        ? 'très mécontent'
        : RegExp(r'peur|danger|inquiet').hasMatch(texte)
        ? 'inquiet'
        : 'mécontent';
    return ReclamationAnalyse(
      type: type,
      priorite: priorite,
      sentiment: sentiment,
      objetSuggere: sujet,
      conseil:
          'Précisez la date, l’heure et le trajet concernés, et joignez '
          'une capture ou une photo si possible. Délai de traitement '
          'estimé : ${priorite.sla.inHours} h.',
      locale: true,
    );
  }

  // ---------------------------------------------------------------------
  // 2. Brouillon de réponse pour l'administrateur
  // ---------------------------------------------------------------------

  Future<String> suggererReponse(
    Reclamation r, {
    String ton = 'empathique et professionnel',
  }) async {
    if (!estConfiguree) return _reponseModele(r);
    final fil = r.responses
        .map(
          (m) =>
              '${m.parAdmin ? 'Admin' : 'Étudiant'} : '
              '${m.message.isEmpty ? '[pièce jointe]' : m.message}',
        )
        .join('\n');
    try {
      return await _client.chat(
        system:
            '$_contexte\nTu rédiges la réponse de l’équipe support à un '
            'étudiant. Ton : $ton. En français, 3 à 5 phrases, vouvoiement. '
            'Remercie, reformule brièvement le problème, explique les '
            'mesures prises ou les prochaines étapes concrètes (contact du '
            'conducteur, vérification, remboursement éventuel si paiement), '
            'et termine par « L’équipe UniDrive ». N’invente pas de montant '
            'ni de sanction précise. Réponds uniquement avec le message.',
        user:
            'Catégorie : ${r.typeLabel}\nPriorité : ${r.priorite.label}\n'
            'Statut : ${r.status.label}\nTrajet : ${r.trajet}\n'
            'Objet : ${r.sujet}\nDescription : ${r.description}\n'
            '${fil.isEmpty ? '' : 'Échanges précédents :\n$fil'}',
        temperature: 0.5,
        maxTokens: 450,
      );
    } on DeepSeekException catch (e) {
      throw ReclamationAiException(e.message);
    }
  }

  String _reponseModele(Reclamation r) {
    final etape = switch (r.type) {
      ReclamationType.retard =>
        'Nous avons contacté le conducteur afin qu’il respecte les horaires '
            'annoncés et qu’il prévienne les passagers en cas d’imprévu.',
      ReclamationType.conducteur =>
        'Nous allons examiner le comportement signalé et prendre les '
            'mesures nécessaires auprès du conducteur.',
      ReclamationType.vehicule =>
        'Nous avons demandé au conducteur de vérifier l’état de son '
            'véhicule avant ses prochains trajets.',
      ReclamationType.paiement =>
        'Notre équipe vérifie la transaction et reviendra vers vous '
            'concernant un éventuel remboursement.',
      ReclamationType.autre =>
        'Notre équipe analyse votre demande et reviendra vers vous rapidement.',
    };
    return 'Bonjour,\n\nMerci pour votre signalement concernant '
        '« ${r.sujet} ». $etape\n\nN’hésitez pas à nous répondre si vous '
        'avez des informations complémentaires.\n\nL’équipe UniDrive';
  }

  // ---------------------------------------------------------------------
  // 3. Synthèse globale pour le tableau de bord admin
  // ---------------------------------------------------------------------

  Future<String> syntheseAdmin(List<Reclamation> reclamations) async {
    if (reclamations.isEmpty) {
      return 'Aucune réclamation à analyser.';
    }
    if (!estConfiguree) {
      throw const ReclamationAiException(
        'La synthèse IA nécessite la clé DeepSeek '
        '(--dart-define-from-file=secrets.json).',
      );
    }
    final format = DateFormat('dd/MM');
    final lignes = reclamations
        .take(60)
        .map(
          (r) =>
              '- [${format.format(r.date)}] ${r.typeLabel} | '
              '${r.priorite.label} | ${r.status.label} | ${r.trajet} | '
              '${r.sujet} : ${_tronquer(r.description, 160)}',
        )
        .join('\n');
    try {
      return await _client.chat(
        system:
            '$_contexte\nTu es analyste qualité. À partir de la liste des '
            'réclamations, rédige en français une synthèse courte pour '
            'l’administrateur avec trois rubriques (texte simple, puces « • ») :\n'
            'Problèmes récurrents :\nTrajets / conducteurs à surveiller :\n'
            'Actions recommandées :\nMaximum 12 lignes au total.',
        user: lignes,
        temperature: 0.3,
        maxTokens: 700,
      );
    } on DeepSeekException catch (e) {
      throw ReclamationAiException(e.message);
    }
  }

  static String _tronquer(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}…';
}
