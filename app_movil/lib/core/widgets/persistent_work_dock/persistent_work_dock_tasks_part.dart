part of '../persistent_work_dock.dart';

extension _PersistentWorkDockTasksPart on _PersistentWorkDockState {
  List<WorkTask> _gatherActiveTasks(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.hasActiveContext) {
      return [];
    }

    final tasks = <WorkTask>[];

    // 1. Caja Rápida
    final quickProv = Provider.of<QuickSaleProvider>(context);
    if (quickProv.cartItems.isNotEmpty) {
      final count = quickProv.cartItems.length;
      final total = quickProv.totalToPay;
      tasks.add(
        WorkTask(
          id: 'quick_sale',
          title: 'Caja Rápida',
          shortTitle: 'Caja',
          subtitle: '$count ítems • ${AppCurrency.format(total)}',
          icon: Icons.point_of_sale_rounded,
          color: const Color(0xFF2E7D32),
          onResume: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QuickSaleScreen()),
            );
          },
          onDiscard: () {
            _confirmDiscard(
              context,
              title: '¿Descartar Caja Rápida?',
              message:
                  'Se limpiarán los productos agregados a la venta rápida.',
              onConfirm: () => quickProv.clearCart(),
            );
          },
        ),
      );
    }

    // 2. Factura en Staging / Escáner
    final scannerProv = Provider.of<ScannerProvider>(context);
    if (scannerProv.stagingData != null &&
        scannerProv.stagingData!.productosAgrupados.isNotEmpty) {
      final groupsCount = scannerProv.stagingData!.productosAgrupados.length;
      tasks.add(
        WorkTask(
          id: 'scanner_staging',
          title: 'Factura en Staging',
          shortTitle: 'Factura',
          subtitle: '$groupsCount grupos pendientes de ingreso',
          icon: Icons.receipt_long_rounded,
          color: const Color(0xFFE65100),
          onResume: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InvoiceStagingScreen()),
            );
          },
          onDiscard: () {
            _confirmDiscard(
              context,
              title: '¿Descartar Factura?',
              message:
                  'Se perderán los datos extraídos de la factura pendiente.',
              onConfirm: () => scannerProv.clearData(),
            );
          },
        ),
      );
    }

    // 3. Conciliación / Matching
    final matchingProv = Provider.of<MatchingProvider>(context);
    if (matchingProv.pairs.isNotEmpty) {
      final count = matchingProv.pairs.length;
      final total = matchingProv.totalNetAmount;
      tasks.add(
        WorkTask(
          id: 'matching',
          title: 'Conciliación IA',
          shortTitle: 'Conciliación',
          subtitle: '$count ítems • ${AppCurrency.format(total)}',
          icon: Icons.auto_awesome_rounded,
          color: const Color(0xFF5E35B1),
          onResume: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MatchingScreen(
                  extractedItems: matchingProv.pairs
                      .map((p) => p.sourceItem)
                      .toList(),
                  metadata: matchingProv.metadata,
                ),
              ),
            );
          },
          onDiscard: () {
            _confirmDiscard(
              context,
              title: '¿Descartar Conciliación?',
              message: 'Se perderán los ítems extraídos de la lista escolar.',
              onConfirm: () => matchingProv.clearState(),
            );
          },
        ),
      );
    }

    // 4. Borrador de Cotización Manual
    final smartProv = Provider.of<SmartQuotationProvider>(context);
    if (smartProv.hasManualDraft) {
      final count = smartProv.draftManualItems?.length ?? 0;
      final title = smartProv.draftQuoteTitle?.isNotEmpty == true
          ? smartProv.draftQuoteTitle!
          : 'Cotización en progreso';
      tasks.add(
        WorkTask(
          id: 'manual_quote',
          title: 'Borrador de Cotización',
          shortTitle: 'Borrador',
          subtitle: '$count ítems • $title',
          icon: Icons.edit_note_rounded,
          color: const Color(0xFF00838F),
          onResume: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ManualQuotationScreen(quotationId: null),
              ),
            );
          },
          onDiscard: () {
            _confirmDiscard(
              context,
              title: '¿Descartar Borrador?',
              message:
                  'Se eliminará la cotización manual guardada como borrador.',
              onConfirm: () => smartProv.clearManualDraft(),
            );
          },
        ),
      );
    }

    // 5. Borrador de Producto en Creación
    final invProv = Provider.of<InventoryProvider>(context);
    if (invProv.hasCreationDraft) {
      final draft = invProv.creationDraft!;
      final name = draft.name.trim().isNotEmpty
          ? draft.name.trim()
          : 'Nuevo Producto';
      final presCount = draft.presentations.length;
      final subtitle = presCount <= 1
          ? '$name • 1 presentación'
          : '$name • $presCount presentaciones';

      tasks.add(
        WorkTask(
          id: 'product_create',
          title: 'Producto en Creación',
          shortTitle: 'Producto',
          subtitle: subtitle,
          icon: Icons.add_box_rounded,
          color: const Color(0xFF00897B),
          onResume: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProductCreateScreen()),
            );
          },
          onDiscard: () {
            _confirmDiscard(
              context,
              title: '¿Descartar Producto?',
              message:
                  'Se perderán los datos del producto que estabas creando.',
              onConfirm: () => invProv.clearCreationDraft(),
            );
          },
        ),
      );
    }

    return tasks;
  }
}
