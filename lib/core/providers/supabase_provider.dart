import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Supabase client provider
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Current user provider
final currentUserProvider = StreamProvider<User?>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return supabase.auth.onAuthStateChange.map((event) => event.session?.user);
});

// User session provider
final userSessionProvider = StreamProvider<Session?>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return supabase.auth.onAuthStateChange.map((event) => event.session);
});

// User ID provider (convenience)
final userIdProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserProvider).value;
  return user?.id;
});

// User email provider (convenience)
final userEmailProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserProvider).value;
  return user?.email;
});
