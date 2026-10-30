import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/screens/product_detail_screen.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';
import 'package:app_movil/features/smart_quotation/screens/crm/client_detail_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/quotation_detail_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/sale_history_detail_screen.dart';
import 'package:app_movil/features/scanner/services/spanish_lemmatizer.dart';
import 'package:app_movil/core/widgets/universal_image.dart';

class OmniSearchBar extends StatelessWidget {
  final VoidCallback? onBarcodeTap;

  const OmniSearchBar({super.key, this.onBarcodeTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _openOmniSearchModal(context),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey.shade300,
            width: 1,
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              color: isDark ? Colors.blue[300] : Colors.blue[700],
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final String placeholderText = width >= 260
                      ? "Buscar productos, clientes o ventas"
                      : (width >= 190
                          ? "Buscar productos o clientes"
                          : "Buscar productos...");

                  return FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      placeholderText,
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[500],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                    ),
                  );
                },
              ),
            ),
            if (onBarcodeTap != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.qr_code_scanner_rounded,
                  color: isDark ? Colors.blue[300] : Colors.blue[600],
                  size: 22,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onBarcodeTap,
                tooltip: "Escanear código de barras",
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openOmniSearchModal(BuildContext context) {
    HapticFeedback.lightImpact();
    InteractiveSheetWrapper.show(
      context: context,
      builder: (ctx) => const _OmniSearchSheet(),
    );
  }
}

class _OmniSearchSheet extends StatefulWidget {
  const _OmniSearchSheet();

  @override
  State<_OmniSearchSheet> createState() => _OmniSearchSheetState();
}

enum OmniSortOption {
  relevance('Relevancia', Icons.auto_awesome_rounded),
  recent('Más Recientes', Icons.schedule_rounded),
  az('A - Z', Icons.sort_by_alpha_rounded),
  priceDesc('Mayor Precio', Icons.arrow_downward_rounded),
  priceAsc('Menor Precio', Icons.arrow_upward_rounded);

  final String label;
  final IconData icon;
  const OmniSortOption(this.label, this.icon);
}

class _OmniSearchSheetState extends State<_OmniSearchSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();  List<Map<String, dynamic>> _productResults = [];
  List<Map<String, dynamic>> _clientResults = [];
  List<Map<String, dynamic>> _quoteResults = [];
  List<Map<String, dynamic>> _saleResults = [];

  // Conteos reales en SQLite
  int _dbCountProducts = 0;
  int _dbCountClients = 0;
  int _dbCountQuotes = 0;
  int _dbCountSales = 0;

  bool _isSearching = false;
  String _activeCategory = 'all'; // all, products, clients, quotes, sales
  OmniSortOption _sortOption = OmniSortOption.relevance;
  final Set<String> _expandedKeys = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDatabaseCounts();
      _loadRecentDefaults();
      // ⏱️ Coordinación de foco para entrada limpia y continua sin doble salto
      Future.delayed(const Duration(milliseconds: 220), () {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 📊 Consulta a SQLite para obtener los conteos reales totales de cada categoría
  Future<void> _loadDatabaseCounts() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final businessId = auth.activeBusinessId ?? 1;
      final db = await LocalDatabase.instance.database;

      // 1. Total real de variantes / presentaciones registradas activas
      final prodsCountRes = await db.rawQuery('''
        SELECT COUNT(*) as c
        FROM presentaciones_producto pr
        JOIN productos p ON pr.producto_id = p.id
        WHERE p.negocio_id = ? AND pr.activo = 1
      ''', [businessId]);
      final int countProds = (prodsCountRes.first['c'] as num?)?.toInt() ?? 0;

      // 2. Total real de clientes en el directorio
      final clientsCountRes = await db.rawQuery('''
        SELECT COUNT(*) as c
        FROM clientes
        WHERE negocio_id = ?
      ''', [businessId]);
      final int countClients = (clientsCountRes.first['c'] as num?)?.toInt() ?? 0;

      // 3. Total real de cotizaciones activas (omitiendo las que ya fueron vendidas o anuladas)
      final quotesCountRes = await db.rawQuery('''
        SELECT COUNT(*) as c
        FROM smart_quotations
        WHERE negocio_id = ? 
          AND LOWER(IFNULL(status, '')) NOT IN ('vendida', 'sold', 'annulled', 'anulada')
      ''', [businessId]);
      final int countQuotes = (quotesCountRes.first['c'] as num?)?.toInt() ?? 0;

      // 4. Total real de ventas registradas en el sistema (ventas de caja rápida + cotizaciones convertidas)
      final salesCountRes = await db.rawQuery('''
        SELECT COUNT(*) as c
        FROM ventas
        WHERE negocio_id = ? AND is_archived = 0
      ''', [businessId]);
      final int countSales = (salesCountRes.first['c'] as num?)?.toInt() ?? 0;

      if (mounted) {
        setState(() {
          _dbCountProducts = countProds;
          _dbCountClients = countClients;
          _dbCountQuotes = countQuotes;
          _dbCountSales = countSales;
        });
      }
    } catch (e) {
      debugPrint("Error cargando conteos reales en omnicanal: $e");
    }
  }

  /// Helper SQL para normalizar y eliminar tildes directamente en SQLite.
  /// SQLite LOWER() solo opera en ASCII (A-Z). Reemplazamos tanto minúsculas como mayúsculas con tilde y diéresis.
  String _sqlUnaccent(String expr) {
    return "REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LOWER(IFNULL($expr, '')), 'á', 'a'), 'é', 'e'), 'í', 'i'), 'ó', 'o'), 'ú', 'u'), 'Á', 'a'), 'É', 'e'), 'Í', 'i'), 'Ó', 'o'), 'Ú', 'u'), 'ü', 'u'), 'Ü', 'u')";
  }

  /// Helper Dart para normalizar texto a minúsculas sin tildes ni diéresis
  String _normalizeDart(String text) {
    String s = text.toLowerCase().trim();
    return s
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

  /// Carga registros recientes por defecto cuando el buscador se abre vacío
  Future<void> _loadRecentDefaults() async {
    if (_searchCtrl.text.trim().isNotEmpty) return;
    setState(() => _isSearching = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final businessId = auth.activeBusinessId ?? 1;
      final db = await LocalDatabase.instance.database;

      final bool loadProds = _activeCategory == 'all' || _activeCategory == 'products';
      final bool loadClients = _activeCategory == 'all' || _activeCategory == 'clients';
      final bool loadQuotes = _activeCategory == 'all' || _activeCategory == 'quotes';
      final bool loadSales = _activeCategory == 'all' || _activeCategory == 'sales';

      // 1. Productos recientes (hasta 1000 si la categoría es específica, 30 si es 'all')
      List<Map<String, dynamic>> prods = [];
      if (loadProds) {
        try {
          final int limit = _activeCategory == 'products' ? 1000 : 30;
          prods = await db.rawQuery('''
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
          ''', [businessId, limit]);
        } catch (_) {}
      }

      // 2. Clientes recientes
      List<Map<String, dynamic>> clients = [];
      if (loadClients) {
        try {
          final int limit = _activeCategory == 'clients' ? 1000 : 25;
          clients = await db.rawQuery('''
            SELECT id, nombre_completo, telefono, dni_ruc, saldo_a_favor, deuda_total, nivel_confianza, notas
            FROM clientes
            WHERE negocio_id = ?
            ORDER BY id DESC
            LIMIT ?
          ''', [businessId, limit]);
        } catch (_) {}
      }

      // 3. Cotizaciones recientes (omitiendo las que ya fueron vendidas o anuladas)
      List<Map<String, dynamic>> quotes = [];
      if (loadQuotes) {
        try {
          final int limit = _activeCategory == 'quotes' ? 1000 : 25;
          quotes = await db.rawQuery('''
            SELECT sq.id, sq.numero_secuencial, sq.client_name, sq.client_id, sq.institution_name,
                   sq.grade_level, sq.total_amount, sq.status, sq.created_at
            FROM smart_quotations sq
            WHERE sq.negocio_id = ? 
              AND LOWER(IFNULL(sq.status, '')) NOT IN ('vendida', 'sold', 'annulled', 'anulada')
            ORDER BY sq.id DESC
            LIMIT ?
          ''', [businessId, limit]);
        } catch (_) {}
      }

      // 4. Ventas recientes
      List<Map<String, dynamic>> sales = [];
      if (loadSales) {
        try {
          final int limit = _activeCategory == 'sales' ? 1000 : 25;
          sales = await db.rawQuery('''
            SELECT v.id, v.numero_secuencial, v.monto_total, v.fecha_venta, v.metodo_pago, v.estado_pago,
                   c.nombre_completo as cliente_nombre
            FROM ventas v
            LEFT JOIN clientes c ON v.cliente_id = c.id
            WHERE v.negocio_id = ? AND v.is_archived = 0
            ORDER BY v.id DESC
            LIMIT ?
          ''', [businessId, limit]);
        } catch (_) {}
      }

      if (mounted && _searchCtrl.text.trim().isEmpty) {
        setState(() {
          _productResults = List.from(prods);
          _clientResults = List.from(clients);
          _quoteResults = List.from(quotes);
          _saleResults = List.from(sales);
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _performSearch(String query) async {
    final term = query.trim();
    if (term.isEmpty) {
      await _loadRecentDefaults();
      return;
    }

    setState(() => _isSearching = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final businessId = auth.activeBusinessId ?? 1;
      final db = await LocalDatabase.instance.database;

      final tokens = term.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

      final bool searchProds = _activeCategory == 'all' || _activeCategory == 'products';
      final bool searchClients = _activeCategory == 'all' || _activeCategory == 'clients';
      final bool searchQuotes = _activeCategory == 'all' || _activeCategory == 'quotes';
      final bool searchSales = _activeCategory == 'all' || _activeCategory == 'sales';

      // ==========================================
      // 1. PRODUCTOS (PRESENTACIONES INDIVIDUALES)
      // ==========================================
      List<Map<String, dynamic>> prods = [];
      if (searchProds) {
        try {
          List<String> prodConditions = [];
          List<dynamic> prodArgs = [businessId];

          for (final token in tokens) {
            final norm = _normalizeDart(token);
            final lem = SpanishLemmatizer.lemmatize(norm);

            if (norm == lem) {
              prodConditions.add('''
                (
                  ${_sqlUnaccent('p.nombre')} LIKE ? OR
                  ${_sqlUnaccent('pr.nombre_especifico')} LIKE ? OR
                  ${_sqlUnaccent('m.nombre')} LIKE ? OR
                  ${_sqlUnaccent('c.nombre')} LIKE ? OR
                  IFNULL(pr.codigo_barras, '') LIKE ? OR
                  IFNULL(p.codigo_barras, '') LIKE ?
                )
              ''');
              final pArg = '%$norm%';
              prodArgs.addAll([pArg, pArg, pArg, pArg, pArg, pArg]);
            } else {
              prodConditions.add('''
                (
                  ${_sqlUnaccent('p.nombre')} LIKE ? OR ${_sqlUnaccent('p.nombre')} LIKE ? OR
                  ${_sqlUnaccent('pr.nombre_especifico')} LIKE ? OR ${_sqlUnaccent('pr.nombre_especifico')} LIKE ? OR
                  ${_sqlUnaccent('m.nombre')} LIKE ? OR ${_sqlUnaccent('m.nombre')} LIKE ? OR
                  ${_sqlUnaccent('c.nombre')} LIKE ? OR ${_sqlUnaccent('c.nombre')} LIKE ? OR
                  IFNULL(pr.codigo_barras, '') LIKE ? OR
                  IFNULL(p.codigo_barras, '') LIKE ?
                )
              ''');
              final pArg1 = '%$norm%';
              final pArg2 = '%$lem%';
              prodArgs.addAll([pArg1, pArg2, pArg1, pArg2, pArg1, pArg2, pArg1, pArg2, pArg1, pArg1]);
            }
          }

          final int limit = _activeCategory == 'products' ? 1000 : 35;
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

      // ==========================================
      // 2. CLIENTES
      // ==========================================
      List<Map<String, dynamic>> clients = [];
      if (searchClients) {
        try {
          List<String> clientConditions = [];
          List<dynamic> clientArgs = [businessId];

          for (final token in tokens) {
            final norm = _normalizeDart(token);
            clientConditions.add('''
              (
                ${_sqlUnaccent('c.nombre_completo')} LIKE ? OR
                IFNULL(c.telefono, '') LIKE ? OR
                IFNULL(c.dni_ruc, '') LIKE ? OR
                ${_sqlUnaccent('c.notas')} LIKE ?
              )
            ''');
            final cArg = '%$norm%';
            clientArgs.addAll([cArg, cArg, cArg, cArg]);
          }

          final int limit = _activeCategory == 'clients' ? 1000 : 35;
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

      // ==========================================
      // 3. COTIZACIONES (Omitiendo vendidas y anuladas)
      // ==========================================
      List<Map<String, dynamic>> quotes = [];
      if (searchQuotes) {
        try {
          List<String> quoteConditions = [];
          List<dynamic> quoteArgs = [businessId];

          for (final token in tokens) {
            final norm = _normalizeDart(token);
            quoteConditions.add('''
              (
                ${_sqlUnaccent('sq.client_name')} LIKE ? OR
                ${_sqlUnaccent('sq.institution_name')} LIKE ? OR
                ${_sqlUnaccent('sq.grade_level')} LIKE ? OR
                CAST(sq.id AS TEXT) LIKE ? OR
                CAST(IFNULL(sq.numero_secuencial, sq.id) AS TEXT) LIKE ? OR
                ${_sqlUnaccent('sq.status')} LIKE ?
              )
            ''');
            final qArg = '%$norm%';
            quoteArgs.addAll([qArg, qArg, qArg, qArg, qArg, qArg]);
          }

          final int limit = _activeCategory == 'quotes' ? 1000 : 35;
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

      // ==========================================
      // 4. VENTAS
      // ==========================================
      List<Map<String, dynamic>> sales = [];
      if (searchSales) {
        try {
          List<String> saleConditions = [];
          List<dynamic> saleArgs = [businessId];

          for (final token in tokens) {
            final norm = _normalizeDart(token);
            saleConditions.add('''
              (
                ${_sqlUnaccent('c.nombre_completo')} LIKE ? OR
                CAST(v.id AS TEXT) LIKE ? OR
                CAST(IFNULL(v.numero_secuencial, v.id) AS TEXT) LIKE ? OR
                ${_sqlUnaccent('v.metodo_pago')} LIKE ? OR
                ${_sqlUnaccent('v.estado_pago')} LIKE ? OR
                CAST(v.monto_total AS TEXT) LIKE ?
              )
            ''');
            final sArg = '%$norm%';
            saleArgs.addAll([sArg, sArg, sArg, sArg, sArg, sArg]);
          }

          final int limit = _activeCategory == 'sales' ? 1000 : 35;
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

      if (mounted) {
        setState(() {
          _productResults = prods;
          _clientResults = clients;
          _quoteResults = quotes;
          _saleResults = sales;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // =========================================================================
  // SCORING Y ORDENAMIENTO DINÁMICO
  // =========================================================================

  double _scoreItem(String title, String? secondary, String? code, String query) {
    double score = 0;
    final normTitle = _normalizeDart(title);
    final normSec = _normalizeDart(secondary ?? '');
    final normQ = _normalizeDart(query);
    final tokens = normQ.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

    if (normTitle == normQ || code?.trim() == query.trim()) score += 100;
    if (normTitle.startsWith(normQ)) score += 60;
    if (normSec.startsWith(normQ)) score += 30;

    for (final t in tokens) {
      if (normTitle.contains(t)) score += 20;
      if (normSec.contains(t)) score += 10;
    }
    return score;
  }

  List<Map<String, dynamic>> _applySorting(
    List<Map<String, dynamic>> list,
    String entityType,
  ) {
    final copy = List<Map<String, dynamic>>.from(list);
    final query = _searchCtrl.text.trim();

    switch (_sortOption) {
      case OmniSortOption.relevance:
        if (query.isNotEmpty) {
          copy.sort((a, b) {
            double scoreA = 0;
            double scoreB = 0;
            if (entityType == 'products') {
              scoreA = _scoreItem(
                "${a['producto_nombre'] ?? ''} ${a['nombre_especifico'] ?? ''}",
                a['marca_nombre'],
                a['codigo_barras'],
                query,
              );
              scoreB = _scoreItem(
                "${b['producto_nombre'] ?? ''} ${b['nombre_especifico'] ?? ''}",
                b['marca_nombre'],
                b['codigo_barras'],
                query,
              );
            } else if (entityType == 'clients') {
              scoreA = _scoreItem(a['nombre_completo'] ?? '', a['dni_ruc'], a['telefono'], query);
              scoreB = _scoreItem(b['nombre_completo'] ?? '', b['dni_ruc'], b['telefono'], query);
            } else if (entityType == 'quotes') {
              scoreA = _scoreItem(a['client_name'] ?? '', a['institution_name'], a['id']?.toString(), query);
              scoreB = _scoreItem(b['client_name'] ?? '', b['institution_name'], b['id']?.toString(), query);
            } else if (entityType == 'sales') {
              scoreA = _scoreItem(a['cliente_nombre'] ?? '', a['metodo_pago'], a['numero_secuencial']?.toString(), query);
              scoreB = _scoreItem(b['cliente_nombre'] ?? '', b['metodo_pago'], b['numero_secuencial']?.toString(), query);
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
            nameA = "${a['producto_nombre'] ?? ''} ${a['nombre_especifico'] ?? ''}".trim();
            nameB = "${b['producto_nombre'] ?? ''} ${b['nombre_especifico'] ?? ''}".trim();
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
          final valA = _extractNumericValue(a);
          final valB = _extractNumericValue(b);
          return valB.compareTo(valA);
        });
        break;

      case OmniSortOption.priceAsc:
        copy.sort((a, b) {
          final valA = _extractNumericValue(a);
          final valB = _extractNumericValue(b);
          return valA.compareTo(valB);
        });
        break;
    }
    return copy;
  }

  double _extractNumericValue(Map<String, dynamic> item) {
    final raw = item['precio_venta_final'] ??
        item['total_amount'] ??
        item['monto_total'] ??
        item['deuda_total'];
    if (raw == null) return 0.0;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString()) ?? 0.0;
  }

  // =========================================================================
  // NAVEGACIÓN PROFUNDA SEGURA
  // =========================================================================

  Future<void> _navigateToProduct(Map<String, dynamic> p) async {
    final nav = Navigator.of(context);
    final invProv = Provider.of<InventoryProvider>(context, listen: false);
    final prodId = p['product_id'] as int;
    final presId = p['presentation_id'] as int;

    final fullProd = await invProv.getFullProductWithFallback(prodId);
    if (!mounted) return;
    nav.pop(); // Cierra el modal de búsqueda
    if (fullProd != null) {
      nav.push(
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(
            product: fullProd,
            initialPresentationId: presId,
            heroTag: 'omni_${prodId}_$presId',
          ),
        ),
      );
    }
  }

  Future<void> _navigateToClient(Map<String, dynamic> c) async {
    final nav = Navigator.of(context);
    final clientId = c['id'] as int;
    final clientModel = await ClientService().getClientById(clientId);
    if (!mounted) return;
    nav.pop(); // Cierra el modal de búsqueda
    if (clientModel != null) {
      nav.push(
        MaterialPageRoute(
          builder: (_) => ClientDetailScreen(client: clientModel),
        ),
      );
    }
  }

  void _navigateToQuote(Map<String, dynamic> q) {
    final nav = Navigator.of(context);
    final quoteId = q['id'] as int;
    final clientName = q['client_name'];
    nav.pop();
    nav.push(
      MaterialPageRoute(
        builder: (_) => QuotationDetailScreen(
          quotationId: quoteId,
          clientName: clientName,
        ),
      ),
    );
  }

  void _navigateToSale(Map<String, dynamic> s) {
    final nav = Navigator.of(context);
    final saleId = s['id'] as int;
    nav.pop();
    nav.push(
      MaterialPageRoute(
        builder: (_) => SaleHistoryDetailScreen(saleId: saleId),
      ),
    );
  }

  // =========================================================================
  // CONSTRUCCIÓN DE UI
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalMatches = _productResults.length +
        _clientResults.length +
        _quoteResults.length +
        _saleResults.length;

    final sortedProducts = _applySorting(_productResults, 'products');
    final sortedClients = _applySorting(_clientResults, 'clients');
    final sortedQuotes = _applySorting(_quoteResults, 'quotes');
    final sortedSales = _applySorting(_saleResults, 'sales');

    final bool isQueryEmpty = _searchCtrl.text.trim().isEmpty;

    final List<_OmniListItem> listItems = [];
    if ((_activeCategory == 'all' || _activeCategory == 'products') &&
        sortedProducts.isNotEmpty) {
      listItems.add(_HeaderItem("📦 PRODUCTOS", sortedProducts.length));
      for (final p in sortedProducts) {
        listItems.add(_ProductItem(p));
      }
      listItems.add(_SpacerItem());
    }

    if ((_activeCategory == 'all' || _activeCategory == 'clients') &&
        sortedClients.isNotEmpty) {
      listItems.add(_HeaderItem("👤 CLIENTES", sortedClients.length));
      for (final c in sortedClients) {
        listItems.add(_ClientItem(c));
      }
      listItems.add(_SpacerItem());
    }

    if ((_activeCategory == 'all' || _activeCategory == 'quotes') &&
        sortedQuotes.isNotEmpty) {
      listItems.add(_HeaderItem("📝 COTIZACIONES", sortedQuotes.length));
      for (final q in sortedQuotes) {
        listItems.add(_QuoteItem(q));
      }
      listItems.add(_SpacerItem());
    }

    if ((_activeCategory == 'all' || _activeCategory == 'sales') &&
        sortedSales.isNotEmpty) {
      listItems.add(_HeaderItem("🧾 VENTAS", sortedSales.length));
      for (final s in sortedSales) {
        listItems.add(_SaleItem(s));
      }
      listItems.add(_SpacerItem());
    }

    return InteractiveSheetWrapper(
      title: "Búsqueda Omnicanal Local",
      maxHeightFactor: 0.92,
      maintainFixedHeightOnKeyboard: true,
      applyEffectiveBottomPadding: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Input de búsqueda
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14141C) : Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.grey.shade300,
              ),
            ),
            child: TextField(
              controller: _searchCtrl,
              focusNode: _focusNode,
              autofocus: false,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: "Escribe producto, cliente, cotización o folio...",
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey[500] : Colors.grey[400],
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: isDark ? Colors.blue[300] : Colors.blue[700],
                ),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchCtrl.clear();
                          _loadRecentDefaults();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onChanged: _performSearch,
            ),
          ),

          // Chips de segmentos con conteos reales consolidados de SQLite
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryChip(
                  'all',
                  'Todos (${_dbCountProducts + _dbCountClients + _dbCountQuotes + _dbCountSales})',
                  isDark,
                ),
                const SizedBox(width: 8),
                _buildCategoryChip(
                  'products',
                  '📦 Productos ($_dbCountProducts)',
                  isDark,
                ),
                const SizedBox(width: 8),
                _buildCategoryChip(
                  'clients',
                  '👤 Clientes ($_dbCountClients)',
                  isDark,
                ),
                const SizedBox(width: 8),
                _buildCategoryChip(
                  'quotes',
                  '📝 Cotizaciones ($_dbCountQuotes)',
                  isDark,
                ),
                const SizedBox(width: 8),
                _buildCategoryChip(
                  'sales',
                  '🧾 Ventas ($_dbCountSales)',
                  isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Barra de ordenamiento dinámico
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isQueryEmpty
                    ? "Registros recientes del negocio"
                    : "Resultados ordenados por:",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              PopupMenuButton<OmniSortOption>(
                initialValue: _sortOption,
                onSelected: (opt) {
                  HapticFeedback.selectionClick();
                  setState(() => _sortOption = opt);
                },
                color: isDark ? const Color(0xFF23232F) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? Colors.white24 : Colors.blue.shade200,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _sortOption.icon,
                        size: 14,
                        color: isDark ? Colors.blue[300] : Colors.blue[800],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _sortOption.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.blue[300] : Colors.blue[800],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 18,
                        color: isDark ? Colors.blue[300] : Colors.blue[800],
                      ),
                    ],
                  ),
                ),
                itemBuilder: (ctx) => OmniSortOption.values.map((opt) {
                  final isSelected = opt == _sortOption;
                  return PopupMenuItem(
                    value: opt,
                    child: Row(
                      children: [
                        Icon(
                          opt.icon,
                          size: 16,
                          color: isSelected
                              ? Colors.blue
                              : (isDark ? Colors.grey[400] : Colors.grey[700]),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          opt.label,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected
                                ? Colors.blue
                                : (isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Contenido de resultados virtualizado y con scroll desacoplado
          Expanded(
            child: _isSearching
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : totalMatches == 0
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 48,
                                color: isDark ? Colors.white24 : Colors.grey[400],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "No se encontraron resultados para '${_searchCtrl.text}'",
                                style: TextStyle(
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Builder(
                        builder: (ctx) {
                          final bottomKeyboardInset = MediaQuery.viewInsetsOf(ctx).bottom;
                          return ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.only(bottom: bottomKeyboardInset + 24),
                            itemCount: listItems.length,
                            itemBuilder: (context, index) {
                          final item = listItems[index];
                          if (item is _HeaderItem) {
                            return _buildSectionHeader(item.title, item.count, isDark);
                          }
                          if (item is _ProductItem) {
                            return _buildProductCard(item.data, isDark);
                          }
                          if (item is _ClientItem) {
                            return _buildClientCard(item.data, isDark);
                          }
                          if (item is _QuoteItem) {
                            return _buildQuoteCard(item.data, isDark);
                          }
                          if (item is _SaleItem) {
                            return _buildSaleCard(item.data, isDark);
                          }
                          if (item is _SpacerItem) {
                            return const SizedBox(height: 12);
                          }
                          return const SizedBox.shrink();
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String id, String label, bool isDark) {
    final isSelected = _activeCategory == id;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _activeCategory = id);
        if (_searchCtrl.text.trim().isEmpty) {
          _loadRecentDefaults();
        } else {
          _performSearch(_searchCtrl.text);
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.blue[700] : Colors.blue[600])
              : (isDark ? Colors.white10 : Colors.grey[200]),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.grey[400] : Colors.grey[700]),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: isDark ? Colors.blue[300] : Colors.blue[800],
            ),
          ),
          Text(
            "$count elementos",
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TARJETAS INTERACTIVAS EN DOBLE MODO (RECOGIDO VS DESPLEGADO INLINE)
  // =========================================================================

  Widget _buildProductCard(Map<String, dynamic> p, bool isDark) {
    final String key = "prod_${p['presentation_id']}";
    final bool isExpanded = _expandedKeys.contains(key);

    final double price = (p['precio_venta_final'] as num?)?.toDouble() ?? 0.0;
    final double? offerPrice = (p['precio_oferta'] as num?)?.toDouble();
    final int stock = (p['stock_actual'] as int?) ?? 0;
    final int factor = (p['unidades_por_venta'] as int?) ?? 1;
    final int displayStock = factor > 0 ? (stock ~/ factor) : stock;
    final String unit = p['unidad_venta'] ?? 'und';
    final String barcode = (p['codigo_barras'] ?? '').toString();
    final String category = p['categoria_nombre'] ?? 'Sin categoría';
    final String brand = p['marca_nombre'] ?? 'Genérico';
    final String? imgUrl = p['pres_img'] ?? p['prod_img'];

    final bool isLowStock = stock <= ((p['stock_alerta'] as int?) ?? 5);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded
              ? (isDark ? Colors.blue.withValues(alpha: 0.5) : Colors.blue.shade300)
              : (isDark ? Colors.white10 : Colors.grey.shade200),
          width: isExpanded ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              if (isExpanded) {
                _expandedKeys.remove(key);
              } else {
                _expandedKeys.add(key);
              }
            });
          },
          child: AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // MODO RECOGIDO (Fila Principal)
                  Row(
                    children: [
                      // Avatar o Imagen
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: imgUrl != null && imgUrl.isNotEmpty
                              ? UniversalImage(
                                  path: imgUrl,
                                  productName: p['producto_nombre'],
                                  categoryName: category,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  color: isDark ? Colors.white10 : Colors.blue.shade50,
                                  child: Icon(
                                    Icons.inventory_2_rounded,
                                    size: 20,
                                    color: isDark ? Colors.blue[300] : Colors.blue[700],
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Título y Marca
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${p['producto_nombre'] ?? ''} ${p['nombre_especifico'] ?? ''}".trim(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: isExpanded ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white10 : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    brand,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "Stock: $displayStock $unit",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isLowStock
                                        ? Colors.orangeAccent
                                        : (isDark ? Colors.grey[400] : Colors.grey[600]),
                                    fontWeight: isLowStock ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Precio y Botón Rápido
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "S/ ${(offerPrice != null && offerPrice > 0 ? offerPrice : price).toStringAsFixed(2)}",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: isDark ? Colors.green[400] : Colors.green[700],
                            ),
                          ),
                          if (offerPrice != null && offerPrice > 0)
                            Text(
                              "S/ ${price.toStringAsFixed(2)}",
                              style: const TextStyle(
                                fontSize: 10,
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: () => _navigateToProduct(p),
                        tooltip: "Ver producto",
                      ),
                    ],
                  ),

                  // MODO DESPLEGADO (Detalles Específicos de la Presentación)
                  if (isExpanded) ...[
                    const SizedBox(height: 12),
                    Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.shade200),
                    const SizedBox(height: 10),

                    // Grid de información específica
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _buildDetailChip("Categoría", category, isDark),
                        _buildDetailChip("Empaque", "1 $unit = $factor und", isDark),
                        if (barcode.isNotEmpty)
                          _buildDetailChip("Código", barcode, isDark, isMonospace: true),
                        _buildDetailChip("Stock Total", "$stock unidades", isDark),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Botón de redirección completa
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? Colors.blue[700] : Colors.blue[600],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text(
                          "Ver Ficha Completa del Producto",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onPressed: () => _navigateToProduct(p),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClientCard(Map<String, dynamic> c, bool isDark) {
    final String key = "client_${c['id']}";
    final bool isExpanded = _expandedKeys.contains(key);

    final double deuda = (c['deuda_total'] as num?)?.toDouble() ?? 0.0;
    final double saldo = (c['saldo_a_favor'] as num?)?.toDouble() ?? 0.0;
    final String doc = (c['dni_ruc'] ?? '').toString();
    final String phone = (c['telefono'] ?? '').toString();
    final String notes = (c['notas'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded
              ? (isDark ? Colors.indigo.withValues(alpha: 0.5) : Colors.indigo.shade300)
              : (isDark ? Colors.white10 : Colors.grey.shade200),
          width: isExpanded ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              if (isExpanded) {
                _expandedKeys.remove(key);
              } else {
                _expandedKeys.add(key);
              }
            });
          },
          child: AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: isDark ? Colors.indigo[900] : Colors.indigo[100],
                        child: Text(
                          (c['nombre_completo'] != null &&
                                  c['nombre_completo'].toString().isNotEmpty)
                              ? c['nombre_completo'][0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.indigo[200] : Colors.indigo[900],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c['nombre_completo'] ?? 'Sin nombre',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Telf: ${phone.isNotEmpty ? phone : 'S/N'}${doc.isNotEmpty ? ' · DNI/RUC: $doc' : ''}",
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (deuda > 0)
                            Text(
                              "Debe: S/ ${deuda.toStringAsFixed(2)}",
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          if (saldo > 0)
                            Text(
                              "A favor: S/ ${saldo.toStringAsFixed(2)}",
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          if (deuda <= 0 && saldo <= 0)
                            Text(
                              "Al día",
                              style: TextStyle(
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: () => _navigateToClient(c),
                        tooltip: "Ver cliente",
                      ),
                    ],
                  ),
                  if (isExpanded) ...[
                    const SizedBox(height: 12),
                    Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.shade200),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _buildDetailChip("Nivel Confianza", c['nivel_confianza'] ?? 'Bueno', isDark),
                        if (doc.isNotEmpty) _buildDetailChip("Documento", doc, isDark, isMonospace: true),
                        if (notes.isNotEmpty) _buildDetailChip("Notas", notes, isDark),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? Colors.indigo[700] : Colors.indigo[600],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.person_pin_rounded, size: 16),
                        label: const Text(
                          "Ver Perfil y Cuenta Corriente",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onPressed: () => _navigateToClient(c),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuoteCard(Map<String, dynamic> q, bool isDark) {
    final String key = "quote_${q['id']}";
    final bool isExpanded = _expandedKeys.contains(key);

    final double amount = (q['total_amount'] as num?)?.toDouble() ?? 0.0;
    final int quoteId = q['id'] as int;
    final int seq = (q['numero_secuencial'] as int?) ?? quoteId;
    final String institution = (q['institution_name'] ?? '').toString();
    final String grade = (q['grade_level'] ?? '').toString();
    final String status = (q['status'] ?? 'PENDING').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded
              ? (isDark ? Colors.orange.withValues(alpha: 0.5) : Colors.orange.shade300)
              : (isDark ? Colors.white10 : Colors.grey.shade200),
          width: isExpanded ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              if (isExpanded) {
                _expandedKeys.remove(key);
              } else {
                _expandedKeys.add(key);
              }
            });
          },
          child: AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.orange.withValues(alpha: 0.15) : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.description_outlined,
                          size: 20,
                          color: isDark ? Colors.orange[300] : Colors.orange[800],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Cotización #$seq · ${q['client_name'] ?? 'Cliente General'}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Estado: $status${institution.isNotEmpty ? ' · $institution' : ''}",
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "S/ ${amount.toStringAsFixed(2)}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: () => _navigateToQuote(q),
                        tooltip: "Ver cotización",
                      ),
                    ],
                  ),
                  if (isExpanded) ...[
                    const SizedBox(height: 12),
                    Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.shade200),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        if (institution.isNotEmpty) _buildDetailChip("Institución", institution, isDark),
                        if (grade.isNotEmpty) _buildDetailChip("Grado/Nivel", grade, isDark),
                        _buildDetailChip("Folio", "#$seq", isDark, isMonospace: true),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? Colors.orange[700] : Colors.orange[800],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.visibility_rounded, size: 16),
                        label: const Text(
                          "Abrir Detalle de Cotización",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onPressed: () => _navigateToQuote(q),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSaleCard(Map<String, dynamic> s, bool isDark) {
    final String key = "sale_${s['id']}";
    final bool isExpanded = _expandedKeys.contains(key);

    final double amount = (s['monto_total'] as num?)?.toDouble() ?? 0.0;
    final int saleId = s['id'] as int;
    final int seq = (s['numero_secuencial'] as int?) ?? saleId;
    final String paymentMethod = (s['metodo_pago'] ?? 'efectivo').toString();
    final String paymentStatus = (s['estado_pago'] ?? 'completado').toString();
    final String dateStr = s['fecha_venta'] != null
        ? s['fecha_venta'].toString().substring(0, 10)
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded
              ? (isDark ? Colors.teal.withValues(alpha: 0.5) : Colors.teal.shade300)
              : (isDark ? Colors.white10 : Colors.grey.shade200),
          width: isExpanded ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              if (isExpanded) {
                _expandedKeys.remove(key);
              } else {
                _expandedKeys.add(key);
              }
            });
          },
          child: AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.teal.withValues(alpha: 0.15) : Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.receipt_rounded,
                          size: 20,
                          color: isDark ? Colors.teal[300] : Colors.teal[700],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Venta #$seq · ${s['cliente_nombre'] ?? 'Cliente Mostrador'}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Pago: $paymentMethod · $paymentStatus${dateStr.isNotEmpty ? ' · $dateStr' : ''}",
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "S/ ${amount.toStringAsFixed(2)}",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: isDark ? Colors.teal[300] : Colors.teal[800],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: () => _navigateToSale(s),
                        tooltip: "Ver venta",
                      ),
                    ],
                  ),
                  if (isExpanded) ...[
                    const SizedBox(height: 12),
                    Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.shade200),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _buildDetailChip("Folio", "#$seq", isDark, isMonospace: true),
                        _buildDetailChip("Método Pago", paymentMethod.toUpperCase(), isDark),
                        _buildDetailChip("Estado Pago", paymentStatus.toUpperCase(), isDark),
                        if (dateStr.isNotEmpty) _buildDetailChip("Fecha", dateStr, isDark),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? Colors.teal[700] : Colors.teal[600],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.receipt_long_rounded, size: 16),
                        label: const Text(
                          "Abrir Detalle de Venta",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onPressed: () => _navigateToSale(s),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailChip(String label, String value, bool isDark, {bool isMonospace = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: RichText(
        text: TextSpan(
          text: "$label: ",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
          children: [
            TextSpan(
              text: value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: isMonospace ? 'monospace' : null,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// CLASES AUXILIARES PARA RENDERIZADO VIRTUALIZADO PLANO (60 FPS)
// =========================================================================

abstract class _OmniListItem {}

class _HeaderItem extends _OmniListItem {
  final String title;
  final int count;
  _HeaderItem(this.title, this.count);
}

class _ProductItem extends _OmniListItem {
  final Map<String, dynamic> data;
  _ProductItem(this.data);
}

class _ClientItem extends _OmniListItem {
  final Map<String, dynamic> data;
  _ClientItem(this.data);
}

class _QuoteItem extends _OmniListItem {
  final Map<String, dynamic> data;
  _QuoteItem(this.data);
}

class _SaleItem extends _OmniListItem {
  final Map<String, dynamic> data;
  _SaleItem(this.data);
}

class _SpacerItem extends _OmniListItem {}

