part of '../smart_action_grid.dart';

mixin _SmartActionGridDefinitionsMixin on _SmartActionGridStateBase {
  @override
  List<String> _getDefaultCardIds() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isCommunityClient) {
      return ['order_catalog'];
    }
    final ids = [
      'quick_sale',
      'create_product',
      'quote_list',
      'quote_manual',
      'load_invoice',
      'clients',
      'loyalty_rewards',
      'activity',
      'analytics',
      'commercial_radar',
    ];
    if (kDebugMode) {
      ids.add('db_inspector');
    }
    return ids;
  }

  @override
  bool get _isCustomized {
    final defaultIds = _getDefaultCardIds();
    if (_columnsDensity != 2 ||
        _heroCardId != null ||
        _hiddenCardIds.isNotEmpty ||
        _orderedCardIds.length != defaultIds.length) {
      return true;
    }
    for (int i = 0; i < defaultIds.length; i++) {
      if (i >= _orderedCardIds.length || _orderedCardIds[i] != defaultIds[i]) {
        return true;
      }
    }
    return false;
  }

  void _runLicensedAction(BuildContext ctx, VoidCallback action) {
    final licenseProv = Provider.of<LicenseProvider?>(ctx, listen: false);
    if (licenseProv != null && !licenseProv.canCreateSales) {
      SoftLockRenewalModal.show(ctx);
      return;
    }
    action();
  }

  @override
  Map<String, _ActionCardDef> _getCardDefinitions(BuildContext context) {
    final inventoryScanner = Provider.of<ScannerProvider>(context);
    final quotationScanner = Provider.of<SmartQuotationProvider>(context);
    final trackingProv = Provider.of<TrackingProvider>(context);
    final salesProv = Provider.of<SaleProvider>(context);
    final quickSaleProv = Provider.of<QuickSaleProvider>(context);
    final invProv = Provider.of<InventoryProvider>(context);

    return {
      'order_catalog': _ActionCardDef(
        id: 'order_catalog',
        title: "Crear Pedido",
        subtitle: "Catálogo Virtual",
        icon: Icons.add_shopping_cart_rounded,
        colorBuilder: (isDark) =>
            isDark ? Colors.blue[400]! : Colors.blue[700]!,
        badgeBuilder: (ctx, isDark) => null,
        onTapBuilder: (ctx, isDark) =>
            () => Navigator.push(
              ctx,
              MaterialPageRoute(builder: (_) => const ManualQuotationScreen()),
            ),
      ),
      'quick_sale': _ActionCardDef(
        id: 'quick_sale',
        title: "Venta Rápida",
        subtitle: "Caja al paso",
        icon: Icons.flash_on_rounded,
        colorBuilder: (isDark) =>
            isDark ? Colors.pink[300]! : Colors.pink[600]!,
        badgeBuilder: (ctx, isDark) => quickSaleProv.cartItems.isNotEmpty
            ? _buildBadge("${quickSaleProv.cartItems.length}", Colors.red)
            : null,
        onTapBuilder: (ctx, isDark) =>
            () => _runLicensedAction(ctx, () {
              Navigator.push(
                ctx,
                MaterialPageRoute(builder: (_) => const QuickSaleScreen()),
              );
            }),
        onLongPressBuilder: (ctx, isDark) =>
            () => _showQuickSalePowerShortcut(ctx, quickSaleProv, isDark),
      ),
      'create_product': _ActionCardDef(
        id: 'create_product',
        title: "Crear Producto",
        subtitle: "Inventario",
        icon: Icons.add_box_rounded,
        colorBuilder: (isDark) =>
            isDark ? Colors.green[400]! : Colors.green[600]!,
        badgeBuilder: (ctx, isDark) => invProv.totalPresentationsCount > 0
            ? _buildBadge(
                "${invProv.totalPresentationsCount}",
                Colors.green[800]!,
              )
            : null,
        onTapBuilder: (ctx, isDark) => () async {
          await Navigator.push(
            ctx,
            MaterialPageRoute(builder: (_) => const ProductCreateScreen()),
          );
        },
      ),
      'quote_list': _ActionCardDef(
        id: 'quote_list',
        title: "Cotizar Lista",
        subtitle: "Escaneo con IA",
        icon: Icons.document_scanner_rounded,
        colorBuilder: (isDark) =>
            isDark ? Colors.orange[400]! : Colors.orange[700]!,
        badgeBuilder: (ctx, isDark) => quotationScanner.items.isNotEmpty
            ? _buildBadge("${quotationScanner.items.length}", Colors.orange)
            : null,
        onTapBuilder: (ctx, isDark) =>
            () => _runLicensedAction(ctx, () {
              if (quotationScanner.items.isNotEmpty) {
                _showResumeDialog(
                  ctx,
                  title: "Lista Detectada",
                  msg: "Tienes una lista o pedido procesado sin guardar.",
                  isDark: isDark,
                  onNew: () {
                    quotationScanner.clearState();
                    Navigator.push(
                      ctx,
                      MaterialPageRoute(
                        builder: (_) =>
                            const ScanScreen(mode: ScanMode.quotation),
                      ),
                    );
                  },
                  onResume: () => Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => MatchingScreen(
                        extractedItems: quotationScanner.items,
                        metadata: quotationScanner.metadata,
                      ),
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => const ScanScreen(mode: ScanMode.quotation),
                  ),
                );
              }
            }),
      ),
      'quote_manual': _ActionCardDef(
        id: 'quote_manual',
        title: "Cotizar Manual",
        subtitle: "Detallada",
        icon: Icons.edit_note_rounded,
        colorBuilder: (isDark) =>
            isDark ? Colors.blue[400]! : Colors.blue[700]!,
        badgeBuilder: (ctx, isDark) => quotationScanner.hasManualDraft
            ? _buildBadge(
                "${quotationScanner.draftManualItems!.length}",
                Colors.blue,
              )
            : null,
        onTapBuilder: (ctx, isDark) =>
            () => _runLicensedAction(ctx, () {
              Navigator.push(
                ctx,
                MaterialPageRoute(
                  builder: (_) => const ManualQuotationScreen(),
                ),
              );
            }),
      ),
      'load_invoice': _ActionCardDef(
        id: 'load_invoice',
        title: "Cargar Factura",
        subtitle: "Reponer Stock",
        icon: Icons.receipt_long_rounded,
        colorBuilder: (isDark) =>
            isDark ? Colors.teal[400]! : Colors.teal[600]!,
        badgeBuilder: (ctx, isDark) => inventoryScanner.aiRawData != null
            ? _buildBadge(
                "${inventoryScanner.aiRawData!.items.length}",
                Colors.teal,
              )
            : null,
        onTapBuilder: (ctx, isDark) => () {
          if (inventoryScanner.aiRawData != null) {
            _showResumeDialog(
              ctx,
              title: "Factura Pendiente",
              msg:
                  "Tienes una factura en proceso de revisión o vinculación. ¿Deseas retomarla?",
              isDark: isDark,
              onNew: () {
                inventoryScanner.clearData();
                Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => const ScanScreen(mode: ScanMode.invoice),
                  ),
                );
              },
              onResume: () {
                if (inventoryScanner.hasSavedProgress &&
                    inventoryScanner.stagingData != null) {
                  Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => const InvoiceStagingScreen(),
                    ),
                  );
                } else {
                  Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => const InvoiceReviewScreen(),
                    ),
                  );
                }
              },
            );
          } else {
            Navigator.push(
              ctx,
              MaterialPageRoute(
                builder: (_) => const ScanScreen(mode: ScanMode.invoice),
              ),
            );
          }
        },
      ),
      'clients': _ActionCardDef(
        id: 'clients',
        title: "Clientes",
        subtitle: "Deudas y Pagos",
        icon: Icons.people_alt_rounded,
        colorBuilder: (isDark) =>
            isDark ? Colors.purple[300]! : Colors.purple[600]!,
        badgeBuilder: (ctx, isDark) => trackingProv.clientCount > 0
            ? _buildBadge("${trackingProv.clientCount}", Colors.purple)
            : null,
        onTapBuilder: (ctx, isDark) =>
            () => Navigator.push(
              ctx,
              MaterialPageRoute(builder: (_) => const ClientTrackingScreen()),
            ),
      ),
      'loyalty_rewards': _ActionCardDef(
        id: 'loyalty_rewards',
        title: "Fidelización",
        subtitle: trackingProv.pendingRewardsCount > 0
            ? "${trackingProv.pendingRewardsCount} por revisar"
            : "Puntos y Premios",
        icon: Icons.military_tech_rounded,
        colorBuilder: (isDark) =>
            isDark ? Colors.amber[400]! : Colors.amber[700]!,
        badgeBuilder: (ctx, isDark) => trackingProv.pendingRewardsCount > 0
            ? _buildBadge(
                "${trackingProv.pendingRewardsCount}",
                Colors.redAccent,
              )
            : null,
        onTapBuilder: (ctx, isDark) =>
            () => Navigator.push(
              ctx,
              MaterialPageRoute(builder: (_) => const LoyaltyCenterScreen()),
            ),
      ),
      'activity': _ActionCardDef(
        id: 'activity',
        title: "Actividad",
        subtitle: salesProv.todaySalesCount > 0
            ? "${salesProv.todaySalesCount} ventas hoy"
            : "Historial Ventas",
        icon: Icons.history_edu_rounded,
        colorBuilder: (isDark) =>
            isDark ? Colors.indigo[300]! : Colors.indigo[600]!,
        badgeBuilder: (ctx, isDark) => salesProv.todaySalesCount > 0
            ? _buildBadge("${salesProv.todaySalesCount}", Colors.indigo)
            : null,
        onTapBuilder: (ctx, isDark) =>
            () => Navigator.push(
              ctx,
              MaterialPageRoute(builder: (_) => const SalesHistoryScreen()),
            ),
      ),
      'analytics': _ActionCardDef(
        id: 'analytics',
        title: "Estadísticas",
        subtitle: "Finanzas y Top",
        icon: Icons.pie_chart_rounded,
        colorBuilder: (isDark) =>
            isDark ? Colors.amber[500]! : Colors.amber[700]!,
        badgeBuilder: (ctx, isDark) => null,
        onTapBuilder: (ctx, isDark) =>
            () => Navigator.push(
              ctx,
              MaterialPageRoute(
                builder: (_) => const AnalyticsDashboardScreen(),
              ),
            ),
      ),
      'commercial_radar': _ActionCardDef(
        id: 'commercial_radar',
        title: "Radar IA",
        subtitle: "Noticias y Alertas",
        icon: Icons.radar,
        colorBuilder: (isDark) =>
            isDark ? Colors.cyan[300]! : Colors.cyan[700]!,
        badgeBuilder: (ctx, isDark) => null,
        onTapBuilder: (ctx, isDark) =>
            () => Navigator.push(
              ctx,
              MaterialPageRoute(builder: (_) => const CommercialRadarScreen()),
            ),
      ),
      'db_inspector': _ActionCardDef(
        id: 'db_inspector',
        title: "DB Inspector",
        subtitle: "Depuración BD",
        icon: Icons.admin_panel_settings_rounded,
        colorBuilder: (isDark) =>
            isDark ? Colors.grey[400]! : Colors.grey[700]!,
        badgeBuilder: (ctx, isDark) => null,
        onTapBuilder: (ctx, isDark) =>
            () => Navigator.push(
              ctx,
              MaterialPageRoute(builder: (_) => const DbInspectorScreen()),
            ),
      ),
    };
  }
}
