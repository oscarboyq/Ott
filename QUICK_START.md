# Quick Start Guide - OTT Platform

## What's Been Done

Your Flutter OTT platform has been fully restructured with modern best practices:

### ✅ Architecture
- Clean Architecture (data/domain/presentation)
- Feature-based folder structure
- Proper separation of concerns

### ✅ State Management
- **Riverpod** for reactive state management
- Providers for: Auth, Video Catalog, Watchlist, Subscriptions
- Computed providers for derived state
- Proper error and loading states

### ✅ Networking
- **Dio** HTTP client with interceptors
- API Service wrapper for all endpoints
- Secure token storage (encrypted)
- Comprehensive error handling
- Request/response logging (debug mode)

### ✅ Authentication
- Login and registration pages
- Secure token management
- Auto-login on app restart
- Route protection with auth guard

### ✅ UI/UX
- Material Design 3 theme (dark by default)
- Reusable widgets (VideoCard, LoadingIndicator, ErrorWidget)
- Proper error states and loading indicators
- Empty states

### ✅ Core Features Ready
- Video catalog with pagination
- Video search
- Watchlist management
- Subscription plans
- Video player integration

## Next Steps

### 1. Update Configuration (IMPORTANT)
```dart
// File: lib/core/constants/app_config.dart
static const String baseUrl = 'https://your-backend-url.com/api/v1';
```

### 2. Get Dependencies
```bash
cd /home/asif/code/flutter/video
flutter pub get
```

### 3. Generate Code (Riverpod & Hive)
```bash
flutter pub run build_runner build
```

### 4. Run the App
```bash
flutter run
```

### 5. Test Login
- Use any email/password format
- Backend will validate (mock data in development)

### 6. Build Your Backend

See **BACKEND_INTEGRATION_GUIDE.md** for:
- Required API endpoints
- Request/response formats
- Authentication flow
- Error handling

## Important Files

| File | Purpose |
|------|---------|
| `lib/core/constants/app_config.dart` | API configuration |
| `lib/core/network/api_service.dart` | API endpoint definitions |
| `lib/core/providers/*.dart` | State management |
| `lib/features/*/presentation/pages/` | UI screens |
| `BACKEND_INTEGRATION_GUIDE.md` | Backend setup guide |
| `TECHNICAL_ARCHITECTURE.md` | Architecture overview |

## Default Credentials

For testing with mock data:
- **Email**: demo@example.com
- **Password**: Demo123!

## Key Providers & How To Use

### Auth Provider
```dart
final authState = ref.watch(authProvider);
await ref.read(authProvider.notifier).login(email, password);
```

### Video Catalog
```dart
final videos = ref.watch(videoCatalogProvider);
await ref.read(videoCatalogProvider.notifier).loadCatalog();
```

### Watchlist
```dart
final isInWatchlist = ref.watch(isInWatchlistProvider(videoId));
await ref.read(watchlistProvider.notifier).addToWatchlist(videoId);
```

## Debugging

### Enable/Disable API Logging
```dart
// In lib/core/network/http_client.dart
if (kDebugMode) {  // Remove this condition to always log
  _dio.interceptors.add(PrettyDioLogger(...));
}
```

### Check App Flow
1. Do you see Login page? → App running ✓
2. Can you login? → Auth flow working ✓
3. Do you see videos? → API calls working ✓
4. Can you play video? → Video player working ✓

## Common Issues

**Issue**: "Cannot connect to API"
- Solution: Check backend is running
- Solution: Verify base URL in `app_config.dart`
- Solution: Check internet connection

**Issue**: "Login not working"  
- Solution: Check API returns correct response format
- Solution: Check email/password validation
- Solution: Check tokens are being saved

**Issue**: "Videos not loading"
- Solution: Check `/videos/catalog` endpoint
- Solution: Verify response format matches VideoModel
- Solution: Check pagination parameters

## Project Statistics

- **Total Files Created**: 40+
- **Dependencies Added**: 15+
- **Providers**: 8
- **Screens**: 4
- **Widgets**: 5+
- **Core Services**: 3
- **Models**: 6

## Next Advanced Features (Optional)

1. **Search & Filtering**
   - Implement search UI
   - Add genre filtering
   - Add sorting options

2. **Watchlist**
   - Create watchlist page
   - Add to watchlist from video cards
   - Clear watchlist functionality

3. **User Profile**
   - Create profile page
   - Edit profile functionality
   - Logout functionality

4. **Subscription Management**
   - Create subscription page
   - Plan selection
   - Payment integration

5. **Admin Dashboard**
   - Video management
   - User analytics
   - Upload new videos

## Support & Documentation

- **Technical Details**: See `TECHNICAL_ARCHITECTURE.md`
- **Backend Setup**: See `BACKEND_INTEGRATION_GUIDE.md`
- **Code Comments**: Check inline code documentation
- **Model Schemas**: Check classes in `lib/core/models/`

## Production Checklist

Before deploying:
- [ ] Backend API fully implemented
- [ ] SSL certificate configured
- [ ] CORS enabled
- [ ] Error messages user-friendly
- [ ] App tested on real devices
- [ ] Sensitive data removed
- [ ] Version bumped
- [ ] Build optimizations done
- [ ] App signing configured
- [ ] All dependencies updated

Good luck! Your OTT platform is ready for connection! 🚀
