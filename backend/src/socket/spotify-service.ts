import axios from 'axios';

interface SpotifyPlaybackState {
  trackId: string;
  trackName: string;
  artistName: string;
  albumArt: string | null;
  durationMs: number;
  progressMs: number;
  isPlaying: boolean;
}

export class SpotifyService {
  private static readonly BASE_URL = 'https://api.spotify.com/v1';

  static async getCurrentlyPlaying(accessToken: string): Promise<SpotifyPlaybackState | null> {
    try {
      const response = await axios.get(`${this.BASE_URL}/me/player/currently-playing`, {
        headers: { Authorization: `Bearer ${accessToken}` },
      });

      // 204 = no content (nothing playing)
      if (response.status === 204 || !response.data) {
        return null;
      }

      const data = response.data;
      if (!data.item) return null;

      return {
        trackId: data.item.id,
        trackName: data.item.name,
        artistName: data.item.artists.map((a: { name: string }) => a.name).join(', '),
        albumArt: data.item.album?.images?.[0]?.url ?? null,
        durationMs: data.item.duration_ms,
        progressMs: data.progress_ms ?? 0,
        isPlaying: data.is_playing ?? false,
      };
    } catch (error) {
      if (axios.isAxiosError(error) && error.response?.status === 401) {
        console.error('[Spotify] Token expired — needs refresh');
      } else {
        console.error('[Spotify] API error:', error);
      }
      return null;
    }
  }

  static async refreshAccessToken(refreshToken: string): Promise<string | null> {
    try {
      const clientId = process.env.SPOTIFY_CLIENT_ID;
      const clientSecret = process.env.SPOTIFY_CLIENT_SECRET;
      if (!clientId || !clientSecret) return null;

      const credentials = Buffer.from(`${clientId}:${clientSecret}`).toString('base64');

      const response = await axios.post(
        'https://accounts.spotify.com/api/token',
        new URLSearchParams({
          grant_type: 'refresh_token',
          refresh_token: refreshToken,
        }),
        {
          headers: {
            Authorization: `Basic ${credentials}`,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        }
      );

      return response.data.access_token;
    } catch (error) {
      console.error('[Spotify] Token refresh error:', error);
      return null;
    }
  }
}
