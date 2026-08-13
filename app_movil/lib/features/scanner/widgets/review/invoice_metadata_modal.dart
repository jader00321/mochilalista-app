import 'package:flutter/material.dart';
import 'package:app_movil/features/scanner/widgets/review/provider_info_card.dart';

class InvoiceMetadataModal {
  static void show({
    required BuildContext context,
    required bool isDark,
    required TextEditingController providerNameCtrl,
    required TextEditingController rucCtrl,
    required TextEditingController dateCtrl,
    required TextEditingController montoTotalCtrl,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
           decoration: BoxDecoration(
             color: isDark ? const Color(0xFF1A1A24) : Colors.grey[100],
             borderRadius: const BorderRadius.vertical(top: Radius.circular(24))
           ),
           padding: const EdgeInsets.only(top: 8, bottom: 24),
           child: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
                Container(width: 40, height: 5, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 16),
                Text("Datos del Comprobante", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 16),
                ProviderInfoCard(
                  providerNameCtrl: providerNameCtrl,
                  rucCtrl: rucCtrl,
                  dateCtrl: dateCtrl,
                  montoTotalCtrl: montoTotalCtrl, 
                  isDark: isDark,
                ),
             ]
           )
        )
      )
    );
  }
}
