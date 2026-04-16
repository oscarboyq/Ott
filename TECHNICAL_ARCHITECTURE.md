# OTT Platform - Technical Architecture

## Project Structure

```
lib/
├── main.dart                          # Entry point with ProviderScope
├── app/
│   ├── app.dart                       # Main app widget (ConsumerWidget)
│   ├── router/
│   │   └── app_router.dart           # GoRouter with Riverpod auth guard
│   ├── theme/
│   │   └── app_theme.dart            # Material 3 theming
│   └── di/
│       └── injection_container.dart  # Legacy (can be removed)
├── core/
│   ├── constants/
│   │   ├── app_strings.dart          # App constants and strings
│   │   └── app_config.dart           # API configuration
│   ├── exceptions/
│   │   └── app_exception.dart        # Custom exception classes
│   ├── models/
│   │   ├── user_model.dart           # User DTO
│   │   ├── auth_response_model.dart  # Auth response DTO
│   │   ├── video_model.dart          # Video DTO
│   │   ├── subscription_plan_model.dart
│   │   ├── watchlist_item_model.dart
│   │   └── api_response_model.dart   # Generic API response
│   ├── network/
│   │   ├── http_client.dart          # Dio HTTP client singleton
│   │   ├── api_service.dart          # API endpoints wrapper
│   │   └── secure_storage_service.dart  # Secure token storage
│   ├── providers/                    # Riverpod providers
│   │   ├── service_providers.dart    # Http, Storage, API services
│   │   ├── auth_provider.dart        # Authentication state
│   │   ├── video_catalog_provider.dart # Video browsing
│   │   ├── watchlist_provider.dart   # Watchlist management
│   │   └── subscription_provider.dart # Subscription plans
│   └── utils/
│       ├── extensions.dart           # String, Int, Double, DateTime extensions
│       └── validation_helper.dart    # Form validation utilities
├── common/
│   └── widgets/
│       ├── video_card_widget.dart    # Reusable video card
│       ├── common_widgets.dart       # LoadingIndicator, ErrorWidget, EmptyState
│       └── search_widgets.dart       # SearchBar, GenreChip
└── features/
    ├── auth/
    │   ├── data/
    │   ├── domain/
    │   └── presentation/
    │       └── pages/
    │           ├── login_page.dart
    │           └── register_page.dart
    ├── catalog/
    │   ├── data/
    │   ├── domain/
    │   └── presentation/
    │       └── pages/
    │           └── home_page.dart
    ├── video/
    │   ├── data/
    │   ├── domain/
    │   └── presentation/
    │       └── pages/
    │           └── video_details_page.dart
    ├── subscription/
    │   └── presentation/
    │       └── pages/
    │           └── subscription_page.dart
    └── admin/
        └── presentation/
            └── pages/
                └── admin_dashboard_page.dart
```

## State Management Architecture

### Riverpod Providers

#### Service Providers (`service_providers.dart`)
```dart
httpClientProvider          // Dio HTTP client (singleton)
secureStorageProvider       // Secure token storage
apiServiceProvider          // API service wrapper
```

#### Auth Provider (`auth_provider.dart`)
- **State**: `AuthState` with user, tokens, loading, and error states
- **Notifier**: `AuthStateNotifier` handles login/register/logout
- **Computed Providers**:
  - `authProvider` - Full auth state
  - `isAuthenticatedProvider` - Boolean for route guards
  - `currentUserProvider` - Current user data

#### Video Catalog Provider (`video_catalog_provider.dart`)
- **State**: VideoCatalogState with pagination, filtering, and videos list
- **Notifier**: VideoCatalogNotifier handles loading, pagination, filtering
- **Family Providers**:
  - `videoDetailsProvider` - Get single video by ID
  - `searchVideosProvider` - Search videos by query
- **Computed Providers**:
  - `isInWatchlistProvider` - Check if video in watchlist (takes videoId)

#### Watchlist Provider (`watchlist_provider.dart`)
- **State**: WatchlistState with items list
- **Notifier**: WatchlistNotifier handles add/remove/load
- **Computed Providers**:
  - `isInWatchlistProvider` - Check specific video in watchlist

#### Subscription Provider (`subscription_provider.dart`)
- **Providers**:
  - `subscriptionPlansProvider` - Fetch all plans
  - `userSubscriptionProvider` - Get user's current subscription
  - `upgradeSubscriptionProvider` - Handle plan upgrades

## Data Flow

### Authentication Flow
```
LoginPage
  ↓
AuthStateNotifier.login()
  ├→ ApiService.login(email, password)
  ├→ SecureStorageService.saveTokens()
  ├→ HttpClient.setAuthToken()
  ↓
AuthState updates
  ↓
GoRouter redirect to '/'
```

### Video Listing Flow
```
HomePage
  ↓
VideoCatalogNotifier.loadCatalog()
  ├→ ApiService.getVideoCatalog()
  ├→ Parse response to VideoModel list
  ↓
VideoCatalogState.videos updates
  ↓
GridView rebuilds with videos
```

### Watchlist Flow
```
VideoDetailsPage
  ↓
WatchlistNotifier.addToWatchlist(videoId)
  ├→ ApiService.addToWatchlist(videoId)
  ├→ WatchlistNotifier.loadWatchlist() [refresh]
  ↓
WatchlistState.items updates
  ↓
isInWatchlistProvider reflects change
```

## HTTP Request Lifecycle

1. **Request**
   ```dart
   final response = await httpClient.post(
     '/endpoint',
     data: {...}
   )
   ```

2. **Interceptor Processing**
   - Authorization header added (if token available)
   - Request logged (debug mode)

3. **Response Handling**
   - Status code check
   - Error parsing and exception throwing
   - Data parsing to model

4. **Error Handling**
   - DioException caught and mapped to AppException
   - Specific error types: NetworkException, AuthException, ServerException, etc.

## Secure Token Management

### Token Storage
```dart
// Tokens stored in FlutterSecureStorage (encrypted platform storage)
secureStorageService.saveAccessToken(token)
secureStorageService.saveRefreshToken(token)

// Tokens auto-loaded on app start via checkAuthStatus()
```

### Token Usage
```dart
// Automatically added to all requests
httpClient.setAuthToken(token)
// Results in header: Authorization: Bearer {token}
```

### Token Refresh (Future Implementation)
```dart
// Intercept 401 responses and refresh token
// Currently can be added to HttpClient interceptor
```

## Error Handling Strategy

### Exception Hierarchy
```
AppException (base)
├── NetworkException
├── AuthException
│   └── TokenExpiredException
├── ValidationException
├── ServerException (with statusCode)
├── CacheException
└── UnknownException
```

### Error Propagation
```dart
try {
  // API call
} on TokenExpiredException {
  // Logout and redirect to login
} on AuthException {
  // Show unauthorized message
} on NetworkException {
  // Show network error message
}
```

## Model/Entity Mapping

All network responses are parsed using model classes:

```dart
// API Response ↓
{
  "id": "123",
  "title": "Movie",
  ...
}

// ↓ Parse using VideoModel.fromJson()

// VideoModel ↓
VideoModel(
  id: '123',
  title: 'Movie',
  ...
)

// ↓ Use in UI

// ↓ If updating, use .copyWith() for immutability
video.copyWith(rating: 9.0)
```

## Extensions & Utilities

### String Extensions
- `isValidEmail` - Email validation
- `isStrongPassword` - Password strength check
- `truncate()` - Truncate with ellipsis
- `capitalized` - Capitalize first letter

### DateTime Extensions
- `isToday`, `isYesterday` - Date comparison
- `formattedDate` - Format as "Jan 15, 2024"
- `relativeTime` - Format as "2 days ago"

### Int/Double Extensions
- `toReadableTime` - Format as "MM:SS"
- `toCurrency` - Format as "$123.45"

## Security Best Practices Implemented

✅ **Token Security**
- Tokens stored in secure storage (encrypted)
- HttpClient automatically adds to headers
- Tokens cleared on logout

✅ **Request Security**
- HTTPS support with certificate pinning ready
- Request/response logging only in debug mode

✅ **Input Validation**
- Form validation with helper functions
- API response validation
- Exception handling for all network calls

## Testing Recommendations

### Unit Tests
- Provider logic (auth, catalog, watchlist)
- Model serialization/deserialization
- Validation utilities
- Extensions

### Widget Tests
- Login/Register forms
- Home page listings
- Video player widget

### Integration Tests
- Full auth flow
- Video browsing and playback
- Watchlist operations

## Performance Optimization

### Current Optimizations
- Riverpod caching of providers
- Lazy loading of providers
- Pagination for video catalog
- Image caching ready (cached_network_image dependency)

### Recommended Future Optimizations
- Local caching with Hive
- Offline support for watchlist
- Video quality selection
- Lazy image loading in grids
- Pagination optimization

## Deployment Checklist

- [ ] Backend API URL configured in `app_config.dart`
- [ ] All API endpoints implemented
- [ ] HTTPS enabled on backend
- [ ] CORS configured for frontend domain
- [ ] Error messages tested and user-friendly
- [ ] Token refresh logic verified
- [ ] Secure storage working on both iOS and Android
- [ ] App signing configured
- [ ] Version bumped for production
- [ ] Build and test on physical devices

## Future Enhancements

1. **Local Caching**
   - Hive implementation for offline data
   - Cache invalidation strategy

2. **Advanced Features**
   - Search suggestions/autocomplete
   - Recommendations algorithm
   - User preferences storage
   - Download for offline viewing
   - Multi-profile support

3. **Analytics**
   - User tracking
   - Event analytics
   - Error tracking (Sentry)

4. **Performance**
   - Network optimization
   - Image optimization
   - Video codec optimization

5. **Security**
   - Certificate pinning
   - API token encryption
   - Rate limiting
