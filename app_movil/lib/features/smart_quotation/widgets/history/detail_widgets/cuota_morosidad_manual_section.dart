part of 'cuota_morosidad_modal.dart';

mixin _CuotaMorosidadManualMixin on _CuotaMorosidadStateBase {
  @override
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

    final double valPorPeriodo = (widget.cuota['mora_valor'] as num?)?.toDouble() ?? 0.0;
    final String tipoRecargo = widget.cuota['mora_tipo']?.toString() ?? 'porcentaje';
    final double feePerCycle = tipoRecargo == 'porcentaje' ? (_montoOriginal * (valPorPeriodo / 100)) : valPorPeriodo;
    final double feeDisplay = feePerCycle > 0 
        ? feePerCycle 
        : (_calcType == 'porcentaje' ? (_montoOriginal * ((double.tryParse(_valorCtrl.text) ?? 5) / 100)) : (double.tryParse(_valorCtrl.text) ?? 0));

    if (!isVencida && hasScheduledRule) {
      badgeText = "MORA PROGRAMADA SI VENCE";
      badgeColor = isDark ? Colors.cyanAccent : Colors.teal;
      badgeBgColor = (isDark ? Colors.cyan : Colors.teal).withValues(alpha: 0.15);
      badgeIcon = Icons.shield_outlined;
    } else if (isVencida && hasScheduledRule) {
      final freqLabel = _formatFrecuenciaLabel(_autoFrecuencia, _autoIntervaloDias);
      final double displayMora = _moraMontoActual > 0.01 ? _moraMontoActual : feeDisplay;
      badgeText = "MORA PERIÓDICA ACTIVA: +${AppCurrency.format(displayMora)} cada $freqLabel";
      badgeColor = Colors.orange[400]!;
      badgeBgColor = Colors.orange.withValues(alpha: 0.18);
      badgeIcon = Icons.update_rounded;
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
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
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

  @override
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
                  "Cuota en plazo (Vence: ${dueDateStr?.split('T').first ?? ''})",
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

  @override
  Widget _buildManualBody(bool isDark, Color textColor, Color cardBg) {
    final double valPorPeriodo = (widget.cuota['mora_valor'] as num?)?.toDouble() ?? 0.0;
    final String tipoRecargo = widget.cuota['mora_tipo']?.toString() ?? 'porcentaje';
    final double feePerCycle = tipoRecargo == 'porcentaje' ? (_montoOriginal * (valPorPeriodo / 100)) : valPorPeriodo;
    final double feeDisplay = feePerCycle > 0 
        ? feePerCycle 
        : (_calcType == 'porcentaje' ? (_montoOriginal * ((double.tryParse(_valorCtrl.text) ?? 5) / 100)) : (double.tryParse(_valorCtrl.text) ?? 0));
    final String freqLabel = _formatFrecuenciaLabel(_autoFrecuencia, _autoIntervaloDias);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_autoActiva) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.orange.withValues(alpha: 0.15) : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? Colors.orange.withValues(alpha: 0.4) : Colors.orange.shade200, width: 0.8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: isDark ? Colors.orange[300] : Colors.orange[800]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "La acumulación periódica (+${AppCurrency.format(feeDisplay)} cada $freqLabel) sigue activa",
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.orange[200] : Colors.orange[900],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () {
                    setState(() {
                      _autoActiva = false;
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.35), width: 0.8),
                    ),
                    child: const Text(
                      "Desactivar",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
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
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
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
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
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

}
