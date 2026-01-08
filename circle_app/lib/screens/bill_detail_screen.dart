import 'package:flutter/material.dart';
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

    // Get current user
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
            backgroundColor: Colors.green,
          ),
        );
        _loadBill();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Gagal approve'),
            backgroundColor: Colors.red,
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
            backgroundColor: Colors.orange,
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
      ).showSnackBar(const SnackBar(content: Text('No members to split with')));
      return;
    }

    final result = await BillService.splitEqually(
      groupId: widget.groupId,
      billId: widget.billId,
      memberIds: memberIds,
    );

    if (result.success) {
      _loadBill();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bill split equally!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Failed to split'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showSplitItemDialog(BillItem item) async {
    if (widget.group?.members == null) return;

    final members = widget.group!.members!;
    final selectedMembers = <String, double>{};

    // Pre-fill with existing splits
    for (var split in item.splits) {
      selectedMembers[split.userId] = split.shareAmount;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
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
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Split: ${item.name}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Rp ${_formatNumber(item.totalPrice)}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          if (selectedMembers.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Each pays: Rp ${_formatNumber(splitAmount)}',
                              style: const TextStyle(
                                color: Colors.deepPurple,
                                fontWeight: FontWeight.bold,
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

                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (value) {
                              setModalState(() {
                                if (value == true) {
                                  selectedMembers[member.userId] = 0;
                                } else {
                                  selectedMembers.remove(member.userId);
                                }
                              });
                            },
                            secondary: CircleAvatar(
                              backgroundColor: Colors.deepPurple,
                              child: Text(
                                (member.profile?.username ?? 'U')
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(
                              member.profile?.fullName ??
                                  member.profile?.username ??
                                  'Unknown',
                            ),
                            subtitle: member.profile?.username != null
                                ? Text('@${member.profile!.username}')
                                : null,
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: selectedMembers.isEmpty
                              ? null
                              : () async {
                                  Navigator.pop(context);

                                  final splits = selectedMembers.keys
                                      .map(
                                        (userId) => {
                                          'user_id': userId,
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

                                  if (result.success) {
                                    _loadBill();
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Split Item'),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_bill?.storeName ?? 'Bill Details'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          if (_bill != null && !_bill!.isCompleted)
            PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'split_equal',
                  child: Row(
                    children: [
                      Icon(Icons.call_split),
                      SizedBox(width: 8),
                      Text('Split Equally'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'complete',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle),
                      SizedBox(width: 8),
                      Text('Mark Complete'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) async {
                if (value == 'split_equal') {
                  _splitEqually();
                } else if (value == 'complete') {
                  final result = await BillService.completeBill(
                    groupId: widget.groupId,
                    billId: widget.billId,
                  );
                  if (result.success) {
                    _loadBill();
                  }
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(_error!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadBill,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _bill == null
          ? const Center(child: Text('Bill not found'))
          : RefreshIndicator(
              onRefresh: _loadBill,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bill header
                    _buildBillHeader(),
                    const SizedBox(height: 24),

                    // Items section
                    _buildItemsSection(),
                    const SizedBox(height: 24),

                    // Summary section
                    _buildSummarySection(),
                    const SizedBox(height: 24),

                    // Balances section
                    if (_balances.isNotEmpty) _buildBalancesSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBillHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.receipt_long,
                color: Colors.deepPurple,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _bill!.storeName ?? 'Unknown Store',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(_bill!.createdAt),
                    style: TextStyle(color: Colors.grey[600]),
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
        color = Colors.green;
        label = 'Completed';
        break;
      case 'splitting':
        color = Colors.orange;
        label = 'Splitting';
        break;
      default:
        color = Colors.grey;
        label = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
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
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (_bill!.items.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No items added yet',
                  style: TextStyle(color: Colors.grey[600]),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: _bill!.isCompleted ? null : () => _showSplitItemDialog(item),
        borderRadius: BorderRadius.circular(12),
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
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${item.quantity}x Rp ${_formatNumber(item.unitPrice)}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Rp ${_formatNumber(item.totalPrice)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              if (item.splits.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: item.splits.map((split) {
                    return Chip(
                      avatar: CircleAvatar(
                        backgroundColor: Colors.deepPurple,
                        child: Text(
                          (split.user?.username ?? 'U')
                              .substring(0, 1)
                              .toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      label: Text(
                        'Rp ${_formatNumber(split.shareAmount)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: split.isPaid
                          ? Colors.green.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                    );
                  }).toList(),
                ),
              ] else if (!_bill!.isCompleted) ...[
                const SizedBox(height: 8),
                Text(
                  'Tap to split this item',
                  style: TextStyle(
                    color: Colors.deepPurple.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    return Card(
      color: Colors.deepPurple.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSummaryRow('Subtotal', _bill!.subtotal),
            if (_bill!.taxAmount > 0) _buildSummaryRow('Tax', _bill!.taxAmount),
            if (_bill!.serviceCharge > 0)
              _buildSummaryRow('Service Charge', _bill!.serviceCharge),
            const Divider(),
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
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 18 : 14,
            ),
          ),
          Text(
            'Rp ${_formatNumber(amount)}',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 18 : 14,
              color: isBold ? Colors.deepPurple : null,
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (_isCreator)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Admin Bill',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ...(_balances.map((balance) => _buildBalanceCard(balance))),
      ],
    );
  }

  Widget _buildBalanceCard(UserBalance balance) {
    final isCurrentUser = balance.userId == _currentUserId;
    final isCreatorBalance = balance.userId == _bill?.uploadedBy;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isCurrentUser ? Colors.deepPurple.withOpacity(0.05) : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Avatar with status indicator
            Stack(
              children: [
                CircleAvatar(
                  backgroundColor: balance.isSettled
                      ? Colors.green
                      : Colors.deepPurple,
                  backgroundImage: balance.user?.avatarUrl != null
                      ? NetworkImage(balance.user!.avatarUrl!)
                      : null,
                  child: balance.user?.avatarUrl == null
                      ? Text(
                          (balance.user?.username ?? 'U')
                              .substring(0, 1)
                              .toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        )
                      : null,
                ),
                if (balance.isSettled)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.green,
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
            // Name and status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        balance.user?.fullName ??
                            balance.user?.username ??
                            'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (isCurrentUser)
                        const Text(
                          ' (Kamu)',
                          style: TextStyle(
                            color: Colors.deepPurple,
                            fontSize: 12,
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
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Pembuat',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    balance.isSettled ? 'Sudah bayar ✓' : 'Belum bayar',
                    style: TextStyle(
                      color: balance.isSettled ? Colors.green : Colors.orange,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Rp ${_formatNumber(balance.amountOwed)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: balance.isSettled ? Colors.green : Colors.black,
                    decoration: balance.isSettled
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                // Approve/reject button (only for bill creator, not for themselves)
                if (_isCreator && !isCreatorBalance) ...[
                  const SizedBox(height: 8),
                  if (balance.isSettled)
                    TextButton.icon(
                      onPressed: _isApproving
                          ? null
                          : () => _rejectPayment(balance.userId),
                      icon: const Icon(Icons.undo, size: 16),
                      label: const Text('Batalkan'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 32),
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: _isApproving
                          ? null
                          : () => _showApproveDialog(balance),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Acc'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(0, 32),
                      ),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showApproveDialog(UserBalance balance) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Pembayaran'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apakah ${balance.user?.username ?? 'user'} sudah transfer ke rekening kamu?',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.payments, color: Colors.green),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Jumlah',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      Text(
                        'Rp ${_formatNumber(balance.amountOwed)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
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
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _approvePayment(balance.userId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sudah Masuk'),
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
          (Match m) => '${m[1]}.',
        );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
