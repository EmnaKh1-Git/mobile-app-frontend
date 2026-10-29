import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Singleton wrapper around Supabase client for UniDrive.
class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  static const String _url = 'https://glbpfzacfvkzhxooqsox.supabase.co';
  static const String _publishableKey =
      'sb_publishable_vErwOKF_UvwBU08wVx4brg_5XjkU6Fz';

  SupabaseClient get client => Supabase.instance.client;

  /// Initialize Supabase — call once in main() before runApp().
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: _url,
      publishableKey: _publishableKey,
      debug: kDebugMode,
    );
  }

  // ─── Auth helpers ─────────────────────────────────────────────────────────

  User? get currentUser => client.auth.currentUser;
  bool get isSignedIn => currentUser != null;
  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  Future<AuthResponse> signInWithEmail(String email, String password) =>
      client.auth.signInWithPassword(email: email, password: password);

  Future<AuthResponse> signUpWithEmail(
    String email,
    String password, {
    Map<String, dynamic>? data,
  }) =>
      client.auth.signUp(email: email, password: password, data: data);

  Future<void> signOut() => client.auth.signOut();

  Future<void> sendPasswordReset(String email) =>
      client.auth.resetPasswordForEmail(email);

  // ─── Storage helpers ───────────────────────────────────────────────────────

  /// Uploads [file] to [bucket]/[path] and returns the public URL.
  Future<String?> uploadFile({
    required String bucket,
    required String path,
    required File file,
    String contentType = 'image/jpeg',
  }) async {
    try {
      await client.storage.from(bucket).upload(
        path,
        file,
        fileOptions: FileOptions(contentType: contentType, upsert: true),
      );
      return client.storage.from(bucket).getPublicUrl(path);
    } catch (e) {
      debugPrint('[SupabaseService] Erreur upload ($bucket/$path): $e');
      return null;
    }
  }

  /// Uploads an image from [localPath] to Supabase Storage.
  /// Returns the public URL, or null if error.
  Future<String?> uploadImage(String localPath, {String? customName, String bucket = 'unidrive-uploads'}) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) return null;
      final ext = localPath.split('.').last.toLowerCase();
      final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
      final fileName = customName ?? 'img_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = 'images/$fileName';

      // First try configured bucket, fallback to 'reclamations' or 'images' if needed
      final url = await uploadFile(
        bucket: bucket,
        path: path,
        file: file,
        contentType: contentType,
      );
      if (url != null) return url;

      // Fallback bucket 'images'
      return await uploadFile(
        bucket: 'images',
        path: fileName,
        file: file,
        contentType: contentType,
      );
    } catch (e) {
      debugPrint('[SupabaseService] uploadImage failed: $e');
      return null;
    }
  }

  /// Uploads an audio file from [localPath] to Supabase Storage.
  /// Returns the public URL, or null if error.
  Future<String?> uploadAudio(String localPath, {String? customName, String bucket = 'unidrive-uploads'}) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) return null;
      final ext = localPath.split('.').last.toLowerCase();
      final fileName = customName ?? 'audio_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = 'audio/$fileName';

      final url = await uploadFile(
        bucket: bucket,
        path: path,
        file: file,
        contentType: 'audio/mp4',
      );
      if (url != null) return url;

      // Fallback bucket
      return await uploadFile(
        bucket: 'audio',
        path: fileName,
        file: file,
        contentType: 'audio/mp4',
      );
    } catch (e) {
      debugPrint('[SupabaseService] uploadAudio failed: $e');
      return null;
    }
  }

  // ─── Database helpers ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> insert(
    String table,
    Map<String, dynamic> data,
  ) async {
    final response = await client.from(table).insert(data).select().single();
    return response;
  }

  Future<List<Map<String, dynamic>>> select(
    String table, {
    Map<String, dynamic>? filters,
    String? orderBy,
    bool ascending = false,
    int? limit,
  }) async {
    if (orderBy != null) {
      return await client
          .from(table)
          .select()
          .order(orderBy, ascending: ascending)
          .limit(limit ?? 100);
    }
    return await client.from(table).select().limit(limit ?? 100);
  }
}
