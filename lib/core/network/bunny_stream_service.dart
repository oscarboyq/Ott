import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video/core/models/bunny_upload_session.dart';

class BunnyStreamService {
  BunnyStreamService(this._supabase);

  final SupabaseClient _supabase;

  Future<BunnyUploadSession> createVideo({
    required String title,
    String? collectionId,
    int? thumbnailTime,
  }) async {
    final response = await _supabase.functions.invoke(
      'bunny-create-video',
      body: {
        'title': title,
        if (collectionId != null && collectionId.isNotEmpty)
          'collectionId': collectionId,
        'thumbnailTime': ?thumbnailTime,
      },
    );

    final data = response.data;
    if (response.status >= 400) {
      throw Exception('Bunny create video failed: $data');
    }
    if (data is! Map) {
      throw Exception('Unexpected Bunny create video response');
    }

    return BunnyUploadSession.fromJson(Map<String, dynamic>.from(data));
  }

  Future<Map<String, dynamic>> getVideo(String videoId) async {
    final response = await _supabase.functions.invoke(
      'bunny-get-video?videoId=$videoId',
      method: HttpMethod.get,
    );

    final data = response.data;
    if (response.status >= 400) {
      throw Exception('Bunny get video failed: $data');
    }
    if (data is! Map) {
      throw Exception('Unexpected Bunny get video response');
    }

    return Map<String, dynamic>.from(data);
  }

  Future<void> deleteVideo(String videoId) async {
    final response = await _supabase.functions.invoke(
      'bunny-delete-video',
      body: {'videoId': videoId},
    );

    if (response.status >= 400) {
      final data = response.data;
      throw Exception('Bunny delete video failed: $data');
    }
  }
}
