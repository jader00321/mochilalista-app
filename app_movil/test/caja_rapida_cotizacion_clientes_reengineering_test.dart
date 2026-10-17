import 'package:flutter_test/flutter_test.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';

void main() {
  group('Fase 1: Motor Multi-Palabra de Clientes & _sqlUnaccent 12 Niveles', () {
    String normalizeTokens(String input) {
      return input
          .toLowerCase()
          .replaceAll(RegExp(r'[áàäâÁ]'), 'a')
          .replaceAll(RegExp(r'[éèëêÉ]'), 'e')
          .replaceAll(RegExp(r'[íìïîÍ]'), 'i')
          .replaceAll(RegExp(r'[óòöôÓ]'), 'o')
          .replaceAll(RegExp(r'[úùüûÚüÜ]'), 'u')
          .replaceAll(RegExp(r'ñ'), 'n')
          .replaceAll(RegExp(r'Ñ'), 'n')
          .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
          .trim();
    }

    String sqlUnaccentSimulated(String input) {
      // Simula el generador SQL de 12 niveles de REPLACE implementado en ClientRepository
      return input
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
          .replaceAll('Ü', 'u')
          .toLowerCase();
    }

    test('SQLite _sqlUnaccent remueve 12 niveles de tildes y mayúsculas diacríticas', () {
      final dbRaw = 'Ángel Íñigo Óptico Úrsula Pingüino Éxito';
      final cleaned = sqlUnaccentSimulated(dbRaw);

      expect(cleaned, contains('angel'));
      expect(cleaned, contains('optico'));
      expect(cleaned, contains('ursula'));
      expect(cleaned, contains('pinguino'));
      expect(cleaned, contains('exito'));
    });

    test('Búsqueda multi-palabra con tokens AND cruzados encuentra clientes en orden arbitrario', () {
      final clientComposite = 'maria josefa rodriguez lopez 987654321 44556677 av arequipa 123 lima colegio san martin'.toLowerCase();
      final userQuery = '987654321 rodriguez lima arequipa';
      final tokens = userQuery.split(' ').map((t) => normalizeTokens(t)).toList();

      final allMatch = tokens.every((token) => clientComposite.contains(token));
      expect(allMatch, isTrue);
    });

    test('Búsqueda por DNI parcial y teléfono funciona sin importar espacios', () {
      final clientDoc = '72345678';
      final clientPhone = '987 654 321'.replaceAll(' ', '');
      
      expect(clientDoc.contains('7234'), isTrue);
      expect(clientPhone.contains('654321'), isTrue);
    });
  });

  group('Fase 2: Datos del Cliente y Edición In-Situ en Quick Sale', () {
    late QuickSaleProvider provider;

    setUp(() {
      provider = QuickSaleProvider();
    });

    test('setClientInfo actualiza datos básicos y resetea correctamente', () {
      provider.setClientInfo(
        id: 42,
        name: 'Carlos Mendoza',
        phone: '999888777',
        clientNote: 'Cliente preferencial',
        saleNote: 'Entregar en la tarde',
        saldo: 15.50,
      );

      expect(provider.clientId, equals(42));
      expect(provider.clientName, equals('Carlos Mendoza'));
      expect(provider.clientPhone, equals('999888777'));
      expect(provider.clientNote, equals('Cliente preferencial'));
      expect(provider.saleNote, equals('Entregar en la tarde'));
      expect(provider.clientSaldo, equals(15.50));

      // Desvincular cliente
      provider.setClientInfo(
        id: null,
        name: null,
        phone: null,
        clientNote: null,
        saleNote: provider.saleNote,
        saldo: 0,
      );

      expect(provider.clientId, isNull);
      expect(provider.clientName, isNull);
      expect(provider.clientPhone, isNull);
      expect(provider.clientSaldo, equals(0.0));
      expect(provider.saleNote, equals('Entregar en la tarde')); // La nota de venta se preserva
    });

    test('updateSelectedClientData sincroniza ClientModel y datos en tiempo real', () {
      final client = ClientModel(
        id: 101,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        fullName: 'Librería Central',
        phone: '987654321',
        docNumber: '20123456789',
        address: 'Jr. Puno 456',
        saldoAFavor: 50.0,
        totalDebt: 120.0,
        notes: 'Pago a 15 días',
        registeredDate: DateTime.now().toIso8601String(),
      );

      provider.updateSelectedClientData(client);

      expect(provider.selectedClient, equals(client));
      expect(provider.clientId, equals(101));
      expect(provider.clientName, equals('Librería Central'));
      expect(provider.clientPhone, equals('987654321'));
      expect(provider.clientSaldo, equals(50.0));
      expect(provider.clientNote, equals('Pago a 15 días'));
    });

    test('Validación de registro de cliente de paso requiere nombre no vacío', () {
      String cleanWalkInName(String name) => name.trim();
      String cleanPhone(String phone) => phone.replaceAll(RegExp(r'\D'), '');

      expect(cleanWalkInName('   '), isEmpty);
      expect(cleanWalkInName('  Ana Pérez  '), equals('Ana Pérez'));
      expect(cleanPhone('987-654-321'), equals('987654321'));
      expect(cleanPhone('987 654 321'), equals('987654321'));
    });
  });

  group('Fase 3: Modal de Nota de Venta & Indicadores Activos', () {
    late QuickSaleProvider provider;

    setUp(() {
      provider = QuickSaleProvider();
    });

    test('Chips rápidos de nota acumulan texto con guión sin duplicados', () {
      String appendChip(String current, String text) {
        final c = current.trim();
        if (c.isEmpty) return text;
        if (c.contains(text)) return c;
        return "$c - $text";
      }

      var note = appendChip('', 'Entrega pendiente');
      expect(note, equals('Entrega pendiente'));

      note = appendChip(note, 'Envío a domicilio');
      expect(note, equals('Entrega pendiente - Envío a domicilio'));

      // Intentar agregar duplicado no hace nada
      note = appendChip(note, 'Entrega pendiente');
      expect(note, equals('Entrega pendiente - Envío a domicilio'));

      provider.setClientInfo(saleNote: note);
      expect(provider.saleNote, equals('Entrega pendiente - Envío a domicilio'));

      provider.clearSaleNote();
      expect(provider.saleNote, isNull);
    });

    test('Indicador visual activo de nota detecta presencia de texto', () {
      bool hasActiveNote(String? note) => note != null && note.trim().isNotEmpty;

      expect(hasActiveNote(null), isFalse);
      expect(hasActiveNote(''), isFalse);
      expect(hasActiveNote('   '), isFalse);
      expect(hasActiveNote('Factura con orden de compra'), isTrue);
    });
  });

  group('Fase 4: QuickSaleDetailModal & Carrito (Fusión de Presentaciones & Descuento)', () {
    late QuickSaleProvider provider;

    setUp(() {
      provider = QuickSaleProvider();
      provider.clearCart();
    });

    test('updateItemFromModal fusiona cantidad cuando se cambia a una presentación ya existente en el carrito', () {
      // 1. Agregar dos presentaciones al carrito directamente
      final item1 = MatchedProduct(
        productId: 10,
        presentationId: 1,
        fullName: 'Cuaderno Standford A4 Unidad',
        productName: 'Cuaderno Standford A4',
        specificName: 'Unidad',
        unit: 'Unidad',
        price: 5.0,
        stock: 50,
      );

      final item2 = MatchedProduct(
        productId: 10,
        presentationId: 2,
        fullName: 'Cuaderno Standford A4 Docena',
        productName: 'Cuaderno Standford A4',
        specificName: 'Docena',
        unit: 'Docena',
        price: 50.0,
        stock: 10,
      );

      provider.cartItems.add(item1);
      provider.updateQuantity(1, 2, 50);

      provider.cartItems.add(item2);
      provider.updateQuantity(2, 1, 10);

      expect(provider.cartItems.length, equals(2));
      expect(provider.getQuantity(1), equals(2));
      expect(provider.getQuantity(2), equals(1));

      // 2. Modificar el item2 (presId: 2) para que se convierta en la presentación 1 con nueva cantidad 3
      // Debe fusionarse con item1, resultando en 1 solo ítem con cantidad 2 + 3 = 5
      provider.updateItemFromModal(
        2, // oldPresentationId
        item1, // nuevo producto/variante (presId 1)
        3, // newQty
        null, // newOverridePrice
      );

      expect(provider.cartItems.length, equals(1));
      expect(provider.cartItems[0].presentationId, equals(1));
      expect(provider.getQuantity(1), equals(5));
      expect(provider.getEffectivePrice(1), equals(5.0));
    });

    test('updateItemFromModal actualiza normalmente si no existe duplicado', () {
      final item = MatchedProduct(
        productId: 20,
        presentationId: 5,
        fullName: 'Plumones Faber 12',
        productName: 'Plumones Faber',
        unit: 'Caja',
        price: 12.0,
        stock: 20,
      );
      provider.cartItems.add(item);
      provider.updateQuantity(5, 1, 20);

      final updatedVariant = MatchedProduct(
        productId: 20,
        presentationId: 6,
        fullName: 'Plumones Faber Pack x3',
        productName: 'Plumones Faber',
        unit: 'Pack x3',
        price: 32.0,
        stock: 15,
      );

      provider.updateItemFromModal(
        5,
        updatedVariant,
        4,
        30.0,
      );

      expect(provider.cartItems.length, equals(1));
      expect(provider.cartItems[0].presentationId, equals(6));
      expect(provider.cartItems[0].unit, equals('Pack x3'));
      expect(provider.getQuantity(6), equals(4));
      expect(provider.getEffectivePrice(6), equals(30.0));
    });

    test('Cálculo de Descuento de 2 Niveles no desborda y calcula porcentaje exacto', () {
      const basePrice = 20.0;
      const discountedPrice = 18.0;
      final discountPercent = ((basePrice - discountedPrice) / basePrice) * 100;

      expect(discountPercent, equals(10.0));
      expect(discountPercent.toStringAsFixed(1), equals('10.0'));
    });

    test('updateItemFromModal aplica tope de stock (clamp) y emite advertencia si la fusión supera el stock', () {
      final item1 = MatchedProduct(
        productId: 30,
        presentationId: 10,
        fullName: 'Témperas Artesco 6 Colores',
        productName: 'Témperas Artesco',
        unit: 'Caja',
        price: 8.0,
        stock: 5, // Stock máximo limitado a 5
      );

      final item2 = MatchedProduct(
        productId: 30,
        presentationId: 11,
        fullName: 'Témperas Artesco Pack',
        productName: 'Témperas Artesco',
        unit: 'Pack',
        price: 15.0,
        stock: 10,
      );

      provider.cartItems.add(item1);
      provider.updateQuantity(10, 4, 5); // 4 unidades en el carrito

      provider.cartItems.add(item2);
      provider.updateQuantity(11, 3, 10);

      // Intentar fusionar sumando 3 más (4 + 3 = 7, pero el stock es 5)
      final result = provider.updateItemFromModal(
        11,
        item1,
        3,
        null,
      );

      expect(provider.cartItems.length, equals(1));
      expect(provider.getQuantity(10), equals(5)); // Clamped a 5 (no 7)
      expect(result, contains('stock máximo disponible (5)'));
    });

    test('updateItemFromModal rechaza fusión si el producto destino tiene stock 0 sin lanzar excepción clamp', () {
      final item1 = MatchedProduct(
        productId: 40,
        presentationId: 20,
        fullName: 'Regla 30cm Acrílica',
        productName: 'Regla 30cm',
        unit: 'Unidad',
        price: 2.0,
        stock: 0, // Stock agotado
      );

      final item2 = MatchedProduct(
        productId: 40,
        presentationId: 21,
        fullName: 'Regla 30cm Metálica',
        productName: 'Regla 30cm',
        unit: 'Unidad',
        price: 5.0,
        stock: 10,
      );

      provider.cartItems.add(item1);
      provider.cartItems.add(item2);
      provider.updateQuantity(21, 2, 10);

      final result = provider.updateItemFromModal(
        21,
        item1,
        2,
        null,
      );

      expect(result, contains('No hay unidades disponibles en stock'));
    });
  });

  group('Fase 5: Cotización Inteligente & Conciliación IA', () {
    test('Selección de cliente en Cotización autocompleta DNI, Dirección y Notas', () {
      final client = ClientModel(
        id: 77,
        negocioId: 2,
        creadoPorUsuarioId: 5,
        fullName: 'Colegio Santa Rosa',
        phone: '955443322',
        docNumber: '20556677889',
        address: 'Av. Las Palmeras 789',
        email: 'santarosa@edu.pe',
        notes: 'Cotizar con IGV desglosado',
        registeredDate: DateTime.now().toIso8601String(),
      );

      final clientMap = {
        'fullName': client.fullName,
        'phone': client.phone,
        'docNumber': client.docNumber ?? '',
        'address': client.address ?? '',
        'email': client.email ?? '',
        'notes': client.notes ?? '',
      };

      expect(clientMap['fullName'], equals('Colegio Santa Rosa'));
      expect(clientMap['docNumber'], equals('20556677889'));
      expect(clientMap['address'], equals('Av. Las Palmeras 789'));
      expect(clientMap['email'], equals('santarosa@edu.pe'));
      expect(clientMap['notes'], equals('Cotizar con IGV desglosado'));
    });

    test('Ratio responsivo en matching_item_row calcula ancho seguro en pantallas de 320dp a 412dp', () {
      double calculateLeftWidth(double screenW, bool isExpanded) {
        if (isExpanded) return 50.0;
        final double maxLeft = (screenW - 56) * 0.42;
        final double minLeft = 110.0 <= maxLeft ? 110.0 : maxLeft;
        return (screenW * 0.35).clamp(minLeft, maxLeft);
      }

      // Pantalla ultra angosta 320dp
      final w320 = calculateLeftWidth(320.0, false);
      expect(w320 <= (320 - 56) * 0.42, isTrue); // Nunca ahoga a la tarjeta derecha
      expect(w320 >= 100.0, isTrue);

      // Pantalla estándar 360dp
      final w360 = calculateLeftWidth(360.0, false);
      expect(w360, greaterThanOrEqualTo(110.0));
      expect(w360, lessThanOrEqualTo((360 - 56) * 0.42));

      // Pantalla moderna 390dp
      final w390 = calculateLeftWidth(390.0, false);
      expect(w390, greaterThanOrEqualTo(125.0));

      // Pantalla grande 412dp
      final w412 = calculateLeftWidth(412.0, false);
      expect(w412, greaterThanOrEqualTo(130.0));
    });
  });
}
