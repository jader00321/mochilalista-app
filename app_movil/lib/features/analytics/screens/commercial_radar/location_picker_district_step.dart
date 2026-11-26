part of 'location_picker_sheet.dart';

mixin _LocationPickerDistrictStepMixin on _LocationPickerSheetStateBase {
  Widget _buildDistrictPrecisionView(
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    final deptName = _stagedDept!.name;
    final provName = _stagedProv!.name;
    final corridor = _stagedDept!.mainCorridor;
    final suggested = PeruUbigeoCatalog.getSuggestedDistricts(
      deptName,
      provName,
    );

    return InteractiveSheetWrapper(
      backgroundColor: widget.sheetBg,
      maxHeightFactor: 0.90,
      applyEffectiveBottomPadding: true,
      showHandle: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(
            bottom: InteractiveSheetWrapper.kModalScrollBottomClearance,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabecera con retorno
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    color: primaryTextColor,
                    onPressed: () {
                      setState(() {
                        _stagedProv = null;
                        _stagedDept = null;
                        _districtController.clear();
                      });
                    },
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "$provName, $deptName",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: primaryTextColor,
                            ),
                          ),
                        ),
                        Text(
                          "Paso 3 de 3 • Precisa distrito o caserío (opcional)",
                          style: TextStyle(
                            fontSize: 11.5,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Chips de distritos sugeridos
              if (suggested.isNotEmpty) ...[
                Text(
                  "Distritos / Sectores sugeridos:",
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.4,
                    color: secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: suggested.map((dist) {
                    final isChosen =
                        _districtController.text.trim().toLowerCase() ==
                        dist.toLowerCase();
                    return ActionChip(
                      avatar: Icon(
                        Icons.pin_drop,
                        size: 14,
                        color: isChosen ? Colors.white : Colors.blueAccent,
                      ),
                      label: Text(dist),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isChosen
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isChosen ? Colors.white : primaryTextColor,
                      ),
                      backgroundColor: isChosen
                          ? Colors.blueAccent
                          : (isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      onPressed: () {
                        setState(() {
                          _districtController.text = dist;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
              ],

              // Campo de texto libre opcional
              Text(
                "O ingresa cualquier localidad o caserío:",
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4,
                  color: secondaryTextColor,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _districtController,
                onChanged: (_) => setState(() {}),
                style: TextStyle(fontSize: 13.5, color: primaryTextColor),
                decoration: InputDecoration(
                  hintText: suggested.isNotEmpty
                      ? "Ej. ${suggested.first}, o tu caserío..."
                      : "Ej. Distrito, caserío o centro poblado...",
                  hintStyle: TextStyle(
                    fontSize: 12.5,
                    color: secondaryTextColor,
                  ),
                  prefixIcon: const Icon(
                    Icons.edit_location_alt_outlined,
                    size: 20,
                    color: Colors.blueAccent,
                  ),
                  suffixIcon: _districtController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _districtController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Tarjeta explicativa
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blueAccent.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.blueAccent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "El Radar priorizará noticias de tu localidad y las complementará con $provName y la región de $deptName.",
                        style: TextStyle(
                          fontSize: 11,
                          color: secondaryTextColor,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Botón 1: Aplicar con Distrito/Localidad
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  key: const ValueKey('btn_apply_district'),
                  onPressed: () {
                    final text = _districtController.text.trim();
                    widget.onLocationSelected(
                      RadarLocation(
                        department: deptName,
                        province: provName,
                        district: text.isNotEmpty ? text : null,
                        corridor: corridor,
                      ),
                    );
                  },
                  icon: const Icon(Icons.check, size: 18),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _districtController.text.trim().isNotEmpty
                          ? "Aplicar con '${_districtController.text.trim()}'"
                          : "Aplicar con Distrito / Localidad",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Botón 2: Usar toda la provincia
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const ValueKey('btn_use_province'),
                  onPressed: () {
                    widget.onLocationSelected(
                      RadarLocation(
                        department: deptName,
                        province: provName,
                        district: null,
                        corridor: corridor,
                      ),
                    );
                  },
                  icon: const Icon(Icons.location_city_rounded, size: 18),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      "Usar toda la provincia ($provName)",
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark
                        ? Colors.grey[300]
                        : const Color(0xFF334155),
                    side: BorderSide(
                      color: isDark ? Colors.white24 : Colors.grey[400]!,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
