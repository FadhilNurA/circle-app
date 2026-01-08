import { NextRequest, NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';

// GET - Get receipt details with items and splits
export async function GET(
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

    // Get receipt basic info
    const { data: receipt, error: receiptError } = await supabaseAdmin
      .from('receipts')
      .select('*')
      .eq('id', receiptId)
      .eq('group_id', groupId)
      .single();

    if (receiptError) {
      return NextResponse.json({ error: receiptError.message }, { status: 500 });
    }

    // Get uploaded_by profile
    let uploadedByUser = null;
    if (receipt.uploaded_by) {
      const { data: profile } = await supabaseAdmin
        .from('profiles')
        .select('id, username, full_name, avatar_url')
        .eq('id', receipt.uploaded_by)
        .single();
      uploadedByUser = profile;
    }

    // Get receipt items
    const { data: items } = await supabaseAdmin
      .from('receipt_items')
      .select('*')
      .eq('receipt_id', receiptId);

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

    // Get user balances for this receipt
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

    return NextResponse.json({ 
      receipt: { ...receipt, uploaded_by_user: uploadedByUser, receipt_items: itemsWithSplits }, 
      balances 
    });

  } catch (error) {
    console.error('Get receipt error:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

// PUT - Update receipt (add items, update total)
export async function PUT(
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

    const { store_name, total_amount, tax_amount, service_charge, status } = await request.json();

    const { data: receipt, error: updateError } = await supabaseAdmin
      .from('receipts')
      .update({
        store_name,
        total_amount,
        tax_amount,
        service_charge,
        status,
        updated_at: new Date().toISOString(),
      })
      .eq('id', receiptId)
      .eq('group_id', groupId)
      .select()
      .single();

    if (updateError) {
      return NextResponse.json({ error: updateError.message }, { status: 500 });
    }

    return NextResponse.json({ message: 'Receipt updated', receipt });

  } catch (error) {
    console.error('Update receipt error:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

// DELETE - Delete receipt
export async function DELETE(
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

    // Check if user uploaded this receipt
    const { data: receipt } = await supabaseAdmin
      .from('receipts')
      .select('uploaded_by')
      .eq('id', receiptId)
      .single();

    if (!receipt || receipt.uploaded_by !== user.id) {
      return NextResponse.json({ error: 'Not authorized to delete this receipt' }, { status: 403 });
    }

    const { error: deleteError } = await supabaseAdmin
      .from('receipts')
      .delete()
      .eq('id', receiptId);

    if (deleteError) {
      return NextResponse.json({ error: deleteError.message }, { status: 500 });
    }

    return NextResponse.json({ message: 'Receipt deleted' });

  } catch (error) {
    console.error('Delete receipt error:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
