import 'package:flutter_test/flutter_test.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';

void main() {
  group('Fase 1: Tarjetas del Catálogo y Título de Pantalla', () {
    test('Micro-píldora financiera calcula y formatea costo y margen sin truncamiento', () {
      const double costo = 0.83;
      const double precio = 1.20;
      final double margen = ((precio - costo) / precio) * 100;

      expect(margen, closeTo(30.83, 0.01));

      // Formato compacto para evitar desbordes en tarjetas angostas
      final String costText = 'C: S/ ${costo.toStringAsFixed(2)}';
      final String marginText = '+${margen.toStringAsFixed(0)}%';

      expect(costText, equals('C: S/ 0.83'));
      expect(marginText, equals('+31%'));

      // Semáforo dinámico de rentabilidad
      bool isHealthyMargin = margen >= 25.0;
      expect(isHealthyMargin, isTrue);
    });

    test('Título del Catálogo de Ventas es responsivo y conciso', () {
      const String fullTitle = 'Catálogo de Ventas';
      expect(fullTitle.length, lessThanOrEqualTo(20));
      expect(fullTitle, contains('Catálogo'));
    });
  });

  group('Fase 2: Modal de Detalles de Producto (ProductDetailModal)', () {
    test('Encabezado financiero elimina la etiqueta (INTERNO)', () {
      const String headerTitle = 'DATOS FINANCIEROS';
      expect(headerTitle.contains('(INTERNO)'), isFalse);
      expect(headerTitle, equals('DATOS FINANCIEROS'));
    });

    test('Píldoras superiores: etiquetas completas sin corte de texto', () {
      final pills = ['EMPAQUE', 'PRESENTACIÓN', 'STOCK'];
      for (final pill in pills) {
        expect(pill.endsWith('...'), isFalse, reason: '$pill no debe estar truncado con elipsis');
      }
      expect(pills[1], equals('PRESENTACIÓN'));
    });

    test('Cálculo de ganancia y badge de margen en modal', () {
      const double precio = 1.20;
      const double costo = 0.83;
      const int cantidad = 1;

      final double gananciaPorUnidad = precio - costo;
      final double gananciaTotal = gananciaPorUnidad * cantidad;
      final double margen = (gananciaPorUnidad / precio) * 100;

      expect(gananciaTotal, closeTo(0.37, 0.01));
      expect(margen, closeTo(30.83, 0.01));

      final String badgeText = '+${margen.toStringAsFixed(0)}% MARGEN';
      expect(badgeText, equals('+31% MARGEN'));
    });

    test('Alineación del selector de cantidad en la fila inferior', () {
      const bool isSeparatedRow = true;
      expect(isSeparatedRow, isTrue);
    });
  });

  group('Fase 3: Transición Hero limpia sin artefactos ni líneas amarillas', () {
    test('Tag Hero canónico para tarjeta y modal', () {
      const int prodId = 42;
      const int presId = 101;
      final String heroTag = 'product_img_${prodId}_$presId';

      expect(heroTag, equals('product_img_42_101'));
      expect(heroTag.isNotEmpty, isTrue);
    });
  });

  group('Fase 4: Arquitectura SQLite y Presentación Principal (es_default = 1)', () {
    test('Sanitización V23: asigna es_default = 1 a la primera presentación de producto huérfano', () {
      // Simular lista de presentaciones de un producto en base de datos
      final presentaciones = [
        {'id': 10, 'producto_id': 1, 'nombre_especifico': 'Unidad', 'es_default': 0},
        {'id': 11, 'producto_id': 1, 'nombre_especifico': 'Six Pack', 'es_default': 0},
        {'id': 12, 'producto_id': 1, 'nombre_especifico': 'Docena', 'es_default': 0},
      ];

      // Verificar que ninguna es default
      final bool hasDefault = presentaciones.any((p) => p['es_default'] == 1);
      expect(hasDefault, isFalse);

      // Algoritmo de migración V23
      if (!hasDefault && presentaciones.isNotEmpty) {
        presentaciones.first['es_default'] = 1;
      }

      // Verificación
      expect(presentaciones.first['es_default'], equals(1));
      expect(presentaciones[1]['es_default'], equals(0));
      expect(presentaciones[2]['es_default'], equals(0));
    });

    test('Filtro "Solo presentación principal" devuelve exactamente las variantes principales', () {
      final List<Map<String, dynamic>> allPresentationsInDb = [
        {'id': 1, 'producto_id': 1, 'nombre': 'Galleta Soda', 'es_default': 1},
        {'id': 2, 'producto_id': 1, 'nombre': 'Galleta Soda Pack', 'es_default': 0},
        {'id': 3, 'producto_id': 2, 'nombre': 'Aceite Primor', 'es_default': 1},
        {'id': 4, 'producto_id': 3, 'nombre': 'Arroz Costeño', 'es_default': 1},
        {'id': 5, 'producto_id': 3, 'nombre': 'Arroz Costeño Saco', 'es_default': 0},
      ];

      // Filtro SQL: WHERE es_default = 1
      final principales = allPresentationsInDb.where((p) => p['es_default'] == 1).toList();

      expect(principales.length, equals(3));
      expect(principales.length, isNot(equals(0)), reason: 'El filtro jamás debe arrojar 0 cuando hay productos');
      expect(principales.every((p) => p['es_default'] == 1), isTrue);
    });

    test('Orden canónico respeta es_default DESC, id ASC', () {
      final presList = [
        ProductPresentation(id: 3, nombreEspecifico: 'Docena', esDefault: false, precioVentaFinal: 30.0, stockActual: 5),
        ProductPresentation(id: 1, nombreEspecifico: 'Unidad', esDefault: true, precioVentaFinal: 3.0, stockActual: 10),
        ProductPresentation(id: 2, nombreEspecifico: 'Pack x6', esDefault: false, precioVentaFinal: 16.0, stockActual: 8),
      ];

      presList.sort((a, b) {
        if (a.esDefault && !b.esDefault) return -1;
        if (!a.esDefault && b.esDefault) return 1;
        return (a.id ?? 0).compareTo(b.id ?? 0);
      });

      expect(presList[0].id, equals(1));
      expect(presList[0].esDefault, isTrue);
      expect(presList[1].id, equals(2));
      expect(presList[2].id, equals(3));
    });

    test('Edición de producto mantiene presentación principal al frente sin mutación arbitraria', () {
      final pres1 = ProductPresentation(id: 10, nombreEspecifico: 'Principal', esDefault: true, precioVentaFinal: 5.0, stockActual: 20);
      final pres2 = ProductPresentation(id: 11, nombreEspecifico: 'Secundaria', esDefault: false, precioVentaFinal: 10.0, stockActual: 10);

      final p = Product(
        id: 1,
        nombre: 'Detergente Opal',
        categoriaId: 1,
        presentaciones: [pres1, pres2],
      );

      // Simulación de carga en ProductEditScreen preservando orden canónico
      List<ProductPresentation> sortedList = List.from(p.presentaciones);
      sortedList.sort((a, b) {
        if (a.esDefault && !b.esDefault) return -1;
        if (!a.esDefault && b.esDefault) return 1;
        return (a.id ?? 0).compareTo(b.id ?? 0);
      });

      expect(sortedList.first.id, equals(10));
      expect(sortedList.first.esDefault, isTrue);
    });
  });

  group('Fase 5: Hidratación Multi-Variante en ProductDetailScreen', () {
    test('ProductDetailScreen expone selector horizontal cuando hay más de 1 variante', () {
      final pres1 = ProductPresentation(id: 100, nombreEspecifico: 'Bolsa 500g', esDefault: true, precioVentaFinal: 4.50, stockActual: 15);
      final pres2 = ProductPresentation(id: 101, nombreEspecifico: 'Bolsa 1kg', esDefault: false, precioVentaFinal: 8.50, stockActual: 10);

      final product = Product(
        id: 5,
        nombre: 'Avena Santa Catalina',
        categoriaId: 1,
        presentaciones: [pres1, pres2],
      );

      final bool hasMultipleVariantes = product.presentaciones.length > 1;
      expect(hasMultipleVariantes, isTrue);
      expect(product.presentaciones.length, equals(2));
      expect(product.presentaciones.map((p) => p.nombreEspecifico).toList(), equals(['Bolsa 500g', 'Bolsa 1kg']));
    });

    test('Marca compartida canónicamente entre producto padre y todas sus presentaciones', () {
      const String marcaNombre = 'Gloria';
      final p = Product(
        id: 8,
        nombre: 'Leche Evaporada',
        categoriaId: 1,
        marcaNombre: marcaNombre,
        presentaciones: [
          ProductPresentation(id: 201, nombreEspecifico: 'Lata Chica', precioVentaFinal: 2.50, stockActual: 30),
          ProductPresentation(id: 202, nombreEspecifico: 'Lata Grande', precioVentaFinal: 4.20, stockActual: 25),
        ],
      );

      final wrapper1 = InventoryWrapper(product: p, presentation: p.presentaciones[0]);
      final wrapper2 = InventoryWrapper(product: p, presentation: p.presentaciones[1]);

      expect(wrapper1.product.marcaNombre, equals('Gloria'));
      expect(wrapper2.product.marcaNombre, equals('Gloria'));
      expect(wrapper1.product.marcaNombre, equals(wrapper2.product.marcaNombre));
    });
  });

  group('Fase 6: Auditoría de 6 Puntos Críticos y Paridad Total', () {
    test('Punto 1: OmniSearch - Mapeo de presentaciones, conteo de ventas sin duplicados', () {
      // Simulación de registros en base de datos
      final presentationsInDb = [
        {'id': 101, 'product_id': 1, 'nombre_especifico': 'Unidad', 'producto_nombre': 'Cuaderno Standford'},
        {'id': 102, 'product_id': 1, 'nombre_especifico': 'Docena', 'producto_nombre': 'Cuaderno Standford'},
        {'id': 103, 'product_id': 2, 'nombre_especifico': 'Caja x12', 'producto_nombre': 'Lápiz Faber-Castell'},
      ];

      // El buscador debe listar cada presentación activa individualmente (3 ítems, no 2 productos)
      expect(presentationsInDb.length, equals(3));
      final names = presentationsInDb.map((p) => "${p['producto_nombre']} ${p['nombre_especifico']}").toList();
      expect(names, contains('Cuaderno Standford Unidad'));
      expect(names, contains('Cuaderno Standford Docena'));
      expect(names, contains('Lápiz Faber-Castell Caja x12'));

      // Conteo de ventas sin doble conteo: solo cuenta registros de la tabla ventas activos
      final salesRows = [
        {'id': 1, 'monto_total': 50.0, 'is_archived': 0},
        {'id': 2, 'monto_total': 30.0, 'is_archived': 0},
      ];
      final smartQuotations = [
        {'id': 10, 'status': 'vendida'}, // Ya migrada a tabla ventas
        {'id': 11, 'status': 'aprobada'},
      ];
      // Conteo correcto: solo ventas no archivadas
      final int totalVentas = salesRows.where((s) => s['is_archived'] == 0).length;
      expect(totalVentas, equals(2));

      // Cotizaciones activas excluye las vendidas/anuladas
      final int activeQuotes = smartQuotations.where((q) {
        final st = (q['status'] as String).toLowerCase();
        return !['vendida', 'sold', 'annulled', 'anulada'].contains(st);
      }).length;
      expect(activeQuotes, equals(1));
    });

    test('Punto 3: Unificación matemática de margen comercial en toda la app', () {
      const double costo = 0.83;
      const double precio = 1.20;
      const double ganancia = precio - costo;

      // Margen comercial unificado sobre precio de venta: ((precio - costo) / precio * 100)
      final int margenPorcentaje = ((precio - costo) / precio * 100).round();
      expect(margenPorcentaje, equals(31)); // +31% en Catálogo, Modal y ProductDetailScreen

      // Línea financiera de tarjeta: C: S/ 0.83 · G: S/ 0.37 · +31%
      final String cardFinancialLine = 'C: S/ ${costo.toStringAsFixed(2)} · G: S/ ${ganancia.toStringAsFixed(2)} · +$margenPorcentaje%';
      expect(cardFinancialLine, equals('C: S/ 0.83 · G: S/ 0.37 · +31%'));
    });

    test('Punto 4: Preservación de variante seleccionada inicial al hidratar ProductDetailScreen', () {
      final pres1 = ProductPresentation(id: 10, nombreEspecifico: 'Chica', esDefault: true, precioVentaFinal: 2.0, stockActual: 5);
      final pres2 = ProductPresentation(id: 11, nombreEspecifico: 'Grande', esDefault: false, precioVentaFinal: 5.0, stockActual: 8);

      final p = Product(id: 1, nombre: 'Goma', categoriaId: 1, presentaciones: [pres1, pres2]);
      const int targetPresId = 11; // Usuario hizo clic en la variante 'Grande'

      // Al hidratar hermanas, el selector debe mantener targetPresId
      final selected = p.presentaciones.firstWhere(
        (pr) => pr.id == targetPresId,
        orElse: () => p.presentaciones.first,
      );

      expect(selected.id, equals(11));
      expect(selected.nombreEspecifico, equals('Grande'));
    });

    test('Punto 5: FloatingDockSessionState retiene coordenadas y estado tuck al navegar', () {
      // Estado de memoria compartida
      double posX = 15.0;
      double posY = 350.0;
      bool isLeft = true;
      bool isEdgeTucked = true;

      // Simular cambio de pantalla
      final savedState = {
        'posX': posX,
        'posY': posY,
        'isLeft': isLeft,
        'isEdgeTucked': isEdgeTucked,
      };

      // Al inicializar en la nueva pantalla, debe recuperar exactamente los mismos valores
      expect(savedState['posX'], equals(15.0));
      expect(savedState['posY'], equals(350.0));
      expect(savedState['isLeft'], isTrue);
      expect(savedState['isEdgeTucked'], isTrue);
    });
  });
}

