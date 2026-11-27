import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/utils/app_feedback_helper.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/widgets/morphing_accordion.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';
import 'package:app_movil/features/smart_quotation/widgets/manual/client_search_modal.dart';

part 'header/quick_sale_client_actions_mixin.dart';
part 'header/quick_sale_client_sections_mixin.dart';

/// Cabecera de Caja Rápida con selección, edición y registro rápido de clientes.
class QuickSaleHeader extends StatefulWidget {
  final bool isGuest;
  final bool isDark;

  const QuickSaleHeader({
    super.key,
    required this.isGuest,
    required this.isDark,
  });

  @override
  State<QuickSaleHeader> createState() => _QuickSaleHeaderState();
}

abstract class _QuickSaleHeaderBase extends State<QuickSaleHeader> {
  final ClientService _clientService = ClientService();

  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _dniCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _notesCtrl;

  bool _isEditingClient = false;
  bool _showExtraWalkInFields = false;
  bool _isSavingClient = false;

  int? _lastClientId;
  String? _lastClientName;

  Future<void> _saveClientChanges(QuickSaleProvider quickProv);

  Future<void> _registerWalkInClient(QuickSaleProvider quickProv);

  String _formatPhone(String phone);
}

class _QuickSaleHeaderState extends _QuickSaleHeaderBase
    with _QuickSaleClientActionsMixin, _QuickSaleClientSectionsMixin {
  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _dniCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _dniCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = Provider.of<QuickSaleProvider>(context, listen: false);
    _syncFromProvider(provider);
  }

  void _syncFromProvider(QuickSaleProvider provider) {
    final idChanged = provider.clientId != _lastClientId;
    final clearedExternally =
        provider.clientId == null &&
        provider.clientName == null &&
        (_lastClientId != null ||
            (_lastClientName != null && _lastClientName!.isNotEmpty));
    final clientAssigned =
        provider.selectedClient != null &&
        provider.selectedClient!.id != _lastClientId;

    if (idChanged || clearedExternally || clientAssigned) {
      _lastClientId = provider.clientId;
      _lastClientName = provider.clientName;
      _isEditingClient = false;
      _showExtraWalkInFields = false;

      final client = provider.selectedClient;
      if (client != null) {
        _nameCtrl.text = client.fullName;
        _phoneCtrl.text = client.phone;
        _dniCtrl.text = client.docNumber ?? '';
        _addressCtrl.text = client.address ?? '';
        _notesCtrl.text = client.notes ?? '';
      } else {
        _nameCtrl.text = provider.clientName ?? '';
        _phoneCtrl.text = provider.clientPhone ?? '';
        _dniCtrl.clear();
        _addressCtrl.clear();
        _notesCtrl.text = provider.clientNote ?? '';
      }
    }
  }

  Widget? _buildSummaryBadge(QuickSaleProvider provider) {
    final hasSaldo = provider.clientSaldo > 0;
    final selectedClient = provider.selectedClient;
    final hasDebt = selectedClient != null && selectedClient.totalDebt > 0;

    if (hasSaldo) {
      return _badgeContainer(
        text: "${AppCurrency.format(provider.clientSaldo)} a favor",
        color: const Color(0xFF00E676),
        borderAlpha: 0.4,
      );
    }
    if (hasDebt) {
      return _badgeContainer(
        text: "Deuda: ${AppCurrency.format(selectedClient.totalDebt)}",
        color: const Color(0xFFFF5252),
        borderAlpha: 0.4,
      );
    }
    if (provider.clientId != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: (widget.isDark ? const Color(0xFF42A5F5) : Colors.blue)
              .withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          "Vinculado",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: widget.isDark
                ? const Color(0xFF64B5F6)
                : const Color(0xFF1565C0),
          ),
        ),
      );
    }
    if (provider.clientName != null && provider.clientName!.isNotEmpty) {
      return _badgeContainer(
        text: "Cliente de Paso",
        color: widget.isDark ? Colors.amber[300]! : Colors.amber[800]!,
        bgBase: Colors.amber,
        borderAlpha: 0.3,
      );
    }
    return null;
  }

  Widget _badgeContainer({
    required String text,
    required Color color,
    Color? bgBase,
    required double borderAlpha,
  }) {
    final effectiveBg = bgBase ?? color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: effectiveBg.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: effectiveBg.withValues(alpha: borderAlpha)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<QuickSaleProvider>(context);
    _syncFromProvider(provider);

    final selectedClient = provider.selectedClient;
    final hasDebt = selectedClient != null && selectedClient.totalDebt > 0;
    final badgeWidget = _buildSummaryBadge(provider);

    return MorphingAccordion(
      title: provider.clientName ?? "Datos del Cliente (Opcional)",
      icon: Icons.person_outline_rounded,
      iconColor: widget.isDark ? Colors.blue[300] : Colors.blue,
      summaryBadge: badgeWidget,
      backgroundColor: widget.isDark ? const Color(0xFF1E1E2A) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      content: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.person_search_rounded, size: 20),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "Buscar en Directorio de Clientes",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: widget.isDark
                      ? Colors.blue[300]
                      : Colors.blue[800],
                  side: BorderSide(
                    color: widget.isDark
                        ? Colors.blue.withValues(alpha: 0.3)
                        : Colors.blue.shade200,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _openClientSearch(context, provider),
              ),
            ),
            const SizedBox(height: 16),
            if (provider.clientSaldo > 0)
              _buildAlertBanner(
                icon: Icons.account_balance_wallet_rounded,
                iconColor: const Color(0xFF00C853),
                borderColor: const Color(0xFF00E676).withValues(alpha: 0.35),
                bgColor: widget.isDark
                    ? const Color(0xFF00E676).withValues(alpha: 0.12)
                    : const Color(0xFFE8F5E9),
                text:
                    "Saldo a favor disponible: ${AppCurrency.format(provider.clientSaldo)}",
                textColor: widget.isDark
                    ? const Color(0xFF69F0AE)
                    : const Color(0xFF1B5E20),
              ),
            if (hasDebt)
              _buildAlertBanner(
                icon: Icons.warning_amber_rounded,
                iconColor: const Color(0xFFFF5252),
                borderColor: const Color(0xFFFF5252).withValues(alpha: 0.35),
                bgColor: widget.isDark
                    ? const Color(0xFFFF5252).withValues(alpha: 0.12)
                    : const Color(0xFFFFEBEE),
                text:
                    "Deuda acumulada pendiente: ${AppCurrency.format(selectedClient.totalDebt)}",
                textColor: widget.isDark
                    ? const Color(0xFFFF8A80)
                    : const Color(0xFFB71C1C),
              ),
            if (provider.clientId != null)
              _buildSelectedClientCard(context, provider)
            else
              _buildWalkInClientSection(provider),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertBanner({
    required IconData icon,
    required Color iconColor,
    required Color borderColor,
    required Color bgColor,
    required String text,
    required Color textColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
