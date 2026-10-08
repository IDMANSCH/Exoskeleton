import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class CloudinaryUploadService {
  static const apiKey = String.fromEnvironment(
    'CLOUDINARY_API_KEY',
    defaultValue: 'iKxKkrm0EHlg6wf7Mu_CwCB2jn0',
  );
  static const cloudName = String.fromEnvironment('CLOUDINARY_CLOUD_NAME');
  static const uploadPreset =
      String.fromEnvironment('CLOUDINARY_UPLOAD_PRESET');

  Future<String> uploadAvatar(XFile image) async {
    if (cloudName.isEmpty || uploadPreset.isEmpty) {
      throw StateError('Missing Cloudinary cloud name or upload preset');
    }

    final uri = Uri.https(
      'api.cloudinary.com',
      '/v1_1/$cloudName/image/upload',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['api_key'] = apiKey
      ..fields['upload_preset'] = uploadPreset
      ..fields['folder'] = 'exoskeleton-leg/avatars'
      ..files.add(await http.MultipartFile.fromPath('file', image.path));

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    final body = jsonDecode(responseBody);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = body is Map ? body['error'] : null;
      final message = error is Map ? error['message'] : null;
      throw StateError(message?.toString() ?? 'Cloudinary upload failed');
    }

    if (body is Map && body['secure_url'] is String) {
      return body['secure_url'] as String;
    }
    throw const FormatException('Invalid Cloudinary upload response');
  }
}
