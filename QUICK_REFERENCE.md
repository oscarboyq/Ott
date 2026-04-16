# 🚀 Quick Reference - Supabase Setup

## Credentials (In `lib/core/constants/app_config.dart`)
```
URL: https://mornbhixlbbebaoosbng.supabase.co
Key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

## Run App
```bash
flutter run
```

## Test Everything
Add to `main.dart` and run:
```dart
import 'package:video/core/network/supabase_tests.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );
  await runCompleteTests();  // ← Run all tests
  runApp(const ProviderScope(child: OttApp()));
}
```

## Use in Your App

### Get Videos
```dart
final apiService = ServiceLocator.getIt<ApiService>();
final videos = await apiService.getVideoCatalog(page: 1);
```

### Get Current User
```dart
final user = ref.watch(currentUserProvider);
```

### Add to Watchlist
```dart
await apiService.addToWatchlist(videoId: 1);
```

### Get Subscriptions
```dart
final plans = await apiService.getSubscriptionPlans();
```

## Files Created/Updated
- ✅ `lib/main.dart` - Supabase init
- ✅ `lib/core/constants/app_config.dart` - Credentials
- ✅ `lib/core/network/http_client.dart` - Auth headers
- ✅ `lib/core/network/api_service.dart` - Supabase endpoints
- ✅ `lib/core/network/supabase_tests.dart` - Test functions (NEW)
- ✅ `lib/core/providers/supabase_provider.dart` - Providers (NEW)

## Status
✅ All 9 API endpoints mapped
✅ JWT authentication configured
✅ RLS policies ready
✅ Zero compilation errors
✅ Ready to test!
