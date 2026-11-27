import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/core/models/notification_preferences_model.dart';
import 'package:app_movil/core/providers/notification_provider.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/widgets/notification_toast_feedback.dart';
import 'package:app_movil/features/profile/widgets/notifications/archived_notifications_modal.dart';
import 'package:app_movil/features/profile/widgets/notifications/silenced_notifications_modal.dart';

part 'settings/notification_settings_sections_part.dart';
part 'settings/notification_settings_controls_part.dart';

/// Modal de configuración de canales, umbrales, gracia anti-spam y navegación de alertas.
class NotificationSettingsModal extends StatefulWidget {
  final bool isDark;

  const NotificationSettingsModal({super.key, required this.isDark});

  static Future<void> show(BuildContext context, {required bool isDark}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => NotificationSettingsModal(isDark: isDark),
    );
  }

  @override
  State<NotificationSettingsModal> createState() =>
      _NotificationSettingsModalState();
}

class _NotificationSettingsModalState extends State<NotificationSettingsModal> {
  late NotificationPreferences _localPrefs;
  bool _initialized = false;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _bandejasKey = GlobalKey();
  final GlobalKey _cobranzasKey = GlobalKey();
  final GlobalKey _inventarioKey = GlobalKey();
  final GlobalKey _cotizacionesKey = GlobalKey();
  final GlobalKey _tiemposKey = GlobalKey();
  final GlobalKey _interaccionKey = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final prov = Provider.of<NotificationProvider>(context, listen: false);
      _localPrefs = prov.preferences;
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _updatePreference(NotificationPreferences newPrefs) {
    setState(() {
      _localPrefs = newPrefs;
    });
    Provider.of<NotificationProvider>(
      context,
      listen: false,
    ).updatePreferences(newPrefs);
  }

  void _scrollToSection(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
        alignment: 0.05,
      );
    }
  }

  void _restoreDefaults() {
    final defaultPrefs = NotificationPreferences.defaultFor(
      _localPrefs.negocioId,
    );
    _updatePreference(defaultPrefs);
    NotificationToastFeedback.showSuccess(
      context,
      "Preferencias restauradas a valores predeterminados",
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final prov = Provider.of<NotificationProvider>(context);
    final effectiveBottom = InteractiveSheetWrapper.getEffectiveBottomPadding(
      context,
      minPadding: kMinDefensiveBottomClearance,
    );

    final bgCardColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final sectionBg = isDark ? const Color(0xFF1E1E28) : Colors.grey[50];
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.90,
      decoration: BoxDecoration(
        color: sectionBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          _buildModalHeader(
            context: context,
            isDark: isDark,
            textColor: textColor,
          ),
          _buildJumpPillsBar(isDark),
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              physics: const BouncingScrollPhysics(),
              children: _buildBodySections(
                context: context,
                prov: prov,
                isDark: isDark,
                bgCardColor: bgCardColor,
                textColor: textColor,
                subtitleColor: subtitleColor,
              ),
            ),
          ),
          _buildDockedFooter(
            context: context,
            isDark: isDark,
            bgCardColor: bgCardColor,
            effectiveBottom: effectiveBottom,
          ),
        ],
      ),
    );
  }

  Widget _buildModalHeader({
    required BuildContext context,
    required bool isDark,
    required Color textColor,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.settings_suggest_rounded,
                  color: isDark ? Colors.blue[300] : Colors.blue[700],
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Configuración de Alertas",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
                tooltip: "Cerrar",
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJumpPillsBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF191922) : Colors.grey[100],
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
          bottom: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildJumpPill(
              "Bandejas",
              Icons.inventory_2_outlined,
              () => _scrollToSection(_bandejasKey),
              isDark,
            ),
            const SizedBox(width: 6),
            _buildJumpPill(
              "Cobranzas",
              Icons.monetization_on_outlined,
              () => _scrollToSection(_cobranzasKey),
              isDark,
            ),
            const SizedBox(width: 6),
            _buildJumpPill(
              "Inventario",
              Icons.inventory_rounded,
              () => _scrollToSection(_inventarioKey),
              isDark,
            ),
            const SizedBox(width: 6),
            _buildJumpPill(
              "Cotizaciones",
              Icons.receipt_long_rounded,
              () => _scrollToSection(_cotizacionesKey),
              isDark,
            ),
            const SizedBox(width: 6),
            _buildJumpPill(
              "Tiempos",
              Icons.timer_outlined,
              () => _scrollToSection(_tiemposKey),
              isDark,
            ),
            const SizedBox(width: 6),
            _buildJumpPill(
              "Interacción",
              Icons.tune_rounded,
              () => _scrollToSection(_interaccionKey),
              isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDockedFooter({
    required BuildContext context,
    required bool isDark,
    required Color bgCardColor,
    required double effectiveBottom,
  }) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, effectiveBottom + 12),
      decoration: BoxDecoration(
        color: bgCardColor,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: OutlinedButton.icon(
              onPressed: _restoreDefaults,
              icon: const Icon(Icons.restart_alt_rounded, size: 16),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  "Restaurar recomendados",
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5),
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.grey[300] : Colors.grey[800],
                side: BorderSide(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  "Listo / Guardar",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
