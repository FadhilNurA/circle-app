import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/bill.dart';
import 'storage_service.dart';

class BillResult<T> {
  final bool success;
  final String? message;
  final T? data;

  BillResult({required this.success, this.message, this.data});
}

class BillService {
  static Future<Map<String, String>> _getHeaders() async {
    final token = await StorageService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Get all bills for a group
  static Future<BillResult<List<Bill>>> getBills(String groupId) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.receipts(groupId)),
        headers: await _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final bills = (data['receipts'] as List)
            .map((r) => Bill.fromJson(r))
            .toList();
        return BillResult(success: true, data: bills);
      } else {
        return BillResult(success: false, message: data['error']);
      }
    } catch (e) {
      return BillResult(success: false, message: e.toString());
    }
  }

  /// Get single bill with items and splits
  static Future<BillResult<Bill>> getBill({
    required String groupId,
    required String billId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.receipt(groupId, billId)),
        headers: await _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return BillResult(success: true, data: Bill.fromJson(data['receipt']));
      } else {
        return BillResult(success: false, message: data['error']);
      }
    } catch (e) {
      return BillResult(success: false, message: e.toString());
    }
  }

  /// Create a new bill
  static Future<BillResult<Bill>> createBill({
    required String groupId,
    String? storeName,
    required double totalAmount,
    double taxAmount = 0,
    double serviceCharge = 0,
    List<Map<String, dynamic>>? items,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.receipts(groupId)),
        headers: await _getHeaders(),
        body: jsonEncode({
          'store_name': storeName ?? 'Receipt',
          'total_amount': totalAmount,
          'tax_amount': taxAmount,
          'service_charge': serviceCharge,
          'items': items,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return BillResult(
          success: true,
          message: data['message'],
          data: Bill.fromJson(data['receipt']),
        );
      } else {
        return BillResult(success: false, message: data['error']);
      }
    } catch (e) {
      return BillResult(success: false, message: e.toString());
    }
  }

  /// Add item to bill
  static Future<BillResult<BillItem>> addItem({
    required String groupId,
    required String billId,
    required String name,
    required int quantity,
    required double unitPrice,
  }) async {
    try {
      final response = await http.put(
        Uri.parse(ApiConfig.receipt(groupId, billId)),
        headers: await _getHeaders(),
        body: jsonEncode({
          'items': [
            {
              'name': name,
              'quantity': quantity,
              'unit_price': unitPrice,
              'total_price': quantity * unitPrice,
            },
          ],
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return BillResult(success: true, message: 'Item added');
      } else {
        return BillResult(success: false, message: data['error']);
      }
    } catch (e) {
      return BillResult(success: false, message: e.toString());
    }
  }

  /// Split an item among users
  static Future<BillResult<void>> splitItem({
    required String groupId,
    required String billId,
    required String itemId,
    required List<Map<String, dynamic>> splits,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.splitBill(groupId, billId)),
        headers: await _getHeaders(),
        body: jsonEncode({'item_id': itemId, 'splits': splits}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return BillResult(success: true, message: data['message']);
      } else {
        return BillResult(success: false, message: data['error']);
      }
    } catch (e) {
      return BillResult(success: false, message: e.toString());
    }
  }

  /// Split bill equally among all members
  static Future<BillResult<void>> splitEqually({
    required String groupId,
    required String billId,
    required List<String> memberIds,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.splitBill(groupId, billId)),
        headers: await _getHeaders(),
        body: jsonEncode({'split_type': 'equal', 'member_ids': memberIds}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return BillResult(success: true, message: data['message']);
      } else {
        return BillResult(success: false, message: data['error']);
      }
    } catch (e) {
      return BillResult(success: false, message: e.toString());
    }
  }

  /// Mark bill as completed
  static Future<BillResult<void>> completeBill({
    required String groupId,
    required String billId,
  }) async {
    try {
      final response = await http.put(
        Uri.parse(ApiConfig.receipt(groupId, billId)),
        headers: await _getHeaders(),
        body: jsonEncode({'status': 'completed'}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return BillResult(success: true, message: 'Bill completed');
      } else {
        return BillResult(success: false, message: data['error']);
      }
    } catch (e) {
      return BillResult(success: false, message: e.toString());
    }
  }

  /// Get user balances for a bill
  static Future<BillResult<List<UserBalance>>> getBalances({
    required String groupId,
    required String billId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.splitBill(groupId, billId)),
        headers: await _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final balances =
            (data['balances'] as List?)
                ?.map((b) => UserBalance.fromJson(b))
                .toList() ??
            [];
        return BillResult(success: true, data: balances);
      } else {
        return BillResult(success: false, message: data['error']);
      }
    } catch (e) {
      return BillResult(success: false, message: e.toString());
    }
  }

  /// Delete a bill
  static Future<BillResult<void>> deleteBill({
    required String groupId,
    required String billId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse(ApiConfig.receipt(groupId, billId)),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return BillResult(success: true, message: 'Bill deleted');
      } else {
        final data = jsonDecode(response.body);
        return BillResult(success: false, message: data['error']);
      }
    } catch (e) {
      return BillResult(success: false, message: e.toString());
    }
  }

  /// Approve payment from a user (only bill creator can do this)
  static Future<BillResult<bool>> approvePayment({
    required String groupId,
    required String billId,
    required String userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.approveBill(groupId, billId)),
        headers: await _getHeaders(),
        body: jsonEncode({'user_id': userId, 'action': 'approve'}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return BillResult(
          success: true,
          message: data['message'],
          data: data['is_all_settled'] ?? false,
        );
      } else {
        return BillResult(success: false, message: data['error']);
      }
    } catch (e) {
      return BillResult(success: false, message: e.toString());
    }
  }

  /// Reject payment (undo approval)
  static Future<BillResult<void>> rejectPayment({
    required String groupId,
    required String billId,
    required String userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.approveBill(groupId, billId)),
        headers: await _getHeaders(),
        body: jsonEncode({'user_id': userId, 'action': 'reject'}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return BillResult(success: true, message: data['message']);
      } else {
        return BillResult(success: false, message: data['error']);
      }
    } catch (e) {
      return BillResult(success: false, message: e.toString());
    }
  }

  /// Get balances with approval status
  static Future<BillResult<List<UserBalance>>> getBillBalances({
    required String groupId,
    required String billId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.approveBill(groupId, billId)),
        headers: await _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final balances =
            (data['balances'] as List?)
                ?.map((b) => UserBalance.fromJson(b))
                .toList() ??
            [];
        return BillResult(success: true, data: balances);
      } else {
        return BillResult(success: false, message: data['error']);
      }
    } catch (e) {
      return BillResult(success: false, message: e.toString());
    }
  }
}
