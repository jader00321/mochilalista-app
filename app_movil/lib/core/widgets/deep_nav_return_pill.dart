import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/scanner/providers/scanner_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/matching_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

// Pantallas destino de los 4 procesos
import 'package:app_movil/features/smart_quotation/screens/quick_sale_screen.dart';
import 'package:app_movil/features/scanner/screens/invoice_staging_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/matching_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/manual_quotation_screen.dart';

/// 💊 DeepNavReturnPill - Mobile Awards Retorno en 1 Toque
///
/// Flota discretamente en rutas secundarias profundas (Catálogo, Clientes, Inventario, etc.)
/// cuando hay un proceso activo en segundo plano (Caja Rápida, Factura en Staging,
/// Conciliación de Lista Escolar o Cotización Manual), permitiendo retornar instantáneamente
/// sin perder contexto.
///
/// 🛡️ BLINDAJES RUNTIME:
/// 1. Solo se muestra si ModalRoute.canPop == true (oculto en IndexedStack de HomeScreen).
/// 2. Se auto-oculta si currentScreenId coincide con la tarea activa.
/// 3. Se ubica a la izquierda (left: 16) para no colisionar con los FABs (right: 16).
class DeepNavReturnPill extends StatelessWidget {
  /// Posición vertical: true para fijar abajo con padding seguro, false para arriba.
  final bool isBottom;

  /// Identificador de la pantalla actual para auto-ocultarse si coincide con la tarea activa.
  /// Valores esperados: 'quick_sale', 'scanner_staging', 'matching', 'manual_quote'.
  final String? currentScreenId;

  const DeepNavReturnPill({
    super.key,
    this.isBottom = true,
    this.currentScreenId,
  });

  @override
  Widget build(BuildContext context) {
    // 🛡️ Regla 1: Ocultar si estamos en el nivel raíz (ej. HomeScreen IndexedStack)
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    if (!canPop) return const SizedBox.shrink();

    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.hasActiveContext) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final quickProv = Provider.of<QuickSaleProvider>(context);
    final scannerProv = Provider.of<ScannerProvider>(context);
    final matchingProv = Provider.of<MatchingProvider>(context);
    final smartProv = Provider.of<SmartQuotationProvider>(context);

    // Prioridad 1: Caja Rápida con productos
    if (quickProv.cartItems.isNotEmpty && currentScreenId != 'quick_sale') {
      final count = quickProv.cartItems.length;
      final total = quickProv.totalToPay;

      return _buildPill(
        context,
        isDark: isDark,
        icon: Icons.point_of_sale_rounded,
        label: 'Caja Rápida ($count)',
        sublabel: 'S/ ${total.toStringAsFixed(2)}',
        color: const Color(0xFF2E7D32),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const QuickSaleScreen()),
          );
        },
      );
    }

    // Prioridad 2: Factura en Staging / Escáner
    if (scannerProv.stagingData != null &&
        scannerProv.stagingData!.productosAgrupados.isNotEmpty &&
        currentScreenId != 'scanner_staging') {
      final count = scannerProv.stagingData!.productosAgrupados.length;

      return _buildPill(
        context,
        isDark: isDark,
        icon: Icons.receipt_long_rounded,
        label: 'Factura en Staging',
        sublabel: '$count grupos pendientes',
        color: const Color(0xFFE65100),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const InvoiceStagingScreen()),
          );
        },
      );
    }

    // Prioridad 3: Conciliación / Matching de Lista Escolar
    if (matchingProv.pairs.isNotEmpty && currentScreenId != 'matching') {
      final count = matchingProv.pairs.length;
      final total = matchingProv.totalNetAmount;

      return _buildPill(
        context,
        isDark: isDark,
        icon: Icons.checklist_rounded,
        label: 'Conciliación Lista',
        sublabel: '$count ítems • S/ ${total.toStringAsFixed(2)}',
        color: const Color(0xFF6A1B9A),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MatchingScreen(
                extractedItems: matchingProv.pairs.map((p) => p.sourceItem).toList(),
                metadata: matchingProv.metadata,
              ),
            ),
          );
        },
      );
    }

    // Prioridad 4: Borrador de Cotización Manual
    if (smartProv.hasManualDraft && currentScreenId != 'manual_quote') {
      final count = smartProv.draftManualItems?.length ?? 0;

      return _buildPill(
        context,
        isDark: isDark,
        icon: Icons.edit_note_rounded,
        label: 'Cotización en curso',
        sublabel: '$count ítems',
        color: const Color(0xFF00838F),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ManualQuotationScreen(quotationId: null),
            ),
          );
        },
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildPill(
    BuildContext context, {
    required bool isDark,
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
    required VoidCallback onTap,
  }) {
    final effectiveBottom = isBottom
        ? InteractiveSheetWrapper.getEffectiveBottomPadding(context, minPadding: 80)
        : 16.0;

    return Positioned(
      bottom: isBottom ? effectiveBottom : null,
      top: isBottom ? null : 16.0,
      left: 16, // 🛡️ Ubicado a la izquierda para evitar colisión con FABs (right: 16)
      child: Material(
        elevation: isDark ? 6 : 8,
        shadowColor: color.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(30),
        color: isDark ? const Color(0xFF222230) : Colors.white,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: color.withValues(alpha: isDark ? 0.6 : 0.35),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      sublabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: color,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
