# 🚀 Supabase Integration Guide for OTT Platform

## 📋 Table of Contents
1. [Supabase Setup](#supabase-setup)
2. [Database Configuration](#database-configuration)
3. [Flutter App Integration](#flutter-app-integration)
4. [Authentication Flow](#authentication-flow)
5. [Testing & Troubleshooting](#testing--troubleshooting)

---

## Supabase Setup

### ✅ Step 1: Create Supabase Account
**Time: 5 minutes**

1. Go to [https://supabase.com](https://supabase.com)
2. Click **"Sign Up"** → Choose **GitHub** (fastest)
3. Authorize Supabase to access GitHub
4. You're now in the Supabase dashboard

### ✅ Step 2: Create New Project
**Time: 3 minutes**

1. Click **"New Project"** button
2. **Organization**: Create new or use default
3. **Project Name**: `ott-platform` (or your preferred name)
4. **Database Password**: Create a strong password 🔐
   - Save this somewhere safe!
   - You won't see it again
5. **Region**: Choose closest to your users
   - US East (N. Virginia)
   - Europe (Ireland)
   - Asia Pacific (Singapore)
6. Click **"Create new project"**
7. Wait 2-3 minutes for initialization ⏳

### ✅ Step 3: Get Your Credentials
**Time: 2 minutes**

Once project is ready:

1. **Go to Settings → API** (left sidebar)
2. **Copy these values**:
   ```
   PROJECT_URL (URL like: https://xxxxxxxxxxx.supabase.co)
   ANON_KEY (long string starting with eyJ...)
   SERVICE_ROLE_KEY (keep this SECRET! Don't share)
   ```
3. **Save them securely** - we'll use these in Flutter app

---

## Database Configuration

### ✅ Step 4: Create Database Tables

**Time: 5 minutes**

1. In Supabase dashboard → **SQL Editor** (left sidebar)
2. Click **"New Query"**
3. **Copy the entire SQL from**: `docs/supabase_schema.sql`
4. **Paste** into the SQL editor
5. Click **"Run"** button (top right)
6. Wait for execution ✅

**Success signs:**
```
✓ No errors
✓ Tables appear in Tables list (left sidebar)
✓ You can see: videos, watchlist, subscription_plans, etc.
```

### ✅ Step 5: Verify Database Structure

In Supabase, click on each table to confirm:
- ✅ Videos table (with columns: id, title, description, etc.)
- ✅ Subscription Plans (with Free, Premium, VIP)
- ✅ Watchlist table
- ✅ User Profiles
- ✅ Transactions

### ✅ Step 6: Add Sample Video Data

**Time: 5 minutes**

In SQL Editor, run this:

```sql
INSERT INTO videos (title, description, thumbnail_url, video_url, duration_seconds, category, is_free, rating, tagline, accent_hex) 
VALUES 
  ('Flutter Basics', 'Learn Flutter from scratch', 'https://via.placeholder.com/300x200?text=Flutter', 'https://example.com/flutter.mp4', 3600, 'Education', true, 4.5, 'Master the basics', '#2196F3'),
  ('Advanced TypeScript', 'Deep dive into TypeScript', 'https://via.placeholder.com/300x200?text=TypeScript', 'https://example.com/typescript.mp4', 4800, 'Programming', false, 4.8, 'Go professional', '#3178C6'),
  ('Web Design Pro', 'Create stunning designs', 'https://via.placeholder.com/300x200?text=Design', 'https://example.com/design.mp4', 2400, 'Design', true, 4.3, 'Design like a pro', '#FF6B6B');
```

---

## Flutter App Integration

### ✅ Step 7: Update App Configuration

**File**: `lib/core/constants/app_config.dart`

```dart
class AppConfig {
  // Your Supabase credentials from Step 3
  static const String supabaseUrl = 'https://YOUR_PROJECT.supabase.co';
  static const String supabaseAnonKey = 'YOUR_ANON_KEY_HERE';
  
  // Keep for future backend migration
  static const String backendUrl = 'https://your-backend-api.com/api/v1';
}
```

Replace:
- `YOUR_PROJECT.supabase.co` - with your actual project URL
- `YOUR_ANON_KEY_HERE` - with your Anon Key

### ✅ Step 8: Install Supabase SDK

**Time: 2 minutes**

Run in terminal:
```bash
cd /home/asif/code/flutter/video
flutter pub add supabase
```

This adds to your `pubspec.yaml`:
```yaml
dependencies:
  supabase: latest_version
```

Then run: `flutter pub get`

### ✅ Step 9: Update HTTP Client for Supabase

**File**: `lib/core/network/http_client.dart`

Your current HTTP client already works with Supabase's REST API!
Supabase REST API is compatible with standard Dio requests.

### ✅ Step 10: Update API Service

**File**: `lib/core/providers/service_providers.dart`

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video/core/constants/app_config.dart';

// Initialize Supabase
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// For future: also initialize in main.dart main() function
```

---

## Authentication Flow

### ✅ Step 11: Setup Authentication in main.dart

**Update**: `lib/main.dart`

Add this before `runApp()`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  
  runApp(const MyApp());
}
```

### ✅ Step 12: API Endpoints Mapping

Your current API endpoints map to Supabase REST API:

```
POST /auth/login
  → Supabase: signInWithPassword(email, password)

POST /auth/register
  → Supabase: signUp(email, password)

GET /videos/catalog?page=1&limit=10
  → Supabase: from('videos').select()

GET /watchlist/list
  → Supabase: from('watchlist').select()

POST /watchlist/add
  → Supabase: from('watchlist').insert()
```

### ✅ Step 13: Update Auth Provider

Your auth system is ready to use! Just map endpoints:

**Current API calls:**
```dart
// Login
await apiService.login(email, password);

// Register
await apiService.register(email, username, password);
```

These already work because your HTTP client supports REST APIs.

---

## Testing & Troubleshooting

### ✅ Step 14: Test Connection

Run this in your app (temporary):

```dart
// In your auth_provider.dart for testing
Future<void> testSupabaseConnection() async {
  try {
    final response = await Supabase.instance.client
        .from('subscription_plans')
        .select();
    print('✅ Supabase connected! Plans: $response');
  } catch (e) {
    print('❌ Error: $e');
  }
}
```

### ✅ Step 15: Verify Authentication

```dart
// Check if user is already logged in
final user = Supabase.instance.client.auth.currentUser;
if (user != null) {
  print('✅ User logged in: ${user.email}');
} else {
  print('❌ No user logged in');
}
```

### Common Issues & Fixes

| Issue | Cause | Fix |
|-------|-------|-----|
| ❌ "Invalid API key" | Wrong Anon Key | Check `app_config.dart` |
| ❌ "Connection refused" | Wrong URL | Verify project URL from Settings |
| ❌ "Auth failed" | User doesn't exist | Check email format, try sign up |
| ❌ "No rows returned" | Table empty | Insert sample data using SQL |
| ❌ "Permission denied" | RLS policy issue | Check SQL schema RLS policies executed |

---

## 📊 Quick Verification Checklist

Before moving forward, verify:

- [ ] Supabase project created
- [ ] URL copied to `app_config.dart`
- [ ] Anon Key copied to `app_config.dart`
- [ ] SQL schema executed successfully
- [ ] Tables visible in Supabase dashboard
- [ ] Sample video data inserted
- [ ] `supabase_flutter` package installed
- [ ] Supabase initialized in `main.dart`
- [ ] Can view subscription plans in Supabase

---

## 🎯 Next Steps

1. **Test login/register** with Supabase Auth
2. **Load videos** from `videos` table
3. **Test watchlist** add/remove functionality
4. **Test subscriptions** check premium access
5. **(Optional) Setup Stripe** for real payments

---

## 📞 Need Help?

- Supabase Docs: https://supabase.com/docs
- Your Project: https://YOUR_PROJECT.supabase.co
- Contact Support in Supabase Dashboard

