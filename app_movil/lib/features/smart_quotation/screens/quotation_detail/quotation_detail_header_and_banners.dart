part of '../quotation_detail_screen.dart';

mixin _QuotationDetailHeaderAndBannersMixin on _QuotationDetailScreenStateBase {
  @override
  Future<void> _downloadImage() async {
    if (_fullQuotation?.sourceImageUrl == null) {
      return;
    }
    try {
      bool hasAccess = false;
      if (Platform.isAndroid) {
        if (await Permission.photos.request().isGranted) {
          hasAccess = true;
        } else if (await Permission.storage.request().isGranted) {
          hasAccess = true;
        }
      } else {
        if (await Permission.photosAddOnly.request().isGranted ||
            await Permission.photos.request().isGranted) {
          hasAccess = true;
        }
      }

      if (!hasAccess && await Permission.storage.isPermanentlyDenied) {
        if (mounted) {
          CustomSnackBar.show(
            context,
            message: "Habilita el permiso de almacenamiento en Configuración",
            isError: true,
          );
        }
        return;
      }
      if (mounted) {
        CustomSnackBar.show(context, message: "Descargando...", isError: false);
      }

      final url = Uri.parse(_fullQuotation!.sourceImageUrl!);
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(url);
      final httpResponse = await request.close();
      final bytes = await consolidateHttpClientResponseBytes(httpResponse);
      await Gal.putImageBytes(
        Uint8List.fromList(bytes),
        name: "cotizacion_${_fullQuotation!.id}",
      );

      if (mounted) {
        CustomSnackBar.show(
          context,
          message: "Imagen guardada en Galería",
          isError: false,
        );
      }
    } on GalException catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: "Permiso denegado por el sistema: ${e.type.message}",
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: "Error al descargar imagen",
          isError: true,
        );
      }
    }
  }

  @override
  Widget _buildSmartAlertBanner(ValidationResult validation, bool isDark) {
    final bool isCritical =
        !validation.canSell || validation.sharedStockConflicts.isNotEmpty;

    if (isCritical) {
      // Banner crítico: stock insuficiente, bundle eliminado o conflicto compartido.
      final hasShared = validation.sharedStockConflicts.isNotEmpty;
      final Color bgColor = isDark ? Colors.red[900]! : Colors.red;
      return Container(
        width: double.infinity,
        color: bgColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              hasShared ? Icons.hub_rounded : Icons.error,
              color: Colors.white,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasShared
                        ? "¡Atención! Conflicto de Stock Compartido"
                        : "¡Atención! Stock Insuficiente",
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasShared
                        ? "Variantes compiten por el mismo inventario base en almacén."
                        : "Productos agotados detectados.",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 116),
              child: ElevatedButton(
                onPressed: () => _handleUpdateAnalysis(validation),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: bgColor,
                  elevation: 4,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "VER SOLUCIONES",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // Banner informativo: precios desactualizados sin bloquear venta.
      final Color bgColor = isDark
          ? Colors.amber[900]!.withValues(alpha: 0.6)
          : Colors.amber[100]!;
      final Color textColor = isDark ? Colors.amber[200]! : Colors.amber[900]!;
      return Container(
        width: double.infinity,
        color: bgColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: textColor, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Hay cambios de precio en algunos productos.",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  fontSize: 13,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _handleUpdateAnalysis(validation),
              style: TextButton.styleFrom(
                foregroundColor: textColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
              ),
              child: const Text(
                "REVISAR",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Color _getStatusColor(String status, bool isDark, bool isClient) {
    if (isClient) {
      switch (status) {
        case 'PENDING_APPROVAL':
        case 'PENDING':
          return isDark ? Colors.orange[400]! : Colors.orange;
        case 'READY':
          return isDark ? Colors.blue[400]! : Colors.blue;
        case 'SOLD':
          return isDark ? Colors.green[400]! : Colors.green;
        case 'DRAFT':
        case 'ARCHIVED':
          return isDark ? Colors.red[400]! : Colors.red;
        default:
          return Colors.grey;
      }
    } else {
      switch (status) {
        case 'PENDING_APPROVAL':
          return isDark ? Colors.deepOrange[400]! : Colors.deepOrange;
        case 'PENDING':
          return isDark ? Colors.orange[400]! : Colors.orange;
        case 'READY':
          return isDark ? Colors.blue[400]! : Colors.blue;
        case 'SOLD':
          return isDark ? Colors.green[400]! : Colors.green;
        case 'ARCHIVED':
          return Colors.grey;
        default:
          return Colors.grey;
      }
    }
  }

  @override
  String _getStatusText(String status, bool isClient) {
    if (isClient) {
      switch (status) {
        case 'PENDING_APPROVAL':
        case 'PENDING':
          return 'En Revisión';
        case 'READY':
          return 'Revisado / Aceptado';
        case 'SOLD':
          return 'Compra Confirmada';
        case 'DRAFT':
        case 'ARCHIVED':
          return 'Rechazado / Cancelado';
        default:
          return 'Desconocido';
      }
    } else {
      switch (status) {
        case 'PENDING_APPROVAL':
          return 'Nuevo Pedido Web';
        case 'PENDING':
          return 'Pendiente';
        case 'READY':
          return 'Listo para Vender';
        case 'SOLD':
          return 'Vendido';
        case 'ARCHIVED':
          return 'Archivado';
        default:
          return 'Borrador';
      }
    }
  }
}

class _QuoteHeaderDelegate extends SliverPersistentHeaderDelegate {
  final SmartQuotationModel? quotation;
  final String? fallbackClientName;
  final bool isDark;
  final Key? summaryKey;
  final double textScale;

  _QuoteHeaderDelegate({
    required this.quotation,
    this.fallbackClientName,
    required this.isDark,
    this.summaryKey,
    this.textScale = 1.0,
  });

  @override
  double get minExtent => 85.0 * textScale.clamp(1.0, 1.4);

  @override
  double get maxExtent {
    double baseHeight = 148.0 * textScale;
    if (quotation?.institutionName != null &&
        quotation!.institutionName!.isNotEmpty) {
      baseHeight += 52.0 * textScale;
    }
    if (quotation?.gradeLevel != null && quotation!.gradeLevel!.isNotEmpty) {
      baseHeight += 32.0 * textScale;
    }

    if (quotation?.notas != null && quotation!.notas!.isNotEmpty) {
      baseHeight += 68.0 * textScale;
    }

    return baseHeight < (155.0 * textScale) ? (155.0 * textScale) : baseHeight;
  }

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final double currentExtent = maxExtent - shrinkOffset;
    final double shrinkFactor = (shrinkOffset / (maxExtent - minExtent)).clamp(
      0.0,
      1.0,
    );

    return SizedBox(
      height: currentExtent.clamp(minExtent, maxExtent),
      child: ClipRect(
        child: OverflowBox(
          minHeight: minExtent,
          maxHeight: maxExtent,
          alignment: Alignment.topCenter,
          child: QuoteDetailHeader(
            quotation: quotation,
            fallbackClientName: fallbackClientName,
            isDark: isDark,
            shrinkFactor: shrinkFactor,
            summaryKey: summaryKey,
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _QuoteHeaderDelegate oldDelegate) {
    return quotation != oldDelegate.quotation ||
        fallbackClientName != oldDelegate.fallbackClientName ||
        isDark != oldDelegate.isDark ||
        summaryKey != oldDelegate.summaryKey ||
        textScale != oldDelegate.textScale;
  }
}
