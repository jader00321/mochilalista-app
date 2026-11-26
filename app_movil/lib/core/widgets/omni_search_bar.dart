import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/widgets/search/omni_search_sheet.dart';

export 'package:app_movil/core/widgets/search/omni_search_models_and_engine.dart';
export 'package:app_movil/core/widgets/search/omni_search_result_cards.dart';
export 'package:app_movil/core/widgets/search/omni_search_sheet.dart'
    show OmniSearchSheet;

class OmniSearchBar extends StatelessWidget {
  final VoidCallback? onBarcodeTap;

  const OmniSearchBar({super.key, this.onBarcodeTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _openOmniSearchModal(context),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey.shade300,
            width: 1,
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              color: isDark ? Colors.blue[300] : Colors.blue[700],
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final String placeholderText = width >= 260
                      ? "Buscar productos, clientes o ventas"
                      : (width >= 190
                            ? "Buscar productos o clientes"
                            : "Buscar productos...");

                  return FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      placeholderText,
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[500],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                    ),
                  );
                },
              ),
            ),
            if (onBarcodeTap != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.qr_code_scanner_rounded,
                  color: isDark ? Colors.blue[300] : Colors.blue[600],
                  size: 22,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onBarcodeTap,
                tooltip: "Escanear código de barras",
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openOmniSearchModal(BuildContext context) {
    HapticFeedback.lightImpact();
    InteractiveSheetWrapper.show(
      context: context,
      builder: (ctx) => const OmniSearchSheet(),
    );
  }
}
