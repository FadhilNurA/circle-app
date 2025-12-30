# Circle

A social music sharing app built with Flutter and Next.js, integrating Spotify and Supabase.

## Project Structure

```
Circle/
├── circle_app/     # Flutter mobile application
├── backend/        # Next.js API backend
└── README.md
```

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.x or later)
- [Node.js](https://nodejs.org/) (18.x or later)
- [Spotify Developer Account](https://developer.spotify.com/dashboard)
- [Supabase Account](https://supabase.com/)

## Setup

### 1. Clone the Repository

```bash
git clone <your-repo-url>
cd Circle
```

### 2. Backend Setup

```bash
cd backend

# Install dependencies
npm install

# Create environment file
cp .env.local.example .env.local
```

Edit `.env.local` with your credentials:

```env
SUPABASE_URL=your_supabase_project_url
SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key
SPOTIFY_CLIENT_ID=your_spotify_client_id
SPOTIFY_CLIENT_SECRET=your_spotify_client_secret
```

Start the development server:

```bash
npm run dev
```

The backend will be available at `http://localhost:3000`.

### 3. Flutter App Setup

```bash
cd circle_app

# Install dependencies
flutter pub get

# Run the app
flutter run
```

## API Endpoints

### Spotify

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/spotify/create-jam` | Exchange Spotify auth code for access token |

#### POST /api/spotify/create-jam

Request body:
```json
{
  "code": "spotify_authorization_code",
  "redirect_uri": "your_app_redirect_uri",
  "user_id": "optional_supabase_user_id"
}
```

Response:
```json
{
  "access_token": "...",
  "refresh_token": "...",
  "expires_in": 3600,
  "token_type": "Bearer",
  "scope": "..."
}
```

## Development

### Running the Backend

```bash
cd backend
npm run dev      # Development mode
npm run build    # Build for production
npm start        # Start production server
```

### Running the Flutter App

```bash
cd circle_app
flutter run              # Run on connected device
flutter run -d chrome    # Run on web
flutter run -d ios       # Run on iOS simulator
flutter run -d android   # Run on Android emulator
```

### Running Tests

```bash
# Flutter tests
cd circle_app
flutter test

# Backend tests (if configured)
cd backend
npm test
```

## Environment Variables

### Backend (.env.local)

| Variable | Description |
|----------|-------------|
| `SUPABASE_URL` | Your Supabase project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase service role key (server-side only) |
| `SPOTIFY_CLIENT_ID` | Spotify app client ID |
| `SPOTIFY_CLIENT_SECRET` | Spotify app client secret |

## Supabase Setup

Create the following table in your Supabase database for storing Spotify tokens:

```sql
CREATE TABLE spotify_tokens (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id),
  access_token TEXT NOT NULL,
  refresh_token TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  scope TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE spotify_tokens ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only access their own tokens
CREATE POLICY "Users can access own tokens" ON spotify_tokens
  FOR ALL USING (auth.uid() = user_id);
```

## Spotify Setup

1. Go to [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
2. Create a new app
3. Add your redirect URIs in the app settings
4. Copy the Client ID and Client Secret to your `.env.local`

## License

MIT
