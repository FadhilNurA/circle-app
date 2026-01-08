import { NextRequest, NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';

// POST - Split items among users
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

    const { splits } = await request.json();
    // splits format: [{ item_id, user_ids: [], split_type: 'equal' | 'custom', amounts: [] }]

    if (!splits || !Array.isArray(splits)) {
      return NextResponse.json({ error: 'Splits array is required' }, { status: 400 });
    }

    // Clear existing splits for this receipt
    const { data: items } = await supabaseAdmin
      .from('receipt_items')
      .select('id')
      .eq('receipt_id', receiptId);

    const itemIds = items?.map(i => i.id) || [];
    
    if (itemIds.length > 0) {
      await supabaseAdmin
        .from('item_splits')
        .delete()
        .in('receipt_item_id', itemIds);
    }

    // Insert new splits
    const splitsToInsert: any[] = [];

    for (const split of splits) {
      const { item_id, user_ids, split_type = 'equal', amounts = [] } = split;

      // Get item price
      const { data: item } = await supabaseAdmin
        .from('receipt_items')
        .select('total_price')
        .eq('id', item_id)
        .single();

      if (!item) continue;

      if (split_type === 'equal') {
        const shareAmount = item.total_price / user_ids.length;
        for (const userId of user_ids) {
          splitsToInsert.push({
            receipt_item_id: item_id,
            user_id: userId,
            share_amount: shareAmount,
          });
        }
      } else {
        // Custom amounts
        for (let i = 0; i < user_ids.length; i++) {
          splitsToInsert.push({
            receipt_item_id: item_id,
            user_id: user_ids[i],
            share_amount: amounts[i] || 0,
          });
        }
      }
    }

    if (splitsToInsert.length > 0) {
      const { error: insertError } = await supabaseAdmin
        .from('item_splits')
        .insert(splitsToInsert);

      if (insertError) {
        return NextResponse.json({ error: insertError.message }, { status: 500 });
      }
    }

    // Calculate and update user balances
    await updateUserBalances(receiptId, groupId);

    // Update receipt status
    await supabaseAdmin
      .from('receipts')
      .update({ status: 'completed', updated_at: new Date().toISOString() })
      .eq('id', receiptId);

    return NextResponse.json({ message: 'Bill split successfully' }, { status: 201 });

  } catch (error) {
    console.error('Split bill error:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

// GET - Get current splits for a receipt
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

    // Get items
    const { data: items, error } = await supabaseAdmin
      .from('receipt_items')
      .select('*')
      .eq('receipt_id', receiptId);

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    // Get splits for each item with user profiles
    const itemsWithSplits = await Promise.all(
      (items || []).map(async (item) => {
        const { data: splits } = await supabaseAdmin
          .from('item_splits')
          .select('*')
          .eq('receipt_item_id', item.id);

        const splitsWithUsers = await Promise.all(
          (splits || []).map(async (split) => {
            const { data: profile } = await supabaseAdmin
              .from('profiles')
              .select('id, username, full_name, avatar_url')
              .eq('id', split.user_id)
              .single();
            return { ...split, user: profile };
          })
        );

        return { ...item, item_splits: splitsWithUsers };
      })
    );

    // Get user balances
    const { data: balancesRaw } = await supabaseAdmin
      .from('user_balances')
      .select('*')
      .eq('receipt_id', receiptId);

    const balances = await Promise.all(
      (balancesRaw || []).map(async (balance) => {
        const { data: profile } = await supabaseAdmin
          .from('profiles')
          .select('id, username, full_name, avatar_url')
          .eq('id', balance.user_id)
          .single();
        return { ...balance, user: profile };
      })
    );

    return NextResponse.json({ items: itemsWithSplits, balances });

  } catch (error) {
    console.error('Get splits error:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

// Helper function to calculate user balances
async function updateUserBalances(receiptId: string, groupId: string) {
  // Get all splits for this receipt
  const { data: items } = await supabaseAdmin
    .from('receipt_items')
    .select(`
      id,
      item_splits (
        user_id,
        share_amount
      )
    `)
    .eq('receipt_id', receiptId);

  // Calculate total per user
  const userTotals: Record<string, number> = {};

  for (const item of items || []) {
    for (const split of item.item_splits || []) {
      if (!userTotals[split.user_id]) {
        userTotals[split.user_id] = 0;
      }
      userTotals[split.user_id] += split.share_amount;
    }
  }

  // Get tax and service charge
  const { data: receipt } = await supabaseAdmin
    .from('receipts')
    .select('tax_amount, service_charge')
    .eq('id', receiptId)
    .single();

  // Add proportional tax and service charge
  const extraCharges = (receipt?.tax_amount || 0) + (receipt?.service_charge || 0);
  const totalItems = Object.values(userTotals).reduce((a, b) => a + b, 0);

  if (totalItems > 0 && extraCharges > 0) {
    for (const userId of Object.keys(userTotals)) {
      const proportion = userTotals[userId] / totalItems;
      userTotals[userId] += extraCharges * proportion;
    }
  }

  // Delete existing balances
  await supabaseAdmin
    .from('user_balances')
    .delete()
    .eq('receipt_id', receiptId);

  // Insert new balances
  const balancesToInsert = Object.entries(userTotals).map(([userId, amount]) => ({
    receipt_id: receiptId,
    user_id: userId,
    amount_owed: amount,
    amount_paid: 0,
  }));

  if (balancesToInsert.length > 0) {
    await supabaseAdmin
      .from('user_balances')
      .insert(balancesToInsert);
  }
}
