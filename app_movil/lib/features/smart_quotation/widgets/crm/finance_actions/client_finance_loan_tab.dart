part of '../client_finance_actions_modal.dart';

mixin _ClientFinanceLoanTabMixin on _ClientFinanceActionsStateBase {
  // =========================================================================
  // TAB 2: PRÉSTAMO / FIADO CON MOTOR DE CRONOGRAMA EN CASCADA
  // =========================================================================

  @override
  Widget _buildLoanTab(Color textColor, double enteredAmount) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 48),
      children: [
        Text("Monto del Préstamo",
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600])),
        const SizedBox(height: 8),
        _buildInputLarge(
            ctrl: _amountCtrl,
            isDark: widget.isDark,
            textColor: textColor,
            isInt: false),

        const SizedBox(height: 20),

        Text("Método de entrega",
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600])),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildMethodChip("Efectivo", Icons.money, false),
            _buildMethodChip("Yape", Icons.qr_code_2, false),
            _buildMethodChip("Plin", Icons.qr_code, false),
            _buildMethodChip("Transferencia", Icons.account_balance, false),
          ],
        ),

        const SizedBox(height: 20),

        // Fecha de Emisión / Entrega del Préstamo (desbloqueada desde 2015)
        Text("Fecha de Emisión / Entrega",
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600])),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.isDark
                ? const Color(0xFF14141C)
                : Colors.grey[50],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: widget.isDark
                    ? Colors.white10
                    : Colors.grey.shade300),
          ),
          child: InkWell(
            onTap: () => _selectLoanEmissionDate(context),
            child: Row(
              children: [
                Icon(Icons.calendar_month_outlined,
                    color: widget.isDark
                        ? Colors.orange[300]
                        : Colors.orange[700],
                    size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Fecha de Entrega del Dinero",
                        style: TextStyle(
                            fontSize: 12,
                            color: widget.isDark
                                ? Colors.grey[400]
                                : Colors.grey[600]),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDateSpanish(_loanEmissionDate),
                        style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.edit_calendar,
                    color: widget.isDark
                        ? Colors.orange[300]
                        : Colors.orange[700],
                    size: 20),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Motivo / Detalle (Wrap responsivo sin desbordes horizontales)
        Text("Motivo / Detalle",
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600])),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: _motivosSug.map((motivo) {
              final isSelected = _noteCtrl.text == motivo;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(motivo),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) {
                      _noteCtrl.text = motivo;
                    } else {
                      _noteCtrl.clear();
                    }
                    FocusScope.of(context).unfocus();
                    _saveCurrentDraft();
                    setState(() {});
                  },
                  selectedColor: Colors.orange.withValues(alpha: 0.25),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? Colors.orange
                        : (widget.isDark ? Colors.grey[300] : Colors.grey[800]),
                  ),
                  backgroundColor:
                      widget.isDark ? Colors.white10 : Colors.grey[100],
                  side: BorderSide(
                    color: isSelected
                        ? Colors.orange
                        : (widget.isDark
                            ? Colors.white10
                            : Colors.grey.shade300),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 12),

        TextField(
          controller: _noteCtrl,
          maxLines: 2,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          style: TextStyle(color: textColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: "Ej. Préstamo personal, Fiado mercadería...",
            hintStyle: TextStyle(
                color: widget.isDark ? Colors.grey[500] : Colors.grey),
            filled: true,
            fillColor:
                widget.isDark ? const Color(0xFF14141C) : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color:
                      widget.isDark ? Colors.white10 : Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color:
                      widget.isDark ? Colors.white10 : Colors.grey.shade300),
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),

        const SizedBox(height: 22),

        // Fecha de vencimiento para 1 cuota y estado histórico inicial
        if (!_splitInQuotas) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: widget.isDark
                  ? const Color(0xFF14141C)
                  : Colors.grey[50],
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: widget.isDark
                      ? Colors.white10
                      : Colors.grey.shade300),
            ),
            child: InkWell(
              onTap: () => _selectDueDate(context),
              child: Row(
                children: [
                  Icon(Icons.event_available,
                      color: widget.isDark
                          ? Colors.orange[300]
                          : Colors.orange[700],
                      size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Fecha de Vencimiento (1 cuota)",
                          style: TextStyle(
                              fontSize: 12,
                              color: widget.isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600]),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDateSpanish(_dueDate),
                          style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.edit_calendar,
                      color: widget.isDark
                          ? Colors.orange[300]
                          : Colors.orange[700],
                      size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildOneQuotaStatusCard(textColor, enteredAmount),
        ],

        const SizedBox(height: 14),

        // Switch Fraccionamiento
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            "¿Dividir en cuotas o aplicar interés?",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: textColor),
          ),
          subtitle: Text(
            _splitInQuotas
                ? "Fraccionado en cuotas periódicas"
                : "Cuota única al vencimiento",
            style: TextStyle(
                fontSize: 12,
                color:
                    widget.isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          value: _splitInQuotas,
          activeThumbColor: Colors.orange,
          onChanged: (val) {
            setState(() {
              _splitInQuotas = val;
              if (val) {
                _recalculateMultipleInstallments();
              } else {
                _installments.clear();
              }
              _saveCurrentDraft();
            });
          },
        ),

        // Sección de parámetros de cuotas múltiples
        if (_splitInQuotas) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildInput(
                  label: "N° Cuotas",
                  ctrl: _numCuotasCtrl,
                  isDark: widget.isDark,
                  textColor: textColor,
                  isInt: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _buildInput(
                  label: "Interés",
                  suffix: "%",
                  ctrl: _interestCtrl,
                  isDark: widget.isDark,
                  textColor: textColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: DropdownButtonFormField<String>(
                  initialValue: _frecuencia,
                  isExpanded: true,
                  dropdownColor: widget.isDark
                      ? const Color(0xFF23232F)
                      : Colors.white,
                  style: TextStyle(
                      color: textColor,
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: "Frecuencia",
                    labelStyle: TextStyle(
                        color: widget.isDark
                            ? Colors.grey[400]
                            : Colors.grey[600],
                        fontSize: 13),
                    filled: true,
                    fillColor: widget.isDark
                        ? const Color(0xFF14141C)
                        : Colors.grey[100],
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 12),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: "diario",
                      child: Text("Diario", overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: "semanal",
                      child: Text("Semanal", overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: "quincenal",
                      child: Text("Quincenal", overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: "mensual",
                      child: Text("Mensual", overflow: TextOverflow.ellipsis),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _frecuencia = v;
                        final names = {
                          'diario': 'Diario',
                          'semanal': 'Semanal',
                          'quincenal': 'Quincenal',
                          'mensual': 'Mensual',
                        };
                        _recalculateMultipleInstallments(
                          customFeedback:
                              "Cronograma recalculado • Frecuencia ${names[v] ?? v}",
                        );
                      });
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Selector de Fecha de Inicio de Cobro
          InkWell(
            onTap: () => _selectStartDate(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: widget.isDark
                    ? const Color(0xFF14141C)
                    : Colors.orange.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded,
                      size: 18,
                      color: widget.isDark
                          ? Colors.orange[300]
                          : Colors.orange[700]),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      "Fecha Base / Inicio:",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: widget.isDark
                            ? Colors.grey[300]
                            : Colors.grey[700],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          _formatDateSpanish(_startDate),
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: widget.isDark
                                ? Colors.orange[300]
                                : Colors.orange[800],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.edit_calendar,
                      size: 16,
                      color: widget.isDark
                          ? Colors.orange[300]
                          : Colors.orange[700]),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Selector de Días de Cobro Activos / Excluidos [L] [M] [M] [J] [V] [S] [D]
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Días de Cobro Permitidos",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: widget.isDark
                      ? Colors.grey[300]
                      : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _getFrequencyContextSubtitle(),
                style: TextStyle(
                  fontSize: 11.5,
                  color: widget.isDark
                      ? Colors.grey[400]
                      : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),

              // Fila interactiva de los 7 días
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildWeekdayButton(1, "L", "Lunes"),
                  _buildWeekdayButton(2, "M", "Martes"),
                  _buildWeekdayButton(3, "M", "Miércoles"),
                  _buildWeekdayButton(4, "J", "Jueves"),
                  _buildWeekdayButton(5, "V", "Viernes"),
                  _buildWeekdayButton(6, "S", "Sábado"),
                  _buildWeekdayButton(7, "D", "Domingo"),
                ],
              ),

              const SizedBox(height: 10),

              // Chips de acceso rápido para presets con comportamiento Toggle
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildPresetChip(
                    label: "Omitir Domingos",
                    icon: Icons.event_busy_rounded,
                    isSelected: _excludedWeekdays.length == 1 &&
                        _excludedWeekdays.contains(DateTime.sunday),
                    onTap: () {
                      final isCurrentlySelected = _excludedWeekdays.length == 1 &&
                          _excludedWeekdays.contains(DateTime.sunday);
                      setState(() {
                        if (isCurrentlySelected) {
                          // Desmarcar chip -> Restaurar todos los días
                          _excludedWeekdays.clear();
                          _recalculateMultipleInstallments(
                            customFeedback:
                                "Fechas restauradas • Cobro todos los días habilitado",
                          );
                        } else {
                          // Activar Omitir Domingos
                          _excludedWeekdays = {DateTime.sunday};
                          _recalculateMultipleInstallments();
                        }
                      });
                    },
                  ),
                  _buildPresetChip(
                    label: "Solo Lun - Vie",
                    icon: Icons.business_center_outlined,
                    isSelected: _excludedWeekdays.length == 2 &&
                        _excludedWeekdays.contains(DateTime.saturday) &&
                        _excludedWeekdays.contains(DateTime.sunday),
                    onTap: () {
                      final isCurrentlySelected = _excludedWeekdays.length == 2 &&
                          _excludedWeekdays.contains(DateTime.saturday) &&
                          _excludedWeekdays.contains(DateTime.sunday);
                      setState(() {
                        if (isCurrentlySelected) {
                          // Desmarcar chip -> Restaurar todos los días
                          _excludedWeekdays.clear();
                          _recalculateMultipleInstallments(
                            customFeedback:
                                "Fechas restauradas • Cobro todos los días habilitado",
                          );
                        } else {
                          // Activar Solo Lun - Vie
                          _excludedWeekdays = {
                            DateTime.saturday,
                            DateTime.sunday,
                          };
                          _recalculateMultipleInstallments(
                            customFeedback:
                                "Fechas actualizadas • Solo cobros de Lunes a Viernes",
                          );
                        }
                      });
                    },
                  ),
                  _buildPresetChip(
                    label: "Todos los días",
                    icon: Icons.calendar_month_outlined,
                    isSelected: _excludedWeekdays.isEmpty,
                    onTap: () {
                      setState(() {
                        _excludedWeekdays.clear();
                        _recalculateMultipleInstallments(
                          customFeedback:
                              "Fechas restauradas • Cobro todos los días habilitado",
                        );
                      });
                    },
                  ),
                ],
              ),
            ],
          ),

          // Lista de cuotas generadas con soporte para edición y salto de fecha
          if (_installments.isNotEmpty) ...[
            const SizedBox(height: 18),
            ..._buildGeneratedSchedulePreview(textColor),
          ],
        ],
      ],
    );
  }
}
