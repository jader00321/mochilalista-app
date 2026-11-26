part of '../commercial_radar_card.dart';

mixin _RadarCardHeaderAndPickersMixin on _CommercialRadarCardStateBase {
  void _openRegionPicker() {
    final sheetBg = widget.isDark ? const Color(0xFF1E293B) : Colors.white;

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return InteractiveSheetWrapper(
          backgroundColor: sheetBg,
          maxHeightFactor: 0.85,
          applyEffectiveBottomPadding: true,
          showHandle: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.location_on, color: Colors.blueAccent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Enfoque Geográfico", 
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "Sintoniza noticias y mercado de tu localidad",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: InteractiveSheetWrapper.kModalScrollBottomClearance),
                    children: [
                      ..._radarPredefinedRegions.map((reg) {
                        final isSelected = reg == _selectedRegion;
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            reg == 'Todo el Perú' ? Icons.public : Icons.location_city,
                            color: isSelected ? Colors.blueAccent : Colors.grey,
                          ),
                          title: Text(
                            reg,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected 
                                  ? Colors.blueAccent 
                                  : (widget.isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                          trailing: isSelected 
                              ? const Icon(Icons.check_circle, color: Colors.blueAccent, size: 20) 
                              : null,
                          onTap: () {
                            Navigator.pop(ctx);
                            _setRegion(reg);
                          },
                        );
                      }),
                      const Divider(),
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.edit_location_alt, color: Colors.amber),
                        title: const Text(
                          "Otra / Personalizada...",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          _promptCustomRegion();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _promptCustomRegion() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.location_city, color: Colors.blueAccent),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                "Ciudad o Región",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Escribe tu ciudad, provincia o región en Perú:",
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: "Ej: Huancayo, Chimbote, Iquitos...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              final val = textController.text.trim();
              if (val.isNotEmpty) {
                Navigator.pop(dlgCtx);
                _setRegion(val);
              }
            },
            child: const Text("Aplicar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget _buildRadarCardBody(BuildContext context) {
    final filtered = _filteredItems;
    // Priorizar distintas categorías y rotar dinámicamente
    final diversified = CommercialRadarService.interleaveCategories(filtered);
    final previewItems = _getRotatedPreview(diversified, 3);

    return GlassCard(
      isDark: widget.isDark,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with radar pulse
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.redAccent.withValues(
                        alpha: 0.15 + (_pulseController.value * 0.15),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withValues(
                            alpha: 0.2 * _pulseController.value,
                          ),
                          blurRadius: 10 * _pulseController.value,
                          spreadRadius: 2 * _pulseController.value,
                        )
                      ],
                    ),
                    child: const Icon(Icons.radar, color: Colors.redAccent, size: 22),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          const Text(
                            "Radar Comercial",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.4)),
                            ),
                            child: const Text(
                              "IA EN VIVO",
                              style: TextStyle(
                                fontSize: 9, 
                                fontWeight: FontWeight.bold, 
                                color: Colors.blueAccent,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Alertas estratégicas para comerciantes en Perú",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12, 
                        color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.shuffle_rounded, size: 20),
                tooltip: "Alternar señales",
                onPressed: filtered.length > 1 ? _rotateSignals : null,
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: "Actualizar señales de mercado",
                onPressed: () => _startRadarStream(forceRefresh: true),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Region Switcher Pill
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                "Enfoque Geográfico:",
                style: TextStyle(
                  fontSize: 12, 
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.grey[400] : Colors.grey[700],
                ),
              ),
              GestureDetector(
                onTap: _openRegionPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.isDark ? Colors.white10 : Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: widget.isDark ? Colors.white24 : Colors.grey[300]!,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _selectedRegion.toLowerCase().contains('talara') || _selectedRegion.toLowerCase().contains('piura')
                            ? Icons.location_on 
                            : (_selectedRegion == 'Todo el Perú' ? Icons.public : Icons.location_city),
                        size: 14,
                        color: Colors.blueAccent,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _selectedRegion,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, size: 16, color: Colors.blueAccent),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Category filter pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                    selectedColor: Colors.blueAccent,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected 
                          ? Colors.white 
                          : (widget.isDark ? Colors.grey[300] : Colors.grey[800]),
                    ),
                    backgroundColor: widget.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                    side: BorderSide(
                      color: isSelected ? Colors.blueAccent : (widget.isDark ? Colors.white12 : Colors.grey[300]!),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // News items or loading indicator (Máximo 2 noticias estables en Estadísticas)
          if (_isLoading && _newsItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32.0),
              child: Center(
                child: Column(
                  children: [
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Sintonizando señales de mercado en $_selectedRegion...",
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Text(
                  "No hay alertas en la categoría '$_selectedCategory' por el momento.",
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
              ),
            )
          else
            Column(
              children: [
                ...previewItems.map((item) => _buildNewsCard(item)),
                const SizedBox(height: 6),
                _buildOpenRadarButton(),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildOpenRadarButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent.withValues(alpha: widget.isDark ? 0.15 : 0.08),
          foregroundColor: Colors.blueAccent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.blueAccent, width: 1.2),
          ),
        ),
        icon: const Icon(Icons.newspaper_rounded, size: 20),
        label: const Text(
          "Explorar más noticias y alertas comerciales (Abrir Radar IA)",
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CommercialRadarScreen(
                initialRegion: _selectedRegion,
                profileId: _resolvedProfileId,
              ),
            ),
          );
          if (mounted) {
            await _loadSavedRegion(profileId: _resolvedProfileId);
          }
        },
      ),
    );
  }
}
