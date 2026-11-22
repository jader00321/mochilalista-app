import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';

/// Contenedor de claves de instancia para la Pantalla de Creación/Edición de Producto
class ProductCreateTourKeys {
  final GlobalKey backButtonKey;
  final GlobalKey generalInfoKey;
  final GlobalKey barcodeKey;
  final GlobalKey stockStrategyKey;
  final GlobalKey variantsHeaderKey;
  final GlobalKey saveButtonKey;

  ProductCreateTourKeys({
    GlobalKey? backButtonKey,
    GlobalKey? generalInfoKey,
    GlobalKey? barcodeKey,
    GlobalKey? stockStrategyKey,
    GlobalKey? variantsHeaderKey,
    GlobalKey? saveButtonKey,
  })  : backButtonKey = backButtonKey ?? GlobalKey(debugLabel: 'prod_tour_back'),
        generalInfoKey = generalInfoKey ?? GlobalKey(debugLabel: 'prod_tour_general_info'),
        barcodeKey = barcodeKey ?? GlobalKey(debugLabel: 'prod_tour_barcode'),
        stockStrategyKey = stockStrategyKey ?? GlobalKey(debugLabel: 'prod_tour_stock_strategy'),
        variantsHeaderKey = variantsHeaderKey ?? GlobalKey(debugLabel: 'prod_tour_variants_header'),
        saveButtonKey = saveButtonKey ?? GlobalKey(debugLabel: 'prod_tour_save_btn');
}

/// Configuración de la Guía Turística para ProductCreateScreen
class ProductCreateTour {
  static final ProductCreateTourKeys defaultKeys = ProductCreateTourKeys();

  static ScreenTourConfig buildConfig({
    ProductCreateTourKeys? keys,
    Future<void> Function()? onExpandBarcodeSection,
    Future<void> Function()? onCollapseBarcodeSection,
    Future<void> Function()? onExpandSection,
    Future<void> Function()? onCollapseSection,
  }) {
    final k = keys ?? defaultKeys;

    return ScreenTourConfig(
      screenId: 'product_create_screen',
      screenTitle: 'Creación de Producto',
      welcomeSummary:
          'Aprende a registrar productos comerciales con múltiples presentaciones, cálculo automático de márgenes y protección de borradores.',
      icon: Icons.inventory_2_rounded,
      steps: [
        TourStep(
          id: 'step_general_info',
          targetKey: k.generalInfoKey,
          title: 'Datos Principales del Producto',
          description:
              'Ingresa el nombre comercial, categoría y marca para que tus productos aparezcan ordenados y sean fáciles de encontrar en ventas y cotizaciones.',
          tip: 'Usa los selectores inteligentes para no tener que escribir categorías y marcas repetidas.',
          icon: Icons.edit_note_rounded,
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'step_barcode',
          targetKey: k.barcodeKey,
          title: 'Código de Barras Global',
          description:
              'Asigna un código de barras manual o activa el escaneo con la cámara para agilizar la búsqueda en caja con un solo toque.',
          tip: 'Cada presentación individual también puede tener su propio código de barras.',
          icon: Icons.qr_code_scanner_rounded,
          borderRadius: 14.0,
          onBeforeStep: onExpandBarcodeSection,
          onAfterStep: onCollapseBarcodeSection,
        ),
        TourStep(
          id: 'step_stock_strategy',
          targetKey: k.stockStrategyKey,
          title: 'Estrategia de Stock y Precios',
          description:
              'Elige entre Stock Independiente (cada presentación tiene su propio inventario) o Stock Compartido (se descuenta del mismo lote común).',
          tip: 'Usa los chips de redondeo rápido (.50, .90, .00) para fijar precios atractivos en mostrador.',
          icon: Icons.price_change_outlined,
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'step_variants_advanced',
          targetKey: k.variantsHeaderKey,
          title: 'Presentaciones y Opciones Avanzadas',
          description:
              'Crea presentaciones por Unidad, Paquete, Docena o Caja. El sistema calcula automáticamente el costo proporcional y el margen de ganancia.',
          tip: 'Puedes clonar presentaciones existentes para no tener que rellenar los datos de nuevo.',
          icon: Icons.layers_outlined,
          borderRadius: 14.0,
          onBeforeStep: onExpandSection,
          onAfterStep: onCollapseSection,
        ),
        TourStep(
          id: 'step_back_rule',
          targetKey: k.backButtonKey,
          title: 'Regla de Oro: Botón Atrás vs. Cierre',
          description:
              'Presionar el botón Atrás NO borra tu avance: tus datos se conservan en un borrador temporal en memoria para que no pierdas nada al navegar. Sin embargo, cerrar completamente la aplicación desde las apps recientes sí descartará los cambios sin guardar.',
          tip: 'La etiqueta "Borrador" en la barra superior te indica cuándo hay datos temporales protegidos.',
          icon: Icons.arrow_back_rounded,
          borderRadius: 24.0,
        ),
        TourStep(
          id: 'step_save_button',
          targetKey: k.saveButtonKey,
          title: 'Guardar Producto',
          description:
              'Presiona Guardar para registrar el producto en la base de datos de tu negocio y dejarlo disponible inmediatamente para vender.',
          icon: Icons.save_rounded,
          borderRadius: 16.0,
        ),
      ],
    );
  }
}
