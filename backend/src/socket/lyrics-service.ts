import axios from 'axios';

export interface LyricLine {
  time: number; // milliseconds
  text: string;
}

export class LyricsService {
  private static readonly MUSIXMATCH_BASE = 'https://api.musixmatch.com/ws/1.1';
  private static readonly API_KEY = process.env.MUSIXMATCH_API_KEY || '';

  /**
   * Get synced lyrics for a track.
   * Falls back to unsynced lyrics if synced not available.
   */
  static async getSyncedLyrics(trackName: string, artistName: string): Promise<LyricLine[]> {
    try {
      // Step 1: Search for the track
      const searchResponse = await axios.get(`${this.MUSIXMATCH_BASE}/track.search`, {
        params: {
          q_track: trackName,
          q_artist: artistName,
          page_size: 1,
          s_track_rating: 'desc',
          apikey: this.API_KEY,
        },
      });

      const trackList = searchResponse.data?.message?.body?.track_list;
      if (!trackList || trackList.length === 0) {
        console.log(`[Lyrics] Track not found: ${trackName} - ${artistName}`);
        return this.createPlaceholderLyrics(trackName, artistName);
      }

      const trackId = trackList[0].track.track_id;

      // Step 2: Try to get synced lyrics (subtitle)
      try {
        const subtitleResponse = await axios.get(`${this.MUSIXMATCH_BASE}/track.subtitle.get`, {
          params: {
            track_id: trackId,
            subtitle_format: 'lrc',
            apikey: this.API_KEY,
          },
        });

        const subtitleBody = subtitleResponse.data?.message?.body?.subtitle?.subtitle_body;
        if (subtitleBody) {
          const parsed = this.parseLRC(subtitleBody);
          if (parsed.length > 0) {
            console.log(`[Lyrics] Synced lyrics found for: ${trackName} (${parsed.length} lines)`);
            return parsed;
          }
        }
      } catch {
        console.log(`[Lyrics] No synced lyrics for: ${trackName}`);
      }

      // Step 3: Fall back to unsynced lyrics
      try {
        const lyricsResponse = await axios.get(`${this.MUSIXMATCH_BASE}/track.lyrics.get`, {
          params: {
            track_id: trackId,
            apikey: this.API_KEY,
          },
        });

        const lyricsBody = lyricsResponse.data?.message?.body?.lyrics?.lyrics_body;
        if (lyricsBody) {
          const lines = this.createUnsyncedLyrics(lyricsBody);
          console.log(`[Lyrics] Unsynced lyrics found for: ${trackName} (${lines.length} lines)`);
          return lines;
        }
      } catch {
        console.log(`[Lyrics] No lyrics at all for: ${trackName}`);
      }

      return this.createPlaceholderLyrics(trackName, artistName);
    } catch (error) {
      console.error('[Lyrics] Error fetching lyrics:', error);
      return this.createPlaceholderLyrics(trackName, artistName);
    }
  }

  /**
   * Parse LRC format lyrics into timestamped lines.
   * LRC format: [mm:ss.xx] Lyric text
   */
  private static parseLRC(lrcContent: string): LyricLine[] {
    const lines: LyricLine[] = [];
    const lrcLines = lrcContent.split('\n');

    for (const line of lrcLines) {
      // Match patterns like [00:12.34] or [01:23.45]
      const match = line.match(/\[(\d{2}):(\d{2})\.(\d{2,3})\]\s*(.*)/);
      if (match) {
        const minutes = parseInt(match[1], 10);
        const seconds = parseInt(match[2], 10);
        const hundredths = match[3].length === 3
          ? parseInt(match[3], 10)
          : parseInt(match[3], 10) * 10;

        const timeMs = (minutes * 60 + seconds) * 1000 + hundredths;
        const text = match[4].trim();

        if (text.length > 0) {
          lines.push({ time: timeMs, text });
        }
      }
    }

    return lines.sort((a, b) => a.time - b.time);
  }

  /**
   * Create timed lines from unsynced lyrics (estimate spacing).
   */
  private static createUnsyncedLyrics(lyricsBody: string): LyricLine[] {
    const lines = lyricsBody
      .split('\n')
      .map(l => l.trim())
      .filter(l => l.length > 0 && !l.includes('****'));

    // Estimate ~3 seconds per line
    return lines.map((text, index) => ({
      time: index * 3000,
      text,
    }));
  }

  /**
   * Placeholder when no lyrics found.
   */
  private static createPlaceholderLyrics(trackName: string, artistName: string): LyricLine[] {
    return [
      { time: 0, text: `🎵 ${trackName}` },
      { time: 2000, text: `by ${artistName}` },
      { time: 5000, text: '' },
      { time: 6000, text: '♪ Lyrics not available ♪' },
      { time: 8000, text: 'Enjoy the music!' },
    ];
  }
}
