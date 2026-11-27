import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/models/user_model.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/utils/app_date_formatter.dart';
import 'package:app_movil/core/utils/app_feedback_helper.dart';
import 'package:app_movil/core/utils/cuota_date_helper.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/utils/whatsapp_uri_builder.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/models/extracted_list_model.dart';
import 'package:app_movil/features/smart_quotation/models/pdf_config_model.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/models/whatsapp_config_model.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';
import 'package:app_movil/features/smart_quotation/services/pdf_preferences_service.dart';
import 'package:app_movil/features/smart_quotation/services/whatsapp_preferences_service.dart';
import 'package:app_movil/features/smart_quotation/utils/pdf_generator.dart';
import 'package:app_movil/features/smart_quotation/widgets/manual/client_search_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/whatsapp/wa_business_section.dart';
import 'package:app_movil/features/smart_quotation/widgets/whatsapp/wa_client_section.dart';
import 'package:app_movil/features/smart_quotation/widgets/whatsapp/wa_config_section.dart';
import 'package:app_movil/features/smart_quotation/widgets/whatsapp/wa_final_preview_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/whatsapp/wa_message_editor.dart';

part 'whatsapp_preview/whatsapp_state_and_history_mixin.dart';
part 'whatsapp_preview/whatsapp_message_builder_mixin.dart';
part 'whatsapp_preview/whatsapp_message_financial_mixin.dart';
part 'whatsapp_preview/whatsapp_actions_and_gps_mixin.dart';
part 'whatsapp_preview/whatsapp_pdf_and_send_mixin.dart';

class WhatsAppPreviewScreen extends StatefulWidget {
  final int? quotationId;
  final int? saleId;
  final QuotationContextMode? contextMode;

  const WhatsAppPreviewScreen({
    super.key,
    this.quotationId,
    this.saleId,
    this.contextMode,
  });

  @override
  State<WhatsAppPreviewScreen> createState() => _WhatsAppPreviewScreenState();
}

abstract class _WhatsAppPreviewScreenStateBase
    extends State<WhatsAppPreviewScreen> {
  bool _isLoading = true;
  bool _isManualEdit = false;
  bool _isGpsLoading = false;

  late WhatsAppConfig _config;
  SmartQuotationModel? _quotation;
  Map<String, dynamic>? _saleData;

  ClientModel? _originalClient;
  ClientModel? _selectedClient;
  bool _isUsingSelectedClient = false;

  // Pila de Historial Undo / Redo (1 Solo Toque Garantizado)
  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  bool _isApplyingUndoRedo = false;
  Timer? _typingDebounceTimer;
  String _lastCommittedText = "";

  final _clientNameCtrl = TextEditingController();
  final _clientPhoneCtrl = TextEditingController();
  final _bizAddressCtrl = TextEditingController();
  final _bizRucCtrl = TextEditingController();
  final _bizPhoneCtrl = TextEditingController();
  final _bizPaymentCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  double? _bizLat;
  double? _bizLng;

  String _originalBizAddress = "";
  String _originalBizRuc = "";
  String _originalBizPhone = "";
  String _originalBizPayment = "";
  double? _originalBizLat;
  double? _originalBizLng;

  final Map<PaymentChipType, String> _sessionPaymentMemory = {};

  String get _currentContextKey {
    if (_saleData != null) {
      final bool isLoan =
          _saleData!['origen_venta'] == 'prestamo_personal' ||
          _saleData!['is_loan'] == true;
      return isLoan ? 'loan' : 'sale';
    }
    return 'quote';
  }

  @override
  void initState() {
    super.initState();
    _config = WhatsAppConfig();
    _loadData();
  }

  @override
  void dispose() {
    _typingDebounceTimer?.cancel();
    _clientNameCtrl.dispose();
    _clientPhoneCtrl.dispose();
    _bizAddressCtrl.dispose();
    _bizRucCtrl.dispose();
    _bizPhoneCtrl.dispose();
    _bizPaymentCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData();
  void _onMessageEdited(String newText);
  void _onClientDataChanged();

  void _regenerateMessage();
  void _appendLoanDetailSection(StringBuffer sb);
  void _appendTotalSummarySection(StringBuffer sb, {required bool isSale});
  void _appendInstallmentsScheduleSection(StringBuffer sb);
  void _appendDeliveryValidityPaymentBusinessClosing(
    StringBuffer sb, {
    required bool isSale,
    required bool isLoan,
  });

  Future<void> _hydrateProductImages();
  Future<void> _sharePdfAndMessage();
  Future<void> _executeSendProcess();
}

class _WhatsAppPreviewScreenState extends _WhatsAppPreviewScreenStateBase
    with
        _WhatsAppStateAndHistoryMixin,
        _WhatsAppMessageFinancialMixin,
        _WhatsAppMessageBuilderMixin,
        _WhatsAppActionsAndGpsMixin,
        _WhatsAppPdfAndSendMixin {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final authProv = Provider.of<AuthProvider>(context, listen: false);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final bool isSale = _saleData != null;
    final changedBusinessFields = _computeChangedBusinessFields(
      authProv.currentBusiness,
    );
    final bool hasBusinessChanges = changedBusinessFields.isNotEmpty;
    if (!hasBusinessChanges && _config.updateBusinessData) {
      _config.updateBusinessData = false;
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(isDark),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WaClientSection(
                      nameCtrl: _clientNameCtrl,
                      phoneCtrl: _clientPhoneCtrl,
                      isUsingSelectedClient: _isUsingSelectedClient,
                      originalClient: _originalClient,
                      updateClientData: _config.updateClientData,
                      onSearchTap: () => _showClientSelectorModal(isDark),
                      onRevertTap: _revertToOriginalClient,
                      onUpdateDataChanged: (v) =>
                          setState(() => _config.updateClientData = v),
                      onDataChanged: _onClientDataChanged,
                    ),
                    const SizedBox(height: 16),
                    WaConfigSection(
                      config: _config,
                      isSale: isSale,
                      contextKey: _currentContextKey,
                      quotation: _quotation,
                      saleData: _saleData,
                      businessName: authProv.currentBusiness?.commercialName,
                      businessPhone: _bizPhoneCtrl.text,
                      paymentAccountsText: _bizPaymentCtrl.text,
                      onChanged: () => setState(() => _regenerateMessage()),
                    ),
                    const SizedBox(height: 16),
                    WaBusinessSection(
                      phoneCtrl: _bizPhoneCtrl,
                      rucCtrl: _bizRucCtrl,
                      addressCtrl: _bizAddressCtrl,
                      paymentCtrl: _bizPaymentCtrl,
                      isGpsLoading: _isGpsLoading,
                      updateBusinessData: _config.updateBusinessData,
                      hasBusinessChanges: hasBusinessChanges,
                      changedBusinessFields: changedBusinessFields,
                      sessionPaymentMemory: _sessionPaymentMemory,
                      onGpsTap: _fillCurrentLocation,
                      onUpdateDataChanged: (v) =>
                          setState(() => _config.updateBusinessData = v),
                      onDataChanged: () => setState(() => _regenerateMessage()),
                    ),
                    const SizedBox(height: 20),
                    _buildMessageEditor(isDark),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
            _buildBottomPreviewButton(context, isDark),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      titleSpacing: 0,
      actionsPadding: EdgeInsets.zero,
      title: const FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          "Editor WhatsApp",
          maxLines: 1,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      backgroundColor: isDark
          ? const Color(0xFF142C23)
          : const Color(0xFF00A884),
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        const InfoTooltipButton(
          iconColor: Colors.white,
          constraints: BoxConstraints(minWidth: 32, minHeight: 32),
          padding: EdgeInsets.all(6),
          title: "Guía del Editor WhatsApp",
          description:
              "Personaliza mensajes de cotización, comprobantes de venta o recordatorios de cuotas con estilos comerciales y vista previa realista.",
          tips: [
            InfoTip(
              icon: Icons.style_rounded,
              text:
                  "Elige entre 6 estilos comerciales (Formal, Ejecutivo, Oferta Urgente y más) con 1 solo toque.",
            ),
            InfoTip(
              icon: Icons.tune_rounded,
              text:
                  "Activa o oculta subtotales, ahorros, cronograma de pagos, cuentas bancarias y datos del negocio al instante.",
            ),
            InfoTip(
              icon: Icons.visibility_rounded,
              text:
                  "Toca el botón de ayuda (i) en las tarjetas para previsualizar el bloque exacto generado con tus datos.",
            ),
            InfoTip(
              icon: Icons.history_rounded,
              text:
                  "Edita libremente el mensaje con historial deshacer/rehacer ilimitado y envío directo al contacto.",
            ),
            InfoTip(
              icon: Icons.chat_bubble_outline_rounded,
              text:
                  "Verifica la burbuja de chat realista y confirma la actualización del teléfono o negocio antes de enviar.",
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.restart_alt, size: 24),
          tooltip: "Restaurar Mensaje Original",
          visualDensity: VisualDensity.compact,
          onPressed: () {
            _recordUndoSnapshot();
            setState(() => _isManualEdit = false);
            _regenerateMessage();
            AppFeedbackHelper.showSuccess(
              context,
              "Mensaje restaurado a su plantilla original",
            );
          },
        ),
      ],
    );
  }

  void _revertToOriginalClient() {
    setState(() {
      _isUsingSelectedClient = false;
      _selectedClient = null;
      if (_originalClient != null) {
        _clientNameCtrl.text = PdfGenerator.cleanClientDisplayName(
          _originalClient!.fullName,
        );
        _clientPhoneCtrl.text = _originalClient!.phone;
      } else {
        final raw =
            _saleData?['cliente_nombre'] ?? _quotation?.clientName ?? "";
        _clientNameCtrl.text = PdfGenerator.cleanClientDisplayName(raw);
        _clientPhoneCtrl.clear();
      }
      _onClientDataChanged();
    });
  }

  Widget _buildMessageEditor(bool isDark) {
    return WaMessageEditor(
      isDark: isDark,
      isManualEdit: _isManualEdit,
      messageCtrl: _messageCtrl,
      config: _config,
      paymentAccountsText: _bizPaymentCtrl.text,
      canUndo: _undoStack.isNotEmpty,
      canRedo: _redoStack.isNotEmpty,
      onUndo: _undoStack.isNotEmpty ? _handleUndo : null,
      onRedo: _redoStack.isNotEmpty ? _handleRedo : null,
      onBeforeChange: () => _recordUndoSnapshot(),
      onStyleChanged: (newStyle) {
        _recordUndoSnapshot();
        setState(() {
          _config.applyTemplateStyle(newStyle);
          _isManualEdit = false;
          _regenerateMessage();
        });
      },
      onOptionToggled: (optionKey, newValue) {
        _recordUndoSnapshot();
        setState(() {
          switch (optionKey) {
            case 'unit_prices':
              _config.showUnitPrices = newValue;
              break;
            case 'brand_package':
              _config.showBrandPackage = newValue;
              break;
            case 'client_data':
              _config.showClientData = newValue;
              break;
            case 'validity':
              _config.includeValidity = newValue;
              break;
            case 'delivery':
              _config.includeDelivery = newValue;
              break;
            case 'payment':
              _config.showPaymentInfo = newValue;
              break;
          }
          _isManualEdit = false;
          _regenerateMessage();
        });
      },
      onRegenerateAuto: () {
        _recordUndoSnapshot();
        setState(() {
          _isManualEdit = false;
          _regenerateMessage();
        });
        AppFeedbackHelper.showSuccess(
          context,
          "Plantilla regenerada automáticamente",
        );
      },
      onChanged: _onMessageEdited,
    );
  }

  Widget _buildBottomPreviewButton(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, -10),
            ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: () => _showFinalPreviewModal(isDark),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A884),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: isDark ? 0 : 4,
            ),
            icon: const Icon(Icons.remove_red_eye, size: 22),
            label: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                "VISUALIZAR MENSAJE FINAL",
                maxLines: 1,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
