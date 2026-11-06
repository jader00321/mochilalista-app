import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
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
    final c = widget.cuota;
    _montoActual = (c['monto'] as num).toDouble();
    _montoOriginal = (c['monto_original'] as num?)?.toDouble() ?? _montoActual;
    _moraMontoActual = (c['mora_monto'] as num?)?.toDouble() ?? 0.0;
    _autoActiva = (c['mora_automatica'] == 1 || c['mora_automatica'] == true);

    _autoFrecuencia = c['mora_frecuencia']?.toString() ?? 'diario';
    _autoIntervaloDias = (c['mora_intervalo_dias'] as num?)?.toInt() ?? 1;

    final existingType = c['mora_tipo']?.toString() ?? 'porcentaje';
    _calcType = (existingType == 'fijo') ? 'fijo' : 'porcentaje';

    final double val = (c['mora_valor'] as num?)?.toDouble() ?? 
        (_calcType == 'porcentaje' 
            ? ((c['mora_porcentaje'] as num?)?.toDouble() ?? 5.0) 
            : _moraMontoActual);

    _valorCtrl = TextEditingController(text: val > 0 ? (val % 1 == 0 ? val.toInt().toString() : val.toStringAsFixed(1)) : "5");
    _totalDirectoCtrl = TextEditingController(text: _montoActual.toStringAsFixed(2));
    _customDaysCtrl = TextEditingController(text: _autoIntervaloDias.toString());

    if (_autoActiva) {
      _activeTab = 'automatico';
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
    if (_calcType == 'total_directo') {
      final double tot = double.tryParse(_totalDirectoCtrl.text) ?? _montoOriginal;
      return tot >= _montoOriginal ? tot : _montoOriginal;
    }
    return _montoOriginal + _computedMoraMonto;
  }

  double get _computedPorcentaje {
    if (_montoOriginal <= 0) return 0.0;
    return (_computedMoraMonto / _montoOriginal) * 100;
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

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1E1E28) : Colors.grey[100]!;
    final textColor = isDark ? Colors.white : Colors.black87;
    final int cuotaNum = widget.cuota['numero_cuota'] ?? 1;

    return InteractiveSheetWrapper(
      title: "Gestor de Morosidad · Cuota #$cuotaNum",
      icon: Icons.timer_outlined,
      iconColor: Colors.amber[700]!,
      backgroundColor: surfaceColor,
      applyEffectiveBottomPadding: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resumen de Base y Monto Actual
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.amber.withValues(alpha: 0.12) : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.amber.withValues(alpha: 0.35) : Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: isDark ? Colors.amber.withValues(alpha: 0.25) : Colors.amber.shade100,
                    child: Icon(Icons.warning_amber_rounded, color: isDark ? Colors.amber[300] : Colors.amber[900], size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Cuota #$cuotaNum · Vence: ${widget.cuota['fecha_vencimiento']?.toString().split('T').first ?? ''}",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Monto Base Original: ${AppCurrency.format(_montoOriginal)}${_moraMontoActual > 0.01 ? '  •  Mora Actual: +${AppCurrency.format(_moraMontoActual)}' : ''}",
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.amber[200] : Colors.amber[900]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Selector de Pestaña: Modo Manual vs Modo Automático
            Container(
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
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _activeTab == 'manual' ? (isDark ? Colors.blueGrey[800] : Colors.white) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _activeTab == 'manual' ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)] : null,
                        ),
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
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _activeTab = 'automatico'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _activeTab == 'automatico' ? (isDark ? Colors.blueGrey[800] : Colors.white) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _activeTab == 'automatico' ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)] : null,
                        ),
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
                ],
              ),
            ),
            const SizedBox(height: 16),

            // CONTENIDO SEGÚN PESTAÑA
            if (_activeTab == 'manual') ...[
              // Selector de Tipo de Cálculo Manual
              Text(
                "FORMA DE CÁLCULO",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text("Porcentaje (%)"),
                    selected: _calcType == 'porcentaje',
                    onSelected: (sel) {
                      if (sel) setState(() => _calcType = 'porcentaje');
                    },
                    selectedColor: Colors.blue.withValues(alpha: 0.25),
                  ),
                  ChoiceChip(
                    label: const Text("Monto Fijo (S/)"),
                    selected: _calcType == 'fijo',
                    onSelected: (sel) {
                      if (sel) setState(() => _calcType = 'fijo');
                    },
                    selectedColor: Colors.blue.withValues(alpha: 0.25),
                  ),
                  ChoiceChip(
                    label: const Text("Total Cuota Directo"),
                    selected: _calcType == 'total_directo',
                    onSelected: (sel) {
                      if (sel) setState(() => _calcType = 'total_directo');
                    },
                    selectedColor: Colors.blue.withValues(alpha: 0.25),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if (_calcType == 'total_directo') ...[
                TextField(
                  controller: _totalDirectoCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
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
            ] else ...[
              // PESTAÑA: AUTOMÁTICO PERIÓDICO
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Activar Acumulación Periódica", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                          const SizedBox(height: 2),
                          Text(
                            "Suma el recargo cada intervalo de tiempo mientras siga vencida.",
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
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
              const SizedBox(height: 14),

              // Unidad del incremento periódico
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
                        if (sel) setState(() => _calcType = 'porcentaje');
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
                        if (sel) setState(() => _calcType = 'fijo');
                      },
                      selectedColor: Colors.orange.withValues(alpha: 0.25),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _valorCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: _calcType == 'porcentaje' ? "Porcentaje por cada periodo (%)" : "Monto fijo por periodo (S/)",
                  suffixText: _calcType == 'porcentaje' ? "%" : "S/",
                  prefixIcon: const Icon(Icons.timer),
                  filled: true,
                  fillColor: cardBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 14),

              // Frecuencia
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
                  style: TextStyle(color: textColor, fontSize: 14),
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
              const SizedBox(height: 12),

              // Origen del conteo
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: _calcularDesdeVencimiento,
                      onChanged: (val) => setState(() => _calcularDesdeVencimiento = val ?? true),
                      activeColor: Colors.orange[700],
                    ),
                    Expanded(
                      child: Text(
                        "Contar desde la fecha de vencimiento original (acumular periodos ya transcurridos)",
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[300] : Colors.grey[800]),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // TARJETA DE PREVIEW DE LA FÓRMULA MATEMÁTICA
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF14141C) : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Monto Base Original:", style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[700])),
                      Text(AppCurrency.format(_montoOriginal), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Incremento por Mora (${_computedPorcentaje.toStringAsFixed(1)}%):", style: TextStyle(fontSize: 12, color: Colors.amber[800])),
                      Text("+ ${AppCurrency.format(_computedMoraMonto)}", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.amber[800])),
                    ],
                  ),
                  Divider(height: 16, thickness: 0.8, color: isDark ? Colors.white24 : Colors.grey[400]),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Nuevo Total de la Cuota:", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
                      Text(AppCurrency.format(_computedTotal), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.green[600])),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // BOTONES DE ACCIÓN
            Row(
              children: [
                if (_moraMontoActual > 0.01) ...[
                  IconButton(
                    onPressed: _isSaving ? null : _handleQuitarMora,
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: "Quitar Morosidad",
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: isDark ? Colors.white24 : Colors.grey[400]!),
                    ),
                    child: Text("Cancelar", style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _handleSave,
                    icon: _isSaving 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(
                      _isSaving ? "Guardando..." : "Guardar y Aplicar",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildFreqChip(String label, String value) {
    final bool isSelected = _autoFrecuencia == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      onSelected: (sel) {
        if (sel) setState(() => _autoFrecuencia = value);
      },
      selectedColor: Colors.orange.withValues(alpha: 0.25),
    );
  }
}
