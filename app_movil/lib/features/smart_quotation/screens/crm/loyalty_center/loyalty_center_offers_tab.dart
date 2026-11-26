part of '../loyalty_center_screen.dart';

mixin _LoyaltyCenterOffersTabMixin on _LoyaltyCenterStateBase {
  // =========================================================================
  // TAB 3: AVISOS DE OFERTAS, AUDIENCIA Y DIFUSOR WHATSAPP
  // =========================================================================
  @override
  Widget _buildOffersBroadcasterTab(bool isDark, Color cardColor, Color textColor) {
    final products = _filteredCatalogProducts;
    final audienceClients = _finalAudienceClients;
    final bool canBroadcast = _selectedProductIds.isNotEmpty && audienceClients.isNotEmpty;

    String broadcastBtnText;
    if (_selectedProductIds.isEmpty) {
      broadcastBtnText = "Selecciona productos para difundir";
    } else if (audienceClients.isEmpty) {
      broadcastBtnText = "Sin clientes en este segmento";
    } else {
      broadcastBtnText = "Difundir Ofertas (${_selectedProductIds.length} prod. • ${audienceClients.length} clientes)";
    }

    return Column(
      children: [
        // Banner explicativo descartable
        if (_showTab3Banner)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.campaign_rounded, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Selecciona ofertas y envíalas por WhatsApp a tus clientes con formato comercial.",
                    style: TextStyle(fontSize: 11.5, color: isDark ? Colors.blue[200] : Colors.blue[900]),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  onPressed: () => setState(() => _showTab3Banner = false),
                ),
              ],
            ),
          ),

        // Filtro y Acciones Rápidas de Productos
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "1. Selecciona los Productos",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (_selectedProductIds.length == products.length) {
                          _selectedProductIds.clear();
                        } else {
                          _selectedProductIds.addAll(products.map((p) => p['id'] as int));
                        }
                      });
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      _selectedProductIds.length == products.length && products.isNotEmpty
                          ? "Limpiar selección"
                          : "Seleccionar todos (${products.length})",
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.amber[800]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Chips de Modo de Producto (Iconos vectoriales limpios sin emojis)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    ChoiceChip(
                      avatar: const Icon(Icons.local_fire_department_rounded, size: 14, color: Colors.orange),
                      label: Text("Ofertas Activas ($_ofertasCount)"),
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: _productFilterMode == 'ofertas' ? FontWeight.bold : FontWeight.w500,
                      ),
                      selected: _productFilterMode == 'ofertas',
                      selectedColor: Colors.orange.withValues(alpha: 0.2),
                      onSelected: (v) => setState(() => _productFilterMode = 'ofertas'),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      avatar: const Icon(Icons.inventory_2_outlined, size: 14, color: Colors.purple),
                      label: Text("Baja Rotación ($_bajaRotacionCount)"),
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: _productFilterMode == 'baja_rotacion' ? FontWeight.bold : FontWeight.w500,
                      ),
                      selected: _productFilterMode == 'baja_rotacion',
                      selectedColor: Colors.purple.withValues(alpha: 0.2),
                      onSelected: (v) => setState(() => _productFilterMode = 'baja_rotacion'),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      avatar: const Icon(Icons.list_alt_rounded, size: 14, color: Colors.grey),
                      label: Text("Todos (${_catalogProducts.length})"),
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: _productFilterMode == 'todos' ? FontWeight.bold : FontWeight.w500,
                      ),
                      selected: _productFilterMode == 'todos',
                      selectedColor: Colors.grey.withValues(alpha: 0.2),
                      onSelected: (v) => setState(() => _productFilterMode = 'todos'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Buscador de Productos
              TextField(
                controller: _productSearchCtrl,
                onChanged: (val) => setState(() => _productSearchQuery = val),
                style: TextStyle(color: textColor, fontSize: 13),
                decoration: InputDecoration(
                  hintText: "Buscar producto por nombre o descripción...",
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  suffixIcon: _productSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          onPressed: () {
                            _productSearchCtrl.clear();
                            setState(() => _productSearchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
        ),

        // Lista de Productos Expandida (Ocupa todo el espacio vertical disponible)
        Expanded(
          child: products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 40, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        _productSearchQuery.isNotEmpty
                            ? "No hay productos que coincidan con la búsqueda"
                            : "No hay productos con este filtro",
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      if (_productSearchQuery.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: () {
                            _productSearchCtrl.clear();
                            setState(() => _productSearchQuery = '');
                          },
                          child: const Text("Limpiar búsqueda"),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  physics: const BouncingScrollPhysics(),
                  itemCount: products.length,
                  itemBuilder: (ctx, i) {
                    final p = products[i];
                    final id = p['id'] as int;
                    final isSelected = _selectedProductIds.contains(id);
                    final regularPrice = p['precioRegular'] as double;
                    final effectivePrice = p['precioEfectivo'] as double;
                    final hasOffer = p['hasOffer'] as bool;
                    final savings = (regularPrice - effectivePrice).clamp(0.0, double.infinity);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      elevation: 0,
                      color: cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected
                              ? Colors.amber[700]!
                              : (isDark ? Colors.white10 : Colors.grey.shade200),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: CheckboxListTile(
                        dense: true,
                        value: isSelected,
                        activeColor: Colors.amber[700],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedProductIds.add(id);
                            } else {
                              _selectedProductIds.remove(id);
                            }
                          });
                        },
                        title: Text(
                          p['nombre'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Wrap(
                          spacing: 6,
                          runSpacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              AppCurrency.format(effectivePrice),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                                color: hasOffer ? Colors.green[600] : textColor,
                              ),
                            ),
                            if (hasOffer) ...[
                              Text(
                                AppCurrency.format(regularPrice),
                                style: const TextStyle(
                                  fontSize: 11,
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.grey,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  "Ahorro ${AppCurrency.format(savings)}",
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: (p['isLowStock'] as bool)
                                    ? Colors.red.withValues(alpha: 0.15)
                                    : (isDark ? Colors.white10 : Colors.grey[200]),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "Stock: ${p['stock']}",
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: (p['isLowStock'] as bool)
                                      ? Colors.red
                                      : (isDark ? Colors.grey[400] : Colors.grey[700]),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Dock Inferior Colapsable de Audiencia y Envío
        _buildAudienceDock(isDark, cardColor, textColor, canBroadcast, broadcastBtnText),
      ],
    );
  }

  Widget _buildAudienceDock(
    bool isDark,
    Color cardColor,
    Color textColor,
    bool canBroadcast,
    String broadcastBtnText,
  ) {
    final audienceClients = _finalAudienceClients;
    final totalSegment = _segmentClients;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
        border: Border(
          top: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barra de Resumen / Título del Dock (Tocar para expandir/colapsar)
          InkWell(
            onTap: () => setState(() => _isAudienceDockExpanded = !_isAudienceDockExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.groups_rounded,
                    size: 18,
                    color: Colors.blue[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Audiencia: ${_audienceFilterTier == 'TODOS' ? 'Todos' : ReputationTier.fromKey(_audienceFilterTier).badgeText} (${audienceClients.length} clientes)",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "${_selectedProductIds.length} prod.",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber[800],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _isAudienceDockExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),

          // Contenido Expandido del Dock
          if (_isAudienceDockExpanded) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Chips de Niveles de Audiencia (con iconos vectoriales y conteo)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildAudienceChip('TODOS', 'Todos (${_allClients.length})', Icons.people_outline_rounded),
                        const SizedBox(width: 6),
                        _buildAudienceChip('DIAMANTE_VIP', 'Diamante VIP (${_countByTier('DIAMANTE_VIP')})', Icons.diamond_rounded),
                        const SizedBox(width: 6),
                        _buildAudienceChip('ORO', 'Oro (${_countByTier('ORO')})', Icons.military_tech_rounded),
                        const SizedBox(width: 6),
                        _buildAudienceChip('PLATA', 'Plata (${_countByTier('PLATA')})', Icons.verified_rounded),
                        const SizedBox(width: 6),
                        _buildAudienceChip('BRONCE', 'Bronce (${_countByTier('BRONCE')})', Icons.shield_outlined),
                        const SizedBox(width: 6),
                        _buildAudienceChip('OBSERVACION', 'Observación (${_countByTier('OBSERVACION')})', Icons.warning_amber_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Lista seleccionable de clientes de la audiencia
                  if (totalSegment.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        "No hay clientes registrados en este segmento.",
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 140),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: totalSegment.length,
                        itemBuilder: (ctx, idx) {
                          final c = totalSegment[idx];
                          final isIncluded = !_deselectedAudienceClientIds.contains(c.id);

                          return CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            value: isIncluded,
                            activeColor: const Color(0xFF25D366),
                            title: Text(
                              c.fullName,
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textColor),
                            ),
                            subtitle: Text(
                              "${c.phone} • ${c.tier.badgeText} (${c.puntosActuales} pts)",
                              style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                            ),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _deselectedAudienceClientIds.remove(c.id);
                                } else {
                                  _deselectedAudienceClientIds.add(c.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],

          // Botón de Envío Difusión WhatsApp
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                key: _tourKeys.broadcastWhatsappKey,
                onPressed: canBroadcast
                    ? () {
                        final auth = Provider.of<AuthProvider>(context, listen: false);
                        final selectedProductsList = _catalogProducts
                            .where((p) => _selectedProductIds.contains(p['id']))
                            .toList();

                        PromotionBroadcastModal.show(
                          context,
                          businessName: auth.businessName,
                          selectedProducts: selectedProductsList,
                          targetClients: audienceClients,
                        );
                      }
                    : null,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  broadcastBtnText,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  disabledBackgroundColor: isDark ? Colors.white10 : Colors.grey.shade300,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: isDark ? Colors.white38 : Colors.grey.shade500,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudienceChip(String key, String label, IconData icon) {
    final isSelected = _audienceFilterTier == key;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 13,
        color: isSelected ? Colors.white : Colors.blue[600],
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87),
        ),
      ),
      selected: isSelected,
      selectedColor: Colors.blue[600],
      backgroundColor: Colors.blue.withValues(alpha: 0.12),
      onSelected: (val) {
        if (val) {
          setState(() {
            _audienceFilterTier = key;
            _deselectedAudienceClientIds.clear();
          });
        }
      },
    );
  }
}
