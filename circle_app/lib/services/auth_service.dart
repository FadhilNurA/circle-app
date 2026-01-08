import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/user.dart';
import '../models/auth_session.dart';
import 'storage_service.dart';

class AuthResult {
  final bool success;
  final String? message;
  final User? user;
  final AuthSession? session;

  AuthResult({required this.success, this.message, this.user, this.session});
}

class AuthService {
  // Register a new user
  static Future<AuthResult> register({
    required String email,
    required String password,
    required String username,
    String? fullName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.register),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'username': username,
          'full_name': fullName,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        final user = User.fromJson(data['user']);
        return AuthResult(success: true, message: data['message'], user: user);
      } else {
        return AuthResult(
          success: false,
          message: data['error'] ?? 'Registration failed',
        );
      }
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  // Login user
  static Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.login),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final user = User.fromJson(data['user']);
        final session = AuthSession.fromJson(data['session']);

        // Save to local storage
        await StorageService.saveSession(session);
        await StorageService.saveUser(user);

        return AuthResult(
          success: true,
          message: data['message'],
          user: user,
          session: session,
        );
      } else {
        return AuthResult(
          success: false,
          message: data['error'] ?? 'Login failed',
        );
      }
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  // Logout user
  static Future<AuthResult> logout() async {
    try {
      final token = await StorageService.getAccessToken();

      if (token != null) {
        await http.post(
          Uri.parse(ApiConfig.logout),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      }

      // Clear local storage regardless of API response
      await StorageService.clearAuth();

      return AuthResult(success: true, message: 'Logged out successfully');
    } catch (e) {
      // Still clear local storage even if API call fails
      await StorageService.clearAuth();
      return AuthResult(success: true, message: 'Logged out');
    }
  }

  // Get current user
  static Future<AuthResult> getCurrentUser() async {
    try {
      final token = await StorageService.getAccessToken();

      if (token == null) {
        return AuthResult(success: false, message: 'Not logged in');
      }

      final response = await http.get(
        Uri.parse(ApiConfig.me),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final user = User.fromJson(data['user']);
        await StorageService.saveUser(user);

        return AuthResult(success: true, user: user);
      } else {
        // Token might be expired, try to refresh
        final refreshResult = await refreshToken();
        if (refreshResult.success) {
          // Retry getting user with new token
          return getCurrentUser();
        }

        return AuthResult(
          success: false,
          message: data['error'] ?? 'Failed to get user',
        );
      }
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  // Refresh access token
  static Future<AuthResult> refreshToken() async {
    try {
      final refreshTokenValue = await StorageService.getRefreshToken();

      if (refreshTokenValue == null) {
        return AuthResult(
          success: false,
          message: 'No refresh token available',
        );
      }

      final response = await http.post(
        Uri.parse(ApiConfig.refresh),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshTokenValue}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final session = AuthSession.fromJson(data['session']);
        await StorageService.saveSession(session);

        return AuthResult(
          success: true,
          message: data['message'],
          session: session,
        );
      } else {
        // Refresh failed, clear auth data
        await StorageService.clearAuth();
        return AuthResult(
          success: false,
          message: data['error'] ?? 'Failed to refresh token',
        );
      }
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    return await StorageService.isLoggedIn();
  }
}
