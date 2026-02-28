import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';
import '../models/bill.dart';
import '../models/group.dart';
import '../services/bill_service.dart';

class CreateBillScreen extends StatefulWidget {
  final String groupId;
  final Group? group;

  const CreateBillScreen({super.key, required this.groupId, this.group});

  @override
  State<CreateBillScreen> createState() => _CreateBillScreenState();
}

class _CreateBillScreenState extends State<CreateBillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storeNameController = TextEditingController();
  final _taxController = TextEditingController(text: '0');
  final _serviceChargeController = TextEditingController(text: '0');

  List<BillItemInput> _items = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _addItem();
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _taxController.dispose();
    _serviceChargeController.dispose();
    for (var item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    setState(() => _items.add(BillItemInput()));
  }

  void _removeItem(int index) {
    if (_items.length > 1) {
      setState(() {
        _items[index].dispose();
        _items.removeAt(index);
      });
    }
  }

  double get _subtotal => _items.fold(0.0, (sum, item) => sum + item.total);
  double get _tax => double.tryParse(_taxController.text) ?? 0;
  double get _serviceCharge =>
      double.tryParse(_serviceChargeController.text) ?? 0;
  double get _grandTotal => _subtotal + _tax + _serviceCharge;

  Future<void> _createBill() async {
    if (!_formKey.currentState!.validate()) return;
    bool hasValidItem = _items.any(
      (item) => item.name.isNotEmpty && item.total > 0,
    );
    if (!hasValidItem) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tambah minimal 1 item'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    final items = _items
        .where((item) => item.name.isNotEmpty && item.total > 0)
        .map(
          (item) => {
            'name': item.name,
            'quantity': item.quantity,
            'unit_price': item.unitPrice,
            'total_price': item.total,
          },
        )
        .toList();
    final result = await BillService.createBill(
      groupId: widget.groupId,
      storeName: _storeNameController.text.trim(),
      totalAmount: _grandTotal,
      taxAmount: _tax,
      serviceCharge: _serviceCharge,
      items: items,
    );
    setState(() => _isLoading = false);
    if (mounted) {
      if (result.success) {
        Navigator.pop(context, result.data);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Gagal membuat bill'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  InputDecoration _inputDecoration(
    String label, {
    String? prefix,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixText: prefix,
      prefixIcon: icon != null
          ? Icon(icon, color: AppColors.textMuted, size: 20)
          : null,
      labelStyle: const TextStyle(color: AppColors.textMuted),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      isDense: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Buat Bill Manual',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Store name
                    TextFormField(
                      controller: _storeNameController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: _inputDecoration(
                        'Nama Toko / Restoran',
                        icon: Icons.store_rounded,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty)
                          return 'Masukkan nama toko';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Items header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Items',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(
                          height: 34,
                          child: TextButton.icon(
                            onPressed: _addItem,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text(
                              'Tambah',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Item list
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _items.length,
                      itemBuilder: (context, index) => _buildItemCard(index),
                    ),
                    const SizedBox(height: 24),

                    // Tax & service charge
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _taxController,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                            ),
                            decoration: _inputDecoration(
                              'Pajak',
                              prefix: 'Rp ',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _serviceChargeController,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                            ),
                            decoration: _inputDecoration(
                              'Service',
                              prefix: 'Rp ',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Bottom summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.surfaceBorder)),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    _buildSummaryRow('Subtotal', _subtotal),
                    _buildSummaryRow('Pajak', _tax),
                    _buildSummaryRow('Service Charge', _serviceCharge),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Container(
                        height: 1,
                        color: AppColors.surfaceBorder,
                      ),
                    ),
                    _buildSummaryRow('Grand Total', _grandTotal, isBold: true),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: GradientButton(
                        onPressed: _isLoading ? null : _createBill,
                        label: 'Buat Bill',
                        icon: Icons.receipt_long_rounded,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(int index) {
    final item = _items[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Item ${index + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (_items.length > 1)
                    IconButton(
                      onPressed: () => _removeItem(index),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.error,
                        size: 20,
                      ),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: item.nameController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: _inputDecoration('Nama Item'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: TextFormField(
                      controller: item.quantityController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: _inputDecoration('Qty'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: item.priceController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: _inputDecoration(
                        'Harga Satuan',
                        prefix: 'Rp ',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Rp ${_formatNumber(item.total)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
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

  String _formatNumber(double number) {
    return number
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
  }
}

class BillItemInput {
  final nameController = TextEditingController();
  final quantityController = TextEditingController(text: '1');
  final priceController = TextEditingController();

  String get name => nameController.text.trim();
  int get quantity => int.tryParse(quantityController.text) ?? 1;
  double get unitPrice => double.tryParse(priceController.text) ?? 0;
  double get total => quantity * unitPrice;

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    priceController.dispose();
  }
}
