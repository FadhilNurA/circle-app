import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/bill.dart';
import '../models/group.dart';
import '../services/bill_service.dart';
import '../services/storage_service.dart';

class BillDetailScreen extends StatefulWidget {
  final String groupId;
  final String billId;
  final Group? group;

  const BillDetailScreen({
    super.key,
    required this.groupId,
    required this.billId,
    this.group,
  });

  @override
  State<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends State<BillDetailScreen> {
  Bill? _bill;
  List<UserBalance> _balances = [];
  String? _currentUserId;
  bool _isLoading = true;
  bool _isApproving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBill();
  }

  bool get _isCreator => _bill?.uploadedBy == _currentUserId;

  Future<void> _loadBill() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final currentUser = await StorageService.getUser();
    _currentUserId = currentUser?.id;
    final results = await Future.wait([
      BillService.getBill(groupId: widget.groupId, billId: widget.billId),
      BillService.getBillBalances(
        groupId: widget.groupId,
        billId: widget.billId,
      ),
    ]);
    setState(() {
      _isLoading = false;
      final billResult = results[0] as BillResult<Bill>;
      if (billResult.success) {
        _bill = billResult.data;
      } else {
        _error = billResult.message;
      }
      final balancesResult = results[1] as BillResult<List<UserBalance>>;
      if (balancesResult.success) {
        _balances = balancesResult.data ?? [];
      }
    });
  }

  Future<void> _approvePayment(String userId) async {
    setState(() => _isApproving = true);
    final result = await BillService.approvePayment(
      groupId: widget.groupId,
      billId: widget.billId,
      userId: userId,
    );
    if (mounted) {
      setState(() => _isApproving = false);
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pembayaran di-approve! ✓'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadBill();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Gagal approve'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _rejectPayment(String userId) async {
    setState(() => _isApproving = true);
    final result = await BillService.rejectPayment(
      groupId: widget.groupId,
      billId: widget.billId,
      userId: userId,
    );
    if (mounted) {
      setState(() => _isApproving = false);
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Approval dibatalkan'),
            backgroundColor: AppColors.warning,
          ),
        );
        _loadBill();
      }
    }
  }

  Future<void> _splitEqually() async {
    if (widget.group == null || _bill == null) return;
    final memberIds =
        widget.group!.members?.map((m) => m.userId).toList() ?? [];
    if (memberIds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tidak ada member')));
      return;
    }
    final result = await BillService.splitEqually(
      groupId: widget.groupId,
      billId: widget.billId,
      memberIds: memberIds,
    );
    if (result.success) {
      _loadBill();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bill dibagi rata! ✓'),
            backgroundColor: AppColors.success,
          ),
        );
    } else {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Gagal split'),
            backgroundColor: AppColors.error,
          ),
        );
    }
  }

  Future<void> _showSplitItemDialog(BillItem item) async {
    if (widget.group?.members == null) return;
    final members = widget.group!.members!;
    final selectedMembers = <String, double>{};
    for (var s in item.splits) {
      selectedMembers[s.userId] = s.shareAmount;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            minChildSize: 0.4,
            expand: false,
            builder: (context, scrollController) {
              final splitAmount = selectedMembers.isEmpty
                  ? 0.0
                  : item.totalPrice / selectedMembers.length;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
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
                        Text(
                          'Split: ${item.name}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Rp ${_formatNumber(item.totalPrice)}',
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                        if (selectedMembers.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Masing-masing: Rp ${_formatNumber(splitAmount)}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: members.length,
                      itemBuilder: (context, index) {
                        final member = members[index];
                        final isSelected = selectedMembers.containsKey(
                          member.userId,
                        );
                        return Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withOpacity(0.08)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: CheckboxListTile(
                            value: isSelected,
                            activeColor: AppColors.primary,
                            checkColor: Colors.white,
                            onChanged: (v) {
                              setModalState(() {
                                if (v == true)
                                  selectedMembers[member.userId] = 0;
                                else
                                  selectedMembers.remove(member.userId);
                              });
                            },
                            secondary: _avatar(
                              member.profile?.username,
                              member.profile?.avatarUrl,
                            ),
                            title: Text(
                              member.profile?.fullName ??
                                  member.profile?.username ??
                                  'Unknown',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: member.profile?.username != null
                                ? Text(
                                    '@${member.profile!.username}',
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12,
                                    ),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: GradientButton(
                        onPressed: selectedMembers.isEmpty
                            ? null
                            : () async {
                                Navigator.pop(context);
                                final splits = selectedMembers.keys
                                    .map(
                                      (uid) => {
                                        'user_id': uid,
                                        'share_amount': splitAmount,
                                      },
                                    )
                                    .toList();
                                final result = await BillService.splitItem(
                                  groupId: widget.groupId,
                                  billId: widget.billId,
                                  itemId: item.id,
                                  splits: splits,
                                );
                                if (result.success) _loadBill();
                              },
                        label: 'Split Item',
                        icon: Icons.call_split_rounded,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _avatar(String? name, String? url) {
    final l = (name ?? 'U').substring(0, 1).toUpperCase();
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        shape: BoxShape.circle,
        image: url != null
            ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
            : null,
      ),
      child: url == null
          ? Center(
              child: Text(
                l,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _bill?.storeName ?? 'Detail Bill',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_bill != null && !_bill!.isCompleted)
            PopupMenuButton(
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'split_equal',
                  child: Row(
                    children: [
                      Icon(
                        Icons.call_split_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Split Rata',
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'complete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Tandai Selesai',
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ],
              onSelected: (value) async {
                if (value == 'split_equal')
                  _splitEqually();
                else if (value == 'complete') {
                  final r = await BillService.completeBill(
                    groupId: widget.groupId,
                    billId: widget.billId,
                  );
                  if (r.success) _loadBill();
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _error != null
          ? Center(
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
                    _error!,
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadBill,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            )
          : _bill == null
          ? const Center(
              child: Text(
                'Bill tidak ditemukan',
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _loadBill,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBillHeader(),
                    const SizedBox(height: 20),
                    _buildItemsSection(),
                    const SizedBox(height: 20),
                    _buildSummarySection(),
                    const SizedBox(height: 20),
                    if (_balances.isNotEmpty) _buildBalancesSection(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBillHeader() {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _bill!.storeName ?? 'Unknown Store',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(_bill!.createdAt),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            _buildStatusChip(_bill!.status),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;
    switch (status) {
      case 'completed':
        color = AppColors.success;
        label = 'Selesai';
        break;
      case 'splitting':
        color = AppColors.warning;
        label = 'Splitting';
        break;
      default:
        color = AppColors.textMuted;
        label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Items',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        if (_bill!.items.isEmpty)
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Belum ada item',
                  style: TextStyle(color: AppColors.textMuted.withOpacity(0.7)),
                ),
              ),
            ),
          )
        else
          ...(_bill!.items.map((item) => _buildItemCard(item))),
      ],
    );
  }

  Widget _buildItemCard(BillItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        child: InkWell(
          onTap: _bill!.isCompleted ? null : () => _showSplitItemDialog(item),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${item.quantity}x Rp ${_formatNumber(item.unitPrice)}',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Rp ${_formatNumber(item.totalPrice)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                if (item.splits.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(height: 1, color: AppColors.surfaceBorder),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: item.splits.map((split) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: split.isPaid
                              ? AppColors.success.withOpacity(0.12)
                              : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: split.isPaid
                                ? AppColors.success.withOpacity(0.3)
                                : AppColors.surfaceBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _avatar(split.user?.username, null),
                            const SizedBox(width: 6),
                            Text(
                              'Rp ${_formatNumber(split.shareAmount)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: split.isPaid
                                    ? AppColors.success
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ] else if (!_bill!.isCompleted) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Tap untuk split item ini',
                    style: TextStyle(
                      color: AppColors.primary.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSummaryRow('Subtotal', _bill!.subtotal),
            if (_bill!.taxAmount > 0)
              _buildSummaryRow('Pajak', _bill!.taxAmount),
            if (_bill!.serviceCharge > 0)
              _buildSummaryRow('Service Charge', _bill!.serviceCharge),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Container(height: 1, color: AppColors.surfaceBorder),
            ),
            _buildSummaryRow('Total', _bill!.totalAmount, isBold: true),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
              fontSize: isBold ? 17 : 14,
              color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
          Text(
            'Rp ${_formatNumber(amount)}',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w400,
              fontSize: isBold ? 17 : 14,
              color: isBold ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalancesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Status Pembayaran',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (_isCreator)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Admin Bill',
                  style: TextStyle(
                    color: AppColors.info,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        ...(_balances.map((b) => _buildBalanceCard(b))),
      ],
    );
  }

  Widget _buildBalanceCard(UserBalance balance) {
    final isCurrentUser = balance.userId == _currentUserId;
    final isCreatorBalance = balance.userId == _bill?.uploadedBy;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Stack(
                children: [
                  _avatar(balance.user?.username, balance.user?.avatarUrl),
                  if (balance.isSettled)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 10,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            balance.user?.fullName ??
                                balance.user?.username ??
                                'Unknown',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCurrentUser)
                          const Text(
                            ' (Kamu)',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (isCreatorBalance)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Pembuat',
                              style: TextStyle(
                                color: AppColors.warning,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      balance.isSettled ? 'Sudah bayar ✓' : 'Belum bayar',
                      style: TextStyle(
                        color: balance.isSettled
                            ? AppColors.success
                            : AppColors.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Rp ${_formatNumber(balance.amountOwed)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: balance.isSettled
                          ? AppColors.success
                          : AppColors.textPrimary,
                      decoration: balance.isSettled
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  if (_isCreator && !isCreatorBalance) ...[
                    const SizedBox(height: 6),
                    if (balance.isSettled)
                      SizedBox(
                        height: 30,
                        child: TextButton.icon(
                          onPressed: _isApproving
                              ? null
                              : () => _rejectPayment(balance.userId),
                          icon: const Icon(Icons.undo_rounded, size: 14),
                          label: const Text(
                            'Batalkan',
                            style: TextStyle(fontSize: 11),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.warning,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: 30,
                        child: ElevatedButton.icon(
                          onPressed: _isApproving
                              ? null
                              : () => _showApproveDialog(balance),
                          icon: const Icon(Icons.check_rounded, size: 14),
                          label: const Text(
                            'Acc',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showApproveDialog(UserBalance balance) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Konfirmasi Pembayaran',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apakah ${balance.user?.username ?? 'user'} sudah transfer ke rekening kamu?',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.payments_rounded, color: AppColors.success),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Jumlah',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Rp ${_formatNumber(balance.amountOwed)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Batal',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _approvePayment(balance.userId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Sudah Masuk',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
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

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
