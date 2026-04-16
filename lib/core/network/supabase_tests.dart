import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video/core/constants/app_config.dart';

// This file contains helpful test functions for verifying Supabase integration
// You can call these from your app (e.g., in a temporary test screen or main.dart)

/// Test 1: Verify Supabase initialization
Future<void> testSupabaseConnection() async {
  try {
    final supabase = Supabase.instance.client;
    print('✅ Supabase initialized successfully');
    print('Project URL: ${AppConstants.supabaseUrl}');

    // Try to fetch subscription plans to verify connection
    final plans = await supabase.from('subscription_plans').select();
    print('✅ Successfully connected to database');
    print('✅ Found ${plans.length} subscription plans');

    for (var plan in plans) {
      print('  - ${plan['name']}: \$${plan['monthly_price']}/month');
    }
  } catch (e) {
    print('❌ Supabase connection error: $e');
  }
}

/// Test 2: Verify videos are in database
Future<void> testVideosCatalog() async {
  try {
    final supabase = Supabase.instance.client;
    final videos = await supabase.from('videos').select().limit(5);

    print('✅ Videos loaded successfully');
    print('✅ Found ${videos.length} videos');

    for (var video in videos) {
      print('  - ${video['title']} (${video['category']})');
    }
    return;
  } catch (e) {
    print('❌ Error loading videos: $e');
  }
}

/// Test 3: Verify subscription plans
Future<void> testSubscriptionPlans() async {
  try {
    final supabase = Supabase.instance.client;
    final plans = await supabase
        .from('subscription_plans')
        .select()
        .eq('is_active', true);

    print('✅ Subscription plans loaded');
    print('✅ Found ${plans.length} active plans');

    for (var plan in plans) {
      print('  - ${plan['name']}: \$${plan['monthly_price']}/month');
    }
  } catch (e) {
    print('❌ Error loading subscription plans: $e');
  }
}

/// Test 4: Test search functionality
Future<void> testSearchVideos(String searchQuery) async {
  try {
    final supabase = Supabase.instance.client;
    final results = await supabase
        .from('videos')
        .select()
        .ilike('title', '%$searchQuery%');

    print('✅ Search successful');
    print('✅ Found ${results.length} results for "$searchQuery"');

    for (var video in results) {
      print('  - ${video['title']}');
    }
  } catch (e) {
    print('❌ Error searching: $e');
  }
}

/// Test 5: Test authentication signup
Future<void> testSignUp(String email, String password) async {
  try {
    final supabase = Supabase.instance.client;
    final response = await supabase.auth.signUp(
      email: email,
      password: password,
    );

    if (response.user != null) {
      print('✅ Sign up successful');
      print('✅ User ID: ${response.user!.id}');
      print('✅ Email: ${response.user!.email}');

      // Sign out after test
      await supabase.auth.signOut();
      print('✅ User signed out');
    }
  } catch (e) {
    print('❌ Sign up error: $e');
  }
}

/// Test 6: Test authentication login
Future<void> testLogin(String email, String password) async {
  try {
    final supabase = Supabase.instance.client;
    final response = await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user != null) {
      print('✅ Login successful');
      print('✅ User ID: ${response.user!.id}');
      print('✅ Access Token: ${response.session?.accessToken}');

      // Sign out after test
      await supabase.auth.signOut();
      print('✅ User signed out');
    }
  } catch (e) {
    print('❌ Login error: $e');
  }
}

/// Test 7: Test watchlist operations
Future<void> testWatchlistOperations() async {
  try {
    final supabase = Supabase.instance.client;

    // Get current user
    final user = supabase.auth.currentUser;
    if (user == null) {
      print('❌ No user logged in. Please login first.');
      return;
    }

    print('✅ Logged in as: ${user.email}');

    // Get watchlist
    final watchlist = await supabase
        .from('watchlist')
        .select()
        .eq('user_id', user.id);

    print('✅ Watchlist loaded');
    print('✅ Found ${watchlist.length} items in watchlist');
  } catch (e) {
    print('❌ Watchlist error: $e');
  }
}

/// Test 8: Complete setup verification
Future<void> runCompleteTests() async {
  print('\n🧪 Starting Supabase Integration Tests...\n');

  print('Test 1: Connection');
  await testSupabaseConnection();

  print('\nTest 2: Videos Catalog');
  await testVideosCatalog();

  print('\nTest 3: Subscription Plans');
  await testSubscriptionPlans();

  print('\nTest 4: Search');
  await testSearchVideos('flutter');

  print('\n✅ All tests completed!\n');
}
