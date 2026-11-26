part of '../license_status_and_activation_screen.dart';

mixin _LicenseCatalogSectionMixin on _LicenseScreenStateBase {
  @override
  Widget _buildPricingAndPaymentCatalog(
    LicenseModel? license,
    String fingerprint,
    bool isDark,
    EffectiveCommercialConfig effectiveConfig,
  ) {
    final hasPaidCommercialLicense =
        license != null && license.isActive && !license.isTrial;
    _isPlansExpanded ??= !hasPaidCommercialLicense;
    final isExpanded = _isPlansExpanded!;
    final activePlans =
        LicenseStatusAndActivationScreen.buildEffectiveOfficialPlans(
          effectiveConfig,
        );

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E28) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            KeyedSubtree(
              key: _tourKeys.pricingCatalogKey,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const ValueKey("accordion_pricing_catalog_header"),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() {
                      _isPlansExpanded = !_isPlansExpanded!;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.local_offer_rounded,
                          size: 20,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Planes Comerciales Oficiales",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              if (!isExpanded) ...[
                                const SizedBox(height: 3),
                                Text(
                                  "Explora 7 planes y recargas: mayor ahorro semestral/anual, Licencia Perpetua y Bolsas Extra IA sin vencimiento.",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeInOutCubic,
                          child: const Icon(
                            Icons.expand_more_rounded,
                            size: 22,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (!isExpanded) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const ValueKey("btn_toggle_expand_plans"),
                  onPressed: () {
                    setState(() {
                      _isPlansExpanded = true;
                    });
                  },
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text(
                    "Ver planes y recargas",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue[700],
                    side: BorderSide(color: Colors.blue.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              child: isExpanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),

                        // Indicador compacto cuando hay tarifas MLC1 sincronizadas
                        if (effectiveConfig.hasSyncedOverride) ...[
                          Container(
                            key: const ValueKey('badge_mlc1_synced_catalog'),
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.teal.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.verified_rounded,
                                      size: 16,
                                      color: Colors.teal,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Tarifas sincronizadas (Rev. #${effectiveConfig.revision} · ${effectiveConfig.issuedAtLimaLabel ?? effectiveConfig.appliedAtLimaLabel ?? ''})',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.tealAccent[200]
                                              : Colors.teal[900],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    key: const ValueKey(
                                      'btn_mlc1_reset_defaults',
                                    ),
                                    onPressed: _confirmResetCommercialCatalog,
                                    style: TextButton.styleFrom(
                                      foregroundColor: isDark
                                          ? Colors.orange[300]
                                          : Colors.orange[900],
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    icon: const Icon(
                                      Icons.restore_rounded,
                                      size: 14,
                                    ),
                                    label: const Text(
                                      'Restaurar defaults',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],

                        // Aviso de Renovación Acumulativa
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.blue.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                size: 18,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Si renuevas antes de que venza tu periodo, tus días no se pierden, se suman automáticamente.",
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.lightBlue[200]
                                        : Colors.blue[900],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Aviso de Cobertura Multinegocio y Cuota IA Compartida
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.indigo.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.indigo.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.storefront_rounded,
                                size: 18,
                                color: Colors.indigo,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Una sola licencia activa ampara todos los perfiles de tu negocio en este celular. La cuota de escaneos IA es compartida y acumulativa entre todos tus perfiles.",
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    height: 1.35,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? Colors.indigo[200]
                                        : Colors.indigo[900],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Lista de los 7 Productos del Catálogo Oficial
                        ...activePlans.map(
                          (p) => _buildPlanTile(p, fingerprint, isDark),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          key: const ValueKey('tile_migration_fee_info'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF14141C)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark ? Colors.white10 : Colors.black12,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.swap_horiz_rounded,
                                size: 16,
                                color: isDark
                                    ? Colors.indigo[300]
                                    : Colors.indigo[700],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${effectiveConfig.migracion.label}: ${effectiveConfig.migracion.formattedPrice}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.grey[300]
                                        : Colors.grey[800],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        const Divider(height: 1),
                        const SizedBox(height: 14),

                        // Medios de Pago Directos (Perú) con Copiado en 1 Toque y Toast Flotante
                        Text(
                          "Medios de Pago Directos (Perú):",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Tarjeta Yape / Plin con Copiado en 1 Toque
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF14141C)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.white12 : Colors.black12,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF6B1D90,
                                  ).withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.qr_code_2_rounded,
                                  color: Color(0xFF6B1D90),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Yape y Plin (Perú)",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                    Text(
                                      "${effectiveConfig.yapePhone} • ${effectiveConfig.yapeHolder}",
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isDark
                                            ? Colors.grey[300]
                                            : Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () {
                                  ClipboardHelper.copyWithFeedback(
                                    context,
                                    effectiveConfig.yapePhone,
                                    feedbackMessage:
                                        "Número Yape/Plin copiado: ${effectiveConfig.yapePhone}",
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6B1D90),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  "Copiar",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Tarjetas Bancarias Opcionales BCP / BBVA
                        _buildBankAccountsSection(isDark, effectiveConfig),
                        const SizedBox(height: 14),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final msg =
                                  "Hola Julio Angello, deseo renovar/activar mi plan en MochilaLista. Mi ID de equipo es: $fingerprint";
                              _launchWhatsAppMessage(msg);
                            },
                            icon: const Icon(Icons.chat_rounded, size: 18),
                            label: const Text(
                              "Contactar por WhatsApp para activar",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
