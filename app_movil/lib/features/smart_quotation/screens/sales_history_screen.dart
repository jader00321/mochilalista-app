import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/sale_provider.dart';
import '../../../providers/auth_provider.dart'; 
import '../widgets/history/history_dashboard_cards.dart';
import '../widgets/history/history_filter_bar.dart';
import '../widgets/history/sales_list_builder.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0; 

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    _tabController.addListener(() {
      if (_tabController.index != _currentTabIndex) {
        _currentTabIndex = _tabController.index;
        final tabs = ['todas', 'smart_quotation', 'pos_rapido', 'archivadas'];
        Provider.of<SaleProvider>(context, listen: false).setTab(tabs[_currentTabIndex]);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SaleProvider>(context, listen: false).loadFilteredHistory(reset: true);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showExplorationModal(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.explore, color: Colors.orange[400]),
            const SizedBox(width: 10),
            const Text("Modo Exploración", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          "Para generar y exportar el reporte de tus ventas en formato Excel, necesitas registrar tu negocio en tu Perfil.",
          style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 16, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Entendido", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      )
    );
  }

  Future<void> _exportToCsv() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!auth.hasActiveContext) {
      _showExplorationModal(context, isDark);
      return;
    }

    final provider = Provider.of<SaleProvider>(context, listen: false);
    final csvData = provider.generateCsvData();
    
    if (csvData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No hay datos para exportar")));
      return;
    }

    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/Reporte_Ventas.csv');
      await file.writeAsString(csvData);
      
      await Share.shareXFiles([XFile(file.path)], text: 'Adjunto el reporte de ventas (Formato Excel/CSV).');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al exportar: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final auth = Provider.of<AuthProvider>(context);
    final isGuest = !auth.hasActiveContext;
    
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Historial de Ventas", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: isDark ? const Color(0xFF1A1A24) : Colors.blue[900],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download, size: 26),
            tooltip: "Exportar a Excel (CSV)",
            onPressed: _exportToCsv,
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: Colors.orange,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          tabs: const [
            Tab(text: "Todas"),
            Tab(text: "Listas Escolares"),
            Tab(text: "Caja Rápida"),
            Tab(text: "Archivadas / Anuladas"),
          ],
        ),
      ),
      body: Column(
        children: [
          if (isGuest)
            Container(
              width: double.infinity,
              color: Colors.orange.withOpacity(0.15),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Modo Exploración. Registra tu negocio para empezar a ver tus métricas de ventas e ingresos reales aquí.",
                      style: TextStyle(color: isDark ? Colors.orange[200] : Colors.orange[900], fontSize: 13),
                    )
                  )
                ]
              )
            ),
          
          const HistoryDashboardCards(),
          const HistoryFilterBar(),
          const SizedBox(height: 10),
          const Expanded(
            child: SalesListBuilder(),
          ),
        ],
      ),
    );
  }
}