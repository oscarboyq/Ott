# ✅ Supabase Integration Checklist for OTT Platform

## 🎯 Phase 1: Supabase Setup (DO THIS FIRST)

### Step 1: Create Supabase Account & Project
- [ ] Go to https://supabase.com
- [ ] Sign up with GitHub
- [ ] Create new project: `ott-platform`
- [ ] Set database password (save securely!)
- [ ] Choose region closest to you
- [ ] Wait 2-3 minutes for initialization
- [ ] Go to Settings → API

### Step 2: Copy Your Credentials
- [ ] Copy **Project URL** (format: `https://XXXXX.supabase.co`)
- [ ] Copy **Anon Key** (long string starting with `eyJ...`)
- [ ] Save these temporarily in a safe place

---

## 🎯 Phase 2: Database Setup (5 MINUTES)

### Step 3: Create Database Tables
- [ ] Open Supabase dashboard → SQL Editor
- [ ] Click "New Query"
- [ ] Open file: `docs/supabase_schema.sql`
- [ ] Copy ALL the SQL code
- [ ] Paste into SQL Editor
- [ ] Click "Run"
- [ ] Wait for execution (should say ✅ Success)

### Step 4: Verify Tables Created
In Supabase left sidebar, check you see:
- [ ] `videos` table
- [ ] `user_profiles` table
- [ ] `user_subscriptions` table
- [ ] `subscription_plans` table
- [ ] `watchlist` table
- [ ] `watch_history` table
- [ ] `transactions` table
- [ ] `video_ratings` table

### Step 5: Add Sample Data
- [ ] Go to SQL Editor → New Query
- [ ] Paste this SQL:

```sql
INSERT INTO videos (title, description, thumbnail_url, video_url, duration_seconds, category, is_free, rating, tagline, accent_hex) 
VALUES 
  ('Flutter Basics', 'Learn Flutter from scratch', 'https://via.placeholder.com/300x200?text=Flutter', 'https://example.com/flutter.mp4', 3600, 'Education', true, 4.5, 'Master the basics', '#2196F3'),
  ('Advanced TypeScript', 'Deep dive into TypeScript', 'https://via.placeholder.com/300x200?text=TypeScript', 'https://example.com/typescript.mp4', 4800, 'Programming', false, 4.8, 'Go professional', '#3178C6'),
  ('Web Design Pro', 'Create stunning designs', 'https://via.placeholder.com/300x200?text=Design', 'https://example.com/design.mp4', 2400, 'Design', true, 4.3, 'Design like a pro', '#FF6B6B');
```

- [ ] Click "Run"
- [ ] Check `videos` table now has 3 rows

### Step 6: Verify Subscription Plans
- [ ] Open Supabase → Tables → `subscription_plans`
- [ ] You should see 3 plans:
  - [ ] Free ($0)
  - [ ] Premium ($9.99/month)
  - [ ] VIP ($19.99/month)

---

## 🎯 Phase 3: Flutter App Configuration

### Step 7: Update app_config.dart
**File**: `lib/core/constants/app_config.dart`

- [ ] Find the `SUPABASE CONFIGURATION` section
- [ ] Replace `YOUR_PROJECT.supabase.co` with your actual Project URL
- [ ] Replace `YOUR_ANON_KEY_HERE` with your Anon Key
- [ ] Example:
  ```dart
  static const String supabaseUrl = 'https://abc123xyz.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGc...'; // Your anon key
  ```

### Step 8: Install Supabase Package
Run in terminal:
```bash
cd /home/asif/code/flutter/video
flutter pub add supabase_flutter
flutter pub get
```

- [ ] Wait for packages to download
- [ ] Check no errors

### Step 9: Update main.dart
**File**: `lib/main.dart`

Add this import at the top:
```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video/core/constants/app_config.dart';
```

Update the `main()` function to initialize Supabase before `runApp()`:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  try {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );
    print('✅ Supabase initialized successfully');
  } catch (e) {
    print('❌ Supabase init error: $e');
  }
  
  runApp(const MyApp());
}
```

- [ ] File updated
- [ ] No syntax errors

### Step 10: Test Supabase Connection
**Temporary test** - Add to your HomePage or auth page:

```dart
// Test connection (remove after testing)
Future<void> _testSupabaseConnection() async {
  try {
    final plans = await Supabase.instance.client
        .from('subscription_plans')
        .select();
    print('✅ Supabase Connected! Plans: $plans');
  } catch (e) {
    print('❌ Connection Error: $e');
  }
}

// Call this in initState or a button
_testSupabaseConnection();
```

- [ ] Call the test function
- [ ] Check console for ✅ message
- [ ] Check project structure is correct

---

## 🎯 Phase 4: API Integration

### Step 11: Update HTTP Client Headers
**File**: `lib/core/network/http_client.dart`

Add Supabase headers to your Dio client:
```dart
// After creating Dio instance
_dio.options.headers.addAll({
  'apikey': AppConstants.supabaseAnonKey,
  'Content-Type': 'application/json',
});
```

### Step 12: Update API Service Endpoints
**File**: `lib/core/providers/api_service.dart`

Map your endpoints to Supabase tables:
```dart
// Example for getVideos
Future<dynamic> getVideos(int page, int limit) async {
  try {
    final response = await _dio.get(
      '${AppConstants.baseUrl}/videos'
      '?offset=${(page - 1) * limit}'
      '&limit=$limit'
      '&select=*'
      '&order=created_at.desc',
    );
    return response.data;
  } catch (e) {
    throw _handleException(e);
  }
}
```

---

## 🎯 Phase 5: Authentication

### Step 13: Update Login Endpoint
**File**: `lib/core/providers/api_service.dart`

```dart
Future<AuthResponseModel> login(String email, String password) async {
  try {
    // Use Supabase Auth directly (not via API)
    final AuthResponse response = await Supabase.instance.client.auth
        .signInWithPassword(email: email, password: password);
    
    return AuthResponseModel(
      accessToken: response.session?.accessToken ?? '',
      refreshToken: response.session?.refreshToken ?? '',
      user: UserModel(
        id: response.user?.id ?? '',
        email: response.user?.email ?? '',
        username: response.user?.email?.split('@')[0] ?? '',
      ),
    );
  } catch (e) {
    throw _handleException(e);
  }
}
```

### Step 14: Update Register Endpoint
```dart
Future<AuthResponseModel> register(
    String email, String username, String password) async {
  try {
    final AuthResponse response = await Supabase.instance.client.auth
        .signUp(email: email, password: password);
    
    // Create user profile
    if (response.user != null) {
      await Supabase.instance.client.from('user_profiles').insert({
        'id': response.user!.id,
        'email': email,
        'username': username,
      });
    }
    
    return AuthResponseModel(
      accessToken: response.session?.accessToken ?? '',
      refreshToken: response.session?.refreshToken ?? '',
      user: UserModel(
        id: response.user?.id ?? '',
        email: email,
        username: username,
      ),
    );
  } catch (e) {
    throw _handleException(e);
  }
}
```

---

## ✅ Final Verification

Before moving to testing:

- [ ] Supabase project created
- [ ] All credentials in `app_config.dart`
- [ ] `supabase_flutter` package installed
- [ ] Supabase initialized in `main.dart`
- [ ] All tables created in database
- [ ] Sample data inserted
- [ ] HTTP headers updated
- [ ] Test connection shows ✅
- [ ] No console errors

---

## 🧪 Testing Phase

### Test 1: Load Videos
```dart
// In your home page or console
final videos = await Supabase.instance.client
    .from('videos')
    .select();
print('Videos: $videos');
```

Expected: See 3 videos you inserted

### Test 2: Load Subscription Plans
```dart
final plans = await Supabase.instance.client
    .from('subscription_plans')
    .select();
print('Plans: $plans');
```

Expected: See Free, Premium, VIP plans

### Test 3: Login/Register
```dart
// Test signup
await Supabase.instance.client.auth.signUp(
  email: 'test@example.com',
  password: 'TestPassword123!',
);

// Test login
final response = await Supabase.instance.client.auth.signInWithPassword(
  email: 'test@example.com',
  password: 'TestPassword123!',
);
print('User: ${response.user?.email}');
```

Expected: User created and logged in successfully

---

## 🚨 Troubleshooting

| Error | Solution |
|-------|----------|
| ❌ "Invalid API key" | Check Anon Key in `app_config.dart` |
| ❌ "401 Unauthorized" | Verify Anon Key is correct |
| ❌ "Connection refused" | Check Project URL is correct |
| ❌ "No rows returned" | Check sample data was inserted |
| ❌ "Auth failed" | Check email/password format |
| ❌ "RLS policy violation" | Verify RLS policies in schema |

---

## 📝 Notes

- **Anon Key**: Safe to share, use in app
- **Service Role Key**: KEEP SECRET, only for backend
- **All credentials** in `app_config.dart`
- **Row-level security**: Automatically enforced by Supabase
- **Realtime**: Added but can be enabled later

---

## ✅ When Complete

Once all steps are done:
1. ✅ App compiles without errors
2. ✅ Can load videos from Supabase
3. ✅ Can login/register with Supabase Auth
4. ✅ Can add/remove from watchlist
5. ✅ Can check subscription status

**THEN MOVE TO**: Setting up Stripe for real payments (optional)

---

## 📞 Support

- Supabase Docs: https://supabase.com/docs/guides/getting-started
- Flutter Integration: https://supabase.com/docs/guides/getting-started/quickstarts/flutter
- API Reference: https://supabase.com/docs/guides/api/rest/overview

Good luck! 🚀
