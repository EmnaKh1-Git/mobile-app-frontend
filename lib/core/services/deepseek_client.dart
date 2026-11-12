import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Erreur lisible renvoyée par [DeepSeekClient].
class DeepSeekException implements Exception {
  final String message;
  const DeepSeekException(this.message);

  @override
  String toString() => message;
}

/// Client minimal pour l'API DeepSeek (compatible OpenAI).
///
/// La clé est injectée à la compilation :
/// `flutter run --dart-define-from-file=secrets.json`
class DeepSeekClient {
  DeepSeekClient._();
  static final DeepSeekClient instance = DeepSeekClient._();

  static const _apiKey = String.fromEnvironment('DEEPSEEK_API_KEY');
  static const _endpoint = 'https://api.deepseek.com/chat/completions';
  static const _model = 'deepseek-chat';

  bool get estConfigure => _apiKey.trim().isNotEmpty;

  /// Envoie une conversation et renvoie le texte de la réponse.
  /// Avec [json] = true, la réponse est forcée au format objet JSON
  /// (le prompt doit alors mentionner le mot « JSON »).
  Future<String> chat({
    required String system,
    required String user,
    double temperature = 0.3,
    int maxTokens = 600,
    bool json = false,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (!estConfigure) {
      throw const DeepSeekException(
        'Clé DeepSeek absente : lancez l’application avec '
        '--dart-define-from-file=secrets.json',
      );
    }

    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Authorization': 'Bearer ${_apiKey.trim()}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': _model,
              'temperature': temperature,
              'max_tokens': maxTokens,
              if (json) 'response_format': {'type': 'json_object'},
              'messages': [
                {'role': 'system', 'content': system},
                {'role': 'user', 'content': user},
              ],
            }),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const DeepSeekException('DeepSeek ne répond pas (délai dépassé).');
    } on SocketException {
      throw const DeepSeekException('Pas de connexion Internet.');
    } on http.ClientException catch (e) {
      throw DeepSeekException('Erreur réseau : ${e.message}');
    }

    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      body = decoded is Map ? Map<String, dynamic>.from(decoded) : {};
    } catch (_) {
      body = {};
    }

    if (response.statusCode != 200) {
      final error = body['error'];
      final detail = error is Map ? error['message'] : null;
      throw DeepSeekException(switch (response.statusCode) {
        401 => 'Clé DeepSeek invalide (401).',
        402 => 'Solde DeepSeek insuffisant (402).',
        429 => 'Trop de requêtes DeepSeek, réessayez dans un instant (429).',
        _ =>
          'DeepSeek a refusé la demande (${response.statusCode})'
              '${detail is String ? ' : $detail' : '.'}',
      });
    }

    final choices = body['choices'];
    final message = choices is List && choices.isNotEmpty && choices.first is Map
        ? (choices.first as Map)['message']
        : null;
    final content = message is Map ? message['content'] : null;
    if (content is! String || content.trim().isEmpty) {
      throw const DeepSeekException('DeepSeek n’a renvoyé aucun contenu.');
    }
    return content.trim();
  }

  /// Variante qui décode directement un objet JSON.
  Future<Map<String, dynamic>> chatJson({
    required String system,
    required String user,
    double temperature = 0.2,
    int maxTokens = 700,
  }) async {
    final texte = await chat(
      system: system,
      user: user,
      temperature: temperature,
      maxTokens: maxTokens,
      json: true,
    );
    try {
      final debut = texte.indexOf('{');
      final fin = texte.lastIndexOf('}');
      final brut = debut >= 0 && fin > debut
          ? texte.substring(debut, fin + 1)
          : texte;
      final decoded = jsonDecode(brut);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    throw const DeepSeekException('Réponse JSON de DeepSeek illisible.');
  }
}
