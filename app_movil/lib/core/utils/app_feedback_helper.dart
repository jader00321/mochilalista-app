import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/core/widgets/loyalty_toast_feedback.dart';
import 'package:app_movil/core/widgets/notification_toast_feedback.dart';

/// Facade unificado para emitir retroalimentación visual consistente en pantalla
/// (`CustomSnackBar`, `SnackBar` estándar, `LoyaltyToastFeedback` o `NotificationToastFeedback`).
class AppFeedbackHelper {
  AppFeedbackHelper._();

  static void showSuccess(
    BuildContext context,
    String message, {
    bool useNotificationToast = false,
    bool useLoyaltyToast = false,
    IconData? icon,
    Color? backgroundColor,
  }) {
    if (!context.mounted) return;
    if (useNotificationToast) {
      NotificationToastFeedback.showSuccess(context, message, icon: icon);
      return;
    }
    if (useLoyaltyToast) {
      LoyaltyToastFeedback.showSuccess(context, message);
      return;
    }
    CustomSnackBar.show(
      context,
      message: message,
      icon: icon,
      backgroundColor: backgroundColor,
      isError: false,
    );
  }

  static void showError(
    BuildContext context,
    String message, {
    bool useNotificationToast = false,
    IconData? icon,
    Color? backgroundColor,
  }) {
    if (!context.mounted) return;
    if (useNotificationToast) {
      NotificationToastFeedback.showError(context, message);
      return;
    }
    CustomSnackBar.show(
      context,
      message: message,
      icon: icon,
      backgroundColor: backgroundColor,
      isError: true,
    );
  }

  static void showInfo(
    BuildContext context,
    String message, {
    bool useNotificationToast = false,
    bool useLoyaltyToast = false,
    IconData? icon,
    Color? backgroundColor,
  }) {
    if (!context.mounted) return;
    if (useNotificationToast) {
      NotificationToastFeedback.showInfo(context, message);
      return;
    }
    if (useLoyaltyToast) {
      LoyaltyToastFeedback.showInfo(context, message);
      return;
    }
    CustomSnackBar.show(
      context,
      message: message,
      icon: icon,
      backgroundColor: backgroundColor,
      isError: false,
    );
  }

  static void showSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
    Color? backgroundColor,
    SnackBarBehavior? behavior,
  }) {
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        backgroundColor: backgroundColor,
        behavior: behavior,
      ),
    );
  }
}
