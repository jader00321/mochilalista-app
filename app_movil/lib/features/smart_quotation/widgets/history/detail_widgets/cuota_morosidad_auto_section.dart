part of 'cuota_morosidad_modal.dart';

mixin _CuotaMorosidadAutoMixin on _CuotaMorosidadStateBase {
  @override
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

  Widget _buildSimRow({
    required IconData icon,
    required String text,
    required bool isDark,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[300] : Colors.grey[800],
              height: 1.3,
            ),
          ),
        ),
      ],
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
    IconData simIcon;
    Color simColor;

    if (!isVencida) {
      simTitle = "Proyección: Regla Programada";
      simColor = isDark ? Colors.cyanAccent : Colors.teal;
      simIcon = Icons.shield_outlined;
      final dateFmt = dueDate != null ? DateFormat('dd/MM/yyyy').format(dueDate) : "su vencimiento";
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
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildSimRow(
              icon: Icons.info_outline_rounded,
              text: "Cuota en plazo. La regla no generará ningún cobro ahora; se dejará configurada la regla periódica de +${AppCurrency.format(recargoPorPeriodo)} cada ${_formatFrecuenciaLabel(_autoFrecuencia, interval)}, la cual comenzará a correr a partir del $dateFmt si no se paga a tiempo.",
              isDark: isDark,
              color: simColor,
            ),
          ],
        ),
      );
    } else if (!_autoActiva) {
      simTitle = "Acumulación Periódica Desactivada";
      simColor = Colors.grey;
      simIcon = Icons.pause_circle_outline;
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
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildSimRow(
              icon: Icons.info_outline_rounded,
              text: "Interruptor desactivado: no se sumarán nuevos recargos periódicos. La mora actual (+${AppCurrency.format(_moraMontoActual)}) se conserva intacta.",
              isDark: isDark,
              color: simColor,
            ),
          ],
        ),
      );
    } else {
      final int daysOverdue = daysDiff > 0 ? daysDiff : 0;
      simColor = isDark ? Colors.orange[300]! : Colors.orange[800]!;

      if (_calcularDesdeVencimiento) {
        final int periods = daysOverdue ~/ interval;
        final int remainder = daysOverdue % interval;
        final int daysToNext = interval - remainder;
        final double moraAcumulada = periods * recargoPorPeriodo;

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
                  Icon(Icons.insights_rounded, size: 16, color: simColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Simulación en Vivo ($periods ${periods == 1 ? 'ciclo cumplido' : 'ciclos cumplidos'})",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: simColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Fila 1: Atraso y Periodos
              _buildSimRow(
                icon: Icons.event_busy_rounded,
                text: "$daysOverdue ${daysOverdue == 1 ? 'día' : 'días'} de atraso • $periods ${periods == 1 ? 'ciclo cumplido' : 'ciclos cumplidos'} (cada ${_formatFrecuenciaLabel(_autoFrecuencia, interval)})",
                isDark: isDark,
                color: simColor,
              ),
              const SizedBox(height: 6),
              // Fila 2: Cálculo Actual
              _buildSimRow(
                icon: Icons.calculate_outlined,
                text: periods > 0
                    ? "$periods ciclos × ${AppCurrency.format(recargoPorPeriodo)} = +${AppCurrency.format(moraAcumulada)} de mora hoy"
                    : "0 ciclos cumplidos = +${AppCurrency.format(0.0)} de mora hoy",
                isDark: isDark,
                color: simColor,
              ),
              const SizedBox(height: 6),
              // Fila 3: Próximo Recargo
              _buildSimRow(
                icon: Icons.schedule_rounded,
                text: "Siguiente recargo (+${AppCurrency.format(recargoPorPeriodo)}): en $daysToNext ${daysToNext == 1 ? 'día' : 'días'}",
                isDark: isDark,
                color: isDark ? Colors.grey[300]! : Colors.grey[800]!,
              ),
            ],
          ),
        );
      } else {
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
                  Icon(Icons.schedule_rounded, size: 16, color: simColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Simulación: Conteo desde Hoy",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: simColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildSimRow(
                icon: Icons.info_outline_rounded,
                text: "El recargo periódico comenzará a acumularse a partir de hoy. El primer incremento (+${AppCurrency.format(recargoPorPeriodo)}) se sumará en $interval ${interval == 1 ? 'día' : 'días'}.",
                isDark: isDark,
                color: simColor,
              ),
            ],
          ),
        );
      }
    }
  }

  // --- ZONA C: PIE DE PÁGINA FIJO (PINNED FOOTER EN bottomAction) ---

}
