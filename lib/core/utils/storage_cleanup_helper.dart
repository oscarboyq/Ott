import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Helper utility to safely extract and purge thumbnail files from Supabase Storage.
class StorageCleanupHelper {
  /// Extracts the relative storage path (e.g. `admin/123-abc.jpg`) from a full Supabase public URL.
  /// Returns null if the URL is not a Supabase Storage thumbnails bucket URL.
  static String? extractThumbnailStoragePath(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final normalized = url.trim();

    // Look for pattern /thumbnails/admin/...
    const marker = '/thumbnails/';
    final markerIndex = normalized.indexOf(marker);
    if (markerIndex == -1) return null;

    final pathWithQuery = normalized.substring(markerIndex + marker.length);
    final questionMarkIndex = pathWithQuery.indexOf('?');
    final path = questionMarkIndex != -1
        ? pathWithQuery.substring(0, questionMarkIndex)
        : pathWithQuery;

    if (path.isEmpty) return null;
    return Uri.decodeComponent(path);
  }

  /// Attempts to delete a thumbnail from the Supabase Storage `thumbnails` bucket.
  /// Does not throw on error; logs gracefully instead.
  static Future<bool> tryDeleteThumbnail(String? url) async {
    final path = extractThumbnailStoragePath(url);
    if (path == null) return false;

    try {
      await Supabase.instance.client.storage.from('thumbnails').remove([path]);
      debugPrint('[StorageCleanupHelper] Successfully removed storage thumbnail: $path');
      return true;
    } catch (error) {
      debugPrint('[StorageCleanupHelper] Could not remove thumbnail ($path): $error');
      return false;
    }
  }
}
