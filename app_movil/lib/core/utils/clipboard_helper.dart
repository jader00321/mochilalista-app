import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_movil/core/utils/app_feedback_helper.dart';

/// Helper centralizado DRY para copiar texto al portapapeles del sistema
/// con retroalimentación háptica y visual unificada.
class ClipboardHelper {
  ClipboardHelper._();

  static Future<void> copyWithFeedback(
    BuildContext context,
    String text, {
    String? feedbackMessage,
    bool haptic = true,
    bool useScaffoldSnackBar = false,
    bool useLoyaltyToast = false,
    Duration snackBarDuration = const Duration(seconds: 1),
  }) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (haptic) {
      HapticFeedback.selectionClick();
    }
    if (!context.mounted || feedbackMessage == null || feedbackMessage.isEmpty) {
      return;
    }
    if (useScaffoldSnackBar) {
      AppFeedbackHelper.showSnackBar(
        context,
        feedbackMessage,
        duration: snackBarDuration,
      );
      return;
    }
    AppFeedbackHelper.showSuccess(
      context,
      feedbackMessage,
      useLoyaltyToast: useLoyaltyToast,
    );
  }
}
