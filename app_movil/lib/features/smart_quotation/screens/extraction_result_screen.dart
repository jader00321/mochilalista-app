import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:multi_split_view/multi_split_view.dart';

import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/utils/app_feedback_helper.dart';
import 'package:app_movil/core/widgets/universal_image.dart';
import 'package:app_movil/features/smart_quotation/models/extracted_list_model.dart';
import 'package:app_movil/features/smart_quotation/providers/matching_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';
import 'package:app_movil/features/smart_quotation/screens/matching_screen.dart';
import 'package:app_movil/features/smart_quotation/widgets/extraction/quotation_confirmation_modal.dart';

part 'extraction_result/extraction_result_metadata_and_list_part.dart';
part 'extraction_result/extraction_result_cards_part.dart';

/// Pantalla de revisión de datos e ítems extraídos antes de pasar al emparejamiento.
class ExtractionResultScreen extends StatefulWidget {
  const ExtractionResultScreen({super.key});

  @override
  State<ExtractionResultScreen> createState() => _ExtractionResultScreenState();
}

class _ExtractionResultScreenState extends State<ExtractionResultScreen> {
  final _schoolCtrl = TextEditingController();
  final _studentCtrl = TextEditingController();
  final _gradeCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  QuotationContextMode _currentMode = QuotationContextMode.general;

  late MultiSplitViewController _splitController;
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _splitController = MultiSplitViewController(
      areas: [Area(size: 0.35, min: 0.20), Area(size: 0.65, min: 0.45)],
    );

    _scrollController.addListener(() {
      if (_scrollController.offset > 200 && !_showScrollToTop) {
        setState(() => _showScrollToTop = true);
      } else if (_scrollController.offset <= 200 && _showScrollToTop) {
        setState(() => _showScrollToTop = false);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final provider = Provider.of<SmartQuotationProvider>(
        context,
        listen: false,
      );
      if (provider.metadata != null) {
        _currentMode = provider.metadata!.contextMode;
        _schoolCtrl.text = provider.metadata!.businessOrInstitutionName ?? "";
        _studentCtrl.text = provider.metadata!.clientOrContactName ?? "";
        _gradeCtrl.text = provider.metadata!.referenceNotes ?? "";
        _phoneCtrl.text = provider.metadata!.phone ?? "";
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _schoolCtrl.dispose();
    _studentCtrl.dispose();
    _gradeCtrl.dispose();
    _phoneCtrl.dispose();
    _splitController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _updateContextMode(
    QuotationContextMode mode,
    SmartQuotationProvider provider,
  ) {
    setState(() => _currentMode = mode);
    provider.updateMetadata(mode: mode);
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
    );
  }

  void _showDeleteConfirmation(
    BuildContext parentContext,
    int itemId,
    bool isDark,
  ) {
    showDialog(
      context: parentContext,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: isDark ? Colors.orange[300] : Colors.orange,
              size: 30,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "¿Eliminar ítem?",
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          "Se eliminará este producto de la lista. Esta acción no se puede deshacer.",
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[700],
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Cancelar",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.red[800] : Colors.red[50],
              foregroundColor: isDark ? Colors.white : Colors.red,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Provider.of<SmartQuotationProvider>(
                parentContext,
                listen: false,
              ).deleteItem(itemId);
              Navigator.pop(ctx);
              AppFeedbackHelper.showSnackBar(
                parentContext,
                "Producto eliminado",
                duration: const Duration(milliseconds: 1500),
                behavior: SnackBarBehavior.floating,
              );
            },
            child: const Text(
              "Eliminar",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _openConfirmModal(BuildContext context, bool isClient) {
    final smartProvider = Provider.of<SmartQuotationProvider>(
      context,
      listen: false,
    );
    final matchingProvider = Provider.of<MatchingProvider>(
      context,
      listen: false,
    );

    final totalCount = smartProvider.items.length;
    final readyCount = smartProvider.items
        .where((i) => i.fullName.trim().isNotEmpty && i.quantity > 0)
        .length;
    final emptyOrZeroCount = totalCount - readyCount;

    QuotationConfirmationModal.show(
      context: context,
      totalItems: totalCount,
      readyItems: readyCount,
      zeroOrEmptyItems: emptyOrZeroCount,
      currentMode: _currentMode,
      isClientRole: isClient,
      onConfirm: (prioritizeWholesale, selectedMode) {
        final updatedMetadata = ExtractedMetadata(
          contextMode: selectedMode,
          clientOrContactName: _studentCtrl.text.trim().isEmpty
              ? null
              : _studentCtrl.text.trim(),
          businessOrInstitutionName: _schoolCtrl.text.trim().isEmpty
              ? null
              : _schoolCtrl.text.trim(),
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          referenceNotes: _gradeCtrl.text.trim().isEmpty
              ? null
              : _gradeCtrl.text.trim(),
        );

        matchingProvider.setEvidence(
          smartProvider.currentImage,
          smartProvider.fullExtractedText,
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MatchingScreen(
              metadata: updatedMetadata,
              extractedItems: smartProvider.items,
              prioritizeWholesale: prioritizeWholesale,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isClient = auth.isCommunityClient;

    return Consumer<SmartQuotationProvider>(
      builder: (context, provider, child) {
        final String? imagePath = provider.currentImage?.path;

        if (imagePath == null) {
          return Scaffold(
            backgroundColor: bgColor,
            appBar: AppBar(title: const Text("Error")),
            body: const Center(child: Text("No se pudo cargar la imagen.")),
          );
        }

        final int readyCount = provider.items
            .where((i) => i.fullName.trim().isNotEmpty && i.quantity > 0)
            .length;
        final String actionText = isClient
            ? "BUSCAR ($readyCount)"
            : "COTIZAR ($readyCount/${provider.items.length})";

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            titleSpacing: 8,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    isClient ? "Revisa tu Lista" : "Datos Extraídos",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),
                Text(
                  "${provider.items.length} productos identificados",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.blue[200] : Colors.blue[100],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            backgroundColor: isDark
                ? const Color(0xFF1A1A24)
                : Colors.blue[900],
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 8.0,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.42,
                  ),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: isDark ? Colors.blue[700] : Colors.white,
                      foregroundColor: isDark ? Colors.white : Colors.blue[900],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _openConfirmModal(context, isClient),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            actionText,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Container(
              color: isDark ? const Color(0xFF14141C) : Colors.grey[200],
              child: MultiSplitViewTheme(
                data: MultiSplitViewThemeData(dividerThickness: 35),
                child: MultiSplitView(
                  axis: Axis.vertical,
                  controller: _splitController,
                  dividerBuilder:
                      (axis, index, resizable, dragging, highlighted, data) {
                        return _PulsingDragHandle(
                          isDark: isDark,
                          dragging: dragging,
                        );
                      },
                  builder: (BuildContext context, Area area) {
                    if (area.index == 0) {
                      return _buildImageViewer(imagePath);
                    }
                    return _buildDataList(provider, isDark, isClient);
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageViewer(String imagePath) {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          InteractiveViewer(
            minScale: 1.0,
            maxScale: 5.0,
            boundaryMargin: EdgeInsets.zero,
            panEnabled: true,
            child: UniversalImage(path: imagePath, fit: BoxFit.contain),
          ),
          Positioned(
            bottom: 12,
            left: 16,
            right: 16,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.zoom_in_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        "Pellizca para hacer zoom a la lista",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
