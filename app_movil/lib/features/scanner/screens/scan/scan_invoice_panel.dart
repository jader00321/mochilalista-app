part of '../scan_screen.dart';

extension _ScanScreenInvoiceExtension on _ScanScreenState {
  Widget _buildInvoiceHeroCard(bool isDark) {
    return KeyedSubtree(
      key: _invoiceTourKeys.heroQuotaKey,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF0D2928), const Color(0xFF13222B)]
                : [const Color(0xFFE6F7F5), const Color(0xFFF0FDF8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark
                ? Colors.teal.withValues(alpha: 0.35)
                : Colors.teal.shade300.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.teal.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                size: 34,
                color: isDark ? Colors.tealAccent : Colors.teal.shade700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Procesa tu Compra",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              "Digitaliza tu factura o boleta de proveedor y actualiza tu stock automáticamente.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            // Badge Reactivo de Cuota IA (nullable-safe)
            Builder(
              builder: (ctx) {
                final licenseProv = Provider.of<LicenseProvider?>(ctx);
                final isByok =
                    licenseProv != null &&
                    (licenseProv.isUsingByokMode ||
                        licenseProv.isUsingCustomApiKey);
                final remaining = licenseProv?.remainingAiScans ?? 0;
                final isLow = remaining <= 5;

                final MaterialColor badgeColor = isByok
                    ? Colors.purple
                    : (isLow ? Colors.amber : Colors.teal);

                final String badgeText = isByok
                    ? "IA Ilimitada (Clave Propia)"
                    : (licenseProv == null
                          ? "IA Oficial Activa"
                          : "$remaining ${remaining == 1 ? 'escaneo IA disponible' : 'escaneos IA disponibles'}");

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: isDark ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: badgeColor.withValues(
                        alpha: isDark ? 0.45 : 0.35,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isByok ? Icons.key_rounded : Icons.auto_awesome_rounded,
                        size: 14,
                        color: isDark
                            ? badgeColor.shade200
                            : badgeColor.shade800,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          badgeText,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? badgeColor.shade200
                                : badgeColor.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceMainPanel(bool isDark, bool isGuest) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      key: const ValueKey("main_panel_invoice"),
      children: [
        // 1. Tarjeta Hero Moderna con Badge en Vivo de Escaneos IA
        _buildInvoiceHeroCard(isDark),

        if (isGuest) ...[
          const SizedBox(height: 12),
          _buildGuestExplorationBanner(
            isDark: isDark,
            padding: 12,
            fontSize: 12,
          ),
        ],

        const SizedBox(height: 16),

        // 2. Tarjetas Interactivas de Acción Primaria (Cámara y Galería)
        Row(
          children: [
            Expanded(
              child: KeyedSubtree(
                key: _invoiceTourKeys.cameraCardKey,
                child: _buildActionCard(
                  icon: Icons.camera_alt_rounded,
                  title: "Cámara",
                  subtitle: "Toma una foto nítida de la factura",
                  color: Colors.teal,
                  isDark: isDark,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _pickImage(ImageSource.camera);
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: KeyedSubtree(
                key: _invoiceTourKeys.galleryCardKey,
                child: _buildActionCard(
                  icon: Icons.photo_library_rounded,
                  title: "Galería",
                  subtitle: "Sube una imagen o captura guardada",
                  color: Colors.orange.shade800,
                  isDark: isDark,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // 3. Bloque Inferior Pedagógico y de Valor Real (CERO emojis crudos)
        Row(
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 18,
              color: isDark ? Colors.tealAccent : Colors.teal.shade700,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "¿Qué procesa la IA automáticamente?",
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        _buildFeatureRow(
          icon: Icons.inventory_2_outlined,
          color: Colors.blue,
          title: "Ítems y Cantidades",
          description: "Detecta cada producto y sus unidades de compra.",
          isDark: isDark,
        ),
        _buildFeatureRow(
          icon: Icons.payments_outlined,
          color: Colors.green,
          title: "Costos y Márgenes",
          description:
              "Calcula el costo unitario y ayuda a definir tu precio de venta.",
          isDark: isDark,
        ),
        _buildFeatureRow(
          icon: Icons.sync_rounded,
          color: Colors.purple,
          title: "Reposición Directa",
          description:
              "Actualiza tu inventario al confirmar sin digitar uno por uno.",
          isDark: isDark,
        ),

        const SizedBox(height: 10),

        // 4. Consejo de Captura Óptima
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.amber.withValues(alpha: 0.1)
                : const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.amber.withValues(alpha: isDark ? 0.35 : 0.5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: isDark ? Colors.amber[300] : Colors.amber[800],
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Consejo: Coloca la factura sobre una superficie plana, con buena iluminación y evitando sombras o dobleces.",
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.amber[100] : const Color(0xFF78350F),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: color.withValues(alpha: 0.15),
        highlightColor: color.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E222D) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? color.withValues(alpha: 0.35)
                  : color.withValues(alpha: 0.25),
              width: 1.5,
            ),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: color.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required MaterialColor color,
    required String title,
    required String description,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1F2A) : Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: isDark ? color.shade300 : color.shade700,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
