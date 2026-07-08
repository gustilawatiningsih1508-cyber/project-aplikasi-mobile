import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../theme/app_theme.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifikasi')),
        body: const Center(child: Text('Anda harus masuk.')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded),
            tooltip: 'Tandai semua dibaca',
            onPressed: () {
              Provider.of<NotificationProvider>(context, listen: false)
                  .markAllRead(user.id!);
            },
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
          }

          final notifications = provider.notifications;
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada notifikasi',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Notifikasi Anda akan muncul di sini.',
                    style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index];
              final isRead = notif['isRead'] == 1;
              
              IconData icon;
              Color iconColor;
              switch (notif['type']) {
                case 'welcome':
                  icon = Icons.waving_hand_rounded;
                  iconColor = AppTheme.primaryColor;
                  break;
                case 'courier_approved':
                  icon = Icons.verified_rounded;
                  iconColor = AppTheme.successColor;
                  break;
                case 'transaction':
                  icon = Icons.receipt_long_rounded;
                  iconColor = AppTheme.warningColor;
                  break;
                default:
                  icon = Icons.notifications_rounded;
                  iconColor = AppTheme.accentColor;
              }

              return Card(
                elevation: isRead ? 0 : 2,
                color: isRead ? Colors.white : AppTheme.lightBlue.withOpacity(0.3),
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: isRead ? Colors.grey.shade100 : AppTheme.primaryColor.withOpacity(0.3)),
                ),
                child: InkWell(
                  onTap: () {
                    if (!isRead) {
                      provider.markRead(notif['id'], user.id!);
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: iconColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: iconColor, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notif['title'],
                                style: GoogleFonts.poppins(
                                  fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                                  fontSize: 14,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                notif['body'],
                                style: GoogleFonts.poppins(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _formatTime(notif['createdAt']),
                                style: GoogleFonts.poppins(
                                  color: Colors.grey.shade500,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTime(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      return DateFormat('dd MMM yyyy, HH:mm').format(date);
    } catch (_) {
      return '';
    }
  }
}
