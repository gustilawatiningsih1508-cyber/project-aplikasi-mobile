import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../theme/app_theme.dart';
import 'chat_room_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isAuthenticated) {
        Provider.of<ChatProvider>(context, listen: false)
            .loadChatSessions(auth.currentUser!.id!);
      }
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);

    if (!auth.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pesan Masuk')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_outlined, size: 80, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text(
                  'Mulai Obrolan Anda',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Silakan masuk terlebih dahulu untuk melihat pesan atau berdiskusi dengan penjual.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final sessions = chatProvider.sessions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Obrolan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryColor),
            onPressed: () => chatProvider.loadChatSessions(auth.currentUser!.id!),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => chatProvider.loadChatSessions(auth.currentUser!.id!),
        child: sessions.isEmpty
            ? _buildEmptyState()
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: sessions.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final session = sessions[index];
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundImage: session.contactPhoto.startsWith('http')
                          ? NetworkImage(session.contactPhoto)
                          : null,
                      child: session.contactPhoto.isEmpty
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(
                      session.contactName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    subtitle: Text(
                      session.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: session.unreadCount > 0 ? Colors.black87 : AppTheme.textSecondary,
                        fontWeight: session.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatTime(session.lastTimestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: session.unreadCount > 0 ? AppTheme.primaryColor : Colors.grey,
                            fontWeight: session.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        if (session.unreadCount > 0) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${session.unreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatRoomScreen(
                            contactId: session.contactId,
                            contactName: session.contactName,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'Belum ada obrolan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Pesan Anda ketika menawar produk akan muncul di sini.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      final now = DateTime.now();
      
      if (date.year == now.year && date.month == now.month && date.day == now.day) {
        return DateFormat('HH:mm').format(date);
      } else {
        return DateFormat('dd/MM').format(date);
      }
    } catch (_) {
      return '';
    }
  }
}
