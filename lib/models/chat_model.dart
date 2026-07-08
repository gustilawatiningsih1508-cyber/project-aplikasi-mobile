class ChatMessageModel {
  final int? id;
  final int senderId;
  final int receiverId;
  final String message;
  final String timestamp;
  final int isRead; // 0 = false, 1 = true
  final int isBid; // 0 = false, 1 = true
  final int? bidProductId;
  final double? bidPrice;
  final String? bidStatus; // 'pending', 'accepted', 'rejected'

  ChatMessageModel({
    this.id,
    required this.senderId,
    required this.receiverId,
    required this.message,
    required this.timestamp,
    required this.isRead,
    this.isBid = 0,
    this.bidProductId,
    this.bidPrice,
    this.bidStatus,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'timestamp': timestamp,
      'isRead': isRead,
      'isBid': isBid,
      'bidProductId': bidProductId,
      'bidPrice': bidPrice,
      'bidStatus': bidStatus,
    };
  }

  factory ChatMessageModel.fromMap(Map<String, dynamic> map) {
    return ChatMessageModel(
      id: map['id'] as int?,
      senderId: map['senderId'] as int? ?? 0,
      receiverId: map['receiverId'] as int? ?? 0,
      message: map['message'] as String? ?? '',
      timestamp: map['timestamp'] as String? ?? DateTime.now().toIso8601String(),
      isRead: map['isRead'] as int? ?? 0,
      isBid: map['isBid'] as int? ?? 0,
      bidProductId: map['bidProductId'] as int?,
      bidPrice: (map['bidPrice'] as num?)?.toDouble(),
      bidStatus: map['bidStatus'] as String?,
    );
  }
}

class ChatSession {
  final int contactId;
  final String contactName;
  final String contactPhoto;
  final String lastMessage;
  final String lastTimestamp;
  final int unreadCount;

  ChatSession({
    required this.contactId,
    required this.contactName,
    required this.contactPhoto,
    required this.lastMessage,
    required this.lastTimestamp,
    required this.unreadCount,
  });
}
