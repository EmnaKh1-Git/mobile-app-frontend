import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'email_config.dart';

class EmailSendResult {
  final bool success;
  final String code;
  final String message;

  const EmailSendResult({
    required this.success,
    required this.code,
    required this.message,
  });
}

class EmailService {
  static final EmailService _instance = EmailService._internal();
  factory EmailService() => _instance;
  static EmailService get instance => _instance;

  EmailService._internal();

  String generateVerificationCode() {
    return (1000 + Random().nextInt(9000)).toString();
  }

  Future<EmailSendResult> sendRecoveryEmail({
    required String recipientEmail,
    required String recipientName,
  }) async {
    final code = generateVerificationCode();

    if (EmailConfig.devModeMockEnabled) {
      return EmailSendResult(
        success: true,
        code: code,
        message: 'Mode simulation actif. Code : $code',
      );
    }

    if (!EmailConfig.isConfigured) {
      return EmailSendResult(
        success: false,
        code: code,
        message: 'Identifiants EmailJS non configurés.',
      );
    }

    HttpClient? client;
    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 12);

      final uri = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
      final request = await client.postUrl(uri);
      
      request.headers.set('content-type', 'application/json');
      request.headers.set('origin', 'http://localhost');

      final Map<String, dynamic> bodyData = {
        'service_id': EmailConfig.serviceId.trim(),
        'template_id': EmailConfig.templateId.trim(),
        'user_id': EmailConfig.publicKey.trim(),
        'template_params': {
          'to_email': recipientEmail,
          'to_name': recipientName,
          'name': recipientName,
          'from_name': 'UniDrive',
          'verification_code': code,
          'code': code,
          'email': recipientEmail,
          'user_email': recipientEmail,
          'message': 'Voici votre code de sécurité pour réinitialiser votre mot de passe : $code',
          'app_name': 'UniDrive',
          'support_email': 'support@unidrive.tn',
        },
      };

      if (EmailConfig.privateKey.trim().isNotEmpty) {
        bodyData['accessToken'] = EmailConfig.privateKey.trim();
      }

      request.write(jsonEncode(bodyData));
      
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return EmailSendResult(
          success: true,
          code: code,
          message: 'E-mail de récupération envoyé avec succès à $recipientEmail.',
        );
      } else {
        return EmailSendResult(
          success: false,
          code: code,
          message: 'Erreur EmailJS (${response.statusCode}) : ${responseBody.isNotEmpty ? responseBody : "Vérifiez vos clés EmailJS."}',
        );
      }
    } catch (e) {
      return EmailSendResult(
        success: false,
        code: code,
        message: 'Erreur de connexion lors de l\'envoi de l\'e-mail : $e',
      );
    } finally {
      client?.close();
    }
  }
}
