import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/group.dart';
import '../models/message.dart';
import '../models/user.dart';
import 'storage_service.dart';

class GroupResult<T> {
  final bool success;
  final String? message;
  final T? data;
  final String? userRole;
  final bool? hasMore;

  GroupResult({
    required this.success,
    this.message,
    this.data,
    this.userRole,
    this.hasMore,
  });
}

class GroupService {
  static Future<Map<String, String>> _getHeaders() async {
    final token = await StorageService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Get all groups
  static Future<GroupResult<List<Group>>> getGroups() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.groups),
        headers: await _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final groups = (data['groups'] as List)
            .map((g) => Group.fromJson(g))
            .toList();
        return GroupResult(success: true, data: groups);
      } else {
        return GroupResult(success: false, message: data['error']);
      }
    } catch (e) {
      return GroupResult(success: false, message: e.toString());
    }
  }

  // Create a new group
  static Future<GroupResult<Group>> createGroup({
    required String name,
    String? description,
    List<String>? memberIds,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.groups),
        headers: await _getHeaders(),
        body: jsonEncode({
          'name': name,
          'description': description,
          'member_ids': memberIds,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return GroupResult(
          success: true,
          message: data['message'],
          data: Group.fromJson(data['group']),
        );
      } else {
        return GroupResult(success: false, message: data['error']);
      }
    } catch (e) {
      return GroupResult(success: false, message: e.toString());
    }
  }

  // Get group details with user role
  static Future<GroupResult<Group>> getGroup(String groupId) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.group(groupId)),
        headers: await _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return GroupResult(
          success: true,
          data: Group.fromJson(data['group']),
          userRole: data['user_role'],
        );
      } else {
        return GroupResult(success: false, message: data['error']);
      }
    } catch (e) {
      return GroupResult(success: false, message: e.toString());
    }
  }

  // Update group
  static Future<GroupResult<Group>> updateGroup({
    required String groupId,
    String? name,
    String? description,
    String? imageUrl,
  }) async {
    try {
      final response = await http.put(
        Uri.parse(ApiConfig.group(groupId)),
        headers: await _getHeaders(),
        body: jsonEncode({
          'name': name,
          'description': description,
          'image_url': imageUrl,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return GroupResult(success: true, data: Group.fromJson(data['group']));
      } else {
        return GroupResult(success: false, message: data['error']);
      }
    } catch (e) {
      return GroupResult(success: false, message: e.toString());
    }
  }

  // Delete group
  static Future<GroupResult<void>> deleteGroup(String groupId) async {
    try {
      final response = await http.delete(
        Uri.parse(ApiConfig.group(groupId)),
        headers: await _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return GroupResult(success: true, message: data['message']);
      } else {
        return GroupResult(success: false, message: data['error']);
      }
    } catch (e) {
      return GroupResult(success: false, message: e.toString());
    }
  }

  // Add member to group (must be a friend)
  // The backend validates that the target user is a friend
  static Future<GroupResult<void>> addMember({
    required String groupId,
    String? userId,
    String? username,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.groupMembers(groupId)),
        headers: await _getHeaders(),
        body: jsonEncode({'user_id': userId, 'username': username}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return GroupResult(success: true, message: data['message']);
      } else {
        return GroupResult(success: false, message: data['error']);
      }
    } catch (e) {
      return GroupResult(success: false, message: e.toString());
    }
  }

  // Add friend to group by username (convenience method)
  static Future<GroupResult<void>> addFriendToGroup({
    required String groupId,
    required String username,
  }) async {
    return addMember(groupId: groupId, username: username);
  }

  // Remove member from group
  static Future<GroupResult<void>> removeMember({
    required String groupId,
    required String userId,
  }) async {
    try {
      final request = http.Request(
        'DELETE',
        Uri.parse(ApiConfig.groupMembers(groupId)),
      );
      request.headers.addAll(await _getHeaders());
      request.body = jsonEncode({'user_id': userId});

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return GroupResult(success: true, message: data['message']);
      } else {
        return GroupResult(success: false, message: data['error']);
      }
    } catch (e) {
      return GroupResult(success: false, message: e.toString());
    }
  }

  // Get messages with pagination
  static Future<GroupResult<List<Message>>> getMessages({
    required String groupId,
    int limit = 50,
    String? before,
  }) async {
    try {
      var url = '${ApiConfig.groupMessages(groupId)}?limit=$limit';
      if (before != null) {
        url += '&before=$before';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final messages = (data['messages'] as List)
            .map((m) => Message.fromJson(m))
            .toList();
        return GroupResult(
          success: true,
          data: messages,
          hasMore: data['has_more'] ?? false,
        );
      } else {
        return GroupResult(success: false, message: data['error']);
      }
    } catch (e) {
      return GroupResult(success: false, message: e.toString());
    }
  }

  // Send message
  static Future<GroupResult<Message>> sendMessage({
    required String groupId,
    required String content,
    String messageType = 'text',
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.groupMessages(groupId)),
        headers: await _getHeaders(),
        body: jsonEncode({
          'content': content,
          'message_type': messageType,
          'metadata': metadata,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return GroupResult(
          success: true,
          data: Message.fromJson(data['message']),
        );
      } else {
        return GroupResult(success: false, message: data['error']);
      }
    } catch (e) {
      return GroupResult(success: false, message: e.toString());
    }
  }

  // Search users
  static Future<GroupResult<List<User>>> searchUsers(String query) async {
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
        return GroupResult(success: true, data: users);
      } else {
        return GroupResult(success: false, message: data['error']);
      }
    } catch (e) {
      return GroupResult(success: false, message: e.toString());
    }
  }
}
