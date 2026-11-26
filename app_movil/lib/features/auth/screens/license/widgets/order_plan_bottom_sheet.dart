import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:app_movil/core/utils/clipboard_helper.dart';
import 'package:app_movil/core/services/sync/client_sync_service.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';

part 'order_plan_bottom_sheet_sections.dart';

/// Modal Bottom Sheet interactivo y editable al pulsar "Pedir"
class OrderPlanBottomSheet extends StatefulWidget {
  final String planName;
  final String price;
  final String desc;
  final String aiScansBadge;
  final String hardwareId;
  final String defaultMessage;
  final String? syncToken;
  final bool isDark;
  final ValueChanged<String> onSendWhatsApp;

  static const String yapePlinLine =
      "• Estado: Pago realizado vía Yape/Plin. Adjunto comprobante.";
  static const String bankAccountLine =
      "• Consulta: Solicito números de cuenta para transferencia bancaria.";
  static const String invoiceLine =
      "• Requerimiento: Solicito emisión de Factura con RUC.";

  const OrderPlanBottomSheet({
    super.key,
    required this.planName,
    required this.price,
    required this.desc,
    required this.aiScansBadge,
    required this.hardwareId,
    required this.defaultMessage,
    this.syncToken,
    required this.isDark,
    required this.onSendWhatsApp,
  });

  /// Extrae el cuerpo libre del mensaje escrito por el usuario, despojándolo de
  /// tokens técnicos `MLS1-...` y de líneas correspondientes a complementos rápidos conocidos.
  static String extractUserBody(String fullText) {
    // 1. Quitar referencia de soporte MLS1 y regex general de sync tokens
    var body = ClientSyncService().removeSyncTokenFromMessage(fullText);

    // 2. Quitar complementos rápidos conocidos
    body = body.replaceAll(yapePlinLine, '');
    body = body.replaceAll(bankAccountLine, '');
    body = body.replaceAll(invoiceLine, '');

    // Variaciones defensivas por si el usuario editó espacios o viñetas
    body = body.replaceAll(
      RegExp(
        r'•\s*Estado:\s*Pago realizado vía Yape/Plin\.\s*Adjunto comprobante\.?',
      ),
      '',
    );
    body = body.replaceAll(
      RegExp(
        r'•\s*Consulta:\s*Solicito números de cuenta para transferencia bancaria\.?',
      ),
      '',
    );
    body = body.replaceAll(
      RegExp(r'•\s*Requerimiento:\s*Solicito emisión de Factura con RUC\.?'),
      '',
    );

    // 3. Normalizar saltos de línea repetidos
    body = body.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return body.trimRight();
  }

  /// Compone el mensaje final en 3 bloques estructurados:
  /// Bloque 1: Cuerpo del usuario / texto libre base
  /// Bloque 2: Complementos rápidos activos ordenados
  /// Bloque 3: Pie técnico de soporte (`Ref. soporte: MLS1-...`) estrictamente al final
  static String composeMessage({
    required String userBody,
    bool yapePlin = false,
    bool bankAccounts = false,
    bool invoice = false,
    bool includeLicenseRef = true,
    String? syncToken,
  }) {
    final cleanBody = userBody.trimRight();
    final complements = <String>[];
    if (yapePlin) complements.add(yapePlinLine);
    if (bankAccounts) complements.add(bankAccountLine);
    if (invoice) complements.add(invoiceLine);

    String result;
    if (complements.isNotEmpty) {
      if (cleanBody.isNotEmpty) {
        result = '$cleanBody\n\n${complements.join('\n')}';
      } else {
        result = complements.join('\n');
      }
    } else {
      result = cleanBody;
    }

    if (includeLicenseRef && syncToken != null && syncToken.isNotEmpty) {
      result = ClientSyncService().appendSyncTokenToMessage(result, syncToken);
    }

    return result;
  }

  @override
  State<OrderPlanBottomSheet> createState() => _OrderPlanBottomSheetState();
}

abstract class _OrderPlanBottomSheetStateBase extends State<OrderPlanBottomSheet> {
  late final TextEditingController _msgController;

  bool _yapePlinActive = false;
  bool _bankAccountsActive = false;
  bool _commercialInvoiceActive = false;
  bool _includeLicenseRef = true;
  bool _isInternalUpdating = false;

  @override
  void initState() {
    super.initState();
    final initialBody = OrderPlanBottomSheet.extractUserBody(
      widget.defaultMessage,
    );
    final initialMessage = OrderPlanBottomSheet.composeMessage(
      userBody: initialBody,
      yapePlin: false,
      bankAccounts: false,
      invoice: false,
      includeLicenseRef: _includeLicenseRef,
      syncToken: widget.syncToken,
    );
    _msgController = TextEditingController(text: initialMessage);
    _msgController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _msgController.removeListener(_onTextChanged);
    _msgController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_isInternalUpdating) return;
    final text = _msgController.text;
    final hasYape = text.contains("Pago realizado vía Yape/Plin");
    final hasBank = text.contains(
      "Solicito números de cuenta para transferencia bancaria",
    );
    final hasInv = text.contains("Solicito emisión de Factura con RUC");
    final hasSync = ClientSyncService().messageContainsSyncToken(text);

    if (hasYape != _yapePlinActive ||
        hasBank != _bankAccountsActive ||
        hasInv != _commercialInvoiceActive ||
        hasSync != _includeLicenseRef) {
      setState(() {
        _yapePlinActive = hasYape;
        _bankAccountsActive = hasBank;
        _commercialInvoiceActive = hasInv;
        _includeLicenseRef = hasSync;
      });
    } else {
      setState(() {});
    }
  }

  void _toggleChip(String chipType, bool isSelected) {
    final currentText = _msgController.text;
    final userBody = OrderPlanBottomSheet.extractUserBody(currentText);

    if (chipType == 'yape') _yapePlinActive = isSelected;
    if (chipType == 'bank') _bankAccountsActive = isSelected;
    if (chipType == 'invoice') _commercialInvoiceActive = isSelected;

    final composed = OrderPlanBottomSheet.composeMessage(
      userBody: userBody,
      yapePlin: _yapePlinActive,
      bankAccounts: _bankAccountsActive,
      invoice: _commercialInvoiceActive,
      includeLicenseRef: _includeLicenseRef,
      syncToken: widget.syncToken,
    );

    _isInternalUpdating = true;
    _msgController.text = composed;
    _msgController.selection = TextSelection.fromPosition(
      TextPosition(offset: _msgController.text.length),
    );
    _isInternalUpdating = false;
    setState(() {});
  }

  void _onLicenseRefSwitchChanged(bool val) {
    final currentText = _msgController.text;
    final userBody = OrderPlanBottomSheet.extractUserBody(currentText);
    _includeLicenseRef = val;

    final composed = OrderPlanBottomSheet.composeMessage(
      userBody: userBody,
      yapePlin: _yapePlinActive,
      bankAccounts: _bankAccountsActive,
      invoice: _commercialInvoiceActive,
      includeLicenseRef: _includeLicenseRef,
      syncToken: widget.syncToken,
    );

    _isInternalUpdating = true;
    _msgController.text = composed;
    _msgController.selection = TextSelection.fromPosition(
      TextPosition(offset: _msgController.text.length),
    );
    _isInternalUpdating = false;
    setState(() {});
  }

  void _resetText() {
    FocusManager.instance.primaryFocus?.unfocus();
    final defaultBody = OrderPlanBottomSheet.extractUserBody(
      widget.defaultMessage,
    );
    _yapePlinActive = false;
    _bankAccountsActive = false;
    _commercialInvoiceActive = false;
    _includeLicenseRef = true;

    final composed = OrderPlanBottomSheet.composeMessage(
      userBody: defaultBody,
      yapePlin: false,
      bankAccounts: false,
      invoice: false,
      includeLicenseRef: true,
      syncToken: widget.syncToken,
    );

    _isInternalUpdating = true;
    _msgController.text = composed;
    _msgController.selection = TextSelection.fromPosition(
      TextPosition(offset: _msgController.text.length),
    );
    _isInternalUpdating = false;
    setState(() {});

    CustomSnackBar.show(
      context,
      message: "Texto restablecido al formato oficial",
      isError: false,
    );
  }

  Widget _buildLicenseRefSwitch(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14141C) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _includeLicenseRef
              ? Colors.green.withValues(alpha: 0.35)
              : (isDark ? Colors.white10 : Colors.black12),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: (_includeLicenseRef ? Colors.green : Colors.grey)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.verified_user_outlined,
              size: 18,
              color: _includeLicenseRef ? Colors.green[700] : Colors.grey,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Incluir datos de mi licencia para atención rápida",
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Ayuda a verificar tu plan y agilizar tu solicitud",
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            key: const ValueKey("switch_include_license_ref"),
            value: _includeLicenseRef,
            activeThumbColor: Colors.green,
            activeTrackColor: Colors.green.withValues(alpha: 0.3),
            onChanged: _onLicenseRefSwitchChanged,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final padding = MediaQuery.paddingOf(context);
    final double bottomSafety =
        math.max(
          viewInsets.bottom,
          math.max(viewPadding.bottom, padding.bottom),
        ) +
        12.0;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E28) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Zona 1 — Cabecera Ejecutiva Fija
            _buildFixedHeader(isDark),
            Divider(
              height: 1,
              thickness: 1,
              color: isDark ? Colors.white10 : Colors.black12,
            ),

            // Zona 2 — Cuerpo Desplazable Cómodo (Flexible + SingleChildScrollView)
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSummaryCard(isDark),
                    const SizedBox(height: 12),
                    _buildLicenseRefSwitch(isDark),
                    _buildQuickChips(isDark),
                    const SizedBox(height: 14),
                    _buildEditableMessageField(isDark),
                  ],
                ),
              ),
            ),

            // Zona 3 — Zona de Acciones Inferior Fija (100% Protegida)
            _buildFixedActions(isDark, bottomSafety),
          ],
        ),
      ),
    );
  }
  Widget _buildFixedHeader(bool isDark);
  Widget _buildSummaryCard(bool isDark);
  Widget _buildQuickChips(bool isDark);
  Widget _buildEditableMessageField(bool isDark);
  Widget _buildFixedActions(bool isDark, double bottomSafety);
}

class _OrderPlanBottomSheetState extends _OrderPlanBottomSheetStateBase
    with _OrderPlanBottomSheetSectionsMixin {}
