# Skill Swiper - Design Dokument

**Datum:** 2026-02-24
**Typ:** Android App (Flutter + Supabase)
**Konzept:** Globale und lokale Tauschwirtschaft für Fähigkeiten — "Skill-Tinder"

---

## 1. Vision & Kernkonzept

Skill Swiper bringt Menschen in der direkten Umgebung zusammen, die voneinander lernen wollen. Nutzer bieten Fähigkeiten an ("Ich zeige dir in 2h die React-Basics") und entdecken durch Swipen, was andere Menschen in ihrer Nähe beibringen können.

**Kernprinzipien:**
- **Entdecken statt Suchen:** Der Feed zeigt alle Nutzer im Umkreis — ungefiltert. Man entdeckt Skills, von denen man nicht wusste, dass man sie lernen will.
- **Global, lokal & persönlich:** Nur Menschen in der Nähe werden angezeigt, ausser man wählt für seinen Skill 'remote' aus, dann werden auch Menschen angezeigt, die ebenfalls Skills mit Status 'remote' haben. Ziel ist die echte Begegnung, nicht nur digitaler Kontakt.
- **Tauschwirtschaft ohne Geld:** Wissen wird getauscht, nicht verkauft.
- **Einfachheit:** Nutzer geben nur an, was sie anbieten — kein kompliziertes Matching-Setup.

---

## 2. Zielgruppe

- Menschen, die neue Fähigkeiten lernen wollen, ohne Geld auszugeben
- Menschen, die ihr Wissen gerne teilen und andere Leute kennenlernen wollen
- Studenten, Berufstätige, Hobbyisten — jeder, der etwas kann und etwas Neues entdecken will
- Lokal verankert: funktioniert am besten in Städten und dicht besiedelten Gebieten
- aber auch globale Vernetzung. Skills können auch remote beigebracht werden

---

## 3. Tech-Stack

| Komponente       | Technologie                        |
|------------------|------------------------------------|
| Frontend         | Flutter (Dart)                     |
| Backend          | Supabase                           |
| Auth             | Supabase Auth (Email + Google)     |
| Datenbank        | PostgreSQL (via Supabase)          |
| Geo-Queries      | PostGIS Extension                  |
| Echtzeit-Chat    | Supabase Realtime                  |
| Bild-Storage     | Supabase Storage                   |
| Sicherheit       | Row Level Security (RLS)           |

---

## 4. Datenmodell

### 4.1 `profiles`

Erweitert die Supabase `auth.users` Tabelle mit App-spezifischen Daten.

| Spalte       | Typ                  | Beschreibung                                      |
|--------------|----------------------|---------------------------------------------------|
| id           | UUID (PK, FK)        | Referenz auf `auth.users.id`                      |
| name         | TEXT (NOT NULL)       | Anzeigename des Nutzers                           |
| bio          | TEXT                 | Kurze Selbstbeschreibung (max. 300 Zeichen)       |
| avatar_url   | TEXT                 | URL zum Profilbild in Supabase Storage             |
| location     | GEOGRAPHY(POINT)     | GPS-Koordinaten des Nutzers (PostGIS)             |
| radius_km    | INTEGER (DEFAULT 10) | Maximaler Umkreis für den Swipe-Feed in km        |
| created_at   | TIMESTAMPTZ          | Erstellungszeitpunkt                              |
| updated_at   | TIMESTAMPTZ          | Letztes Update                                    |

**Hinweise:**
- `location` wird als PostGIS `geography(Point, 4326)` gespeichert (WGS84-Koordinatensystem)
- Der Nutzer kann den Standort per GPS freigeben oder manuell eine Stadt/PLZ eingeben
- `radius_km` ist einstellbar im Profil (Optionen: 5, 10, 25, 50 km)

### 4.2 `skills`

Globaler Katalog aller verfügbaren Skills. Wird initial mit Kategorien befüllt und wächst mit der Community.

| Spalte    | Typ               | Beschreibung                              |
|-----------|--------------------|-------------------------------------------|
| id        | UUID (PK)          | Eindeutige ID                             |
| name      | TEXT (UNIQUE)      | Skill-Name (z.B. "React", "Gitarre")     |
| category  | TEXT               | Kategorie (z.B. "Programmierung", "Musik")|
| created_at| TIMESTAMPTZ        | Erstellungszeitpunkt                      |

**Kategorien (initial):**
- Programmierung & Tech
- Sprachen
- Musik & Kunst
- Handwerk & DIY
- Sport & Fitness
- Kochen & Ernährung
- Business & Finanzen
- Sonstiges

### 4.3 `user_skills`

Verknüpft Nutzer mit ihren angebotenen Skills. Jeder Eintrag enthält eine konkrete Beschreibung, was der Nutzer beibringen kann.

| Spalte      | Typ          | Beschreibung                                                |
|-------------|--------------|-------------------------------------------------------------|
| id          | UUID (PK)    | Eindeutige ID                                               |
| user_id     | UUID (FK)    | Referenz auf `profiles.id`                                  |
| skill_id    | UUID (FK)    | Referenz auf `skills.id`                                    |
| description | TEXT         | Konkrete Beschreibung ("Zeige dir in 2h die React-Basics")  |
| created_at  | TIMESTAMPTZ  | Erstellungszeitpunkt                                        |

**Constraints:**
- UNIQUE auf `(user_id, skill_id)` — ein Nutzer kann jeden Skill nur einmal anbieten
- `description` ist Pflichtfeld — das macht die Karte interessant

### 4.4 `swipes`

Speichert jede Swipe-Aktion eines Nutzers.

| Spalte     | Typ          | Beschreibung                                    |
|------------|--------------|-------------------------------------------------|
| id         | UUID (PK)    | Eindeutige ID                                   |
| swiper_id  | UUID (FK)    | Wer hat geswiped (Referenz auf `profiles.id`)   |
| swiped_id  | UUID (FK)    | Wer wurde geswiped (Referenz auf `profiles.id`) |
| direction  | TEXT         | `right` (Interesse) oder `left` (Weiter)        |
| created_at | TIMESTAMPTZ  | Zeitpunkt des Swipes                            |

**Constraints:**
- UNIQUE auf `(swiper_id, swiped_id)` — jede Kombination nur einmal
- CHECK: `direction IN ('right', 'left')`
- CHECK: `swiper_id != swiped_id` — man kann sich nicht selbst swipen

### 4.5 `matches`

Wird automatisch erstellt, wenn beide Nutzer sich gegenseitig nach rechts geswiped haben.

| Spalte     | Typ          | Beschreibung                                  |
|------------|--------------|-----------------------------------------------|
| id         | UUID (PK)    | Eindeutige ID                                 |
| user_a     | UUID (FK)    | Erster Nutzer (Referenz auf `profiles.id`)    |
| user_b     | UUID (FK)    | Zweiter Nutzer (Referenz auf `profiles.id`)   |
| created_at | TIMESTAMPTZ  | Zeitpunkt des Matches                         |

**Constraints:**
- UNIQUE auf `(user_a, user_b)` mit Konvention: `user_a < user_b` (verhindert Duplikate)
- Match-Erstellung erfolgt über eine **Postgres-Funktion** die bei jedem Right-Swipe prüft, ob der andere Nutzer bereits nach rechts geswiped hat

**Postgres-Funktion `handle_swipe`:**
```sql
-- Wird als Database Function in Supabase angelegt
-- Aufgerufen nach jedem INSERT in swipes mit direction = 'right'
-- Prüft ob gegenseitiger Swipe existiert
-- Falls ja: INSERT in matches + Rückgabe match_id
-- Falls nein: Rückgabe null
```

### 4.6 `messages`

Chat-Nachrichten zwischen gematchten Nutzern.

| Spalte     | Typ          | Beschreibung                                  |
|------------|--------------|-----------------------------------------------|
| id         | UUID (PK)    | Eindeutige ID                                  |
| match_id   | UUID (FK)    | Referenz auf `matches.id`                      |
| sender_id  | UUID (FK)    | Wer hat die Nachricht gesendet                 |
| content    | TEXT         | Nachrichteninhalt                              |
| created_at | TIMESTAMPTZ  | Zeitpunkt der Nachricht                        |

**Constraints:**
- `sender_id` muss `user_a` oder `user_b` des referenzierten Matches sein
- Nachrichten werden über **Supabase Realtime** live an den Chat-Partner gepusht

---

## 5. Screens & User Flow

### 5.1 Splash Screen

- App-Logo "Skill Swiper" mit kurzer Animation
- Automatischer Auth-Check: Ist der Nutzer eingeloggt?
  - **Ja** → Weiter zum Swipe-Screen
  - **Nein** → Weiter zum Login-Screen

### 5.2 Login / Register Screen

**Login-Optionen:**
- Email + Passwort
- "Mit Google anmelden" Button (Supabase Google OAuth)
- Link: "Noch kein Konto? Registrieren"

**Registrierung:**
- Email + Passwort eingeben
- Email-Bestätigung via Supabase (Magic Link oder Code)
- Nach erfolgreicher Registrierung → Weiter zum Profil-Setup

**Fehlerbehandlung:**
- Ungültige Email → Inline-Fehlermeldung unter dem Feld
- Passwort zu kurz (< 8 Zeichen) → Inline-Fehlermeldung
- Email bereits registriert → Hinweis mit Link zum Login
- Netzwerkfehler → Snackbar "Keine Internetverbindung"

### 5.3 Profil-Setup (Onboarding)

Wird nur beim ersten Login nach Registrierung angezeigt. Mehrstufiger Flow:

**Schritt 1: Persönliche Infos**
- Name eingeben (Pflichtfeld, max. 50 Zeichen)
- Bio eingeben (optional, max. 300 Zeichen, Placeholder: "Erzähl etwas über dich...")
- Profilbild hochladen (optional, Kamera oder Galerie, wird in Supabase Storage gespeichert, max. 5 MB, wird auf 400x400px komprimiert)

**Schritt 2: Standort**
- Button: "Standort freigeben" (GPS-Permission-Request)
- Alternative: Stadt/PLZ manuell eingeben (Geocoding zu Koordinaten)
- Umkreis einstellen: Slider oder Auswahl (5 / 10 / 25 / 50 km)
- Kartenvorschau zeigt den gewählten Umkreis

**Schritt 3: Skills anbieten**
- Überschrift: "Was kannst du anderen beibringen?"
- Skill auswählen aus Kategorien (durchsuchbare Liste)
- Zu jedem Skill eine Beschreibung eingeben (Pflicht)
  - Placeholder: "z.B. Zeige dir in 2 Stunden die Basics..."
  - Max. 200 Zeichen
- Mindestens 1 Skill muss angelegt werden
- Maximal 10 Skills
- Button: "Weiteren Skill hinzufügen"
- Vorschau: Wie die eigene Swipe-Karte für andere aussieht

**Abschluss:**
- "Los geht's!" Button → Weiter zum Swipe-Screen

### 5.4 Swipe-Screen (Hauptscreen)

Der zentrale Screen der App. Zeigt Profilkarten als Stack an.

**Karten-Design:**
- Großes Profilbild (obere 60% der Karte)
- Name + Entfernung ("Max, ~3 km")
- Bio (2 Zeilen, abgeschnitten mit "...")
- Liste der angebotenen Skills als Chips/Tags
- Beim Antippen eines Skill-Chips: Beschreibung wird eingeblendet

**Swipe-Interaktion:**
- **Rechts swipen** (oder grüner Button) → Interesse
- **Links swipen** (oder roter Button) → Weiter / Kein Interesse
- Karte dreht sich leicht in Swipe-Richtung mit visueller Rückmeldung:
  - Grüner Overlay + Häkchen bei rechts
  - Roter Overlay + X bei links
- Smooth Animation: Karte fliegt raus, nächste Karte rutscht nach

**Feed-Logik:**
- Zeigt alle Nutzer im eingestellten Umkreis
- Sortiert nach Entfernung (nähste zuerst)
- Bereits geswipte Nutzer werden ausgeschlossen
- Eigenes Profil wird nicht angezeigt
- Wenn keine Karten mehr → "Keine neuen Leute in deiner Nähe. Versuch einen größeren Umkreis!"

**Match-Popup:**
- Erscheint sofort wenn ein gegenseitiger Right-Swipe erkannt wird
- "It's a Match!" mit beiden Profilbildern nebeneinander
- Zwei Buttons:
  - "Nachricht senden" → Öffnet Chat mit diesem Match
  - "Weiter swipen" → Schließt Popup, zurück zum Feed

**Supabase Query für den Feed:**
```sql
SELECT p.*,
       ST_Distance(p.location, my_location) as distance,
       array_agg(json_build_object('name', s.name, 'description', us.description)) as skills
FROM profiles p
JOIN user_skills us ON us.user_id = p.id
JOIN skills s ON s.id = us.skill_id
WHERE p.id != current_user_id
  AND p.id NOT IN (SELECT swiped_id FROM swipes WHERE swiper_id = current_user_id)
  AND ST_DWithin(p.location, my_location, radius_in_meters)
GROUP BY p.id
ORDER BY distance ASC
LIMIT 20;
```

### 5.5 Matches-Tab

Liste aller aktiven Matches, aufgeteilt in zwei Bereiche:

**Bereich 1: Neue Matches (horizontal scrollbar)**
- Horizontale Reihe mit runden Profilbildern
- Nur Matches ohne bisherige Nachrichten
- Antippen → Öffnet Chat

**Bereich 2: Chats (vertikale Liste)**
- Matches mit mindestens einer Nachricht
- Sortiert nach letzter Nachricht (neueste oben)
- Jeder Eintrag zeigt:
  - Profilbild (rund)
  - Name
  - Letzte Nachricht (abgeschnitten) + Zeitstempel
  - Ungelesene-Nachrichten-Badge (Zahl)
- Antippen → Öffnet Chat

**Leerer Zustand:**
- "Noch keine Matches. Swipe weiter, um Leute zu entdecken!"

### 5.6 Chat-Screen

Echtzeit-Chat zwischen zwei gematchten Nutzern.

**Layout:**
- Header: Profilbild + Name des Chat-Partners (antippen → Profil ansehen)
- Nachrichtenverlauf: Klassische Chat-Bubbles
  - Eigene Nachrichten: rechts, farbig (Primärfarbe)
  - Partner-Nachrichten: links, grau
  - Zeitstempel unter jeder Nachricht (oder gruppiert nach Tag)
- Input-Bereich: Textfeld + Senden-Button

**Funktionalität:**
- Nachrichten werden über Supabase Realtime live empfangen
- Beim Öffnen des Chats: Lade letzte 50 Nachrichten, bei Hochscrollen weitere nachladen (Pagination)
- Senden-Button ist deaktiviert bei leerem Textfeld
- Neue Nachrichten scrollen automatisch nach unten
- Nachrichten werden mit `created_at` Timestamp gespeichert und chronologisch angezeigt

**Echtzeit-Implementierung:**
- Supabase Realtime Subscription auf `messages` Tabelle
- Filter: `match_id = current_match_id`
- Bei neuer Nachricht: sofort in der UI anzeigen
- Bei Verbindungsverlust: Reconnect-Logik mit Nachlade der verpassten Nachrichten

### 5.7 Profil-Screen (eigenes Profil)

**Ansicht:**
- Profilbild (groß, mit Bearbeiten-Icon)
- Name + Bio
- Standort (Stadt/Bereich, nicht exakte Koordinaten) + Umkreis-Einstellung
- Liste der eigenen Skills mit Beschreibungen
- "Profil bearbeiten" Button
- "Abmelden" Button

**Bearbeiten-Modus:**
- Alle Felder aus dem Profil-Setup sind editierbar
- Skills können hinzugefügt, bearbeitet und gelöscht werden
- Änderungen werden mit "Speichern" Button übernommen
- Profilbild kann geändert oder entfernt werden

---

## 6. Navigation

**Bottom Navigation Bar** mit 3 Tabs:

| Position | Tab      | Icon             | Screen          |
|----------|----------|------------------|-----------------|
| Links    | Profil   | Person-Icon      | Profil-Screen   |
| Mitte    | Swipe    | Flammen/Card-Icon| Swipe-Screen    |
| Rechts   | Matches  | Chat-Bubble-Icon | Matches-Tab     |

- Aktiver Tab ist farblich hervorgehoben (Primärfarbe)
- Matches-Tab zeigt Badge mit Anzahl neuer Matches / ungelesener Nachrichten
- Swipe-Tab ist beim App-Start aktiv (Hauptscreen)

---

## 7. Row Level Security (RLS)

Jede Tabelle bekommt RLS-Policies, damit Nutzer nur auf erlaubte Daten zugreifen können.

**`profiles`:**
- SELECT: Jeder authentifizierte Nutzer kann alle Profile lesen (für den Swipe-Feed)
- UPDATE: Nur das eigene Profil bearbeiten (`auth.uid() = id`)
- INSERT: Nur für die eigene ID (`auth.uid() = id`)

**`user_skills`:**
- SELECT: Alle authentifizierten Nutzer (für Swipe-Karten)
- INSERT/UPDATE/DELETE: Nur eigene Skills (`auth.uid() = user_id`)

**`swipes`:**
- INSERT: Nur eigene Swipes (`auth.uid() = swiper_id`)
- SELECT: Nur eigene Swipes (`auth.uid() = swiper_id`)

**`matches`:**
- SELECT: Nur Matches an denen man beteiligt ist (`auth.uid() IN (user_a, user_b)`)
- INSERT: Nur via Database Function (nicht direkt durch den Client)

**`messages`:**
- SELECT: Nur Nachrichten aus eigenen Matches
- INSERT: Nur in eigene Matches senden, nur als eigene `sender_id`

---

## 8. Supabase Storage

**Bucket: `avatars`**
- Öffentlich lesbar (für Swipe-Karten)
- Upload nur für authentifizierte Nutzer
- Pfadstruktur: `avatars/{user_id}/profile.jpg`
- Max. Dateigröße: 5 MB
- Erlaubte Formate: JPG, PNG, WebP
- Client-seitig auf 400x400px komprimiert vor Upload

---

## 9. Farben & Design-Sprache

**Farbpalette (Vorschlag):**
- Primärfarbe: Leuchtendes Türkis/Teal (#00BFA6) — frisch, modern, einladend
- Sekundärfarbe: Warmgrau (#F5F5F5) für Hintergründe
- Akzent: Korall (#FF6B6B) für den "Nein"-Swipe
- Grün: (#4CAF50) für den "Ja"-Swipe
- Text: Dunkelgrau (#212121) auf hellem Hintergrund

**Design-Prinzipien:**
- Material Design 3 als Basis
- Abgerundete Ecken (16px Radius) für Karten und Buttons
- Große, gut lesbare Typografie
- Viel Whitespace — die App soll sich leicht und einladend anfühlen
- Profilbilder immer rund (in Listen) oder abgerundet (auf Karten)

---

## 10. Nicht im MVP (spätere Features)

Folgende Features werden bewusst **nicht** in der ersten Version gebaut:

- Push-Benachrichtigungen (neue Matches, neue Nachrichten)
- Bilder im Chat senden
- Profil verifizierung
- Bewertungssystem nach einem Skill-Tausch
- Blockieren / Melden von Nutzern
- Skills vorschlagen (wenn ein Skill nicht im Katalog ist)
- Dark Mode
- Onboarding-Tutorial / App-Tour
