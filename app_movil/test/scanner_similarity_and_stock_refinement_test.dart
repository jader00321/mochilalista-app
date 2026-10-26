import 'package:flutter_test/flutter_test.dart';
import 'package:app_movil/features/scanner/services/commercial_invoice_normalizer.dart';
import 'package:app_movil/features/scanner/models/scanner_models.dart';
import 'package:app_movil/features/scanner/providers/scanner_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FASE 1: Normalización sin Diacríticos, Prefix Stemming y Cobertura Multi-Campo', () {
    test('Diacríticos son eliminados y el prefix stemming hace match al 100%', () {
      final t1 = CommercialInvoiceNormalizer.normalizeCommercialString("ESCARCH");
      final t2 = CommercialInvoiceNormalizer.normalizeCommercialString("Escarchado");
      expect(CommercialInvoiceNormalizer.matchTokens(t1, t2), equals(1.0));

      final c1 = CommercialInvoiceNormalizer.normalizeCommercialString("CONSTR");
      final c2 = CommercialInvoiceNormalizer.normalizeCommercialString("Construcción");
      expect(CommercialInvoiceNormalizer.matchTokens(c1, c2), equals(1.0));

      final l1 = CommercialInvoiceNormalizer.normalizeCommercialString("LATINOAM");
      final l2 = CommercialInvoiceNormalizer.normalizeCommercialString("Latinoamericana");
      expect(CommercialInvoiceNormalizer.matchTokens(l1, l2), equals(1.0));
    });

    test('Normalización de dimensiones peruanas (100cm x 100cm -> 100x100cm)', () {
      final s1 = CommercialInvoiceNormalizer.normalizeCommercialString("FOMI ESCARCH 100cm x 100cm");
      final s2 = CommercialInvoiceNormalizer.normalizeCommercialString("FOMI ESCARCH 100x100cm");
      final s3 = CommercialInvoiceNormalizer.normalizeCommercialString("FOMI ESCARCH 100 cm x 100 cm");

      expect(s1.contains("100x100cm"), isTrue);
      expect(s2.contains("100x100cm"), isTrue);
      expect(s3.contains("100x100cm"), isTrue);
    });

    test('Normalización de abreviaturas de número (No 7, Nro 7, # 7 -> n 7)', () {
      final s1 = CommercialInvoiceNormalizer.normalizeCommercialString("BLOQUES LOGICOS No 7 TAPER (GRUESO)");
      final s2 = CommercialInvoiceNormalizer.normalizeCommercialString("Bloques Lógicos N° 7 Taper Grueso");
      final s3 = CommercialInvoiceNormalizer.normalizeCommercialString("BLOQUES LOGICOS Nro 7 TAPER");

      expect(s1.contains("n 7"), isTrue);
      expect(s2.contains("n 7"), isTrue);
      expect(s3.contains("n 7"), isTrue);
    });

    test('Caso 1 Real: BLOQUES LOGICOS No 7 TAPER (GRUESO) supera el 90% contra BD con variante', () {
      final result = CommercialInvoiceNormalizer.evaluateCompositeMatch(
        facturaDescripcion: "BLOQUES LOGICOS No 7 TAPER (GRUESO)",
        productoNombre: "Bloques Lógicos",
        marcaNombre: null,
        variantes: [
          {'nombre_especifico': "N° 7 Taper Grueso", 'nombre_completo': "Bloques Lógicos N° 7 Taper Grueso"},
          {'nombre_especifico': "Madera", 'nombre_completo': "Bloques Lógicos Madera"},
        ],
      );

      expect(result.score, greaterThanOrEqualTo(90));
    });

    test('Caso 2 Real: FOMI ESCARCH 100cm x 100cm supera el 90% contra BD con variante', () {
      final result = CommercialInvoiceNormalizer.evaluateCompositeMatch(
        facturaDescripcion: "FOMI ESCARCH 100cm x 100cm",
        productoNombre: "Fomi Escarchado",
        marcaNombre: null,
        variantes: [
          {'nombre_especifico': "100cm x 100cm", 'nombre_completo': "Fomi Escarchado 100cm x 100cm"},
          {'nombre_especifico': "50cm x 50cm", 'nombre_completo': "Fomi Escarchado 50cm x 50cm"},
        ],
      );

      expect(result.score, greaterThanOrEqualTo(90));
    });

    test('Caso 3 Real: BLOQUES CONSTRUCCION EDUKT PLASTIC supera el 90% con Marca y SKU', () {
      final result = CommercialInvoiceNormalizer.evaluateCompositeMatch(
        facturaDescripcion: "BLOQUES CONSTRUCCION EDUKT PLASTIC",
        productoNombre: "Bloques de Construcción",
        marcaNombre: "Edukt Plastic",
        variantes: [
          {'sku': "MDJ049", 'nombre_especifico': "Plástico", 'nombre_completo': "Bloques de Construcción Plástico"},
        ],
      );

      expect(result.score, greaterThanOrEqualTo(90));
    });
  });

  group('FASE 2: Getters Unificados y Base Única de Verdad de Stock', () {
    test('effectiveUnidadVenta y effectiveFactorVenta respetan BD hasta que se editen explícitamente', () {
      final variant = StagingVariant(
        uuidTemporal: "var-1",
        nombreEspecifico: "½ Docena",
        unidadVenta: "Unidad",
        unidadesPorVenta: 1,
        umpCompra: "Paquete",
        cantidadUmpComprada: 1,
        precioUmpProveedor: 12.0,
        totalPagoLote: 12.0,
        unidadesPorLote: 4,
        costoUnitarioSugerido: 3.0,
        factorGananciaVentaSugerido: 1.35,
        precioVentaSugerido: 4.05,
        matchPresentacion: MatchResult(
          estado: "MATCH_AUTO",
          confianza: 95,
          datos: MatchData(
            id: 10,
            nombre: "½ Docena",
            unidadVenta: "½ Docena",
            unidadesPorVenta: 6,
            stockActual: 4,
          ),
        ),
      );

      // Sin editar: debe reflejar los valores de BD
      expect(variant.effectiveUnidadVenta, equals("½ Docena"));
      expect(variant.effectiveFactorVenta, equals(6));

      // Si el usuario edita y updateUnidadVenta = true: debe reflejar lo editado
      variant.unidadVenta = "Docena";
      variant.unidadesPorVenta = 12;
      variant.updateUnidadVenta = true;

      expect(variant.effectiveUnidadVenta, equals("Docena"));
      expect(variant.effectiveFactorVenta, equals(12));
    });

    test('calculateTotalUnitsBase unifica sumar vs reemplazar', () {
      final variant = StagingVariant(
        uuidTemporal: "var-1",
        nombreEspecifico: "½ Docena",
        unidadVenta: "½ Docena",
        unidadesPorVenta: 6,
        umpCompra: "Paquete",
        cantidadUmpComprada: 1,
        precioUmpProveedor: 12.0,
        totalPagoLote: 12.0,
        unidadesPorLote: 4,
        costoUnitarioSugerido: 3.0,
        factorGananciaVentaSugerido: 1.35,
        precioVentaSugerido: 4.05,
        matchPresentacion: MatchResult(
          estado: "MATCH_AUTO",
          confianza: 95,
          datos: MatchData(id: 10, nombre: "½ Docena", stockActual: 4),
        ),
      )..stockOperation = 'sumar';

      // 4 BD + 4 ingresante = 8 unidades base
      expect(variant.calculateTotalUnitsBase(stockActualBD: 4), equals(8));

      // En modo reemplazar: solo 4 ingresantes
      variant.stockOperation = 'reemplazar';
      expect(variant.calculateTotalUnitsBase(stockActualBD: 4), equals(4));
    });

    test('4 BD + 4 ingreso = 8 unid. base para ½ Docena (x6) es SOBRANTE (1 paquete y 2 sueltas), NO DÉFICIT', () {
      final variant = StagingVariant(
        uuidTemporal: "var-1",
        nombreEspecifico: "½ Docena",
        unidadVenta: "½ Docena",
        unidadesPorVenta: 6,
        umpCompra: "Paquete",
        cantidadUmpComprada: 1,
        precioUmpProveedor: 12.0,
        totalPagoLote: 12.0,
        unidadesPorLote: 4,
        costoUnitarioSugerido: 3.0,
        factorGananciaVentaSugerido: 1.35,
        precioVentaSugerido: 4.05,
        matchPresentacion: MatchResult(
          estado: "MATCH_AUTO",
          confianza: 95,
          datos: MatchData(id: 10, nombre: "½ Docena", stockActual: 4, unidadesPorVenta: 6, unidadVenta: "½ Docena"),
        ),
      )..stockOperation = 'sumar';

      final totalBase = variant.calculateTotalUnitsBase(stockActualBD: 4);
      final factor = variant.effectiveFactorVenta;
      final completas = totalBase ~/ factor;
      final sobrante = totalBase % factor;

      expect(totalBase, equals(8));
      expect(factor, equals(6));
      expect(completas, equals(1)); // 1 ½ Docena
      expect(sobrante, equals(2)); // 2 sueltas (sobrante)
      expect(completas > 0, isTrue); // NO ES DÉFICIT (deficit ocurre solo si completas == 0)
    });
  });

  group('FASE 3: Matemática Exacta en Acciones de 1 Toque y Separación de Sobrante', () {
    test('Separar sobrante: Deja exactamente 1 presentación en la principal y envía 2 a Unidad (x1)', () {
      final provider = ScannerProvider();

      final principal = StagingVariant(
        uuidTemporal: "var-principal",
        nombreEspecifico: "½ Docena",
        unidadVenta: "½ Docena",
        unidadesPorVenta: 6,
        umpCompra: "Paquete",
        cantidadUmpComprada: 1,
        precioUmpProveedor: 12.0,
        totalPagoLote: 12.0,
        unidadesPorLote: 4,
        costoUnitarioSugerido: 3.0,
        factorGananciaVentaSugerido: 1.35,
        precioVentaSugerido: 4.05,
        matchPresentacion: MatchResult(
          estado: "MATCH_AUTO",
          confianza: 95,
          datos: MatchData(id: 10, nombre: "½ Docena", stockActual: 4, unidadesPorVenta: 6, unidadVenta: "½ Docena"),
        ),
      )..stockOperation = 'sumar';

      final group = StagingProductGroup(
        uuidTemporal: "grp-1",
        nombrePadre: "Producto Prueba",
        marcaTexto: "Genérica",
        matchMarca: MatchResult(estado: "NUEVO", confianza: 0),
        variantes: [principal],
        matchProducto: MatchResult(
          estado: "MATCH_AUTO",
          confianza: 95,
          datos: MatchData(id: 1, nombre: "Producto Prueba"),
        ),
      );

      final staging = StagingResponse(
        proveedorMatch: MatchResult(estado: "NUEVO", confianza: 0),
        proveedorTexto: "Distribuidora Test",
        productosAgrupados: [group],
      );

      provider.setStagingDataForTesting(staging);

      // Inicialmente hay un error de stock por las 2 unidades sueltas no resueltas
      expect(provider.hasUnresolvedStock, isTrue);
      expect(provider.unresolvedStockErrorsCount, equals(1));

      // Acción de 1 toque: Enviar 2 sobrantes a 'Unidad (x1)'
      provider.createLeftoverVariant("var-principal", 2);

      // Verificación matemática:
      // En modo 'sumar': nuevoIngresoPrincipal = max(0, (1 * 6) - 4) = 2 unid. base
      expect(principal.stockIngresanteOverride, equals(2));
      // Con 4 en BD + 2 nuevo ingreso = 6 base (1 ½ docena exacta)
      expect(principal.calculateTotalUnitsBase(stockActualBD: 4), equals(6));
      expect(principal.calculateTotalUnitsBase(stockActualBD: 4) % principal.effectiveFactorVenta, equals(0));

      // Y la nueva variante 'Unidad (x1)' se creó con 2 unidades base ingresantes
      expect(group.variantes.length, equals(2));
      final leftoverVar = group.variantes.firstWhere((v) => v.sourceVariantUuid == "var-principal");
      expect(leftoverVar.effectiveUnidadVenta, equals("Unidad"));
      expect(leftoverVar.effectiveFactorVenta, equals(1));
      expect(leftoverVar.stockIngresanteOverride, equals(2));

      // Suma total en inventario: 6 (principal) + 2 (sobrante) = 8 unidades base intactas
      final totalInventario = principal.calculateTotalUnitsBase(stockActualBD: 4) + leftoverVar.calculateTotalUnitsBase(stockActualBD: 0);
      expect(totalInventario, equals(8));

      // El error de stock queda totalmente resuelto
      expect(provider.hasUnresolvedStock, isFalse);
      expect(provider.unresolvedStockErrorsCount, equals(0));
    });

    test('Conservar en reserva: allowLeftoverInReserve desbloquea el guardado conservando las 8 unid.', () {
      final provider = ScannerProvider();

      final principal = StagingVariant(
        uuidTemporal: "var-principal",
        nombreEspecifico: "½ Docena",
        unidadVenta: "½ Docena",
        unidadesPorVenta: 6,
        umpCompra: "Paquete",
        cantidadUmpComprada: 1,
        precioUmpProveedor: 12.0,
        totalPagoLote: 12.0,
        unidadesPorLote: 4,
        costoUnitarioSugerido: 3.0,
        factorGananciaVentaSugerido: 1.35,
        precioVentaSugerido: 4.05,
        matchPresentacion: MatchResult(
          estado: "MATCH_AUTO",
          confianza: 95,
          datos: MatchData(id: 10, nombre: "½ Docena", stockActual: 4, unidadesPorVenta: 6, unidadVenta: "½ Docena"),
        ),
      )..stockOperation = 'sumar';

      final group = StagingProductGroup(
        uuidTemporal: "grp-1",
        nombrePadre: "Producto Prueba",
        marcaTexto: "Genérica",
        matchMarca: MatchResult(estado: "NUEVO", confianza: 0),
        variantes: [principal],
        matchProducto: MatchResult(
          estado: "MATCH_AUTO",
          confianza: 95,
          datos: MatchData(id: 1, nombre: "Producto Prueba"),
        ),
      );

      final staging = StagingResponse(
        proveedorMatch: MatchResult(estado: "NUEVO", confianza: 0),
        proveedorTexto: "Distribuidora Test",
        productosAgrupados: [group],
      );

      provider.setStagingDataForTesting(staging);
      expect(provider.hasUnresolvedStock, isTrue);

      // Acción de 1 toque: Conservar en reserva base
      provider.authorizeLeftoverInReserve("var-principal");

      expect(principal.allowLeftoverInReserve, isTrue);
      expect(provider.hasUnresolvedStock, isFalse);
      expect(provider.unresolvedStockErrorsCount, equals(0));
    });

    test('Déficit real: Adaptar a Unidad (x1) y Autorizar 0 resuelven el conflicto', () {
      final provider = ScannerProvider();

      final deficitVar = StagingVariant(
        uuidTemporal: "var-deficit",
        nombreEspecifico: "½ Docena",
        unidadVenta: "½ Docena",
        unidadesPorVenta: 6,
        umpCompra: "Paquete",
        cantidadUmpComprada: 1,
        precioUmpProveedor: 6.0,
        totalPagoLote: 6.0,
        unidadesPorLote: 2, // Solo 2 unidades llegaron, y 0 en BD
        costoUnitarioSugerido: 3.0,
        factorGananciaVentaSugerido: 1.35,
        precioVentaSugerido: 4.05,
        matchPresentacion: MatchResult(
          estado: "MATCH_AUTO",
          confianza: 95,
          datos: MatchData(id: 10, nombre: "½ Docena", stockActual: 0, unidadesPorVenta: 6, unidadVenta: "½ Docena"),
        ),
      )..stockOperation = 'sumar';

      final group = StagingProductGroup(
        uuidTemporal: "grp-1",
        nombrePadre: "Producto Prueba",
        marcaTexto: "Genérica",
        matchMarca: MatchResult(estado: "NUEVO", confianza: 0),
        variantes: [deficitVar],
        matchProducto: MatchResult(estado: "MATCH_AUTO", confianza: 95, datos: MatchData(id: 1, nombre: "Producto Prueba")),
      );

      final staging = StagingResponse(
        proveedorMatch: MatchResult(estado: "NUEVO", confianza: 0),
        proveedorTexto: "Distribuidora Test",
        productosAgrupados: [group],
      );

      provider.setStagingDataForTesting(staging);
      expect(provider.hasUnresolvedStock, isTrue);

      // 1. Autorizar registro en 0
      provider.authorizeDeficitRegistration("var-deficit");
      expect(deficitVar.allowDeficitApproved, isTrue);
      expect(provider.hasUnresolvedStock, isFalse);

      // Deshacer autorización
      deficitVar.allowDeficitApproved = false;
      expect(provider.hasUnresolvedStock, isTrue);

      // 2. Adaptar a Unidad (x1)
      provider.adaptVariantUnit("var-deficit");
      expect(deficitVar.effectiveUnidadVenta, equals("Unidad"));
      expect(deficitVar.effectiveFactorVenta, equals(1));
      expect(provider.hasUnresolvedStock, isFalse);
    });
  });

  group('BLINDAJES CRÍTICOS: Sincronización en Vivo, Reset de Flags y Persistencia SQLite', () {
    test('Punto 1: Sincronización de stock ingresante al separar sobrante en el modal sin pérdida en applyChanges', () {
      final provider = ScannerProvider();

      final principal = StagingVariant(
        uuidTemporal: "var-principal",
        nombreEspecifico: "½ Docena",
        unidadVenta: "½ Docena",
        unidadesPorVenta: 6,
        umpCompra: "Paquete",
        cantidadUmpComprada: 1,
        precioUmpProveedor: 12.0,
        totalPagoLote: 12.0,
        unidadesPorLote: 4, // 4 ingresantes
        costoUnitarioSugerido: 18.0,
        factorGananciaVentaSugerido: 1.35,
        precioVentaSugerido: 24.30,
        matchPresentacion: MatchResult(
          estado: "MATCH_EXACTO",
          confianza: 100,
          datos: MatchData(id: 10, nombre: "½ Docena", stockActual: 4, unidadesPorVenta: 6, unidadVenta: "½ Docena"),
        ),
      );
      principal.stockOperation = 'sumar';

      final group = StagingProductGroup(
        uuidTemporal: "grp-1",
        nombrePadre: "Producto Prueba",
        marcaTexto: "Genérica",
        matchMarca: MatchResult(estado: "NUEVO", confianza: 0),
        variantes: [principal],
        matchProducto: MatchResult(estado: "MATCH_EXACTO", confianza: 100, datos: MatchData(id: 1, nombre: "Producto Prueba")),
      );

      final staging = StagingResponse(
        proveedorMatch: MatchResult(estado: "NUEVO", confianza: 0),
        proveedorTexto: "Distribuidora Test",
        productosAgrupados: [group],
      );

      provider.setStagingDataForTesting(staging);

      // Total base: 4 BD + 4 ingreso = 8 unidades.
      // Paquetes completos de 6: 1 (6 unid.). Sobrante: 2 unid.
      expect(principal.calculateTotalUnitsBase(stockActualBD: 4), equals(8));

      // 1. Simular acción [➕ Enviar 2 unid. a variante 'Unidad (x1)'] desde adentro del modal
      provider.createLeftoverVariant("var-principal", 2);

      // La variante principal queda ajustada con 2 unidades ingresantes (para completar 4 BD + 2 = 6 unid.)
      expect(principal.stockIngresanteOverride, equals(2));
      expect(group.variantes.length, equals(2));
      final leftoverVar = group.variantes.last;
      expect(leftoverVar.stockIngresanteOverride, equals(2));
      expect(leftoverVar.effectiveUnidadVenta, equals("Unidad"));
      expect(leftoverVar.effectiveFactorVenta, equals(1));

      // 2. Simular el recálculo en vivo del modal: _stockIngresanteCtrl.text = principal.stockIngresanteOverride.toString()
      String stockCtrlText = principal.stockIngresanteOverride.toString(); // '2'
      expect(stockCtrlText, equals("2"));

      // 3. Simular que el usuario presiona [GUARDAR DECISIÓN] (_applyChanges):
      int baselineStock = (principal.originalCantidadUmpComprada * principal.originalUnidadesPorLote).toInt();
      int? enteredStock = int.tryParse(stockCtrlText);
      if (enteredStock != null && enteredStock != baselineStock) {
        principal.stockIngresanteOverride = enteredStock;
      }
      
      // BLINDAJE: principal.stockIngresanteOverride JAMÁS se vuelve null ni vuelve a 4
      expect(principal.stockIngresanteOverride, equals(2));
      expect(principal.stockIngresanteBase, equals(2));

      // El stock total resultante en la principal es 4 BD + 2 ingreso = 6 unid. base (exactamente 1 paquete)
      expect(principal.calculateTotalUnitsBase(stockActualBD: 4), equals(6));
      expect(provider.hasUnresolvedStock, isFalse);
    });

    test('Punto 1.1: Chips de Divisores Exactos calculados dinámicamente para Sobrante y Déficit', () {
      // Cálculo de divisores exactos para 8 unidades base (actual factor 6)
      List<int> calculateExactDivisors(int totalBase, int currentFactor) {
        if (totalBase <= 0) return [];
        List<int> divisores = [];
        List<int> candidates = [1, 2, 3, 4, 5, 6, 8, 10, 12, 24, 25, 50, 100, 144];
        for (int d in candidates) {
          if (d <= totalBase && totalBase % d == 0 && d != currentFactor) {
            divisores.add(d);
          }
        }
        for (int d = 1; d <= totalBase && d <= 144; d++) {
          if (totalBase % d == 0 && d != currentFactor && !divisores.contains(d)) {
            divisores.add(d);
          }
        }
        divisores.sort();
        return divisores;
      }

      // Caso 8 unidades (Sobrante con factor 6)
      final div8 = calculateExactDivisors(8, 6);
      expect(div8, equals([1, 2, 4, 8]));

      // Caso 4 unidades (Déficit con factor 6)
      final div4 = calculateExactDivisors(4, 6);
      expect(div4, equals([1, 2, 4]));
    });

    test('Punto 2: Reinicio automático de allowLeftoverInReserve y allowDeficitApproved ante cambios', () {
      final variant = StagingVariant(
        uuidTemporal: "var-flags",
        nombreEspecifico: "Prueba Flags",
        unidadVenta: "Docena",
        unidadesPorVenta: 12,
        umpCompra: "Paquete",
        cantidadUmpComprada: 1,
        precioUmpProveedor: 10.0,
        totalPagoLote: 10.0,
        unidadesPorLote: 8,
        costoUnitarioSugerido: 10.0,
        factorGananciaVentaSugerido: 1.35,
        precioVentaSugerido: 13.50,
        matchPresentacion: MatchResult(estado: "NUEVO", confianza: 0),
      );

      // Activar flags
      variant.allowLeftoverInReserve = true;
      variant.allowDeficitApproved = true;

      // 1. Cambiar stockOperation a 'reemplazar' debe resetear ambos flags
      variant.stockOperation = 'reemplazar';
      expect(variant.allowLeftoverInReserve, isFalse);
      expect(variant.allowDeficitApproved, isFalse);

      // Volver a activar
      variant.allowLeftoverInReserve = true;
      variant.allowDeficitApproved = true;

      // 2. Cambiar stockOperation de vuelta a 'sumar' debe resetear ambos flags
      variant.stockOperation = 'sumar';
      expect(variant.allowLeftoverInReserve, isFalse);
      expect(variant.allowDeficitApproved, isFalse);

      // Volver a activar
      variant.allowLeftoverInReserve = true;
      variant.allowDeficitApproved = true;

      // 3. Llamar a resetStockAuthorizationFlags explícitamente (ejecutado al editar factor, unidad o stock)
      variant.resetStockAuthorizationFlags();
      expect(variant.allowLeftoverInReserve, isFalse);
      expect(variant.allowDeficitApproved, isFalse);
    });

    test('Punto 3: Persistencia SQLite para variante principal ajustada + variante sobrante sin colisiones', () {
      final principal = StagingVariant(
        uuidTemporal: "v-princ",
        nombreEspecifico: "½ Docena",
        unidadVenta: "½ Docena",
        unidadesPorVenta: 6,
        umpCompra: "Paquete",
        cantidadUmpComprada: 1,
        precioUmpProveedor: 12.0,
        totalPagoLote: 12.0,
        unidadesPorLote: 4,
        costoUnitarioSugerido: 18.0,
        factorGananciaVentaSugerido: 1.35,
        precioVentaSugerido: 24.30,
        matchPresentacion: MatchResult(
          estado: "MATCH_EXACTO",
          confianza: 100,
          datos: MatchData(id: 10, nombre: "½ Docena", stockActual: 4, unidadesPorVenta: 6, unidadVenta: "½ Docena"),
        ),
      );
      principal.stockOperation = 'sumar';
      principal.stockIngresanteOverride = 2; // Ajustado a 2 unidades base

      final leftover = StagingVariant(
        uuidTemporal: "v-leftover",
        nombreEspecifico: "½ Docena - Unidad",
        unidadVenta: "Unidad",
        unidadesPorVenta: 1,
        umpCompra: "Unidad",
        cantidadUmpComprada: 0,
        precioUmpProveedor: 0,
        totalPagoLote: 0,
        unidadesPorLote: 1,
        costoUnitarioSugerido: 3.0,
        factorGananciaVentaSugerido: 1.35,
        precioVentaSugerido: 4.05,
        matchPresentacion: MatchResult(estado: "NUEVO_EN_PADRE", confianza: 0),
      );
      leftover.stockIngresanteOverride = 2; // 2 unidades base sobrantes

      // Validar mapeo de SQLite para la variante principal (UPDATE)
      int stockActualBD = 4;
      int cantidadSumarPrincipal = principal.stockIngresanteBase;
      expect(cantidadSumarPrincipal, equals(2));

      Map<String, dynamic> updateData = {
        'stock_actual': principal.stockOperation == 'reemplazar'
            ? cantidadSumarPrincipal
            : (stockActualBD + cantidadSumarPrincipal),
        'unidad_venta': principal.effectiveUnidadVenta,
        'unidades_por_venta': principal.effectiveFactorVenta,
      };

      expect(updateData['stock_actual'], equals(6)); // 4 actual + 2 ingreso = 6
      expect(updateData['unidad_venta'], equals("½ Docena"));
      expect(updateData['unidades_por_venta'], equals(6));

      // Validar mapeo de SQLite para la variante sobrante (INSERT)
      int cantidadSumarLeftover = leftover.stockIngresanteBase;
      expect(cantidadSumarLeftover, equals(2));

      Map<String, dynamic> insertData = {
        'producto_id': 1,
        'nombre_especifico': leftover.nombreEspecifico,
        'unidad_venta': leftover.effectiveUnidadVenta,
        'unidades_por_venta': leftover.effectiveFactorVenta,
        'stock_actual': cantidadSumarLeftover,
        'es_default': 0,
      };

      expect(insertData['producto_id'], equals(1));
      expect(insertData['stock_actual'], equals(2));
      expect(insertData['unidad_venta'], equals("Unidad"));
      expect(insertData['unidades_por_venta'], equals(1));

      // TOTAL FÍSICO COMBINADO: 6 + 2 = 8 unidades base
      int totalEnSQLite = (updateData['stock_actual'] as int) + (insertData['stock_actual'] as int);
      expect(totalEnSQLite, equals(8));
    });
  });
}
