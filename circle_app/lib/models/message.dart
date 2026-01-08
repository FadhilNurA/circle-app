import 'user.dart';

class Message {
  final String id;
  final String groupId;
  final String? senderId;
  final String content;
  final String messageType;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;
  final User? sender;

  Message({
    required this.id,
    required this.groupId,
    this.senderId,
    required this.content,
    this.messageType = 'text',
    this.metadata,
    this.createdAt,
    this.sender,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? '',
      groupId: json['group_id'] ?? '',
      senderId: json['sender_id'],
      content: json['content'] ?? '',
      messageType: json['message_type'] ?? 'text',
      metadata: json['metadata'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      sender: json['sender'] != null ? User.fromJson(json['sender']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'sender_id': senderId,
      'content': content,
      'message_type': messageType,
      'metadata': metadata,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  bool get isReceipt => messageType == 'receipt';
}
