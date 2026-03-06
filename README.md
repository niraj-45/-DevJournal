# DevJournal

A Flutter time-tracking app for developers — log sessions, track mood, generate standups, and manage multiple workspaces.

Built with Flutter + Riverpod + Supabase.

---

## Getting Started

### 1. Clone the repo

```bash
git clone https://github.com/YOUR_USERNAME/devjournal.git
cd devjournal/devjournal_app
```

### 2. Set up credentials

This project keeps Supabase credentials out of version control.

```bash
cp lib/core/config/env.example.dart lib/core/config/env.dart
```

Open `lib/core/config/env.dart` and fill in your Supabase project values:

```dart
class Env {
  static const supabaseUrl = 'https://YOUR_PROJECT.supabase.co';
  static const supabaseAnonKey = 'YOUR_ANON_KEY';
}
```

> Find these in your Supabase dashboard → **Settings → API**.

### 3. Install dependencies

```bash
flutter pub get
```

### 4. Run the app

```bash
flutter run
```

---

## Environment & Secrets

| File | Committed? | Purpose |
|------|-----------|---------|
| `lib/core/config/env.dart` | ❌ gitignored | Your real Supabase credentials |
| `lib/core/config/env.example.dart` | ✅ | Template — copy to `env.dart` |

**Never commit `env.dart`.**

---

## Supabase Setup

You'll need the following RLS policies on your Supabase project:

```sql
-- Sessions: read, insert, update, delete own rows
CREATE POLICY "Users can read own sessions"   ON sessions FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own sessions" ON sessions FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own sessions" ON sessions FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete own sessions" ON sessions FOR DELETE USING (auth.uid() = user_id);

-- mood_logs: delete via session ownership
CREATE POLICY "Users can delete own mood_logs" ON mood_logs FOR DELETE
  USING (session_id IN (SELECT id FROM sessions WHERE user_id = auth.uid()));

-- notes column (if not already present)
ALTER TABLE sessions ADD COLUMN IF NOT EXISTS notes text;
```

---

## Features

- Live session timer with ticket + subtask fields
- Manual session creation with time pickers
- Edit and delete sessions (swipe or tap)
- Daily standup generator from logged sessions
- Mood tracking per session
- Multiple workspaces with invite support
- Work-hours bar overlay with out-of-hours warning

## Tech Stack

- **Flutter** — UI
- **Riverpod** — state management
- **Supabase** — backend (auth, database)
- **go_router** — navigation
- **SharedPreferences** — local persistence
