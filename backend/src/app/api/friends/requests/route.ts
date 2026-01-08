import { NextRequest, NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';

// GET - Get pending friend requests (received)
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

    // Get pending requests where user is addressee
    const { data: requests, error } = await supabaseAdmin
      .from('friendships')
      .select('*')
      .eq('addressee_id', user.id)
      .eq('status', 'pending')
      .order('created_at', { ascending: false });

    if (error) {
      console.error('Get requests error:', error);
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    // Get requester profiles separately
    const requestsWithProfiles = await Promise.all(
      (requests || []).map(async (req) => {
        const { data: profile } = await supabaseAdmin
          .from('profiles')
          .select('id, username, full_name, avatar_url')
          .eq('id', req.requester_id)
          .single();
        
        return {
          ...req,
          requester: profile,
        };
      })
    );

    return NextResponse.json({ requests: requestsWithProfiles });

  } catch (error) {
    console.error('Get friend requests error:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
