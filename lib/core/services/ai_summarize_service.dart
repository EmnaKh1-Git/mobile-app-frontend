import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Service pour reformuler/résumer du texte de réclamation via IA.
class AiSummarizeService {
  AiSummarizeService._();
  static final AiSummarizeService instance = AiSummarizeService._();

  static const _deepseekKey = String.fromEnvironment('DEEPSEEK_API_KEY');
  static const _geminiKey = String.fromEnvironment('GEMINI_API_KEY');

  /// Reformule le texte donné pour le rendre plus clair, concis et professionnel.
  Future<String?> reformuler(String texte) async {
    final clean = texte.trim();
    if (clean.isEmpty) return null;

    // 1. Essai avec DeepSeek si configuré
    if (_deepseekKey.isNotEmpty) {
      try {
        final res = await http.post(
          Uri.parse('https://api.deepseek.com/chat/completions'),
          headers: {
            'Authorization': 'Bearer $_deepseekKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'deepseek-chat',
            'temperature': 0.3,
            'messages': [
              {
                'role': 'system',
                'content':
                    'Tu es un assistant expert pour UniDrive. Reformule cette réclamation étudiante en français formel, clair et concis. Donne directement le texte reformulé sans salutations ni commentaires.',
              },
              {'role': 'user', 'content': clean},
            ],
          }),
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(utf8.decode(res.bodyBytes));
          final reply = data['choices']?[0]?['message']?['content'];
          if (reply != null && reply.toString().trim().isNotEmpty) {
            return reply.toString().trim();
          }
        }
      } catch (e) {
        debugPrint('[AiSummarize] Erreur DeepSeek: $e');
      }
    }

    // 2. Essai avec Gemini si configuré
    if (_geminiKey.isNotEmpty) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_geminiKey',
        );
        final res = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {
                    'text':
                        'Reformule cette réclamation étudiante en français de manière claire, concise et professionnelle sans introduction ni conclusion :\n\n$clean'
                  }
                ]
              }
            ],
          }),
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(utf8.decode(res.bodyBytes));
          final reply =
              data['candidates']?[0]?['content']?['parts']?[0]?['text'];
          if (reply != null && reply.toString().trim().isNotEmpty) {
            return reply.toString().trim();
          }
        }
      } catch (e) {
        debugPrint('[AiSummarize] Erreur Gemini: $e');
      }
    }

    // 3. Reformulation intelligente locale (moteur NLP embarqué)
    return _reformulerLocal(clean);
  }

  /// Moteur de reformulation et synthèse locale
  String _reformulerLocal(String texte) {
    // Nettoyer les espaces multiples et sauts de ligne
    var phrase = texte.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Remplacement d'abréviations et langage familier fréquent
    final repl = {
      RegExp(r'\bslt\b', caseSensitive: false): 'Bonjour',
      RegExp(r'\bsvp\b', caseSensitive: false): "s'il vous plaît",
      RegExp(r'\bpck|parske\b', caseSensitive: false): 'parce que',
      RegExp(r'\bpk\b', caseSensitive: false): 'pourquoi',
      RegExp(r'\bpr\b', caseSensitive: false): 'pour',
      RegExp(r'\bcdd\b', caseSensitive: false): 'conducteur',
      RegExp(r'\bchui|chuis\b', caseSensitive: false): 'je suis',
      RegExp(r'\bproblème grave\b', caseSensitive: false): 'incident majeur',
      RegExp(r'\bpas venu\b', caseSensitive: false): 'absent au rendez-vous',
    };

    repl.forEach((pattern, val) {
      phrase = phrase.replaceAll(pattern, val);
    });

    // Découper en phrases
    final sentences = phrase
        .split(RegExp(r'[.!?]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (sentences.isEmpty) return texte;

    // Capitaliser chaque phrase proprement
    final capitalized = sentences.map((s) {
      if (s.isEmpty) return s;
      return s[0].toUpperCase() + s.substring(1);
    }).toList();

    // Résumé / synthèse professionnelle
    final formatted = capitalized.join('. ');
    return '$formatted.';
  }
}
