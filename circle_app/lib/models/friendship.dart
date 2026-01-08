import 'user.dart';

enum FriendshipStatus { pending, accepted, rejected, blocked }

class Friendship {
  final String id;
  final String requesterId;
  final String addresseeId;
  final FriendshipStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final User? requester;
  final User? addressee;

  Friendship({
    required this.id,
    required this.requesterId,
    required this.addresseeId,
    required this.status,
    this.createdAt,
    this.updatedAt,
    this.requester,
    this.addressee,
  });

  factory Friendship.fromJson(Map<String, dynamic> json) {
    return Friendship(
      id: json['id'] ?? '',
      requesterId: json['requester_id'] ?? '',
      addresseeId: json['addressee_id'] ?? '',
      status: _parseStatus(json['status']),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      requester: json['requester'] != null
          ? User.fromJson(json['requester'])
          : null,
      addressee: json['addressee'] != null
          ? User.fromJson(json['addressee'])
          : null,
    );
  }

  static FriendshipStatus _parseStatus(String? status) {
    switch (status) {
      case 'pending':
        return FriendshipStatus.pending;
      case 'accepted':
        return FriendshipStatus.accepted;
      case 'rejected':
        return FriendshipStatus.rejected;
      case 'blocked':
        return FriendshipStatus.blocked;
      default:
        return FriendshipStatus.pending;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'requester_id': requesterId,
      'addressee_id': addresseeId,
      'status': status.name,
    };
  }

  bool get isPending => status == FriendshipStatus.pending;
  bool get isAccepted => status == FriendshipStatus.accepted;
}

class Friend {
  final String friendshipId;
  final FriendshipStatus status;
  final DateTime? createdAt;
  final bool isRequester;
  final User friend;

  Friend({
    required this.friendshipId,
    required this.status,
    this.createdAt,
    required this.isRequester,
    required this.friend,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      friendshipId: json['friendship_id'] ?? '',
      status: Friendship._parseStatus(json['status']),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      isRequester: json['is_requester'] ?? false,
      friend: User.fromJson(json['friend']),
    );
  }
}

class FriendRequest {
  final String id;
  final String requesterId;
  final String addresseeId;
  final FriendshipStatus status;
  final DateTime? createdAt;
  final User requester;

  FriendRequest({
    required this.id,
    required this.requesterId,
    required this.addresseeId,
    required this.status,
    this.createdAt,
    required this.requester,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id'] ?? '',
      requesterId: json['requester_id'] ?? '',
      addresseeId: json['addressee_id'] ?? '',
      status: Friendship._parseStatus(json['status']),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      requester: User.fromJson(json['requester']),
    );
  }
}
