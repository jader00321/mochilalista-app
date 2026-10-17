import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 🏆 UNIVERSAL IMAGE (Mobile Awards Quality)
/// Carga imágenes locales y remotas con caché, y en caso de ausencia o fallo,
/// genera un Smart Visual Placeholder proporcional con degradado determinístico,
/// monograma tipográfico y micro-icono vectorial de categoría sin mostrar "Sin imagen".
class UniversalImage extends StatelessWidget {
  final String? path;
  final double? height; 
  final double? width;
  final BoxFit fit;
  final String? productName;
  final String? categoryName;

  const UniversalImage({
    super.key,
    required this.path,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.productName,
    this.categoryName,
  });

  static const List<List<Color>> _palettes = [
    [Color(0xFF283593), Color(0xFF1A237E)], // Indigo
    [Color(0xFF00695C), Color(0xFF004D40)], // Teal
    [Color(0xFF4527A0), Color(0xFF311B92)], // Deep Purple
    [Color(0xFF37474F), Color(0xFF263238)], // Blue Grey
    [Color(0xFF1565C0), Color(0xFF0D47A1)], // Blue
    [Color(0xFF880E4F), Color(0xFF4A148C)], // Magenta / Purple
    [Color(0xFFC2185B), Color(0xFF880E4F)], // Pink
    [Color(0xFF2E7D32), Color(0xFF1B5E20)], // Green
    [Color(0xFFD84315), Color(0xFFBF360C)], // Deep Orange
    [Color(0xFF00838F), Color(0xFF006064)], // Cyan
  ];

  static String extractInitials(String? name) {
    if (name == null || name.trim().isEmpty) return "ML";
    final clean = name.replaceAll(RegExp(r'^[^a-zA-Z0-9áéíóúÁÉÍÓÚñÑ]+'), '').trim();
    if (clean.isEmpty) return "ML";
    final words = clean.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length >= 2) {
      return (words[0][0] + words[1][0]).toUpperCase();
    }
    if (clean.length >= 2) {
      return clean.substring(0, 2).toUpperCase();
    }
    return clean.toUpperCase();
  }

  static IconData getCategoryIcon(String? catName, [String? prodName]) {
    final combined = "${catName ?? ''} ${prodName ?? ''}".toLowerCase();
    if (combined.trim().isEmpty) return Icons.inventory_2_rounded;
    if (combined.contains("bebid") || combined.contains("agua") || combined.contains("gaseos") || combined.contains("jugo") || combined.contains("licor") || combined.contains("cerveza") || combined.contains("vino") || combined.contains("refresco")) {
      return Icons.local_drink_rounded;
    }
    if (combined.contains("abarrot") || combined.contains("despens") || combined.contains("alimento") || combined.contains("arroz") || combined.contains("aceite") || combined.contains("azucar") || combined.contains("fideo") || combined.contains("harina") || combined.contains("atun") || combined.contains("conserva")) {
      return Icons.shopping_basket_rounded;
    }
    if (combined.contains("limpiez") || combined.contains("aseo") || combined.contains("deterg") || combined.contains("jabon") || combined.contains("shampoo") || combined.contains("cloro") || combined.contains("suaviz")) {
      return Icons.cleaning_services_rounded;
    }
    if (combined.contains("util") || combined.contains("librer") || combined.contains("escolar") || combined.contains("papel") || combined.contains("cuaderno") || combined.contains("lapiz") || combined.contains("boligrafo")) {
      return Icons.edit_note_rounded;
    }
    if (combined.contains("lacte") || combined.contains("leche") || combined.contains("queso") || combined.contains("yogur") || combined.contains("mantequilla")) {
      return Icons.breakfast_dining_rounded;
    }
    if (combined.contains("snack") || combined.contains("golosin") || combined.contains("dulce") || combined.contains("gallet") || combined.contains("chocolate") || combined.contains("caramelo")) {
      return Icons.cookie_rounded;
    }
    if (combined.contains("carn") || combined.contains("pollo") || combined.contains("embut") || combined.contains("jamon") || combined.contains("salchicha")) {
      return Icons.restaurant_rounded;
    }
    return Icons.inventory_2_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (path == null || path!.isEmpty || path == 'null') {
      return _buildSmartPlaceholder(context, isDark);
    }

    // Salvavidas para datos antiguos (legacy URLs)
    if (path!.startsWith('http')) {
      return Image.network(
        path!,
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildSmartPlaceholder(context, isDark, isError: true),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: height,
            width: width,
            color: isDark ? Colors.white10 : Colors.grey[100],
            child: const Center(
              child: SizedBox(
                height: 24, width: 24, 
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.grey),
              ),
            ),
          );
        },
      );
    }

    // Lógica Offline Principal: Leer desde el almacenamiento local
    final file = File(path!);
    if (file.existsSync()) {
      return Image.file(
        file,
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildSmartPlaceholder(context, isDark, isError: true),
      );
    }

    return _buildSmartPlaceholder(context, isDark);
  }

  Widget _buildSmartPlaceholder(BuildContext context, bool isDark, {bool isError = false}) {
    final seed = (productName ?? categoryName ?? 'mochilalista').hashCode.abs();
    final palette = _palettes[seed % _palettes.length];
    final initials = extractInitials(productName);
    final categoryIcon = getCategoryIcon(categoryName, productName);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : (width ?? 90.0);
        final double maxH = constraints.maxHeight.isFinite ? constraints.maxHeight : (height ?? 90.0);
        final double minDim = math.min(maxW, maxH);

        final double fontSize = (minDim * 0.36).clamp(11.0, 44.0);
        final double iconSize = (minDim * 0.22).clamp(10.0, 26.0);
        final double badgePadding = (minDim * 0.05).clamp(3.0, 8.0);

        final bgGradient = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  palette[0].withValues(alpha: 0.38),
                  palette[1].withValues(alpha: 0.60),
                ]
              : [
                  palette[0].withValues(alpha: 0.12),
                  palette[1].withValues(alpha: 0.24),
                ],
        );

        final textColor = isDark 
            ? Colors.white.withValues(alpha: 0.95) 
            : palette[0].withValues(alpha: 0.95);

        return Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            gradient: bgGradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Monograma Central Escalar
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: textColor,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),

              // Micro-Icono de Categoría en Esquina Inferior Derecha
              Positioned(
                bottom: badgePadding,
                right: badgePadding,
                child: Container(
                  padding: EdgeInsets.all(badgePadding * 0.8),
                  decoration: BoxDecoration(
                    color: isDark 
                        ? Colors.black.withValues(alpha: 0.35) 
                        : Colors.white.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.black12,
                      width: 0.8,
                    ),
                  ),
                  child: Icon(
                    isError ? Icons.broken_image_rounded : categoryIcon,
                    size: iconSize,
                    color: isError 
                        ? (isDark ? Colors.red[300] : Colors.red[700]) 
                        : (isDark ? Colors.white70 : palette[0]),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}