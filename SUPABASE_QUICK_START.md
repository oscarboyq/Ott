# 🚀 Quick Start: Supabase Integration

## ⏱️ Time to Complete
Total: **~30-45 minutes** (one-time setup)

---

## 📋 What You Need to Do NOW

### ✅ IMMEDIATE: Follow in this order

#### **1️⃣ Go to Supabase (5 minutes)**
```
1. Open https://supabase.com
2. Sign up with GitHub
3. Create project: "ott-platform"
4. Wait for database to initialize (2-3 minutes)
5. Go to Settings → API
6. Copy Project URL + Anon Key
```

#### **2️⃣ Add SQL Schema (5 minutes)**
```
1. Open your Supabase dashboard
2. Go to SQL Editor → New Query
3. Open file: docs/supabase_schema.sql
4. Copy ALL code and paste in SQL editor
5. Click "Run"
6. Wait for ✅ Success message
```

#### **3️⃣ Add Sample Data (2 minutes)**
```
1. SQL Editor → New Query
2. Paste the INSERT query from docs/SUPABASE_CHECKLIST.md
3. Click "Run"
4. Verify 3 videos in videos table
```

#### **4️⃣ Update Flutter App (3 minutes)**
**File**: `lib/core/constants/app_config.dart`

Find this section:
```dart
// ============================================================
// SUPABASE CONFIGURATION (Primary Backend)
// ============================================================
// TODO: Replace with your actual Supabase project URL and key
static const String supabaseUrl = 'https://YOUR_PROJECT.supabase.co';
static const String supabaseAnonKey = 'YOUR_ANON_KEY_HERE';
```

Replace with YOUR actual credentials:
```dart
static const String supabaseUrl = 'https://abc123xyz.supabase.co';
static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5...';
```

#### **5️⃣ Install Supabase Package (2 minutes)**
```bash
cd /home/asif/code/flutter/video
flutter pub add supabase_flutter
flutter pub get
```

#### **6️⃣ Run App (2 minutes)**
```bash
flutter run
```

If you see ✅ in console: **SUCCESS!**

---

## 🎯 Testing Checklist

After running, verify:

- [ ] App starts without errors
- [ ] Check console for "✅ Supabase initialized successfully"
- [ ] Try to navigate to home page
- [ ] No red error boxes on screen

---

## 📁 Files You've Modified

```
lib/
  main.dart                          ← Supabase initialization added
  core/
    constants/
      app_config.dart                ← Supabase credentials added

docs/
  supabase_schema.sql               ← Database schema (created)
  SUPABASE_SETUP_GUIDE.md           ← Full guide (created)
  SUPABASE_CHECKLIST.md             ← Step-by-step checklist (created)
  SUPABASE_API_REFERENCE.md         ← API endpoints (created)
```

---

## 🔍 How to Verify Setup

### Check Console Output
```
✅ Supabase initialized successfully
→ Your setup is correct!

❌ Supabase initialization error: ...
→ Check your credentials in app_config.dart
```

### Check Supabase Dashboard
1. Go to your Supabase project
2. Left sidebar → Tables
3. You should see:
   - videos (3 rows with sample data)
   - subscription_plans (3 rows)
   - user_profiles
   - watchlist
   - And others...

### Check Flutter App
1. Run `flutter run`
2. Look for console output
3. Try to load home page
4. Videos should load from Supabase

---

## ⚠️ If You Get Errors

### Error: "Invalid API key"
```
✗ Check app_config.dart
✓ Make sure Anon Key is correct (starts with eyJ...)
✓ Make sure Project URL matches your Supabase project
```

### Error: "Connection refused"
```
✗ Check internet connection
✓ Make sure Supabase project is initialized
✓ Run: flutter pub get
```

### Error: "No tables found"
```
✗ SQL schema wasn't executed
✓ Go to Supabase → SQL Editor
✓ Run the schema again
```

---

## 🎮 Testing the Connection

### Option 1: Console Test
Add this to `lib/main.dart` temporarily for testing:

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
    
    // TEST: Load videos
    final videos = await Supabase.instance.client
        .from('videos')
        .select();
    print('✅ Videos loaded: ${videos.length} videos');
    
  } catch (e) {
    print('❌ Error: $e');
  }

  runApp(const ProviderScope(child: OttApp()));
}
```

Expected console output:
```
✅ Supabase initialized successfully
✅ Videos loaded: 3 videos
```

---

## 📞 Need Help?

### Issue: Can't get credentials
→ Check: https://supabase.com/docs/guides/getting-started

### Issue: SQL won't run
→ Copy the entire `supabase_schema.sql` file and paste all at once

### Issue: App crashes after adding Supabase
→ Make sure `supabase_flutter` is installed: `flutter pub add supabase_flutter`

---

## ✅ Completion Checklist

- [ ] Supabase account created
- [ ] Project initialized
- [ ] SQL schema executed
- [ ] Sample data added
- [ ] Credentials in app_config.dart
- [ ] supabase_flutter installed
- [ ] main.dart updated
- [ ] App runs without errors
- [ ] Console shows ✅ message
- [ ] Supabase dashboard shows tables

**Once all checked ✅ → You're ready for Phase 2!**

---

## 🎯 Next Steps (After Basic Setup Works)

1. **Test Authentication**
   - Implement login with Supabase Auth
   - Test registration
   - Test JWT token handling

2. **Connect API Service**
   - Map existing endpoints to Supabase tables
   - Update video loading
   - Update watchlist operations

3. **Test Full Flow**
   - Login → Load videos → Add to watchlist
   - Check subscription status
   - Test premium video access

4. **Optional: Stripe Integration**
   - Connect Stripe for payments
   - Implement subscription upgrade flow

---

## 📞 Getting Support

- **Supabase Support**: https://supabase.com/docs
- **Flutter Integration**: https://supabase.com/docs/guides/getting-started/quickstarts/flutter
- **Your Project**: Login to https://supabase.com → See your dashboard

---

**Happy coding! 🚀**

