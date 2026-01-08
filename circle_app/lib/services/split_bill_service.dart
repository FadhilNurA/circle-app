import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/receipt.dart';
import 'storage_service.dart';

class SplitBillResult<T> {
  final bool success;
  final String? message;
  final T? data;

  SplitBillResult({required this.success, this.message, this.data});
}

class SplitBillService {
  static Future<Map<String, String>> _getHeaders() async {
    final token = await StorageService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Get all receipts in a group
  static Future<SplitBillResult<List<Receipt>>> getReceipts(
    String groupId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.receipts(groupId)),
        headers: await _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final receipts = (data['receipts'] as List)
            .map((r) => Receipt.fromJson(r))
            .toList();
        return SplitBillResult(success: true, data: receipts);
      } else {
        return SplitBillResult(success: false, message: data['error']);
      }
    } catch (e) {
      return SplitBillResult(success: false, message: e.toString());
    }
  }

  // Create a new receipt
  static Future<SplitBillResult<Receipt>> createReceipt({
    required String groupId,
    String? storeName,
    String? imageUrl,
    double totalAmount = 0,
    double taxAmount = 0,
    double serviceCharge = 0,
    List<Map<String, dynamic>>? items,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.receipts(groupId)),
        headers: await _getHeaders(),
        body: jsonEncode({
          'store_name': storeName,
          'image_url': imageUrl,
          'total_amount': totalAmount,
          'tax_amount': taxAmount,
          'service_charge': serviceCharge,
          'items': items,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return SplitBillResult(
          success: true,
          message: data['message'],
          data: Receipt.fromJson(data['receipt']),
        );
      } else {
        return SplitBillResult(success: false, message: data['error']);
      }
    } catch (e) {
      return SplitBillResult(success: false, message: e.toString());
    }
  }

  // Get receipt details
  static Future<SplitBillResult<Receipt>> getReceipt({
    required String groupId,
    required String receiptId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.receipt(groupId, receiptId)),
        headers: await _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return SplitBillResult(
          success: true,
          data: Receipt.fromJson(data['receipt']),
        );
      } else {
        return SplitBillResult(success: false, message: data['error']);
      }
    } catch (e) {
      return SplitBillResult(success: false, message: e.toString());
    }
  }

  // Update receipt
  static Future<SplitBillResult<Receipt>> updateReceipt({
    required String groupId,
    required String receiptId,
    String? storeName,
    double? totalAmount,
    double? taxAmount,
    double? serviceCharge,
    String? status,
  }) async {
    try {
      final response = await http.put(
        Uri.parse(ApiConfig.receipt(groupId, receiptId)),
        headers: await _getHeaders(),
        body: jsonEncode({
          'store_name': storeName,
          'total_amount': totalAmount,
          'tax_amount': taxAmount,
          'service_charge': serviceCharge,
          'status': status,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return SplitBillResult(
          success: true,
          data: Receipt.fromJson(data['receipt']),
        );
      } else {
        return SplitBillResult(success: false, message: data['error']);
      }
    } catch (e) {
      return SplitBillResult(success: false, message: e.toString());
    }
  }

  // Delete receipt
  static Future<SplitBillResult<void>> deleteReceipt({
    required String groupId,
    required String receiptId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse(ApiConfig.receipt(groupId, receiptId)),
        headers: await _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return SplitBillResult(success: true, message: data['message']);
      } else {
        return SplitBillResult(success: false, message: data['error']);
      }
    } catch (e) {
      return SplitBillResult(success: false, message: e.toString());
    }
  }

  // Add items to receipt
  static Future<SplitBillResult<List<ReceiptItem>>> addItems({
    required String groupId,
    required String receiptId,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.receiptItems(groupId, receiptId)),
        headers: await _getHeaders(),
        body: jsonEncode({'items': items}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        final items = (data['items'] as List)
            .map((i) => ReceiptItem.fromJson(i))
            .toList();
        return SplitBillResult(success: true, data: items);
      } else {
        return SplitBillResult(success: false, message: data['error']);
      }
    } catch (e) {
      return SplitBillResult(success: false, message: e.toString());
    }
  }

  // Delete item
  static Future<SplitBillResult<void>> deleteItem({
    required String groupId,
    required String receiptId,
    required String itemId,
  }) async {
    try {
      final request = http.Request(
        'DELETE',
        Uri.parse(ApiConfig.receiptItems(groupId, receiptId)),
      );
      request.headers.addAll(await _getHeaders());
      request.body = jsonEncode({'item_id': itemId});

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return SplitBillResult(success: true, message: data['message']);
      } else {
        return SplitBillResult(success: false, message: data['error']);
      }
    } catch (e) {
      return SplitBillResult(success: false, message: e.toString());
    }
  }

  // Split bill among users
  static Future<SplitBillResult<void>> splitBill({
    required String groupId,
    required String receiptId,
    required List<Map<String, dynamic>> splits,
    // splits format: [{ item_id, user_ids: [], split_type: 'equal', amounts: [] }]
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.splitBill(groupId, receiptId)),
        headers: await _getHeaders(),
        body: jsonEncode({'splits': splits}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return SplitBillResult(success: true, message: data['message']);
      } else {
        return SplitBillResult(success: false, message: data['error']);
      }
    } catch (e) {
      return SplitBillResult(success: false, message: e.toString());
    }
  }

  // Get splits for a receipt
  static Future<SplitBillResult<Map<String, dynamic>>> getSplits({
    required String groupId,
    required String receiptId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.splitBill(groupId, receiptId)),
        headers: await _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return SplitBillResult(success: true, data: data);
      } else {
        return SplitBillResult(success: false, message: data['error']);
      }
    } catch (e) {
      return SplitBillResult(success: false, message: e.toString());
    }
  }
}
