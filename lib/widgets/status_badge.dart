import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;

    switch (status) {
      // Courier tracking statuses
      case 'Pending Pickup':
        backgroundColor = Colors.amber.shade50;
        textColor = Colors.amber.shade900;
        break;
      case 'Picked Up':
        backgroundColor = Colors.blue.shade50;
        textColor = Colors.blue.shade800;
        break;
      case 'In Transit':
        backgroundColor = Colors.indigo.shade50;
        textColor = Colors.indigo.shade800;
        break;
      case 'Delivered':
      case 'Completed':
        backgroundColor = AppTheme.lightGreen;
        textColor = AppTheme.primaryColor;
        break;

      // Transaction / Purchase statuses
      case 'Paid':
        backgroundColor = Colors.teal.shade50;
        textColor = Colors.teal.shade800;
        break;
      case 'Cancelled':
        backgroundColor = Colors.red.shade50;
        textColor = Colors.red.shade900;
        break;
      default:
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
