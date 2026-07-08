# quota

Flutter client for the quotes-v2 backend (`../backend`).

Ported from the original Supabase-backed app: auth is now JWT + refresh
tokens against the Rust API, with sessions persisted locally.

## Running

```bash
flutter pub get
flutter run                # uses https://quote-db.qinnovate.nz
flutter run --dart-define=API_BASE_URL=http://localhost:8080   # local backend
```

Note for the Android emulator: use `http://10.0.2.2:8080` to reach a backend
on the host machine. Debug builds allow cleartext (plain http) traffic;
release builds require https.

## Features

- Email/password sign up, sign in, forgot-password (email reset link)
- Quote books: create, rename, delete; owned books sort first
- Quotes: list, fuzzy search, add, delete (book owner or quote author)
- Sharing: add members by email; if they have no account yet an email
  invite is sent, and pending invites can be revoked from book settings
