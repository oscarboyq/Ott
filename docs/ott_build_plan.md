# OTT Build Plan

## Product Goal

Build a small OTT-style platform where:

- Only the admin uploads videos
- Viewers can browse the catalog
- Some videos are free
- Some videos are paid
- Users must log in before accessing paid plans and premium content

## Clean Architecture Shape

We will keep the Flutter app in these layers:

- `presentation`: pages, widgets, controllers
- `domain`: entities, repository contracts, use cases
- `data`: models, data sources, repository implementations
- `app/core`: routing, DI, theme, shared constants

This lets us start with mock data now and swap in real backend services later without rewriting the UI flow.

## Recommended Backend Strategy

For a small first version, the simplest production path is:

- `Firebase Auth` for login
- `Cloud Firestore` for video metadata and access flags
- `Cloud Storage for Firebase` for storing source video files

If you later want a stronger OTT experience with automatic transcoding and smoother streaming, keep the same Flutter architecture and move video delivery to a dedicated service such as Cloudflare Stream or Mux.

## Where Video Files Should Live

Do not keep real video files inside your Flutter project.

Use this flow instead:

1. Admin uploads the video to cloud storage or a streaming service
2. The backend returns a storage path, playback ID, or playback URL
3. Save only metadata in the database:
   - title
   - description
   - thumbnail
   - free or premium flag
   - category
   - duration
   - playback reference
4. Your app reads the metadata list
5. When a user opens a video, the app checks login and entitlement
6. If the user is allowed, the app loads the playback URL

## Suggested Data Model

Each video record should eventually contain fields like:

- `id`
- `title`
- `description`
- `category`
- `isPremium`
- `thumbnailUrl`
- `videoStoragePath` or `playbackUrl`
- `duration`
- `publishedAt`
- `isPublished`

## Build Steps

1. App foundation
   - clean folders
   - routing
   - theme
   - mock auth
   - mock catalog
2. Viewer flow
   - home catalog
   - video details page
   - free vs premium gate
3. Authentication
   - real login
   - session persistence
4. Admin upload flow
   - upload form
   - metadata save
   - publish/unpublish
5. Premium plan flow
   - plan page
   - payment gateway
   - entitlement storage
6. Secure playback
   - storage rules
   - signed access or protected playback flow
7. Production hardening
   - error handling
   - analytics
   - search
   - caching
   - testing

## What This First Slice Delivers

This first implementation creates:

- the clean architecture skeleton
- a working OTT-style viewer UI
- free and premium catalog flags
- login-required premium flow
- a premium plan screen
- a video details page ready for real backend integration
