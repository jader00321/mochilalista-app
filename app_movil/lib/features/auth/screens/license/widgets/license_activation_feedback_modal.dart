import 'dart:async';
import 'package:flutter/material.dart';

import 'package:app_movil/core/services/license/license_redeem_result.dart';
import 'package:app_movil/core/utils/app_date_formatter.dart';
import 'package:app_movil/core/utils/clipboard_helper.dart';

part 'activation_feedback/license_activation_feedback_cards_part.dart';
part 'activation_feedback/license_activation_feedback_actions_part.dart';

/// Modal animado e interactivo de retroalimentación tras un intento de canje de licencia.
class LicenseActivationFeedbackModal extends StatefulWidget {
  final LicenseRedeemResult result;
  final VoidCallback? onDone;
  final VoidCallback? onContactSupport;

  const LicenseActivationFeedbackModal({
    super.key,
    required this.result,
    this.onDone,
    this.onContactSupport,
  });

  /// Despliega el modal como BottomSheet responsivo con `SafeArea`.
  static Future<void> show(
    BuildContext context, {
    required LicenseRedeemResult result,
    VoidCallback? onDone,
    VoidCallback? onContactSupport,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LicenseActivationFeedbackModal(
        result: result,
        onDone: onDone,
        onContactSupport: onContactSupport,
      ),
    );
  }

  @override
  State<LicenseActivationFeedbackModal> createState() =>
      _LicenseActivationFeedbackModalState();
}

class _LicenseActivationFeedbackModalState
    extends State<LicenseActivationFeedbackModal> {
  bool _copiedDeviceId = false;
  Timer? _copyResetTimer;

  @override
  void dispose() {
    _copyResetTimer?.cancel();
    super.dispose();
  }

  void _copyToClipboard(String text) {
    ClipboardHelper.copyWithFeedback(context, text);
    _copyResetTimer?.cancel();
    setState(() => _copiedDeviceId = true);
    _copyResetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _copiedDeviceId = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final result = widget.result;
    final _ModalVisualConfig config = _resolveVisualConfig(
      result.status,
      isDark,
    );

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.24)
                        : Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) {
                  return Transform.scale(scale: scale, child: child);
                },
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: config.accentColor.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: config.accentColor.withValues(alpha: 0.35),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: config.accentColor.withValues(alpha: 0.2),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(config.icon, size: 38, color: config.accentColor),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                config.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                config.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 20),
              _buildContentCard(result, config, isDark),
              const SizedBox(height: 24),
              _buildActionButtons(result, config, isDark),
            ],
          ),
        ),
      ),
    );
  }
}
