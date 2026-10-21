import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/universal_image.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';

/// SliverAppBar para la pantalla de detalle de producto con visor de imagen,
/// animación Hero transparente (sin líneas amarillas) y barra de acciones
/// superiores (InfoTooltip, Historial de Auditoría y Editar Producto).
class ProductDetailSliverAppBar extends StatelessWidget {
  final String? displayImage;
  final String productName;
  final String categoryName;
  final String heroTag;
  final bool isDark;
  final VoidCallback onShowImage;
  final VoidCallback onAuditTrail;
  final VoidCallback onEdit;

  const ProductDetailSliverAppBar({
    super.key,
    required this.displayImage,
    required this.productName,
    required this.categoryName,
    required this.heroTag,
    required this.isDark,
    required this.onShowImage,
    required this.onAuditTrail,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 300.0,
      pinned: true,
      backgroundColor: isDark
          ? const Color(0xFF14141C)
          : Theme.of(context).primaryColor,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const InfoTooltipButton(
            iconColor: Colors.white70,
            title: 'Detalle de Producto',
            description:
                'Toda la información de tu producto en un solo lugar: precio de compra, precio de venta, stock, presentaciones disponibles y más.',
            tips: [
              InfoTip(
                icon: Icons.swap_horiz,
                text:
                    'Desliza las presentaciones para ver precio y stock de cada variante (unidad, pack, caja, etc).',
              ),
              InfoTip(
                icon: Icons.local_offer,
                text:
                    'Toca "Aplicar Descuento" para crear un descuento inteligente sobre este producto.',
              ),
              InfoTip(
                icon: Icons.history,
                text:
                    'El botón de reloj (⏰) abre el historial de cambios de precios y stock del producto.',
              ),
              InfoTip(
                icon: Icons.edit,
                text:
                    'El botón de lápiz te lleva a editar toda la información del producto.',
              ),
              InfoTip(
                icon: Icons.inventory_2,
                text:
                    'El stock se actualiza automáticamente al procesar facturas o realizar ventas.',
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.history,
              color: Colors.white,
              size: 24,
            ),
            onPressed: onAuditTrail,
            tooltip: "Auditoría de Producto",
          ),
        ),
        Container(
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.edit, color: Colors.white, size: 24),
            onPressed: onEdit,
            tooltip: "Editar Producto",
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: LayoutBuilder(
          builder: (context, constraints) {
            final settings = context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
            double opacity = 1.0;
            if (settings != null) {
              final delta = settings.maxExtent - settings.minExtent;
              if (delta > 0) {
                // collapseProgress va de 0.0 (totalmente expandido) a 1.0 (totalmente colapsado)
                final collapseProgress =
                    ((settings.maxExtent - settings.currentExtent) / delta).clamp(0.0, 1.0);
                // El avatar o foto se desvanece suavemente a partir de 30% de scroll
                // y alcanza opacidad 0.0 al 75% de colapso, evitando que se asomen
                // las puntas de iniciales o imágenes bajo los botones superiores.
                opacity = (1.0 - (collapseProgress - 0.3) / 0.45).clamp(0.0, 1.0);
              }
            }

            return ClipRect(
              child: Opacity(
                opacity: opacity,
                child: GestureDetector(
                  onTap: opacity > 0.1 ? onShowImage : null,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        color: isDark ? const Color(0xFF14141C) : Colors.white,
                        child: Hero(
                          tag: heroTag,
                          flightShuttleBuilder: (
                            flightContext,
                            animation,
                            flightDirection,
                            fromHeroContext,
                            toHeroContext,
                          ) {
                            return Material(
                              type: MaterialType.transparency,
                              child: toHeroContext.widget,
                            );
                          },
                          child: Material(
                            type: MaterialType.transparency,
                            child: UniversalImage(
                              path: displayImage,
                              productName: productName,
                              categoryName: categoryName,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black54,
                              Colors.transparent,
                              Colors.black45,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
