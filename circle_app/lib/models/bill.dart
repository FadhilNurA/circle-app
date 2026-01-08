import 'user.dart';

class Bill {
  final String id;
  final String groupId;
  final String? uploadedBy;
  final User? uploadedByUser;
  final String? imageUrl;
  final String? storeName;
  final double totalAmount;
  final double taxAmount;
  final double serviceCharge;
  final String status; // pending, splitting, completed
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<BillItem> items;

  Bill({
    required this.id,
    required this.groupId,
    this.uploadedBy,
    this.uploadedByUser,
    this.imageUrl,
    this.storeName,
    required this.totalAmount,
    this.taxAmount = 0,
    this.serviceCharge = 0,
    required this.status,
    this.createdAt,
    this.updatedAt,
    this.items = const [],
  });

  factory Bill.fromJson(Map<String, dynamic> json) {
    return Bill(
      id: json['id'] ?? '',
      groupId: json['group_id'] ?? '',
      uploadedBy: json['uploaded_by'],
      uploadedByUser: json['uploaded_by_user'] != null
          ? User.fromJson(json['uploaded_by_user'])
          : null,
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
      items: json['receipt_items'] != null
          ? (json['receipt_items'] as List)
                .map((i) => BillItem.fromJson(i))
                .toList()
          : [],
    );
  }

  double get subtotal => totalAmount - taxAmount - serviceCharge;

  bool get isPending => status == 'pending';
  bool get isSplitting => status == 'splitting';
  bool get isCompleted => status == 'completed';
}

class BillItem {
  final String id;
  final String receiptId;
  final String name;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final DateTime? createdAt;
  final List<ItemSplit> splits;

  BillItem({
    required this.id,
    required this.receiptId,
    required this.name,
    this.quantity = 1,
    required this.unitPrice,
    required this.totalPrice,
    this.createdAt,
    this.splits = const [],
  });

  factory BillItem.fromJson(Map<String, dynamic> json) {
    return BillItem(
      id: json['id'] ?? '',
      receiptId: json['receipt_id'] ?? '',
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? 1,
      unitPrice: (json['unit_price'] ?? 0).toDouble(),
      totalPrice: (json['total_price'] ?? 0).toDouble(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      splits: json['item_splits'] != null
          ? (json['item_splits'] as List)
                .map((s) => ItemSplit.fromJson(s))
                .toList()
          : [],
    );
  }

  double get remainingAmount {
    final splitTotal = splits.fold(0.0, (sum, s) => sum + s.shareAmount);
    return totalPrice - splitTotal;
  }

  bool get isFullySplit => remainingAmount <= 0;
}

class ItemSplit {
  final String id;
  final String receiptItemId;
  final String userId;
  final User? user;
  final double shareAmount;
  final bool isPaid;
  final DateTime? createdAt;

  ItemSplit({
    required this.id,
    required this.receiptItemId,
    required this.userId,
    this.user,
    required this.shareAmount,
    this.isPaid = false,
    this.createdAt,
  });

  factory ItemSplit.fromJson(Map<String, dynamic> json) {
    return ItemSplit(
      id: json['id'] ?? '',
      receiptItemId: json['receipt_item_id'] ?? '',
      userId: json['user_id'] ?? '',
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      shareAmount: (json['share_amount'] ?? 0).toDouble(),
      isPaid: json['is_paid'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }
}

class UserBalance {
  final String id;
  final String receiptId;
  final String userId;
  final User? user;
  final double amountOwed;
  final double amountPaid;
  final bool isSettled;
  final DateTime? updatedAt;

  UserBalance({
    required this.id,
    required this.receiptId,
    required this.userId,
    this.user,
    required this.amountOwed,
    this.amountPaid = 0,
    this.isSettled = false,
    this.updatedAt,
  });

  factory UserBalance.fromJson(Map<String, dynamic> json) {
    return UserBalance(
      id: json['id'] ?? '',
      receiptId: json['receipt_id'] ?? '',
      userId: json['user_id'] ?? '',
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      amountOwed: (json['amount_owed'] ?? 0).toDouble(),
      amountPaid: (json['amount_paid'] ?? 0).toDouble(),
      isSettled: json['is_settled'] ?? false,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  double get remaining => amountOwed - amountPaid;
}
