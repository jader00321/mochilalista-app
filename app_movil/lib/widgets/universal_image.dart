import 'dart:io';
import 'package:flutter/material.dart';

class UniversalImage extends StatelessWidget {
  final String? path;
  final double? height; 
  final double? width;
  final BoxFit fit;

  const UniversalImage({
    super.key,
    required this.path,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (path == null || path!.isEmpty || path == 'null') {
      return _buildPlaceholder(context, isDark);
    }

    // Salvavidas para datos antiguos (legacy URLs)
    if (path!.startsWith('http')) {
      return Image.network(
        path!,
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildError(context, isDark),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: height,
            width: width,
            color: isDark ? Colors.white10 : Colors.grey[100],
            child: const Center(
              child: SizedBox(
                height: 24, width: 24, 
                child: CircularProgressIndicator(strokeWidth: 3, color: Colors.grey)
              )
            ),
          );
        },
      );
    }

    // Lógica Offline Principal: Leer desde el celular
    final file = File(path!);
    if (file.existsSync()) {
      return Image.file(
        file,
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildError(context, isDark),
      );
    }

    return _buildPlaceholder(context, isDark);
  }

  Widget _buildPlaceholder(BuildContext context, bool isDark) {
    return Container(
      height: height,
      width: width,
      color: isDark ? Colors.white10 : Colors.grey[100],
      padding: const EdgeInsets.all(4),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported_outlined, size: 36, color: isDark ? Colors.white24 : Colors.grey[400]),
            const SizedBox(height: 6),
            Text("Sin imagen", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[500], fontSize: 12, fontWeight: FontWeight.bold))
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, bool isDark) {
    return Container(
      height: height,
      width: width,
      color: isDark ? Colors.white10 : Colors.grey[100],
      padding: const EdgeInsets.all(4),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, color: isDark ? Colors.grey[600] : Colors.grey, size: 30),
            const SizedBox(height: 6),
            Text("Error", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold))
          ],
        ),
      ),
    );
  }
}