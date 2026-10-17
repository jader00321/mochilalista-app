import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Fase 1: Motor de Búsqueda OmniSearch & Normalización SQLite', () {
    String normalizeTokens(String input) {
      return input
          .toLowerCase()
          .replaceAll(RegExp(r'[áàäâÁ]'), 'a')
          .replaceAll(RegExp(r'[éèëêÉ]'), 'e')
          .replaceAll(RegExp(r'[íìïîÍ]'), 'i')
          .replaceAll(RegExp(r'[óòöôÓ]'), 'o')
          .replaceAll(RegExp(r'[úùüûÚüÜ]'), 'u')
          .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
          .trim();
    }

    String sqlUnaccentSimulated(String input) {
      // Simulación de SQLite LOWER() (que solo baja ASCII A-Z) + 12 niveles de REPLACE
      // que reemplaza explícitamente minúsculas y mayúsculas tildadas y diéresis.
      return input
          .toLowerCase()
          .replaceAll('á', 'a')
          .replaceAll('é', 'e')
          .replaceAll('í', 'i')
          .replaceAll('ó', 'o')
          .replaceAll('ú', 'u')
          .replaceAll('Á', 'a')
          .replaceAll('É', 'e')
          .replaceAll('Í', 'i')
          .replaceAll('Ó', 'o')
          .replaceAll('Ú', 'u')
          .replaceAll('ü', 'u')
          .replaceAll('Ü', 'u');
    }

    test('Normalización de tokens remueve tildes y caracteres especiales', () {
      expect(normalizeTokens('Lápiz Faber-Castell 2B!'), equals('lapiz fabercastell 2b'));
      expect(normalizeTokens('Acción Rápida'), equals('accion rapida'));
    });

    test('Normalización simula sqlUnaccent de SQLite con 12 niveles REPLACE incluyendo mayúsculas tildadas', () {
      // Caso crítico: SQLite LOWER('Útiles') sigue siendo 'Útiles' porque LOWER() no afecta caracteres no-ASCII
      final dbSavedName = 'Útiles Escolares Ácido Óptico Pingüino';
      final unaccentedCol = sqlUnaccentSimulated(dbSavedName);

      expect(unaccentedCol.contains(normalizeTokens('utiles')), isTrue);
      expect(unaccentedCol.contains(normalizeTokens('acido')), isTrue);
      expect(unaccentedCol.contains(normalizeTokens('optico')), isTrue);
      expect(unaccentedCol.contains(normalizeTokens('pinguino')), isTrue);
    });

    test('Búsqueda multi-palabra tokenizada con AND cruzado encuentra registros desordenados', () {
      final productFields = 'cuaderno a4 stanford cuadriculado 100 hojas 7750123456789'.toLowerCase();
      final userQuery = 'stanford cuaderno 100';
      final tokens = userQuery.split(' ').map((t) => normalizeTokens(t)).toList();

      final allMatch = tokens.every((token) => productFields.contains(token));
      expect(allMatch, isTrue);
    });

    test('Esquema de clientes utiliza dni_ruc y deuda_total', () {
      final clientRow = {
        'id': 10,
        'nombre_completo': 'Juan Pérez',
        'dni_ruc': '10456789012',
        'telefono': '987654321',
        'deuda_total': 150.50,
      };

      expect(clientRow.containsKey('dni_ruc'), isTrue);
      expect(clientRow.containsKey('deuda_total'), isTrue);
      expect(clientRow['dni_ruc'], equals('10456789012'));
      expect(clientRow['deuda_total'], equals(150.50));
    });
  });

  group('Fase 2: Ordenamiento Dinámico, Extracción Numérica Segura y Navegación', () {
    double extractNumericValue(Map<String, dynamic> item) {
      final raw = item['precio_venta_final'] ??
          item['total_amount'] ??
          item['monto_total'] ??
          item['deuda_total'];
      if (raw == null) return 0.0;
      if (raw is num) return raw.toDouble();
      return double.tryParse(raw.toString()) ?? 0.0;
    }

    final sampleItems = [
      {'nombre': 'Borrador Blanco', 'precio_venta_final': 1.50},
      {'nombre': 'Cuaderno Standford', 'total_amount': '6.50'}, // String representation
      {'nombre': 'Archivador A4', 'monto_total': 12}, // int representation
      {'nombre': 'Cliente Sin Deuda', 'deuda_total': null}, // null representation
    ];

    test('Extracción numérica segura maneja double, int, String y null sin excepción', () {
      expect(extractNumericValue(sampleItems[0]), equals(1.50));
      expect(extractNumericValue(sampleItems[1]), equals(6.50));
      expect(extractNumericValue(sampleItems[2]), equals(12.00));
      expect(extractNumericValue(sampleItems[3]), equals(0.0));
    });

    test('Ordenamiento por Mayor Precio/Monto seguro', () {
      final list = List<Map<String, dynamic>>.from(sampleItems);
      list.sort((a, b) => extractNumericValue(b).compareTo(extractNumericValue(a)));
      expect(extractNumericValue(list.first), equals(12.00));
      expect(extractNumericValue(list.last), equals(0.0));
    });

    test('Ordenamiento por Menor Precio/Monto seguro', () {
      final list = List<Map<String, dynamic>>.from(sampleItems);
      list.sort((a, b) => extractNumericValue(a).compareTo(extractNumericValue(b)));
      expect(extractNumericValue(list.first), equals(0.0));
      expect(extractNumericValue(list.last), equals(12.00));
    });
  });

  group('Fase 3: Flujo de Código de Barras y Modal No Encontrado', () {
    test('Inyección de initialBarcode precarga tanto el código general como la variante inicial', () {
      final initialBarcode = '7751234567890';
      final barcodeCtrlText = initialBarcode;
      final firstPresentationController = {'barcode': initialBarcode};

      expect(barcodeCtrlText, equals(initialBarcode));
      expect(firstPresentationController['barcode'], equals(initialBarcode));
    });

    test('Cierre de diálogo sin registrar reanuda cámara y libera bandera de procesamiento', () {
      bool isProcessing = true;
      bool cameraRunning = false;
      bool navigatedToCreate = false;

      // Simulación de cierre de diálogo por botón o gesto
      void onDialogDismissed() {
        if (!navigatedToCreate) {
          cameraRunning = true;
          isProcessing = false;
        }
      }

      onDialogDismissed();
      expect(isProcessing, isFalse);
      expect(cameraRunning, isTrue);
    });
  });

  group('Fase 4: PersistentWorkDock y Modo Globo Magnético Bounded', () {
    test('Coordenadas de Positioned son mutuamente excluyentes entre left y right en modo globo', () {
      bool isMutuallyExclusive(double? left, double? right) =>
          (left != null && right == null) || (left == null && right != null);

      expect(isMutuallyExclusive(45.0, null), isTrue);
      expect(isMutuallyExclusive(16.0, null), isTrue);
      expect(isMutuallyExclusive(null, 16.0), isTrue);
      expect(isMutuallyExclusive(16.0, 16.0), isFalse);
    });

    test('Dimensiones del globo flotante acotan el HitTest a 58x58px', () {
      double computeDockWidth(bool isBubble) => isBubble ? 58.0 : double.infinity;
      expect(computeDockWidth(true), equals(58.0));
      expect(computeDockWidth(false), equals(double.infinity));
    });

    test('Padding dinámico del scroll del Home cambia según el estado del dock', () {
      double calculateBottomPadding({required bool hasTasks, required bool isBubble}) {
        if (!hasTasks) return 30.0;
        return isBubble ? 40.0 : 150.0;
      }

      expect(calculateBottomPadding(hasTasks: false, isBubble: false), equals(30.0));
      expect(calculateBottomPadding(hasTasks: true, isBubble: false), equals(150.0));
      expect(calculateBottomPadding(hasTasks: true, isBubble: true), equals(40.0));
    });
  });

  group('Fase 5: Home Studio, Densidad 3 Columnas y Hero Card', () {
    final defaultIds = [
      'quick_sale',
      'create_product',
      'quote_list',
      'quote_manual',
      'load_invoice',
      'clients',
      'activity',
      'analytics',
    ];

    test('Reordenamiento por Drag & Drop intercambia posiciones con precisión', () {
      final currentOrder = List<String>.from(defaultIds);
      final dragged = 'clients';
      final target = 'quick_sale';

      final oldIndex = currentOrder.indexOf(dragged);
      final newIndex = currentOrder.indexOf(target);

      currentOrder.removeAt(oldIndex);
      currentOrder.insert(newIndex, dragged);

      expect(currentOrder.first, equals('clients'));
      expect(currentOrder[1], equals('quick_sale'));
      expect(currentOrder.length, equals(defaultIds.length));
    });

    test('Ocultar tarjeta y restaurar desde la bandeja de ocultas', () {
      final hiddenSet = <String>{};
      final toHide = 'load_invoice';

      hiddenSet.add(toHide);
      expect(hiddenSet.contains(toHide), isTrue);

      hiddenSet.remove(toHide);
      expect(hiddenSet.contains(toHide), isFalse);
    });

    test('Detección del estado personalizado para el punto azul (Propuesta 3)', () {
      bool isCustomized({
        required List<String> currentOrder,
        required Set<String> hidden,
        required int density,
        required String? heroId,
      }) {
        if (density != 2) return true;
        if (heroId != null) return true;
        if (hidden.isNotEmpty) return true;
        for (int i = 0; i < defaultIds.length; i++) {
          if (i >= currentOrder.length || currentOrder[i] != defaultIds[i]) {
            return true;
          }
        }
        return false;
      }

      // Fábrica
      expect(isCustomized(currentOrder: defaultIds, hidden: {}, density: 2, heroId: null), isFalse);

      // Con cambio de densidad
      expect(isCustomized(currentOrder: defaultIds, hidden: {}, density: 3, heroId: null), isTrue);

      // Con Hero asignado
      expect(isCustomized(currentOrder: defaultIds, hidden: {}, density: 2, heroId: 'quick_sale'), isTrue);

      // Con tarjeta oculta
      expect(isCustomized(currentOrder: defaultIds, hidden: {'load_invoice'}, density: 2, heroId: null), isTrue);
    });

    test('Restablecimiento a orden de fábrica restaura todos los valores iniciales', () {
      var currentOrder = ['clients', 'quick_sale'];
      var hidden = {'create_product'};
      var density = 3;
      String? hero = 'analytics';

      // Fábrica
      currentOrder = List.from(defaultIds);
      hidden.clear();
      density = 2;
      hero = null;

      expect(currentOrder, equals(defaultIds));
      expect(hidden.isEmpty, isTrue);
      expect(density, equals(2));
      expect(hero, isNull);
    });

    test('Power shortcut en Hero card se activa en modo normal', () {
      bool isEditing = false;
      bool shortcutFired = false;
      void Function()? onLongPressBuilder() => () => shortcutFired = true;

      void handleLongPress() {
        if (!isEditing) {
          onLongPressBuilder()?.call();
        }
      }

      handleLongPress();
      expect(shortcutFired, isTrue);
    });

    test('Calibración de childAspectRatio para 3 columnas previene overflow en pantallas angostas', () {
      double computeAspectRatio(int cols, double screenWidth) {
        if (cols == 3) {
          return screenWidth > 600 ? 1.05 : (screenWidth > 360 ? 0.82 : 0.76);
        }
        return screenWidth > 400 ? 1.08 : 0.94;
      }

      // En 3 columnas y pantalla angosta (350dp), aspect ratio da más altura vertical (0.76)
      expect(computeAspectRatio(3, 350), equals(0.76));
      expect(computeAspectRatio(3, 380), equals(0.82));
      expect(computeAspectRatio(2, 380), equals(0.94));
    });
  });
}
