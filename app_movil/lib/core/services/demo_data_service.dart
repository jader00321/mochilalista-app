import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/models/category_model.dart';
import 'package:app_movil/features/catalog/models/brand_model.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';

/// Proveedor de datos de demostración realistas para el Modo Explorador.
///
/// Garantiza que cualquier usuario que navegue sin haber registrado aún su negocio
/// experimente una aplicación viva, visualmente impactante y rica en datos
/// (productos de librería/bazar, cotizaciones y métricas) con CERO errores de SQLite.
class DemoDataService {
  DemoDataService._();

  static final List<Category> demoCategories = [
    Category(id: 901, nombre: "Cuadernos y Papelería", descripcion: "Cuadernos, resmas y blocks", activo: true, productsCount: 2),
    Category(id: 902, nombre: "Escritura y Corrección", descripcion: "Lapiceros, plumones y correctores", activo: true, productsCount: 2),
    Category(id: 903, nombre: "Arte y Manualidades", descripcion: "Colores, témperas y plastilinas", activo: true, productsCount: 2),
    Category(id: 904, nombre: "Adhesivos y Corte", descripcion: "Gomas, cintas y tijeras", activo: true, productsCount: 1),
    Category(id: 905, nombre: "Mochilas y Cartucheras", descripcion: "Mochilas ergonómicas y estuches", activo: true, productsCount: 1),
  ];

  static final List<Brand> demoBrands = [
    Brand(id: 801, nombre: "Standford", activo: true, productsCount: 2),
    Brand(id: 802, nombre: "Faber-Castell", activo: true, productsCount: 2),
    Brand(id: 803, nombre: "Artesco", activo: true, productsCount: 2),
    Brand(id: 804, nombre: "Pritt", activo: true, productsCount: 1),
    Brand(id: 805, nombre: "Norma", activo: true, productsCount: 1),
  ];

  static final List<InventoryWrapper> demoInventory = [
    InventoryWrapper(
      product: Product(
        id: 1001,
        nombre: "Cuaderno Standford A4 Cuadriculado 100H",
        descripcion: "Papel bond 75g carátula plastificada premium",
        codigoBarras: "775012300101",
        categoriaId: 901,
        marcaId: 801,
        marcaNombre: "Standford",
        estado: "publico",
        stockTotalCalculado: 48,
      ),
      presentation: ProductPresentation(
        id: 2001,
        nombreEspecifico: "Unidad Cuaderno A4",
        precioVentaFinal: 6.50,
        costoUnitarioCalculado: 4.20,
        stockActual: 48,
        unidadVenta: "Unidad",
        unidadesPorVenta: 1,
        esDefault: true,
        orden: 1,
      ),
    ),
    InventoryWrapper(
      product: Product(
        id: 1002,
        nombre: "Caja de Colores Faber-Castell x 24 Largos",
        descripcion: "Mina súper suave de 3.3mm con máxima cobertura",
        codigoBarras: "775012300102",
        categoriaId: 903,
        marcaId: 802,
        marcaNombre: "Faber-Castell",
        estado: "publico",
        stockTotalCalculado: 25,
      ),
      presentation: ProductPresentation(
        id: 2002,
        nombreEspecifico: "Caja x 24 colores",
        precioVentaFinal: 18.00,
        costoUnitarioCalculado: 12.50,
        stockActual: 25,
        unidadVenta: "Caja",
        unidadesPorVenta: 1,
        esDefault: true,
        orden: 1,
      ),
    ),
    InventoryWrapper(
      product: Product(
        id: 1003,
        nombre: "Estuche Plumones Artesco Dúo x 12",
        descripcion: "Doble punta fina y biselada, tinta lavable no tóxica",
        codigoBarras: "775012300103",
        categoriaId: 902,
        marcaId: 803,
        marcaNombre: "Artesco",
        estado: "publico",
        stockTotalCalculado: 32,
      ),
      presentation: ProductPresentation(
        id: 2003,
        nombreEspecifico: "Estuche x 12 plumones",
        precioVentaFinal: 11.50,
        costoUnitarioCalculado: 7.80,
        stockActual: 32,
        unidadVenta: "Estuche",
        unidadesPorVenta: 1,
        esDefault: true,
        orden: 1,
      ),
    ),
    InventoryWrapper(
      product: Product(
        id: 1004,
        nombre: "Pegamento en Barra Pritt 40g",
        descripcion: "Fórmula 97% ingredientes naturales, secado rápido",
        codigoBarras: "775012300104",
        categoriaId: 904,
        marcaId: 804,
        marcaNombre: "Pritt",
        estado: "publico",
        stockTotalCalculado: 18,
      ),
      presentation: ProductPresentation(
        id: 2004,
        nombreEspecifico: "Barra 40 gramos",
        precioVentaFinal: 7.00,
        costoUnitarioCalculado: 4.80,
        stockActual: 18,
        unidadVenta: "Unidad",
        unidadesPorVenta: 1,
        esDefault: true,
        orden: 1,
      ),
    ),
    InventoryWrapper(
      product: Product(
        id: 1005,
        nombre: "Resma Papel Bond Chamex A4 75g (500 hojas)",
        descripcion: "Papel blanco alcalino óptimo para impresiones láser y tinta",
        codigoBarras: "775012300105",
        categoriaId: 901,
        marcaId: 805,
        marcaNombre: "Norma",
        estado: "publico",
        stockTotalCalculado: 14,
      ),
      presentation: ProductPresentation(
        id: 2005,
        nombreEspecifico: "Resma 500 hojas",
        precioVentaFinal: 17.50,
        costoUnitarioCalculado: 13.00,
        stockActual: 14,
        unidadVenta: "Paquete",
        unidadesPorVenta: 1,
        esDefault: true,
        orden: 1,
      ),
    ),
    InventoryWrapper(
      product: Product(
        id: 1006,
        nombre: "Lapicero Faber-Castell Trilux 032 Medium Azul",
        descripcion: "Forma ergonómica triangular con punta metálica",
        codigoBarras: "775012300106",
        categoriaId: 902,
        marcaId: 802,
        marcaNombre: "Faber-Castell",
        estado: "publico",
        stockTotalCalculado: 120,
      ),
      presentation: ProductPresentation(
        id: 2006,
        nombreEspecifico: "Unidad Lapicero Azul",
        precioVentaFinal: 1.50,
        costoUnitarioCalculado: 0.85,
        stockActual: 120,
        unidadVenta: "Unidad",
        unidadesPorVenta: 1,
        esDefault: true,
        orden: 1,
      ),
    ),
    InventoryWrapper(
      product: Product(
        id: 1007,
        nombre: "Témperas Artesco Set x 6 colores con pincel",
        descripcion: "Colores vivos de alta consistencia y solubles en agua",
        codigoBarras: "775012300107",
        categoriaId: 903,
        marcaId: 803,
        marcaNombre: "Artesco",
        estado: "publico",
        stockTotalCalculado: 22,
      ),
      presentation: ProductPresentation(
        id: 2007,
        nombreEspecifico: "Caja x 6 frascos + pincel",
        precioVentaFinal: 9.00,
        costoUnitarioCalculado: 5.90,
        stockActual: 22,
        unidadVenta: "Set",
        unidadesPorVenta: 1,
        esDefault: true,
        orden: 1,
      ),
    ),
    InventoryWrapper(
      product: Product(
        id: 1008,
        nombre: "Mochila Escolar Standford Reforzada",
        descripcion: "Compartimentos múltiples con soporte lumbar acolchado",
        codigoBarras: "775012300108",
        categoriaId: 905,
        marcaId: 801,
        marcaNombre: "Standford",
        estado: "publico",
        stockTotalCalculado: 9,
      ),
      presentation: ProductPresentation(
        id: 2008,
        nombreEspecifico: "Mochila Ergonómica Escolar",
        precioVentaFinal: 85.00,
        costoUnitarioCalculado: 55.00,
        stockActual: 9,
        unidadVenta: "Unidad",
        unidadesPorVenta: 1,
        esDefault: true,
        orden: 1,
      ),
    ),
  ];

  /// Cotizaciones demostrativas listas para probar la Mesa de Trabajo en Modo Explorador
  static final List<Map<String, dynamic>> demoQuotations = [
    {
      "id": 9001,
      "numero_secuencial": 101,
      "client_name": "Colegio San Agustín - Lista 3er Grado",
      "institution_name": "Colegio San Agustín",
      "grade_level": "3ro Primaria",
      "total_amount": 165.50,
      "total_savings": 22.00,
      "status": "APPROVED",
      "created_at": DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
    },
    {
      "id": 9002,
      "numero_secuencial": 102,
      "client_name": "María Eugenia Ramos - Útiles de Oficina",
      "institution_name": "Estudio Jurídico Ramos",
      "grade_level": "General",
      "total_amount": 89.00,
      "total_savings": 8.50,
      "status": "PENDING",
      "created_at": DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
    },
  ];

  /// Métricas simuladas para Inteligencia de Negocio en Modo Explorador
  static Map<String, dynamic> getDemoAnalytics() {
    return {
      "ventas_hoy": 348.50,
      "transacciones_hoy": 14,
      "ticket_promedio": 24.89,
      "margen_promedio_porcentaje": 38.4,
      "top_productos": [
        {"nombre": "Cuaderno Standford A4", "cantidad": 28, "ingresos": 182.00},
        {"nombre": "Colores Faber-Castell x 24", "cantidad": 6, "ingresos": 108.00},
        {"nombre": "Lapiceros Trilux Azul", "cantidad": 35, "ingresos": 52.50},
      ],
    };
  }
}
