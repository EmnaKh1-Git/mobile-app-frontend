import 'dart:convert';

import 'package:http/http.dart' as http;

class ReclamationAiException implements Exception {
  final String message;

  const ReclamationAiException(this.message);

  @override
  String toString() => message;
}

class ReclamationAiService {
  static const _apiKey = String.fromEnvironment('OPENROUTER_API_KEY');
  static const _endpoint = 'https://openrouter.ai/api/v1/chat/completions';

  Future<String> analyser({
    required String sujet,
    required String description,
  }) async {
    if (_apiKey.isEmpty) {
      throw const ReclamationAiException(
        'L’assistance IA n’est pas configurée. Lancez l’application avec '
        '--dart-define=OPENROUTER_API_KEY=<votre-clé>.',
      );
    }

    final response = await http
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://covoiturage-etudiant.local',
            'X-Title': 'Covoiturage Étudiant - Réclamations',
          },
          body: jsonEncode({
            'model': 'openai/gpt-4o-mini',
            'temperature': 0.2,
            'messages': [
              {
                'role': 'system',
                'content':
                    'Tu es un assistant de support pour une application de '
                    'covoiturage étudiant. Analyse la réclamation en français. '
                    'Réponds brièvement avec une catégorie recommandée parmi '
                    'Retard, Conducteur, Véhicule, Paiement ou Autre, puis '
                    'une action conseillée.',
              },
              {
                'role': 'user',
                'content': 'Objet: $sujet\nDescription: $description',
              },
            ],
          }),
        )
        .timeout(const Duration(seconds: 20));

    final body = _decodeObject(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = body['error'];
      final message = error is Map ? error['message'] : null;
      throw ReclamationAiException(
        'OpenRouter a refusé la demande (${response.statusCode})'
        '${message is String ? ': $message' : '.'}',
      );
    }

    final choices = body['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) {
      throw const ReclamationAiException(
        'La réponse de l’assistance IA est invalide.',
      );
    }

    final message = (choices.first as Map)['message'];
    final content = message is Map ? message['content'] : null;
    if (content is! String || content.trim().isEmpty) {
      throw const ReclamationAiException(
        'L’assistance IA n’a retourné aucun conseil.',
      );
    }
    return content.trim();
  }

  Map<String, dynamic> _decodeObject(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const ReclamationAiException(
        'La réponse du service IA est invalide.',
      );
    }
    return Map<String, dynamic>.from(decoded);
  }
}
