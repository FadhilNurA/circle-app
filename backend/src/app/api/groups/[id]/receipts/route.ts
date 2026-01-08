import { NextRequest, NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';

// Helper function to update user balances after creating splits
async function updateUserBalances(receiptId: string, uploadedBy: string) {
  try {
    // Get all items for this receipt
    const { data: items } = await supabaseAdmin
      .from('receipt_items')
      .select('id')
      .eq('receipt_id', receiptId);

    if (!items || items.length === 0) return;

    // Get all splits for these items
    const itemIds = items.map(i => i.id);
    const { data: splits } = await supabaseAdmin
      .from('item_splits')
      .select('user_id, share_amount')
      .in('receipt_item_id', itemIds);

    if (!splits || splits.length === 0) return;

    // Calculate total per user
    const userTotals: Record<string, number> = {};
    for (const split of splits) {
      userTotals[split.user_id] = (userTotals[split.user_id] || 0) + parseFloat(split.share_amount);
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
      is_settled: userId === uploadedBy, // Creator doesn't owe themselves
    }));

    await supabaseAdmin
      .from('user_balances')
      .insert(balancesToInsert);

  } catch (error) {
    console.error('Update user balances error:', error);
  }
}

// GET - Get all receipts in a group
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

    const { data: receipts, error: receiptError } = await supabaseAdmin
      .from('receipts')
      .select(`
        *,
        receipt_items (
          id,
          name,
          quantity,
          unit_price,
          total_price,
          item_splits (
            id,
            user_id,
            share_amount,
            is_paid
          )
        )
      `)
      .eq('group_id', groupId)
      .order('created_at', { ascending: false });

    if (receiptError) {
      return NextResponse.json({ error: receiptError.message }, { status: 500 });
    }

    // Get uploaded_by profiles and split user profiles for each receipt
    const receiptsWithProfiles = await Promise.all(
      (receipts || []).map(async (receipt) => {
        let uploadedByUser = null;
        if (receipt.uploaded_by) {
          const { data: profile } = await supabaseAdmin
            .from('profiles')
            .select('id, username, full_name, avatar_url')
            .eq('id', receipt.uploaded_by)
            .single();
          uploadedByUser = profile;
        }

        // Add user profiles to item splits
        const itemsWithSplitUsers = await Promise.all(
          (receipt.receipt_items || []).map(async (item: any) => {
            const splitsWithUsers = await Promise.all(
              (item.item_splits || []).map(async (split: any) => {
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

        return { ...receipt, uploaded_by_user: uploadedByUser, receipt_items: itemsWithSplitUsers };
      })
    );

    return NextResponse.json({ receipts: receiptsWithProfiles });

  } catch (error) {
    console.error('Get receipts error:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

// POST - Create a new receipt (manual or from OCR)
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

    const { 
      store_name, 
      image_url,
      total_amount = 0,
      tax_amount = 0,
      service_charge = 0,
      items = []
    } = await request.json();

    // Create receipt
    const { data: receipt, error: receiptError } = await supabaseAdmin
      .from('receipts')
      .insert({
        group_id: groupId,
        uploaded_by: user.id,
        store_name,
        image_url,
        total_amount,
        tax_amount,
        service_charge,
        status: items.length > 0 ? 'splitting' : 'pending',
      })
      .select()
      .single();

    if (receiptError) {
      return NextResponse.json({ error: receiptError.message }, { status: 500 });
    }

    // Add items if provided
    if (items.length > 0) {
      for (const item of items) {
        const price = item.price || item.unit_price || item.total_price || 0;
        const qty = item.quantity || 1;
        
        const itemData = {
          receipt_id: receipt.id,
          name: item.name,
          quantity: qty,
          unit_price: price,
          total_price: price * qty,
        };

        console.log('Inserting item:', itemData);

        const { data: insertedItem, error: itemError } = await supabaseAdmin
          .from('receipt_items')
          .insert(itemData)
          .select()
          .single();

        if (itemError) {
          console.error('Item insert error:', itemError);
          continue;
        }

        console.log('Inserted item:', insertedItem);

        // Add splits if assigned_to is provided
        if (item.assigned_to && Array.isArray(item.assigned_to) && item.assigned_to.length > 0) {
          const shareAmount = price / item.assigned_to.length;
          
          const splitsToInsert = item.assigned_to.map((userId: string) => ({
            receipt_item_id: insertedItem.id,
            user_id: userId,
            share_amount: shareAmount,
            is_paid: false,
          }));

          const { error: splitError } = await supabaseAdmin
            .from('item_splits')
            .insert(splitsToInsert);

          if (splitError) {
            console.error('Split insert error:', splitError);
          }
        }
      }

      // Calculate and insert user balances
      await updateUserBalances(receipt.id, user.id);
    }

    // Fetch the complete receipt with items and splits
    const { data: receiptItems } = await supabaseAdmin
      .from('receipt_items')
      .select(`
        *,
        item_splits (
          id,
          user_id,
          share_amount,
          is_paid
        )
      `)
      .eq('receipt_id', receipt.id);

    // Add user profiles to splits
    const itemsWithSplitUsers = await Promise.all(
      (receiptItems || []).map(async (item) => {
        const splitsWithUsers = await Promise.all(
          (item.item_splits || []).map(async (split: any) => {
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

    const receiptWithItems = {
      ...receipt,
      receipt_items: itemsWithSplitUsers,
    };

    return NextResponse.json({ 
      message: 'Receipt created',
      receipt: receiptWithItems
    }, { status: 201 });

  } catch (error) {
    console.error('Create receipt error:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
