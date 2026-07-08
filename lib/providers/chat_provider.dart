import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/chat_model.dart';
import '../services/db_helper.dart';

class ChatProvider extends ChangeNotifier {
  List<ChatMessageModel> _messages = [];
  List<ChatSession> _sessions = [];
  bool _isLoading = false;

  List<ChatMessageModel> get messages => _messages;
  List<ChatSession> get sessions => _sessions;
  bool get isLoading => _isLoading;

  // Load message history between current user and contact user
  Future<void> loadMessages(int currentUserId, int contactId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DBHelper.instance.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'chat_messages',
        where: '(senderId = ? AND receiverId = ?) OR (senderId = ? AND receiverId = ?)',
        whereArgs: [currentUserId, contactId, contactId, currentUserId],
        orderBy: 'id ASC',
      );

      _messages = List.generate(maps.length, (i) {
        return ChatMessageModel.fromMap(maps[i]);
      });

      // Mark all messages from contact to current user as read
      await db.update(
        'chat_messages',
        {'isRead': 1},
        where: 'senderId = ? AND receiverId = ?',
        whereArgs: [contactId, currentUserId],
      );

      // Reload chat sessions list
      await loadChatSessions(currentUserId);
    } catch (e) {
      debugPrint('Error loading messages: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // Load list of users who have had chat sessions with current user
  Future<void> loadChatSessions(int currentUserId) async {
    try {
      final db = await DBHelper.instance.database;

      // Custom query to get unique chat partners, their last message, and unread counts
      final List<Map<String, dynamic>> partnersResult = await db.rawQuery('''
        SELECT DISTINCT CASE 
          WHEN senderId = ? THEN receiverId 
          ELSE senderId 
        END as partnerId
        FROM chat_messages
        WHERE senderId = ? OR receiverId = ?
      ''', [currentUserId, currentUserId, currentUserId]);

      List<ChatSession> tempSessions = [];

      for (var row in partnersResult) {
        final partnerId = row['partnerId'] as int;

        // Fetch partner details
        final userResult = await db.query(
          'users',
          where: 'id = ?',
          whereArgs: [partnerId],
        );

        if (userResult.isEmpty) continue;
        final partnerName = userResult.first['name'] as String;
        final partnerPhoto = userResult.first['photoUrl'] as String;

        // Fetch last message
        final lastMsgResult = await db.query(
          'chat_messages',
          where: '(senderId = ? AND receiverId = ?) OR (senderId = ? AND receiverId = ?)',
          whereArgs: [currentUserId, partnerId, partnerId, currentUserId],
          orderBy: 'id DESC',
          limit: 1,
        );

        if (lastMsgResult.isEmpty) continue;
        final lastMsg = ChatMessageModel.fromMap(lastMsgResult.first);

        // Fetch unread count
        final unreadResult = await db.rawQuery('''
          SELECT COUNT(*) as count 
          FROM chat_messages 
          WHERE senderId = ? AND receiverId = ? AND isRead = 0
        ''', [partnerId, currentUserId]);

        final unreadCount = unreadResult.first['count'] as int? ?? 0;

        tempSessions.add(ChatSession(
          contactId: partnerId,
          contactName: partnerName,
          contactPhoto: partnerPhoto,
          lastMessage: lastMsg.message,
          lastTimestamp: lastMsg.timestamp,
          unreadCount: unreadCount,
        ));
      }

      // Sort sessions by last message timestamp desc
      tempSessions.sort((a, b) => b.lastTimestamp.compareTo(a.lastTimestamp));
      _sessions = tempSessions;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading chat sessions: $e');
    }
  }

  // Send message
  Future<void> sendMessage(int senderId, int receiverId, String messageText) async {
    if (messageText.trim().isEmpty) return;

    final now = DateTime.now().toIso8601String();
    final message = ChatMessageModel(
      senderId: senderId,
      receiverId: receiverId,
      message: messageText.trim(),
      timestamp: now,
      isRead: 0,
    );

    try {
      final db = await DBHelper.instance.database;
      final id = await db.insert('chat_messages', message.toMap());
      
      // Add locally to list and trigger redraw
      _messages.add(ChatMessageModel(
        id: id,
        senderId: senderId,
        receiverId: receiverId,
        message: messageText.trim(),
        timestamp: now,
        isRead: 0,
      ));
      notifyListeners();

      await loadChatSessions(senderId);

      // Trigger automatic simulated seller reply if buyer is chatting with mock sellers (1, 2, or 3)
      if (receiverId <= 3 && senderId != receiverId) {
        _simulateSellerReply(senderId, receiverId, messageText.trim());
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  // Seller response simulator
  void _simulateSellerReply(int buyerId, int sellerId, String buyerMsg) {
    Timer(const Duration(seconds: 2), () async {
      final db = await DBHelper.instance.database;
      String replyText = '';
      final lowerMsg = buyerMsg.toLowerCase();

      // Simple contextual responses
      if (lowerMsg.contains('ready') || lowerMsg.contains('ada') || lowerMsg.contains('masih')) {
        replyText = 'Halo! Iya mas/mba, barangnya masih ready dan siap dibeli. Silakan langsung checkout dengan kurir lokal ya.';
      } else if (lowerMsg.contains('nego') || lowerMsg.contains('kurang') || lowerMsg.contains('pas')) {
        replyText = 'Harganya sudah disesuaikan dengan kondisi barang. Nego tipis saja ya, silakan ditawar via chat atau ajukan harga.';
      } else if (lowerMsg.contains('cod') || lowerMsg.contains('ketemu') || lowerMsg.contains('lokasi')) {
        replyText = 'Untuk COD bisa di daerah Bengkalis Kota (seperti Senggoro, Kelapapati, Wonosari). Tapi kalau sibuk, bisa pakai Kurir Lokal Bengkalis di aplikasi ini, murah dan praktis!';
      } else if (lowerMsg.contains('kondisi') || lowerMsg.contains('minus') || lowerMsg.contains('lecet')) {
        replyText = 'Kondisi barang sesuai dengan deskripsi foto mas. Sangat terawat dan pemakaian wajar. Boleh langsung dicek pas barang sampai.';
      } else {
        replyText = 'Halo! Terima kasih sudah bertanya. Barangnya ready sesuai deskripsi. Ada hal detail lain yang ingin ditanyakan?';
      }

      final now = DateTime.now().toIso8601String();
      final reply = ChatMessageModel(
        senderId: sellerId,
        receiverId: buyerId,
        message: replyText,
        timestamp: now,
        isRead: 0,
      );

      final id = await db.insert('chat_messages', reply.toMap());

      // If buyer is still viewing the chat, append message to list
      if (_messages.isNotEmpty && 
          ((_messages.first.senderId == buyerId && _messages.first.receiverId == sellerId) ||
           (_messages.first.senderId == sellerId && _messages.first.receiverId == buyerId))) {
        _messages.add(ChatMessageModel(
          id: id,
          senderId: sellerId,
          receiverId: buyerId,
          message: replyText,
          timestamp: now,
          isRead: 1, // Marked as read since buyer is in chat room
        ));
        
        // Mark as read in db as well since they are online
        await db.update(
          'chat_messages',
          {'isRead': 1},
          where: 'id = ?',
          whereArgs: [id],
        );
      }

      await loadChatSessions(buyerId);
      notifyListeners();
    });
  }

  // Send a custom Bidding Message
  Future<void> sendBidMessage({
    required int senderId,
    required int receiverId,
    required int productId,
    required double bidPrice,
    required String productName,
  }) async {
    final now = DateTime.now().toIso8601String();
    final text = 'Mengajukan penawaran untuk $productName seharga Rp ${NumberFormat("#,##0", "id_ID").format(bidPrice)}';
    
    final message = ChatMessageModel(
      senderId: senderId,
      receiverId: receiverId,
      message: text,
      timestamp: now,
      isRead: 0,
      isBid: 1,
      bidProductId: productId,
      bidPrice: bidPrice,
      bidStatus: 'pending',
    );

    try {
      final db = await DBHelper.instance.database;
      final id = await db.insert('chat_messages', message.toMap());
      
      _messages.add(message.toMap().containsKey('id') 
          ? ChatMessageModel.fromMap(message.toMap()) 
          : ChatMessageModel(
              id: id,
              senderId: senderId,
              receiverId: receiverId,
              message: text,
              timestamp: now,
              isRead: 0,
              isBid: 1,
              bidProductId: productId,
              bidPrice: bidPrice,
              bidStatus: 'pending',
            ));
      notifyListeners();

      await loadChatSessions(senderId);

      // Simple mock reply from system/mock sellers
      if (receiverId <= 3 && senderId != receiverId) {
        Timer(const Duration(seconds: 3), () async {
          // Mock auto-accept bids if they are close enough (e.g. above 80% of original price or random)
          // For demo simplicity, let's auto accept after 3 seconds!
          await respondToBid(id, 'accepted', senderId, receiverId);
        });
      }
    } catch (e) {
      debugPrint('Error sending bid message: $e');
    }
  }

  // Respond to Bidding (Accept / Reject)
  Future<void> respondToBid(int messageId, String newStatus, int currentUserId, int contactId) async {
    try {
      final db = await DBHelper.instance.database;
      await db.update(
        'chat_messages',
        {'bidStatus': newStatus},
        where: 'id = ?',
        whereArgs: [messageId],
      );

      // Load bid details to post a notification reply
      final result = await db.query('chat_messages', where: 'id = ?', whereArgs: [messageId]);
      if (result.isNotEmpty) {
        final bidMsg = ChatMessageModel.fromMap(result.first);
        final replyText = newStatus == 'accepted' 
            ? 'Penawaran Anda sebesar Rp ${NumberFormat("#,##0", "id_ID").format(bidMsg.bidPrice)} telah DISETUJUI! Silakan klik tombol "Beli Sekarang" di gelembung penawaran.'
            : 'Penawaran Anda sebesar Rp ${NumberFormat("#,##0", "id_ID").format(bidMsg.bidPrice)} ditolak.';

        final now = DateTime.now().toIso8601String();
        // Insert response message
        await db.insert('chat_messages', {
          'senderId': bidMsg.receiverId, // Seller responds
          'receiverId': bidMsg.senderId,
          'message': replyText,
          'timestamp': now,
          'isRead': 0,
          'isBid': 0,
        });
      }

      // Reload messages for the active room
      await loadMessages(currentUserId, contactId);
    } catch (e) {
      debugPrint('Error responding to bid: $e');
    }
  }
}
