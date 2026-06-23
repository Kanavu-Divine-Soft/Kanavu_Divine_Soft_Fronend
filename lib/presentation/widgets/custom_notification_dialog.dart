import 'dart:ui';
import 'package:flutter/material.dart';

enum NotificationType { success, error, warning, info }

class CustomNotificationDialog extends StatelessWidget {
  final String title;
  final String message;
  final NotificationType type;
  final VoidCallback? onOkPressed;

  const CustomNotificationDialog({
    super.key,
    required this.title,
    required this.message,
    required this.type,
    this.onOkPressed,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    NotificationType type = NotificationType.info,
    VoidCallback? onOkPressed,
  }) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return CustomNotificationDialog(
          title: title,
          message: message,
          type: type,
          onOkPressed: onOkPressed,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 4 * animation.value,
            sigmaY: 4 * animation.value,
          ),
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
            ),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          ),
        );
      },
    );
  }

  Color get _iconColor {
    switch (type) {
      case NotificationType.success:
        return const Color(0xFF4CAF50); // Green
      case NotificationType.error:
        return const Color(0xFFE53935); // Red
      case NotificationType.warning:
        return const Color(0xFFFF9800); // Orange
      case NotificationType.info:
      default:
        return const Color(0xFF2196F3); // Blue
    }
  }

  IconData get _iconData {
    switch (type) {
      case NotificationType.success:
        return Icons.check;
      case NotificationType.error:
        return Icons.close;
      case NotificationType.warning:
        return Icons.priority_high;
      case NotificationType.info:
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Circle
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _iconColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _iconColor.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _iconData,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              
              // Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              
              // Message
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              
              // OK Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    if (onOkPressed != null) onOkPressed!();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF334155),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
