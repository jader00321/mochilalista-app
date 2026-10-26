import 'package:flutter/material.dart';
import 'package:app_movil/features/smart_quotation/providers/matching_provider.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';

/// 🏆 MatchingSmartBottomBar (Mobile Awards Standard)
/// Barra inferior fija para la Conciliación IA / Cotización Inteligente.
/// Integra el resumen financiero con el disparador de acciones primarias,
/// eliminando completamente el FAB flotante que tapaba los productos.
class MatchingSmartBottomBar extends StatelessWidget {
  final MatchingProvider provider;
  final bool isDark;
  final TextTheme theme;
  final bool isClient;
  final VoidCallback onActionTap;
  final bool isEnabled;

  const MatchingSmartBottomBar({
    super.key,
    required this.provider,
    required this.isDark,
    required this.theme,
    this.isClient = false,
    required this.onActionTap,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBottom = InteractiveSheetWrapper.getEffectiveBottomPadding(context, minPadding: 16.0);
    final hasSavings = provider.totalSavingsAmount > 0;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, effectiveBottom),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2A) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 15,
            offset: const Offset(0, -4),
          )
        ],
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Row(
          children: [
            // Resumen Financiero a la izquierda
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasSavings)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        "Ahorro: ${AppCurrency.format(provider.totalSavingsAmount)}",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFF69F0AE) : const Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                  Text(
                    "TOTAL A PAGAR",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: provider.totalNetAmount == 0
                        ? Text(
                            "Falta vincular",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.grey[500] : Colors.grey[600],
                            ),
                          )
                        : Text(
                            AppCurrency.format(provider.totalNetAmount),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: isDark ? const Color(0xFF64B5F6) : const Color(0xFF1565C0),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Botón de acción principal a la derecha
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: isEnabled ? onActionTap : null,
                icon: Icon(
                  isClient ? Icons.send_rounded : Icons.bolt_rounded,
                  size: 18,
                ),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isClient ? "Enviar Pedido" : "Acciones",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    if (!isClient) ...[
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_drop_up_rounded, size: 20),
                    ],
                  ],
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isClient
                      ? (isDark ? const Color(0xFF00C853) : const Color(0xFF2E7D32))
                      : const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 🏆 Bottom Sheet Modal de Acciones para Cotización Inteligente
class MatchingActionsBottomSheet extends StatelessWidget {
  final bool isDark;
  final Function(String actionType) onActionSelected;

  const MatchingActionsBottomSheet({
    super.key,
    required this.isDark,
    required this.onActionSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required bool isDark,
    required Function(String actionType) onActionSelected,
  }) {
    return InteractiveSheetWrapper.show(
      context: context,
      builder: (_) => MatchingActionsBottomSheet(
        isDark: isDark,
        onActionSelected: onActionSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.blue.withValues(alpha: 0.2)
                      : Colors.blue.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.bolt_rounded,
                  color: isDark ? Colors.blue[300] : Colors.blue[800],
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Procesar Cotización",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      "Selecciona una acción para continuar",
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          _buildOptionTile(
            icon: Icons.list_alt_rounded,
            title: "Guardar y ver Mesa de Trabajo",
            subtitle: "Guarda la cotización y abre el desglose de productos",
            color: const Color(0xFF2563EB),
            onTap: () {
              Navigator.pop(context);
              onActionSelected('save');
            },
          ),
          const SizedBox(height: 10),

          _buildOptionTile(
            icon: Icons.chat_rounded,
            title: "Enviar por WhatsApp",
            subtitle: "Previsualiza el mensaje formal con formato prolijo",
            color: const Color(0xFF00C853),
            onTap: () {
              Navigator.pop(context);
              onActionSelected('whatsapp');
            },
          ),
          const SizedBox(height: 10),

          _buildOptionTile(
            icon: Icons.picture_as_pdf_rounded,
            title: "Generar PDF Directo",
            subtitle: "Crea el archivo PDF imprimible para el cliente",
            color: const Color(0xFFEF4444),
            onTap: () {
              Navigator.pop(context);
              onActionSelected('pdf');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF23232F) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey.shade300,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: isDark ? Colors.grey[500] : Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}