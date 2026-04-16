import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video/core/network/api_service.dart';
import 'package:video/core/network/bunny_stream_service.dart';
import 'package:video/core/network/http_client.dart';
import 'package:video/core/network/secure_storage_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// HTTP Client Provider
final httpClientProvider = Provider<HttpClient>((ref) {
  return HttpClient();
});

// Secure Storage Provider
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

// API Service Provider
final apiServiceProvider = Provider<ApiService>((ref) {
  final httpClient = ref.watch(httpClientProvider);
  return ApiService(httpClient);
});

// Bunny Stream Service Provider
final bunnyStreamServiceProvider = Provider<BunnyStreamService>((ref) {
  return BunnyStreamService(Supabase.instance.client);
});
