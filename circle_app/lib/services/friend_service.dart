import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/friendship.dart';
import '../models/user.dart';
import 'storage_service.dart';

class FriendResult<T> {
  final bool success;
  final String? message;
  final T? data;

  FriendResult({required this.success, this.message, this.data});
}

class FriendService {
  static Future<Map<String, String>> _getHeaders() async {
    final token = await StorageService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Get all friends (accepted friendships)
  static Future<FriendResult<List<Friend>>> getFriends() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.friends}?status=accepted'),
        headers: await _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final friends = (data['friends'] as List)
            .map((f) => Friend.fromJson(f))
            .toList();
        return FriendResult(success: true, data: friends);
      } else {
        return FriendResult(success: false, message: data['error']);
      }
    } catch (e) {
      return FriendResult(success: false, message: e.toString());
    }
  }

  /// Get pending friend requests (sent by current user)
  static Future<FriendResult<List<Friend>>> getSentRequests() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.friends}?status=pending'),
        headers: await _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final friends = (data['friends'] as List)
            .map((f) => Friend.fromJson(f))
            .where((f) => f.isRequester) // Only sent requests
            .toList();
        return FriendResult(success: true, data: friends);
      } else {
        return FriendResult(success: false, message: data['error']);
      }
    } catch (e) {
      return FriendResult(success: false, message: e.toString());
    }
  }

  /// Get received friend requests
  static Future<FriendResult<List<FriendRequest>>> getReceivedRequests() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.friendRequests),
        headers: await _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final requests = (data['requests'] as List)
            .map((r) => FriendRequest.fromJson(r))
            .toList();
        return FriendResult(success: true, data: requests);
      } else {
        return FriendResult(success: false, message: data['error']);
      }
    } catch (e) {
      return FriendResult(success: false, message: e.toString());
    }
  }

  /// Send friend request by username
  static Future<FriendResult<Friendship>> sendFriendRequest({
    required String username,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.friends),
        headers: await _getHeaders(),
        body: jsonEncode({'username': username}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return FriendResult(
          success: true,
          message: data['message'],
          data: Friendship.fromJson(data['friendship']),
        );
      } else {
        return FriendResult(success: false, message: data['error']);
      }
    } catch (e) {
      return FriendResult(success: false, message: e.toString());
    }
  }

  /// Accept friend request
  static Future<FriendResult<Friendship>> acceptRequest({
    required String friendshipId,
  }) async {
    try {
      final response = await http.put(
        Uri.parse(ApiConfig.friendship(friendshipId)),
        headers: await _getHeaders(),
        body: jsonEncode({'action': 'accept'}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return FriendResult(
          success: true,
          message: data['message'],
          data: Friendship.fromJson(data['friendship']),
        );
      } else {
        return FriendResult(success: false, message: data['error']);
      }
    } catch (e) {
      return FriendResult(success: false, message: e.toString());
    }
  }

  /// Reject friend request
  static Future<FriendResult<Friendship>> rejectRequest({
    required String friendshipId,
  }) async {
    try {
      final response = await http.put(
        Uri.parse(ApiConfig.friendship(friendshipId)),
        headers: await _getHeaders(),
        body: jsonEncode({'action': 'reject'}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return FriendResult(
          success: true,
          message: data['message'],
          data: Friendship.fromJson(data['friendship']),
        );
      } else {
        return FriendResult(success: false, message: data['error']);
      }
    } catch (e) {
      return FriendResult(success: false, message: e.toString());
    }
  }

  /// Remove friend or cancel request
  static Future<FriendResult<void>> removeFriend({
    required String friendshipId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse(ApiConfig.friendship(friendshipId)),
        headers: await _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return FriendResult(success: true, message: data['message']);
      } else {
        return FriendResult(success: false, message: data['error']);
      }
    } catch (e) {
      return FriendResult(success: false, message: e.toString());
    }
  }

  /// Search users by username (for adding friends)
  static Future<FriendResult<List<User>>> searchUsers(String query) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.searchUsers}?q=$query'),
        headers: await _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final users = (data['users'] as List)
            .map((u) => User.fromJson(u))
            .toList();
        return FriendResult(success: true, data: users);
      } else {
        return FriendResult(success: false, message: data['error']);
      }
    } catch (e) {
      return FriendResult(success: false, message: e.toString());
    }
  }
}
