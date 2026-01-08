import { NextRequest, NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';

// Helper to get profile
async function getProfile(userId: string) {
  const { data } = await supabaseAdmin
    .from('profiles')
    .select('id, username, full_name, avatar_url, email')
    .eq('id', userId)
    .single();
  return data;
}

// GET - Get all friends (accepted friendships)
export async function GET(request: NextRequest) {
  try {
    const authHeader = request.headers.get('authorization');
    if (!authHeader?.startsWith('Bearer ')) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const token = authHeader.split(' ')[1];
    const { data: { user }, error: userError } = await supabaseAdmin.auth.getUser(token);

    if (userError || !user) {
      return NextResponse.json({ error: 'Invalid token' }, { status: 401 });
    }

    // Get query params for filtering
    const { searchParams } = new URL(request.url);
    const status = searchParams.get('status') || 'accepted';

    // Get friendships where user is either requester or addressee
    const { data: friendships, error } = await supabaseAdmin
      .from('friendships')
      .select('*')
      .or(`requester_id.eq.${user.id},addressee_id.eq.${user.id}`)
      .eq('status', status)
      .order('updated_at', { ascending: false });

    if (error) {
      console.error('Get friendships error:', error);
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    // Transform to get friend info (the other person)
    const friends = await Promise.all(
      (friendships || []).map(async (f) => {
        const isRequester = f.requester_id === user.id;
        const friendId = isRequester ? f.addressee_id : f.requester_id;
        const friend = await getProfile(friendId);
        
        return {
          friendship_id: f.id,
          status: f.status,
          created_at: f.created_at,
          is_requester: isRequester,
          friend: friend,
        };
      })
    );

    return NextResponse.json({ friends });

  } catch (error) {
    console.error('Get friends error:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

// POST - Send friend request by username
export async function POST(request: NextRequest) {
  try {
    const authHeader = request.headers.get('authorization');
    if (!authHeader?.startsWith('Bearer ')) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const token = authHeader.split(' ')[1];
    const { data: { user }, error: userError } = await supabaseAdmin.auth.getUser(token);

    if (userError || !user) {
      return NextResponse.json({ error: 'Invalid token' }, { status: 401 });
    }

    const { username } = await request.json();

    if (!username) {
      return NextResponse.json({ error: 'Username is required' }, { status: 400 });
    }

    // Find user by username
    const { data: targetUser, error: findError } = await supabaseAdmin
      .from('profiles')
      .select('id, username, full_name, avatar_url')
      .eq('username', username.toLowerCase())
      .single();

    if (findError || !targetUser) {
      return NextResponse.json({ error: 'User not found' }, { status: 404 });
    }

    if (targetUser.id === user.id) {
      return NextResponse.json({ error: 'Cannot add yourself as friend' }, { status: 400 });
    }

    // Check if friendship already exists (in either direction)
    const { data: existing } = await supabaseAdmin
      .from('friendships')
      .select('id, status')
      .or(`and(requester_id.eq.${user.id},addressee_id.eq.${targetUser.id}),and(requester_id.eq.${targetUser.id},addressee_id.eq.${user.id})`)
      .single();

    if (existing) {
      if (existing.status === 'accepted') {
        return NextResponse.json({ error: 'Already friends' }, { status: 409 });
      }
      if (existing.status === 'pending') {
        return NextResponse.json({ error: 'Friend request already pending' }, { status: 409 });
      }
      if (existing.status === 'blocked') {
        return NextResponse.json({ error: 'Cannot send friend request' }, { status: 403 });
      }
    }

    // Create friend request
    const { data: friendship, error: insertError } = await supabaseAdmin
      .from('friendships')
      .insert({
        requester_id: user.id,
        addressee_id: targetUser.id,
        status: 'pending',
      })
      .select()
      .single();

    if (insertError) {
      return NextResponse.json({ error: insertError.message }, { status: 500 });
    }

    return NextResponse.json({
      message: 'Friend request sent',
      friendship: {
        ...friendship,
        addressee: targetUser,
      }
    }, { status: 201 });

  } catch (error) {
    console.error('Send friend request error:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
