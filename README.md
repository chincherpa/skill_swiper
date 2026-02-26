# Skill Swiper

Eine Flutter-App für den lokalen und globalen Tausch von Fähigkeiten — **"Skill-Tinder"**.

Menschen in der Umgebung entdecken, die etwas beibringen können, und im Gegenzug eigenes Wissen teilen. Kein Geld, nur Wissen gegen Wissen.

## Konzept

- **Swipen statt Suchen** — Ein Feed zeigt Nutzer im Umkreis mit ihren angebotenen Skills
- **Lokal & Remote** — Treffe Leute in deiner Nähe oder vernetze dich global für Remote-Skills
- **Tauschwirtschaft** — Wissen wird getauscht, nicht verkauft
- **Match & Chat** — Gegenseitiges Interesse? Echtzeit-Chat zum Organisieren des Skill-Tauschs

## Screenshots

*Coming soon*

## Tech-Stack

| Komponente | Technologie |
|---|---|
| Frontend | Flutter (Dart) |
| Backend | Supabase |
| Auth | Supabase Auth (Email + Google OAuth) |
| Datenbank | PostgreSQL + PostGIS |
| Echtzeit-Chat | Supabase Realtime |
| Bild-Storage | Supabase Storage |
| State Management | Riverpod |
| Routing | GoRouter |
| Sicherheit | Row Level Security (RLS) |

## Projektstruktur

```
lib/
├── core/
│   ├── constants/       # Supabase-Konfiguration
│   ├── router/          # GoRouter-Setup, Splash Screen
│   └── theme/           # Farben, App-Theme (Material Design 3)
├── features/
│   ├── auth/            # Login, Registrierung, Profil-Setup
│   ├── chat/            # Echtzeit-Chat zwischen Matches
│   ├── matches/         # Match-Übersicht
│   ├── profile/         # Eigenes Profil anzeigen/bearbeiten
│   └── swipe/           # Swipe-Feed mit Profilkarten
├── models/              # Datenmodelle (Profile, Skill, Match, Message)
├── services/            # Supabase-Service-Layer
├── widgets/             # Gemeinsame Widgets (Shell-Scaffold)
└── main.dart
```

## Features

- **Swipe-Feed** — Profilkarten mit Skills als Chips, Entfernungsanzeige, Swipe-Gesten
- **Match-System** — Automatisches Match bei gegenseitigem Interesse (via Postgres-Funktion)
- **Echtzeit-Chat** — Nachrichten über Supabase Realtime
- **Standort-basiert** — GPS oder manuelle Eingabe, einstellbarer Umkreis (5–50 km)
- **Profilverwaltung** — Profilbild, Bio, Skills hinzufügen/bearbeiten
- **Auth** — Email/Passwort + Google OAuth

## Voraussetzungen

- [Flutter SDK](https://docs.flutter.dev/get-started/install) >= 3.6.0
- Ein [Supabase](https://supabase.com)-Projekt mit:
  - PostGIS Extension aktiviert
  - Tabellen: `profiles`, `skills`, `user_skills`, `swipes`, `matches`, `messages`
  - Row Level Security Policies konfiguriert
  - Storage Bucket `avatars` angelegt

## Setup

1. **Repository klonen**
   ```bash
   git clone <repo-url>
   cd flutter_application_1
   ```

2. **Dependencies installieren**
   ```bash
   flutter pub get
   ```

3. **Supabase konfigurieren**

   Die Supabase-URL und den Anon-Key in `lib/core/constants/supabase_constants.dart` eintragen.

4. **Code-Generierung ausführen** (für Riverpod)
   ```bash
   dart run build_runner build
   ```

5. **App starten**
   ```bash
   flutter run
   ```

## Datenmodell

```
profiles ──< user_skills >── skills
    │
    ├──< swipes
    │
    ├──< matches
    │       │
    │       └──< messages
```

- **profiles** — Nutzerdaten mit GPS-Standort (PostGIS)
- **skills** — Globaler Skill-Katalog mit Kategorien
- **user_skills** — Verknüpfung Nutzer ↔ Skill mit Beschreibung
- **swipes** — Swipe-Aktionen (links/rechts)
- **matches** — Automatisch erstellt bei gegenseitigem Right-Swipe
- **messages** — Chat-Nachrichten innerhalb eines Matches

## Lizenz

Dieses Projekt ist nicht öffentlich lizenziert.
