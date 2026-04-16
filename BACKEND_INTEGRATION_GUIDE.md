# OTT Platform Backend Integration Guide

## Overview
Your Flutter OTT platform is now properly structured with:
- ✅ Riverpod for state management
- ✅ Clean architecture (data/domain/presentation)
- ✅ Dio for HTTP requests
- ✅ Secure token storage
- ✅ Authentication flow
- ✅ Video catalog and watchlist
- ✅ UI components

## Step-by-Step Backend Connection

### 1. Configure Backend API Base URL

Update `/lib/core/constants/app_config.dart`:

```dart
static const String baseUrl = 'https://your-api.com/api/v1';
// Change from http://your-backend-api.com/api/v1
```

### 2. Backend API Endpoints Required

Your backend should implement these endpoints:

#### Authentication
- `POST /api/v1/auth/login` - User login
  - Body: `{ email, password }`
  - Response: `{ accessToken, refreshToken, user }`
  
- `POST /api/v1/auth/register` - Register new user
  - Body: `{ email, username, password }`
  - Response: `{ accessToken, refreshToken, user }`
  
- `GET /api/v1/auth/profile` - Get current user profile
  - Headers: `Authorization: Bearer {token}`
  - Response: `{ user }`
  
- `POST /api/v1/auth/refresh` - Refresh access token
  - Body: `{ refreshToken }`
  - Response: `{ accessToken, refreshToken, user }`
  
- `POST /api/v1/auth/logout` - Logout
  - Headers: `Authorization: Bearer {token}`

#### Videos/Catalog
- `GET /api/v1/videos/catalog` - Get video catalog
  - Query Params: `page=1, limit=20, genre=action`
  - Response: `{ videos: [ { id, title, description, thumbnailUrl, videoUrl, genre, rating, duration, viewCount, requiresPremium, releaseDate, createdAt, director, cast, availableQualities } ] }`
  
- `GET /api/v1/videos/:videoId` - Get video details
  - Response: `{ video: { ...videoData } }`
  
- `GET /api/v1/videos/search` - Search videos
  - Query Params: `q=query, page=1, limit=20`
  - Response: `{ results: [...] }`

#### Watchlist
- `GET /api/v1/watchlist` - Get user watchlist
  - Headers: `Authorization: Bearer {token}`
  - Response: `{ watchlist: [ { id, videoId, userId, addedAt, watched, watchProgress } ] }`
  
- `POST /api/v1/watchlist/add` - Add to watchlist
  - Headers: `Authorization: Bearer {token}`
  - Body: `{ videoId }`
  
- `DELETE /api/v1/watchlist/remove` - Remove from watchlist
  - Headers: `Authorization: Bearer {token}`
  - Body: `{ videoId }`

#### Subscription
- `GET /api/v1/subscriptions/plans` - Get subscription plans
  - Response: `{ plans: [ { id, tier, name, description, monthlyPrice, yearlyPrice, maxDevices, hd, fourK, adFree, offlineDownload, features } ] }`
  
- `GET /api/v1/subscriptions/user` - Get user subscription
  - Headers: `Authorization: Bearer {token}`
  - Response: `{ subscription: { ...subscriptionData } }`
  
- `POST /api/v1/subscriptions/upgrade` - Upgrade subscription
  - Headers: `Authorization: Bearer {token}`
  - Body: `{ planId }`

### 3. Security Implementation

#### Token Management
Tokens are automatically managed:
- `SecureStorageService` stores tokens securely
- `HttpClient` automatically adds `Authorization: Bearer {token}` header
- Token refresh happens automatically on 401 responses

#### Best Practices
```dart
// Tokens are automatically loaded when app starts
await ref.read(authProvider.notifier).checkAuthStatus();

// Set token after login/register
httpClient.setAuthToken(authResponse.accessToken);

// Remove token on logout
httpClient.removeAuthToken();
```

### 4. Implement Backend Error Handling

Backend should return errors in this format:
```json
{
  "success": false,
  "message": "Error description",
  "error": "ERROR_CODE",
  "statusCode": 400
}
```

Status codes handled automatically:
- `200` - Success
- `201` - Created
- `400` - Validation error
- `401` - Unauthorized (token expired)
- `403` - Forbidden
- `404` - Not found
- `500` - Server error

### 5. Next Steps

1. **Update pubspec.yaml dependencies** (if not done):
   ```bash
   flutter pub get
   ```

2. **Update API Base URL** in `app_config.dart`

3. **Implement your backend** with the specified endpoints

4. **Configure CORS** on your backend (allow requests from your app)

5. **Test Authentication Flow**:
   - Launch app and try login/register
   - Check tokens are saved securely
   - Verify API calls include authorization header

6. **Test Video Features**:
   - Load video catalog
   - Search videos
   - Watch video details
   - Add/remove watchlist

### 6. Example Backend Response Formats

**Login Response:**
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "refresh_token_here",
  "user": {
    "id": "user123",
    "email": "user@example.com",
    "username": "johndoe",
    "profileImageUrl": "https://...",
    "isPremium": true,
    "createdAt": "2024-01-15T10:30:00Z",
    "premiumExpiresAt": "2024-06-15T10:30:00Z"
  }
}
```

**Catalog Response:**
```json
{
  "videos": [
    {
      "id": "video123",
      "title": "Movie Title",
      "description": "Long description...",
      "thumbnailUrl": "https://...",
      "videoUrl": "https://...",
      "genre": "action",
      "rating": 8.5,
      "duration": 7200,
      "viewCount": 1000,
      "requiresPremium": false,
      "releaseDate": "2024-01-10T00:00:00Z",
      "createdAt": "2024-01-10T10:30:00Z",
      "director": "Director Name",
      "cast": ["Actor 1", "Actor 2"],
      "availableQualities": ["hd", "fullHd", "fourK"]
    }
  ]
}
```

### 7. Development Mode Features

To test without backend:
- Mock repositories are still available in `/features/{feature}/data/repositories/mock_*.dart`
- To use mocks, update providers in `injection_container.dart`
- API service will return mock data when endpoints aren't available

### 8. Important Environment Considerations

- **iOS**: May need to configure `App Transport Security` settings
- **Android**: Add internet permission in `AndroidManifest.xml`
- **HTTPS**: Use HTTPS in production (HTTP works for development)

### 9. Common Issues & Solutions

**Issue: 401 Unauthorized on API calls**
- Solution: Check token is saved in secure storage
- Solution: Verify backend returns valid JWT token format
- Solution: Check token isn't expired

**Issue: CORS errors**
- Solution: Enable CORS on backend API
- Solution: Add proper headers in backend

**Issue: Video not playing**
- Solution: Verify video URLs are accessible
- Solution: Check video format is supported (MP4, HLS recommended)
- Solution: Test URLs in browser first

### 10. Testing Checklist

- [ ] Backend API running and accessible
- [ ] All endpoints responding with correct data format
- [ ] Authentication working (login/register)
- [ ] Tokens persisting across app restarts
- [ ] Video catalog loading
- [ ] Video playback working
- [ ] Watchlist add/remove working
- [ ] Subscription plans loading
- [ ] Error messages displaying correctly
- [ ] App handles network disconnections gracefully

## Next: Monitoring & Analytics

Consider adding:
- Sentry for error tracking
- Firebase Analytics for user tracking
- Mixpanel for event tracking
- App performance monitoring

Good luck with your OTT platform! 🚀
