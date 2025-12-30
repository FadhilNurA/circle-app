import { NextRequest, NextResponse } from 'next/server';
import axios from 'axios';
import { supabaseAdmin } from '@/lib/supabase';

const SPOTIFY_TOKEN_URL = 'https://accounts.spotify.com/api/token';

interface SpotifyTokenResponse {
  access_token: string;
  token_type: string;
  scope: string;
  expires_in: number;
  refresh_token: string;
}

export async function POST(request: NextRequest) {
  try {
    const { code, redirect_uri, user_id } = await request.json();

    // Validate required fields
    if (!code || !redirect_uri) {
      return NextResponse.json(
        { error: 'Missing required fields: code and redirect_uri are required' },
        { status: 400 }
      );
    }

    const clientId = process.env.SPOTIFY_CLIENT_ID;
    const clientSecret = process.env.SPOTIFY_CLIENT_SECRET;

    if (!clientId || !clientSecret) {
      console.error('Missing Spotify credentials in environment variables');
      return NextResponse.json(
        { error: 'Server configuration error' },
        { status: 500 }
      );
    }

    // Create Base64 encoded credentials for Basic Auth
    const credentials = Buffer.from(`${clientId}:${clientSecret}`).toString('base64');

    // Exchange authorization code for access token
    const tokenResponse = await axios.post<SpotifyTokenResponse>(
      SPOTIFY_TOKEN_URL,
      new URLSearchParams({
        grant_type: 'authorization_code',
        code: code,
        redirect_uri: redirect_uri,
      }),
      {
        headers: {
          'Authorization': `Basic ${credentials}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      }
    );

    const { access_token, refresh_token, expires_in, token_type, scope } = tokenResponse.data;

    // Optionally store tokens in Supabase if user_id is provided
    if (user_id) {
      const expiresAt = new Date(Date.now() + expires_in * 1000).toISOString();
      
      const { error: dbError } = await supabaseAdmin
        .from('spotify_tokens')
        .upsert({
          user_id: user_id,
          access_token: access_token,
          refresh_token: refresh_token,
          expires_at: expiresAt,
          scope: scope,
          updated_at: new Date().toISOString(),
        }, {
          onConflict: 'user_id',
        });

      if (dbError) {
        console.error('Error storing tokens in Supabase:', dbError);
        // Continue anyway - tokens are still valid, just not persisted
      }
    }

    // Return tokens to the client
    return NextResponse.json({
      access_token,
      refresh_token,
      expires_in,
      token_type,
      scope,
    });

  } catch (error) {
    if (axios.isAxiosError(error)) {
      console.error('Spotify API error:', error.response?.data);
      return NextResponse.json(
        { 
          error: 'Failed to exchange code for token',
          details: error.response?.data?.error_description || error.message,
        },
        { status: error.response?.status || 500 }
      );
    }

    console.error('Unexpected error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
