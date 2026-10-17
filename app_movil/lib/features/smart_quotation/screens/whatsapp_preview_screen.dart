import 'dart:convert'; 
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart'; 

import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart'; 
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';

import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/models/whatsapp_config_model.dart';

import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/features/smart_quotation/widgets/manual/client_search_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/whatsapp/wa_client_section.dart';
import 'package:app_movil/features/smart_quotation/widgets/whatsapp/wa_config_section.dart';
import 'package:app_movil/features/smart_quotation/widgets/whatsapp/wa_business_section.dart';
import 'package:app_movil/features/smart_quotation/widgets/whatsapp/wa_message_editor.dart';
import 'package:app_movil/features/smart_quotation/widgets/whatsapp/wa_final_preview_modal.dart';

class WhatsAppPreviewScreen extends StatefulWidget {
  final int? quotationId; 
  final int? saleId;      

  const WhatsAppPreviewScreen({super.key, this.quotationId, this.saleId});

  @override
  State<WhatsAppPreviewScreen> createState() => _WhatsAppPreviewScreenState();
}

class _WhatsAppPreviewScreenState extends State<WhatsAppPreviewScreen> {
  bool _isLoading = true;
  bool _isManualEdit = false;
  bool _isGpsLoading = false; 
  
  late WhatsAppConfig _config;
  SmartQuotationModel? _quotation;
  Map<String, dynamic>? _saleData; 
  
  ClientModel? _originalClient; 
  ClientModel? _selectedClient; 
  bool _isUsingSelectedClient = false;

  final _clientNameCtrl = TextEditingController();
  final _clientPhoneCtrl = TextEditingController();
  final _bizAddressCtrl = TextEditingController();
  final _bizRucCtrl = TextEditingController();
  final _bizPhoneCtrl = TextEditingController();
  final _bizPaymentCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  double? _bizLat; 
  double? _bizLng; 

  @override
  void initState() {
    super.initState();
    _config = WhatsAppConfig();
    _loadData();
  }

  @override
  void dispose() {
    _clientNameCtrl.dispose();
    _clientPhoneCtrl.dispose();
    _bizAddressCtrl.dispose();
    _bizRucCtrl.dispose();
    _bizPhoneCtrl.dispose();
    _bizPaymentCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final clientService = ClientService();

    try {
      if (widget.saleId != null) {
        final saleProv = Provider.of<SaleProvider>(context, listen: false);
        _saleData = await saleProv.getSaleDetailSilently(widget.saleId!); // Usamos un método silencioso para no cargar la UI
        if (_saleData != null && _saleData!['cotizacion'] != null) {
          _quotation = SmartQuotationModel.fromJson(_saleData!['cotizacion']);
        }
      } else if (widget.quotationId != null) {
        final qProv = Provider.of<SmartQuotationProvider>(context, listen: false);
        _quotation = await qProv.getQuotationById(widget.quotationId!);
      }
      
      if (_quotation != null) {
        final bool isQuickSale = _saleData != null && _saleData!['origen_venta'] == 'pos_rapido';
        _clientNameCtrl.text = _saleData?['cliente_nombre'] ?? _quotation!.clientName ?? (isQuickSale ? "Cliente de Mostrador" : "");
        
        final int? targetClientId = _saleData?['cliente_id'] ?? _quotation!.clientId;
        
        if (targetClientId != null) {
          final clientData = await clientService.getClientById(targetClientId);
          if (clientData != null) {
            _originalClient = clientData;
            _clientNameCtrl.text = clientData.fullName;
            _clientPhoneCtrl.text = clientData.phone;
          }
        }

        final biz = authProv.currentBusiness;
        if (biz != null) {
          _bizAddressCtrl.text = biz.address ?? "";
          _bizRucCtrl.text = biz.ruc ?? "";
          _bizPhoneCtrl.text = authProv.user?.phone ?? "";
          _bizPaymentCtrl.text = biz.paymentInfo ?? "BCP: 000-000...\nYape: 999...";
          _bizLat = biz.latitud;
          _bizLng = biz.longitud;
        }
      }
      
      _regenerateMessage();

    } catch (e) {
      debugPrint("Error loading WA data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _regenerateMessage() {
    if (_isManualEdit || _quotation == null) return;

    final sb = StringBuffer();
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final bool isSale = _saleData != null;

    final String clientName = _clientNameCtrl.text.trim().isEmpty ? 'Cliente' : _clientNameCtrl.text.trim();

    sb.writeln("¡Hola *$clientName*! 👋");
    sb.writeln("");
    
    if (isSale) {
      final double total = (_saleData!['monto_total'] ?? 0).toDouble();
      final double paid = (_saleData!['monto_pagado'] ?? 0).toDouble();
      final double debt = total - paid;
      final bool isQuickSale = _saleData!['origen_venta'] == 'pos_rapido';
      
      if (debt > 0.01) {
        sb.writeln("Muchas gracias por tu preferencia. A continuación, te comparto el resumen de tu compra:");
        if (_config.showDebtInfo) {
          sb.writeln("");
          sb.writeln("📌 *Recordatorio:* Tienes un saldo pendiente de *${currency.format(debt).trim()}*.");
        }
      } else {
        if (isQuickSale) {
          sb.writeln("¡Muchas gracias por tu compra! Te adjunto el detalle de los productos que llevaste:");
        } else {
          sb.writeln("¡Gracias por confirmar tu pedido! Aquí tienes el comprobante de tu compra:");
        }
      }

      final String deliveryStatus = _saleData!['estado_entrega'] ?? 'entregado';
      if (_config.showDeliveryInfo && deliveryStatus != 'entregado') {
        sb.writeln("");
        sb.writeln("📦 *ESTADO DEL PEDIDO*");
        sb.writeln("▪ Estado: *${deliveryStatus.toUpperCase().replaceAll('_', ' ')}*");
        if (_saleData!['fecha_entrega'] != null) {
          final dateFormatted = DateFormat('dd/MM/yyyy').format(DateTime.parse(_saleData!['fecha_entrega']));
          sb.writeln("▪ Entrega programada: $dateFormatted");
        }
      }

    } else {
      sb.writeln("Es un gusto saludarte. Aquí te envío la cotización detallada de los productos solicitados:");
    }
    sb.writeln("");

    sb.writeln("🛍️ *DETALLE DE PRODUCTOS*");
    for (var item in _quotation!.items) {
      final lineTotal = item.quantity * item.unitPriceApplied;
      final hasDiscount = (item.originalUnitPrice - item.unitPriceApplied) > 0.01;

      String name = (item.bundleId != null) 
          ? (item.productName ?? 'Paquete') 
          : item.displayName;

      String line = "▪ ${item.quantity}x $name";
      
      if (_config.showSubtotals) {
        line += " -> *${currency.format(lineTotal).trim()}*";
      }

      if (item.bundleId != null && item.specificName != null && item.specificName!.isNotEmpty && item.specificName != "Paquete") {
        line += "\n   _${item.specificName}_";
      }

      if (_config.showSavingsSection && _config.showDiscountDetail && hasDiscount) {
        final savings = item.originalUnitPrice - item.unitPriceApplied;
        line += "\n   └ _Ahorras: ${currency.format(savings).trim()} c/u_";
      }
      sb.writeln(line);
    }
    sb.writeln("");

    if (_config.showTotalGlobal) {
      double finalTotal = isSale ? (_saleData!['monto_total'] ?? 0).toDouble() : _quotation!.totalAmount;
      final double finalSavings = isSale ? (_saleData!['descuento_aplicado'] ?? 0).toDouble() : _quotation!.totalSavings;

      sb.writeln("📊 *RESUMEN TOTAL*");
      sb.writeln("▪ Importe Total: *${currency.format(finalTotal).trim()}*");
      if (_config.showSavingsSection && finalSavings > 0.01) {
        sb.writeln("▪ Ahorro Total: *${currency.format(finalSavings).trim()}* 🎉");
      }

      if (isSale) {
        double paid = (_saleData!['monto_pagado'] ?? 0.0).toDouble();
        double debt = finalTotal - paid;
        if (debt < 0) debt = 0;
        
        if (debt > 0.01) {
          sb.writeln("▪ Pagado: *${currency.format(paid).trim()}*");
          if (_config.showDebtInfo) {
            sb.writeln("▪ Saldo Pendiente: *${currency.format(debt).trim()}* ⚠️");
          }
        }
      }
      sb.writeln("");
    }

    if (isSale && _config.showInstallmentDetails) {
       final List<dynamic>? cuotasRaw = _saleData!['cuotas'];
       if (cuotasRaw != null && cuotasRaw.isNotEmpty) {
          sb.writeln("📅 *CRONOGRAMA DE PAGOS* (${cuotasRaw.length} Cuotas)");
          for (var c in cuotasRaw) {
             final bool pagado = c['estado'] == 'pagado';
             final String icon = pagado ? "✅ Pagado" : "⏳ Pendiente";
             final String date = DateFormat('dd/MM/yyyy').format(DateTime.parse(c['fecha_vencimiento']));
             sb.writeln("▪ Cuota ${c['numero_cuota']}: *${currency.format(c['monto']).trim()}* (Vence: $date) - $icon");
          }
          sb.writeln("");
       }
    }

    if (_config.showPaymentInfo) {
      if (isSale) {
        final double total = (_saleData!['monto_total'] ?? 0).toDouble();
        final double paid = (_saleData!['monto_pagado'] ?? 0).toDouble();
        
        if ((total - paid) > 0.01 && _bizPaymentCtrl.text.isNotEmpty) {
          sb.writeln("💳 *MÉTODOS DE PAGO* (Para cancelar saldo)");
          sb.writeln(_bizPaymentCtrl.text.trim());
          sb.writeln("");
        } else if ((total - paid) <= 0.01) {
          sb.writeln("💳 *PAGADO MEDIANTE:* ${_saleData!['metodo_pago'].toString().toUpperCase()}");
          sb.writeln("");
        }
      } else if (_bizPaymentCtrl.text.isNotEmpty) {
        sb.writeln("💳 *MEDIOS DE PAGO*");
        sb.writeln(_bizPaymentCtrl.text.trim());
        sb.writeln("");
      }
    }

    if (_config.showBusinessInfo) {
      final authProv = Provider.of<AuthProvider>(context, listen: false);
      final bizName = authProv.businessName;
      
      sb.writeln("🏢 *Visítanos en $bizName*");
      
      if (_config.includeShopAddress && _bizAddressCtrl.text.isNotEmpty) {
         sb.writeln("📍 Dirección: ${_bizAddressCtrl.text}");
      }
      
      if (_config.includeShopAddress && _bizLat != null && _bizLng != null) {
          final String mapLink = "https://www.google.com/maps/search/?api=1&query=$_bizLat,$_bizLng";
          sb.writeln("🗺️ Ver en Mapa: $mapLink");
      }

      if (_config.includeShopRuc && _bizRucCtrl.text.isNotEmpty) {
        sb.writeln("📄 RUC: ${_bizRucCtrl.text}");
      }
      if (_config.includeOwnerPhone && _bizPhoneCtrl.text.isNotEmpty) {
        sb.writeln("📞 Contacto: ${_bizPhoneCtrl.text}");
      }
      
      if (!isSale) {
        sb.writeln("\n¡Quedamos atentos a tu confirmación!");
      }
    }

    _messageCtrl.text = sb.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;


    if (_isLoading) return Scaffold(backgroundColor: bgColor, body: const Center(child: CircularProgressIndicator()));
    final bool isSale = _saleData != null;

    return Scaffold(
      backgroundColor: bgColor, 
      appBar: AppBar(
        title: const Text("Editor WhatsApp", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: isDark ? const Color(0xFF142C23) : const Color(0xFF00A884), 
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt, size: 26),
            tooltip: "Restaurar Mensaje Original",
            onPressed: () {
              setState(() => _isManualEdit = false);
              _regenerateMessage();
              CustomSnackBar.show(context, message: "Mensaje restaurado", isError: false);
            },
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
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
                    onRevertTap: () {
                      setState(() {
                        _isUsingSelectedClient = false;
                        _selectedClient = null;
                        if (_originalClient != null) {
                          _clientNameCtrl.text = _originalClient!.fullName;
                          _clientPhoneCtrl.text = _originalClient!.phone;
                        } else {
                          _clientNameCtrl.text = _saleData?['cliente_nombre'] ?? _quotation?.clientName ?? "";
                          _clientPhoneCtrl.clear();
                        }
                        _regenerateMessage();
                      });
                    },
                    onUpdateDataChanged: (v) => setState(() => _config.updateClientData = v),
                    onDataChanged: _regenerateMessage,
                  ),
                  const SizedBox(height: 20),
                  
                  WaConfigSection(
                    config: _config,
                    isSale: isSale, 
                    onChanged: () => setState(() => _regenerateMessage()),
                  ),
                  const SizedBox(height: 20),
                  
                  WaBusinessSection(
                    phoneCtrl: _bizPhoneCtrl,
                    rucCtrl: _bizRucCtrl,
                    addressCtrl: _bizAddressCtrl,
                    paymentCtrl: _bizPaymentCtrl,
                    isGpsLoading: _isGpsLoading,
                    updateBusinessData: _config.updateBusinessData,
                    onGpsTap: _fillCurrentLocation,
                    onUpdateDataChanged: (v) => setState(() => _config.updateBusinessData = v),
                    onDataChanged: _regenerateMessage,
                  ),
                  const SizedBox(height: 24),
                  
                  WaMessageEditor(
                    isDark: isDark,
                    isManualEdit: _isManualEdit,
                    messageCtrl: _messageCtrl,
                    onChanged: (val) {
                      if (!_isManualEdit) setState(() => _isManualEdit = true);
                    },
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, -10))]),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () => _showFinalPreviewModal(isDark),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A884),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: isDark ? 0 : 4,
                  ),
                  icon: const Icon(Icons.remove_red_eye, size: 24),
                  label: const Text("VISUALIZAR MENSAJE FINAL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClientSelectorModal(bool isDark) {
    ClientSearchModal.show(
      context,
      onClientSelected: (client) {
        setState(() {
          _selectedClient = client;
          _isUsingSelectedClient = true;
          _clientNameCtrl.text = client.fullName;
          _clientPhoneCtrl.text = client.phone;
          _regenerateMessage();
        });
      },
    );
  }

  Future<void> _fillCurrentLocation() async {
    setState(() => _isGpsLoading = true); 
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception("El GPS está desactivado. Actívalo e intenta de nuevo.");

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception("Permiso de ubicación denegado.");
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception("Permiso denegado permanentemente. Habilítalo en configuración.");
      } 

      final Position position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      
      if (mounted) {
        setState(() {
          _bizLat = position.latitude;
          _bizLng = position.longitude;
          _regenerateMessage();
        });
        CustomSnackBar.show(context, message: "Ubicación agregada con éxito", isError: false);
      }
    } catch (e) {
      if (mounted) CustomSnackBar.show(context, message: e.toString().replaceAll("Exception:", "").trim(), isError: true);
    } finally {
      if (mounted) setState(() => _isGpsLoading = false);
    }
  }

  void _showFinalPreviewModal(bool isDark) {
    final rawPhone = _clientPhoneCtrl.text.replaceAll(" ", "");
    if (rawPhone.length != 9) {
      CustomSnackBar.show(context, message: "⚠️ El número debe tener 9 dígitos", isError: true);
      return;
    }
    if (_clientNameCtrl.text.isEmpty) {
      CustomSnackBar.show(context, message: "⚠️ Ingresa el nombre del cliente", isError: true);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WaFinalPreviewModal(
        isDark: isDark,
        phone: _clientPhoneCtrl.text,
        messageCtrl: _messageCtrl,
        onSend: () {
          Navigator.pop(ctx);
          _executeSendProcess(); 
        },
      ),
    );
  }

  Future<void> _executeSendProcess() async {
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final clientService = ClientService();
    bool savingError = false;

    // VALIDACIÓN PREVIA DE SEGURIDAD
    if (authProv.activeBusinessId == null || authProv.activeUserId == null) {
      CustomSnackBar.show(context, message: "Error crítico: Sesión no válida.", isError: true);
      return;
    }

    if (_config.updateBusinessData) {
      try {
        bool showAddress = true;
        bool showRuc = true;
        
        final biz = authProv.currentBusiness;
        if (biz != null && biz.printerConfig != null && biz.printerConfig!.isNotEmpty) {
           try {
              final Map<String, dynamic> prefs = json.decode(biz.printerConfig!);
              showAddress = prefs['show_address'] ?? true;
              showRuc = prefs['show_ruc'] ?? true;
           } catch (_) {}
        }
        
        // 🔥 CORRECCIÓN 2: Argumentos correctos y en orden. Se inyecta el activeBusinessId internamente en updateBusinessProfile.
        await authProv.updateBusinessProfile(authProv.businessName, _bizRucCtrl.text, _bizAddressCtrl.text, _bizPaymentCtrl.text, _bizLat, _bizLng, showAddress, showRuc);
      } catch (e) { savingError = true; }
    }

    if (_config.updateClientData) {
      try {
        final clientData = {'nombre_completo': _clientNameCtrl.text, 'telefono': _clientPhoneCtrl.text.replaceAll(" ", "")};
        if (_isUsingSelectedClient && _selectedClient != null) {
          // 🔥 CORRECCIÓN 3: Solo enviamos el ID del cliente y la data. Ya no el token.
          await clientService.updateClient(_selectedClient!.id, clientData);
        } else if (_originalClient != null && !_isUsingSelectedClient) {
          await clientService.updateClient(_originalClient!.id, clientData);
        } else {
          // 🔥 CORRECCIÓN 4: Inyectamos activeBusinessId y activeUserId 
          await clientService.createClient(clientData, authProv.activeBusinessId!, authProv.activeUserId!);
        }
      } catch (e) { savingError = true; }
    }

    if (savingError) {
      if (mounted) CustomSnackBar.show(context, message: "Datos guardados con advertencias", isError: true);
    } else if ((_config.updateBusinessData || _config.updateClientData) && mounted) {
      CustomSnackBar.show(context, message: "Datos actualizados correctamente", isError: false);
    }

    final phone = _clientPhoneCtrl.text.replaceAll(" ", "");
    final message = Uri.encodeComponent(_messageCtrl.text);
    final url = Uri.parse("https://wa.me/51$phone?text=$message");

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) CustomSnackBar.show(context, message: "No se pudo abrir WhatsApp", isError: true);
      }
    } catch (e) {
      debugPrint("Error launching WA: $e");
    }
  } 
}