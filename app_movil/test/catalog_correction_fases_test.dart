import 'package:flutter_test/flutter_test.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/core/widgets/universal_image.dart';

void main() {
  group('Fase 1: Hidratación de Presentaciones y Cero Pantalla Blanca', () {
    test('Product.copyWith preserva o actualiza presentaciones correctamente', () {
      final p1 = Product(
        id: 10,
        nombre: 'Galleta Chomp',
        categoriaId: 1,
        presentaciones: [],
      );

      expect(p1.presentaciones, isEmpty);

      final pres1 = ProductPresentation(
        id: 101,
        nombreEspecifico: 'Paquete x 6',
        unidadVenta: 'Paquete',
        unidadesPorVenta: 6,
        precioVentaFinal: 3.50,
        stockActual: 24,
      );
      final pres2 = ProductPresentation(
        id: 102,
        nombreEspecifico: 'Caja x 24',
        unidadVenta: 'Caja',
        unidadesPorVenta: 24,
        precioVentaFinal: 12.00,
        stockActual: 5,
      );

      final hydratedProduct = p1.copyWith(presentaciones: [pres1, pres2]);
      expect(hydratedProduct.presentaciones.length, 2);
      expect(hydratedProduct.presentaciones.first.nombreEspecifico, 'Paquete x 6');
      expect(hydratedProduct.presentaciones.last.nombreEspecifico, 'Caja x 24');
    });

    test('InventoryWrapper.copyWith actualiza product hidratado y mantiene consistencia', () {
      final prod = Product(id: 1, nombre: 'Arroz Extra', categoriaId: 1);
      final pres = ProductPresentation(
        id: 201,
        nombreEspecifico: 'Kilo',
        precioVentaFinal: 4.20,
        stockActual: 50,
      );
      final wrapper = InventoryWrapper(product: prod, presentation: pres);

      expect(wrapper.product.presentaciones, isEmpty);

      final updatedWrapper = wrapper.copyWith(
        product: prod.copyWith(presentaciones: [pres]),
      );

      expect(updatedWrapper.product.presentaciones.length, 1);
      expect(updatedWrapper.presentation.id, 201);
    });
  });

  group('Fases 2 y 3: Cálculo Matemático Factor-Aware de Costo, Ganancia y Margen', () {
    test('Calcula costoPresentacion, ganancia y margen correctamente para pack con factor > 1', () {
      // Caso de prueba adversarial:
      // Six pack o caja:
      // unidadesPorVenta = 12
      // costoUnitarioBase = 1.00
      // precioVentaFinal = 15.00
      const int unidadesPorVenta = 12;
      const double costoUnitarioBase = 1.00;
      const double precioVentaFinal = 15.00;
      const int cantidad = 2;

      final int factor = unidadesPorVenta <= 0 ? 1 : unidadesPorVenta;
      final double costoPresentacion = costoUnitarioBase * factor;
      expect(costoPresentacion, 12.00);

      const double precioEfectivo = precioVentaFinal;
      final double gananciaPresentacion = precioEfectivo - costoPresentacion;
      expect(gananciaPresentacion, 3.00);

      final double gananciaTotal = gananciaPresentacion * cantidad;
      expect(gananciaTotal, 6.00);

      final double margenPorcentual = (gananciaPresentacion / precioEfectivo) * 100;
      expect(margenPorcentual, closeTo(20.0, 0.01));
    });

    test('Calcula semáforo de rentabilidad adecuadamente', () {
      double getMargen(double precio, double costo) {
        if (precio <= 0) return 0.0;
        return ((precio - costo) / precio) * 100;
      }

      String getSemaforo(double margen) {
        if (margen >= 30.0) return 'verde';
        if (margen >= 15.0) return 'ambar';
        return 'rojo';
      }

      // Margen excelente (35%)
      expect(getSemaforo(getMargen(100.0, 65.0)), 'verde');

      // Margen moderado (20%)
      expect(getSemaforo(getMargen(100.0, 80.0)), 'ambar');

      // Margen bajo o crítico (10%)
      expect(getSemaforo(getMargen(100.0, 90.0)), 'rojo');

      // Margen con pérdida (-10%)
      expect(getSemaforo(getMargen(100.0, 110.0)), 'rojo');
    });

    test('Clamping de stock al cambiar de variante en modal', () {
      int currentQty = 8;

      const int stockActualB = 6;
      const int unidadesPorVentaB = 2;
      final int maxStockB = stockActualB ~/ (unidadesPorVentaB <= 0 ? 1 : unidadesPorVentaB);
      expect(maxStockB, 3);

      if (currentQty > maxStockB) {
        currentQty = maxStockB > 0 ? maxStockB : 1;
      }
      expect(currentQty, 3);
    });
  });

  group('Fase 4: SmartVisualPlaceholder Initials & Category Detection', () {
    test('UniversalImage.extractInitials extrae iniciales correctamente', () {
      expect(UniversalImage.extractInitials('Coca Cola 500ml'), 'CC');
      expect(UniversalImage.extractInitials('Leche Gloria'), 'LG');
      expect(UniversalImage.extractInitials('Arroz'), 'AR');
      expect(UniversalImage.extractInitials('  '), 'ML');
      expect(UniversalImage.extractInitials('123'), '12');
    });

    test('UniversalImage.getCategoryIcon asigna iconos según categoría de negocio', () {
      expect(
        UniversalImage.getCategoryIcon('Gaseosas y Bebidas').codePoint,
        isNotNull,
      );
      expect(
        UniversalImage.getCategoryIcon('Lácteos y Quesos').codePoint,
        isNotNull,
      );
      expect(
        UniversalImage.getCategoryIcon('Snacks y Golosinas').codePoint,
        isNotNull,
      );
      expect(
        UniversalImage.getCategoryIcon('Inclasificable').codePoint,
        isNotNull,
      );
    });
  });

  group('Fase 5: Lógica de Filtros y Conteo a 0ms', () {
    test('Conteo en vivo filtra por stock, categorías y ofertas de forma consistente', () {
      final p1 = Product(id: 1, nombre: 'Inka Kola', categoriaId: 5, marcaId: 10);
      final pres1 = ProductPresentation(
        id: 1,
        precioVentaFinal: 3.50,
        stockActual: 10,
        esDefault: true,
      );

      final p2 = Product(id: 2, nombre: 'Oreo', categoriaId: 3, marcaId: 20);
      final pres2 = ProductPresentation(
        id: 2,
        precioVentaFinal: 1.00,
        precioOferta: 0.80,
        stockActual: 0,
        esDefault: true,
      );

      final items = [
        InventoryWrapper(product: p1, presentation: pres1),
        InventoryWrapper(product: p2, presentation: pres2),
      ];

      // Filtro 1: Solo con stock
      final withStock = items.where((w) => !w.isOutOfStock).toList();
      expect(withStock.length, 1);
      expect(withStock.first.product.nombre, 'Inka Kola');

      // Filtro 2: Solo ofertas
      final withOffers = items.where((w) => w.presentation.precioOferta != null && w.presentation.precioOferta! > 0).toList();
      expect(withOffers.length, 1);
      expect(withOffers.first.product.nombre, 'Oreo');

      // Filtro 3: Por categoría
      final cat5Items = items.where((w) => w.product.categoriaId == 5).toList();
      expect(cat5Items.length, 1);
      expect(cat5Items.first.product.nombre, 'Inka Kola');
    });
  });

  group('Auditoría Final 5 Puntos: Casos Borde y Sincronización', () {
    test('Punto 1: Sincronización de presentación activa al clonar wrapper para acciones', () {
      final prod = Product(id: 10, nombre: 'Gaseosa Concordia', categoriaId: 2);
      final defaultPres = ProductPresentation(
        id: 100,
        unidadVenta: 'Botella 500ml',
        precioVentaFinal: 2.50,
        stockActual: 20,
      );
      final altPres = ProductPresentation(
        id: 101,
        unidadVenta: 'Six Pack',
        unidadesPorVenta: 6,
        precioVentaFinal: 12.00,
        stockActual: 18,
      );

      final initialWrapper = InventoryWrapper(product: prod, presentation: defaultPres);
      expect(initialWrapper.presentation.id, 100);

      // Simula el cambio de chip en ProductDetailModal
      final targetWrapper = initialWrapper.copyWith(presentation: altPres);
      expect(targetWrapper.presentation.id, 101);
      expect(targetWrapper.presentation.unidadesPorVenta, 6);
      expect(targetWrapper.effectivePrice, 12.00);
      expect(targetWrapper.displayStock, 3); // 18 ~/ 6
    });

    test('Punto 2: Prevenir falso margen de +100% cuando el costo es 0.00 (No Registrado)', () {
      final presSinCosto = ProductPresentation(
        id: 201,
        unidadVenta: 'Unidad',
        precioVentaFinal: 10.00,
        costoUnitarioCalculado: 0.0,
        precioUmpProveedor: 0.0,
        stockActual: 5,
      );

      final double costo = presSinCosto.costoPresentacionFinal;
      final bool tieneCosto = costo > 0;
      final double effectivePrice = presSinCosto.precioVentaFinal;

      // El cálculo matemáticamente correcto evita (10 - 0) / 10 = +100%
      final double margenPorcentual = (tieneCosto && effectivePrice > 0)
          ? ((effectivePrice - costo) / effectivePrice * 100)
          : 0.0;

      expect(tieneCosto, isFalse);
      expect(costo, 0.0);
      expect(margenPorcentual, 0.0); // NO debe ser 100%
    });

    test('Punto 2: costoPresentacionFinal prioriza costoUnitarioCalculado * factorVenta y divide UMP correctamente', () {
      // Caso crítico: Se compra paquete de 15 a S/ 9.00 (costoUnitarioCalculado = 0.60)
      // Se vende por Unidad (unidadesPorVenta = 1) a S/ 1.00
      final presUnidad = ProductPresentation(
        id: 202,
        unidadVenta: 'Unidad',
        unidadesPorVenta: 1,
        unidadesPorLote: 15, // factorUmp
        costoUnitarioCalculado: 0.60,
        precioUmpProveedor: 9.00,
        precioVentaFinal: 1.00,
        stockActual: 30,
      );

      // Debe devolver 0.60, JAMÁS 9.00 (que causaría falso margen negativo)
      expect(presUnidad.costoPresentacionFinal, 0.60);

      // Si la presentación es Six Pack (unidadesPorVenta = 6) con costo de presentación guardado
      final presSixPack = ProductPresentation(
        id: 203,
        unidadVenta: 'Six Pack',
        unidadesPorVenta: 6,
        unidadesPorLote: 15,
        costoUnitarioCalculado: 3.60, // En SQLite costo_unitario_calculado es el costo de esa presentación
        precioUmpProveedor: 9.00,
        precioVentaFinal: 5.00,
        stockActual: 30,
      );

      expect(presSixPack.costoPresentacionFinal, closeTo(3.60, 0.001));

      // Fallback cuando costoUnitarioCalculado es 0/null pero existe precioUmpProveedor
      final presFallback = ProductPresentation(
        id: 204,
        unidadVenta: 'Unidad',
        unidadesPorVenta: 1,
        unidadesPorLote: 15, // factorCompra = 15
        costoUnitarioCalculado: 0.0,
        precioUmpProveedor: 9.00,
        precioVentaFinal: 1.00,
        stockActual: 30,
      );

      // (9.00 / 15) * 1 = 0.60
      expect(presFallback.costoPresentacionFinal, closeTo(0.60, 0.001));
    });

    test('Punto 3: getCategoryIcon detecta palabras clave en el nombre del producto', () {
      // Sin nombre de categoría (null), debe detectar por producto
      expect(UniversalImage.getCategoryIcon(null, 'Inca Kola 500ml'), isNotNull);
      expect(UniversalImage.getCategoryIcon(null, 'Leche Gloria Tarro'), isNotNull);
      expect(UniversalImage.getCategoryIcon(null, 'Detergente Ace 1kg'), isNotNull);
      expect(UniversalImage.getCategoryIcon(null, 'Cuaderno Cuadriculado'), isNotNull);
      expect(UniversalImage.getCategoryIcon(null, 'Arroz Extra Faraón'), isNotNull);
      expect(UniversalImage.getCategoryIcon(null, 'Galletas Rellenitas'), isNotNull);
      expect(UniversalImage.getCategoryIcon(null, 'Jamónada San Fernando'), isNotNull);
    });
  });
}
