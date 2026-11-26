part of '../scan_screen.dart';

extension _ScanScreenQuotationAndErrorExtension on _ScanScreenState {
  Widget _buildGuestExplorationBanner({
    required bool isDark,
    EdgeInsetsGeometry? margin,
    double padding = 14,
    double fontSize = 12.5,
  }) {
    return Container(
      margin: margin,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Estás en Modo Exploración. Explora la interfaz visual, pero para procesar imágenes necesitas registrar tu negocio.",
              style: TextStyle(
                color: isDark ? Colors.orange[200] : Colors.orange[900],
                fontSize: fontSize,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Panel integrado de Error
  Widget _buildErrorPanel(bool isDark, Color mainColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      key: const ValueKey("error_panel"),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.1),
                  blurRadius: 25,
                  spreadRadius: 5,
                ),
            ],
          ),
          child: Icon(
            Icons.error_outline_rounded,
            size: 70,
            color: Colors.red[400],
          ),
        ),
        const SizedBox(height: 30),

        Text(
          "No pudimos procesar la imagen",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : Colors.black87,
            letterSpacing: -0.5,
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.grey[300] : Colors.grey[700],
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Botón Primario: Reintentar
        SizedBox(
          width: 280,
          height: 56,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.refresh_rounded, size: 24),
            label: const Text(
              "Reintentar Escaneo",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: mainColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              shadowColor: mainColor.withValues(alpha: 0.4),
            ),
            onPressed: _retryWithCachedImage,
          ),
        ),

        const SizedBox(height: 16),

        // Botón Secundario: Nueva Foto
        SizedBox(
          width: 280,
          height: 50,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.camera_alt_outlined, size: 20),
            label: const Text(
              "Escanear una nueva foto",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? Colors.grey[300] : Colors.grey[700],
              side: BorderSide(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                width: 2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _pickNewImage,
          ),
        ),
      ],
    );
  }

  Widget _buildQuotationMainPanel(
    bool isDark,
    Color mainColor,
    IconData mainIcon,
    String subtitle,
    bool isGuest,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      key: const ValueKey("main_panel_quotation"),
      children: [
        KeyedSubtree(
          key: _quotationTourKeys.clientHintKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: isDark
                      ? mainColor.withValues(alpha: 0.15)
                      : mainColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: mainColor.withValues(alpha: 0.1),
                        blurRadius: 20,
                        spreadRadius: 3,
                      ),
                  ],
                ),
                child: Icon(
                  mainIcon,
                  size: 60,
                  color: isDark ? mainColor.withValues(alpha: 0.9) : mainColor,
                ),
              ),
              const SizedBox(height: 24),

              Text(
                "Digitaliza tu Lista",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                  letterSpacing: -0.5,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                child: Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Chips informativos de escenarios multi-rubro soportados (sin emojis crudos)
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: KeyedSubtree(
            key: _quotationTourKeys.scenariosKey,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildScenarioPill(
                  icon: Icons.shopping_bag_outlined,
                  label: "Compras / Pedido",
                  color: Colors.blue,
                  isDark: isDark,
                ),
                _buildScenarioPill(
                  icon: Icons.storefront_rounded,
                  label: "Mayorista / Negocio",
                  color: Colors.teal,
                  isDark: isDark,
                ),
                _buildScenarioPill(
                  icon: Icons.school_outlined,
                  label: "Lista Escolar",
                  color: Colors.orange,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),

        if (isGuest)
          _buildGuestExplorationBanner(
            isDark: isDark,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            padding: 14,
            fontSize: 12.5,
          ),

        const SizedBox(height: 24),

        KeyedSubtree(
          key: _quotationTourKeys.captureActionsKey,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: _bigButton(
                    icon: Icons.camera_alt_rounded,
                    label: "Cámara",
                    color: mainColor,
                    isDark: isDark,
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _bigButton(
                    icon: Icons.photo_library_rounded,
                    label: "Galería",
                    color: Colors.orange,
                    isDark: isDark,
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _bigButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        splashColor: color.withValues(alpha: 0.2),
        highlightColor: color.withValues(alpha: 0.1),
        child: Container(
          height: 135,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF23232F) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? color.withValues(alpha: 0.3)
                  : color.withValues(alpha: 0.2),
              width: 2,
            ),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: color.withValues(alpha: 0.15),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 44,
                color: isDark ? color.withValues(alpha: 0.9) : color,
              ),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    color: isDark ? color.withValues(alpha: 0.9) : color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScenarioPill({
    required IconData icon,
    required String label,
    required MaterialColor color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? color.withValues(alpha: 0.15) : color.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? color.withValues(alpha: 0.3) : color.shade200,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: isDark ? color.shade300 : color.shade700,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? color.shade200 : color.shade900,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
