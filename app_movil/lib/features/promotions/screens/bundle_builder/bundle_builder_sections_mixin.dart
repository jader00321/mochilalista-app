part of '../bundle_builder_screen.dart';

mixin _BundleBuilderSectionsMixin on _BundleBuilderScreenStateBase {
  Widget _buildPromoTypeSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Tipo de Promoción",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final double tileWidth = constraints.maxWidth > 600
                ? 150.0
                : ((constraints.maxWidth - 16) / 3).clamp(80.0, 200.0);

            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _BundleBuilderScreenStateBase._promoTypes.map((t) {
                final isSelected = _tipoPromocion == t['id'];
                final accentColor = t['color'] as Color;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _tipoPromocion = t['id'] as String;
                      _userEditedPrice = false;
                      _applyPromoRules();
                    });
                    _autoSuggestNameAndPrice();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    width: tileWidth,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? accentColor.withValues(alpha: 0.15)
                          : (isDark
                                ? const Color(0xFF23232F)
                                : Colors.grey[50]),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? accentColor
                            : (isDark ? Colors.white12 : Colors.grey.shade300),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: accentColor.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          t['icon'] as IconData,
                          color: isSelected ? accentColor : Colors.grey,
                          size: 26,
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            t['label'] as String,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected
                                  ? accentColor
                                  : (isDark ? Colors.white60 : Colors.black54),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 12),
        Builder(
          builder: (ctx) {
            final current = _BundleBuilderScreenStateBase._promoTypes
                .firstWhere(
                  (t) => t['id'] == _tipoPromocion,
                  orElse: () => _BundleBuilderScreenStateBase._promoTypes.first,
                );
            final accentColor = current['color'] as Color;
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Container(
                key: ValueKey(_tipoPromocion),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: accentColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        current['desc'] as String,
                        style: TextStyle(
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDateLimits(bool isDark) {
    final bool hasLimits = _fechaInicio != null || _fechaFin != null;
    final String dateSummary = !hasLimits
        ? "Permanente"
        : "${_fechaInicio != null ? AppDateFormatter.ddMM.format(_fechaInicio!) : 'Hoy'} → ${_fechaFin != null ? AppDateFormatter.ddMM.format(_fechaFin!) : 'Sin fin'}";

    return MorphingAccordion(
      title: "Vigencia de Campaña",
      icon: Icons.calendar_month_outlined,
      iconColor: Colors.blue,
      initialExpanded: hasLimits || _tipoPromocion == 'flash',
      summaryBadge: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: (hasLimits ? Colors.blue : Colors.grey).withValues(
            alpha: 0.15,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          dateSummary,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: hasLimits
                ? (isDark ? Colors.blue[300] : Colors.blue[700])
                : Colors.grey,
          ),
        ),
      ),
      content: LayoutBuilder(
        builder: (context, constraints) {
          final double fieldWidth = constraints.maxWidth > 460
              ? (constraints.maxWidth - 12) / 2
              : constraints.maxWidth;

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: fieldWidth,
                child: InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _fechaInicio ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) setState(() => _fechaInicio = date);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _fechaInicio != null
                                ? AppDateFormatter.ddMMyyyy.format(
                                    _fechaInicio!,
                                  )
                                : 'Inicio',
                            style: const TextStyle(fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: fieldWidth,
                child: InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _fechaFin ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) setState(() => _fechaFin = date);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.event_busy,
                          size: 16,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _fechaFin != null
                                ? AppDateFormatter.ddMMyyyy.format(_fechaFin!)
                                : 'Fin (Opcional)',
                            style: const TextStyle(fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_fechaFin != null)
                          InkWell(
                            onTap: () => setState(() => _fechaFin = null),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPackageInfoSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                "Información del Paquete",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _isActive
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isActive
                      ? Colors.green.withValues(alpha: 0.5)
                      : Colors.grey,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Activo",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _isActive ? Colors.green : Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                      activeTrackColor: Colors.green.withValues(alpha: 0.5),
                      activeThumbColor: Colors.green,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: "Nombre del Paquete",
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.card_giftcard),
          ),
          validator: (v) => v!.isEmpty ? "Requerido" : null,
          onChanged: (_) => _userEditedName = true,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descController,
          decoration: const InputDecoration(
            labelText: "Descripción corta (Opcional)",
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.notes),
          ),
          maxLines: 2,
          onChanged: (_) => _userEditedDesc = true,
        ),
      ],
    );
  }
}
