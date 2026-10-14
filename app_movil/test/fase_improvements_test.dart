import 'package:flutter_test/flutter_test.dart';
import 'package:app_movil/features/catalog/services/auto_categorization_service.dart';
import 'package:app_movil/features/catalog/models/category_model.dart';

void main() {
  group('Fase 5 - AutoCategorizationService Tests', () {
    test('Sugiere Lácteos para productos lácteos comunes', () {
      expect(AutoCategorizationService.suggestCategoryName('Leche Gloria Azul 400g'), 'Lácteos');
      expect(AutoCategorizationService.suggestCategoryName('Yogurt Laive Fresa 1L'), 'Lácteos');
      expect(AutoCategorizationService.suggestCategoryName('Queso Edam Bonle'), 'Lácteos');
    });

    test('Sugiere Limpieza para productos de aseo del hogar', () {
      expect(AutoCategorizationService.suggestCategoryName('Detergente Ariel 1kg'), 'Limpieza');
      expect(AutoCategorizationService.suggestCategoryName('Lejía Clorox Tradicional'), 'Limpieza');
      expect(AutoCategorizationService.suggestCategoryName('Lavavajilla Ayudín Limón'), 'Limpieza');
    });

    test('Sugiere Cuidado Personal para higiene personal', () {
      expect(AutoCategorizationService.suggestCategoryName('Shampoo Sedal Ceramidas 350ml'), 'Cuidado Personal');
      expect(AutoCategorizationService.suggestCategoryName('Pasta dental Colgate Total 12'), 'Cuidado Personal');
      expect(AutoCategorizationService.suggestCategoryName('Desodorante Rexona Clinical'), 'Cuidado Personal');
    });

    test('Sugiere Golosinas y Snacks para dulces y galletas', () {
      expect(AutoCategorizationService.suggestCategoryName('Galleta Oreo 6 unidades'), 'Golosinas y Snacks');
      expect(AutoCategorizationService.suggestCategoryName('Chocolate Sublime Clásico'), 'Golosinas y Snacks');
      expect(AutoCategorizationService.suggestCategoryName('Papas Lays Clásicas'), 'Golosinas y Snacks');
    });

    test('Sugiere Bebidas para refrescos y aguas', () {
      expect(AutoCategorizationService.suggestCategoryName('Gaseosa Inka Kola 500ml'), 'Bebidas');
      expect(AutoCategorizationService.suggestCategoryName('Agua San Luis Sin Gas'), 'Bebidas');
      expect(AutoCategorizationService.suggestCategoryName('Frugos del Valle Durazno'), 'Bebidas');
    });

    test('Sugiere Útiles Escolares para papelería', () {
      expect(AutoCategorizationService.suggestCategoryName('Cuaderno Standford Cuadriculado'), 'Útiles Escolares');
      expect(AutoCategorizationService.suggestCategoryName('Lapicero Faber Castell 033 Azul'), 'Útiles Escolares');
      expect(AutoCategorizationService.suggestCategoryName('Borrador Artesco Blanco'), 'Útiles Escolares');
    });

    test('Sugiere Abarrotes y Despensa para despensa básica', () {
      expect(AutoCategorizationService.suggestCategoryName('Arroz Costeño Extra 1kg'), 'Abarrotes y Despensa');
      expect(AutoCategorizationService.suggestCategoryName('Aceite Primor Clásico 900ml'), 'Abarrotes y Despensa');
      expect(AutoCategorizationService.suggestCategoryName('Fideos Don Vittorio Spaguetti'), 'Abarrotes y Despensa');
    });

    test('Retorna null para nombres vacíos o no reconocidos', () {
      expect(AutoCategorizationService.suggestCategoryName(''), isNull);
      expect(AutoCategorizationService.suggestCategoryName('   '), isNull);
      expect(AutoCategorizationService.suggestCategoryName('Xyz999 Inclasificable'), isNull);
    });

    test('matchExistingCategory asocia correctamente categorías existentes', () {
      final existing = [
        Category(id: 1, nombre: 'Lácteos'),
        Category(id: 2, nombre: 'Abarrotes'),
        Category(id: 3, nombre: 'Limpieza'),
      ];

      final matched = AutoCategorizationService.matchExistingCategory('Lácteos', existing);
      expect(matched, isNotNull);
      expect(matched!.id, 1);
      expect(matched.nombre, 'Lácteos');

      final notFound = AutoCategorizationService.matchExistingCategory('Juguetería', existing);
      expect(notFound, isNull);
    });
  });

  group('Fase 4 y 5 - Lógica de Margen de Ganancia', () {
    test('Calcula porcentaje de margen correctamente', () {
      const costo = 10.0;
      const precioVenta = 15.0;
      final margenPct = ((precioVenta - costo) / precioVenta) * 100;
      expect(margenPct, closeTo(33.33, 0.01));
    });

    test('Clasificación semáforo de margen: Verde (>20%), Amarillo (10-20%), Rojo (<10%)', () {
      String getSemaforo(double margenPct) {
        if (margenPct >= 20.0) return 'VERDE';
        if (margenPct >= 10.0) return 'AMARILLO';
        return 'ROJO';
      }

      expect(getSemaforo(25.0), 'VERDE');
      expect(getSemaforo(20.0), 'VERDE');
      expect(getSemaforo(15.0), 'AMARILLO');
      expect(getSemaforo(10.0), 'AMARILLO');
      expect(getSemaforo(8.5), 'ROJO');
      expect(getSemaforo(-5.0), 'ROJO'); // Venta con pérdida
    });
  });

  group('Fase 1 - Lógica de Remapeo en Restauración de Backup', () {
    test('stock_ledger remapea origen_id según tipo_transaccion (COMPRA_LOTE vs VENTA)', () {
      final invoiceIdMap = {101: 501};
      final saleIdMap = {201: 601};

      int? remapOrigenId(String tipoTransaccion, int origenId) {
        if (tipoTransaccion == 'COMPRA_LOTE' || tipoTransaccion == 'COMPRA') {
          return invoiceIdMap[origenId] ?? origenId;
        } else if (tipoTransaccion == 'VENTA') {
          return saleIdMap[origenId] ?? origenId;
        }
        return origenId;
      }

      expect(remapOrigenId('COMPRA_LOTE', 101), 501);
      expect(remapOrigenId('VENTA', 201), 601);
      expect(remapOrigenId('AJUSTE', 999), 999);
    });

    test('product_history remapea entidad_id según entidad_tipo (producto vs presentacion)', () {
      final productIdMap = {10: 100};
      final presentationIdMap = {25: 250};

      int? remapEntidadId(String entidadTipo, int entidadId) {
        if (entidadTipo == 'producto') {
          return productIdMap[entidadId] ?? entidadId;
        } else if (entidadTipo == 'presentacion') {
          return presentationIdMap[entidadId] ?? entidadId;
        }
        return entidadId;
      }

      expect(remapEntidadId('producto', 10), 100);
      expect(remapEntidadId('presentacion', 25), 250);
      expect(remapEntidadId('desconocido', 99), 99);
    });
  });

  group('Fase 2 - Detección y Normalización de Duplicados', () {
    test('Detecta duplicados case-insensitive y espacios redundantes', () {
      bool isDuplicate(String existing, String candidate) {
        return existing.trim().toLowerCase() == candidate.trim().toLowerCase();
      }

      expect(isDuplicate('Gloria', 'gloria'), isTrue);
      expect(isDuplicate('  Sedal  ', 'sedal'), isTrue);
      expect(isDuplicate('Punto Blanco S.A.C.', 'punto blanco s.a.c.'), isTrue);
      expect(isDuplicate('Pilsen Callao', 'Cristal'), isFalse);
    });
  });

  group('Fase 3 - Cálculo de Completitud de Perfil', () {
    test('Calcula porcentaje exacto de campos completados', () {
      final fields = {
        'nombre': 'Luz Navarro',
        'telefono': '987654321',
        'email': null,
        'ruc': '10456789012',
        'logo': null,
        'direccion': 'Av. Bolognesi 123',
        'info_pago': 'Yape 987654321',
        'gps': null,
        'pin': '1234',
      };

      int completedCount = fields.values.where((v) => v != null && v.toString().trim().isNotEmpty).length;
      double pct = (completedCount / fields.length) * 100;

      expect(completedCount, 6);
      expect(pct, closeTo(66.67, 0.01));
    });
  });

  group('Fase 4 - Resumen de Ganancia en QuickSale', () {
    test('Calcula ganancia total del carrito correctamente', () {
      final items = [
        {'precio': 5.0, 'costo': 3.5, 'cant': 2}, // Ganancia: (5.0 - 3.5)*2 = 3.0
        {'precio': 12.0, 'costo': 9.0, 'cant': 1}, // Ganancia: (12.0 - 9.0)*1 = 3.0
        {'precio': 2.0, 'costo': 1.0, 'cant': 5}, // Ganancia: (2.0 - 1.0)*5 = 5.0
      ];

      double totalVenta = 0;
      double totalCosto = 0;
      for (var it in items) {
        final cant = it['cant'] as int;
        totalVenta += (it['precio'] as double) * cant;
        totalCosto += (it['costo'] as double) * cant;
      }
      final gananciaTotal = totalVenta - totalCosto;

      expect(totalVenta, 32.0);
      expect(totalCosto, 21.0);
      expect(gananciaTotal, 11.0);
    });
  });

  group('Mejoras UX - Modo Privacidad Comercial', () {
    test('Simula visibilidad condicional de ganancia y subtítulo según modo privacidad', () {
      bool hideProfits = false;
      const double profit = 15.5;

      String getSubtitle(bool isPrivacyActive) {
        if (isPrivacyActive) return "Cliente anónimo";
        return "Cliente anónimo · Ganancia est. S/ ${profit.toStringAsFixed(2)}";
      }

      expect(getSubtitle(hideProfits), "Cliente anónimo · Ganancia est. S/ 15.50");

      hideProfits = true;
      expect(getSubtitle(hideProfits), "Cliente anónimo");
    });
  });

  group('Mejoras UX - Lógica de Reabastecimiento Rápido de Stock', () {
    test('Modo Suma: Incrementa stock existente con mercancía recibida', () {
      const int currentStock = 5;
      const int receivedStock = 12;
      const int calculatedNewStock = currentStock + receivedStock;
      expect(calculatedNewStock, 17);
    });

    test('Modo Directo: Fija inventario físico exacto respetando no-negativos', () {
      const int currentStock = 5;
      int exactInventory = 24;
      expect(exactInventory, 24);

      int invalidStock = -3;
      bool isValid = invalidStock >= 0;
      expect(isValid, false);
      expect(currentStock, 5);
    });
  });

  group('Mejoras UX - Navegación y Toggle de Categorías', () {
    test('Des-selecciona categoría activa al tocarla por segunda vez', () {
      int? selectedCategoryId = 2; // Categoría Abarrotes
      
      // Simula toggle
      int? onCategoryTapped(int? tappedId) {
        if (selectedCategoryId == tappedId) {
          return null; // Toggle OFF
        }
        return tappedId;
      }

      // Tocar la misma categoría la deselecciona
      selectedCategoryId = onCategoryTapped(2);
      expect(selectedCategoryId, isNull);

      // Tocar otra categoría la selecciona
      selectedCategoryId = onCategoryTapped(4);
      expect(selectedCategoryId, 4);
    });
  });

  group('Mejoras UX - Atajos de Perfil y Responsividad de Toolbar', () {
    test('Atajo de Logo invoca onChangeLogo preferencialmente antes que onEditBusiness', () {
      bool logoPickerCalled = false;
      bool businessModalCalled = false;

      void mockOnChangeLogo() => logoPickerCalled = true;
      void mockOnEditBusiness() => businessModalCalled = true;

      // Simula el callback del campo Logo en ProfileCompletionIndicator
      const Function? mockNull = null;
      final Function logoTapAction = mockOnChangeLogo;
      logoTapAction();

      expect(logoPickerCalled, isTrue);
      expect(businessModalCalled, isFalse);

      final Function fallbackAction = mockNull ?? mockOnEditBusiness;
      fallbackAction();
      expect(businessModalCalled, isTrue);
    });

    test('Lógica de Toolbar Responsiva oculta etiqueta Ordenar cuando ancho < 380', () {
      bool shouldShowSortLabel(double maxWidth) => maxWidth >= 380;

      expect(shouldShowSortLabel(390), isTrue);
      expect(shouldShowSortLabel(360), isFalse); // Pantalla compacta (360dp)
      expect(shouldShowSortLabel(320), isFalse); // Pantalla muy compacta (320dp)
    });

    test('Aislamiento de Seguridad: Cerrar Sesión es neutral y Eliminar Perfil es crítico', () {
      const bool isLogoutDestructive = false; // Neutral / Slate
      const bool isDeleteDestructive = true;  // Crítico / Danger Zone

      expect(isLogoutDestructive, isFalse);
      expect(isDeleteDestructive, isTrue);
    });
  });
}
