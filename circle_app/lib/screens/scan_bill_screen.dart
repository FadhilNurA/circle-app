import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../config/theme.dart';
import '../models/group.dart';
import '../services/bill_service.dart';
import '../services/scan_receipt_service.dart';

class ScanBillScreen extends StatefulWidget {
  final String groupId;
  final Group? group;

  const ScanBillScreen({super.key, required this.groupId, this.group});

  @override
  State<ScanBillScreen> createState() => _ScanBillScreenState();
}

class _ScanBillScreenState extends State<ScanBillScreen> {
  final ImagePicker _picker = ImagePicker();

  Uint8List? _imageBytes;
  String? _imageFilename;
  bool _isProcessing = false;
  bool _isSaving = false;
  String? _error;

  List<ScannedItem> _items = [];
  String _storeName = '';
  double _tax = 0;
  double _serviceCharge = 0;
  Map<int, Set<String>> _assignedMembers = {};

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 90,
      );
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _imageFilename = pickedFile.name;
          _error = null;
          _items = [];
          _assignedMembers = {};
        });
        await _scanWithAI();
      }
    } catch (e) {
      setState(() => _error = 'Gagal mengambil gambar: $e');
    }
  }

  Future<void> _scanWithAI() async {
    if (_imageBytes == null) return;
    setState(() {
      _isProcessing = true;
      _error = null;
    });
    final result = await ScanReceiptService.scanReceipt(
      imageBytes: _imageBytes!,
      filename: _imageFilename ?? 'receipt.jpg',
    );
    if (!mounted) return;
    if (result.success && result.items != null && result.items!.isNotEmpty) {
      setState(() {
        _items = result.items!;
        _storeName = result.merchantName ?? 'Receipt';
        _tax = result.tax ?? 0;
        _serviceCharge = result.serviceCharge ?? 0;
        _isProcessing = false;
      });
    } else {
      setState(() {
        _isProcessing = false;
        _error = result.error ?? 'Struk tidak terbaca, silakan coba lagi.';
      });
    }
  }

  void _addItem() {
    showDialog(
      context: context,
      builder: (context) => _AddItemDialog(
        onAdd: (name, qty, price) {
          setState(
            () => _items.add(
              ScannedItem(
                name: name,
                qty: qty,
                price: price,
                total: price * qty,
              ),
            ),
          );
        },
      ),
    );
  }

  void _editItem(int index) {
    final item = _items[index];
    showDialog(
      context: context,
      builder: (context) => _AddItemDialog(
        initialName: item.name,
        initialQty: item.qty,
        initialPrice: item.price,
        onAdd: (name, qty, price) {
          setState(
            () => _items[index] = ScannedItem(
              name: name,
              qty: qty,
              price: price,
              total: price * qty,
            ),
          );
        },
      ),
    );
  }

  void _deleteItem(int index) {
    setState(() {
      _items.removeAt(index);
      _assignedMembers.remove(index);
      final n = <int, Set<String>>{};
      _assignedMembers.forEach((k, v) {
        n[k > index ? k - 1 : k] = v;
      });
      _assignedMembers = n;
    });
  }

  void _showAssignMembersDialog(int itemIndex) {
    final item = _items[itemIndex];
    final members = widget.group?.members ?? [];
    Set<String> selectedIds = Set.from(_assignedMembers[itemIndex] ?? {});
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
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
                const SizedBox(height: 20),
                Text(
                  'Siapa yang pesan "${item.name}"?',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Rp ${_formatPrice(item.total)}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: CheckboxListTile(
                    title: const Text(
                      'Pilih Semua',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    value:
                        members.isNotEmpty &&
                        selectedIds.length == members.length,
                    activeColor: AppColors.primary,
                    checkColor: Colors.white,
                    onChanged: (v) {
                      setModalState(() {
                        if (v == true) {
                          selectedIds = members.map((m) => m.userId).toSet();
                        } else {
                          selectedIds.clear();
                        }
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
                const SizedBox(height: 4),
                ...members.map((member) {
                  final isSel = selectedIds.contains(member.userId);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 2),
                    decoration: BoxDecoration(
                      color: isSel
                          ? AppColors.primary.withOpacity(0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: CheckboxListTile(
                      value: isSel,
                      activeColor: AppColors.primary,
                      checkColor: Colors.white,
                      onChanged: (v) {
                        setModalState(() {
                          if (v == true)
                            selectedIds.add(member.userId);
                          else
                            selectedIds.remove(member.userId);
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
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
                      subtitle:
                          selectedIds.contains(member.userId) &&
                              selectedIds.isNotEmpty
                          ? Text(
                              'Rp ${_formatPrice(item.total / selectedIds.length)}',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : null,
                    ),
                  );
                }),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: GradientButton(
                    onPressed: () {
                      setState(() => _assignedMembers[itemIndex] = selectedIds);
                      Navigator.pop(context);
                    },
                    label: selectedIds.isEmpty
                        ? 'Skip Item'
                        : 'Assign ${selectedIds.length} orang',
                    icon: selectedIds.isEmpty
                        ? Icons.skip_next_rounded
                        : Icons.check_rounded,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double get _subtotal => _items.fold(0.0, (sum, item) => sum + item.total);
  double get _grandTotal => _subtotal + _tax + _serviceCharge;
  int get _assignedItemCount => _items
      .asMap()
      .entries
      .where((e) => (_assignedMembers[e.key] ?? {}).isNotEmpty)
      .length;

  Map<String, double> get _memberTotals {
    Map<String, double> totals = {};
    for (var m in (widget.group?.members ?? [])) {
      totals[m.userId] = 0;
    }
    for (int i = 0; i < _items.length; i++) {
      final assigned = _assignedMembers[i] ?? {};
      if (assigned.isNotEmpty) {
        double pp = _items[i].total / assigned.length;
        for (var id in assigned) {
          totals[id] = (totals[id] ?? 0) + pp;
        }
      }
    }
    double ta = totals.values.fold(0.0, (a, b) => a + b);
    if (ta > 0 && (_tax > 0 || _serviceCharge > 0)) {
      double extra = _tax + _serviceCharge;
      for (var id in totals.keys) {
        totals[id] = totals[id]! + (extra * totals[id]! / ta);
      }
    }
    return totals;
  }

  Future<void> _saveBill() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tambah minimal 1 item'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (_assignedItemCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assign minimal 1 item ke member'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    setState(() => _isSaving = true);
    final result = await BillService.createBill(
      groupId: widget.groupId,
      storeName: _storeName,
      totalAmount: _grandTotal,
      taxAmount: _tax,
      serviceCharge: _serviceCharge,
      items: _items
          .asMap()
          .entries
          .map(
            (e) => {
              'name': e.value.name,
              'price': e.value.total,
              'quantity': e.value.qty,
              'assigned_to': (_assignedMembers[e.key] ?? {}).toList(),
            },
          )
          .toList(),
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bill berhasil disimpan! ✓'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, result.data);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Gagal menyimpan'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _avatar(String? name, String? url) {
    final l = (name ?? 'U').substring(0, 1).toUpperCase();
    final color = AppColors.avatarColor(name ?? 'U');
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        shape: BoxShape.circle,
        image: url != null
            ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
            : null,
      ),
      child: url == null
          ? Center(
              child: Text(
                l,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Scan Struk',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'AI powered scanning',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        toolbarHeight: 64,
        actions: [
          if (_imageBytes != null && _items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _isSaving ? null : _saveBill,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : const Text(
                        'Simpan',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
        ],
      ),
      body: _imageBytes == null ? _buildImagePicker() : _buildBillEditor(),
    );
  }

  Widget _buildImagePicker() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.document_scanner_rounded,
                size: 64,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Scan Struk dengan AI',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Foto struk belanja dan AI akan mengekstrak\nsemua item secara otomatis',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: GradientButton(
                      onPressed: () => _pickImage(ImageSource.camera),
                      label: 'Kamera',
                      icon: Icons.camera_alt_rounded,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_rounded, size: 20),
                      label: const Text(
                        'Galeri',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillEditor() {
    if (_isProcessing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'AI sedang membaca struk...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Mengekstrak nama item, harga, dan jumlah',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 56,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: AppColors.error),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 44,
                    child: GradientButton(
                      onPressed: _scanWithAI,
                      label: 'Coba Lagi',
                      icon: Icons.refresh_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_rounded, size: 18),
                      label: const Text('Ganti Foto'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        _buildImagePreview(),
        Expanded(child: _buildItemsList()),
        _buildSummary(),
      ],
    );
  }

  Widget _buildImagePreview() {
    return Container(
      height: 120,
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(
              _imageBytes!,
              width: double.infinity,
              height: 120,
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              children: [
                _imgBtn(
                  Icons.camera_alt_rounded,
                  () => _pickImage(ImageSource.camera),
                ),
                const SizedBox(width: 8),
                _imgBtn(
                  Icons.photo_library_rounded,
                  () => _pickImage(ImageSource.gallery),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 10,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _storeName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imgBtn(IconData icon, VoidCallback onPressed) {
    return Material(
      color: AppColors.surface.withOpacity(0.8),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: AppColors.textPrimary, size: 18),
        ),
      ),
    );
  }

  Widget _buildItemsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Items',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'AI Scan',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _items.isEmpty
                        ? 'Tambahkan item dari struk'
                        : '$_assignedItemCount/${_items.length} item sudah di-assign',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 36,
                child: ElevatedButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text(
                    'Tambah',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(height: 1, color: AppColors.surfaceBorder),
        Expanded(
          child: _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long_rounded,
                        size: 56,
                        color: AppColors.textMuted.withOpacity(0.3),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Belum ada item',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _items.length,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemBuilder: (_, i) => _buildItemTile(i),
                ),
        ),
      ],
    );
  }

  Widget _buildItemTile(int index) {
    final item = _items[index];
    final assigned = _assignedMembers[index] ?? {};
    final isAsgn = assigned.isNotEmpty;
    final members = widget.group?.members ?? [];
    List<String> names = [];
    for (var id in assigned) {
      final m = members.firstWhere(
        (m) => m.userId == id,
        orElse: () => members.first,
      );
      names.add(m.profile?.username ?? '?');
    }
    return Dismissible(
      key: Key('item_$index'),
      background: Container(
        color: AppColors.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteItem(index),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAssignMembersDialog(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isAsgn
                        ? AppColors.success.withOpacity(0.15)
                        : AppColors.warning.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isAsgn
                        ? Icons.check_circle_rounded
                        : Icons.person_add_rounded,
                    color: isAsgn ? AppColors.success : AppColors.warning,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          fontSize: 15,
                        ),
                      ),
                      if (item.qty > 1)
                        Text(
                          '${item.qty}x Rp ${_formatPrice(item.price)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      if (isAsgn)
                        Text(
                          names.join(', '),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      else
                        const Text(
                          'Tap untuk assign',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  'Rp ${_formatPrice(item.total)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(
                    Icons.edit_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  onPressed: () => _editItem(index),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final members = widget.group?.members ?? [];
    final totals = _memberTotals;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.surfaceBorder)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_assignedItemCount > 0) ...[
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      const Text(
                        'Ringkasan per orang:',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...members
                          .where((m) => (totals[m.userId] ?? 0) > 0)
                          .map(
                            (m) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    m.profile?.username ?? '?',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    'Rp ${_formatPrice(totals[m.userId] ?? 0)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_tax > 0 || _serviceCharge > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    if (_tax > 0)
                      Text(
                        'Tax: Rp ${_formatPrice(_tax)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    if (_tax > 0 && _serviceCharge > 0)
                      const Text(
                        ' • ',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    if (_serviceCharge > 0)
                      Text(
                        'Service: Rp ${_formatPrice(_serviceCharge)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'Rp ${_formatPrice(_grandTotal)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                if (_items.isNotEmpty && _assignedItemCount < _items.length)
                  TextButton(
                    onPressed: () {
                      int idx = _items
                          .asMap()
                          .entries
                          .firstWhere(
                            (e) => (_assignedMembers[e.key] ?? {}).isEmpty,
                            orElse: () => _items.asMap().entries.first,
                          )
                          .key;
                      _showAssignMembersDialog(idx);
                    },
                    child: Text(
                      '${_items.length - _assignedItemCount} belum di-assign',
                      style: const TextStyle(color: AppColors.warning),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(double price) {
    return price
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
  }
}

class _AddItemDialog extends StatefulWidget {
  final String? initialName;
  final int? initialQty;
  final double? initialPrice;
  final Function(String, int, double) onAdd;
  const _AddItemDialog({
    this.initialName,
    this.initialQty,
    this.initialPrice,
    required this.onAdd,
  });
  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  late TextEditingController _nameC, _qtyC, _priceC;
  @override
  void initState() {
    super.initState();
    _nameC = TextEditingController(text: widget.initialName);
    _qtyC = TextEditingController(text: (widget.initialQty ?? 1).toString());
    _priceC = TextEditingController(
      text: widget.initialPrice?.toStringAsFixed(0) ?? '',
    );
  }

  @override
  void dispose() {
    _nameC.dispose();
    _qtyC.dispose();
    _priceC.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, {String? hint, String? prefix}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefix,
        labelStyle: const TextStyle(color: AppColors.textMuted),
        hintStyle: TextStyle(color: AppColors.textMuted.withOpacity(0.5)),
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        widget.initialName != null ? 'Edit Item' : 'Tambah Item',
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameC,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: _dec('Nama Item', hint: 'cth: Nasi Goreng'),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _qtyC,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: _dec('Jumlah'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceC,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: _dec('Harga Satuan', prefix: 'Rp '),
            keyboardType: TextInputType.number,
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
            final name = _nameC.text.trim();
            final qty = int.tryParse(_qtyC.text) ?? 1;
            final price = double.tryParse(_priceC.text) ?? 0;
            if (name.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Masukkan nama item'),
                  backgroundColor: AppColors.warning,
                ),
              );
              return;
            }
            if (price <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Masukkan harga yang valid'),
                  backgroundColor: AppColors.warning,
                ),
              );
              return;
            }
            widget.onAdd(name, qty, price);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(widget.initialName != null ? 'Update' : 'Tambah'),
        ),
      ],
    );
  }
}
