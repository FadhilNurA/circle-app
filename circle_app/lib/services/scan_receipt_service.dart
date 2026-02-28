import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config/api_config.dart';
import 'storage_service.dart';

class ScanReceiptResult {
  final bool success;
  final String? error;
  final String? merchantName;
  final List<ScannedItem>? items;
  final double? tax;
  final double? serviceCharge;
  final double? grandTotal;

  ScanReceiptResult({
    required this.success,
    this.error,
    this.merchantName,
    this.items,
    this.tax,
    this.serviceCharge,
    this.grandTotal,
  });
}

class ScannedItem {
  String name;
  int qty;
  double price;
  double total;

  ScannedItem({
    required this.name,
    required this.qty,
    required this.price,
    required this.total,
  });

  factory ScannedItem.fromJson(Map<String, dynamic> json) {
    return ScannedItem(
      name: json['name'] ?? 'Unknown',
      qty: (json['qty'] ?? 1).toInt(),
      price: (json['price'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'qty': qty,
    'price': price,
    'total': total,
  };
}

class ScanReceiptService {
  /// Send receipt image to backend for AI-powered scanning
  static Future<ScanReceiptResult> scanReceipt({
    required Uint8List imageBytes,
    required String filename,
  }) async {
    try {
      final token = await StorageService.getAccessToken();

      final uri = Uri.parse(ApiConfig.scanReceipt);
      final request = http.MultipartRequest('POST', uri);

      // Add auth header if available
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Add image file
      final mimeType = _getMimeType(filename);
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: filename,
          contentType: MediaType.parse(mimeType),
        ),
      );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
      );
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final items = (data['items'] as List)
            .map((item) => ScannedItem.fromJson(item))
            .toList();

        return ScanReceiptResult(
          success: true,
          merchantName: data['merchant_name'],
          items: items,
          tax: (data['tax'] ?? 0).toDouble(),
          serviceCharge: (data['service_charge'] ?? 0).toDouble(),
          grandTotal: (data['grand_total'] ?? 0).toDouble(),
        );
      } else {
        return ScanReceiptResult(
          success: false,
          error: data['error'] ?? 'Struk tidak terbaca, silakan coba lagi.',
        );
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        return ScanReceiptResult(
          success: false,
          error: 'Request timeout. Silakan coba lagi.',
        );
      }
      return ScanReceiptResult(success: false, error: 'Network error: $e');
    }
  }

  static String _getMimeType(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }
}
