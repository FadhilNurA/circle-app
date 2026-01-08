import 'user.dart';

class Group {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<GroupMember>? members;

  Group({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.members,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    // Handle both 'members' and 'group_members' keys from API
    List? membersJson = json['members'] ?? json['group_members'];

    return Group(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      imageUrl: json['image_url'],
      createdBy: json['created_by'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      members: membersJson != null
          ? (membersJson as List).map((m) => GroupMember.fromJson(m)).toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'created_by': createdBy,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  int get memberCount => members?.length ?? 0;
}

class GroupMember {
  final String? id;
  final String userId;
  final String role;
  final DateTime? joinedAt;
  final User? profile;

  GroupMember({
    this.id,
    required this.userId,
    required this.role,
    this.joinedAt,
    this.profile,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    // Handle both 'profile' (singular) and 'profiles' (plural) keys from API
    var profileJson = json['profile'] ?? json['profiles'];

    return GroupMember(
      id: json['id'],
      userId: json['user_id'] ?? '',
      role: json['role'] ?? 'member',
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'])
          : null,
      profile: profileJson != null ? User.fromJson(profileJson) : null,
    );
  }

  bool get isAdmin => role == 'admin';
}
