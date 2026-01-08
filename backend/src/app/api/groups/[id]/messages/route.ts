import { NextRequest, NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';

// GET - Get messages in a group
export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id: groupId } = await params;
    const authHeader = request.headers.get('authorization');
    if (!authHeader?.startsWith('Bearer ')) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const token = authHeader.split(' ')[1];
    const { data: { user }, error: userError } = await supabaseAdmin.auth.getUser(token);

    if (userError || !user) {
      return NextResponse.json({ error: 'Invalid token' }, { status: 401 });
    }

    // Check membership
    const { data: membership } = await supabaseAdmin
      .from('group_members')
      .select('id')
      .eq('group_id', groupId)
      .eq('user_id', user.id)
      .single();

    if (!membership) {
      return NextResponse.json({ error: 'Not a member of this group' }, { status: 403 });
    }

    // Get query params
    const { searchParams } = new URL(request.url);
    const limit = parseInt(searchParams.get('limit') || '50');
    const before = searchParams.get('before'); // cursor for pagination

    let query = supabaseAdmin
      .from('messages')
      .select('*')
      .eq('group_id', groupId)
      .order('created_at', { ascending: false })
      .limit(limit);

    if (before) {
      query = query.lt('created_at', before);
    }

    const { data: messagesRaw, error: msgError } = await query;

    if (msgError) {
      return NextResponse.json({ error: msgError.message }, { status: 500 });
    }

    // Get sender profiles for each message
    const messages = await Promise.all(
      (messagesRaw || []).map(async (msg) => {
        let sender = null;
        if (msg.sender_id) {
          const { data: profile } = await supabaseAdmin
            .from('profiles')
            .select('id, username, full_name, avatar_url')
            .eq('id', msg.sender_id)
            .single();
          sender = profile;
        }
        return { ...msg, sender };
      })
    );

    return NextResponse.json({ 
      messages: messages?.reverse() || [],
      has_more: messages?.length === limit
    });

  } catch (error) {
    console.error('Get messages error:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

// POST - Send a message
export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id: groupId } = await params;
    const authHeader = request.headers.get('authorization');
    if (!authHeader?.startsWith('Bearer ')) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const token = authHeader.split(' ')[1];
    const { data: { user }, error: userError } = await supabaseAdmin.auth.getUser(token);

    if (userError || !user) {
      return NextResponse.json({ error: 'Invalid token' }, { status: 401 });
    }

    // Check membership
    const { data: membership } = await supabaseAdmin
      .from('group_members')
      .select('id')
      .eq('group_id', groupId)
      .eq('user_id', user.id)
      .single();

    if (!membership) {
      return NextResponse.json({ error: 'Not a member of this group' }, { status: 403 });
    }

    const { content, message_type = 'text', metadata } = await request.json();

    if (!content) {
      return NextResponse.json({ error: 'Message content is required' }, { status: 400 });
    }

    const { data: messageRaw, error: insertError } = await supabaseAdmin
      .from('messages')
      .insert({
        group_id: groupId,
        sender_id: user.id,
        content,
        message_type,
        metadata,
      })
      .select('*')
      .single();

    if (insertError) {
      return NextResponse.json({ error: insertError.message }, { status: 500 });
    }

    // Get sender profile
    const { data: senderProfile } = await supabaseAdmin
      .from('profiles')
      .select('id, username, full_name, avatar_url')
      .eq('id', user.id)
      .single();

    const message = { ...messageRaw, sender: senderProfile };

    // Update group timestamp
    await supabaseAdmin
      .from('groups')
      .update({ updated_at: new Date().toISOString() })
      .eq('id', groupId);

    return NextResponse.json({ message }, { status: 201 });

  } catch (error) {
    console.error('Send message error:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
