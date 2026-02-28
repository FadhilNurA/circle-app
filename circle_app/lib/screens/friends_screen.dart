import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/friendship.dart';
import '../services/friend_service.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Friend> _friends = [];
  List<FriendRequest> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      FriendService.getFriends(),
      FriendService.getReceivedRequests(),
    ]);
    setState(() {
      _isLoading = false;
      if (results[0].success)
        _friends = (results[0].data as List<Friend>?) ?? [];
      if (results[1].success)
        _requests = (results[1].data as List<FriendRequest>?) ?? [];
    });
  }

  void _showAddFriendDialog() {
    final controller = TextEditingController();
    bool isLoading = false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tambah Teman'),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Username',
              hintText: 'Masukkan username teman',
              prefixIcon: Icon(Icons.person_search_rounded),
            ),
            enabled: !isLoading,
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (controller.text.trim().isEmpty) return;
                      setDialogState(() => isLoading = true);
                      final result = await FriendService.sendFriendRequest(
                        username: controller.text.trim(),
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              result.success
                                  ? 'Permintaan pertemanan terkirim!'
                                  : result.message ?? 'Gagal mengirim',
                            ),
                            backgroundColor: result.success
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        );
                        if (result.success) _loadData();
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Kirim'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptRequest(FriendRequest request) async {
    final result = await FriendService.acceptRequest(friendshipId: request.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.success ? 'Permintaan diterima!' : result.message ?? 'Gagal',
          ),
          backgroundColor: result.success ? AppColors.success : AppColors.error,
        ),
      );
      if (result.success) _loadData();
    }
  }

  Future<void> _rejectRequest(FriendRequest request) async {
    final result = await FriendService.rejectRequest(friendshipId: request.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.success ? 'Permintaan ditolak' : result.message ?? 'Gagal',
          ),
          backgroundColor: result.success ? AppColors.warning : AppColors.error,
        ),
      );
      if (result.success) _loadData();
    }
  }

  Future<void> _removeFriend(Friend friend) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Teman'),
        content: Text(
          'Yakin ingin menghapus ${friend.friend.fullName ?? friend.friend.username}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final result = await FriendService.removeFriend(
        friendshipId: friend.friendshipId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.success ? 'Teman dihapus' : result.message ?? 'Gagal',
            ),
            backgroundColor: result.success
                ? AppColors.warning
                : AppColors.error,
          ),
        );
        if (result.success) _loadData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.person_add_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            onPressed: _showAddFriendDialog,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Teman'),
                  if (_friends.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _badge('${_friends.length}', AppColors.primary),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Permintaan'),
                  if (_requests.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _badge('${_requests.length}', AppColors.error),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_buildFriendsList(), _buildRequestsList()],
            ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildFriendsList() {
    if (_friends.isEmpty) {
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
                Icons.people_outline_rounded,
                size: 48,
                color: AppColors.primary.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Belum ada teman',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tambah teman untuk buat group bersama.',
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddFriendDialog,
              icon: const Icon(Icons.person_add_rounded, size: 20),
              label: const Text('Tambah Teman'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        itemCount: _friends.length,
        itemBuilder: (context, index) => _buildFriendCard(_friends[index]),
      ),
    );
  }

  Widget _buildFriendCard(Friend friend) {
    final user = friend.friend;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          _avatar(user.username, user.avatarUrl, 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName ?? user.username,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@${user.username}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppColors.textMuted,
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'remove',
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_remove_rounded,
                      color: AppColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Hapus Teman',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'remove') _removeFriend(friend);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList() {
    if (_requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.inbox_rounded,
                size: 48,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Tidak ada permintaan',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Permintaan pertemanan akan muncul di sini.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        itemCount: _requests.length,
        itemBuilder: (context, index) => _buildRequestCard(_requests[index]),
      ),
    );
  }

  Widget _buildRequestCard(FriendRequest request) {
    final user = request.requester;
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _avatar(user.username, user.avatarUrl, 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName ?? user.username,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@${user.username}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _circleActionButton(
                Icons.close_rounded,
                AppColors.error,
                () => _rejectRequest(request),
              ),
              const SizedBox(width: 8),
              _circleActionButton(
                Icons.check_rounded,
                AppColors.success,
                () => _acceptRequest(request),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circleActionButton(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
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
