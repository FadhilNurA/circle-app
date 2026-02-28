# Circle

**Social bill-splitting & music sharing app** built with Flutter and Next.js, integrating Spotify, Supabase, and Google Gemini AI.

---

## Features

### Bill Splitting
- Create and manage group bills
- **AI Receipt Scanner** — snap a receipt photo, Gemini AI extracts all items automatically
- Assign items to members and split costs fairly
- Track payment status per person (pending, approved, rejected)

### Real-time Lyrics Sync
- Create a **music room** and share your Spotify playback in real-time
- Synced lyrics display via Musixmatch integration
- Multiple listeners can join the same room with a 6-character code
- Auto-scrolling lyrics with sync offset controls

### Social
- Add friends and manage friend requests
- Create groups for splitting bills together
- User profiles with avatar and activity history

---

## Project Structure

```
Circle/
├── backend/                  # Next.js API + Socket.IO server
│   ├── server.ts             # Custom HTTP server (Next.js + Socket.IO)
│   ├── src/
│   │   ├── app/api/          # REST API routes
│   │   │   ├── auth/         # Authentication endpoints
│   │   │   ├── bills/        # Bill CRUD endpoints
│   │   │   ├── friends/      # Friend management
│   │   │   ├── groups/       # Group management
│   │   │   ├── lyrics/       # Lyrics room REST endpoint
│   │   │   └── scan-receipt/ # Gemini AI receipt scanning
│   │   ├── socket/
│   │   │   ├── handler.ts         # Socket.IO event handlers
│   │   │   ├── spotify-service.ts # Spotify API integration
│   │   │   └── lyrics-service.ts  # Musixmatch lyrics fetcher
│   │   └── lib/
│   │       └── supabase.ts        # Supabase client
│   └── .env.local            # Environment variables
│
├── circle_app/               # Flutter mobile/web application
│   ├── lib/
│   │   ├── main.dart
│   │   ├── config/
│   │   │   ├── api_config.dart    # API base URL config
│   │   │   └── theme.dart         # Design system (colors, theme, widgets)
│   │   ├── models/                # Data models
│   │   ├── screens/               # All UI screens (13 screens)
│   │   └── services/              # API and Socket services
│   └── pubspec.yaml
│
└── database/
    ├── schema.sql             # Full database schema
    └── schema_simple.sql      # Simplified schema
```

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.x or later)
- [Node.js](https://nodejs.org/) (18.x or later)
- [Supabase Account](https://supabase.com/)
- [Spotify Developer Account](https://developer.spotify.com/dashboard) (for lyrics feature)
- [Google AI Studio](https://aistudio.google.com/) (for receipt scanning)
- [Musixmatch API Key](https://developer.musixmatch.com/) (for lyrics)

### 1. Clone the Repository

```bash
git clone <your-repo-url>
cd Circle
```

### 2. Backend Setup

```bash
cd backend
npm install
```

Create `.env.local` with your credentials:

```env
# Supabase
SUPABASE_URL=your_supabase_project_url
SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key

# Spotify (for lyrics sync)
SPOTIFY_CLIENT_ID=your_spotify_client_id
SPOTIFY_CLIENT_SECRET=your_spotify_client_secret

# Gemini AI (for receipt scanning)
GEMINI_API_KEY=your_gemini_api_key

# Musixmatch (for lyrics)
MUSIXMATCH_API_KEY=your_musixmatch_api_key
```

Start the development server:

```bash
npm run dev
```

The server starts on `http://localhost:3000` with both REST API and Socket.IO enabled.

### 3. Flutter App Setup

```bash
cd circle_app
flutter pub get
flutter run -d chrome    # Run on web
```

Update `lib/config/api_config.dart` if the backend URL differs.

---

## API Endpoints

### Authentication

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/register` | Register a new user |
| POST | `/api/auth/login` | Login with email and password |
| GET | `/api/auth/me` | Get current user profile |

### Groups

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/groups` | List user groups |
| POST | `/api/groups` | Create a new group |
| GET | `/api/groups/:id` | Get group details |

### Bills

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/bills?group_id=xxx` | List bills in a group |
| POST | `/api/bills` | Create a new bill |
| GET | `/api/bills/:id` | Get bill details |
| PATCH | `/api/bills/:id/splits` | Approve or reject a split |

### Friends

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/friends` | List friends |
| POST | `/api/friends/request` | Send friend request |
| PATCH | `/api/friends/:id` | Accept or reject request |

### AI Receipt Scanner

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/scan-receipt` | Upload receipt image, AI extracts items |

### Socket.IO Events

| Event | Direction | Description |
|-------|-----------|-------------|
| `create_room` | Client to Server | Host creates a lyrics room |
| `join_room` | Client to Server | Listener joins a room |
| `leave_room` | Client to Server | Leave current room |
| `room_created` | Server to Client | Room ID returned to host |
| `room_joined` | Server to Client | Room state sent to new member |
| `track_changed` | Server to Client | New track and lyrics broadcast |
| `playback_update` | Server to Client | Progress sync every 2.5s |
| `member_count` | Server to Client | Updated listener count |
| `room_closed` | Server to Client | Host left, room destroyed |
| `error_event` | Server to Client | Error message |

---

## Design System

The app uses a **unified dark theme** defined in `lib/config/theme.dart`:

| Token | Color | Usage |
|-------|-------|-------|
| `primary` | `#7C3AED` | Buttons, accents, active states |
| `accent` | `#06B6D4` | Secondary actions, cyan highlights |
| `background` | `#0F0F1A` | Scaffold background |
| `surface` | `#1A1A2E` | Cards, bottom sheets |
| `surfaceLight` | `#252542` | Input fields, elevated surfaces |
| `textPrimary` | `#F1F1F6` | Headings, primary text |
| `textSecondary` | `#9CA3AF` | Subtitles, descriptions |
| `textMuted` | `#6B7280` | Hints, disabled text |

### Custom Widgets

- **GradientButton** - Primary CTA with purple-to-cyan gradient and shadow
- **GlassCard** - Glass-morphism card with border and dark surface

---

## Screens

| Screen | File | Description |
|--------|------|-------------|
| Login | `login_screen.dart` | Email/password auth |
| Register | `register_screen.dart` | Create new account |
| Home | `home_screen.dart` | Navigation hub (4 tabs) |
| Groups | `groups_screen.dart` | List of user groups |
| Friends | `friends_screen.dart` | Friends and requests (TabBar) |
| Profile | `profile_screen.dart` | User profile and settings |
| Create Group | `create_group_screen.dart` | New group form |
| Group Detail | `group_detail_screen.dart` | Bills, members, settings |
| Scan Bill | `scan_bill_screen.dart` | AI receipt scanner and split |
| Bill Detail | `bill_detail_screen.dart` | Bill items and payment status |
| Create Bill | `create_bill_screen.dart` | Manual bill creation |
| Join Room | `join_room_screen.dart` | Create/join lyrics room |
| Lyrics | `lyrics_screen.dart` | Synced lyrics display |

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter (Dart 3.9), Material 3 |
| Backend | Next.js 16, TypeScript |
| Real-time | Socket.IO 4 |
| Database | Supabase (PostgreSQL) |
| AI | Google Gemini 2.0 Flash Lite |
| Music | Spotify Web API, Musixmatch API |
| Auth | Supabase Auth |

### Flutter Dependencies

- `http` - REST API calls
- `flutter_secure_storage` - Secure token storage
- `shared_preferences` - Local preferences
- `image_picker` - Camera/gallery access
- `http_parser` - Multipart file uploads
- `socket_io_client` - Real-time Socket.IO
- `url_launcher` - External URL handling
- `google_mlkit_text_recognition` - On-device OCR (fallback)

---

## Environment Variables

### Backend (.env.local)

| Variable | Required | Description |
|----------|----------|-------------|
| `SUPABASE_URL` | Yes | Supabase project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | Yes | Supabase service role key |
| `SPOTIFY_CLIENT_ID` | For lyrics | Spotify app client ID |
| `SPOTIFY_CLIENT_SECRET` | For lyrics | Spotify app client secret |
| `GEMINI_API_KEY` | For scanning | Google Gemini API key |
| `MUSIXMATCH_API_KEY` | For lyrics | Musixmatch API key |

---

## Database

Import the schema into your Supabase project:

```bash
psql -h your-supabase-host -U postgres -d postgres -f database/schema.sql
```

See `database/schema.sql` for the complete table definitions.

---

## License

MIT
