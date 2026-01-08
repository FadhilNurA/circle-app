-- =============================================
-- CIRCLE APP DATABASE SCHEMA
-- Run this in Supabase SQL Editor
-- =============================================

-- =============================================
-- DROP EXISTING TABLES (for refresh/reset)
-- Order matters due to foreign key constraints
-- =============================================
DROP TABLE IF EXISTS friendships CASCADE;
DROP TABLE IF EXISTS user_balances CASCADE;
DROP TABLE IF EXISTS item_splits CASCADE;
DROP TABLE IF EXISTS receipt_items CASCADE;
DROP TABLE IF EXISTS receipts CASCADE;
DROP TABLE IF EXISTS messages CASCADE;
DROP TABLE IF EXISTS group_members CASCADE;
DROP TABLE IF EXISTS groups CASCADE;

-- =============================================
-- CREATE TABLES
-- =============================================

-- 1. GROUPS TABLE
CREATE TABLE groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  image_url TEXT,
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. GROUP MEMBERS TABLE
CREATE TABLE group_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT DEFAULT 'member' CHECK (role IN ('admin', 'member')),
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(group_id, user_id)
);

-- 3. MESSAGES TABLE (for group chat)
CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
  sender_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  content TEXT NOT NULL,
  message_type TEXT DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'receipt')),
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. RECEIPTS TABLE (for split bill)
CREATE TABLE receipts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
  uploaded_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  image_url TEXT,
  store_name TEXT,
  total_amount DECIMAL(12, 2) NOT NULL DEFAULT 0,
  tax_amount DECIMAL(12, 2) DEFAULT 0,
  service_charge DECIMAL(12, 2) DEFAULT 0,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'splitting', 'completed')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. RECEIPT ITEMS TABLE
CREATE TABLE receipt_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  receipt_id UUID REFERENCES receipts(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  quantity INTEGER DEFAULT 1,
  unit_price DECIMAL(12, 2) NOT NULL,
  total_price DECIMAL(12, 2) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. ITEM SPLITS TABLE (who pays for what)
CREATE TABLE item_splits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  receipt_item_id UUID REFERENCES receipt_items(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  share_amount DECIMAL(12, 2) NOT NULL,
  is_paid BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(receipt_item_id, user_id)
);

-- 7. USER BALANCES (summary of who owes whom)
CREATE TABLE user_balances (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  receipt_id UUID REFERENCES receipts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  amount_owed DECIMAL(12, 2) NOT NULL DEFAULT 0,
  amount_paid DECIMAL(12, 2) NOT NULL DEFAULT 0,
  is_settled BOOLEAN DEFAULT FALSE,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(receipt_id, user_id)
);

-- =============================================
-- INDEXES FOR PERFORMANCE
-- =============================================
CREATE INDEX idx_group_members_group_id ON group_members(group_id);
CREATE INDEX idx_group_members_user_id ON group_members(user_id);
CREATE INDEX idx_messages_group_id ON messages(group_id);
CREATE INDEX idx_messages_created_at ON messages(created_at DESC);
CREATE INDEX idx_receipts_group_id ON receipts(group_id);
CREATE INDEX idx_receipt_items_receipt_id ON receipt_items(receipt_id);
CREATE INDEX idx_item_splits_receipt_item_id ON item_splits(receipt_item_id);
CREATE INDEX idx_item_splits_user_id ON item_splits(user_id);

-- =============================================
-- ROW LEVEL SECURITY POLICIES
-- =============================================

-- Groups RLS
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view groups they belong to" ON groups
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM group_members WHERE group_members.group_id = id AND group_members.user_id = auth.uid())
  );

CREATE POLICY "Users can create groups" ON groups
  FOR INSERT WITH CHECK (auth.uid() = created_by);

CREATE POLICY "Admins can update their groups" ON groups
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM group_members WHERE group_members.group_id = id AND group_members.user_id = auth.uid() AND group_members.role = 'admin')
  );

CREATE POLICY "Admins can delete their groups" ON groups
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM group_members WHERE group_members.group_id = id AND group_members.user_id = auth.uid() AND group_members.role = 'admin')
  );

-- Group Members RLS
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;

-- Use direct user_id check to avoid recursion
CREATE POLICY "Users can view their own membership" ON group_members
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can view members in same group" ON group_members
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM group_members my_membership 
      WHERE my_membership.group_id = group_members.group_id 
      AND my_membership.user_id = auth.uid()
    )
  );

CREATE POLICY "Creator can add first member" ON group_members
  FOR INSERT WITH CHECK (
    -- Allow if user is the creator adding themselves as first admin
    (user_id = auth.uid() AND role = 'admin')
    OR
    -- Allow if user is already an admin of the group
    EXISTS (
      SELECT 1 FROM group_members 
      WHERE group_members.group_id = group_members.group_id 
      AND group_members.user_id = auth.uid() 
      AND group_members.role = 'admin'
    )
  );

CREATE POLICY "Admins can remove members" ON group_members
  FOR DELETE USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM group_members admin_check 
      WHERE admin_check.group_id = group_members.group_id 
      AND admin_check.user_id = auth.uid() 
      AND admin_check.role = 'admin'
    )
  );

-- Messages RLS
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view messages in their groups" ON messages
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM group_members WHERE group_members.group_id = messages.group_id AND group_members.user_id = auth.uid())
  );

CREATE POLICY "Users can send messages to their groups" ON messages
  FOR INSERT WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (SELECT 1 FROM group_members WHERE group_members.group_id = messages.group_id AND group_members.user_id = auth.uid())
  );

-- Receipts RLS
ALTER TABLE receipts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view receipts in their groups" ON receipts
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM group_members WHERE group_members.group_id = receipts.group_id AND group_members.user_id = auth.uid())
  );

CREATE POLICY "Users can create receipts in their groups" ON receipts
  FOR INSERT WITH CHECK (
    uploaded_by = auth.uid()
    AND EXISTS (SELECT 1 FROM group_members WHERE group_members.group_id = receipts.group_id AND group_members.user_id = auth.uid())
  );

CREATE POLICY "Users can update receipts they created" ON receipts
  FOR UPDATE USING (uploaded_by = auth.uid());

CREATE POLICY "Users can delete receipts they created" ON receipts
  FOR DELETE USING (uploaded_by = auth.uid());

-- Receipt Items RLS
ALTER TABLE receipt_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view receipt items" ON receipt_items
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM receipts r
      JOIN group_members gm ON gm.group_id = r.group_id
      WHERE r.id = receipt_items.receipt_id AND gm.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can manage receipt items they created" ON receipt_items
  FOR ALL USING (
    EXISTS (SELECT 1 FROM receipts WHERE receipts.id = receipt_items.receipt_id AND receipts.uploaded_by = auth.uid())
  );

-- Item Splits RLS
ALTER TABLE item_splits ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view splits in their groups" ON item_splits
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM receipt_items ri
      JOIN receipts r ON r.id = ri.receipt_id
      JOIN group_members gm ON gm.group_id = r.group_id
      WHERE ri.id = item_splits.receipt_item_id AND gm.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can manage their own splits" ON item_splits
  FOR ALL USING (user_id = auth.uid());

CREATE POLICY "Receipt owner can manage splits" ON item_splits
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM receipt_items ri
      JOIN receipts r ON r.id = ri.receipt_id
      WHERE ri.id = item_splits.receipt_item_id AND r.uploaded_by = auth.uid()
    )
  );

-- User Balances RLS
ALTER TABLE user_balances ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their balances" ON user_balances
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can view balances in their receipts" ON user_balances
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM receipts WHERE receipts.id = user_balances.receipt_id AND receipts.uploaded_by = auth.uid())
  );

CREATE POLICY "Receipt owner can manage balances" ON user_balances
  FOR ALL USING (
    EXISTS (SELECT 1 FROM receipts WHERE receipts.id = user_balances.receipt_id AND receipts.uploaded_by = auth.uid())
  );

-- =============================================
-- 8. FRIENDSHIPS TABLE (for friend system)
-- =============================================
CREATE TABLE friendships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  addressee_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'blocked')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(requester_id, addressee_id)
);

-- Index for friendships
CREATE INDEX idx_friendships_requester_id ON friendships(requester_id);
CREATE INDEX idx_friendships_addressee_id ON friendships(addressee_id);
CREATE INDEX idx_friendships_status ON friendships(status);

-- Friendships RLS
ALTER TABLE friendships ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their friendships" ON friendships
  FOR SELECT USING (
    requester_id = auth.uid() OR addressee_id = auth.uid()
  );

CREATE POLICY "Users can send friend requests" ON friendships
  FOR INSERT WITH CHECK (requester_id = auth.uid());

CREATE POLICY "Users can update friendships they're part of" ON friendships
  FOR UPDATE USING (
    addressee_id = auth.uid() OR requester_id = auth.uid()
  );

CREATE POLICY "Users can delete their friendships" ON friendships
  FOR DELETE USING (
    requester_id = auth.uid() OR addressee_id = auth.uid()
  );

-- =============================================
-- OPTIONAL: DISABLE RLS FOR DEVELOPMENT
-- Uncomment below if using service_role key in backend
-- (Backend already handles authorization)
-- =============================================
-- ALTER TABLE groups DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE group_members DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE messages DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE receipts DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE receipt_items DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE item_splits DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE user_balances DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE friendships DISABLE ROW LEVEL SECURITY;
