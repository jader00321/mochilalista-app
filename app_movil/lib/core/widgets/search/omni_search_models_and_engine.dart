import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'package:app_movil/core/widgets/search/omni_search_models.dart';
import 'package:app_movil/features/scanner/services/spanish_lemmatizer.dart';

export 'package:app_movil/core/widgets/search/omni_search_models.dart';

class OmniSearchEngine {
  OmniSearchEngine._();

  /// Helper SQL para normalizar y eliminar tildes directamente en SQLite.
  /// SQLite LOWER() solo opera en ASCII (A-Z). Reemplazamos tanto minúsculas como mayúsculas con tilde y diéresis.
  static String sqlUnaccent(String expr) {
    return "REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LOWER(IFNULL($expr, '')), 'á', 'a'), 'é', 'e'), 'í', 'i'), 'ó', 'o'), 'ú', 'u'), 'Á', 'a'), 'É', 'e'), 'Í', 'i'), 'Ó', 'o'), 'Ú', 'u'), 'ü', 'u'), 'Ü', 'u')";
  }

  /// Helper Dart para normalizar texto a minúsculas sin tildes ni diéresis.
  static String normalizeText(String text) {
    return text
        .toLowerCase()
        .trim()
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

  static double scoreItem(
    String title,
    String? secondary,
    String? code,
    String query,
  ) {
    double score = 0;
    final normTitle = normalizeText(title);
    final normSec = normalizeText(secondary ?? '');
    final normQ = normalizeText(query);
    final tokens = normQ
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    if (normTitle == normQ ||
        (code != null &&
            code.trim().isNotEmpty &&
            code.trim() == query.trim())) {
      score += 100;
    }
    if (normQ.isNotEmpty && normTitle.startsWith(normQ)) score += 60;
    if (normQ.isNotEmpty && normSec.startsWith(normQ)) score += 30;

    for (final t in tokens) {
      if (normTitle.contains(t)) score += 20;
      if (normSec.contains(t)) score += 10;
    }
    return score;
  }

  static double extractNumericValue(Map<String, dynamic> item) {
    final raw =
        item['precio_venta_final'] ??
        item['total_amount'] ??
        item['monto_total'] ??
        item['deuda_total'];
    if (raw == null) return 0.0;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString()) ?? 0.0;
  }

  static List<Map<String, dynamic>> sortResults(
    List<Map<String, dynamic>> list,
    String entityType,
    OmniSortOption sortOption,
    String query,
  ) {
    final copy = List<Map<String, dynamic>>.from(list);
    final trimmedQuery = query.trim();

    switch (sortOption) {
      case OmniSortOption.relevance:
        if (trimmedQuery.isNotEmpty) {
          copy.sort((a, b) {
            double scoreA = 0;
            double scoreB = 0;
            if (entityType == 'products') {
              scoreA = scoreItem(
                "${a['producto_nombre'] ?? ''} ${a['nombre_especifico'] ?? ''}",
                a['marca_nombre']?.toString(),
                a['codigo_barras']?.toString(),
                trimmedQuery,
              );
              scoreB = scoreItem(
                "${b['producto_nombre'] ?? ''} ${b['nombre_especifico'] ?? ''}",
                b['marca_nombre']?.toString(),
                b['codigo_barras']?.toString(),
                trimmedQuery,
              );
            } else if (entityType == 'clients') {
              scoreA = scoreItem(
                a['nombre_completo']?.toString() ?? '',
                a['dni_ruc']?.toString(),
                a['telefono']?.toString(),
                trimmedQuery,
              );
              scoreB = scoreItem(
                b['nombre_completo']?.toString() ?? '',
                b['dni_ruc']?.toString(),
                b['telefono']?.toString(),
                trimmedQuery,
              );
            } else if (entityType == 'quotes') {
              scoreA = scoreItem(
                a['client_name']?.toString() ?? '',
                a['institution_name']?.toString(),
                a['id']?.toString(),
                trimmedQuery,
              );
              scoreB = scoreItem(
                b['client_name']?.toString() ?? '',
                b['institution_name']?.toString(),
                b['id']?.toString(),
                trimmedQuery,
              );
            } else if (entityType == 'sales') {
              scoreA = scoreItem(
                a['cliente_nombre']?.toString() ?? '',
                a['metodo_pago']?.toString(),
                a['numero_secuencial']?.toString(),
                trimmedQuery,
              );
              scoreB = scoreItem(
                b['cliente_nombre']?.toString() ?? '',
                b['metodo_pago']?.toString(),
                b['numero_secuencial']?.toString(),
                trimmedQuery,
              );
            }
            return scoreB.compareTo(scoreA);
          });
        }
        break;

      case OmniSortOption.recent:
        copy.sort((a, b) {
          final idA = (a['presentation_id'] ?? a['id'] ?? 0) as int;
          final idB = (b['presentation_id'] ?? b['id'] ?? 0) as int;
          return idB.compareTo(idA);
        });
        break;

      case OmniSortOption.az:
        copy.sort((a, b) {
          String nameA = '';
          String nameB = '';
          if (entityType == 'products') {
            nameA =
                "${a['producto_nombre'] ?? ''} ${a['nombre_especifico'] ?? ''}"
                    .trim();
            nameB =
                "${b['producto_nombre'] ?? ''} ${b['nombre_especifico'] ?? ''}"
                    .trim();
          } else if (entityType == 'clients') {
            nameA = (a['nombre_completo'] ?? '').toString();
            nameB = (b['nombre_completo'] ?? '').toString();
          } else if (entityType == 'quotes') {
            nameA = (a['client_name'] ?? '').toString();
            nameB = (b['client_name'] ?? '').toString();
          } else if (entityType == 'sales') {
            nameA = (a['cliente_nombre'] ?? '').toString();
            nameB = (b['cliente_nombre'] ?? '').toString();
          }
          return nameA.toLowerCase().compareTo(nameB.toLowerCase());
        });
        break;

      case OmniSortOption.priceDesc:
        copy.sort((a, b) {
          final valA = extractNumericValue(a);
          final valB = extractNumericValue(b);
          return valB.compareTo(valA);
        });
        break;

      case OmniSortOption.priceAsc:
        copy.sort((a, b) {
          final valA = extractNumericValue(a);
          final valB = extractNumericValue(b);
          return valA.compareTo(valB);
        });
        break;
    }
    return copy;
  }

  /// Consulta a SQLite para obtener los conteos reales totales de cada categoría.
  static Future<OmniSearchCounts> loadDatabaseCounts(
    Database db,
    int businessId,
  ) async {
    final prodsCountRes = await db.rawQuery(
      '''
      SELECT COUNT(*) as c
      FROM presentaciones_producto pr
      JOIN productos p ON pr.producto_id = p.id
      WHERE p.negocio_id = ? AND pr.activo = 1
      ''',
      [businessId],
    );
    final int countProds = (prodsCountRes.first['c'] as num?)?.toInt() ?? 0;

    final clientsCountRes = await db.rawQuery(
      '''
      SELECT COUNT(*) as c
      FROM clientes
      WHERE negocio_id = ?
      ''',
      [businessId],
    );
    final int countClients = (clientsCountRes.first['c'] as num?)?.toInt() ?? 0;

    final quotesCountRes = await db.rawQuery(
      '''
      SELECT COUNT(*) as c
      FROM smart_quotations
      WHERE negocio_id = ? 
        AND LOWER(IFNULL(status, '')) NOT IN ('vendida', 'sold', 'annulled', 'anulada')
      ''',
      [businessId],
    );
    final int countQuotes = (quotesCountRes.first['c'] as num?)?.toInt() ?? 0;

    final salesCountRes = await db.rawQuery(
      '''
      SELECT COUNT(*) as c
      FROM ventas
      WHERE negocio_id = ? AND is_archived = 0
      ''',
      [businessId],
    );
    final int countSales = (salesCountRes.first['c'] as num?)?.toInt() ?? 0;

    return OmniSearchCounts(
      products: countProds,
      clients: countClients,
      quotes: countQuotes,
      sales: countSales,
    );
  }

  /// Carga registros recientes por defecto cuando el buscador se abre vacío.
  static Future<OmniSearchResults> loadRecentDefaults(
    Database db,
    int businessId,
    String activeCategory,
  ) async {
    final bool loadProds =
        activeCategory == 'all' || activeCategory == 'products';
    final bool loadClients =
        activeCategory == 'all' || activeCategory == 'clients';
    final bool loadQuotes =
        activeCategory == 'all' || activeCategory == 'quotes';
    final bool loadSales = activeCategory == 'all' || activeCategory == 'sales';

    List<Map<String, dynamic>> prods = [];
    if (loadProds) {
      try {
        final int limit = activeCategory == 'products' ? 1000 : 30;
        prods = await db.rawQuery(
          '''
          SELECT pr.id as presentation_id, pr.nombre_especifico, pr.precio_venta_final, pr.precio_oferta,
                 pr.stock_actual, pr.stock_alerta, pr.unidad_venta, pr.unidades_por_venta, pr.codigo_barras,
                 pr.imagen_url as pres_img, p.id as product_id, p.nombre as producto_nombre,
                 p.imagen_url as prod_img, m.nombre as marca_nombre, c.nombre as categoria_nombre
          FROM presentaciones_producto pr
          JOIN productos p ON pr.producto_id = p.id
          LEFT JOIN marcas m ON p.marca_id = m.id
          LEFT JOIN categorias c ON p.categoria_id = c.id
          WHERE p.negocio_id = ? AND pr.activo = 1
          ORDER BY pr.id DESC
          LIMIT ?
          ''',
          [businessId, limit],
        );
      } catch (_) {}
    }

    List<Map<String, dynamic>> clients = [];
    if (loadClients) {
      try {
        final int limit = activeCategory == 'clients' ? 1000 : 25;
        clients = await db.rawQuery(
          '''
          SELECT id, nombre_completo, telefono, dni_ruc, saldo_a_favor, deuda_total, nivel_confianza, notas
          FROM clientes
          WHERE negocio_id = ?
          ORDER BY id DESC
          LIMIT ?
          ''',
          [businessId, limit],
        );
      } catch (_) {}
    }

    List<Map<String, dynamic>> quotes = [];
    if (loadQuotes) {
      try {
        final int limit = activeCategory == 'quotes' ? 1000 : 25;
        quotes = await db.rawQuery(
          '''
          SELECT sq.id, sq.numero_secuencial, sq.client_name, sq.client_id, sq.institution_name,
                 sq.grade_level, sq.total_amount, sq.status, sq.created_at
          FROM smart_quotations sq
          WHERE sq.negocio_id = ? 
            AND LOWER(IFNULL(sq.status, '')) NOT IN ('vendida', 'sold', 'annulled', 'anulada')
          ORDER BY sq.id DESC
          LIMIT ?
          ''',
          [businessId, limit],
        );
      } catch (_) {}
    }

    List<Map<String, dynamic>> sales = [];
    if (loadSales) {
      try {
        final int limit = activeCategory == 'sales' ? 1000 : 25;
        sales = await db.rawQuery(
          '''
          SELECT v.id, v.numero_secuencial, v.monto_total, v.fecha_venta, v.metodo_pago, v.estado_pago,
                 c.nombre_completo as cliente_nombre
          FROM ventas v
          LEFT JOIN clientes c ON v.cliente_id = c.id
          WHERE v.negocio_id = ? AND v.is_archived = 0
          ORDER BY v.id DESC
          LIMIT ?
          ''',
          [businessId, limit],
        );
      } catch (_) {}
    }

    return OmniSearchResults(
      products: List.from(prods),
      clients: List.from(clients),
      quotes: List.from(quotes),
      sales: List.from(sales),
    );
  }

  static Future<OmniSearchResults> performSearch(
    Database db,
    int businessId,
    String term,
    String activeCategory,
  ) async {
    final tokens = term
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) {
      return loadRecentDefaults(db, businessId, activeCategory);
    }

    final bool searchProds =
        activeCategory == 'all' || activeCategory == 'products';
    final bool searchClients =
        activeCategory == 'all' || activeCategory == 'clients';
    final bool searchQuotes =
        activeCategory == 'all' || activeCategory == 'quotes';
    final bool searchSales =
        activeCategory == 'all' || activeCategory == 'sales';

    List<Map<String, dynamic>> prods = [];
    if (searchProds) {
      try {
        final List<String> prodConditions = [];
        final List<dynamic> prodArgs = [businessId];

        for (final token in tokens) {
          final norm = normalizeText(token);
          final lem = SpanishLemmatizer.lemmatize(norm);

          if (norm == lem) {
            prodConditions.add('''
              (
                ${sqlUnaccent('p.nombre')} LIKE ? OR
                ${sqlUnaccent('pr.nombre_especifico')} LIKE ? OR
                ${sqlUnaccent('m.nombre')} LIKE ? OR
                ${sqlUnaccent('c.nombre')} LIKE ? OR
                IFNULL(pr.codigo_barras, '') LIKE ? OR
                IFNULL(p.codigo_barras, '') LIKE ?
              )
            ''');
            final pArg = '%$norm%';
            prodArgs.addAll([pArg, pArg, pArg, pArg, pArg, pArg]);
          } else {
            prodConditions.add('''
              (
                ${sqlUnaccent('p.nombre')} LIKE ? OR ${sqlUnaccent('p.nombre')} LIKE ? OR
                ${sqlUnaccent('pr.nombre_especifico')} LIKE ? OR ${sqlUnaccent('pr.nombre_especifico')} LIKE ? OR
                ${sqlUnaccent('m.nombre')} LIKE ? OR ${sqlUnaccent('m.nombre')} LIKE ? OR
                ${sqlUnaccent('c.nombre')} LIKE ? OR ${sqlUnaccent('c.nombre')} LIKE ? OR
                IFNULL(pr.codigo_barras, '') LIKE ? OR
                IFNULL(p.codigo_barras, '') LIKE ?
              )
            ''');
            final pArg1 = '%$norm%';
            final pArg2 = '%$lem%';
            prodArgs.addAll([
              pArg1,
              pArg2,
              pArg1,
              pArg2,
              pArg1,
              pArg2,
              pArg1,
              pArg2,
              pArg1,
              pArg1,
            ]);
          }
        }

        final int limit = activeCategory == 'products' ? 1000 : 35;
        prodArgs.add(limit);

        final prodsRaw = await db.rawQuery('''
          SELECT pr.id as presentation_id, pr.nombre_especifico, pr.precio_venta_final, pr.precio_oferta,
                 pr.stock_actual, pr.stock_alerta, pr.unidad_venta, pr.unidades_por_venta, pr.codigo_barras,
                 pr.imagen_url as pres_img, p.id as product_id, p.nombre as producto_nombre,
                 p.imagen_url as prod_img, m.nombre as marca_nombre, c.nombre as categoria_nombre
          FROM presentaciones_producto pr
          JOIN productos p ON pr.producto_id = p.id
          LEFT JOIN marcas m ON p.marca_id = m.id
          LEFT JOIN categorias c ON p.categoria_id = c.id
          WHERE p.negocio_id = ? AND pr.activo = 1 AND ${prodConditions.join(' AND ')}
          LIMIT ?
          ''', prodArgs);
        prods = List.from(prodsRaw);
      } catch (e) {
        debugPrint("Error buscando productos omnicanal: $e");
      }
    }

    List<Map<String, dynamic>> clients = [];
    if (searchClients) {
      try {
        final List<String> clientConditions = [];
        final List<dynamic> clientArgs = [businessId];

        for (final token in tokens) {
          final norm = normalizeText(token);
          clientConditions.add('''
            (
              ${sqlUnaccent('c.nombre_completo')} LIKE ? OR
              IFNULL(c.telefono, '') LIKE ? OR
              IFNULL(c.dni_ruc, '') LIKE ? OR
              ${sqlUnaccent('c.notas')} LIKE ?
            )
          ''');
          final cArg = '%$norm%';
          clientArgs.addAll([cArg, cArg, cArg, cArg]);
        }

        final int limit = activeCategory == 'clients' ? 1000 : 35;
        clientArgs.add(limit);

        final clientsRaw = await db.rawQuery('''
          SELECT id, nombre_completo, telefono, dni_ruc, saldo_a_favor, deuda_total, nivel_confianza, notas
          FROM clientes c
          WHERE c.negocio_id = ? AND ${clientConditions.join(' AND ')}
          LIMIT ?
          ''', clientArgs);
        clients = List.from(clientsRaw);
      } catch (e) {
        debugPrint("Error buscando clientes omnicanal: $e");
      }
    }

    List<Map<String, dynamic>> quotes = [];
    if (searchQuotes) {
      try {
        final List<String> quoteConditions = [];
        final List<dynamic> quoteArgs = [businessId];

        for (final token in tokens) {
          final norm = normalizeText(token);
          quoteConditions.add('''
            (
              ${sqlUnaccent('sq.client_name')} LIKE ? OR
              ${sqlUnaccent('sq.institution_name')} LIKE ? OR
              ${sqlUnaccent('sq.grade_level')} LIKE ? OR
              CAST(sq.id AS TEXT) LIKE ? OR
              CAST(IFNULL(sq.numero_secuencial, sq.id) AS TEXT) LIKE ? OR
              ${sqlUnaccent('sq.status')} LIKE ?
            )
          ''');
          final qArg = '%$norm%';
          quoteArgs.addAll([qArg, qArg, qArg, qArg, qArg, qArg]);
        }

        final int limit = activeCategory == 'quotes' ? 1000 : 35;
        quoteArgs.add(limit);

        final quotesRaw = await db.rawQuery('''
          SELECT sq.id, sq.numero_secuencial, sq.client_name, sq.client_id, sq.institution_name,
                 sq.grade_level, sq.total_amount, sq.status, sq.created_at
          FROM smart_quotations sq
          WHERE sq.negocio_id = ? 
            AND LOWER(IFNULL(sq.status, '')) NOT IN ('vendida', 'sold', 'annulled', 'anulada') 
            AND ${quoteConditions.join(' AND ')}
          ORDER BY sq.id DESC
          LIMIT ?
          ''', quoteArgs);
        quotes = List.from(quotesRaw);
      } catch (e) {
        debugPrint("Error buscando cotizaciones omnicanal: $e");
      }
    }

    List<Map<String, dynamic>> sales = [];
    if (searchSales) {
      try {
        final List<String> saleConditions = [];
        final List<dynamic> saleArgs = [businessId];

        for (final token in tokens) {
          final norm = normalizeText(token);
          saleConditions.add('''
            (
              ${sqlUnaccent('c.nombre_completo')} LIKE ? OR
              CAST(v.id AS TEXT) LIKE ? OR
              CAST(IFNULL(v.numero_secuencial, v.id) AS TEXT) LIKE ? OR
              ${sqlUnaccent('v.metodo_pago')} LIKE ? OR
              ${sqlUnaccent('v.estado_pago')} LIKE ? OR
              CAST(v.monto_total AS TEXT) LIKE ?
            )
          ''');
          final sArg = '%$norm%';
          saleArgs.addAll([sArg, sArg, sArg, sArg, sArg, sArg]);
        }

        final int limit = activeCategory == 'sales' ? 1000 : 35;
        saleArgs.add(limit);

        final salesRaw = await db.rawQuery('''
          SELECT v.id, v.numero_secuencial, v.monto_total, v.fecha_venta, v.metodo_pago, v.estado_pago,
                 c.nombre_completo as cliente_nombre
          FROM ventas v
          LEFT JOIN clientes c ON v.cliente_id = c.id
          WHERE v.negocio_id = ? AND v.is_archived = 0 AND ${saleConditions.join(' AND ')}
          ORDER BY v.id DESC
          LIMIT ?
          ''', saleArgs);
        sales = List.from(salesRaw);
      } catch (e) {
        debugPrint("Error buscando ventas omnicanal: $e");
      }
    }

    return OmniSearchResults(
      products: prods,
      clients: clients,
      quotes: quotes,
      sales: sales,
    );
  }

  static List<OmniListItem> buildVirtualizedItems({
    required String activeCategory,
    required List<Map<String, dynamic>> sortedProducts,
    required List<Map<String, dynamic>> sortedClients,
    required List<Map<String, dynamic>> sortedQuotes,
    required List<Map<String, dynamic>> sortedSales,
  }) {
    final List<OmniListItem> listItems = [];

    if ((activeCategory == 'all' || activeCategory == 'products') &&
        sortedProducts.isNotEmpty) {
      listItems.add(
        OmniHeaderItem(
          "PRODUCTOS",
          sortedProducts.length,
          icon: Icons.inventory_2_outlined,
        ),
      );
      for (final p in sortedProducts) {
        listItems.add(OmniProductItem(p));
      }
      listItems.add(const OmniSpacerItem());
    }

    if ((activeCategory == 'all' || activeCategory == 'clients') &&
        sortedClients.isNotEmpty) {
      listItems.add(
        OmniHeaderItem(
          "CLIENTES",
          sortedClients.length,
          icon: Icons.person_outline_rounded,
        ),
      );
      for (final c in sortedClients) {
        listItems.add(OmniClientItem(c));
      }
      listItems.add(const OmniSpacerItem());
    }

    if ((activeCategory == 'all' || activeCategory == 'quotes') &&
        sortedQuotes.isNotEmpty) {
      listItems.add(
        OmniHeaderItem(
          "COTIZACIONES",
          sortedQuotes.length,
          icon: Icons.description_outlined,
        ),
      );
      for (final q in sortedQuotes) {
        listItems.add(OmniQuoteItem(q));
      }
      listItems.add(const OmniSpacerItem());
    }

    if ((activeCategory == 'all' || activeCategory == 'sales') &&
        sortedSales.isNotEmpty) {
      listItems.add(
        OmniHeaderItem(
          "VENTAS",
          sortedSales.length,
          icon: Icons.receipt_long_outlined,
        ),
      );
      for (final s in sortedSales) {
        listItems.add(OmniSaleItem(s));
      }
      listItems.add(const OmniSpacerItem());
    }

    return listItems;
  }
}
