# 🔌 Supabase REST API Endpoints Reference

## 📌 Base URLs
```
REST API: https://YOUR_PROJECT.supabase.co/rest/v1
Auth API: https://YOUR_PROJECT.supabase.co/auth/v1
```

## 🔐 Authentication Header
```
Authorization: Bearer YOUR_ANON_KEY
Content-Type: application/json
```

---

## 👤 Authentication Endpoints

### Sign Up
```
POST /auth/v1/signup
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "SecurePassword123!"
}

Response:
{
  "user": {
    "id": "uuid",
    "email": "user@example.com"
  },
  "session": {
    "access_token": "eyJ...",
    "refresh_token": "eyJ...",
    "expires_in": 3600
  }
}
```

### Sign In
```
POST /auth/v1/token?grant_type=password
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "SecurePassword123!"
}
```

### Sign Out
```
POST /auth/v1/logout
Authorization: Bearer ACCESS_TOKEN
```

### Get Current User
```
GET /auth/v1/user
Authorization: Bearer ACCESS_TOKEN
```

### Refresh Token
```
POST /auth/v1/token?grant_type=refresh_token
Content-Type: application/json

{
  "refresh_token": "eyJ..."
}
```

---

## 🎬 Videos Endpoints

### Get All Videos
```
GET /rest/v1/videos
  ?select=*
  &order=created_at.desc
  &limit=10
  &offset=0

Response:
[
  {
    "id": "uuid",
    "title": "Flutter Basics",
    "description": "Learn Flutter",
    "video_url": "https://...",
    "duration_seconds": 3600,
    "category": "Education",
    "is_free": true,
    "rating": 4.5,
    "views_count": 1200,
    "created_at": "2024-01-15T10:30:00Z"
  },
  ...
]
```

### Get Video by Category
```
GET /rest/v1/videos
  ?select=*
  &category=eq.Education
  &limit=10

# Operators:
# eq - equals
# neq - not equals
# gt - greater than
# gte - greater than or equal
# lt - less than
# lte - less than or equal
# like - pattern matching
```

### Get Free Videos Only
```
GET /rest/v1/videos
  ?select=*
  &is_free=eq.true
  &order=rating.desc
  &limit=20
```

### Get Single Video
```
GET /rest/v1/videos
  ?select=*
  &id=eq.VIDEO_UUID
```

### Search Videos
```
GET /rest/v1/videos
  ?select=*
  &or=(title.ilike.%flutter%,description.ilike.%flutter%)
  &limit=10

# ilike = case-insensitive like
# % = wildcard character
```

### Create Video (Admin Only)
```
POST /rest/v1/videos
Authorization: Bearer ACCESS_TOKEN
Content-Type: application/json

{
  "title": "New Course",
  "description": "Course description",
  "thumbnail_url": "https://...",
  "video_url": "https://...",
  "duration_seconds": 5400,
  "category": "Programming",
  "is_free": false,
  "rating": 0,
  "tagline": "Learn something new"
}
```

### Update Video (Admin Only)
```
PATCH /rest/v1/videos
  ?id=eq.VIDEO_UUID
Authorization: Bearer ACCESS_TOKEN
Content-Type: application/json

{
  "title": "Updated Title",
  "rating": 4.8
}
```

### Delete Video (Admin Only)
```
DELETE /rest/v1/videos
  ?id=eq.VIDEO_UUID
Authorization: Bearer ACCESS_TOKEN
```

---

## 📋 Watchlist Endpoints

### Get Current User's Watchlist
```
GET /rest/v1/watchlist
  ?select=*,video:videos(*)
  &user_id=eq.CURRENT_USER_UUID
  &order=added_at.desc

Response:
[
  {
    "id": "uuid",
    "user_id": "uuid",
    "video_id": "uuid",
    "position_seconds": 0,
    "percentage_watched": 0,
    "is_completed": false,
    "video": {
      "id": "uuid",
      "title": "Flutter Basics",
      ...
    }
  }
]
```

### Add to Watchlist
```
POST /rest/v1/watchlist
Authorization: Bearer ACCESS_TOKEN
Content-Type: application/json

{
  "user_id": "CURRENT_USER_UUID",
  "video_id": "VIDEO_UUID"
}

Response:
{
  "id": "uuid",
  "user_id": "uuid",
  "video_id": "uuid",
  "added_at": "2024-01-15T10:30:00Z"
}
```

### Update Watchlist (Progress)
```
PATCH /rest/v1/watchlist
  ?id=eq.WATCHLIST_UUID
Authorization: Bearer ACCESS_TOKEN

{
  "position_seconds": 1500,
  "percentage_watched": 42,
  "last_watched_at": "2024-01-15T15:45:00Z"
}
```

### Remove from Watchlist
```
DELETE /rest/v1/watchlist
  ?id=eq.WATCHLIST_UUID
  &user_id=eq.CURRENT_USER_UUID
Authorization: Bearer ACCESS_TOKEN
```

### Mark as Completed
```
PATCH /rest/v1/watchlist
  ?id=eq.WATCHLIST_UUID
Authorization: Bearer ACCESS_TOKEN

{
  "is_completed": true,
  "percentage_watched": 100
}
```

---

## 💳 Subscription Plans Endpoints

### Get All Subscription Plans
```
GET /rest/v1/subscription_plans
  ?select=*
  &is_active=eq.true
  &order=monthly_price.asc

Response:
[
  {
    "id": "uuid",
    "name": "Free",
    "monthly_price": 0,
    "annual_price": 0,
    "features": {
      "key_features": ["Limited videos", "Standard quality"]
    }
  },
  {
    "id": "uuid",
    "name": "Premium",
    "monthly_price": 9.99,
    "annual_price": 99.99,
    "features": {
      "key_features": ["All videos", "HD quality", "Offline download"]
    }
  }
]
```

### Get User's Current Subscription
```
GET /rest/v1/user_subscriptions
  ?select=*,plan:subscription_plans(*)
  &user_id=eq.CURRENT_USER_UUID
  &is_active=eq.true

Response:
[
  {
    "id": "uuid",
    "user_id": "uuid",
    "plan_id": "uuid",
    "expires_at": "2024-12-31T23:59:59Z",
    "plan_name_snapshot": "Premium",
    "price_amount_snapshot": 9.99,
    "price_currency_snapshot": "usdt",
    "billing_period_snapshot": "monthly",
    "plan": {
      "id": "uuid",
      "name": "Premium",
      "monthly_price": 9.99
    }
  }
]
```

### Upgrade Subscription
```
POST /rest/v1/user_subscriptions
Authorization: Bearer ACCESS_TOKEN

{
  "user_id": "CURRENT_USER_UUID",
  "plan_id": "PLAN_UUID",
  "auto_renew": true
}
```

---

## 👥 User Profile Endpoints

### Get Current User Profile
```
GET /rest/v1/user_profiles
  ?select=*
  &id=eq.CURRENT_USER_UUID

Response:
{
  "id": "uuid",
  "username": "john_doe",
  "full_name": "John Doe",
  "bio": "Flutter developer",
  "subscription_tier": "premium",
  "preferences": {
    "language": "en",
    "notifications": true
  }
}
```

### Update User Profile
```
PATCH /rest/v1/user_profiles
  ?id=eq.CURRENT_USER_UUID
Authorization: Bearer ACCESS_TOKEN

{
  "full_name": "John Updated",
  "bio": "Updated bio",
  "preferences": {
    "language": "es",
    "notifications": false
  }
}
```

---

## 📊 Watch History Endpoints

### Get Watch History
```
GET /rest/v1/watch_history
  ?select=*,video:videos(title,category)
  &user_id=eq.CURRENT_USER_UUID
  &order=watched_at.desc
  &limit=20
```

### Add to Watch History
```
POST /rest/v1/watch_history
Authorization: Bearer ACCESS_TOKEN

{
  "user_id": "CURRENT_USER_UUID",
  "video_id": "VIDEO_UUID",
  "duration_watched_seconds": 1500
}
```

History rows are unique per `(user_id, video_id)`. Rewatching the same video updates the existing row instead of inserting a duplicate.

---

## ⭐ Ratings Endpoints

### Get Video Ratings
```
GET /rest/v1/video_ratings
  ?select=*
  &video_id=eq.VIDEO_UUID
  &order=created_at.desc

Response:
[
  {
    "id": "uuid",
    "user_id": "uuid",
    "rating": 5,
    "review_text": "Awesome course!",
    "created_at": "2024-01-15T10:30:00Z"
  }
]
```

### Rate a Video
```
POST /rest/v1/video_ratings
Authorization: Bearer ACCESS_TOKEN

{
  "user_id": "CURRENT_USER_UUID",
  "video_id": "VIDEO_UUID",
  "rating": 5,
  "review_text": "Excellent content!"
}
```

### Update Rating
```
PATCH /rest/v1/video_ratings
  ?user_id=eq.CURRENT_USER_UUID&video_id=eq.VIDEO_UUID
Authorization: Bearer ACCESS_TOKEN

{
  "rating": 4,
  "review_text": "Good, but could be better"
}
```

---

## 📝 Query Parameters

### Pagination
```
?limit=10        # Items per page
&offset=0        # Skip N items

# Example: Get 10 videos, skip first 20
?limit=10&offset=20
```

### Ordering
```
&order=created_at.desc     # Descending
&order=rating.asc          # Ascending
&order=created_at.desc,rating.asc  # Multiple

# Operators:
# asc = ascending
# desc = descending
```

### Filtering
```
&column=eq.value           # Equals
&column=neq.value          # Not equals
&column=gt.value           # Greater than
&column=gte.value          # Greater than or equal
&column=lt.value           # Less than
&column=lte.value          # Less than or equal
&column=like.%pattern%     # Case-sensitive pattern
&column=ilike.%pattern%    # Case-insensitive pattern
&column=in.(1,2,3)         # In array
&column=is.null            # Is null
&column=is.true            # Is true

# Example: Rating > 4 AND is_free = true
?rating=gt.4&is_free=eq.true
```

### Select Specific Columns
```
?select=id,title,rating
?select=id,title,video:videos(title)  # With nested select
```

---

## 🚨 Error Responses

### 401 Unauthorized
```json
{
  "error": "Unauthorized",
  "error_description": "Invalid or expired token"
}
```

### 403 Forbidden (RLS Policy)
```json
{
  "error": "Forbidden",
  "error_description": "Permission denied by row-level-security policy"
}
```

### 409 Conflict (Unique Constraint)
```json
{
  "error": "Conflict",
  "error_description": "duplicate key value violates unique constraint"
}
```

### 400 Bad Request
```json
{
  "error": "Bad Request",
  "error_description": "Invalid request parameters"
}
```

---

## 💡 Common Query Examples

### Get trending videos (last 7 days, highest rated)
```
GET /rest/v1/videos
  ?select=*
  &created_at=gte.2024-01-08
  &order=rating.desc
  &limit=10
```

### Get user's premium watchlist
```
GET /rest/v1/watchlist
  ?select=*,video:videos(*)
  &user_id=eq.USER_UUID
  &video:videos(is_free)=eq.false
```

### Get user's completed videos
```
GET /rest/v1/watchlist
  ?select=video:videos(title,category)
  &user_id=eq.USER_UUID
  &is_completed=eq.true
```

### Search and filter
```
GET /rest/v1/videos
  ?select=*
  &title=ilike.%flutter%
  &is_free=eq.true
  &order=rating.desc
```

---

## 📚 Additional Resources

- [Supabase REST API Docs](https://supabase.com/docs/guides/api/rest/overview)
- [PostgREST Documentation](https://postgrest.org/en/v11/api/overview.html)
- [PostgreSQL Operators](https://www.postgresql.org/docs/current/functions-comparison.html)

