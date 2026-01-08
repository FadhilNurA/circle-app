import { NextRequest, NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';

// PUT - Accept or reject friend request
export async function PUT(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id: friendshipId } = await params;
    const authHeader = request.headers.get('authorization');
    if (!authHeader?.startsWith('Bearer ')) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const token = authHeader.split(' ')[1];
    const { data: { user }, error: userError } = await supabaseAdmin.auth.getUser(token);

    if (userError || !user) {
      return NextResponse.json({ error: 'Invalid token' }, { status: 401 });
    }

    const { action } = await request.json(); // 'accept' or 'reject'

    if (!action || !['accept', 'reject'].includes(action)) {
      return NextResponse.json({ error: 'Action must be "accept" or "reject"' }, { status: 400 });
    }

    // Check if friendship exists and user is the addressee
    const { data: friendship, error: findError } = await supabaseAdmin
      .from('friendships')
      .select('*')
      .eq('id', friendshipId)
      .eq('addressee_id', user.id)
      .eq('status', 'pending')
      .single();

    if (findError || !friendship) {
      return NextResponse.json({ error: 'Friend request not found' }, { status: 404 });
    }

    const newStatus = action === 'accept' ? 'accepted' : 'rejected';

    const { data: updated, error: updateError } = await supabaseAdmin
      .from('friendships')
      .update({
        status: newStatus,
        updated_at: new Date().toISOString(),
      })
      .eq('id', friendshipId)
      .select()
      .single();

    if (updateError) {
      return NextResponse.json({ error: updateError.message }, { status: 500 });
    }

    return NextResponse.json({
      message: action === 'accept' ? 'Friend request accepted' : 'Friend request rejected',
      friendship: updated,
    });

  } catch (error) {
    console.error('Update friendship error:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

// DELETE - Remove friend or cancel request
export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id: friendshipId } = await params;
    const authHeader = request.headers.get('authorization');
    if (!authHeader?.startsWith('Bearer ')) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const token = authHeader.split(' ')[1];
    const { data: { user }, error: userError } = await supabaseAdmin.auth.getUser(token);

    if (userError || !user) {
      return NextResponse.json({ error: 'Invalid token' }, { status: 401 });
    }

    // Check if friendship exists and user is part of it
    const { data: friendship, error: findError } = await supabaseAdmin
      .from('friendships')
      .select('*')
      .eq('id', friendshipId)
      .or(`requester_id.eq.${user.id},addressee_id.eq.${user.id}`)
      .single();

    if (findError || !friendship) {
      return NextResponse.json({ error: 'Friendship not found' }, { status: 404 });
    }

    const { error: deleteError } = await supabaseAdmin
      .from('friendships')
      .delete()
      .eq('id', friendshipId);

    if (deleteError) {
      return NextResponse.json({ error: deleteError.message }, { status: 500 });
    }

    return NextResponse.json({ message: 'Friendship removed' });

  } catch (error) {
    console.error('Delete friendship error:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
