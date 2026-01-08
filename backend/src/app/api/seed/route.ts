import { NextRequest, NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';

// POST - Create dummy users for testing
// WARNING: Only use in development!
export async function POST(request: NextRequest) {
  try {
    // Check for secret key to prevent unauthorized seeding
    const { secret } = await request.json();
    
    if (secret !== 'seed-circle-dev') {
      return NextResponse.json({ error: 'Invalid secret' }, { status: 401 });
    }

    const dummyUsers = [
      { email: 'alice@example.com', password: 'password123', username: 'alice', full_name: 'Alice Johnson' },
      { email: 'bob@example.com', password: 'password123', username: 'bob', full_name: 'Bob Smith' },
      { email: 'charlie@example.com', password: 'password123', username: 'charlie', full_name: 'Charlie Brown' },
      { email: 'diana@example.com', password: 'password123', username: 'diana', full_name: 'Diana Prince' },
      { email: 'evan@example.com', password: 'password123', username: 'evan', full_name: 'Evan Williams' },
    ];

    const createdUsers: { email: string; id: string }[] = [];
    const errors: { email: string; error: string }[] = [];

    for (const user of dummyUsers) {
      // Check if user already exists
      const { data: existingProfile } = await supabaseAdmin
        .from('profiles')
        .select('id')
        .eq('username', user.username)
        .single();

      if (existingProfile) {
        createdUsers.push({ email: user.email, id: existingProfile.id });
        continue;
      }

      // Create user via Supabase Auth
      const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
        email: user.email,
        password: user.password,
        email_confirm: true,
        user_metadata: {
          username: user.username,
          full_name: user.full_name,
        },
      });

      if (authError) {
        errors.push({ email: user.email, error: authError.message });
        continue;
      }

      // Create profile manually (in case trigger doesn't fire)
      await supabaseAdmin.from('profiles').upsert({
        id: authData.user.id,
        username: user.username,
        full_name: user.full_name,
        email: user.email,
        avatar_url: '',
      });

      createdUsers.push({ email: user.email, id: authData.user.id });
    }

    // If we have at least 2 users, create friendships
    if (createdUsers.length >= 2) {
      // Find user IDs by email
      const alice = createdUsers.find(u => u.email === 'alice@example.com');
      const bob = createdUsers.find(u => u.email === 'bob@example.com');
      const charlie = createdUsers.find(u => u.email === 'charlie@example.com');
      const diana = createdUsers.find(u => u.email === 'diana@example.com');
      const evan = createdUsers.find(u => u.email === 'evan@example.com');

      // Alice and Bob are friends
      if (alice && bob) {
        await supabaseAdmin.from('friendships').upsert({
          requester_id: alice.id,
          addressee_id: bob.id,
          status: 'accepted',
        }, { onConflict: 'requester_id,addressee_id' });
      }

      // Charlie sent request to Alice
      if (charlie && alice) {
        await supabaseAdmin.from('friendships').upsert({
          requester_id: charlie.id,
          addressee_id: alice.id,
          status: 'pending',
        }, { onConflict: 'requester_id,addressee_id' });
      }

      // Diana and Evan are friends
      if (diana && evan) {
        await supabaseAdmin.from('friendships').upsert({
          requester_id: diana.id,
          addressee_id: evan.id,
          status: 'accepted',
        }, { onConflict: 'requester_id,addressee_id' });
      }

      // Create a test group with Alice and Bob
      if (alice && bob) {
        const { data: existingGroup } = await supabaseAdmin
          .from('groups')
          .select('id')
          .eq('name', 'Lunch Squad')
          .single();

        if (!existingGroup) {
          const { data: group } = await supabaseAdmin
            .from('groups')
            .insert({
              name: 'Lunch Squad',
              description: 'Group for splitting lunch bills',
              created_by: alice.id,
            })
            .select()
            .single();

          if (group) {
            await supabaseAdmin.from('group_members').insert([
              { group_id: group.id, user_id: alice.id, role: 'admin' },
              { group_id: group.id, user_id: bob.id, role: 'member' },
            ]);
          }
        }
      }
    }

    return NextResponse.json({
      message: 'Seed completed',
      created: createdUsers,
      errors: errors.length > 0 ? errors : undefined,
    });

  } catch (error) {
    console.error('Seed error:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
