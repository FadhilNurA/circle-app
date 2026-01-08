import { NextRequest, NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';

// POST - Bill creator approves payment from a user
export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string; receiptId: string }> }
) {
  try {
    const { id: groupId, receiptId } = await params;
    const authHeader = request.headers.get('authorization');
    if (!authHeader?.startsWith('Bearer ')) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const token = authHeader.split(' ')[1];
    const { data: { user }, error: userError } = await supabaseAdmin.auth.getUser(token);

    if (userError || !user) {
      return NextResponse.json({ error: 'Invalid token' }, { status: 401 });
    }

    // Check if user is the bill creator
    const { data: receipt } = await supabaseAdmin
      .from('receipts')
      .select('uploaded_by')
      .eq('id', receiptId)
      .eq('group_id', groupId)
      .single();

    if (!receipt) {
      return NextResponse.json({ error: 'Receipt not found' }, { status: 404 });
    }

    if (receipt.uploaded_by !== user.id) {
      return NextResponse.json({ error: 'Only bill creator can approve payments' }, { status: 403 });
    }

    const { user_id, action } = await request.json();

    if (!user_id) {
      return NextResponse.json({ error: 'user_id is required' }, { status: 400 });
    }

    // Update the user's balance to settled
    if (action === 'approve') {
      // Get user's balance
      const { data: balance } = await supabaseAdmin
        .from('user_balances')
        .select('amount_owed')
        .eq('receipt_id', receiptId)
        .eq('user_id', user_id)
        .single();

      const { error: updateError } = await supabaseAdmin
        .from('user_balances')
        .update({ 
          is_settled: true,
          amount_paid: balance?.amount_owed || 0,
          updated_at: new Date().toISOString()
        })
        .eq('receipt_id', receiptId)
        .eq('user_id', user_id);

      if (updateError) {
        return NextResponse.json({ error: updateError.message }, { status: 500 });
      }

      // Also update all item_splits for this user
      const { data: items } = await supabaseAdmin
        .from('receipt_items')
        .select('id')
        .eq('receipt_id', receiptId);

      if (items && items.length > 0) {
        const itemIds = items.map(i => i.id);
        await supabaseAdmin
          .from('item_splits')
          .update({ is_paid: true })
          .in('receipt_item_id', itemIds)
          .eq('user_id', user_id);
      }

      // Check if all balances are settled
      const { data: unsettledBalances } = await supabaseAdmin
        .from('user_balances')
        .select('id')
        .eq('receipt_id', receiptId)
        .eq('is_settled', false);

      if (!unsettledBalances || unsettledBalances.length === 0) {
        // All settled, update receipt status
        await supabaseAdmin
          .from('receipts')
          .update({ status: 'completed', updated_at: new Date().toISOString() })
          .eq('id', receiptId);
      }

      return NextResponse.json({ message: 'Payment approved', is_all_settled: !unsettledBalances || unsettledBalances.length === 0 });

    } else if (action === 'reject') {
      // Reset to unpaid
      const { error: updateError } = await supabaseAdmin
        .from('user_balances')
        .update({ 
          is_settled: false,
          amount_paid: 0,
          updated_at: new Date().toISOString()
        })
        .eq('receipt_id', receiptId)
        .eq('user_id', user_id);

      if (updateError) {
        return NextResponse.json({ error: updateError.message }, { status: 500 });
      }

      // Update receipt status back to splitting
      await supabaseAdmin
        .from('receipts')
        .update({ status: 'splitting', updated_at: new Date().toISOString() })
        .eq('id', receiptId);

      return NextResponse.json({ message: 'Payment rejected' });
    }

    return NextResponse.json({ error: 'Invalid action' }, { status: 400 });

  } catch (error) {
    console.error('Approve payment error:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

// GET - Get all balances for a receipt (who paid, who hasn't)
export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string; receiptId: string }> }
) {
  try {
    const { receiptId } = await params;
    const authHeader = request.headers.get('authorization');
    if (!authHeader?.startsWith('Bearer ')) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const token = authHeader.split(' ')[1];
    const { data: { user }, error: userError } = await supabaseAdmin.auth.getUser(token);

    if (userError || !user) {
      return NextResponse.json({ error: 'Invalid token' }, { status: 401 });
    }

    // Get all balances with user profiles
    const { data: balances, error } = await supabaseAdmin
      .from('user_balances')
      .select('*')
      .eq('receipt_id', receiptId);

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    // Get user profiles
    const balancesWithUsers = await Promise.all(
      (balances || []).map(async (balance) => {
        const { data: profile } = await supabaseAdmin
          .from('profiles')
          .select('id, username, full_name, avatar_url')
          .eq('id', balance.user_id)
          .single();
        return { ...balance, user: profile };
      })
    );

    return NextResponse.json({ balances: balancesWithUsers });

  } catch (error) {
    console.error('Get balances error:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
