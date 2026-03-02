import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/group.dart';
import '../models/bill.dart';
import '../services/group_service.dart';
import '../services/bill_service.dart';
import '../services/friend_service.dart';
import 'scan_bill_screen.dart';
import 'bill_detail_screen.dart';
import 'create_bill_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  int _tabIndex = 0;
  Group? _group;
  List<Bill> _bills = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGroupData();
  }

  Future<void> _loadGroupData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final results = await Future.wait([
      GroupService.getGroup(widget.groupId),
      BillService.getBills(widget.groupId),
    ]);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      final groupResult = results[0] as GroupResult<Group>;
      if (groupResult.success && groupResult.data != null) {
        _group = groupResult.data;
      } else {
        _error = groupResult.message;
      }
      final billResult = results[1] as BillResult<List<Bill>>;
      if (billResult.success) {
        _bills = billResult.data ?? [];
      }
    });
  }

  void _navigateToScanBill() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanBillScreen(groupId: widget.groupId, group: _group),
      ),
    );
    if (result != null) _loadGroupData();
  }

  void _navigateToCreateBill() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CreateBillScreen(groupId: widget.groupId, group: _group),
      ),
    );
    if (result != null) _loadGroupData();
  }

  void _navigateToBillDetail(Bill bill) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BillDetailScreen(
          groupId: widget.groupId,
          billId: bill.id,
          group: _group,
        ),
      ),
    ).then((_) => _loadGroupData());
  }

  Future<void> _inviteFriend() async {
    final friendsResult = await FriendService.getFriends();
    if (!mounted || !friendsResult.success) return;
    final friends = friendsResult.data ?? [];
    if (friends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada teman untuk diundang')),
      );
      return;
    }
    final existingMemberIds =
        _group?.members?.map((m) => m.userId).toSet() ?? {};
    final availableFriends = friends
        .where((f) => !existingMemberIds.contains(f.friend.id))
        .toList();
    if (availableFriends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semua teman sudah ada di group')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Undang Teman',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              ...availableFriends.map((f) {
                final user = f.friend;
                final color = AppColors.avatarColor(user.username);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        user.username.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    user.fullName ?? user.username,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    '@${user.username}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                  trailing: SizedBox(
                    height: 32,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final r = await GroupService.addMember(
                          groupId: widget.groupId,
                          userId: user.id,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                r.success
                                    ? 'Berhasil mengundang!'
                                    : (r.message ?? 'Gagal'),
                              ),
                              backgroundColor: r.success
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          );
                          if (r.success) _loadGroupData();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      child: const Text(
                        'Undang',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _group == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 56,
                color: AppColors.textMuted.withOpacity(0.4),
              ),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Group tidak ditemukan',
                style: const TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadGroupData,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildGradientHeader()),
          SliverToBoxAdapter(child: _buildPillTabs()),
          SliverFillRemaining(
            hasScrollBody: true,
            child: IndexedStack(
              index: _tabIndex,
              children: [_buildBillsTab(), _buildMembersTab(), _buildInfoTab()],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabIndex == 0
          ? FloatingActionButton(
              onPressed: () => _showAddBillOptions(),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add_rounded, color: Colors.white),
            )
          : null,
    );
  }

  void _showAddBillOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.document_scanner_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                title: const Text(
                  'Scan Struk',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: const Text(
                  'Scan struk dengan AI',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToScanBill();
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    color: AppColors.accent,
                    size: 22,
                  ),
                ),
                title: const Text(
                  'Input Manual',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: const Text(
                  'Buat tagihan manual',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToCreateBill();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGradientHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 20,
        right: 20,
        bottom: 24,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.person_add_rounded, color: Colors.white),
                onPressed: _inviteFriend,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _group!.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          if (_group!.description != null && _group!.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _group!.description!,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${_group!.memberCount} anggota',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillTabs() {
    final tabs = ['Tagihan', 'Anggota', 'Info'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: List.generate(tabs.length, (i) {
            final isActive = _tabIndex == i;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _tabIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      tabs[i],
                      style: TextStyle(
                        color: isActive ? Colors.white : AppColors.textMuted,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildBillsTab() {
    if (_bills.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  size: 48,
                  color: AppColors.primary.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Belum ada tagihan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Scan struk atau buat tagihan manual.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadGroupData,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
        itemCount: _bills.length,
        itemBuilder: (context, index) {
          final bill = _bills[index];
          return _buildBillCard(bill);
        },
      ),
    );
  }

  Widget _buildBillCard(Bill bill) {
    Color statusColor;
    String statusLabel;
    switch (bill.status) {
      case 'completed':
        statusColor = AppColors.success;
        statusLabel = 'Selesai';
        break;
      case 'splitting':
        statusColor = AppColors.warning;
        statusLabel = 'Splitting';
        break;
      default:
        statusColor = AppColors.textMuted;
        statusLabel = 'Pending';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: () => _navigateToBillDetail(bill),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.receipt_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bill.storeName ?? 'Bill',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Rp ${_formatNumber(bill.totalAmount)}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMembersTab() {
    final members = _group?.members ?? [];
    if (members.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada anggota',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      itemCount: members.length,
      itemBuilder: (context, index) {
        final member = members[index];
        final name =
            member.profile?.fullName ?? member.profile?.username ?? 'Unknown';
        final username = member.profile?.username ?? '';
        final color = AppColors.avatarColor(
          username.isNotEmpty ? username : name,
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 6,
              ),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: member.profile?.avatarUrl != null
                    ? ClipOval(
                        child: Image.network(
                          member.profile!.avatarUrl!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Center(
                        child: Text(
                          (username.isNotEmpty ? username : name)
                              .substring(0, 1)
                              .toUpperCase(),
                          style: TextStyle(
                            color: color,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
              ),
              title: Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: username.isNotEmpty
                  ? Text(
                      '@$username',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    )
                  : null,
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: member.role == 'admin'
                      ? AppColors.primary.withOpacity(0.1)
                      : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  member.role == 'admin' ? 'Admin' : 'Member',
                  style: TextStyle(
                    color: member.role == 'admin'
                        ? AppColors.primary
                        : AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoTab() {
    final totalSpending = _bills.fold<double>(
      0,
      (sum, b) => sum + b.totalAmount,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        children: [
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _infoRow(
                    Icons.calendar_today_rounded,
                    'Dibuat',
                    _group!.createdAt != null
                        ? _formatDate(_group!.createdAt!)
                        : '-',
                  ),
                  const SizedBox(height: 14),
                  _infoRow(
                    Icons.receipt_long_rounded,
                    'Total Tagihan',
                    '${_bills.length} tagihan',
                  ),
                  const SizedBox(height: 14),
                  _infoRow(
                    Icons.payments_rounded,
                    'Total Pengeluaran',
                    'Rp ${_formatNumber(totalSpending)}',
                    valueColor: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatNumber(double number) {
    return number
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
