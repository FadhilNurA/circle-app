import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/group.dart';
import '../services/bill_service.dart';

class ScanBillScreen extends StatefulWidget {
  final String groupId;
  final Group? group;

  const ScanBillScreen({super.key, required this.groupId, this.group});

  @override
  State<ScanBillScreen> createState() => _ScanBillScreenState();
}

class _ScanBillScreenState extends State<ScanBillScreen> {
  final ImagePicker _picker = ImagePicker();
  TextRecognizer? _textRecognizer;

  Uint8List? _imageBytes;
  File? _imageFile;
  bool _isProcessing = false;
  bool _isSaving = false;
  String? _error;

  // Items with assigned members
  List<BillItemData> _items = [];
  String _storeName = '';

  // Tax & service
  double _tax = 0;
  double _serviceCharge = 0;

  @override
  void dispose() {
    if (!kIsWeb && _textRecognizer != null) {
      _textRecognizer!.close();
    }
    super.dispose();
  }

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
          if (!kIsWeb) {
            _imageFile = File(pickedFile.path);
          }
          _error = null;
        });
        await _processImage();
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to pick image: $e';
      });
    }
  }

  Future<void> _processImage() async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      if (kIsWeb) {
        // OCR not available on web
        setState(() {
          _isProcessing = false;
          _storeName = 'Receipt';
        });
        return;
      }

      _textRecognizer ??= TextRecognizer();
      final inputImage = InputImage.fromFile(_imageFile!);
      final recognizedText = await _textRecognizer!.processImage(inputImage);
      _parseReceiptText(recognizedText.text);

      setState(() {
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _error = 'Failed to process: $e';
      });
    }
  }

  void _parseReceiptText(String text) {
    final lines = text.split('\n');
    List<BillItemData> items = [];
    String storeName = '';

    final pricePattern = RegExp(r'(\d{1,3}(?:[.,]\d{3})*|\d+)\s*$');
    final totalPattern = RegExp(
      r'(total|subtotal|grand|jumlah)',
      caseSensitive: false,
    );
    final taxPattern = RegExp(r'(tax|pajak|ppn|pb1)', caseSensitive: false);
    final servicePattern = RegExp(
      r'(service|servis|charge)',
      caseSensitive: false,
    );

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].trim();
      if (line.isEmpty) continue;

      // First non-empty line is store name
      if (i < 3 && storeName.isEmpty && !pricePattern.hasMatch(line)) {
        storeName = line;
        continue;
      }

      // Skip total lines
      if (totalPattern.hasMatch(line)) continue;

      // Check for tax
      if (taxPattern.hasMatch(line)) {
        final match = pricePattern.firstMatch(line);
        if (match != null) {
          _tax = _parsePrice(match.group(1) ?? '0');
        }
        continue;
      }

      // Check for service charge
      if (servicePattern.hasMatch(line)) {
        final match = pricePattern.firstMatch(line);
        if (match != null) {
          _serviceCharge = _parsePrice(match.group(1) ?? '0');
        }
        continue;
      }

      // Try to extract item
      final priceMatch = pricePattern.firstMatch(line);
      if (priceMatch != null) {
        double price = _parsePrice(priceMatch.group(1) ?? '0');
        String itemName = line.substring(0, priceMatch.start).trim();

        if (itemName.length > 1 && price > 100 && price < 10000000) {
          items.add(
            BillItemData(
              name: itemName,
              price: price,
              assignedMemberIds: {}, // Empty - user will assign
            ),
          );
        }
      }
    }

    setState(() {
      _storeName = storeName.isNotEmpty ? storeName : 'Receipt';
      _items = items;
    });
  }

  double _parsePrice(String priceStr) {
    String cleaned = priceStr.replaceAll(RegExp(r'[.,]'), '');
    return double.tryParse(cleaned) ?? 0;
  }

  void _addItem() {
    showDialog(
      context: context,
      builder: (context) => _AddItemDialog(
        onAdd: (name, price) {
          setState(() {
            _items.add(
              BillItemData(name: name, price: price, assignedMemberIds: {}),
            );
          });
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
        initialPrice: item.price,
        onAdd: (name, price) {
          setState(() {
            _items[index] = BillItemData(
              name: name,
              price: price,
              assignedMemberIds: item.assignedMemberIds,
            );
          });
        },
      ),
    );
  }

  void _deleteItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _showAssignMembersDialog(int itemIndex) {
    final item = _items[itemIndex];
    final members = widget.group?.members ?? [];
    Set<String> selectedIds = Set.from(item.assignedMemberIds);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Siapa yang pesan "${item.name}"?',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Rp ${_formatPrice(item.price)}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                // Select all button
                CheckboxListTile(
                  title: const Text(
                    'Pilih Semua',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  value: selectedIds.length == members.length,
                  onChanged: (value) {
                    setModalState(() {
                      if (value == true) {
                        selectedIds = members.map((m) => m.userId).toSet();
                      } else {
                        selectedIds.clear();
                      }
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const Divider(),
                // Member list
                ...members.map((member) {
                  final isSelected = selectedIds.contains(member.userId);
                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (value) {
                      setModalState(() {
                        if (value == true) {
                          selectedIds.add(member.userId);
                        } else {
                          selectedIds.remove(member.userId);
                        }
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    secondary: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.deepPurple,
                      backgroundImage: member.profile?.avatarUrl != null
                          ? NetworkImage(member.profile!.avatarUrl!)
                          : null,
                      child: member.profile?.avatarUrl == null
                          ? Text(
                              (member.profile?.username ?? 'U')
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            )
                          : null,
                    ),
                    title: Text(
                      member.profile?.fullName ??
                          member.profile?.username ??
                          'Unknown',
                    ),
                    subtitle:
                        selectedIds.contains(member.userId) &&
                            selectedIds.isNotEmpty
                        ? Text(
                            'Rp ${_formatPrice(item.price / selectedIds.length)}',
                            style: const TextStyle(
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        : null,
                  );
                }),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _items[itemIndex] = BillItemData(
                          name: item.name,
                          price: item.price,
                          assignedMemberIds: selectedIds,
                        );
                      });
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      selectedIds.isEmpty
                          ? 'Skip Item'
                          : 'Assign ${selectedIds.length} orang',
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

  double get _subtotal => _items.fold(0.0, (sum, item) => sum + item.price);
  double get _grandTotal => _subtotal + _tax + _serviceCharge;

  // Calculate how much each person owes
  Map<String, double> get _memberTotals {
    Map<String, double> totals = {};
    final members = widget.group?.members ?? [];

    // Initialize all members with 0
    for (var member in members) {
      totals[member.userId] = 0;
    }

    // Calculate item splits
    for (var item in _items) {
      if (item.assignedMemberIds.isNotEmpty) {
        double perPerson = item.price / item.assignedMemberIds.length;
        for (var memberId in item.assignedMemberIds) {
          totals[memberId] = (totals[memberId] ?? 0) + perPerson;
        }
      }
    }

    // Add tax & service proportionally
    double totalAssigned = totals.values.fold(0.0, (a, b) => a + b);
    if (totalAssigned > 0 && (_tax > 0 || _serviceCharge > 0)) {
      double extra = _tax + _serviceCharge;
      for (var memberId in totals.keys) {
        double proportion = totals[memberId]! / totalAssigned;
        totals[memberId] = totals[memberId]! + (extra * proportion);
      }
    }

    return totals;
  }

  int get _assignedItemCount =>
      _items.where((i) => i.assignedMemberIds.isNotEmpty).length;

  Future<void> _saveBill() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tambah minimal 1 item'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_assignedItemCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assign minimal 1 item ke member'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    // Create bill
    final result = await BillService.createBill(
      groupId: widget.groupId,
      storeName: _storeName,
      totalAmount: _grandTotal,
      taxAmount: _tax,
      serviceCharge: _serviceCharge,
      items: _items
          .map(
            (item) => {
              'name': item.name,
              'price': item.price,
              'quantity': 1,
              'assigned_to': item.assignedMemberIds.toList(),
            },
          )
          .toList(),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bill berhasil disimpan!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, result.data);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Gagal menyimpan'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Split Bill'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          if (_imageBytes != null && _items.isNotEmpty)
            TextButton(
              onPressed: _isSaving ? null : _saveBill,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Simpan',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 24),
          const Text(
            'Scan Struk',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Foto struk atau pilih dari galeri',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Kamera'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Galeri'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBillEditor() {
    if (_isProcessing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Memproses struk...'),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Image preview
        _buildImagePreview(),

        // Items list
        Expanded(child: _buildItemsList()),

        // Summary
        _buildSummary(),
      ],
    );
  }

  Widget _buildImagePreview() {
    return Container(
      height: 120,
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              _imageBytes!,
              width: double.infinity,
              height: 120,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              children: [
                _imageActionButton(
                  Icons.camera_alt,
                  () => _pickImage(ImageSource.camera),
                ),
                const SizedBox(width: 8),
                _imageActionButton(
                  Icons.photo_library,
                  () => _pickImage(ImageSource.gallery),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _storeName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageActionButton(IconData icon, VoidCallback onPressed) {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  Widget _buildItemsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Items',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _items.isEmpty
                        ? 'Tambahkan item dari struk'
                        : '${_assignedItemCount}/${_items.length} item sudah di-assign',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Tambah'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const Divider(),

        // Items
        Expanded(
          child: _items.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) => _buildItemTile(index),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Belum ada item',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap "Tambah" untuk menambahkan item',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(int index) {
    final item = _items[index];
    final isAssigned = item.assignedMemberIds.isNotEmpty;
    final members = widget.group?.members ?? [];

    // Get assigned member names
    List<String> assignedNames = [];
    for (var memberId in item.assignedMemberIds) {
      final member = members.firstWhere(
        (m) => m.userId == memberId,
        orElse: () => members.first,
      );
      assignedNames.add(member.profile?.username ?? 'Unknown');
    }

    return Dismissible(
      key: Key('item_$index'),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteItem(index),
      child: ListTile(
        onTap: () => _showAssignMembersDialog(index),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isAssigned
                ? Colors.green.withOpacity(0.1)
                : Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isAssigned ? Icons.check_circle : Icons.person_add,
            color: isAssigned ? Colors.green : Colors.orange,
          ),
        ),
        title: Text(
          item.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: isAssigned
            ? Text(
                assignedNames.join(', '),
                style: const TextStyle(color: Colors.deepPurple),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : const Text(
                'Tap untuk assign',
                style: TextStyle(color: Colors.orange),
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Rp ${_formatPrice(item.price)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: () => _editItem(index),
            ),
          ],
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
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Per person breakdown
            if (_assignedItemCount > 0) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Ringkasan per orang:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...members.where((m) => (totals[m.userId] ?? 0) > 0).map((
                      member,
                    ) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(member.profile?.username ?? 'Unknown'),
                            Text(
                              'Rp ${_formatPrice(totals[member.userId] ?? 0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total', style: TextStyle(color: Colors.grey)),
                    Text(
                      'Rp ${_formatPrice(_grandTotal)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ],
                ),
                if (_items.isNotEmpty && _assignedItemCount < _items.length)
                  TextButton(
                    onPressed: () {
                      // Find first unassigned item
                      int index = _items.indexWhere(
                        (i) => i.assignedMemberIds.isEmpty,
                      );
                      if (index >= 0) {
                        _showAssignMembersDialog(index);
                      }
                    },
                    child: Text(
                      '${_items.length - _assignedItemCount} belum di-assign',
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
          (Match m) => '${m[1]}.',
        );
  }
}

// Data class
class BillItemData {
  final String name;
  final double price;
  final Set<String> assignedMemberIds;

  BillItemData({
    required this.name,
    required this.price,
    required this.assignedMemberIds,
  });
}

// Add Item Dialog
class _AddItemDialog extends StatefulWidget {
  final String? initialName;
  final double? initialPrice;
  final Function(String name, double price) onAdd;

  const _AddItemDialog({
    this.initialName,
    this.initialPrice,
    required this.onAdd,
  });

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  late TextEditingController _nameController;
  late TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _priceController = TextEditingController(
      text: widget.initialPrice?.toStringAsFixed(0) ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialName != null ? 'Edit Item' : 'Tambah Item'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nama Item',
              hintText: 'cth: Nasi Goreng',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceController,
            decoration: const InputDecoration(
              labelText: 'Harga',
              prefixText: 'Rp ',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
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
            final name = _nameController.text.trim();
            final price = double.tryParse(_priceController.text) ?? 0;

            if (name.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Masukkan nama item')),
              );
              return;
            }
            if (price <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Masukkan harga yang valid')),
              );
              return;
            }

            widget.onAdd(name, price);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
          child: Text(widget.initialName != null ? 'Update' : 'Tambah'),
        ),
      ],
    );
  }
}
