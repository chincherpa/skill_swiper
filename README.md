# Skill Swiper

A Flutter app for local and global skill exchange — **"Skill-Tinder"**.

Discover people nearby who can teach you something, and share your own knowledge in return. No money, just knowledge for knowledge.

## Concept

- **Swipe, don't search** — A feed shows nearby users with their offered skills
- **Local & Remote** — Meet people in your area or connect globally for remote skills
- **Barter economy** — Knowledge is exchanged, not sold
- **Match & Chat** — Mutual interest? Real-time chat to organize the skill exchange

## Screenshots

*Coming soon*

## Tech Stack

| Component | Technology |
|---|---|
| Frontend | Flutter (Dart) |
| Backend | Supabase |
| Auth | Supabase Auth (Email + Google OAuth) |
| Database | PostgreSQL + PostGIS |
| Real-time Chat | Supabase Realtime |
| Image Storage | Supabase Storage |
| State Management | Riverpod |
| Routing | GoRouter |
| Security | Row Level Security (RLS) |

## Project Structure

```
lib/
├── core/
│   ├── constants/       # Supabase configuration
│   ├── router/          # GoRouter setup, Splash Screen
│   └── theme/           # Colors, App Theme (Material Design 3)
├── features/
│   ├── auth/            # Login, Registration, Profile Setup
│   ├── chat/            # Real-time chat between matches
│   ├── matches/         # Match overview
│   ├── profile/         # View/edit own profile
│   └── swipe/           # Swipe feed with profile cards
├── models/              # Data models (Profile, Skill, Match, Message)
├── services/            # Supabase service layer
├── widgets/             # Shared widgets (Shell Scaffold)
└── main.dart
```

## Features

- **Swipe Feed** — Profile cards with skill chips, distance display, swipe gestures
- **Match System** — Automatic match on mutual interest (via Postgres function)
- **Real-time Chat** — Messages via Supabase Realtime
- **Location-based** — GPS or manual input, adjustable radius (5–50 km)
- **Profile Management** — Profile picture, bio, add/edit skills
- **Auth** — Email/Password + Google OAuth

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) >= 3.6.0
- A [Supabase](https://supabase.com) project with:
  - PostGIS extension enabled
  - Tables: `profiles`, `skills`, `user_skills`, `swipes`, `matches`, `messages`
  - Row Level Security policies configured
  - Storage bucket `avatars` created

## Setup

1. **Clone the repository**
   ```bash
   git clone <repo-url>
   cd flutter_application_1
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Supabase**

   Add your Supabase URL and anon key in `lib/core/constants/supabase_constants.dart`.

4. **Run code generation** (for Riverpod)
   ```bash
   dart run build_runner build
   ```

5. **Start the app**
   ```bash
   flutter run
   ```

## Data Model

```
profiles ──< user_skills >── skills
    │
    ├──< swipes
    │
    ├──< matches
    │       │
    │       └──< messages
```

- **profiles** — User data with GPS location (PostGIS)
- **skills** — Global skill catalog with categories
- **user_skills** — User ↔ Skill link with description
- **swipes** — Swipe actions (left/right)
- **matches** — Automatically created on mutual right-swipe
- **messages** — Chat messages within a match

## License

This project is not publicly licensed.
