# ReelHouse OTT — Full-Stack Streaming Platform

<p align="center">
  <a href="https://ott-steel.vercel.app/"><img src="https://img.shields.io/badge/Live_Demo-ott--steel.vercel.app-000000?style=for-the-badge&logo=vercel&logoColor=white" alt="Live Demo on Vercel" /></a>
  <a href="https://github.com/oscarboyq/Ott/releases/latest"><img src="https://img.shields.io/badge/Download-Android_APK-3DDC84?style=for-the-badge&logo=android&logoColor=white" alt="Download APK" /></a>
  <img src="https://img.shields.io/badge/Flutter-3.47-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-3.13-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Supabase-PostgreSQL-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white" alt="Supabase" />
  <img src="https://img.shields.io/badge/Bunny%20Stream-HLS%20CDN-FF9400?style=for-the-badge&logo=bunny&logoColor=white" alt="Bunny Stream" />
  <img src="https://img.shields.io/badge/Tests-63%20Passing%20(100%25)-brightgreen?style=for-the-badge" alt="Tests" />
  <img src="https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge" alt="License: MIT" />
</p>

---

## 📌 Overview

**ReelHouse** is a full-stack Over-The-Top (OTT) media streaming application built with **Flutter** (Web & Android). It uses **Supabase** for user authentication, PostgreSQL database with Row Level Security (RLS), and thumbnail storage, paired with **Bunny Stream CDN** for chunked resumable video uploads and adaptive bitrate HLS video playback.

- 🌐 **Live Web Application:** [https://ott-steel.vercel.app/](https://ott-steel.vercel.app/)
- 📦 **Android Build:** [Download Latest Release APK](https://github.com/oscarboyq/Ott/releases/latest)

---

## 📸 Product Showcase

<p align="center">
  <img src="docs/screenshots/home_catalog.png" alt="ReelHouse Home Catalog & Continue Watching" width="100%" />
  <br>
  <em>🎬 Home Catalog: Continue Watching rail with real-time watch progress, featured series, and reels shortcuts</em>
</p>

<p align="center">
  <img src="docs/screenshots/series_detail.png" alt="Multi-Season Series Engine" width="49%" />
  &nbsp;
  <img src="docs/screenshots/reels_feed.png" alt="Short-Form Vertical Reels Player" width="49%" />
  <br>
  <em>📺 Left: Multi-Season Series Engine with Episode Resume &nbsp;|&nbsp; 📱 Right: Fullscreen Vertical Reels Player</em>
</p>

<p align="center">
  <img src="docs/screenshots/admin_dashboard.png" alt="ReelHouse Admin Video Management" width="100%" />
  <br>
  <em>🛠️ Admin Console: Video & Reel management, Bunny Stream transcoding status (READY / PROC), and access toggles</em>
</p>

---

## 🌟 Core Features

- **🎬 Video Catalog & Discovery**: Browse content with hero showcases, genre filtering (Action, Drama, Sci-Fi, etc.), live search, and categorized rails.
- **📊 Continue Watching & Progress Sync**: Tracks playback timestamps across videos and episodes, with visual progress bars and resume buttons.
- **📺 Multi-Season Series**: Hierarchical structure (`Series` ➔ `Seasons` ➔ `Episodes`) with individual episode progress tracking and details.
- **📱 Short-Form Reels**: Fullscreen vertical swipeable video player with gesture controls and overlay metadata.
- **🛠️ Admin Management Console**: Dedicated dashboard to upload videos/reels, monitor Bunny Stream transcoding status (`READY` / `0% PROC`), edit titles/genres, and toggle free access.
- **🔐 Authentication & RBAC**: Supabase Auth with role-based permissions (`User`, `Admin`, `Owner`) and database Row Level Security.
- **🎨 Theme Support**: Adaptive Material 3 design supporting both Dark and Light themes.

---

## 🏛️ Architecture

```mermaid
flowchart LR
    subgraph Client["Flutter Client (Web & Mobile)"]
        UI["UI Layer (Material 3)"]
        Router["GoRouter"]
        State["Riverpod State Management"]
        Player["Video Player Engine"]
        UI --> State
        State --> Router
        State --> Player
    end

    subgraph Backend["Supabase Platform"]
        Auth["Supabase Auth"]
        DB[("PostgreSQL Database (RLS)")]
        Storage["Storage ('thumbnails' Bucket)"]
        Edge["Edge Functions"]
        State --> Auth
        State --> DB
        State --> Storage
        State --> Edge
    end

    subgraph CDN["Bunny.net Stream"]
        BunnyAPI["Bunny Video API"]
        TUS["TUS Chunked Uploads"]
        HLS["HLS CDN Playback"]
        Edge -->|API Management| BunnyAPI
        Player -->|Direct Upload| TUS
        HLS -->|Streaming| Player
    end
```

---

## 🧪 Testing

The codebase includes comprehensive unit and widget test coverage:

```bash
# Run static analysis
flutter analyze

# Run all automated tests
flutter test
```

**Test suite highlights (63 tests passing):**
- App startup and routing resilience (`widget_test.dart`)
- First-time installation and owner setup flow (`owner_setup_widget_test.dart`)
- Continue Watching resume calculation (`continue_watching_resume_test.dart`)
- Bunny TUS upload session serialization (`bunny_upload_session_test.dart`)
- Safe type parsing and database error handling (`safe_type_parsers_test.dart`)
- Playback source URL resolution (`playback_source_resolver_test.dart`)
- Light/Dark theme switching (`theme_provider_test.dart`)

---

## 🚀 Getting Started

### 1. Prerequisites
- **Flutter SDK**: 3.24+ (Dart 3.5+)
- **Supabase Account**: (Free cloud project or self-hosted)

### 2. Clone & Install Dependencies
```bash
git clone https://github.com/oscarboyq/Ott.git
cd Ott
flutter pub get
```

### 3. Configure Supabase
Copy the configuration template:
```bash
cp config/supabase.example.json config/supabase.json
```

Add your Supabase credentials in `config/supabase.json`:
```json
{
  "supabaseUrl": "https://your-project.supabase.co",
  "supabaseAnonKey": "your-anon-key"
}
```

### 4. Database Setup
Run the SQL script located at `assets/complete_database_setup.sql` in your Supabase SQL Editor to create tables, indexes, and Row Level Security policies.

### 5. Run the Application
```bash
# Run on Chrome (Web)
flutter run -d chrome

# Run on Android Device / Emulator
flutter run
```

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
