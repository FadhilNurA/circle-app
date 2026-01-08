import 'user.dart';

class Receipt {
  final String id;
  final String groupId;
  final String? uploadedBy;
  final String? imageUrl;
  final String? storeName;
  final double totalAmount;
  final double taxAmount;
  final double serviceCharge;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final User? uploadedByUser;
  final List<ReceiptItem>? items;

  Receipt({
    required this.id,
    required this.groupId,
    this.uploadedBy,
    this.imageUrl,
    this.storeName,
    this.totalAmount = 0,
    this.taxAmount = 0,
    this.serviceCharge = 0,
    this.status = 'pending',
    this.createdAt,
    this.updatedAt,
    this.uploadedByUser,
    this.items,
  });

  factory Receipt.fromJson(Map<String, dynamic> json) {
    return Receipt(
      id: json['id'] ?? '',
      groupId: json['group_id'] ?? '',
      uploadedBy: json['uploaded_by'],
      imageUrl: json['image_url'],
      storeName: json['store_name'],
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      taxAmount: (json['tax_amount'] ?? 0).toDouble(),
      serviceCharge: (json['service_charge'] ?? 0).toDouble(),
      status: json['status'] ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      uploadedByUser: json['uploaded_by_user'] != null
          ? User.fromJson(json['uploaded_by_user'])
          : null,
      items: json['receipt_items'] != null
          ? (json['receipt_items'] as List)
                .map((i) => ReceiptItem.fromJson(i))
                .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'uploaded_by': uploadedBy,
      'image_url': imageUrl,
      'store_name': storeName,
      'total_amount': totalAmount,
      'tax_amount': taxAmount,
      'service_charge': serviceCharge,
      'status': status,
    };
  }

  double get subtotal =>
      items?.fold<double>(0.0, (sum, item) => sum + item.totalPrice) ?? 0;
  double get grandTotal =>
      totalAmount > 0 ? totalAmount : subtotal + taxAmount + serviceCharge;
  bool get isPending => status == 'pending';
  bool get isSplitting => status == 'splitting';
  bool get isCompleted => status == 'completed';
}

class ReceiptItem {
  final String id;
  final String receiptId;
  final String name;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final List<ItemSplit>? splits;

  ReceiptItem({
    required this.id,
    required this.receiptId,
    required this.name,
    this.quantity = 1,
    required this.unitPrice,
    required this.totalPrice,
    this.splits,
  });

  factory ReceiptItem.fromJson(Map<String, dynamic> json) {
    return ReceiptItem(
      id: json['id'] ?? '',
      receiptId: json['receipt_id'] ?? '',
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? 1,
      unitPrice: (json['unit_price'] ?? 0).toDouble(),
      totalPrice: (json['total_price'] ?? 0).toDouble(),
      splits: json['item_splits'] != null
          ? (json['item_splits'] as List)
                .map((s) => ItemSplit.fromJson(s))
                .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
    };
  }
}

class ItemSplit {
  final String id;
  final String receiptItemId;
  final String userId;
  final double shareAmount;
  final bool isPaid;
  final User? user;

  ItemSplit({
    required this.id,
    required this.receiptItemId,
    required this.userId,
    required this.shareAmount,
    this.isPaid = false,
    this.user,
  });

  factory ItemSplit.fromJson(Map<String, dynamic> json) {
    return ItemSplit(
      id: json['id'] ?? '',
      receiptItemId: json['receipt_item_id'] ?? '',
      userId: json['user_id'] ?? '',
      shareAmount: (json['share_amount'] ?? 0).toDouble(),
      isPaid: json['is_paid'] ?? false,
      user: json['user'] != null ? User.fromJson(json['user']) : null,
    );
  }
}

class UserBalance {
  final String id;
  final String receiptId;
  final String userId;
  final double amountOwed;
  final double amountPaid;
  final bool isSettled;
  final User? user;

  UserBalance({
    required this.id,
    required this.receiptId,
    required this.userId,
    required this.amountOwed,
    this.amountPaid = 0,
    this.isSettled = false,
    this.user,
  });

  factory UserBalance.fromJson(Map<String, dynamic> json) {
    return UserBalance(
      id: json['id'] ?? '',
      receiptId: json['receipt_id'] ?? '',
      userId: json['user_id'] ?? '',
      amountOwed: (json['amount_owed'] ?? 0).toDouble(),
      amountPaid: (json['amount_paid'] ?? 0).toDouble(),
      isSettled: json['is_settled'] ?? false,
      user: json['user'] != null ? User.fromJson(json['user']) : null,
    );
  }

  double get remaining => amountOwed - amountPaid;
}
