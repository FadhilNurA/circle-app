import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/group.dart';
import '../models/bill.dart';
import '../services/group_service.dart';
import '../services/bill_service.dart';
import '../services/friend_service.dart';
import 'scan_bill_screen.dart';
import 'bill_detail_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Group? _group;
  String? _userRole;
  List<Bill> _bills = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadGroupData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    setState(() {
      _isLoading = false;
      final groupResult = results[0] as GroupResult<Group>;
      if (groupResult.success) {
        _group = groupResult.data;
        _userRole = groupResult.userRole;
      } else {
        _error = groupResult.message;
      }
      final billsResult = results[1] as BillResult<List<Bill>>;
      if (billsResult.success) _bills = billsResult.data ?? [];
    });
  }

  void _navigateToScanBill() async {
    final result = await Navigator.push<Bill>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ScanBillScreen(groupId: widget.groupId, group: _group),
      ),
    );
    if (result != null) _loadGroupData();
  }

  void _navigateToBillDetail(Bill bill) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BillDetailScreen(
          groupId: widget.groupId,
          billId: bill.id,
          group: _group,
        ),
      ),
    );
    _loadGroupData();
  }

  void _showAddMemberDialog() async {
    final friendsResult = await FriendService.getFriends();
    if (!friendsResult.success || friendsResult.data == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendsResult.message ?? 'Gagal memuat teman'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    final memberIds = _group?.members?.map((m) => m.userId).toSet() ?? {};
    final availableFriends = friendsResult.data!
        .where((f) => !memberIds.contains(f.friend.id))
        .toList();
    if (!mounted) return;
    if (availableFriends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semua teman sudah ada di group ini')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tambah Anggota',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: availableFriends.length,
                itemBuilder: (context, index) {
                  final friend = availableFriends[index];
                  final user = friend.friend;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    leading: _avatar(user.username, user.avatarUrl, 42),
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
                    trailing: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        final result = await GroupService.addMember(
                          groupId: widget.groupId,
                          userId: user.id,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                result.success
                                    ? 'Anggota ditambahkan!'
                                    : result.message ?? 'Gagal',
                              ),
                              backgroundColor: result.success
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          );
                          if (result.success) _loadGroupData();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      child: const Text(
                        'Tambah',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_group?.name ?? 'Group'),
        actions: [
          if (_userRole == 'admin')
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person_add_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              onPressed: _showAddMemberDialog,
            ),
          PopupMenuButton(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppColors.textSecondary,
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded),
                    SizedBox(width: 10),
                    Text('Info Group'),
                  ],
                ),
              ),
              if (_userRole == 'admin')
                const PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings_rounded),
                      SizedBox(width: 10),
                      Text('Pengaturan'),
                    ],
                  ),
                ),
            ],
            onSelected: (value) {},
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('Bills'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('Anggota'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadGroupData,
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [_buildBillsTab(), _buildMembersTab()],
            ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              heroTag: 'group_detail_fab',
              onPressed: _navigateToScanBill,
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text(
                'Scan Bill',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
    );
  }

  Widget _buildBillsTab() {
    if (_bills.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                size: 48,
                color: AppColors.primary.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Belum ada bill',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tekan tombol kamera untuk scan bill.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadGroupData,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        itemCount: _bills.length,
        itemBuilder: (context, index) {
          final bill = _bills[index];
          return GlassCard(
            padding: EdgeInsets.zero,
            child: InkWell(
              onTap: () => _navigateToBillDetail(bill),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getStatusColor(bill.status).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.receipt_rounded,
                        color: _getStatusColor(bill.status),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bill.storeName ?? 'Bill',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            bill.createdAt != null
                                ? _formatDate(bill.createdAt!)
                                : '',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _buildStatusChip(bill.status),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Rp ${_formatNumber(bill.totalAmount)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: AppColors.primaryLight,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final color = _getStatusColor(status);
    String label;
    switch (status) {
      case 'completed':
        label = 'Selesai';
        break;
      case 'splitting':
        label = 'Splitting';
        break;
      default:
        label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'splitting':
        return AppColors.info;
      case 'completed':
        return AppColors.success;
      default:
        return AppColors.textMuted;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Hari ini';
    if (diff.inDays == 1) return 'Kemarin';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatNumber(double number) {
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(0)}K';
    return number.toStringAsFixed(0);
  }

  Widget _buildMembersTab() {
    final members = _group?.members ?? [];
    return RefreshIndicator(
      onRefresh: _loadGroupData,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        itemCount: members.length,
        itemBuilder: (context, index) {
          final member = members[index];
          final user = member.profile;
          return GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                _avatar(user?.username ?? '?', user?.avatarUrl, 42),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.fullName ?? user?.username ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${user?.username ?? ''}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (member.isAdmin)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'ADMIN',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryLight,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _avatar(String name, String? url, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(size * 0.35),
      ),
      child: url != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(size * 0.35),
              child: Image.network(url, fit: BoxFit.cover),
            )
          : Center(
              child: Text(
                name.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
    );
  }
}
