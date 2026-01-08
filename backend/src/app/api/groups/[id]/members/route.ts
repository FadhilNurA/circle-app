import { NextRequest, NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';

// Helper function to check if two users are friends
async function areFriends(userId1: string, userId2: string): Promise<boolean> {
  const { data } = await supabaseAdmin
    .from('friendships')
    .select('id')
    .eq('status', 'accepted')
    .or(`and(requester_id.eq.${userId1},addressee_id.eq.${userId2}),and(requester_id.eq.${userId2},addressee_id.eq.${userId1})`)
    .single();
  
  return !!data;
}

// POST - Add member to group (must be a friend)
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

    // Check if user is admin
    const { data: membership } = await supabaseAdmin
      .from('group_members')
      .select('role')
      .eq('group_id', groupId)
      .eq('user_id', user.id)
      .single();

    if (!membership || membership.role !== 'admin') {
      return NextResponse.json({ error: 'Only admins can add members' }, { status: 403 });
    }

    const { user_id, username } = await request.json();

    let targetUserId = user_id;

    // If username is provided, find the user
    if (!targetUserId && username) {
      const { data: profile } = await supabaseAdmin
        .from('profiles')
        .select('id')
        .eq('username', username)
        .single();

      if (!profile) {
        return NextResponse.json({ error: 'User not found' }, { status: 404 });
      }
      targetUserId = profile.id;
    }

    if (!targetUserId) {
      return NextResponse.json({ error: 'user_id or username is required' }, { status: 400 });
    }

    // Check if target user is a friend
    const isFriend = await areFriends(user.id, targetUserId);
    if (!isFriend) {
      return NextResponse.json({ 
        error: 'You can only add friends to the group. Send a friend request first.' 
      }, { status: 403 });
    }

    // Check if already a member
    const { data: existing } = await supabaseAdmin
      .from('group_members')
      .select('id')
      .eq('group_id', groupId)
      .eq('user_id', targetUserId)
      .single();

    if (existing) {
      return NextResponse.json({ error: 'User is already a member' }, { status: 409 });
    }

    // Add member
    const { error: addError } = await supabaseAdmin
      .from('group_members')
      .insert({
        group_id: groupId,
        user_id: targetUserId,
        role: 'member',
      });

    if (addError) {
      return NextResponse.json({ error: addError.message }, { status: 500 });
    }

    // Update group timestamp
    await supabaseAdmin
      .from('groups')
      .update({ updated_at: new Date().toISOString() })
      .eq('id', groupId);

    return NextResponse.json({ message: 'Member added successfully' }, { status: 201 });

  } catch (error) {
    console.error('Add member error:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

// DELETE - Remove member from group
export async function DELETE(
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

    const { user_id } = await request.json();

    if (!user_id) {
      return NextResponse.json({ error: 'user_id is required' }, { status: 400 });
    }

    // Check permissions - admin or self-removal
    const { data: membership } = await supabaseAdmin
      .from('group_members')
      .select('role')
      .eq('group_id', groupId)
      .eq('user_id', user.id)
      .single();

    const isAdmin = membership?.role === 'admin';
    const isSelf = user_id === user.id;

    if (!isAdmin && !isSelf) {
      return NextResponse.json({ error: 'Not authorized to remove this member' }, { status: 403 });
    }

    // Can't remove the last admin
    if (isAdmin && isSelf) {
      const { data: admins } = await supabaseAdmin
        .from('group_members')
        .select('id')
        .eq('group_id', groupId)
        .eq('role', 'admin');

      if (admins && admins.length <= 1) {
        return NextResponse.json({ error: 'Cannot remove the last admin' }, { status: 400 });
      }
    }

    const { error: removeError } = await supabaseAdmin
      .from('group_members')
      .delete()
      .eq('group_id', groupId)
      .eq('user_id', user_id);

    if (removeError) {
      return NextResponse.json({ error: removeError.message }, { status: 500 });
    }

    return NextResponse.json({ message: 'Member removed' });

  } catch (error) {
    console.error('Remove member error:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
