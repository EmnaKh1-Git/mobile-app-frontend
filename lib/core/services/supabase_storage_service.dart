import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service pour uploader des fichiers vers Supabase Storage.
class SupabaseStorageService {
  SupabaseStorageService._();
  static final SupabaseStorageService instance = SupabaseStorageService._();

  static const String _bucket = 'unidrive-uploads';

  SupabaseClient get _client => Supabase.instance.client;

  /// Upload une image locale vers Supabase Storage.
  /// Retourne l'URL publique du fichier uploadé.
  Future<String?> uploadImage(String localPath) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) return null;

      final ext = _extension(localPath, fallback: 'jpg');
      final contentType = _imageContentType(ext);
      final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storagePath = 'reclamations/images/$fileName';

      await _client.storage
          .from(_bucket)
          .upload(
            storagePath,
            file,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );

      final publicUrl = _client.storage.from(_bucket).getPublicUrl(storagePath);
      debugPrint('[SupabaseStorage] Image uploadée : $publicUrl');
      return publicUrl;
    } catch (e, stackTrace) {
      debugPrint('[SupabaseStorage] Erreur upload image : $e');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  /// Upload un fichier audio local vers Supabase Storage.
  /// Retourne l'URL publique du fichier uploadé.
  Future<String?> uploadAudio(String localPath) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) return null;

      final ext = _extension(localPath, fallback: 'm4a');
      final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storagePath = 'reclamations/audio/$fileName';

      await _client.storage
          .from(_bucket)
          .upload(
            storagePath,
            file,
            fileOptions: const FileOptions(
              contentType: 'audio/mp4',
              upsert: true,
            ),
          );

      final publicUrl = _client.storage.from(_bucket).getPublicUrl(storagePath);
      debugPrint('[SupabaseStorage] Audio uploadé : $publicUrl');
      return publicUrl;
    } catch (e, stackTrace) {
      debugPrint('[SupabaseStorage] Erreur upload audio : $e');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  String _extension(String path, {required String fallback}) {
    final name = path.split(RegExp(r'[/\\]')).last;
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return fallback;
    final extension = name.substring(dot + 1).toLowerCase();
    return RegExp(r'^[a-z0-9]+$').hasMatch(extension) ? extension : fallback;
  }

  String _imageContentType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        return 'application/octet-stream';
    }
  }
}
