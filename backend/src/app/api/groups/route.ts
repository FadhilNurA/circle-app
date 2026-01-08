import { NextRequest, NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';

// GET - List all groups for current user
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

    // Get all groups user is a member of
    const { data: memberships, error: memberError } = await supabaseAdmin
      .from('group_members')
      .select('group_id')
      .eq('user_id', user.id);

    if (memberError) {
      return NextResponse.json({ error: memberError.message }, { status: 500 });
    }

    const groupIds = memberships?.map(m => m.group_id) || [];

    if (groupIds.length === 0) {
      return NextResponse.json({ groups: [] });
    }

    // Get group details
    const { data: groups, error: groupError } = await supabaseAdmin
      .from('groups')
      .select('*')
      .in('id', groupIds)
      .order('updated_at', { ascending: false });

    if (groupError) {
      return NextResponse.json({ error: groupError.message }, { status: 500 });
    }

    // Get members for each group with profiles
    const groupsWithMembers = await Promise.all(
      (groups || []).map(async (group) => {
        const { data: members } = await supabaseAdmin
          .from('group_members')
          .select('user_id, role, joined_at')
          .eq('group_id', group.id);

        // Get profiles for members
        const membersWithProfiles = await Promise.all(
          (members || []).map(async (member) => {
            const { data: profile } = await supabaseAdmin
              .from('profiles')
              .select('id, username, full_name, avatar_url')
              .eq('id', member.user_id)
              .single();
            return { ...member, profile };
          })
        );

        return { ...group, members: membersWithProfiles };
      })
    );

    return NextResponse.json({ groups: groupsWithMembers });

  } catch (error) {
    console.error('Get groups error:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

// POST - Create a new group
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

    const { name, description, member_ids } = await request.json();

    if (!name) {
      return NextResponse.json({ error: 'Group name is required' }, { status: 400 });
    }

    // Create the group
    const { data: group, error: groupError } = await supabaseAdmin
      .from('groups')
      .insert({
        name,
        description,
        created_by: user.id,
      })
      .select()
      .single();

    if (groupError) {
      return NextResponse.json({ error: groupError.message }, { status: 500 });
    }

    // Add creator as admin
    const members = [{ group_id: group.id, user_id: user.id, role: 'admin' }];

    // Add other members
    if (member_ids && Array.isArray(member_ids)) {
      for (const memberId of member_ids) {
        if (memberId !== user.id) {
          members.push({ group_id: group.id, user_id: memberId, role: 'member' });
        }
      }
    }

    const { error: memberError } = await supabaseAdmin
      .from('group_members')
      .insert(members);

    if (memberError) {
      // Rollback group creation
      await supabaseAdmin.from('groups').delete().eq('id', group.id);
      return NextResponse.json({ error: memberError.message }, { status: 500 });
    }

    return NextResponse.json({ 
      message: 'Group created successfully',
      group 
    }, { status: 201 });

  } catch (error) {
    console.error('Create group error:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
