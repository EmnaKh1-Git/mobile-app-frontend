import 'dart:io';

import 'package:http/http.dart' as http;

class CloudinaryUploadException implements Exception {
  final String message;
  const CloudinaryUploadException(this.message);

  @override
  String toString() => message;
}

class CloudinaryService {
  CloudinaryService._();

  static final CloudinaryService instance = CloudinaryService._();

  static const _cloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: 'mon-cloud',
  );
  static const _uploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
    defaultValue: 'ddjb5pp5i',
  );

  bool get isConfigured =>
      _cloudName.isNotEmpty &&
      _uploadPreset.isNotEmpty &&
      _cloudName != 'mon-cloud';

  Future<String> uploadImage(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const CloudinaryUploadException(
        'Le fichier image est introuvable.',
      );
    }

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', path));

    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudinaryUploadException(
        'Cloudinary a refusé l’image (${response.statusCode}).',
      );
    }

    final match = RegExp(r'"secure_url"\s*:\s*"([^"]+)"').firstMatch(body);
    if (match == null) {
      throw const CloudinaryUploadException(
        'Cloudinary n’a pas retourné d’URL d’image.',
      );
    }
    return match.group(1)!;
  }

  Future<String> uploadIfLocalPath(String value) async {
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('avatar_')) {
      return value;
    }
    return uploadImage(value);
  }
}
