part of '../manual_quotation_screen.dart';

extension _ManualQuotationAppBarAndHeadersExt on _ManualQuotationScreenState {
  PreferredSizeWidget _buildAppBar({
    required BuildContext context,
    required bool isDark,
    required Color textColor,
    required bool isClient,
  }) {
    return AppBar(
      leadingWidth: 38,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        padding: EdgeInsets.zero,
        tooltip: 'Volver',
        onPressed: () => Navigator.maybePop(context),
      ),
      titleSpacing: 0,
      actionsPadding: EdgeInsets.zero,
      title: Align(
        alignment: Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            isClient
                ? "Mi Pedido"
                : (_currentQuotationId == null
                      ? "Nueva Cotización"
                      : "Editar Cotización"),
            maxLines: 1,
            style: TextStyle(
              fontSize: 17.5,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
      ),
      backgroundColor: isDark ? const Color(0xFF1A1A24) : Colors.white,
      foregroundColor: textColor,
      elevation: 0,
      actions: [
        InfoTooltipButton(
          iconSize: 20,
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
          title: "Cotización Manual",
          description:
              "Crea o edita presupuestos personalizados seleccionando productos del catálogo o agregando ítems con precios a medida.",
          tips: const [
            InfoTip(
              icon: Icons.description_outlined,
              text:
                  "Abre Identificación de Cotización y Cliente y Colegio para personalizar título, notas o vincular al comprador.",
            ),
            InfoTip(
              icon: Icons.search_rounded,
              text:
                  "Toca Buscar Productos para consultar tu inventario con stock en vivo y añadir presentaciones.",
            ),
            InfoTip(
              icon: Icons.visibility_outlined,
              text:
                  "Usa el botón de privacidad (ojo) para ocultar costos y ganancias cuando atiendas frente al cliente.",
            ),
            InfoTip(
              icon: Icons.point_of_sale_rounded,
              text:
                  "Desliza la barra inferior TOTAL para convertir la cotización en una venta directa con un toque.",
            ),
          ],
          onStartInteractiveTour: () => InteractiveTourService.startManualTour(
            context,
            _buildManualTourConfig(),
          ),
        ),
        Consumer<QuickSaleProvider>(
          builder: (ctx, quickProv, _) => KeyedSubtree(
            key: _tourKeys.privacyEyeKey,
            child: IconButton(
              icon: Icon(
                quickProv.hideProfits
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              splashRadius: 18,
              tooltip: quickProv.hideProfits
                  ? "Modo Cliente (Privacidad activa)"
                  : "Modo Vendedor",
              onPressed: () => quickProv.toggleHideProfits(),
            ),
          ),
        ),
        if (_items.isNotEmpty)
          IconButton(
            icon: Icon(
              Icons.delete_sweep,
              color: isDark ? Colors.red[400] : Colors.red,
              size: 21,
            ),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            splashRadius: 18,
            tooltip: "Limpiar Todo",
            onPressed: _clearWholeList,
          ),
        if (!isClient)
          KeyedSubtree(
            key: _tourKeys.saveButtonKey,
            child: Padding(
              padding: const EdgeInsets.only(
                right: 8,
                left: 2,
                top: 8,
                bottom: 8,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 92),
                child: FilledButton(
                  onPressed: _isSaving ? null : _openSaveModal,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _isSaving
                            ? const SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_rounded, size: 17),
                        const SizedBox(width: 5),
                        const Text(
                          "Guardar",
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildManualHeaders({
    required BuildContext context,
    required bool isDark,
    required Color surfaceColor,
    required Color textColor,
    required bool isGuest,
  }) {
    return ManualQuoteHeadersSection(
      identificationKey: _tourKeys.identificationKey,
      clientSchoolKey: _tourKeys.clientSchoolKey,
      isDark: isDark,
      surfaceColor: surfaceColor,
      textColor: textColor,
      isGuest: isGuest,
      isQuoteDataExpanded: _isQuoteDataExpanded,
      isClientPanelExpanded: _isClientPanelExpanded,
      onQuoteDataExpansionChanged: (val) =>
          updateState(() => _isQuoteDataExpanded = val),
      onClientPanelExpansionChanged: (val) =>
          updateState(() => _isClientPanelExpanded = val),
      quoteTitleCtrl: _quoteTitleCtrl,
      quoteNotesCtrl: _quoteNotesCtrl,
      schoolCtrl: _schoolCtrl,
      gradeCtrl: _gradeCtrl,
      selectedClient: _selectedClient,
      clientNameCtrl: _clientNameCtrl,
      clientPhoneCtrl: _clientPhoneCtrl,
      clientDniCtrl: _clientDniCtrl,
      clientAddressCtrl: _clientAddressCtrl,
      clientEmailCtrl: _clientEmailCtrl,
      clientNotesCtrl: _clientNotesCtrl,
      isNewClientMode: _updateClientData,
      onNewClientModeChanged: (v) {
        updateState(() {
          _updateClientData = v ?? false;
          _hasUnsavedChanges = true;
        });
      },
      isAutoTitleMode: _isAutoTitleMode,
      onRestoreAutoTitle: _restoreAutoTitle,
      onSearchClientTap: (isGuest || _isAppOrder)
          ? () {
              if (_isAppOrder) {
                AppFeedbackHelper.showError(
                  context,
                  "Este pedido pertenece a un cliente de la App. Clónalo si deseas asignarlo a otra persona.",
                );
              } else {
                _showExplorationModal(context, isDark);
              }
            }
          : _showClientSearch,
      onClearClient: _isAppOrder
          ? () {
              AppFeedbackHelper.showError(
                context,
                "No puedes desvincular a un usuario de la App.",
              );
            }
          : _clearClient,
    );
  }

  Widget _buildStatusBanners({
    required BuildContext context,
    required bool isDark,
    required bool isGuest,
    required bool isClient,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isGuest)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Estás explorando. Agrega productos al carrito para ver cómo funciona, pero no podrás guardar.",
                    style: TextStyle(
                      color: isDark ? Colors.orange[200] : Colors.orange[900],
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (_outdatedItemsCount > 0 && !isClient)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.15),
            ),
            child: Row(
              children: [
                Icon(Icons.sync_problem, color: Colors.blue[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "$_outdatedItemsCount productos tienen nombres o precios desactualizados en el inventario.",
                    style: TextStyle(
                      color: isDark ? Colors.blue[200] : Colors.blue[900],
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Flexible(
                  fit: FlexFit.loose,
                  child: TextButton(
                    onPressed: () {
                      Provider.of<WorkbenchProvider>(context, listen: false)
                          .refreshQuotation(
                            widget.quotationId!,
                            fixPrices: true,
                            fixStock: true,
                            fixNames: true,
                            fixBundles: true,
                          )
                          .then((_) {
                            if (!context.mounted) {
                              return;
                            }
                            AppFeedbackHelper.showSuccess(
                              context,
                              "Cotización actualizada correctamente.",
                            );
                            _initData();
                          })
                          .catchError((e) {
                            if (!context.mounted) {
                              return;
                            }
                            AppFeedbackHelper.showError(
                              context,
                              "Error al actualizar.",
                            );
                          });
                    },
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "Sincronizar",
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
