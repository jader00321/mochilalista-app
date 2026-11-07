import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';

class CuotaMorosidadModal extends StatefulWidget {
  final Map<String, dynamic> cuota;
  final bool isDark;
  final VoidCallback onSaved;

  const CuotaMorosidadModal({
    super.key,
    required this.cuota,
    required this.isDark,
    required this.onSaved,
  });

  static Future<void> show({
    required BuildContext context,
    required Map<String, dynamic> cuota,
    required bool isDark,
    required VoidCallback onSaved,
  }) {
    return InteractiveSheetWrapper.show(
      context: context,
      builder: (_) => CuotaMorosidadModal(
        cuota: cuota,
        isDark: isDark,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<CuotaMorosidadModal> createState() => _CuotaMorosidadModalState();
}

class _CuotaMorosidadModalState extends State<CuotaMorosidadModal> {
  // 'manual' (monto o porcentaje) vs 'automatico'
  String _activeTab = 'manual';

  // Tipo de cálculo: 'porcentaje', 'fijo', 'total_directo'
  String _calcType = 'porcentaje';

  // Controladores de texto
  late TextEditingController _valorCtrl;
  late TextEditingController _totalDirectoCtrl;
  late TextEditingController _customDaysCtrl;

  // Parámetros automáticos
  bool _autoActiva = false;
  String _autoFrecuencia = 'diario';
  int _autoIntervaloDias = 1;
  bool _calcularDesdeVencimiento = true;

  late double _montoOriginal;
  late double _moraMontoActual;
  late double _montoActual;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _valorCtrl = TextEditingController();
    _totalDirectoCtrl = TextEditingController();
    _customDaysCtrl = TextEditingController();
    _initFromCuota();
  }

  @override
  void didUpdateWidget(covariant CuotaMorosidadModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cuota != widget.cuota) {
      _initFromCuota();
    }
  }

  void _initFromCuota() {
    final c = widget.cuota;
    _montoActual = (c['monto'] as num).toDouble();
    _montoOriginal = (c['monto_original'] as num?)?.toDouble() ?? _montoActual;
    _moraMontoActual = (c['mora_monto'] as num?)?.toDouble() ?? 0.0;
    _autoActiva = (c['mora_automatica'] == 1 || c['mora_automatica'] == true || c['mora_activa'] == 1 || c['mora_activa'] == true);

    _autoFrecuencia = c['mora_frecuencia']?.toString() ?? 'diario';
    _autoIntervaloDias = (c['mora_intervalo_dias'] as num?)?.toInt() ?? 1;

    final existingType = c['mora_tipo']?.toString() ?? 'porcentaje';
    _calcType = (existingType == 'fijo') ? 'fijo' : 'porcentaje';

    final double val = (c['mora_valor'] as num?)?.toDouble() ?? 
        (_calcType == 'porcentaje' 
            ? ((c['mora_porcentaje'] as num?)?.toDouble() ?? 5.0) 
            : _moraMontoActual);

    _valorCtrl.text = val > 0 ? (val % 1 == 0 ? val.toInt().toString() : val.toStringAsFixed(1)) : "5";
    _totalDirectoCtrl.text = _montoActual.toStringAsFixed(2);
    _customDaysCtrl.text = _autoIntervaloDias.toString();

    final String? dueDateStr = c['fecha_vencimiento']?.toString();
    DateTime? dueDate;
    try {
      dueDate = DateTime.tryParse(dueDateStr?.split('T').first ?? '');
    } catch (_) {}
    final now = DateTime.now();
    final todayNorm = DateTime(now.year, now.month, now.day);
    final bool isVencida = dueDate != null && dueDate.isBefore(todayNorm);

    if (!isVencida) {
      _activeTab = 'automatico';
    } else if (_autoActiva) {
      _activeTab = 'automatico';
    } else {
      _activeTab = 'manual';
    }
  }

  @override
  void dispose() {
    _valorCtrl.dispose();
    _totalDirectoCtrl.dispose();
    _customDaysCtrl.dispose();
    super.dispose();
  }

  double get _computedMoraMonto {
    if (_calcType == 'total_directo') {
      final double tot = double.tryParse(_totalDirectoCtrl.text) ?? _montoOriginal;
      final diff = tot - _montoOriginal;
      return diff > 0 ? diff : 0.0;
    }

    final double val = double.tryParse(_valorCtrl.text) ?? 0.0;
    if (_calcType == 'porcentaje') {
      return (_montoOriginal * (val / 100));
    } else {
      return val;
    }
  }

  double get _computedTotal {
    final String? dueDateStr = widget.cuota['fecha_vencimiento']?.toString();
    DateTime? dueDate;
    try {
      dueDate = DateTime.tryParse(dueDateStr?.split('T').first ?? '');
    } catch (_) {}
    final now = DateTime.now();
    final todayNorm = DateTime(now.year, now.month, now.day);
    final bool isVencida = dueDate != null && dueDate.isBefore(todayNorm);

    if (!isVencida) {
      return _montoOriginal;
    }

    if (_calcType == 'total_directo') {
      final double tot = double.tryParse(_totalDirectoCtrl.text) ?? _montoOriginal;
      return tot >= _montoOriginal ? tot : _montoOriginal;
    }
    return _montoOriginal + _computedMoraMonto;
  }

  void _setValor(String val) {
    setState(() {
      _valorCtrl.text = val;
    });
  }

  void _setTotalDirecto(double val) {
    setState(() {
      _totalDirectoCtrl.text = val.toStringAsFixed(2);
    });
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    final saleProv = Provider.of<SaleProvider>(context, listen: false);
    final int cuotaId = widget.cuota['id'] as int;

    try {
      if (_activeTab == 'manual') {
        final double val = double.tryParse(_valorCtrl.text) ?? 0.0;
        final double? tot = _calcType == 'total_directo' ? double.tryParse(_totalDirectoCtrl.text) : null;

        final ok = await saleProv.aplicarMorosidadManual(
          cuotaId,
          tipo: _calcType,
          valor: val,
          nuevoMontoTotal: tot,
          saleId: widget.cuota['venta_id'] as int?,
        );

        if (ok && mounted) {
          CustomSnackBar.show(context, message: "Morosidad manual actualizada con éxito");
          widget.onSaved();
          Navigator.pop(context);
        }
      } else {
        // Modo Automático Periódico
        final double val = double.tryParse(_valorCtrl.text) ?? 0.0;
        int interval = 1;
        if (_autoFrecuencia == 'personalizado') {
          interval = int.tryParse(_customDaysCtrl.text) ?? 1;
          if (interval < 1) interval = 1;
        } else {
          switch (_autoFrecuencia) {
            case 'cada_2_dias': interval = 2; break;
            case 'cada_3_dias': interval = 3; break;
            case 'semanal': interval = 7; break;
            case 'quincenal': interval = 15; break;
            case 'mensual': interval = 30; break;
            case 'diario':
            default: interval = 1; break;
          }
        }

        final ok = await saleProv.configurarMorosidadAutomatica(
          cuotaId,
          activa: _autoActiva,
          frecuencia: _autoFrecuencia,
          intervaloDias: interval,
          tipo: _calcType == 'total_directo' ? 'fijo' : _calcType,
          valor: val,
          calcularDesdeVencimiento: _calcularDesdeVencimiento,
          saleId: widget.cuota['venta_id'] as int?,
        );

        if (ok && mounted) {
          CustomSnackBar.show(
            context, 
            message: _autoActiva 
                ? "Morosidad automática configurada y aplicada." 
                : "Morosidad automática desactivada. Se conservó el recargo acumulado.",
          );
          widget.onSaved();
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(context, message: "Error al guardar morosidad: $e", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleQuitarMora() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("¿Quitar / Condonar Morosidad?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          "Se eliminará el recargo de ${AppCurrency.format(_moraMontoActual)} y la cuota volverá a su monto original de ${AppCurrency.format(_montoOriginal)}.",
          style: TextStyle(color: widget.isDark ? Colors.grey[300] : Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Sí, Condonar"),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isSaving = true);
    final saleProv = Provider.of<SaleProvider>(context, listen: false);
    final int cuotaId = widget.cuota['id'] as int;

    try {
      final ok = await saleProv.quitarMorosidad(cuotaId);
      if (ok && mounted) {
        CustomSnackBar.show(context, message: "Morosidad condonada. Cuota restaurada al monto original.");
        widget.onSaved();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(context, message: "Error condonando morosidad: $e", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _formatFrecuenciaLabel(String freq, int interval) {
    switch (freq) {
      case 'diario': return "1 día";
      case 'cada_2_dias': return "2 días";
      case 'cada_3_dias': return "3 días";
      case 'semanal': return "7 días";
      case 'quincenal': return "15 días";
      case 'mensual': return "30 días";
      case 'personalizado': return "$interval días";
      default: return "$interval días";
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1E1E28) : Colors.grey[100]!;
    final textColor = isDark ? Colors.white : Colors.black87;
    final int cuotaNum = widget.cuota['numero_cuota'] ?? 1;

    final String? dueDateStr = widget.cuota['fecha_vencimiento']?.toString();
    DateTime? dueDate;
    try {
      dueDate = DateTime.tryParse(dueDateStr?.split('T').first ?? '');
    } catch (_) {}
    final now = DateTime.now();
    final todayNorm = DateTime(now.year, now.month, now.day);
    final bool isVencida = dueDate != null && dueDate.isBefore(todayNorm);
    final int daysDiff = dueDate != null ? todayNorm.difference(dueDate).inDays : 0;

    return InteractiveSheetWrapper(
      maxHeightFactor: 0.88,
      title: "Gestor de Morosidad • Cuota #$cuotaNum",
      icon: Icons.timer_outlined,
      iconColor: Colors.amber[700]!,
      backgroundColor: surfaceColor,
      applyEffectiveBottomPadding: true,
      maintainFixedHeightOnKeyboard: false,
      contentPadding: EdgeInsets.zero,
      bottomAction: _buildBottomAction(isDark, isVencida, textColor),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopStatusCard(isDark, textColor, cardBg, isVencida, dueDate, daysDiff),
            const SizedBox(height: 10),
            if (isVencida)
              _buildModeSelector(isDark, cardBg, textColor)
            else
              _buildShieldBanner(isDark, dueDateStr),
            const SizedBox(height: 12),
            if (_activeTab == 'manual')
              _buildManualBody(isDark, textColor, cardBg)
            else
              _buildAutomaticoBody(isDark, textColor, cardBg, isVencida, dueDate, daysDiff),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // --- ZONA A: CABECERA FIJA ---

  Widget _buildTopStatusCard(
    bool isDark,
    Color textColor,
    Color cardBg,
    bool isVencida,
    DateTime? dueDate,
    int daysDiff,
  ) {
    String friendlyDate;
    if (dueDate == null) {
      friendlyDate = "Sin fecha";
    } else if (daysDiff > 0) {
      friendlyDate = "Venció: ${DateFormat('dd/MM/yyyy').format(dueDate)} (hace $daysDiff ${daysDiff == 1 ? 'día' : 'días'})";
    } else if (daysDiff == 0) {
      friendlyDate = "Vence: Hoy (${DateFormat('dd/MM/yyyy').format(dueDate)})";
    } else {
      final int remaining = daysDiff.abs();
      friendlyDate = "Vence: ${DateFormat('dd/MM/yyyy').format(dueDate)} (en $remaining ${remaining == 1 ? 'día' : 'días'})";
    }

    String badgeText;
    Color badgeColor;
    Color badgeBgColor;
    IconData badgeIcon;

    final bool hasActiveMora = _moraMontoActual > 0.01;
    final bool hasScheduledRule = _autoActiva || (widget.cuota['mora_automatica'] == 1 || widget.cuota['mora_automatica'] == true);

    if (!isVencida && hasScheduledRule) {
      badgeText = "🛡️ MORA PROGRAMADA SI VENCE";
      badgeColor = isDark ? Colors.cyanAccent : Colors.teal;
      badgeBgColor = (isDark ? Colors.cyan : Colors.teal).withValues(alpha: 0.15);
      badgeIcon = Icons.shield_outlined;
    } else if (isVencida && hasScheduledRule) {
      final freqLabel = _formatFrecuenciaLabel(_autoFrecuencia, _autoIntervaloDias);
      badgeText = "⚡ MORA PERIÓDICA ACTIVA: +${AppCurrency.format(_moraMontoActual)} cada $freqLabel";
      badgeColor = Colors.orange[400]!;
      badgeBgColor = Colors.orange.withValues(alpha: 0.18);
      badgeIcon = Icons.autorenew;
    } else if (isVencida && hasActiveMora) {
      badgeText = "MORA MANUAL ACTIVA: +${AppCurrency.format(_moraMontoActual)}";
      badgeColor = isDark ? Colors.amber[300]! : Colors.amber[900]!;
      badgeBgColor = Colors.amber.withValues(alpha: 0.18);
      badgeIcon = Icons.timer_outlined;
    } else {
      badgeText = "SIN MORA APLICADA";
      badgeColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
      badgeBgColor = Colors.grey.withValues(alpha: 0.15);
      badgeIcon = Icons.check_circle_outline;
    }

    final bool canQuitar = hasActiveMora || hasScheduledRule;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.amber.withValues(alpha: 0.08) : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.amber.withValues(alpha: 0.3) : Colors.amber.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: isDark ? Colors.amber.withValues(alpha: 0.25) : Colors.amber.shade100,
                child: Icon(
                  isVencida ? Icons.warning_amber_rounded : Icons.shield_outlined,
                  color: isDark ? Colors.amber[300] : Colors.amber[900],
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Cuota #${widget.cuota['numero_cuota'] ?? 1} • $friendlyDate",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Monto Base Original: ${AppCurrency.format(_montoOriginal)}",
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.amber[200] : Colors.amber[900]),
                    ),
                  ],
                ),
              ),
              if (canQuitar)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _isSaving ? null : _handleQuitarMora,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.35), width: 0.8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline, color: Colors.redAccent, size: 14),
                        SizedBox(width: 3),
                        Text(
                          "Quitar Mora",
                          style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeBgColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(badgeIcon, size: 12, color: badgeColor),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector(bool isDark, Color cardBg, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _activeTab = 'manual'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: _activeTab == 'manual' ? (isDark ? Colors.blueGrey[800] : Colors.white) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _activeTab == 'manual' ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)] : null,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.tune, size: 16, color: _activeTab == 'manual' ? (isDark ? Colors.blue[300] : Colors.blue[800]) : Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        "Manual / Directo",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _activeTab == 'manual' ? FontWeight.bold : FontWeight.normal,
                          color: _activeTab == 'manual' ? textColor : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _activeTab = 'automatico'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: _activeTab == 'automatico' ? (isDark ? Colors.blueGrey[800] : Colors.white) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _activeTab == 'automatico' ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)] : null,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.autorenew, size: 16, color: _activeTab == 'automatico' ? (isDark ? Colors.orange[300] : Colors.orange[800]) : Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        "Automático Periódico",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _activeTab == 'automatico' ? FontWeight.bold : FontWeight.normal,
                          color: _activeTab == 'automatico' ? textColor : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShieldBanner(bool isDark, String? dueDateStr) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.blue.withValues(alpha: 0.4) : Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, color: isDark ? Colors.blue[300] : Colors.blue[800], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "🛡️ Cuota en plazo (Vence: ${dueDateStr?.split('T').first ?? ''})",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.blue[200] : Colors.blue[900]),
                ),
                const SizedBox(height: 3),
                Text(
                  "La morosidad no puede cobrarse antes de tiempo. Programa aquí la regla que se activará automáticamente si vence sin pagarse.",
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- ZONA B: CUERPO ESCROLLEABLE (MANUAL VS AUTOMÁTICO) ---

  Widget _buildManualBody(bool isDark, Color textColor, Color cardBg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "FORMA DE CÁLCULO",
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
        const SizedBox(height: 8),

        // Segmentos horizontales en una sola fila
        Row(
          children: [
            Expanded(child: _buildCalcSegment("Porcentaje", "%", 'porcentaje', isDark, textColor)),
            const SizedBox(width: 6),
            Expanded(child: _buildCalcSegment("Monto Fijo", "S/", 'fijo', isDark, textColor)),
            const SizedBox(width: 6),
            Expanded(child: _buildCalcSegment("Nuevo Total", "S/", 'total_directo', isDark, textColor)),
          ],
        ),
        const SizedBox(height: 12),

        // Campo numérico
        if (_calcType == 'total_directo') ...[
          TextField(
            controller: _totalDirectoCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
            scrollPadding: const EdgeInsets.only(bottom: 90),
            style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: "Nuevo Total a Pagar por esta Cuota (S/)",
              helperText: "Base original: ${AppCurrency.format(_montoOriginal)}. La diferencia se registrará como mora.",
              prefixIcon: const Icon(Icons.attach_money),
              filled: true,
              fillColor: cardBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ] else ...[
          TextField(
            controller: _valorCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
            scrollPadding: const EdgeInsets.only(bottom: 90),
            style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: _calcType == 'porcentaje' ? "Porcentaje de Mora (%)" : "Monto de Mora (S/)",
              hintText: _calcType == 'porcentaje' ? "Ej. 5" : "Ej. 15.00",
              suffixText: _calcType == 'porcentaje' ? "%" : "S/",
              prefixIcon: Icon(_calcType == 'porcentaje' ? Icons.percent : Icons.add_circle_outline),
              filled: true,
              fillColor: cardBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ],
        const SizedBox(height: 10),

        // Presets rápidos en 1 toque
        _buildManualPresets(isDark, textColor),
      ],
    );
  }

  Widget _buildCalcSegment(String title, String symbol, String type, bool isDark, Color textColor) {
    final bool isSelected = _calcType == type;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        setState(() {
          _calcType = type;
          if (type == 'total_directo') {
            _totalDirectoCtrl.text = (_montoOriginal + _computedMoraMonto).toStringAsFixed(2);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.blue[800] : Colors.blue.shade700)
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.blue : (isDark ? Colors.white10 : Colors.grey.shade300),
            width: 0.8,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                symbol,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : (isDark ? Colors.blue[300] : Colors.blue[800]),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManualPresets(bool isDark, Color textColor) {
    List<String> labels;
    List<VoidCallback> callbacks;

    if (_calcType == 'porcentaje') {
      labels = ["+5%", "+10%", "+15%", "+20%"];
      callbacks = [
        () => _setValor("5"),
        () => _setValor("10"),
        () => _setValor("15"),
        () => _setValor("20"),
      ];
    } else if (_calcType == 'fijo') {
      labels = ["+S/ 5", "+S/ 10", "+S/ 20", "+S/ 50"];
      callbacks = [
        () => _setValor("5"),
        () => _setValor("10"),
        () => _setValor("20"),
        () => _setValor("50"),
      ];
    } else {
      labels = ["Base + 5", "Base + 10", "Base + 20", "Base + 50"];
      callbacks = [
        () => _setTotalDirecto(_montoOriginal + 5),
        () => _setTotalDirecto(_montoOriginal + 10),
        () => _setTotalDirecto(_montoOriginal + 20),
        () => _setTotalDirecto(_montoOriginal + 50),
      ];
    }

    return Row(
      children: [
        for (int i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: callbacks[i],
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.blue.withValues(alpha: 0.3) : Colors.blue.shade100,
                    width: 0.8,
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.blue[300] : Colors.blue[800],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAutomaticoBody(
    bool isDark,
    Color textColor,
    Color cardBg,
    bool isVencida,
    DateTime? dueDate,
    int daysDiff,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Switch interactivo
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _autoActiva ? Colors.orange.withValues(alpha: 0.4) : Colors.transparent,
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Activar Acumulación Periódica", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: textColor)),
                    const SizedBox(height: 2),
                    Text(
                      "Suma el recargo cada intervalo de tiempo mientras siga vencida.",
                      style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _autoActiva,
                onChanged: (val) => setState(() => _autoActiva = val),
                activeTrackColor: Colors.orange[700],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Controles de configuración con atenuación animada si el switch está apagado
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _autoActiva ? 1.0 : 0.45,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "TIPO DE RECARGO POR PERIODO",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text("Porcentaje (%)")),
                      selected: _calcType == 'porcentaje',
                      onSelected: (sel) {
                        if (sel) {
                          setState(() {
                            _autoActiva = true;
                            _calcType = 'porcentaje';
                          });
                        }
                      },
                      selectedColor: Colors.orange.withValues(alpha: 0.25),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text("Monto Fijo (S/)")),
                      selected: _calcType == 'fijo',
                      onSelected: (sel) {
                        if (sel) {
                          setState(() {
                            _autoActiva = true;
                            _calcType = 'fijo';
                          });
                        }
                      },
                      selectedColor: Colors.orange.withValues(alpha: 0.25),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _valorCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                scrollPadding: const EdgeInsets.only(bottom: 90),
                style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold),
                onChanged: (_) {
                  if (!_autoActiva) {
                    setState(() => _autoActiva = true);
                  } else {
                    setState(() {});
                  }
                },
                decoration: InputDecoration(
                  labelText: _calcType == 'porcentaje' ? "Porcentaje por periodo (%)" : "Monto fijo por periodo (S/)",
                  suffixText: _calcType == 'porcentaje' ? "%" : "S/",
                  prefixIcon: const Icon(Icons.timer),
                  filled: true,
                  fillColor: cardBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 8),

              // Presets rápidos para automático
              _buildAutoPresets(isDark, textColor),
              const SizedBox(height: 12),

              Text(
                "FRECUENCIA DE ACUMULACIÓN",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildFreqChip("Diario (1 día)", "diario"),
                  _buildFreqChip("Cada 2 días", "cada_2_dias"),
                  _buildFreqChip("Cada 3 días", "cada_3_dias"),
                  _buildFreqChip("Semanal (7 días)", "semanal"),
                  _buildFreqChip("Quincenal (15 días)", "quincenal"),
                  _buildFreqChip("Mensual (30 días)", "mensual"),
                  _buildFreqChip("Personalizado", "personalizado"),
                ],
              ),

              if (_autoFrecuencia == 'personalizado') ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _customDaysCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  scrollPadding: const EdgeInsets.only(bottom: 90),
                  style: TextStyle(color: textColor, fontSize: 14),
                  onChanged: (_) {
                    if (!_autoActiva) {
                      setState(() => _autoActiva = true);
                    } else {
                      setState(() {});
                    }
                  },
                  decoration: InputDecoration(
                    labelText: "Cada cuántos días",
                    hintText: "Ej. 4",
                    prefixIcon: const Icon(Icons.calendar_month),
                    filled: true,
                    fillColor: cardBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ],
              const SizedBox(height: 10),

              // Checkbox conteo desde vencimiento
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: _calcularDesdeVencimiento,
                      onChanged: (val) {
                        setState(() {
                          _autoActiva = true;
                          _calcularDesdeVencimiento = val ?? true;
                        });
                      },
                      activeColor: Colors.orange[700],
                    ),
                    Expanded(
                      child: Text(
                        "Contar desde la fecha de vencimiento original (acumular periodos ya transcurridos)",
                        style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey[300] : Colors.grey[800]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Tarjeta de Simulación en Vivo y Explicación Pedagógica
        _buildSimulatorCard(isDark, textColor, isVencida, dueDate, daysDiff),
      ],
    );
  }

  Widget _buildAutoPresets(bool isDark, Color textColor) {
    final List<String> labels = _calcType == 'porcentaje'
        ? ["+2%", "+5%", "+10%", "+15%"]
        : ["+S/ 2", "+S/ 5", "+S/ 10", "+S/ 20"];
    final List<String> values = _calcType == 'porcentaje'
        ? ["2", "5", "10", "15"]
        : ["2", "5", "10", "20"];

    return Row(
      children: [
        for (int i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                setState(() {
                  _autoActiva = true;
                  _valorCtrl.text = values[i];
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.orange.withValues(alpha: 0.3) : Colors.orange.shade100,
                    width: 0.8,
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.orange[300] : Colors.orange[800],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFreqChip(String label, String value) {
    final bool isSelected = _autoFrecuencia == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      onSelected: (sel) {
        if (sel) {
          setState(() {
            _autoActiva = true;
            _autoFrecuencia = value;
          });
        }
      },
      selectedColor: Colors.orange.withValues(alpha: 0.25),
    );
  }

  Widget _buildSimulatorCard(bool isDark, Color textColor, bool isVencida, DateTime? dueDate, int daysDiff) {
    int interval = 1;
    if (_autoFrecuencia == 'personalizado') {
      interval = int.tryParse(_customDaysCtrl.text) ?? 1;
      if (interval < 1) interval = 1;
    } else {
      switch (_autoFrecuencia) {
        case 'cada_2_dias': interval = 2; break;
        case 'cada_3_dias': interval = 3; break;
        case 'semanal': interval = 7; break;
        case 'quincenal': interval = 15; break;
        case 'mensual': interval = 30; break;
        case 'diario':
        default: interval = 1; break;
      }
    }

    final double val = double.tryParse(_valorCtrl.text) ?? 0.0;
    final double recargoPorPeriodo = _calcType == 'porcentaje'
        ? (_montoOriginal * (val / 100))
        : val;

    String simTitle;
    String simMessage;
    IconData simIcon;
    Color simColor;

    if (!isVencida) {
      simTitle = "Proyección: Regla Programada";
      simColor = isDark ? Colors.cyanAccent : Colors.teal;
      simIcon = Icons.shield_outlined;
      final dateFmt = dueDate != null ? DateFormat('dd/MM/yyyy').format(dueDate) : "su vencimiento";
      simMessage = "🛡️ Cuota en plazo. La regla no generará ningún cobro ahora; se dejará configurada la regla periódica de +${AppCurrency.format(recargoPorPeriodo)} cada ${_formatFrecuenciaLabel(_autoFrecuencia, interval)}, la cual comenzará a correr a partir del $dateFmt si no se paga a tiempo.";
    } else if (!_autoActiva) {
      simTitle = "Acumulación Periódica Desactivada";
      simColor = Colors.grey;
      simIcon = Icons.pause_circle_outline;
      simMessage = "Interruptor desactivado: no se sumarán nuevos recargos periódicos. La mora actual (+${AppCurrency.format(_moraMontoActual)}) se conserva intacta.";
    } else {
      final int daysOverdue = daysDiff > 0 ? daysDiff : 0;
      simColor = isDark ? Colors.orange[300]! : Colors.orange[800]!;
      simIcon = Icons.bolt;

      if (_calcularDesdeVencimiento) {
        final int periods = daysOverdue ~/ interval;
        final int remainder = daysOverdue % interval;
        final int daysToNext = interval - remainder;
        final double moraAcumulada = periods * recargoPorPeriodo;
        final double totalProyectado = _montoOriginal + moraAcumulada;

        simTitle = "Simulación en Vivo ($periods ${periods == 1 ? 'periodo devengado' : 'periodos devengados'})";
        if (periods == 0) {
          final nextStr = daysToNext == 1 
              ? "se aplicará mañana (en 1 día) al cumplir $interval días de atraso." 
              : "se sumará en $daysToNext días al completar el ciclo de $interval días.";
          simMessage = "ℹ️ La cuota venció hace $daysOverdue ${daysOverdue == 1 ? 'día' : 'días'}. Con frecuencia cada ${_formatFrecuenciaLabel(_autoFrecuencia, interval)}, hoy devenga 0 periodos (+S/ 0.00). El 1.er recargo (+${AppCurrency.format(recargoPorPeriodo)}) $nextStr";
        } else {
          simMessage = "⚡ La cuota venció hace $daysOverdue ${daysOverdue == 1 ? 'día' : 'días'}. Al guardar se aplicarán $periods ${periods == 1 ? 'periodo acumulado' : 'periodos acumulados'} (+${AppCurrency.format(moraAcumulada)} ➔ Total cuota: ${AppCurrency.format(totalProyectado)}), y sumará +${AppCurrency.format(recargoPorPeriodo)} cada nuevo ciclo de $interval días (próximo en $daysToNext ${daysToNext == 1 ? 'día' : 'días'}).";
        }
      } else {
        simTitle = "Simulación: Conteo desde Hoy";
        simMessage = "El recargo periódico comenzará a acumularse a partir de hoy. El primer incremento (+${AppCurrency.format(recargoPorPeriodo)}) se sumará en $interval ${interval == 1 ? 'día' : 'días'}.";
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: simColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: simColor.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(simIcon, size: 16, color: simColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  simTitle,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: simColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            simMessage,
            style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[300] : Colors.grey[800], height: 1.35),
          ),
        ],
      ),
    );
  }

  // --- ZONA C: PIE DE PÁGINA FIJO (PINNED FOOTER EN bottomAction) ---

  Widget _buildBottomAction(bool isDark, bool isVencida, Color textColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPreviewCard(isDark, isVencida, textColor),
        const SizedBox(height: 10),
        _buildActionButtons(isDark, isVencida),
      ],
    );
  }

  Widget _buildPreviewCard(bool isDark, bool isVencida, Color textColor) {
    final double previewBase = _montoOriginal;
    double previewMora = 0.0;
    double previewTotal = _montoOriginal;

    if (!isVencida) {
      previewMora = _computedMoraMonto;
      previewTotal = _montoOriginal;
    } else {
      if (_activeTab == 'manual') {
        previewMora = _computedMoraMonto;
        previewTotal = _computedTotal;
      } else {
        if (_autoActiva) {
          if (_calcularDesdeVencimiento) {
            int interval = 1;
            if (_autoFrecuencia == 'personalizado') {
              interval = int.tryParse(_customDaysCtrl.text) ?? 1;
              if (interval < 1) interval = 1;
            } else {
              switch (_autoFrecuencia) {
                case 'cada_2_dias': interval = 2; break;
                case 'cada_3_dias': interval = 3; break;
                case 'semanal': interval = 7; break;
                case 'quincenal': interval = 15; break;
                case 'mensual': interval = 30; break;
                case 'diario':
                default: interval = 1; break;
              }
            }
            final String? dueDateStr = widget.cuota['fecha_vencimiento']?.toString();
            DateTime? dueDate;
            try {
              dueDate = DateTime.tryParse(dueDateStr?.split('T').first ?? '');
            } catch (_) {}
            final todayNorm = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
            final int daysDiff = dueDate != null ? todayNorm.difference(dueDate).inDays : 0;
            final int daysOverdue = daysDiff > 0 ? daysDiff : 0;
            final int periods = daysOverdue ~/ interval;
            final double val = double.tryParse(_valorCtrl.text) ?? 0.0;
            final double recargoPorPeriodo = _calcType == 'porcentaje'
                ? (_montoOriginal * (val / 100))
                : val;
            previewMora = periods * recargoPorPeriodo;
            previewTotal = _montoOriginal + previewMora;
          } else {
            previewMora = 0.0;
            previewTotal = _montoOriginal;
          }
        } else {
          previewMora = _moraMontoActual;
          previewTotal = _montoOriginal + _moraMontoActual;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14141C) : Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Monto Base: ", style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[700])),
                      Text(AppCurrency.format(previewBase), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textColor)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Mora: ", style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[700])),
                      Text(
                        previewMora > 0.01 ? "+ ${AppCurrency.format(previewMora)}" : "S/ 0.00",
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: previewMora > 0.01 ? Colors.amber[800] : textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Divider(height: 1, thickness: 0.8),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  !isVencida ? "Total Exigible Hoy (En Plazo):" : "Nuevo Total de la Cuota:",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                AppCurrency.format(previewTotal),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: !isVencida ? Colors.blue[400] : Colors.green[400],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isDark, bool isVencida) {
    final bool hasActiveMora = _moraMontoActual > 0.01 || _autoActiva;
    return Row(
      children: [
        if (hasActiveMora) ...[
          IconButton(
            onPressed: _isSaving ? null : _handleQuitarMora,
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: "Quitar / Condonar Mora",
          ),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: BorderSide(color: isDark ? Colors.white24 : Colors.grey[400]!),
            ),
            child: Text(
              "Cancelar",
              style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _handleSave,
            icon: _isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.check_circle_outline, size: 18),
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _isSaving
                    ? "Guardando..."
                    : (!isVencida ? "Guardar Regla Programada" : "Guardar y Aplicar"),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}
