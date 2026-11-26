import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';

part 'cuota_morosidad_manual_section.dart';
part 'cuota_morosidad_auto_section.dart';
part 'cuota_morosidad_preview_actions.dart';

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

abstract class _CuotaMorosidadStateBase extends State<CuotaMorosidadModal> {
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

        // Si el usuario desactivó la mora automática desde el banner de Manual / Directo, persistir la desactivación sin corromper la frecuencia
        if (!_autoActiva && (widget.cuota['mora_automatica'] == 1 || widget.cuota['mora_automatica'] == true)) {
          await saleProv.configurarMorosidadAutomatica(
            cuotaId,
            activa: false,
            frecuencia: _autoFrecuencia,
            intervaloDias: _autoIntervaloDias,
            saleId: widget.cuota['venta_id'] as int?,
          );
        }

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
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
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
  );
  Widget _buildModeSelector(bool isDark, Color cardBg, Color textColor);
  Widget _buildShieldBanner(bool isDark, String? dueDateStr);
  Widget _buildManualBody(bool isDark, Color textColor, Color cardBg);
  Widget _buildAutomaticoBody(
    bool isDark,
    Color textColor,
    Color cardBg,
    bool isVencida,
    DateTime? dueDate,
    int daysDiff,
  );
  Widget _buildBottomAction(bool isDark, bool isVencida, Color textColor);
}

class _CuotaMorosidadModalState extends _CuotaMorosidadStateBase
    with
        _CuotaMorosidadManualMixin,
        _CuotaMorosidadAutoMixin,
        _CuotaMorosidadPreviewActionsMixin {}
