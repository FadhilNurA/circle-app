import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/friendship.dart';
import '../services/group_service.dart';
import '../services/friend_service.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  List<Friend> _friends = [];
  List<String> _selectedMemberIds = [];
  bool _isLoading = false;
  bool _isLoadingFriends = true;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    final result = await FriendService.getFriends();
    setState(() {
      _isLoadingFriends = false;
      if (result.success) _friends = result.data ?? [];
    });
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final result = await GroupService.createGroup(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      memberIds: _selectedMemberIds.isEmpty ? null : _selectedMemberIds,
    );
    setState(() => _isLoading = false);
    if (mounted) {
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Group berhasil dibuat!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Gagal membuat group'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _toggleMember(String friendId) {
    setState(() {
      if (_selectedMemberIds.contains(friendId)) {
        _selectedMemberIds.remove(friendId);
      } else {
        _selectedMemberIds.add(friendId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buat Group')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            // ─── Group Icon ───
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.group_add_rounded,
                  size: 32,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 28),

            TextFormField(
              controller: _nameController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Nama Group',
                hintText: 'Contoh: Kos Putra 42',
                prefixIcon: Icon(Icons.group_rounded),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Masukkan nama group'
                  : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _descriptionController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Deskripsi (Opsional)',
                hintText: 'Deskripsi singkat group...',
                prefixIcon: Icon(Icons.description_rounded),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 28),

            // ─── Friends Selection ───
            Row(
              children: [
                const Text(
                  'Tambah Anggota',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (_selectedMemberIds.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_selectedMemberIds.length} dipilih',
                      style: const TextStyle(
                        color: AppColors.primaryLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Hanya teman yang bisa ditambahkan ke group.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 14),

            if (_isLoadingFriends)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_friends.isEmpty)
              GlassCard(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    Icon(
                      Icons.people_outline_rounded,
                      size: 40,
                      color: AppColors.textMuted.withOpacity(0.5),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Belum ada teman',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tambah teman dulu untuk mengundang ke group.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
            else
              GlassCard(
                padding: EdgeInsets.zero,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _friends.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 60),
                  itemBuilder: (context, index) {
                    final friend = _friends[index];
                    final user = friend.friend;
                    final isSelected = _selectedMemberIds.contains(user.id);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      leading: _avatar(user.username, user.avatarUrl, 40),
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
                      trailing: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textMuted,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 18,
                              )
                            : null,
                      ),
                      onTap: () => _toggleMember(user.id),
                    );
                  },
                ),
              ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: GradientButton(
                onPressed: _isLoading ? null : _createGroup,
                isLoading: _isLoading,
                child: const Text(
                  'Buat Group',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
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
